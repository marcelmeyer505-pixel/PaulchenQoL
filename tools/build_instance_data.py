"""Generate Paulchen's instance index from an installed WoW Forever addon directory."""
import argparse
import json
from pathlib import Path
import re

from lupa.lua51 import LuaRuntime, lua_type


ROOT = Path(__file__).resolve().parents[1]


def contents(path):
    return path.read_text(encoding="utf-8-sig")


def sequence(table):
    if lua_type(table) != "table":
        return []
    return [table[index] for index in range(1, len(table) + 1) if table[index] is not None]


def integers(value):
    values = sequence(value) if lua_type(value) == "table" else [value]
    return [int(number) for number in values if isinstance(number, (int, float)) and number > 0]


def normal(name):
    return re.sub(r"[^\w]", "", re.sub(r"^the\s+", "", (name or "").lower()))


def serialize(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return "{ " + ", ".join(map(serialize, value)) + " }"
    return "{ " + ", ".join(f"[{serialize(k)}] = {serialize(v)}" for k, v in value.items()) + " }"


def spot(value):
    if lua_type(value) != "table":
        return None
    map_id, x, y = value["mapID"] or value["map"], value["x"], value["y"]
    if isinstance(map_id, int) and isinstance(x, (int, float)) and isinstance(y, (int, float)):
        if 0 <= x <= 1 and 0 <= y <= 1 and (x > 0 or y > 0):
            return [map_id, x, y]


def localized(value):
    return {"name": value["name"], "de": value["nameDE"]}


def parse_sources(addons):
    lua = LuaRuntime()
    lua.execute(r'''
    routes, journal, atlas, rates, difficulties = {}, { Constants = {} }, {}, {}, {}
    local function key(_, name) return name end
    local api = { Add = function() return atlas end }
    local locale = setmetatable({}, { __index = function(_, name) return name end })
    local dropRates = { AddData = function(_, records) rates = records end }
    local methods = {
        AddDifficulty = function(_, name, alias)
            difficulties[#difficulties + 1] = alias or name
            return #difficulties
        end,
        AddContentType = key, AddItemTableType = key, AddExtraItemTableType = key,
    }
    setmetatable(atlas, { __index = methods })
    atlasEnvironment = {
        string = string, table = table, math = math, tonumber = tonumber, tostring = tostring,
        type = type, ipairs = ipairs, pairs = pairs, select = select, unpack = unpack,
        setmetatable = setmetatable, C_Seasons = {},
        C_Map = { GetAreaInfo = tostring },
        UnitFactionGroup = function() return "Horde" end, GetLocale = function() return "enUS" end,
        FACTION_HORDE = "Horde", FACTION_ALLIANCE = "Alliance",
        AtlasLoot = {
            ItemDB = api, Locales = locale, CLASSIC_VERSION_NUM = 1, WRATH_VERSION_NUM = 3,
            ReturnForGameVersion = function(era) return era end,
            GameVersion_EQ = function(_, version, value) if version == 1 then return value end end,
            GameVersion_GE = function(_, version, value) if version <= 1 then return value end end,
            GameVersion_LT = function(_, version, value) if version > 1 then return value end end,
            Data = { Droprate = dropRates, ContentPhase = setmetatable({
                Phase = setmetatable({}, { __index = function(_, name) return name end }),
            }, { __index = function() return function() return 1 end end }) },
        },
    }
    atlasEnvironment._G = atlasEnvironment
    setmetatable(atlasEnvironment, { __index = function(_, name)
        if name:match("^ATLASLOOT_") then return name end
    end })
    ''')
    run = lua.eval('function(code, name, ns, env) local chunk = assert(loadstring(code, name)); '
                   'if env then setfenv(chunk, env) end; chunk(name, ns) end')
    globals_ = lua.globals()
    dr = addons / "ForeverDungeonRoutes" / "Data"
    dj = addons / "ForeverDungeonJournal" / "Data"
    atlas = addons / "AtlasLootClassic_DungeonsAndRaids"
    for name in ("Dungeons.lua", "Entrances.lua", "Floors.lua", "Rooms.lua", "Pictures.lua", "Minimaps.lua",
                 "DefaultRoutes.lua"):
        run(contents(dr / name), name, globals_.routes)
    for name in ("Dungeons.lua", "DungeonEntrances.lua", "QuestMaps.lua", "Bosses.lua"):
        run(contents(dj / name), name, globals_.journal)
    # Only evaluate the loot tables. The trailing code hooks AtlasLoot's own UI.
    blob = contents(atlas / "data.lua")
    matches = list(re.finditer(r'^data\[["\']', blob, re.MULTILINE))
    end = re.search(r"^}", blob[matches[-1].end():], re.MULTILINE)
    code = blob[:matches[-1].end() + end.end()].replace("local _G = getfenv(0)", "local _G = _G", 1)
    run(code, "data.lua", None, globals_.atlasEnvironment)
    run(contents(atlas / "droprate.lua"), "droprate.lua", None, globals_.atlasEnvironment)
    return lua, globals_


ATLAS_KEYS = {
    "ragefire": "Ragefire", "deadmines": "TheDeadmines", "shadowfang": "ShadowfangKeep",
    "blackfathom": "BlackfathomDeeps", "stockade": "TheStockade",
    "sunkentemple": "TheTempleOfAtal'Hakkar", "lowerblackrock": "LowerBlackrockSpire",
    "upperblackrock": "UpperBlackrockSpire", "stratholme_living": "Stratholme",
    "stratholme_undead": "Stratholme", "zulgurub": "Zul'Gurub",
    "hallofthanes": "TheHallOfThanes", "ruinsoflordaeron": "TheRuinsOfLordaeron",
    "excavationsite": "ExcavationSiteWetlands", "dalaran": "TheCityOfDalaran",
    "drownedcity": "TheDrownedCity", "kroldok": "TheKrolDokStronghold",
    "alcazprison": "TheAlcazPrison", "blackmawhold": "TheBlackmawHold",
    "shapersterrace": "ShapersTerrace", "sm_graveyard": "ScarletMonasteryGraveyard",
    "sm_armory": "ScarletMonasteryArmory", "sm_cathedral": "ScarletMonasteryCathedral",
    "sm_library": "ScarletMonasteryLibrary", "zulfarrak": "Zul'Farrak",
    "ruinsofahnqiraj": "TheRuinsofAhnQiraj", "templeofahnqiraj": "TheTempleofAhnQiraj",
}
JOURNAL_KEYS = {"stockade": "The Stockade"}


def atlas_loot(location, source):
    loot = {}
    for boss in sequence(location and location["items"]):
        if boss["IgnoreAsSource"] or boss["ExtraList"] or not isinstance(boss["name"], str):
            continue
        name = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", boss["name"])
        npcs = integers(boss["npcID"])
        items = {}
        for slot, difficulty in enumerate(sequence(source.difficulties), 1):
            faction = difficulty.capitalize() if difficulty in ("horde", "alliance") else None
            for row in sequence(boss[slot]):
                if lua_type(row) != "table" or not isinstance(row[2], int) or row[2] <= 0:
                    continue
                item = row[2]
                rate = max((source.rates[npc][item] or 0 for npc in npcs if source.rates[npc]), default=0)
                prior = items.get(item)
                items[item] = [item, rate, faction if not prior or prior[2] == faction else None]
        if items:
            loot[name] = {"name": name, "npcs": npcs, "items": sorted(items.values())}
    return loot


def route_data(route, floors, wing, side_floor):
    if route is None:
        return [], []
    variants = [route] if route["paths"] is not None else sequence(route)
    if wing is not None:
        variants = [option for option in variants if option["id"] == "default:" + wing]
    # The purple and orange entrances are separate approaches to the same inner cave.
    # Other alternate routes revisit the same locations with a different itinerary.
    paths, stops, side_stops, seen_paths, seen_stops = [], [], [], set(), set()
    for index, option in enumerate(variants):
        alternate = index > 0
        for part in sequence(option["paths"]):
            floor = part["floor"]
            points = tuple(sequence(part["pts"]))
            identity = (floor, points)
            if floor in floors and (not alternate or floor == side_floor) and identity not in seen_paths:
                seen_paths.add(identity)
                paths.append({"floor": floor, "side": alternate or part["kind"] == "side", "pts": list(points)})
        for stop in sequence(option["stops"]):
            floor = stop["floor"]
            identity = (floor, normal(stop["name"]))
            encounters = integers(stop["encounters"])
            is_boss = stop["kind"] == "boss"
            if not (is_boss or stop["kind"] in ("optional", "rare") and encounters):
                continue
            if floor not in floors or identity in seen_stops:
                continue
            seen_stops.add(identity)
            marker = {**localized(stop), "floor": floor, "x": stop["x"], "y": stop["y"],
                      "encounters": encounters}
            if alternate or not is_boss:
                marker["alternate"] = True
                side_stops.append(marker)
            else:
                stops.append(marker)
    return paths, stops + side_stops


def room_data(rooms, floors):
    result = []
    for room in sequence(rooms):
        boxes = [sequence(box) for box in sequence(room["boxes"])]
        boxes = [box for box in boxes if len(box) == 6 and box[0] in floors and box[3] > 0 and box[4] > 0]
        if not boxes:
            continue
        names = localized(room)
        aliases = sorted({value for key, value in room.items()
                          if key not in ("name", "nameDE") and key.startswith("name") and isinstance(value, str)}
                         - set(names.values()))
        result.append({**names, "aliases": aliases, "boxes": boxes})
    return result


def run(addons, output):
    lua, source = parse_sources(addons)
    routes, journal, atlas = source.routes, source.journal, source.atlas
    atlas_names = {normal(key): key for key, value in atlas.items() if lua_type(value) == "table" and value["items"]}
    journal_names = {normal(key): key for key in sequence(journal.ORDER)}
    floors, dungeons = {}, []
    for route_dungeon in sequence(routes.Dungeons):
        key = route_dungeon.key
        variants = [key] if key != "stratholme" else ["stratholme_living", "stratholme_undead"]
        for index, variant in enumerate(variants, 1):
            record = {"key": variant, "id": route_dungeon.instanceID, **localized(route_dungeon)}
            if route_dungeon.raid:
                record["raid"] = True
            record["levels"] = sequence(route_dungeon.levels)
            providers_key = JOURNAL_KEYS.get(key) or journal_names.get(normal(route_dungeon.name))
            floor_ids = sequence(route_dungeon.floors)
            if len(variants) > 1:
                name, de = (("Stratholme: Living", "Stratholme: Lebende"),
                            ("Stratholme: Undead", "Stratholme: Untote"))[index - 1]
                record.update(name=name, de=de)
                providers_key = name
                floor_ids = [floor_ids[index - 1]]
            jd = journal.DB[providers_key] if providers_key else None
            entry = spot(routes.Entrances[key])
            wings = routes.WingPortals[route_dungeon.instanceID]
            door = next((door for door in sequence(wings) if door["key"] == key), None)
            if door is not None:
                entry = [wings["map"], door["x"], door["y"]]
            if jd and (not entry or len(variants) > 1):
                entry = spot(jd["entrance"]) or entry
            record["entrance"], record["floors"] = entry, floor_ids

            for floor_id in floor_ids:
                if floor_id in floors:
                    continue
                floor = routes.Floors[floor_id]
                floors[floor_id] = {**localized(floor), "tiles": sequence(floor["tiles"]),
                                    "art": [sequence(tile) for tile in sequence(routes.MinimapArt[floor_id])]}
                position = sequence(floor["frame"]) or sequence(floor["world"])
                if position:
                    floors[floor_id]["position"] = position

            wing = ("living", "undead")[index - 1] if key == "stratholme" else None
            side_floor = 280 if key == "maraudon" else None
            record["paths"], record["stops"] = route_data(routes.DefaultRoutes[key], floor_ids, wing, side_floor)
            rooms = room_data(routes.Rooms[key], floor_ids)
            if rooms:
                record["rooms"] = rooms

            quest_ids = set()
            quests = []
            for quest in sequence(jd and jd["quests"]):
                ids = integers(quest["id"])
                if not ids or ids[0] in quest_ids:
                    continue
                qid = ids[0]
                quest_ids.add(qid)
                rewards = sorted({reward[1] for reward in sequence(quest["rewardItems"])
                                  if lua_type(reward) == "table" and isinstance(reward[1], int) and reward[1] > 0})
                minimum = integers(quest["requires"])
                quests.append({"id": qid, "name": quest["name"], "min": minimum[0] if minimum else None,
                               "faction": quest["faction"] if quest["faction"] in ("Alliance", "Horde") else None,
                               "start": spot(quest["startMap"]) or spot(journal.QUEST_START_MAPS[qid]),
                               "finish": spot(quest["turninMap"]), "rewards": rewards})
            record["quests"] = sorted(quests, key=lambda q: q["id"])

            atlas_key = ATLAS_KEYS.get(variant) or atlas_names.get(normal(variant)) or atlas_names.get(normal(record["name"]))
            atlas_location = atlas[atlas_key] if atlas_key else None
            if atlas_location is not None:
                record["area"] = atlas_location["MapID"]
            record["lootKey"] = atlas_key or variant
            loot = atlas_loot(atlas_location, source)
            if len(variants) > 1:
                other_key = "Stratholme: Undead" if index == 1 else "Stratholme: Living"
                own = {normal(boss["name"]) for boss in sequence(jd and jd["bosses"])}
                other = {normal(boss["name"]) for boss in sequence(journal.DB[other_key]["bosses"])}
                loot = {name: data for name, data in loot.items() if normal(name) not in other - own}
            for boss in sequence(jd and jd["bosses"]):
                if boss["recipeTab"] or boss["childOf"] or not isinstance(boss["name"], str):
                    continue
                name = boss["name"]
                items = [entry[1] for entry in sequence(boss["loot"])
                         if lua_type(entry) == "table" and isinstance(entry[1], int) and entry[1] > 0]
                if not items:
                    continue
                match = next((row for label, row in loot.items() if normal(label) == normal(name)), None)
                match = match or loot.setdefault(name, {"name": name, "npcs": integers(boss["npcID"]), "items": []})
                existing = {item[0] for item in match["items"]}
                match["items"].extend([item, 0, boss["factionOnly"]] for item in sorted(set(items) - existing))
            record["loot"] = []
            for boss in sorted(loot.values(), key=lambda row: row["name"]):
                boss["items"].sort(key=lambda item: item[0])
                record["loot"].append(boss)
            by_name = {normal(name): boss for name, boss in loot.items()}
            by_npc = {npc: boss for boss in record["loot"] for npc in boss["npcs"]}
            journal_bosses = {}
            for boss in sequence(jd and jd["bosses"]):
                for name in [boss["name"], *sequence(boss["aliases"])]:
                    if isinstance(name, str):
                        journal_bosses[normal(name)] = boss
            for stop in record["stops"]:
                key_name = normal(stop["name"])
                journal_boss = journal_bosses.get(key_name)
                boss = by_name.get(key_name)
                if boss is None and journal_boss is not None:
                    boss = by_name.get(normal(journal_boss["name"]))
                npcs = integers(journal_boss["npcID"]) if journal_boss is not None else []
                if boss is None:
                    boss = next((by_npc[npc] for npc in npcs if npc in by_npc), None)
                if boss:
                    stop["loot"] = boss["name"]
                npcs.extend(boss["npcs"] if boss else [])
                display = next((journal.STATIC_DISPLAY_IDS[npc] for npc in npcs if journal.STATIC_DISPLAY_IDS[npc]), None)
                if display:
                    stop["display"] = display
            dungeons.append(record)

    # These AtlasLoot raid entries have no published route with the installed Routes data.
    for key, name, de in (
        ("MountHyjal", "Mount Hyjal", "Hyjal"),
        ("BarrowDeepsRaid", "Barrow Deeps", "Hügelgrabtiefen"),
        ("OnyxiasLairNew", "Onyxia's Lair (Forever)", "Onyxias Hort (Forever)"),
    ):
        location = atlas[key]
        loot = atlas_loot(location, source)
        if loot:
            dungeons.append({"key": key, "name": name, "de": de, "id": location["InstanceID"],
                             "area": location["MapID"], "lootKey": key, "raid": True,
                             "floors": [], "levels": [], "paths": [], "stops": [], "quests": [],
                             "loot": sorted(loot.values(), key=lambda row: row["name"])})

    notice = contents(addons / "ForeverDungeonRoutes" / "LICENSE.txt").strip()
    doors = {instance: {"map": source["map"], "w": source["w"], "h": source["h"],
                        "portals": [[door["key"], door["x"], door["y"]] for door in sequence(source)]}
             for instance, source in sorted(routes.WingPortals.items())}
    lines = ["-- Generated by tools/build_instance_data.py. See INSTANCE_DATA.md.",
             "-- Route data derived from Forever Dungeon Routes.",
             "--[=[", notice, "]=]",
             "local _, app = ...", "app.instanceData = {", "    doors = " + serialize(doors) + ",", "    floors = {"]
    for floor, info in sorted(floors.items()):
        lines.append(f"        [{floor}] = {serialize(info)},")
    lines += ["    },", "    dungeons = {"]
    for dungeon in dungeons:
        lines.append("        {")
        for key, value in dungeon.items():
            if key in ("paths", "stops", "rooms", "quests", "loot"):
                lines.append(f"            {key} = {{")
                lines.extend(f"                {serialize(entry)}," for entry in value)
                lines.append("            },")
            else:
                lines.append(f"            {key} = {serialize(value)},")
        lines.append("        },")
    lines += ["    },", "}", ""]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f'{len(dungeons)} entries, {len(floors)} floors, {sum(len(d["quests"]) for d in dungeons)} quest links, '
          f'{sum(len(b["items"]) for d in dungeons for b in d["loot"])} loot entries.')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("addons", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "Modules/Instances/Data.lua")
    args = parser.parse_args()
    run(args.addons, args.output)
