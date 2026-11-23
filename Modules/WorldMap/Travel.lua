local _, app = ...
local map, read = C_Map, app.ReadGameValue
local options, plain = app.comfort, app.Readable
local world = {}
app.worldMap = world

local mapType = Enum and Enum.UIMapType or { World = 1, Continent = 2, Zone = 3, Dungeon = 4 }
world.types = mapType
local factions = Enum and Enum.FlightPathFaction or { Neutral = 0, Horde = 1, Alliance = 2 }

-- Fallback locations for Forever's harbor portals. Object IDs in the client:
-- 716523–716529. The destination's name is read from the destination map.
local portals = {
    [1411] = { { 0.509, 0.135, 1458, "Horde" }, { 0.506, 0.135, 1434, "Horde", "Grom’gol" } },
    [1420] = { { 0.609, 0.589, 1454, "Horde" } },
    [1437] = { { 0.053, 0.570, 1424, "Alliance" }, { 0.056, 0.632, 1445, "Alliance" } },
    [1439] = { { 0.310, 0.411, 1453, "Alliance" } },
    [1445] = { { 0.715, 0.555, 1437, "Alliance" } },
}

-- Stable harbor and station locations in the old-world maps.
local transit = {
    [1411] = { { 0.51, 0.14, 1420, "Horde", "Zeppelin" }, { 0.50, 0.14, 1434, "Horde", "Zeppelin" } },
    [1420] = { { 0.61, 0.59, 1411, "Horde", "Zeppelin" }, { 0.61, 0.61, 1434, "Horde", "Zeppelin" } },
    [1434] = { { 0.315, 0.294, 1411, "Horde", "Zeppelin" }, { 0.315, 0.298, 1420, "Horde", "Zeppelin" },
        { 0.266, 0.738, 1413, nil, "Boot" } },
    [1413] = { { 0.637, 0.393, 1434, nil, "Boot" } },
    [1437] = { { 0.047, 0.638, 1445, "Alliance", "Boot" }, { 0.044, 0.568, 1439, "Alliance", "Boot" } },
    [1439] = { { 0.323, 0.441, 1437, "Alliance", "Boot" }, { 0.31, 0.412, 1438, "Alliance", "Boot" } },
    [1438] = { { 0.550, 0.937, 1439, "Alliance", "Boot" } },
    [1445] = { { 0.717, 0.567, 1437, "Alliance", "Boot" } },
    [1453] = { { 0.662, 0.341, 1455, "Alliance", "Bahn" } },
    [1455] = { { 0.768, 0.514, 1453, "Alliance", "Bahn" } },
}

world.levels = {
    [1411] = {1, 10}, [1412] = {1, 10}, [1413] = {10, 25}, [1416] = {30, 40}, [1417] = {30, 40},
    [1418] = {35, 45}, [1419] = {45, 55}, [1420] = {1, 10}, [1421] = {10, 20}, [1422] = {50, 60},
    [1423] = {55, 60}, [1424] = {20, 30}, [1425] = {40, 50}, [1426] = {1, 10}, [1427] = {43, 50},
    [1428] = {50, 60}, [1429] = {1, 10}, [1430] = {55, 60}, [1431] = {18, 30}, [1432] = {10, 20},
    [1433] = {15, 25}, [1434] = {30, 45}, [1435] = {35, 45}, [1436] = {10, 20}, [1437] = {20, 30},
    [1438] = {1, 10}, [1439] = {10, 20}, [1440] = {18, 30}, [1441] = {25, 35}, [1442] = {15, 27},
    [1443] = {30, 40}, [1444] = {40, 50}, [1445] = {35, 45}, [1446] = {40, 50}, [1447] = {45, 55},
    [1448] = {48, 55}, [1449] = {48, 55}, [1451] = {55, 60}, [1452] = {55, 60}, [2521] = {1, 10},
}

-- Classic open-water fishing ranges are advisory. Individual pools can differ.
world.fishing = {
    [1411] = 1, [1412] = 1, [1413] = 75, [1416] = 150, [1417] = 150, [1418] = 175,
    [1419] = 175, [1420] = 1, [1421] = 75, [1422] = 250, [1423] = 265, [1424] = 100,
    [1425] = 200, [1426] = 1, [1427] = 200, [1428] = 250, [1429] = 1, [1431] = 95,
    [1432] = 55, [1433] = 80, [1434] = 130, [1435] = 175, [1436] = 55, [1437] = 105,
    [1438] = 1, [1439] = 55, [1440] = 95, [1441] = 130, [1442] = 75, [1443] = 150,
    [1444] = 150, [1445] = 150, [1446] = 225, [1447] = 200, [1448] = 175, [1449] = 225,
    [1450] = 205, [1451] = 250, [1452] = 250,
}

local function list(api, ...)
    local value = read(api, ...)
    return type(value) == "table" and value or {}
end

function world.Info(id)
    return map and type(id) == "number" and id > 0 and read(map.GetMapInfo, id) or nil
