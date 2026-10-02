/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 */

// Hall of Records: characters earn a family name.
// At the writ level a Writ of Lineage arrives by mail and starts the faction quest. The quest asks for
// ink, a quill, vellum and an official seal, each sold only by one capital city innkeeper while the quest
// is active. The faction registry (Orgrimmar or Stormwind) takes the four supplies, inscribes the family
// name and returns the player to the character screen so every client picks up the new name.

#include "LastName.h"
#include "CharacterCache.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "GameObjectScript.h"
#include "GameTime.h"
#include "Item.h"
#include "Log.h"
#include "Mail.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "PlayerScript.h"
#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "StringFormat.h"
#include "WorldPacket.h"
#include "WorldScript.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include <mutex>
#include <unordered_set>

namespace
{
    enum RegistryActions
    {
        ACTION_REQUEST_WRIT = 1,
        ACTION_INSCRIBE     = 2,
    };

    // Characters that were already mailed a writ, so a writ left unread in the mailbox isn't sent again.
    class WritTracker
    {
    public:
        static WritTracker* instance()
        {
            static WritTracker instance;
            return &instance;
        }

        void Load()
        {
            std::lock_guard<std::mutex> lock(_lock);
            _sent.clear();

            if (QueryResult result = CharacterDatabase.Query("SELECT `guid` FROM `mod_last_name_writ`"))
            {
                do
                {
                    _sent.insert(result->Fetch()[0].Get<uint32>());
                } while (result->NextRow());
            }
        }

        [[nodiscard]] bool WasSent(ObjectGuid::LowType guid)
        {
            std::lock_guard<std::mutex> lock(_lock);
            return _sent.count(guid) > 0;
        }

        void MarkSent(ObjectGuid::LowType guid)
        {
            {
                std::lock_guard<std::mutex> lock(_lock);
                if (!_sent.insert(guid).second)
                    return;
            }

            CharacterDatabase.Execute("INSERT IGNORE INTO `mod_last_name_writ` (`guid`) VALUES ({})", guid);
        }

    private:
        std::mutex _lock;
        std::unordered_set<ObjectGuid::LowType> _sent;
    };

    // The writ starts the quest and is also one of its required items, so a character without one
    // (never received, or lost after accepting the quest) needs a new one to finish.
    bool IsEligibleForWrit(Player* player)
    {
        return sLastNameConfig->IsRegistryEnabled()
            && player->GetLevel() >= sLastNameConfig->GetWritLevel()
            && !LastName::HasSurname(player->GetName())
            && !player->GetQuestRewardStatus(LastName::GetQuestForTeam(player->GetTeamId()))
            && !player->HasItemCount(LastName::GetWritForTeam(player->GetTeamId()), 1, true);
    }

    void MailWrit(Player* player)
    {
        bool const horde = player->GetTeamId() == TEAM_HORDE;

        std::string const subject = "Writ of Lineage";
        std::string const body = horde
            ? "By order of the Warchief, citizens of the Horde who have proven themselves may inscribe a family "
              "name in the Hall of Records of Orgrimmar.\n\nRead the enclosed writ to learn what the Keeper of "
              "Records requires.\n\n- Keeper of Records, Orgrimmar"
            : "By decree of the King, citizens of the Alliance who have proven themselves may inscribe a family "
              "name in the Hall of Records of Stormwind.\n\nRead the enclosed writ to learn what the Keeper of "
              "Records requires.\n\n- Keeper of Records, Stormwind";

        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        MailDraft draft(subject, body);

        if (Item* writ = Item::CreateItem(LastName::GetWritForTeam(player->GetTeamId()), 1, player))
        {
            writ->SaveToDB(trans);
            draft.AddItem(writ);
        }

        draft.SendMailTo(trans, MailReceiver(player), MailSender(MAIL_CREATURE, LAST_NAME_MAIL_SENDER));
        CharacterDatabase.CommitTransaction(trans);

        WritTracker::instance()->MarkSent(player->GetGUID().GetCounter());
    }

    void TrySendWrit(Player* player)
    {
        if (IsEligibleForWrit(player) && !WritTracker::instance()->WasSent(player->GetGUID().GetCounter()))
            MailWrit(player);
    }

