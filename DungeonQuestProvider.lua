local _, app = ...
-- Independent dungeon quest provider, backed by the bundled MIT-licensed
-- Dungeon Quest Atlas v1.04 reference data. No dependency on Polestar/DQA.
local provider = {}
app.DungeonQuestData = provider

local function sources() return app.dungeonQuestSeed or {} end
local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and (not app.Readable or app.Readable(value) ~= nil) then return value end
end

local index
local function dungeonByKey(key)
    if not index then
        index = {}
        for _, d in ipairs(sources().dungeons or {}) do index[d.key] = d end
    end
    return index[key]
end

function provider.Load()
    local s = sources()
    return type(s.dungeons) == "table" and type(s.quests) == "table" and type(s.places) == "table", "nodata"
end

function provider.List()
    local result = {}
    for _, d in ipairs(sources().dungeons or {}) do
        local count = #(d.quests or {})
        result[#result+1] = {
            key = d.key, name = d.name, minLevel = d.minLevel, maxLevel = d.maxLevel,
            kind = "dungeon", forever = d.isForever, sourceQuestCount = count,
            incomplete = count == 0, instanceID = d.instanceID,
        }
    end
    table.sort(result, function(a, b)
        local al, bl = a.minLevel or 0, b.minLevel or 0
        if al ~= bl then return al < bl end
        return (a.name or "") < (b.name or "")
    end)
    return result
end

local names = {}
local requested = {}
local requestBudget = 0
local function titleOf(id)
    if names[id] then return names[id] end
    local api = C_QuestLog
    local result = safe(api and api.GetTitleForQuestID, id)
        or safe(api and api.GetQuestInfo, id)
    if type(result) == "string" and result ~= "" then
        names[id] = result
        return result
    end
    if not requested[id] and requestBudget < 200 and api and api.RequestLoadQuestByID then
        requested[id] = true
        requestBudget = requestBudget + 1
        pcall(api.RequestLoadQuestByID, id)
    end
    return "Quest #" .. id
end

function provider.QuestTitle(id)
    return titleOf(id)
end

local function place(code)
    if type(code) ~= "string" then return nil end
    local s = sources()
    local p = s.places and s.places[code]
    local kind, rawID = code:match("^([^:]+):(.+)$")
    local id = tonumber(rawID)
    if not p then
        return {kind = kind or "unknown", id = id, name = rawID or code}
    end
    local result = {
        kind = kind == "name" and "object" or kind,
        id = p.npcID or p.objectID or p.itemID or id,
        name = p.name or rawID or code,
        map = p.mapID,
        -- Historical DQA places use map percentages (0..100).
        -- Keep normalized 0..1 even for points below 1% of the zone.
        x = type(p.x) == "number" and p.x / 100 or nil,
        y = type(p.y) == "number" and p.y / 100 or nil,
        inside = p.inside == true,
        under = p.under == true,
    }
    local hint = app.dungeonQuestLocationHints and app.dungeonQuestLocationHints[code]
    if hint and not result.map and type(hint.map) == "number"
        and type(hint.x) == "number" and type(hint.y) == "number" then
        result.map, result.x, result.y = hint.map, hint.x, hint.y
        result.referenceOnly = hint.referenceOnly == true
    end
    return result
end

