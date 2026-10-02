/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 * Author: AlsoNotMehh
 */

#ifndef MOD_LAST_NAME_H
#define MOD_LAST_NAME_H

#include "Define.h"
#include "SharedDefines.h"
#include <string>

// IDs used by the world SQL in data/sql/db-world and by the client DBC patch.
enum LastNameData : uint32
{
    LAST_NAME_MAIL_SENDER       = 911101, // creature_template, only used as the mail sender name

    LAST_NAME_QUEST_HORDE       = 911101,
    LAST_NAME_QUEST_ALLIANCE    = 911102,

    LAST_NAME_ITEM_WRIT_HORDE   = 911101,
    LAST_NAME_ITEM_WRIT_ALLIANCE = 911102,

    LAST_NAME_GO_REGISTRY_HORDE    = 911101, // Orgrimmar
    LAST_NAME_GO_REGISTRY_ALLIANCE = 911102, // Stormwind

    LAST_NAME_TEXT_REGISTRY     = 911101, // npc_text
};

class LastNameConfig
{
public:
    static LastNameConfig* instance();

    void LoadConfig();

    [[nodiscard]] uint32 GetMinPartLength() const { return _minPartLength; }
    [[nodiscard]] uint32 GetMaxPartLength() const { return _maxPartLength; }
    [[nodiscard]] bool IsRegistryEnabled() const { return _registryEnabled; }
    [[nodiscard]] uint8 GetWritLevel() const { return _writLevel; }
    [[nodiscard]] uint32 GetLogoutDelay() const { return _logoutDelay; }

private:
    uint32 _minPartLength = 2;
    uint32 _maxPartLength = 12;
    bool _registryEnabled = true;
    uint8 _writLevel = 20;
    uint32 _logoutDelay = 5;
};

#define sLastNameConfig LastNameConfig::instance()

namespace LastName
{
    // True when the name has a first and a last part.
    [[nodiscard]] inline bool HasSurname(std::string const& name) { return name.find(' ') != std::string::npos; }

    [[nodiscard]] inline uint32 GetQuestForTeam(TeamId team)
    {
        return team == TEAM_HORDE ? LAST_NAME_QUEST_HORDE : LAST_NAME_QUEST_ALLIANCE;
    }

    [[nodiscard]] inline uint32 GetWritForTeam(TeamId team)
    {
        return team == TEAM_HORDE ? LAST_NAME_ITEM_WRIT_HORDE : LAST_NAME_ITEM_WRIT_ALLIANCE;
    }
}

#endif
