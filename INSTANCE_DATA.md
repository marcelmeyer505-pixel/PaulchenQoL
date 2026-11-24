# Instance data

Paulchen's **Instances** view reads `Modules/Instances/Data.lua` at runtime. The installed addon needs no separate instance addon for the guide, route viewer, quest list, loot tables or upgrade source index. The generator is a development tool.

- The route geometry, boss stops, floor metadata, world-to-floor coordinates, named room footprints, entrance coordinates and wing-door detection are adapted from [Forever Dungeon Routes](https://github.com/Checkov23/ForeverDungeonRoutes), installed version 1.3.9. The generator selects the route for each Stratholme wing and includes both Maraudon approaches. The generated Lua file carries Checkov23's copyright and MIT notice.
- Map imagery is drawn by reference to numeric file IDs already in the WoW client. Paulchen includes no copied BLP tiles or illustrated dungeon maps. If a client cannot draw the available references, the route view still draws its paths and boss stops.
- The loot index contains game names, NPC and item IDs, and reported drop percentages from the installed Forever [AtlasLoot](https://www.curseforge.com/wow/addons/atlasloot-forever) data and known [DungeonJournal](https://www.curseforge.com/wow/addons/dungeonjournal) records. DungeonJournal NPC and display IDs link route stops to boss loot and client-rendered portraits. Quest entries use game quest and reward IDs, faction, minimum level and known waypoint coordinates. The generator does not include their program code, authored guides, quest prose or art in Paulchen.
- The information reflects the local source versions at generation. Client quest state and item tooltips come from the game at runtime. The existing Upgrades content filter determines whether sources are included in upgrade searches.

Regenerate from supported installed data with Python and `lupa`:

```powershell
python tools/build_instance_data.py 'C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns'
```

Source versions in this snapshot are Forever Dungeon Routes 1.3.9, DungeonJournal 2.1.4 and AtlasLoot Forever 1.4.8. This notice covers the imported material and assigns no license to Paulchen QoL.
