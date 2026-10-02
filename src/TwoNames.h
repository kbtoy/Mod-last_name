/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 * Author: AlsoNotMehh
 */

#ifndef MOD_TWO_NAMES_H
#define MOD_TWO_NAMES_H

#include "Define.h"
#include "SharedDefines.h"
#include <string>

// IDs used by the world SQL in data/sql/db-world and by the client DBC patch.
enum TwoNamesData : uint32
{
    TWO_NAMES_MAIL_SENDER       = 911101, // creature_template, only used as the mail sender name

    TWO_NAMES_QUEST_HORDE       = 911101,
    TWO_NAMES_QUEST_ALLIANCE    = 911102,

    TWO_NAMES_ITEM_WRIT_HORDE   = 911101,
    TWO_NAMES_ITEM_WRIT_ALLIANCE = 911102,

    TWO_NAMES_GO_REGISTRY_HORDE    = 911101, // Orgrimmar
    TWO_NAMES_GO_REGISTRY_ALLIANCE = 911102, // Stormwind

    TWO_NAMES_TEXT_REGISTRY     = 911101, // npc_text
};

class TwoNamesConfig
{
public:
    static TwoNamesConfig* instance();

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

#define sTwoNamesConfig TwoNamesConfig::instance()

namespace TwoNames
{
    // True when the name has a first and a last part.
    [[nodiscard]] inline bool HasSurname(std::string const& name) { return name.find(' ') != std::string::npos; }

    [[nodiscard]] inline uint32 GetQuestForTeam(TeamId team)
    {
        return team == TEAM_HORDE ? TWO_NAMES_QUEST_HORDE : TWO_NAMES_QUEST_ALLIANCE;
    }

    [[nodiscard]] inline uint32 GetWritForTeam(TeamId team)
    {
        return team == TEAM_HORDE ? TWO_NAMES_ITEM_WRIT_HORDE : TWO_NAMES_ITEM_WRIT_ALLIANCE;
    }
}

#endif