    char const* GetNameErrorText(uint8 result)
    {
        switch (result)
        {
            case CHAR_NAME_TOO_SHORT:
                return "That family name is too short.";
            case CHAR_NAME_TOO_LONG:
                return "That family name is too long.";
            case CHAR_NAME_INVALID_CHARACTER:
            case CHAR_NAME_MIXED_LANGUAGES:
                return "A family name may only use letters, all from the same alphabet as your first name.";
            case CHAR_NAME_THREE_CONSECUTIVE:
                return "A family name cannot use the same letter three times in a row.";
            case CHAR_NAME_PROFANE:
                return "The Keeper of Records refuses to inscribe that name.";
            case CHAR_NAME_RESERVED:
                return "That name is reserved and cannot be inscribed.";
            default:
                return "The ledger will not accept that name.";
        }
    }

    void Inscribe(Player* player, GameObject* registry, std::string surname)
    {
        ChatHandler handler(player->GetSession());
        uint32 const questId = LastName::GetQuestForTeam(player->GetTeamId());
        Quest const* quest = sObjectMgr->GetQuestTemplate(questId);

        // Checked again here: the menu can be left open while the player's state changes.
        if (!quest || LastName::HasSurname(player->GetName()) || !player->CanRewardQuest(quest, false))
            return;

        std::size_t const first = surname.find_first_not_of(' ');
        if (first == std::string::npos)
        {
            handler.SendSysMessage("Enter a family name to inscribe.");
            return;
        }

        surname = surname.substr(first, surname.find_last_not_of(' ') - first + 1);
        if (LastName::HasSurname(surname))
        {
            handler.SendSysMessage("Enter a single family name, without spaces.");
            return;
        }

        std::string fullName = player->GetName() + ' ' + surname;
        if (!normalizePlayerName(fullName))
        {
            handler.SendSysMessage(GetNameErrorText(CHAR_NAME_INVALID_CHARACTER));
            return;
        }

        uint8 const result = ObjectMgr::CheckPlayerName(fullName, true);
        if (result != CHAR_NAME_SUCCESS)
        {
            handler.SendSysMessage(GetNameErrorText(result));
            return;
        }

        if (sCharacterCache->GetCharacterGuidByName(fullName))
        {
            handler.PSendSysMessage("Another adventurer already bears the name {}.", fullName);
            return;
        }

        std::string const oldName = player->GetName();
        std::string lastName = fullName.substr(fullName.find(' ') + 1);

        // Takes the writ and the four supplies, the quest's required items.
        player->RewardQuest(quest, 0, registry);

        player->SetName(fullName);
        sCharacterCache->UpdateCharacterData(player->GetGUID(), fullName);
        player->SaveToDB(false, false);

        // Clients cache names by GUID. This makes online players query the name again and see the new one.
        WorldPacket invalidate(SMSG_INVALIDATE_PLAYER, 8);
        invalidate << player->GetGUID();
        sWorldSessionMgr->SendGlobalMessage(&invalidate);

        std::string firstName = oldName;
        CharacterDatabase.EscapeString(firstName);
        CharacterDatabase.EscapeString(lastName);
        CharacterDatabase.Execute("REPLACE INTO `mod_last_name_surname` (`guid`, `account`, `first_name`, `surname`) "
            "VALUES ({}, {}, '{}', '{}')", player->GetGUID().GetCounter(), player->GetSession()->GetAccountId(), firstName, lastName);

        LOG_INFO("module", "mod-last_name: {} ({}) inscribed a family name and is now {}", oldName, player->GetGUID().ToString(), fullName);

        uint32 const delay = sLastNameConfig->GetLogoutDelay();
        handler.PSendSysMessage("The Keeper of Records inscribes {} into the ledger. You will return to the character "
            "screen in {} seconds to take up your new name.", fullName, delay);

        // Large yellow text mid-screen, since the chat line is easy to miss and there is no logout countdown.
        handler.SendNotification("Your family name has been recorded. Returning to character select...");

        // Deferred to the session update: logging out inside the gossip handler would free the player mid-packet.
        // ShouldLogOut() fires 20 seconds after the logout start time.
        player->GetSession()->SetLogoutStartTime(GameTime::GetGameTime().count() - 20 + delay);
    }

