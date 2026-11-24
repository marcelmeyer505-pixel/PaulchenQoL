# Bundled dungeon quest reference data — source and limits

The following bundled Lua files are adapted from **Dungeon Quest Atlas v1.04** by Pirson,
released with the **MIT license at that historical tag**:

- `Data/DungeonSeedDungeons.lua` ← `Data/Dungeons.lua`
- `Data/DungeonSeedQuests.lua` ← `Data/Quests.lua`
- `Data/DungeonSeedPlaces.lua` ← `Data/Places.lua`

Original files: https://github.com/Pirson-s-Addons/DungeonQuestAtlas/tree/v1.04/Data

License: MIT (historical snapshot), retained in `Data/LICENSE-DQA-MIT.txt`.
Copyright (c) 2025–2026 Pirson.

Only the namespace wrapper and comments were changed so the data load inside
Paulchen's private `app.dungeonQuestSeed`. No Dungeon Quest Atlas runtime code,
fonts, UI art, textures, or current post-v1.04 data were copied.

**Important:** The author's *current* release is no longer MIT-licensed.
This bundle uses **v1.04 only**, which remains covered by its originally
granted MIT license. Never automatically update from newer unlicensed
versions or copy current data into these files.

Polestar's source code, data packs and GPL-licensed `forever-db`
were **not imported**. The optional Polestar integration elsewhere in
Paulchen is unrelated to the standalone quest planner.

Dataset characteristics:
- 35 dungeon / wing entries, 395 dungeon-to-quest references (some
  quests occur in multiple wings), 480 seed quest records and 309
  giver/location records.
- Historical data date: **October 2026**. Some Forever-only dungeons
  have *zero* quest records in this source.
- This dataset is not an authoritative full-coverage server quest API.
  Blizzard/Forever data and quest names belong to their respective
  rights holders. Quest titles use WoW's installed client data when possible.
- This package supplies starting points and chain associations as reference
  facts; a quest's actual completion is checked only by supported game APIs.
  Missing records, protected values and unpublished quest progression remain
  unknown, never inferred to be complete.

Paulchen's own code for interpreting these records, its UI, quest status,
navigation and caching was separately developed.
