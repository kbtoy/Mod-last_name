--[[----------------------------------------------------------------------------
    mod-last_name -- typed family names ("John Doe") and addon settings after a rename.

    This is a FrameXML file: it is listed at the end of FrameXML.toc and loads with
    the base UI, after ChatFrame.lua and StaticPopup.lua whose globals it replaces.

    Names with a space already work wherever the client passes the whole text or
    a name it got from the server: chat links, right-click menus, /r, /invite,
    /ignore, the Add Friend and Add Ignore dialogs, /who and the friends list.
    3.3.5 also keeps a typed two-word whisper target when it is on the client's
    autocomplete list (friends, guild, group, recent contacts). This file adds:

      * whisper targets the client has seen this session (chat, /who, target,
        mouseover), plus /w "John Doe" and /w John_Doe for anyone else,
      * the same for /friend, which otherwise takes only the first word,
      * room for a full name in the guild, raid, arena team and mute dialogs
        and the mail "To:" box,
      * moving per-character AceDB settings from the old name to the new one.
------------------------------------------------------------------------------]]

LastName = {}
local ns = LastName

local MAX_NAME_LETTERS = 25         -- two 12 letter parts and a space

-- Two-part names seen this session: known[lower-case name] = name.
local known = {}

local function Remember(name)
    if ( type(name) == "string" and strfind(name, " ", 1, true) ) then
        known[strlower(name)] = name;
    end
end

-- Prefix match, like the autocomplete check: the player may still be typing the name.
local function IsTypingKnownName(text)
    if ( GetAutoCompleteResults(text, AUTOCOMPLETE_LIST.ALL.include, AUTOCOMPLETE_LIST.ALL.exclude, 1, nil, true) ) then
        return true;
    end
    text = strlower(text);
    local length = strlen(text);
    for name in pairs(known) do
        if ( strsub(name, 1, length) == text ) then
            return true;
        end
    end
    return false;
end

function ns.IsKnownName(name)
    if ( known[strlower(name)] ) then
        return true;
    end
    local found = GetAutoCompleteResults(name, AUTOCOMPLETE_LIST.ALL.include, AUTOCOMPLETE_LIST.ALL.exclude, 1, nil, true);
    return found ~= nil and strlower(found) == strlower(name);
end

-- Splits "<name> <rest>" where the name may be "John Doe" in quotes, John_Doe, or two
-- words that form a known name. Returns nil for empty text, like the stock pattern.
function ns.SplitName(text)
    local quoted, rest = strmatch(text, "^%s*\"([^\"]+)\"%s*(.*)$");
    if ( quoted ) then
        return quoted, rest;
    end
    local first, second, after = strmatch(text, "^%s*([^%s]+)%s+([^%s]+)%s*(.*)$");
    if ( first and ns.IsKnownName(first.." "..second) ) then
        return first.." "..second, after;
    end
    local word, tail = strmatch(text, "^%s*([^%s]+)%s*(.*)$");
    if ( word ) then
        return (gsub(word, "_", " ")), tail;
    end
end

--[[--------------------------------------------------------------------------
    Whispers. Same flow as the stock ChatEdit_ExtractTellTarget (called on every
    keystroke after /w), with the names seen this session counted as known and
    the quoted and underscore forms added.
----------------------------------------------------------------------------]]
function ChatEdit_ExtractTellTarget(editBox, msg)
    -- Grab the string after the slash command
    local target = strmatch(msg, "%s*(.*)");
    if ( not target or (strsub(target, 1, 1) == "|") ) then
        return false;
    end

    if ( strsub(target, 1, 1) == "\"" ) then
        -- /w "John Doe" message: wait for the space after the closing quote, like the stock
        -- code waits for the space after a name, so that space doesn't start the message.
        local quoted, rest = strmatch(target, "^\"([^\"]+)\"%s(.*)$");
        if ( not quoted ) then
            return false;
        end
        target, msg = quoted, rest;
    else
        --If we haven't even finished one word, we aren't done.
        if ( not strfind(target, "%s") ) then
            return false;
        end

        --Even if there's a space, let the person keep typing a name the client knows.
        if ( IsTypingKnownName(target) ) then
            return false;
        end

        --Keep pulling off everything after the last space until we either have a known name or only a single word is left.
        while ( strfind(target, "%s") ) do
            target = strmatch(target, "(.+)%s+[^%s]*");
            if ( ns.IsKnownName(target) or GetAutoCompleteResults(target, AUTOCOMPLETE_LIST.ALL.include, AUTOCOMPLETE_LIST.ALL.exclude, 1, nil, true) ) then
                break;
            end
        end

        msg = strsub(msg, strlen(target) + 2);
        -- Character names never contain "_", so John_Doe can only mean John Doe.
        target = gsub(target, "_", " ");
    end

    editBox:SetAttribute("tellTarget", target);
    editBox:SetAttribute("chatType", "WHISPER");
    editBox:SetText(msg);
    ChatEdit_UpdateHeader(editBox);
    return true;