    class LastNameRegistryWorldScript : public WorldScript
    {
    public:
        LastNameRegistryWorldScript() : WorldScript("LastNameRegistryWorldScript", { WORLDHOOK_ON_STARTUP }) { }

        void OnStartup() override
        {
            WritTracker::instance()->Load();
        }
    };

    class LastNameRegistryPlayerScript : public PlayerScript
    {
    public:
        LastNameRegistryPlayerScript() : PlayerScript("LastNameRegistryPlayerScript", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LEVEL_CHANGED }) { }

        // Also covers characters that were already past the writ level when the module was installed.
        void OnPlayerLogin(Player* player) override
        {
            TrySendWrit(player);
        }

        void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
        {
            TrySendWrit(player);
        }
    };

    class go_last_name_registry : public GameObjectScript
    {
    public:
        go_last_name_registry() : GameObjectScript("go_last_name_registry") { }

        bool OnGossipHello(Player* player, GameObject* go) override
        {
            ClearGossipMenuFor(player);
            ChatHandler handler(player->GetSession());

            if (!sLastNameConfig->IsRegistryEnabled())
            {
                handler.SendSysMessage("The Hall of Records is closed.");
                return true;
            }

            bool const hordeRegistry = go->GetEntry() == LAST_NAME_GO_REGISTRY_HORDE;
            if ((player->GetTeamId() == TEAM_HORDE) != hordeRegistry)
            {
                handler.SendSysMessage(hordeRegistry ? "Only citizens of the Horde may sign this ledger."
                    : "Only citizens of the Alliance may sign this ledger.");
                return true;
            }

            uint32 const questId = LastName::GetQuestForTeam(player->GetTeamId());
            if (LastName::HasSurname(player->GetName()) || player->GetQuestRewardStatus(questId))
            {
                handler.SendSysMessage("Your family name is already recorded in this ledger.");
                return true;
            }

            if (player->GetLevel() < sLastNameConfig->GetWritLevel())
            {
                handler.PSendSysMessage("Return to the Hall of Records once you have reached level {}.", uint32(sLastNameConfig->GetWritLevel()));
                return true;
            }

            if (IsEligibleForWrit(player))
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, "I need a Writ of Lineage.", GOSSIP_SENDER_MAIN, ACTION_REQUEST_WRIT);

            Quest const* quest = sObjectMgr->GetQuestTemplate(questId);
            if (quest && player->CanRewardQuest(quest, false))
            {
                std::string const popup = Acore::StringFormat("Enter your family name, letters only, up to {}. You will be "
                    "returned to the character screen to take up your new name.", sLastNameConfig->GetMaxPartLength());
                AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Inscribe my family name in the ledger.", GOSSIP_SENDER_MAIN,
                    ACTION_INSCRIBE, popup, 0, true);
            }

            SendGossipMenuFor(player, LAST_NAME_TEXT_REGISTRY, go->GetGUID());
            return true;
        }

        bool OnGossipSelect(Player* player, GameObject* /*go*/, uint32 /*sender*/, uint32 action) override
        {
            CloseGossipMenuFor(player);

            if (action == ACTION_REQUEST_WRIT && IsEligibleForWrit(player)
                && player->AddItem(LastName::GetWritForTeam(player->GetTeamId()), 1))
                WritTracker::instance()->MarkSent(player->GetGUID().GetCounter());

            return true;
        }

        bool OnGossipSelectCode(Player* player, GameObject* go, uint32 /*sender*/, uint32 action, char const* code) override
        {
            CloseGossipMenuFor(player);

            if (action == ACTION_INSCRIBE && sLastNameConfig->IsRegistryEnabled())
                Inscribe(player, go, code);

            return true;
        }
    };
}

void AddLastNameRegistryScripts()
{
    new LastNameRegistryWorldScript();
    new LastNameRegistryPlayerScript();
    new go_last_name_registry();
}
