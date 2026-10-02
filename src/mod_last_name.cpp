/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 * Author: AlsoNotMehh
 */

#include "LastName.h"
#include "Config.h"
#include "MiscScript.h"
#include "ObjectMgr.h"
#include "ScriptMgr.h"
#include "Util.h"
#include "WorldScript.h"
#include <algorithm>
#include <string>
#include <string_view>

LastNameConfig* LastNameConfig::instance()
{
    static LastNameConfig instance;
    return &instance;
}

void LastNameConfig::LoadConfig()
{
    _minPartLength = sConfigMgr->GetOption<uint32>("LastName.MinPartLength", 2);
    _maxPartLength = std::min<uint32>(sConfigMgr->GetOption<uint32>("LastName.MaxPartLength", 12), MAX_PLAYER_NAME);
    _registryEnabled = sConfigMgr->GetOption<bool>("LastName.Registry.Enable", true);
    _writLevel = static_cast<uint8>(sConfigMgr->GetOption<uint32>("LastName.Registry.WritLevel", 20));
    _logoutDelay = std::min<uint32>(sConfigMgr->GetOption<uint32>("LastName.Registry.LogoutDelay", 5), 20);
}

namespace
{
    // Same casing rule the core applies to single names: first letter upper, the rest lower.
    bool NormalizePart(std::string& part)
    {
        std::wstring wpart;
        if (part.empty() || !Utf8toWStr(part, wpart))
            return false;

        wstrToLower(wpart);
        wpart[0] = wcharToUpper(wpart[0]);
        return WStrToUtf8(wpart, part);
    }

    uint8 CheckTwoPartName(std::string_view name, bool create)
    {
        if (name.front() == ' ' || name.back() == ' ')
            return CHAR_NAME_INVALID_SPACE;

        if (name.find("  ") != std::string_view::npos)
            return CHAR_NAME_CONSECUTIVE_SPACES;

        std::size_t const space = name.find(' ');
        if (name.find(' ', space + 1) != std::string_view::npos)
            return CHAR_NAME_INVALID_SPACE;

        std::wstring wholeName;
        for (std::string_view part : { name.substr(0, space), name.substr(space + 1) })
        {
            std::wstring wpart;
            if (!Utf8toWStr(part, wpart))
                return CHAR_NAME_INVALID_CHARACTER;

            if (wpart.size() < sLastNameConfig->GetMinPartLength())
                return CHAR_NAME_TOO_SHORT;

            if (wpart.size() > sLastNameConfig->GetMaxPartLength())
                return CHAR_NAME_TOO_LONG;

            // Each part has no space, so this runs the unmodified core rules on it:
            // alphabet, three consecutive letters, reserved and profane names.
            uint8 const partResult = ObjectMgr::CheckPlayerName(part, create);
            if (partResult != CHAR_NAME_SUCCESS)
                return partResult;

            wholeName += wpart;
        }

        // Both parts must be written in the same alphabet.
        if (!isExtendedLatinString(wholeName, false) && !isCyrillicString(wholeName, false) && !isEastAsianString(wholeName, false))
            return CHAR_NAME_MIXED_LANGUAGES;

        if (sObjectMgr->IsReservedName(name))
            return CHAR_NAME_RESERVED;

        if (sObjectMgr->IsProfanityName(name))
            return CHAR_NAME_PROFANE;

        return CHAR_NAME_SUCCESS;
    }

    class LastNameWorldScript : public WorldScript
    {
    public:
        LastNameWorldScript() : WorldScript("LastNameWorldScript", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            sLastNameConfig->LoadConfig();
        }
    };

    // Single names are left entirely to the core; these hooks only take over names containing a space.
    // They stay active regardless of config, otherwise characters with a surname would be forced to rename at login.
    class LastNameMiscScript : public MiscScript
    {
    public:
        LastNameMiscScript() : MiscScript("LastNameMiscScript", { MISCHOOK_ON_NORMALIZE_PLAYER_NAME, MISCHOOK_ON_CHECK_PLAYER_NAME }) { }

        bool OnNormalizePlayerName(std::string& name, bool& result) override
        {
            if (!LastName::HasSurname(name))
                return false;

            // Typed targets such as "/w  john doe " can carry stray outer spaces.
            std::size_t const first = name.find_first_not_of(' ');
            if (first == std::string::npos)
            {
                result = false;
                return true;
            }

            name = name.substr(first, name.find_last_not_of(' ') - first + 1);
            if (!LastName::HasSurname(name))
                return false;

            std::size_t const space = name.find(' ');
            if (name.find(' ', space + 1) != std::string::npos)
            {
                result = false;
                return true;
            }

            std::string firstName = name.substr(0, space);
            std::string lastName = name.substr(space + 1);
            result = NormalizePart(firstName) && NormalizePart(lastName);
            if (result)
                name = firstName + ' ' + lastName;

            return true;
        }

        bool OnCheckPlayerName(std::string_view name, bool create, uint8& result) override
        {
            if (name.find(' ') == std::string_view::npos)
                return false;

            result = CheckTwoPartName(name, create);
            return true;
        }
    };
}

void AddLastNameScripts()
{
    new LastNameWorldScript();
    new LastNameMiscScript();
}
