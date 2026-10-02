# mod-last_name: Family Names for AzerothCore (3.3.5a)

Characters are created with a single name as usual. After reaching level 20 they can **earn a family name** through
the Hall of Records, turning `John` into `John Doe`. No `Wow.exe` patch is needed. The client patch carries DBC data
for the new items and achievements, the book wheel model used by the registry, and one FrameXML file so typed
commands such as `/w John Doe` and `/friend John Doe` take the full name.

## How players earn a family name

1. At level 20 a **Writ of Lineage** arrives by mail from the Keeper of Records. Characters already past 20 get it
   on their next login. Reading the writ starts the quest **A Name Worth Keeping**.
2. The quest asks for four supplies. Each is sold by one capital city innkeeper, only while the quest is active:

   | Horde | Innkeeper | Alliance | Innkeeper |
   | :--- | :--- | :--- | :--- |
   | Forsaken Iron-Gall Ink | Norman, Undercity | Ironforge Forge-Black Ink | Firebrew, Ironforge |
   | Silvermoon Scribe's Quill | Velandra, Silvermoon City | Darnassian Owl-Feather Quill | Saelienne, Darnassus |
   | Mulgore Vellum | Pala, Thunder Bluff | Exodar Crystal Vellum | Caregiver Breel, The Exodar |
   | Warchief's Official Seal | Gryshka, Orgrimmar | King's Official Seal | Allison, Stormwind |

3. Owning all four completes the achievement **What's in a Name?**, which shows the four cities as a checklist.
4. At the **Hall of Records Registry** (Orgrimmar for the Horde, Stormwind for the Alliance) the player chooses
   "Inscribe my family name" and types it. The name goes through the same checks as character creation: letters
   only, reserved names, profanity filter, and whether it's already taken. If it fails, the player keeps everything
   and can try again.
5. On success the supplies and writ are taken and the character is renamed. A chat message and a center-screen
   notice announce the change, and a few seconds later the player returns to the character screen.

A lost writ can be replaced at the registry. Each character can register a family name once. Writs are only mailed to
characters played from a client, so bots such as those of mod-playerbots don't receive them.

## Installation

### 1. Core hooks

The module needs two script hooks the core doesn't have yet: `MiscScript::OnNormalizePlayerName` and
`MiscScript::OnCheckPlayerName`. Apply the patch from the AzerothCore root, then rebuild:

```bash
git apply modules/mod-last_name/core-patch/last-name-hooks.patch
```

Both hooks are also required at login: the core validates every character name when it loads, and would otherwise
force a rename on anyone with a family name.

### 2. Server module

1. Clone the module into `modules/`, then re-run CMake and build. Keep the folder name `mod-last_name`: AzerothCore
   derives the module's script loader from it.

   ```bash
   cd modules
   git clone https://github.com/kbt0y5/mod-last_name.git
   ```

2. Copy `conf/mod_last_name.conf.dist` to your worldserver config folder as `mod_last_name.conf`.
3. The SQL in `data/sql/db-world` and `data/sql/db-characters` is applied automatically by the database updater. The
   characters SQL widens `characters.name` to 25 characters.
4. The module uses ID 911101-911110 (items), 911101-911102 (quests, gameobjects), 911101 (creature, npc_text),
   5101-5102 (achievements), 20101-20108 (achievement criteria) and 10101 (gameobject display). Check they're free
   in your database.

### 3. Spawn the registries

In game, stand where each ledger should go and run:

- Orgrimmar: `.gobject add 911101`
- Stormwind: `.gobject add 911102`

### 4. Client patch

```bash
python tools/make_client_patch.py --toc <your FrameXML.toc> <AzerothCore>/Data/dbc
```

Pass your server's dbc folder (under `DataDir` in `worldserver.conf`). This writes `Item.dbc`, `Achievement.dbc`,
`Achievement_Criteria.dbc` and `GameObjectDisplayInfo.dbc` to `client/DBFilesClient/`. If one of your existing patch
MPQs already ships a modified copy of one of these DBCs, list its folder first so your other changes are kept.

`--toc` is the `Interface\FrameXML\FrameXML.toc` your client loads today: the one in your UI patch if you have one,
otherwise the stock file extracted from `patch-enUS-3.MPQ`. The script writes it to `client/Interface/FrameXML/` with
`LastName.lua` added at the end. Without `--toc`, add that line to your FrameXML.toc yourself.

