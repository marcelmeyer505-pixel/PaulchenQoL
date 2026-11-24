local _, app = ...
local data = app.instanceData
local guide = { entries = data.dungeons, floors = data.floors, byKey = {}, byID = {}, defeated = {} }
app.instances = guide
local L, read = app.L, app.ReadGameValue

for _, entry in ipairs(guide.entries) do
    guide.byKey[entry.key] = entry
    if entry.id and #entry.floors > 0 then
        local entries = guide.byID[entry.id] or {}
        entries[#entries + 1] = entry
        guide.byID[entry.id] = entries
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
    if encounterEntry and encounterEntry.id == id then return encounterEntry, encounterFloor, entries end
    local entry = portalEntry and portalEntry.id == id and portalEntry or enteredWing(id)
    if entry then
        portalEntry = entry
        guide.RememberWing(entry)
    else
        entry = guide.byKey[rememberedWings()[id]] or entries[1]
        if entry.id ~= id then entry = entries[1] end
    end
    return entry, entry.floors[1], entries
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
for _, name in ipairs({ "PLAYER_LOGIN", "PLAYER_LEAVING_WORLD", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL",
    "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do
    app.RegisterSupported(events, name)
end
events:SetScript("OnEvent", function(_, event, encounter, _, _, _, success)
    if event == "PLAYER_LOGIN" then
        if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(.5, noteOutside) end
        local upgrades = app.upgrades
        if upgrades and upgrades.On then
            upgrades.On("GEAR_UPDATED", function()
                if guide.selection and guide.selection.tab ~= "map" then guide.QueueRefresh() end
            end)
        end
        return
    end
    if event == "PLAYER_LEAVING_WORLD" then noteOutside(); return end
    local locationChanged = event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
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
