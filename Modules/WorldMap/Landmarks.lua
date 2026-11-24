-- Selected road approaches and dungeon landmarks from Forever AreaPOI and UiMapAssignment.
-- Coordinates are projected from the game world into the source zone.
local _, app = ...
app.mapRoadLandmarks = {
    [1429] = { { 0.2501, 0.7242, 1436 } },
    [1430] = { { 0.4031, 0.4232, 1431 } },
    [1431] = { { 0.8786, 0.3517, 1430 } },
    [1437] = { { 0.5506, 0.9687, 1432 }, { 0.4742, 0.1677, 1417 } }, -- Algaz Station and Dun Modr
    [1440] = { { 0.3948, 0.8172, 1442 } },
    [1442] = { { 0.8147, 0.3029, 1440 } },
    [1444] = { { 0.8951, 0.4626, 1441 } },
    [1445] = { { 0.2972, 0.4829, 1413 } },
    [1447] = { { 0.1168, 0.7790, 1440 } },
    [1448] = { { 0.6503, 0.0823, 1452 } },
    [1452] = { { 0.2791, 0.3449, 1448 } },
}
app.mapDungeonLandmarks = {
    [1413] = { { 0.4599, 0.3627, "Höhlen des Wehklagens", "Wailing Caverns" } },
    [1418] = { { 0.4423, 0.1221, "Uldaman", "Uldaman" } },
    [1422] = { { 0.6968, 0.7341, "Scholomance", "Scholomance" } },
    [1435] = { { 0.7000, 0.5291, "Tempel von Atal’Hakkar", "Sunken Temple" } },
    [1443] = { { 0.2925, 0.6253, "Maraudon", "Maraudon" } },
    [1445] = { { 0.5230, 0.7614, "Onyxias Hort", "Onyxia's Lair" } },
}

