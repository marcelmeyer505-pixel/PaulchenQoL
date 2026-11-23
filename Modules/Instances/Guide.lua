local _, app = ...
local data = app.instanceData
local guide = { entries = data.dungeons, floors = data.floors, byKey = {}, defeated = {} }
app.instances = guide
local L, read = app.L, app.ReadGameValue

for _, entry in ipairs(guide.entries) do guide.byKey[entry.key] = entry end

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
    if not map:IsShown() and ToggleWorldMap then ToggleWorldMap() end
    if map:IsShown() then app.worldMap.Navigate(map, point[1]) end
end

local function instanceID()
    if not GetInstanceInfo then return end
    local _, kind, _, _, _, _, _, id = GetInstanceInfo()
    if app.Readable(kind) == "party" or app.Readable(kind) == "raid" then return app.Readable(id) end
end

function guide.IsDefeated(entry, index)
    return guide.defeated[entry.key] and guide.defeated[entry.key][index]
end

function guide.MarkDefeated(entry, index)
    if not guide.defeated[entry.key] then guide.defeated[entry.key] = {} end
    guide.defeated[entry.key][index] = true
end

function guide.Open(key, tab, floor)
    local entry = guide.byKey[key]
    if not entry then return end
    guide.selection = { entry = entry, tab = tab or "map", floor = floor or entry.floors[1] }
    app.OpenDashboard("instances")
    if guide.Refresh then guide.Refresh(true) end
end

local events, current = CreateFrame("Frame"), nil
for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_END",
    "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" }) do
    app.RegisterSupported(events, name)
end
events:SetScript("OnEvent", function(_, event, encounter, _, _, _, success)
    if event == "ENCOUNTER_END" then
        local id = read(instanceID)
        if id and app.Readable(success) == 1 then
            for _, entry in ipairs(guide.entries) do
                if entry.id == id then
                    for index, stop in ipairs(entry.stops) do
                        for _, tracked in ipairs(stop.encounters) do
                            if tracked == app.Readable(encounter) then guide.MarkDefeated(entry, index) end
                        end
                    end
                end
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local id = read(instanceID)
        if id ~= current then
            if id then
                for _, entry in ipairs(guide.entries) do
                    if entry.id == id then guide.defeated[entry.key] = nil end
                end
            end
            current = id
        end
    end
    if guide.QueueRefresh then
        guide.QueueRefresh(event == "ENCOUNTER_END" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA")
    end
end)
