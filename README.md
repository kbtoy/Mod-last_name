# mod-two-names: Family Names for AzerothCore (3.3.5a)

Characters are created with a single name as usual. After reaching level 20 they can **earn a family name** through
the Hall of Records, turning `John` into `John Doe`. No `Wow.exe` patch is needed. The client patch only carries DBC
data for the new items and achievements.

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

A lost writ can be replaced at the registry. Each character can register a family name once.

## Installation

### 1. Core hooks

The module needs two script hooks the core doesn't have yet: `MiscScript::OnNormalizePlayerName` and
`MiscScript::OnCheckPlayerName`. Apply the patch from the AzerothCore root, then rebuild:

```bash
git apply modules/mod-two-names/core-patch/two-names-hooks.patch
```

Both hooks are also required at login: the core validates every character name when it loads, and would otherwise
force a rename on anyone with a family name.

### 2. Server module

1. Place the module in `modules/`, re-run CMake and build.
2. Copy `conf/mod_two_names.conf.dist` to your worldserver config folder as `mod_two_names.conf`.
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
python tools/make_client_dbc.py <AzerothCore>/Data/dbc
```

Pass your server's dbc folder (under `DataDir` in `worldserver.conf`). This writes `Item.dbc`, `Achievement.dbc`, `Achievement_Criteria.dbc` and `GameObjectDisplayInfo.dbc` to
`client/DBFilesClient/`. Pack the whole `client/` folder into a patch MPQ (for example `patch-T.MPQ`), keeping its
paths: `DBFilesClient\` for the DBCs and `World\Expansion10\Doodads\Arathor\` for the registry's book wheel model. If one
of your existing patch MPQs already ships a modified copy of one of these DBCs, point the script at that copy instead
so your other changes are kept.

Without the client patch the server side still works, but the items show as unknown, the achievement doesn't appear
in the achievement window and the registry is invisible.

## Configuration (`mod_two_names.conf`)

| Setting | Default | Description |
| :--- | :---: | :--- |
| `TwoNames.MinPartLength` | `2` | Minimum letters in a family name. |
| `TwoNames.MaxPartLength` | `12` | Maximum letters in a family name, capped at 12. |
| `TwoNames.Registry.Enable` | `1` | Writ mail, supplies and registries. Existing family names stay valid when disabled. |
| `TwoNames.Registry.WritLevel` | `20` | Level the writ is mailed at. Keep equal to the quests' `MinLevel`. |
| `TwoNames.Registry.LogoutDelay` | `5` | Seconds from inscribing to returning to the character screen (max 20). |

## Name rules

Single names are left entirely to the core. For a two-part name, each part must pass the core's normal name checks
(alphabet, no three identical letters in a row, reserved and profane names) and the minimum and maximum part length.
Both parts must use the same alphabet, and the full name is also checked against the reserved and profanity lists.

## Known limitations

- **Typed whispers:** `/w John Doe hi` whispers "John", because the 3.3.5 chat box only takes the first word as the
  target. Clicking the name in chat, the friends list, mail, invites and guild commands work with the full name.
- **GM commands:** typed player names are split at the space. Use a shift-clicked player link, a GUID or a target.
- **Paid services:** race change, faction change and appearance change resend the name from the client, and the
  unpatched client rejects names with a space. Not yet tested.
- Online players are told to refresh the renamed character (`SMSG_INVALIDATE_PLAYER`, as TrinityCore does on
  rename). Not yet tested in game; if a client still shows the old name, it updates when that player relogs.

## Credits

- Original module: [AlsoNotMehh](https://github.com/AlsoNotMehh)
- Framework: [AzerothCore](https://www.azerothcore.org)

## License

[GNU AGPL v3](LICENSE)