local function places(list)
    local all = {}
    for _, code in ipairs(list or {}) do
        local p = place(code)
        if p then all[#all + 1] = p end
    end
    return all
end

-- Character-local sightings: the player's position while actually speaking
-- with a known quest giver/turn-in NPC. These are never treated as confirmed
-- locations for all players or uploaded elsewhere.
local function observations()
    local db = app.Settings and app.Settings() or PaulchenQoLDB
    if type(db) ~= "table" then return nil end
    if type(db.dungeonQuestLocations) ~= "table" then db.dungeonQuestLocations = {} end
    return db.dungeonQuestLocations
end

local function applySighting(points, sighting)
    if type(sighting) ~= "table" or sighting.kind ~= "npc"
        or type(sighting.map) ~= "number" or type(sighting.x) ~= "number"
        or type(sighting.y) ~= "number" then return false end
    local found = false
    for _, point in ipairs(points) do
        if point.kind == "npc" and
            (point.id == sighting.id or (not point.id and point.name == sighting.name)) then
            -- Reference coordinates remain the default if already known. Only
            -- enrich unknown places; preserve source precision and provenance.
            if not point.map or point.x == nil or point.y == nil or point.referenceOnly then
                point.map, point.x, point.y = sighting.map, sighting.x, sighting.y
                point.observed = true
                point.referenceOnly = false
            end
            found = true
        end
    end
    if not found and #points == 0 then
        points[1] = { kind = "npc", id = sighting.id, name = sighting.name,
            map = sighting.map, x = sighting.x, y = sighting.y, observed = true }
    end
    return true
end

local function sightingFor(id, role)
    local list = observations()
    local entry = list and list[id]
    return type(entry) == "table" and entry[role] or nil
end

function provider.RecordSighting(id, role, npcID, npcName, map, x, y)
    if type(id) ~= "number" or id < 1 or (role ~= "giver" and role ~= "ender")
        or type(npcID) ~= "number" or type(map) ~= "number"
        or type(x) ~= "number" or type(y) ~= "number"
        or x < 0 or x > 1 or y < 0 or y > 1 then return false end
    local record = sources().quests and sources().quests[id]
    if type(record) ~= "table" then return false end
    local keys = role == "giver" and record.starts or record.ends
    -- Only learn from an actual dialogue with a matching existing NPC.
    -- The exceptional case of a missing start/end list can be learned too.
    local accepted = type(keys) ~= "table" or #keys == 0
    for _, code in ipairs(keys or {}) do
        if code == "npc:" .. npcID then accepted = true; break end
        local named = sources().places and sources().places[code]
        if named and named.name == npcName and type(npcName) == "string"
            and npcName ~= "" and code:match("^name:") then accepted = true; break end
    end
    if not accepted then return false end
    local list = observations()
    if not list then return false end
    if type(list[id]) ~= "table" then list[id] = {} end
    list[id][role] = { kind = "npc", id = npcID, name = npcName,
        map = map, x = x, y = y }
    return true
end

local function toSide(value)
    return value == "Alliance" and "A" or value == "Horde" and "H" or nil
end
local function factionMatches(value, side)
    return side == nil or value == nil or value == "Both" or value == "AH"
        or value == "Alliance" and side == "A"
        or value == "Horde" and side == "H"
end

local function rawQuest(id)
    return sources().quests and sources().quests[id]
end

local function build(id)
    local q = rawQuest(id) or {}
    local startPoints = places(q.starts)
    local finishPoints = places(q.ends)
    applySighting(startPoints, sightingFor(id, "giver"))
    applySighting(finishPoints, sightingFor(id, "ender"))
    local chain = type(q.chain) == "table" and q.chain or {}
    local result = {
        id = id, title = titleOf(id), faction = toSide(q.faction),
        level = q.level, minLevel = q.minLevel,
        chain = chain, start = startPoints[1], finish = finishPoints[1],
        givers = startPoints, enders = finishPoints,
        classes = q.classes, sourceVerified = q.verified, chainIncomplete = q.chain == true,
        source = "DQA-MIT-1.04",
    }
    if not result.start then result.start = {kind = "unknown", name = "?"} end
    if not result.finish then result.finish = {kind = "unknown", name = "?"} end
    return result
end

function provider.Quests(key, faction)
    local d = dungeonByKey(key)
    if not d then return {} end
    if not factionMatches(d.faction, faction) then return {} end
    local result = {}
    for _, id in ipairs(d.quests or {}) do
        local q = rawQuest(id)
        if not q or factionMatches(q.faction, faction) then result[#result+1] = build(id) end
    end
    return result
end

function provider.Quest(key, id)
    if type(id) ~= "number" then return nil end
    local d = dungeonByKey(key)
    if not d then return nil end
    if rawQuest(id) then return build(id) end
    for _, candidate in ipairs(d.quests or {}) do
        if candidate == id then return build(id) end
    end
    return nil
end

function provider.Prerequisites(id)
    local q = rawQuest(id)
    if not q or type(q.chain) ~= "table" then return nil end
    local prereqs = {}
    for _, candidate in ipairs(q.chain) do
        if candidate == id then break end
        prereqs[#prereqs+1] = candidate
    end
    return prereqs
end

function provider.QuestFor(q)
    if type(q) ~= "table" then return nil end
    local allowed = q.classes
    if type(allowed) == "table" and #allowed > 0 then
        local class
        if type(UnitClass) == "function" then
            local ok, _, token = pcall(UnitClass, "player")
            if ok then class = token end
        end
        local exists = false
        for _, token in ipairs(allowed) do
            if token == class then exists = true; break end
        end
        if not exists and type(class) == "string" then return {classes=allowed}, "class" end
    end
    return nil
end

function provider.GuideToPoint(point)
    if type(point) ~= "table" or not point.map or
        type(point.x) ~= "number" or type(point.y) ~= "number" then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local map, x, y = point.map, point.x, point.y
    if x > 1 or y > 1 then x, y = x / 100, y / 100 end
    if x < 0 or x > 1 or y < 0 or y > 1 then return false end
    local mapPoint = UiMapPoint and UiMapPoint.CreateFromCoordinates
    if mapPoint and C_Map and C_Map.SetUserWaypoint then
        local marker = safe(mapPoint, map, x, y)
        if marker then
            local ok = pcall(C_Map.SetUserWaypoint, marker)
            if ok then
                if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                    pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
                end
                return true
            end
        end
    end
    if C_Map and C_Map.OpenWorldMap then
        if pcall(C_Map.OpenWorldMap, map) then return true end
    end
    if WorldMapFrame and WorldMapFrame.SetMapID and
        (not InCombatLockdown or not InCombatLockdown()) then
        local ok = pcall(WorldMapFrame.SetMapID, WorldMapFrame, map)
        if ok then
            if WorldMapFrame.Show then pcall(WorldMapFrame.Show, WorldMapFrame) end
            return true
        end
    end
    return false
end

local function npcIDFromGUID(guid)
    if type(guid) ~= "string" or not (guid:match("^Creature%-") or guid:match("^Vehicle%-")) then
        return nil
    end
    return tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
end

local function observeInteraction(role)
    local id = safe(GetQuestID)
    if type(id) ~= "number" or id < 1 then return end
    if safe(UnitExists, "npc") ~= true then return end
    local npcID = npcIDFromGUID(safe(UnitGUID, "npc"))
    local npcName = safe(UnitName, "npc")
    if not npcID or type(npcName) ~= "string" then return end
    local map = safe(C_Map and C_Map.GetBestMapForUnit, "player")
    local position = map and safe(C_Map and C_Map.GetPlayerMapPosition, map, "player")
    if not position then return end
    local x, y
    if type(position.GetXY) == "function" then
        local ok, a, b = pcall(position.GetXY, position)
        if ok then x, y = a, b end
    end
    x, y = x or position.x, y or position.y
    if provider.RecordSighting(id, role, npcID, npcName, map, x, y)
        and app.dungeonQuests and app.dungeonQuests.Refresh then
        app.dungeonQuests.Refresh()
    end
end

local pending = CreateFrame("Frame")
for _, event in ipairs({"QUEST_DATA_LOAD_RESULT", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE"}) do
    if app.RegisterSupported then app.RegisterSupported(pending, event) end
end
pending:SetScript("OnEvent", function(_, event, id, success)
    if event == "QUEST_DETAIL" then
        observeInteraction("giver")
    elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        observeInteraction("ender")
    elseif event == "QUEST_DATA_LOAD_RESULT" and type(id) == "number" then
        requested[id] = nil
        if success then
            names[id] = nil
            local name = safe(C_QuestLog and C_QuestLog.GetTitleForQuestID, id)
            if type(name) == "string" then names[id] = name end
        end
    end
end)
