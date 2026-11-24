local _, app = ...
local data = app.instanceData
local guide = { entries = data.dungeons, floors = data.floors, byKey = {}, byID = {}, defeated = {} }
app.instances = guide
local L, read = app.L, app.ReadGameValue
local roomNames = {}

for _, entry in ipairs(guide.entries) do
    guide.byKey[entry.key] = entry
    if entry.id and #entry.floors > 0 then
        local entries = guide.byID[entry.id] or {}
        entries[#entries + 1] = entry
        guide.byID[entry.id] = entries
    end
    if entry.rooms then
        local names = {}
        roomNames[entry] = names
        for _, room in ipairs(entry.rooms) do
            room.shapes = {}
            local area, largest = {}, 0
            for _, box in ipairs(room.boxes) do
                local floor = box[1]
                local shapes = room.shapes[floor] or {}
                room.shapes[floor] = shapes
                shapes[#shapes + 1] = box
                area[floor] = (area[floor] or 0) + box[4] * box[5]
                if area[floor] > largest then room.mainFloor, largest = floor, area[floor] end
            end
            names[room.name] = room
            if room.de then names[room.de] = room end
            for _, alias in ipairs(room.aliases) do names[alias] = room end
        end
    end
end

function guide.Name(entry)
    return app.GetLanguage() == "deDE" and entry.de or entry.name
end

function guide.AllowedFaction(owner)
    return not owner or owner == read(UnitFactionGroup, "player")
end

function guide.Location(entry)
    return {
        key = entry.lootKey, guideKey = entry.key, name = entry.name, localName = guide.Name(entry),
        kind = entry.raid and "raid" or "dungeon", map = entry.area,
        instanceID = entry.id, min = entry.levels[1] or 60, suggested = entry.levels[2] or 60, active = true,
    }
end

function guide.QuestTitle(quest)
    local title = read(C_QuestLog and C_QuestLog.GetTitleForQuestID, quest.id)
    return title and title ~= "" and title or quest.name or ("#" .. quest.id)
end

function guide.QuestStatus(id)
    local quests = C_QuestLog
    if not quests then return L("Offen"), app.style.muted end
    if read(quests.ReadyForTurnIn, id) then return L("Abgabebereit"), app.style.gold end
    if read(quests.IsOnQuest, id) then return L("Im Questlog"), app.style.cream end
    if read(quests.IsQuestFlaggedCompleted, id) then return L("Abgeschlossen"), app.style.green end
    return L("Offen"), app.style.muted
end

function guide.ShowWaypoint(point)
    local combat, known = app.comfort.Read(InCombatLockdown)
    if not known or combat or not point or not C_Map then return end
    if read(C_Map.CanSetUserWaypointOnMap, point[1]) == true and UiMapPoint and C_Map.SetUserWaypoint then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(unpack(point)))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end
    local map = WorldMapFrame
    if not map then return end
    app.CloseDashboard("instances")
    if guide.UseOutdoorMap then guide.UseOutdoorMap() end
    if not map:IsShown() and ToggleWorldMap then ToggleWorldMap() end
    if map:IsShown() then app.worldMap.Navigate(map, point[1]) end
end

local function instanceID()
    if not GetInstanceInfo then return end
    local _, kind, _, _, _, _, _, id = GetInstanceInfo()
    if app.Readable(kind) == "party" or app.Readable(kind) == "raid" then return app.Readable(id) end
end

local currentID, encounterEntry, encounterFloor, portalEntry, lastOutside

local function knownInstance()
    local id = read(instanceID)
    if id then return id end
    if read(IsInInstance) ~= false then return currentID end
end

-- The nearest entrance just before zoning can identify a wing without an interior player position.
-- Method adapted from Forever Dungeon Routes Position.lua (see INSTANCE_DATA.md).
local function noteOutside()
    if not app.comfort.Enabled("mapInterior") or read(IsInInstance) ~= false or not C_Map then return end
    local best = read(C_Map.GetBestMapForUnit, "player")
    for _, group in pairs(data.doors or {}) do
        if best == group.map then
            local x, y = app.worldMap.Vector(read(C_Map.GetPlayerMapPosition, best, "player"))
            if app.ValidMapPoint(x, y) then lastOutside = { map = best, x = x, y = y, when = GetTime() } end
            return
        end
    end
end

local function enteredWing(id)
    local group, seen = data.doors and data.doors[id], lastOutside
    if not group or not seen or seen.map ~= group.map or GetTime() - seen.when > 120 then return end
    local entry, nearest = nil, 15 ^ 2
    for _, door in ipairs(group.portals) do
        local distance = ((seen.x - door[2]) * group.w) ^ 2 + ((seen.y - door[3]) * group.h) ^ 2
        if distance <= nearest then entry, nearest = guide.byKey[door[1]], distance end
    end
    return entry
end

local function rememberedWings()
    local db = app.Settings()
    if type(db.instanceWings) ~= "table" then db.instanceWings = {} end
    return db.instanceWings
end

function guide.RememberWing(entry)
    if entry.id and guide.byID[entry.id] and #guide.byID[entry.id] > 1 then
        rememberedWings()[entry.id] = entry.key
    end
end

local function namedRoom(entry, name)
    local names = entry and roomNames[entry]
    return names and type(name) == "string" and names[name] or nil
end

local function uniqueRoom(entries, name, preferred)
    local known = namedRoom(preferred, name)
    if known then return known, preferred end
    local found, owner
    for _, entry in ipairs(entries) do
        local room = namedRoom(entry, name)
        if room then
            if found then return end
            found, owner = room, entry
        end
    end
    return found, owner
end

function guide.CurrentMap()
    local id = knownInstance()
    local entries = guide.byID[id]
    if not entries then return end
    local best = read(C_Map and C_Map.GetBestMapForUnit, "player")
    for _, entry in ipairs(entries) do
        for _, floor in ipairs(entry.floors) do
            if best == floor then
                guide.RememberWing(entry)
                return entry, floor, entries
            end
        end
    end
    local entered = portalEntry and portalEntry.id == id and portalEntry or enteredWing(id)
    local preferred = entered or guide.byKey[rememberedWings()[id]]
    if preferred and preferred.id ~= id then preferred = nil end
    local room, roomEntry = uniqueRoom(entries, read(GetSubZoneText), preferred)
    if room then
        guide.RememberWing(roomEntry)
        local floor = roomEntry == encounterEntry and room.shapes[encounterFloor] and encounterFloor or room.mainFloor
        return roomEntry, floor, entries
    end
    if encounterEntry and encounterEntry.id == id then return encounterEntry, encounterFloor, entries end
    if entered then
        portalEntry = entered
        guide.RememberWing(entered)
    end
    local entry = preferred or entries[1]
    return entry, entry.floors[1], entries
end

function guide.PlayerRoom(entry, preferred)
    if not entry.id or entry.id ~= knownInstance() then return end
    local room = namedRoom(entry, read(GetSubZoneText))
    if not room then return nil, nil, true end
    local best = read(C_Map and C_Map.GetBestMapForUnit, "player")
    local floor = room.shapes[best] and best or room.shapes[preferred] and preferred or room.mainFloor
    return room, floor, true
end

local function projectFloor(floor, north, west)
    local position = guide.floors[floor] and guide.floors[floor].position
    if not position then return end
    local a, b, c, d, e, f = unpack(position)
    local x, y
    if f then
        x, y = a * north + b * west + c, d * north + e * west + f
    else
        x, y = (d - west) / (d - b), (c - north) / (c - a)
    end
    if app.ValidMapPoint(x, y) then return x, y end
end

local function mapFacing(floor)
    local facing = read(GetPlayerFacing)
    if type(facing) ~= "number" then return end
    local position = guide.floors[floor] and guide.floors[floor].position
    if not position or not position[6] then return facing end
    -- The reference artwork for some floors is rotated. Project the direction as well as the point.
    local north, west = math.cos(facing), math.sin(facing)
    local x = position[1] * north + position[2] * west
    local y = position[4] * north + position[5] * west
    return math.atan2(-x, -y * 2 / 3)
end

function guide.PlayerPosition(entry, preferred)
    if not C_Map or not preferred or not entry.id or entry.id ~= knownInstance() then return end
    local best = read(C_Map.GetBestMapForUnit, "player")
    local floor
    for _, candidate in ipairs(guide.byID[entry.id] or {}) do
        for _, id in ipairs(candidate.floors) do
            if best == id then
                if candidate ~= entry then return end
                floor = id
            end
        end
    end
    local selected = floor or preferred
    local x, y = app.worldMap.Vector(read(C_Map.GetPlayerMapPosition, selected, "player"))
    if app.ValidMapPoint(x, y) then return selected, x, y, mapFacing(selected) end
    if not UnitPosition then return end
    local ok, north, west, _, mapID = pcall(UnitPosition, "player")
    if not ok then return end
    north, west, mapID = app.Readable(north), app.Readable(west), app.Readable(mapID)
    if type(north) ~= "number" or type(west) ~= "number" or mapID and mapID ~= entry.id then return end
    x, y = projectFloor(selected, north, west)
    if x then return selected, x, y, mapFacing(selected) end
    if floor then return end
    for _, id in ipairs(entry.floors) do
        if id ~= selected then
            x, y = projectFloor(id, north, west)
            if x then return id, x, y, mapFacing(id) end
        end
    end
end

function guide.IsDefeated(entry, index)
    return guide.defeated[entry.key] and guide.defeated[entry.key][index]
end

function guide.MarkDefeated(entry, index)
    if not guide.defeated[entry.key] then guide.defeated[entry.key] = {} end
    guide.defeated[entry.key][index] = true
end

function guide.Open(key, tab, floor, boss)
    local entry = guide.byKey[key]
    if not entry then return end
    guide.selection = {
        entry = entry, tab = tab == "route" and "map" or tab or "map", floor = floor or entry.floors[1], boss = boss,
    }
    app.OpenDashboard("instances")
    if guide.Refresh then guide.Refresh(true) end
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_LOGIN", "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL",
    "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do
    app.RegisterSupported(events, name)
end
events:SetScript("OnEvent", function(_, event, encounter, _, _, _, success)
    if event == "PLAYER_LOGIN" then
        if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(.5, noteOutside) end
        local upgrades = app.upgrades
        if upgrades and upgrades.On then
            upgrades.On("GEAR_UPDATED", function(reason, id)
                if reason == "bagItems" then return end
                if reason == "items" and id then guide.LootItemUpdated(id)
                else guide.RefreshLoot() end
            end)
        end
        return
    end
    if event == "PLAYER_LEAVING_WORLD" then noteOutside(); return end
    if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        local id = app.Readable(encounter)
        if type(id) == "number" then guide.LootItemUpdated(id) end
        if guide.selection and guide.selection.tab == "quests" and guide.selection.quest then guide.QueueRefresh() end
        return
    end
    local locationChanged = event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
    local isEncounter = event == "ENCOUNTER_START" or event == "ENCOUNTER_END" or event == "BOSS_KILL"
    if locationChanged then
        local id = knownInstance()
        if id ~= currentID then
            for _, entry in ipairs(guide.byID[id] or {}) do
                guide.defeated[entry.key] = nil
            end
            currentID, encounterEntry, encounterFloor, portalEntry = id, nil, nil, enteredWing(id)
            if portalEntry then guide.RememberWing(portalEntry) end
            if id then lastOutside = nil end
            if guide.ResetWorldOverlay then guide.ResetWorldOverlay() end
        end
    elseif isEncounter then
        local id, fight = knownInstance(), app.Readable(encounter)
        if type(fight) == "number" then
            local defeated = event == "BOSS_KILL" or event == "ENCOUNTER_END" and app.Readable(success) == 1
            for _, entry in ipairs(guide.byID[id] or {}) do
                for index, stop in ipairs(entry.stops) do
                    for _, tracked in ipairs(stop.encounters) do
                        if tracked == fight then
                            encounterEntry, encounterFloor = entry, stop.floor
                            guide.RememberWing(entry)
                            if defeated then guide.MarkDefeated(entry, index) end
                            break
                        end
                    end
                end
            end
        end
    end
    if guide.QueueRefresh then guide.QueueRefresh(locationChanged or isEncounter) end
    if (locationChanged or isEncounter) and app.worldMap then
        app.worldMap.Refresh()
        if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then C_Timer.After(.6, app.worldMap.Refresh) end
    end
end)