Pack the whole `client/` folder into a patch MPQ (for example `patch-T.MPQ`), keeping its paths: `DBFilesClient\` for
the DBCs, `Interface\FrameXML\` for `LastName.lua` and the toc, and `World\Expansion10\Doodads\Arathor\` for the
registry's book wheel model.

Without the client patch the server side still works, but the items show as unknown, the achievement doesn't appear
in the achievement window, the registry is invisible, and typed commands only take the first word of a name.

## Configuration (`mod_last_name.conf`)

| Setting | Default | Description |
| :--- | :---: | :--- |
| `LastName.MinPartLength` | `2` | Minimum letters in a family name. |
| `LastName.MaxPartLength` | `12` | Maximum letters in a family name, capped at 12. |
| `LastName.Registry.Enable` | `1` | Writ mail, supplies and registries. Existing family names stay valid when disabled. |
| `LastName.Registry.WritLevel` | `20` | Level the writ is mailed at. Keep equal to the quests' `MinLevel`. |
| `LastName.Registry.LogoutDelay` | `5` | Seconds from inscribing to returning to the character screen (max 20). |

## Name rules

Single names are left entirely to the core. For a two-part name, each part must pass the core's normal name checks
(alphabet, no three identical letters in a row, reserved and profane names) and the minimum and maximum part length.
Both parts must use the same alphabet, and the full name is also checked against the reserved and profanity lists.

## Full names in the client

The server sends full names everywhere it sends a name, so chat, the friends and ignore lists, the guild roster,
`/who`, mail and unit frames all show `John Doe`. Names typed in or picked from the UI also work with the stock client:
chat links, right-click menus, `/r`, `/invite`, `/ignore`, guild and team commands, and the Add Friend and Add Ignore
dialogs. `/who n-"John Doe"` finds one player; `/who John Doe` matches either word, like any other `/who` search.

The FrameXML file in the client patch (`LastName.lua`) covers the rest:

- **Whispers:** the stock chat box keeps a two-word target only when it's on the autocomplete list (friends, guild,
  group, recent contacts), and otherwise whispers the first word. `LastName.lua` also counts every two-part name seen
  this session in chat, `/who`, your target and your mouseover. For anyone else, type `/w "John Doe" hi` or
  `/w John_Doe hi`. To whisper a single-name `John` a message starting with a known surname, quote it: `/w "John" Doe...`.
- **`/friend John Doe`:** resolved the same way (the stock command adds `John` with the note `Doe`).
- **Name boxes:** the mail "To:" box and the guild, raid, arena team and mute dialogs take up to 25 letters instead
  of 12.

## Addon settings after a rename

The client stores addon settings by character name, so `John Doe` starts out without `John`'s.

- **Account-wide settings keyed by character** (every addon using AceDB): at login, `LastName.lua` moves entries saved
  under `John - <realm>` to `John Doe - <realm>` and offers a UI reload so the addons pick them up. This happens once.
- **Per-character saved variables, enabled addons and layout** live in `WTF\Account\<ACCOUNT>\<Realm>\John`, a folder
  the game can't rename. The registry tells the player to close the game and copy it to `John Doe` in the same place.
  Keybindings, macros and chat settings are stored on the server by character and come back on their own.

## Known limitations

- **GM commands:** typed player names are split at the space. Use a shift-clicked player link, a GUID or a target.
- **Paid services:** race change, faction change and appearance change resend the name from the client, and the
  unpatched client rejects names with a space. Not yet tested.
- Online players are told to refresh the renamed character (`SMSG_INVALIDATE_PLAYER`, as TrinityCore does on
  rename). Not yet tested in game; if a client still shows the old name, it updates when that player relogs.

## Credits

- Based on [mod-two-names](https://github.com/AlsoNotMehh/mod-two-names) by [AlsoNotMehh](https://github.com/AlsoNotMehh)
- Framework: [AzerothCore](https://www.azerothcore.org)
- Registry model: `11AT_Arathor_BookWheel01` from World of Warcraft, © Blizzard Entertainment

## License

[GNU AGPL v3](LICENSE)
