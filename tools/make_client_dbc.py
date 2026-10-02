#!/usr/bin/env python3
"""
mod-last_name: build the client DBC files for the Hall of Records.

Appends the module's rows to copies of Item.dbc, Achievement.dbc, Achievement_Criteria.dbc and
GameObjectDisplayInfo.dbc and writes them to client/DBFilesClient/. Pack the whole client/ folder into a patch MPQ:
DBFilesClient\\*.dbc plus the registry model under World\\.

The rows mirror data/sql/db-world/last_name_hall_of_records.sql; change both together.

Usage:
    python tools/make_client_dbc.py <source folder> [source folder ...]

The source is your server's dbc folder (the DataDir dbc folder, e.g. <AzerothCore>/Data/dbc). Each DBC is read from the
first source folder that has it, so list your custom patch folder before the stock DBC folder:

    python tools/make_client_dbc.py "C:/MyPatch/DBFilesClient" <AzerothCore>/Data/dbc

Rows with the module's IDs are replaced if they already exist, so running the script again on its own output is safe.
"""

import struct
import sys
from pathlib import Path

LOCALE_MASK = 0xFF01FE  # same value Blizzard rows use for filled enUS strings
LOCALES = 16

ITEMS = [
    # ID, class, subclass, sound override, material, display, inventory type, sheath
    (911101, 12, 0, -1, 7, 3048, 0, 0),
    (911102, 12, 0, -1, 7, 3048, 0, 0),
    (911103, 12, 0, -1, 3, 55108, 0, 0),
    (911104, 12, 0, -1, 7, 21370, 0, 0),
    (911105, 12, 0, -1, 8, 57388, 0, 0),
    (911106, 12, 0, -1, 1, 40184, 0, 0),
    (911107, 12, 0, -1, 3, 55113, 0, 0),
    (911108, 12, 0, -1, 7, 19569, 0, 0),
    (911109, 12, 0, -1, 8, 57388, 0, 0),
    (911110, 12, 0, -1, 1, 40185, 0, 0),
]

ACHIEVEMENTS = [
    # ID, faction (0 Horde, 1 Alliance), title, description, category, points, icon, reward
    (5101, 0, "What's in a Name?",
     "Gather ink, a quill, vellum and an official seal from the innkeepers of the four great cities of the Horde.",
     92, 10, 2049, "Reward: A family name at the Hall of Records"),
    (5102, 1, "What's in a Name?",
     "Gather ink, a quill, vellum and an official seal from the innkeepers of the four great cities of the Alliance.",
     92, 10, 2049, "Reward: A family name at the Hall of Records"),
]

CRITERIA = [
    # ID, achievement, type (36 = own item), item, quantity, description, ui order
    (20101, 5101, 36, 911103, 1, "Forsaken Iron-Gall Ink", 1),
    (20102, 5101, 36, 911104, 1, "Silvermoon Scribe's Quill", 2),
    (20103, 5101, 36, 911105, 1, "Mulgore Vellum", 3),
    (20104, 5101, 36, 911106, 1, "Warchief's Official Seal", 4),
    (20105, 5102, 36, 911107, 1, "Ironforge Forge-Black Ink", 1),
    (20106, 5102, 36, 911108, 1, "Darnassian Owl-Feather Quill", 2),
    (20107, 5102, 36, 911109, 1, "Exodar Crystal Vellum", 3),
    (20108, 5102, 36, 911110, 1, "King's Official Seal", 4),
]

GAMEOBJECT_DISPLAYS = [
    # ID, model, geometry box min and max (the model's bounding box)
    (10101, "World\\Expansion10\\Doodads\\Arathor\\11AT_Arathor_BookWheel01.mdx",
     (-1.5934, -2.0754, -0.0542), (2.7379, 2.0754, 2.9888)),
]


def float_bits(value):
    return struct.unpack("<I", struct.pack("<f", value))[0]


class Dbc:
    def __init__(self, path):
        data = path.read_bytes()
        magic, count, fields, size, string_size = struct.unpack_from("<4s4I", data)
        if magic != b"WDBC" or size != fields * 4:
            raise SystemExit(f"{path} is not a WDBC file with 4 byte fields")
        self.fields = fields
        self.records = [list(struct.unpack_from(f"<{fields}I", data, 20 + i * size)) for i in range(count)]
        self.strings = bytearray(data[20 + count * size:20 + count * size + string_size])

    def add_string(self, text):
        offset = len(self.strings)
        self.strings += text.encode("utf-8") + b"\0"
        return offset

    def localized(self, text):
        # enUS slot, the 15 other locales empty, then the locale mask
        return [self.add_string(text)] + [0] * (LOCALES - 1) + [LOCALE_MASK]

    def add(self, record):
        if len(record) != self.fields:
            raise SystemExit(f"record {record[0]} has {len(record)} fields, expected {self.fields}")
        # Replace an earlier copy of the same row (re-run on generated output); strings it used stay unreferenced.
        self.records = [existing for existing in self.records if existing[0] != record[0]]
        self.records.append([value & 0xFFFFFFFF for value in record])

    def write(self, path):
        body = b"".join(struct.pack(f"<{self.fields}I", *record) for record in self.records)
        header = struct.pack("<4s4I", b"WDBC", len(self.records), self.fields, self.fields * 4, len(self.strings))
        path.write_bytes(header + body + bytes(self.strings))


def find_source(sources, name):
    for folder in sources:
        # Patch folders often use a different case, e.g. item.dbc
        for candidate in folder.glob("*"):
            if candidate.name.lower() == name.lower():
                print(f"{name}: reading {candidate}")
                return candidate
    raise SystemExit(f"{name} not found in: {', '.join(str(folder) for folder in sources)}")


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    sources = [Path(arg) for arg in sys.argv[1:]]
    target = Path(__file__).resolve().parent.parent / "client" / "DBFilesClient"
    target.mkdir(parents=True, exist_ok=True)

    items = Dbc(find_source(sources, "Item.dbc"))
    for row in ITEMS:
        items.add(list(row))
    items.write(target / "Item.dbc")

    achievements = Dbc(find_source(sources, "Achievement.dbc"))
    for ach_id, faction, title, description, category, points, icon, reward in ACHIEVEMENTS:
        achievements.add([ach_id, faction, -1, 0]
                         + achievements.localized(title)
                         + achievements.localized(description)
                         + [category, points, 0, 0, icon]
                         + achievements.localized(reward)
                         + [0, 0])
    achievements.write(target / "Achievement.dbc")

    criteria = Dbc(find_source(sources, "Achievement_Criteria.dbc"))
    for crit_id, ach_id, crit_type, asset, quantity, description, order in CRITERIA:
        criteria.add([crit_id, ach_id, crit_type, asset, quantity, 0, 0, 0, 0]
                     + criteria.localized(description)
                     + [0, 0, 0, 0, order])
    criteria.write(target / "Achievement_Criteria.dbc")

    displays = Dbc(find_source(sources, "GameObjectDisplayInfo.dbc"))
    for display_id, model, box_min, box_max in GAMEOBJECT_DISPLAYS:
        # 10 sounds, then the geometry box, then the object effect package
        displays.add([display_id, displays.add_string(model)] + [0] * 10
                     + [float_bits(value) for value in box_min + box_max] + [0])
    displays.write(target / "GameObjectDisplayInfo.dbc")

    print(f"Wrote Item.dbc, Achievement.dbc, Achievement_Criteria.dbc and GameObjectDisplayInfo.dbc to {target}")


if __name__ == "__main__":
    main()