-- Outdoor flight points from TaxiNodes and UiMapAssignment (Forever 1.60.1.70959).
-- Entry: node ID, normalized x/y, FlightPathFaction, English and German client names.
-- Special PvP and class-only routes remain live API entries.
app.mapFlightLandmarks = {
    [1411] = {
        { 23, 0.44505, 0.03709, 1, "Orgrimmar, Durotar", "Orgrimmar, Durotar" },
    },
    [1412] = {
        { 22, 0.39802, 0.35686, 1, "Thunder Bluff, Mulgore", "Thunder Bluff, Mulgore" },
    },
    [1413] = {
        { 25, 0.51503, 0.30406, 1, "Crossroads, The Barrens", "Crossroads, Brachland" },
        { 77, 0.44463, 0.59103, 1, "Camp Taurajo, The Barrens", "Camp Taurajo, Brachland" },
        { 80, 0.63118, 0.37108, 0, "Ratchet, The Barrens", "Ratchet, Brachland" },
    },
    [1417] = {
        { 16, 0.45790, 0.46133, 2, "Refuge Pointe, Arathi", "Die Zuflucht, Arathi" },
        { 17, 0.73062, 0.32623, 1, "Hammerfall, Arathi", "Hammerfall, Arathi" },
    },
    [1418] = {
        { 21, 0.04056, 0.44889, 1, "Kargath, Badlands", "Kargath, Ödland" },
    },
    [1419] = {
        { 45, 0.65495, 0.24429, 2, "Nethergarde Keep, Blasted Lands", "Burg Nethergarde, Verwüstete Lande" },
    },
    [1420] = {
        { 11, 0.61198, 0.75316, 1, "Undercity, Tirisfal", "Undercity, Tirisfal" },
    },
    [1421] = {
        { 10, 0.45557, 0.42422, 1, "The Sepulcher, Silverpine Forest", "Das Grabmal, Silberwald" },
    },
    [1422] = {
        { 66, 0.42948, 0.84954, 2, "Chillwind Camp, Western Plaguelands", "Chillwind-Lager, westliche Pestländer" },
    },
    [1423] = {
        { 67, 0.71699, 0.49555, 2, "Light's Hope Chapel, Eastern Plaguelands", "Kapelle des hoffnungsvollen Lichts, östliche Pestländer" },
        { 68, 0.70446, 0.47590, 1, "Light's Hope Chapel, Eastern Plaguelands", "Kapelle des hoffnungsvollen Lichts, östliche Pestländer" },
    },
    [1424] = {
        { 13, 0.60206, 0.18753, 1, "Tarren Mill, Hillsbrad", "Tarrens Mühle, Hillsbrad" },
        { 14, 0.49442, 0.52101, 2, "Southshore, Hillsbrad", "Southshore, Hillsbrad" },
    },
    [1425] = {
        { 43, 0.11111, 0.46088, 2, "Aerie Peak, The Hinterlands", "Aerie Peak, Hinterland" },
        { 76, 0.81701, 0.81893, 1, "Revantusk Village, The Hinterlands", "Revantusk, Hinterland" },
    },
    [1426] = {
        { 6, 0.60051, 0.28772, 2, "Ironforge, Dun Morogh", "Ironforge, Dun Morogh" },
    },
    [1427] = {
        { 74, 0.37887, 0.30426, 2, "Thorium Point, Searing Gorge", "Thoriumspitze, sengende Schlucht" },
        { 75, 0.34830, 0.30584, 1, "Thorium Point, Searing Gorge", "Thoriumspitze, sengende Schlucht" },
    },
    [1428] = {
        { 70, 0.65577, 0.24219, 1, "Flame Crest, Burning Steppes", "Flammenkamm, brennende Steppe" },
        { 71, 0.84382, 0.68304, 2, "Morgan's Vigil, Burning Steppes", "Morgans Wacht, brennende Steppe" },
    },
    [1429] = {
        { 2, 0.30448, 0.38590, 2, "Stormwind, Elwynn", "Stormwind, Elwynn" },
    },
    [1431] = {
        { 12, 0.77592, 0.44377, 2, "Darkshire, Duskwood", "Dunkelhain, Dämmerwald" },
    },
    [1432] = {
        { 8, 0.33943, 0.50795, 2, "Thelsamar, Loch Modan", "Thelsamar, Loch Modan" },
    },
    [1433] = {
        { 5, 0.25343, 0.58988, 2, "Lakeshire, Redridge", "Seenhain, Rotkammgebirge" },
    },
    [1434] = {
        { 18, 0.26816, 0.76996, 1, "Booty Bay, Stranglethorn", "Booty Bay, Schlingendorntal" },
        { 19, 0.27529, 0.77672, 2, "Booty Bay, Stranglethorn", "Booty Bay, Schlingendorntal" },
        { 20, 0.32510, 0.29276, 1, "Grom'gol, Stranglethorn", "Grom'gol, Schlingendorntal" },
    },
    [1435] = {
        { 56, 0.46053, 0.54679, 1, "Stonard, Swamp of Sorrows", "Stonard, Sümpfe des Elends" },
    },
    [1436] = {
        { 4, 0.56571, 0.52667, 2, "Sentinel Hill, Westfall", "Späherkuppe, Westfall" },
    },
    [1437] = {
        { 7, 0.09520, 0.59659, 2, "Menethil Harbor, Wetlands", "Hafen von Menethil, Sumpfland" },
    },
    [1438] = {
        { 27, 0.58400, 0.93927, 2, "Rut'theran Village, Teldrassil", "Rut'theran, Teldrassil" },
    },
    [1439] = {
        { 26, 0.36397, 0.45617, 2, "Auberdine, Darkshore", "Auberdine, Dunkelküste" },
    },
    [1440] = {
        { 28, 0.34495, 0.48015, 2, "Astranaar, Ashenvale", "Astranaar, Ashenvale" },
        { 58, 0.12191, 0.33774, 1, "Zoram'gar Outpost, Ashenvale", "Zoram'gar-Außenposten, Ashenvale" },
        { 61, 0.73258, 0.61672, 1, "Splintertree Post, Ashenvale", "Splintertreeposten, Ashenvale" },
    },
    [1441] = {
        { 30, 0.45022, 0.49126, 1, "Freewind Post, Thousand Needles", "Freiwindposten, Tausend Nadeln" },
    },
    [1442] = {
        { 29, 0.45164, 0.59888, 1, "Sun Rock Retreat, Stonetalon Mountains", "Sonnenfels, Steinkrallengebirge" },
        { 33, 0.36536, 0.07233, 2, "Stonetalon Peak, Stonetalon Mountains", "Steinkrallengipfel, Steinkrallengebirge" },
    },
    [1443] = {
        { 37, 0.64671, 0.10435, 2, "Nijel's Point, Desolace", "Die Nijelspitze, Desolace" },
        { 38, 0.21563, 0.74042, 1, "Shadowprey Village, Desolace", "Shadowprey, Desolace" },
    },
    [1444] = {
        { 31, 0.89461, 0.45868, 2, "Thalanaar, Feralas", "Thalanaar, Feralas" },
        { 41, 0.30259, 0.43319, 2, "Feathermoon, Feralas", "Feathermoon, Feralas" },
        { 42, 0.75430, 0.44314, 1, "Camp Mojache, Feralas", "Camp Mojache, Feralas" },
    },
    [1445] = {
        { 32, 0.67459, 0.51201, 2, "Theramore, Dustwallow Marsh", "Theramore, Marschen von Dustwallow" },
        { 55, 0.35565, 0.31830, 1, "Brackenwall Village, Dustwallow Marsh", "Brackenwall, Marschen von Dustwallow" },
    },
    [1446] = {
        { 39, 0.50954, 0.29325, 2, "Gadgetzan, Tanaris", "Gadgetzan, Tanaris" },
        { 40, 0.51618, 0.25519, 1, "Gadgetzan, Tanaris", "Gadgetzan, Tanaris" },
    },
    [1447] = {
        { 44, 0.21955, 0.49690, 1, "Valormok, Azshara", "Valormok, Azshara" },
        { 64, 0.11903, 0.77477, 2, "Talrendis Point, Azshara", "Talrendisspitze, Azshara" },
    },
    [1448] = {
        { 48, 0.34415, 0.53868, 1, "Bloodvenom Post, Felwood", "Blutgiftposten, Teufelswald" },
        { 65, 0.62457, 0.24194, 2, "Talonbranch Glade, Felwood", "Nachtlaublichtung, Teufelswald" },
    },
    [1449] = {
        { 79, 0.45298, 0.05966, 0, "Marshal's Refuge, Un'Goro Crater", "Marshals Zuflucht, Un'Goro-Krater" },
    },
    [1450] = {
        { 49, 0.47912, 0.67110, 2, "Moonglade", "Moonglade" },
        { 69, 0.32150, 0.66335, 1, "Moonglade", "Moonglade" },
    },
    [1451] = {
        { 72, 0.48826, 0.36724, 1, "Cenarion Hold, Silithus", "Burg Cenarius, Silithus" },
        { 73, 0.50683, 0.34590, 2, "Cenarion Hold, Silithus", "Burg Cenarius, Silithus" },
    },
    [1452] = {
        { 52, 0.62335, 0.36636, 2, "Everlook, Winterspring", "Everlook, Winterspring" },
        { 53, 0.60485, 0.36344, 1, "Everlook, Winterspring", "Everlook, Winterspring" },
    },
    [1453] = {
        { 2, 0.71614, 0.72253, 2, "Stormwind, Elwynn", "Stormwind, Elwynn" },
    },
    [1454] = {
        { 23, 0.45281, 0.63746, 1, "Orgrimmar, Durotar", "Orgrimmar, Durotar" },
    },
    [1455] = {
        { 6, 0.55886, 0.47865, 2, "Ironforge, Dun Morogh", "Ironforge, Dun Morogh" },
    },
    [1456] = {
        { 22, 0.46655, 0.49898, 1, "Thunder Bluff, Mulgore", "Thunder Bluff, Mulgore" },
    },
    [1458] = {
        { 11, 0.63085, 0.48324, 1, "Undercity, Tirisfal", "Undercity, Tirisfal" },
    },
    [2482] = {
        { 559, 0.68639, 0.44111, 0, "Summit of Eternity, Mount Hyjal", "Gipfel der Ewigkeit, Hyjal" },
        { 3242, 0.55096, 0.82548, 0, "Tainted Foothills, Mount Hyjal", "Besudeltes Vorgebirge, Hyjal" },
    },
    [2548] = {
        { 3203, 0.59614, 0.45064, 1, "Rog'mar, Riverglades", "Rog'mar, Flusslande" },
        { 3276, 0.60594, 0.81570, 2, "Farholde Keep, Riverglades", "Burg Farholde, Flusslande" },
    },
}
