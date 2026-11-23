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