end

function world.Vector(point)
    if not point then return end
    if point.GetXY then return read(point.GetXY, point) end
    return plain(point.x), plain(point.y)
end

function world.Name(id, fallback)
    local info = world.Info(id)
    return info and plain(info.name) or fallback
end

function world.JumpContext(id)
    local node, continent, root = id
    for _ = 1, 12 do
        local info = world.Info(node)
        if not info then break end
        local kind, parent = plain(info.mapType), plain(info.parentMapID)
        if kind == mapType.Continent then continent = node end
        if kind == mapType.World then root = node end
        if not parent or parent == node or parent == 0 then break end
        node = parent
    end
    return continent, root or 947
end

function world.Children(id, kind, recurse)
    local result = {}
    for _, value in ipairs(list(map and map.GetMapChildrenInfo, id, kind, recurse)) do
        local child = plain(value)
        local childID, name = child and plain(child.mapID), child and plain(child.name)
        if type(childID) == "number" and childID ~= id and type(name) == "string" and name ~= "" then
            result[#result + 1] = { id = childID, name = name }
        end
    end
    table.sort(result, function(a, b) return a.name == b.name and a.id < b.id or a.name < b.name end)
    return result
end

local function collectSources(id)
    local info = world.Info(id)
    local maps = { id }
    if info and plain(info.mapType) == mapType.Continent then
        for _, child in ipairs(world.Children(id, mapType.Zone, true)) do maps[#maps + 1] = child.id end
    end
    return maps
end

function world.PoiKind(atlas)
    if type(atlas) ~= "string" then return end
    atlas = atlas:lower()
    if atlas:find("portal", 1, true) then return "portal" end
    if atlas:find("zeppelin", 1, true) or atlas:find("boat", 1, true) or atlas:find("tram", 1, true)
        or atlas:find("transport", 1, true) then return "transport" end
    if atlas:find("graveyard", 1, true) or atlas:find("spirithealer", 1, true) then return "healer" end
end

local function nameAndPosition(record)
    return plain(record.name), world.Vector(plain(record.position))
end

function world.Collect(id)
    local points = {}
    if not map or not world.Info(id) then return points end
    local faction = read(UnitFactionGroup, "player")
    local showOpposing = options.Enabled("mapOtherFaction")
    local function allowed(owner)
        return showOpposing or not owner or not faction or owner == faction
    end
    local function add(kind, source, x, y, name, target, note, atlas)
        if not app.ValidMapPoint(x, y) then return end
        x, y = app.ProjectMapPoint(source, id, x, y)
        if not x then return end
        for _, other in ipairs(points) do
            if other.kind == kind and (other.name == name or target and other.target == target)
                and math.abs(other.x - x) < 0.012 and math.abs(other.y - y) < 0.012 then return end
        end
        points[#points + 1] = { kind = kind, x = x, y = y, name = name, target = target, note = note, atlas = atlas }
    end

    local showFlight = options.Enabled("mapFlight")
    local showPortal = options.Enabled("mapPortals")
    local showCross = options.Enabled("mapCrossings")
    local showTransport = options.Enabled("mapTransport")
    local showHealer = options.Enabled("mapSpiritHealers")
    local showDungeon = options.Enabled("mapDungeons")
    local savedCrossings = app.Settings().mapCrossings
    local crossings = options.Enabled("mapLearnCrossings") and type(savedCrossings) == "table" and savedCrossings
    local sources = collectSources(id)
    for _, source in ipairs(sources) do
        if showFlight then
            for _, raw in ipairs(list(C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap, source)) do
                local node = plain(raw)
                if node then
                    local owner = plain(node.faction)
                    owner = owner == factions.Alliance and "Alliance" or owner == factions.Horde and "Horde" or nil
                    if allowed(owner) then
                        local name, x, y = nameAndPosition(node)
                        local note = plain(node.isUndiscovered) == true and app.L("Noch nicht entdeckt") or nil
                        add("flight", source, x, y, name, nil, note, plain(node.atlasName))
                    end
                end
            end
        end
        if showPortal or showCross then
            for _, raw in ipairs(list(map.GetMapLinksForMap, source)) do
                local link = plain(raw)
                if link then
                    local atlas = plain(link.atlasName)
                    local target = plain(link.linkedUiMapID)
                    local kind = world.PoiKind(atlas)
                    local info = world.Info(target)
                    if (kind == "portal" and showPortal)
                        or (not kind and showCross and target ~= source and info and plain(info.mapType) == mapType.Zone) then
                        local name, x, y = nameAndPosition(link)
                        add(kind or "cross", source, x, y, name or world.Name(target), target, nil, atlas)
                    end
                end
            end
        end
        if showPortal or showTransport or showHealer then
            for _, poiID in ipairs(list(C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap, source)) do
                local poi = read(C_AreaPoiInfo.GetAreaPOIInfo, source, plain(poiID))
                if poi then
                    local atlas, owner = plain(poi.atlasName), plain(poi.factionID)
                    local kind = world.PoiKind(atlas)
                    owner = owner == 469 and "Alliance" or owner == 67 and "Horde" or nil
                    if allowed(owner) and ((kind == "portal" and showPortal) or (kind == "transport" and showTransport)
                        or (kind == "healer" and showHealer)) then
                        local name, x, y = nameAndPosition(poi)
                        add(kind, source, x, y, name, plain(poi.linkedUiMapID), plain(poi.description), atlas)
                    end
                end
            end
        end
        if showPortal then
            for _, node in ipairs(portals[source] or {}) do
                if allowed(node[4]) then
                    add("portal", source, node[1], node[2], node[5] or world.Name(node[3]), node[3], app.L("Verfügbarkeit kann von Quests abhängen."))
                end
            end
        end
        if showTransport then
            for _, node in ipairs(transit[source] or {}) do
                if allowed(node[4]) then
                    add("transport", source, node[1], node[2], world.Name(node[3]), node[3], app.L(node[5]))
                end
            end
        end
        if showCross then
            for _, entry in ipairs(app.mapRoadLandmarks[source] or {}) do
                local target = entry[3]
                add("cross", source, entry[1], entry[2], world.Name(target), target, app.L("Wegpunkt nahe dem Übergang"))
            end
        end
        if showCross and crossings and type(crossings[source]) == "table" then
            for _, entry in ipairs(crossings[source]) do
                if type(entry) == "table" then
                    local target = entry[3]
                    local name = world.Name(target)
                    if name then add("cross", source, entry[1], entry[2], name, target, app.L("Beim Gebietswechsel gemessen")) end
                end
            end
        end
        if showHealer then
            for _, raw in ipairs(list(C_DeathInfo and C_DeathInfo.GetGraveyardsForMap, source)) do
                local grave = plain(raw)
                if grave then
                    local name, x, y = nameAndPosition(grave)
                    add("healer", source, x, y, name or app.L("Geistheiler"))
                end
            end
        end
        if showDungeon then
            local entrances = list(C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap, source)
            for _, raw in ipairs(entrances) do
                local dungeon = plain(raw)
                if dungeon then
                    local name, x, y = nameAndPosition(dungeon)
                    add("dungeon", source, x, y, name, nil, plain(dungeon.description), plain(dungeon.atlasName))
                end
            end
            if #entrances == 0 then
                for _, entry in ipairs(app.mapDungeonLandmarks[source] or {}) do
                    add("dungeon", source, entry[1], entry[2], app.L(entry[3]))
                end
            end
        end
    end
    return points
end

local last
local function sampleCrossing()
    if not map or not CreateVector2D or read(InCombatLockdown) or read(UnitOnTaxi, "player")
        or read(IsFlying) or read(UnitOnTransport, "player") or read(IsInInstance) then
        last = nil
        return
    end
    local id = read(map.GetBestMapForUnit, "player")
    local info = world.Info(id)
    if not info or plain(info.mapType) ~= mapType.Zone then last = nil; return end
    local x, y = world.Vector(read(map.GetPlayerMapPosition, id, "player"))
    if not app.ValidMapPoint(x, y) then last = nil; return end
    local continent, pos = read(map.GetWorldPosFromMapPos, id, CreateVector2D(x, y))
    local wx, wy = world.Vector(pos)
    if type(continent) ~= "number" or type(wx) ~= "number" or type(wy) ~= "number" then last = nil; return end
    local now = GetTime()
    local previous = last
    last = { id = id, x = x, y = y, worldX = wx, worldY = wy, continent = continent, at = now }
    if not previous or previous.id == id or previous.continent ~= continent or now - previous.at > 2.2 then return end
    if (previous.worldX - wx) ^ 2 + (previous.worldY - wy) ^ 2 > 150 ^ 2 then return end
    local settings = app.Settings()
    if type(settings.mapCrossings) ~= "table" then settings.mapCrossings = {} end
    local function remember(from, to)
        local entries = settings.mapCrossings[from.id]
        if type(entries) ~= "table" then entries = {}; settings.mapCrossings[from.id] = entries end
        for _, point in ipairs(entries) do
            if type(point) == "table" and app.ValidMapPoint(point[1], point[2]) and to.id == point[3]
                and math.abs(from.x - point[1]) <= 0.015 and math.abs(from.y - point[2]) <= 0.015 then return end
        end
        if #entries >= 36 then table.remove(entries, 1) end
        entries[#entries + 1] = { from.x, from.y, to.id }
    end
    remember(previous, last)
    remember(last, previous)
    if world.Refresh then world.Refresh() end
end

local ticker
function world.UpdateCrossings()
    if options.Enabled("mapCrossings") and options.Enabled("mapLearnCrossings") then
        if not ticker and C_Timer and C_Timer.NewTicker then
            ticker = C_Timer.NewTicker(0.65, sampleCrossing)
        end
    elseif ticker then
        ticker:Cancel()
        ticker, last = nil, nil
    end
end