end

SlashCmdList["FRIENDS"] = function(msg)
    local player, note = ns.SplitName(msg);
    if ( player ~= "" or UnitIsPlayer("target") ) then
        AddOrRemoveFriend(player, note);
    else
        ToggleFriendsPanel();
    end
end

for _, which in ipairs({ "ADD_GUILDMEMBER", "ADD_RAIDMEMBER", "ADD_TEAMMEMBER", "ADD_MUTE" }) do
    local dialog = StaticPopupDialogs[which];
    if ( dialog and (dialog.maxLetters or 0) < MAX_NAME_LETTERS ) then
        dialog.maxLetters = MAX_NAME_LETTERS;
    end
end
-- The mail "To:" box (MailFrame.xml, letters="12").
if ( SendMailNameEditBox ) then
    SendMailNameEditBox:SetMaxLetters(MAX_NAME_LETTERS);
end

--[[--------------------------------------------------------------------------
    Addon settings. AceDB keeps per-character data in account-wide saved
    variables under "<name> - <realm>", so after "John" becomes "John Doe" those
    addons start from scratch. At login, entries under the old name (the first
    part of the new one) are moved to the new name, and a reload makes the addons
    pick them up. Per-character saved variables live in a folder named after the
    character (WTF\Account\<account>\<realm>\<name>) and need copying outside
    the game.
----------------------------------------------------------------------------]]
local function MoveAceDBKeys(sv, oldKey, newKey)
    local changed = false;
    for _, section in ipairs({ "profileKeys", "char" }) do
        local entries = rawget(sv, section);
        if ( type(entries) == "table" and entries[oldKey] ~= nil ) then
            if ( entries[newKey] ~= entries[oldKey] ) then
                entries[newKey] = entries[oldKey];
                changed = true;
            end
            entries[oldKey] = nil;
        end
    end
    local namespaces = rawget(sv, "namespaces");
    if ( type(namespaces) == "table" ) then
        for _, child in pairs(namespaces) do
            if ( type(child) == "table" and MoveAceDBKeys(child, oldKey, newKey) ) then
                changed = true;
            end
        end
    end
    return changed;
end

function ns.MoveAddonSettings()
    local name = UnitName("player");
    local oldName = name and strmatch(name, "^([^%s]+) ");
    if ( not oldName ) then
        return false;
    end
    local realm = GetRealmName();
    local oldKey, newKey = oldName.." - "..realm, name.." - "..realm;
    local changed = false;
    for _, value in pairs(_G) do
        if ( type(value) == "table" and type(rawget(value, "profileKeys")) == "table" and MoveAceDBKeys(value, oldKey, newKey) ) then
            changed = true;
        end
    end
    return changed, oldName;
end

StaticPopupDialogs["LASTNAME_RELOAD"] = {
    text = "Addon settings saved under your old name, %s, now belong to %s. Reload the interface to use them.",
    button1 = "Reload UI",
    button2 = "Later",
    OnAccept = function()
        ReloadUI();
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
};

--[[--------------------------------------------------------------------------
    Events
----------------------------------------------------------------------------]]
local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_BATTLEGROUND",
    "CHAT_MSG_BATTLEGROUND_LEADER", "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT",
};

local frame = CreateFrame("Frame");
for _, event in ipairs(CHAT_EVENTS) do
    frame:RegisterEvent(event);
end
frame:RegisterEvent("WHO_LIST_UPDATE");
frame:RegisterEvent("PLAYER_TARGET_CHANGED");
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
frame:RegisterEvent("PLAYER_LOGIN");

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if ( event == "WHO_LIST_UPDATE" ) then
        for i = 1, GetNumWhoResults() do
            Remember((GetWhoInfo(i)));
        end
    elseif ( event == "PLAYER_TARGET_CHANGED" ) then
        if ( UnitIsPlayer("target") ) then
            Remember((UnitName("target")));
        end
    elseif ( event == "UPDATE_MOUSEOVER_UNIT" ) then
        if ( UnitIsPlayer("mouseover") ) then
            Remember((UnitName("mouseover")));
        end
    elseif ( event == "PLAYER_LOGIN" ) then
        local changed, oldName = ns.MoveAddonSettings();
        if ( changed ) then
            StaticPopup_Show("LASTNAME_RELOAD", oldName, (UnitName("player")));
        end
    else
        Remember(arg2);     -- chat: the author, or the recipient of a whisper you sent
    end
end);
