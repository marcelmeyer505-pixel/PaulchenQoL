"""Test map data and layout with Forever-style API fixtures."""
from pathlib import Path
import sys
from xml.etree import ElementTree

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / "lua_runtime"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime()
lua.execute(r'''
app, frames, timers = {}, {}, {}
secret, clock, playerMap, worldX, combat = {}, 10, 1411, 100, false
function issecretvalue(value) return value == secret end
function GetLocale() return "deDE" end
function GetTime() return clock end
function InCombatLockdown() return combat end
function UnitFactionGroup() return "Horde" end
function CreateVector2D(x, y) return { x = x, y = y } end
C_Timer = {
    After = function(_, callback) timers[#timers + 1] = callback end,
    NewTicker = function(_, callback)
        sample = callback
        return { Cancel = function() sample = nil end }
    end,
}
function flush()
    for _ = 1, 12 do
        if #timers == 0 then return end
        local work = timers
        timers = {}
        for _, callback in ipairs(work) do callback() end
    end
    error("Map updates kept scheduling themselves")
end
function fire(event)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event) end
    end
end

local methods = {
    SetScript = function(self, event, fn) self.scripts[event] = fn end,
    GetScript = function(self, event) return self.scripts[event] end,
    HookScript = function(self, event, fn)
        local previous = self.scripts[event]
        self.scripts[event] = function(...)
            if previous then previous(...) end
            fn(...)
        end
    end,
    RegisterEvent = function(self, event) self.events[event] = true end,
    SetShown = function(self, shown)
        if self.shown == shown then return end
        self.shown = shown
        local event = self.scripts[shown and "OnShow" or "OnHide"]
        if event then event(self) end
    end,
    Show = function(self) self:SetShown(true) end,
    Hide = function(self) self:SetShown(false) end,
    IsShown = function(self) return self.shown end,
    IsVisible = function(self) return self.shown and (not self.parent or self.parent:IsVisible()) end,
    IsMouseOver = function() return true end,
    SetSize = function(self, width, height) self.width, self.height = width, height end,
    SetHeight = function(self, height) self.height = height end,
    GetSize = function(self) return self.width, self.height end,
    GetWidth = function(self) return self.width end,
    GetHeight = function(self) return self.height end,
    GetFrameLevel = function() return 1 end,
    GetScale = function(self) return self.scale or 1 end,
    SetScale = function(self, scale) self.scale = scale end,
    GetAlpha = function(self) return self.alpha or 1 end,
    SetAlpha = function(self, alpha) self.alpha = alpha end,
    IsMovable = function(self) return self.movable or false end,
    SetMovable = function(self, value) self.movable = value end,
    SetPoint = function(self, ...) self.anchor = {...} end,
    GetPoint = function(self) return unpack(self.anchor or {}) end,
    GetNumPoints = function(self) return self.anchor and 1 or 0 end,
    ClearAllPoints = function(self) self.anchor = nil end,
    GetChildren = function(self) return unpack(self.children) end,
    SetText = function(self, text) self.textValue = text end,
    SetTexture = function(self, id) self.textureID = id end,
}
for _, name in ipairs({
    "SetAllPoints", "SetFrameLevel", "SetFrameStrata", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "EnableMouse", "RegisterForDrag", "RegisterForClicks", "SetJustifyH", "SetWordWrap", "SetTextColor",
    "SetHighlightTexture", "SetColorTexture", "SetNormalFontObject", "SetHighlightFontObject",
    "SetDisabledFontObject", "SetTexCoord", "SetVertexColor", "SetMouseMotionEnabled", "SetMouseClickEnabled",
}) do methods[name] = function() end end
function CreateFrame(_, _, parent)
    local widget = setmetatable({ parent = parent, shown = true, children = {}, scripts = {}, events = {},
        width = 700, height = 500 }, { __index = methods })
    frames[#frames + 1] = widget
    if parent then table.insert(parent.children, widget) end
    return widget
end
methods.CreateTexture = function(self) return CreateFrame("Texture", nil, self) end
methods.CreateFontString = methods.CreateTexture
UIParent = CreateFrame("Frame")
UIParent:SetSize(1600, 900)
GameTooltip = { IsOwned = function() return false end }
WorldMapFrame = CreateFrame("Frame", nil, UIParent)
local map = WorldMapFrame
map.ScrollContainer = CreateFrame("Frame", nil, map)
map.TitleCanvasSpacerFrame = CreateFrame("Frame", nil, map)
map.TitleCanvasSpacerFrame:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", -3, -67)
map.BorderFrame = CreateFrame("Frame", nil, map)
map.BorderFrame.NineSlice = CreateFrame("Frame", nil, map.BorderFrame)
map.BlackoutFrame = CreateFrame("Frame", nil, map)
map.id, map.providers = 1411, {}
function map:GetMapID() return self.id end
function map:GetCanvas() return self.ScrollContainer end
function map:GetCanvasScale() return 2 end
function map:IsMaximized() return self.maximized end
function map:OnFrameSizeChanged() self.sized = (self.sized or 0) + 1 end
function map:OnMapChanged() end
function map:SetMapID(id)
    self.id = id
    for _, provider in ipairs(self.providers) do provider:OnMapChanged() end
    self:OnMapChanged()
end
function map:GetNormalizedCursorPosition() return .3, .4 end
function map:EnumeratePinsByTemplate(template)
    local returned
    return function()
        if returned or self.id ~= 1411 or template ~= "FlightPointPinTemplate" then return end
        returned = true
        return { IsShown = function() return true end, GetPosition = function() return .3, .4 end }
    end
end
function map:AddDataProvider(provider)
    self.providers[#self.providers + 1] = provider
    provider.map = self
end
map:Hide()
map:HookScript("OnHide", function()
    for _, provider in ipairs(map.providers) do provider:OnHide() end
end)
function ToggleWorldMap() map:SetShown(not map:IsShown()) end
function hooksecurefunc(target, name, callback)
    local previous = target[name]
    target[name] = function(...) previous(...); callback(...) end
end
MapCanvasDataProviderMixin = { GetMap = function(self) return self.map end }
function CreateFromMixins(source)
    local mixin = {}
    for key, value in pairs(source) do mixin[key] = value end
    return mixin
end
local function menuItem(name, callback)
    local node = { name = name, callback = callback, children = {} }
    function node:CreateButton(label, click)
        local item = menuItem(label, click)
        self.children[label] = item
        return item
    end
    node.CreateTitle = node.CreateButton
    function node:CreateRadio(label, selected, click) return self:CreateButton(label, click) end
    return node
end
MenuUtil = { CreateContextMenu = function(owner, populate)
    menu = menuItem()
    populate(owner, menu)
end }

local maps = {
    [947] = {mapID = 947, name = "Azeroth", mapType = 1, parentMapID = 0},
    [1414] = {mapID = 1414, name = "Kalimdor", mapType = 2, parentMapID = 947},
    [1411] = {mapID = 1411, name = "Durotar", mapType = 3, parentMapID = 1414},
    [1413] = {mapID = 1413, name = "Brachland", mapType = 3, parentMapID = 1414},
    [1454] = {mapID = 1454, name = "Orgrimmar", mapType = 3, parentMapID = 1414},
    [1458] = {mapID = 1458, name = "Undercity", mapType = 3, parentMapID = 1414},
}
C_Map = {
    GetMapInfo = function(id) return maps[id] end,
    GetMapChildrenInfo = function(id, kind)
        local children = {}
        for _, info in pairs(maps) do
            if info.mapType == kind and info.parentMapID == id then children[#children + 1] = info end
        end
        return children
    end,
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function(id)
        if id == playerMap then return {x = .25, y = .5} end
    end,
    GetMapRectOnMap = function(from, to)
        if maps[from] and maps[from].parentMapID == to then return .1, .4, .2, .7 end
    end,
    GetMapLinksForMap = function(id)
        if id == 1411 then return { {linkedUiMapID = 1413, position = {x = .5, y = .8}} } end
    end,
    GetMapArtID = function(id) if id == 1411 then return 1200 end end,
    GetAreaInfo = function(id) return "Gebiet " .. id end,
    GetWorldPosFromMapPos = function() return 1, {x = worldX, y = 200} end,
}
C_TaxiMap = { GetTaxiNodesForMap = function(id)
    if id == 947 then return { {name = "Capital", faction = 1, position = {x = .2, y = .5}} } end
    if id ~= 1411 then return {} end
    return {
        {name = "Horde", faction = 1, position = { x = .3, y = .4 }},
        {name = "Alliance", faction = 2, position = { x = .3, y = .8 }, isUndiscovered = true},
        secret,
    }
end }
C_MapExplorationInfo = { GetExploredMapTextures = function() return explored end }
C_QuestLog = {
    GetNumQuestLogEntries = function() return 2 end,
    GetInfo = function(index) return {questID = index, title = "Quest " .. index} end,
    ReadyForTurnIn = function(id) return id == 1 end,
    GetNextWaypointForMap = function(_, id) if id == 1411 then return .2, .6 end end,
}
''')
load = lua.eval('function(code, name) assert(loadstring(code, "@" .. name))("PaulchenQoL", app) end')
for path in ("Localization.lua", "Core.lua", "Style.lua", "Config.lua", "QuestMap.lua", "Modules/Comfort/Window.lua",
             "Modules/WorldMap/ExplorationData.lua", "Modules/WorldMap/Landmarks.lua", "Modules/WorldMap/Travel.lua",
             "Modules/WorldMap/Dungeons.lua", "Modules/WorldMap/Pins.lua", "Modules/WorldMap/Window.lua"):
    load((root / path).read_text(encoding="utf-8-sig"), path)

binding = ElementTree.parse(root / "Bindings.xml").getroot().find("./Binding[@name='PAULCHENQOLPLAYERMAP']")
assert binding is not None
lua.execute(r'''
app.SecureCall = function(_, call, ...) call(...) end -- Fail the fixture if any guarded path errors.
local world, comfort = app.worldMap, app.comfort
local map = WorldMapFrame
local function count(id, kind)
    local n = 0
    for _, pin in ipairs(world.Collect(id)) do if pin.kind == kind then n = n + 1 end end
    return n
end
assert(count(1411, "flight") == 1 and count(1411, "portal") == 2 and count(1411, "cross") == 1)
assert(count(1414, "flight") == 1 and count(1414, "cross") == 1)
assert(count(947, "flight") == 0 and count(947, "dungeon") == 1)
comfort.SetEnabled("mapFlightsOnWorld", true)
assert(count(947, "flight") == 1)
comfort.SetEnabled("mapFlightsOnWorld", false)
comfort.SetEnabled("mapOtherFaction", true)
assert(count(1411, "flight") == 2)
comfort.SetEnabled("mapPortals", false)
assert(count(1411, "portal") == 0)
comfort.SetEnabled("mapDungeons", true)
assert(count(1413, "dungeon") == 1)

local first = app.mapExplorationArt[1200][5][1]
explored = { {offsetX = first[1], offsetY = first[2], textureWidth = first[3], textureHeight = first[4]} }
local data, missing, discovered = world.Unexplored(1411)
assert(#missing == #data[5] - 1 and #discovered == 1 and discovered[1] == first)
local savedExploration = explored
explored = {secret}
assert(world.Unexplored(1411) == nil)
explored = savedExploration

fire("PLAYER_LOGIN")
assert(not map:IsVisible())
TitanMapPlayerLocation = CreateFrame("Frame")
TitanMapCursorLocation = CreateFrame("Frame")
TitanMapCursorLocation:SetAlpha(.7)
PaulchenQoLOpenPlayerMap()
flush()
assert(map:IsVisible() and map:GetMapID() == playerMap)
assert(TitanMapPlayerLocation:GetAlpha() == 0 and TitanMapCursorLocation:GetAlpha() == 0)
comfort.SetEnabled("mapMouseCoords", false)
flush()
assert(TitanMapPlayerLocation:GetAlpha() == 0 and TitanMapCursorLocation:GetAlpha() == .7)
comfort.SetEnabled("mapMouseCoords", true)
flush()
assert(#map.providers == 2 and map.providers[1].used == 1, "Ready quests remain on the map without other addons")
local waypoints = map.providers[2]
for _, pin in ipairs(waypoints.pins) do
    assert(pin.point.name ~= "Horde", "A native flight pin takes precedence over the same location")
end
assert(select(5, map.TitleCanvasSpacerFrame:GetPoint()) == -49)
assert(map.BorderFrame.NineSlice:GetAlpha() == 0 and not map.BlackoutFrame:IsShown())
local function widget(text)
    for _, candidate in ipairs(frames) do
        if candidate:IsVisible() and candidate.textValue == text then return candidate end
    end
    error("Missing text: " .. text)
end
widget("Spieler  25,0 / 50,0     ·     Maus  30,0 / 40,0")
assert(select(4, widget("Kartenoptionen"):GetPoint()) == 278, "A hidden tab does not leave a gap")
local zones = widget("Gebiete")
zones.scripts.OnClick(zones)
menu.children.Kalimdor.children.Brachland.callback()
flush()
assert(map:GetMapID() == 1413)
assert(map.providers[1].used == 0)
combat = true
PaulchenQoLOpenPlayerMap()
assert(map:GetMapID() == 1413)
combat = false
PaulchenQoLOpenPlayerMap()
comfort.SetEnabled("mapCompact", false)
comfort.SetEnabled("mapReveal", true)
comfort.SetEnabled("mapDiscovery", true)
comfort.SetEnabled("mapShowDiscovered", true)
flush()
assert(select(5, map.TitleCanvasSpacerFrame:GetPoint()) == -67 and map.BorderFrame.NineSlice:GetAlpha() == 1)
assert(select(4, widget("Kartenoptionen"):GetPoint()) == 376)
local provider = map.providers[#map.providers]
assert(provider.used > 1 and provider.tileCount > 0)
assert(map.providers[1].used == 1, "Exploration and travel layers preserve quest turn-ins")
assert(type(provider.tiles[1].textureID) == "number", "Reveal loads the original client texture")
local persisted = false
for _, pin in ipairs(provider.pins) do if pin.point.kind == "discovered" then persisted = true end end
assert(persisted)
map:Hide()
assert(provider.used == 0 and provider.tileCount == 0)
assert(TitanMapPlayerLocation:GetAlpha() == 1 and TitanMapCursorLocation:GetAlpha() == .7)

sample()
playerMap, worldX, clock = 1413, 125, 10.65
sample()
local crossings = app.Settings().mapCrossings
assert(crossings[1411][1][3] == 1413 and crossings[1413][1][3] == 1411)
playerMap, worldX, clock = 1454, 8000, 11.3
sample()
assert(crossings[1454] == nil, "Long distance travel cannot teach a road crossing")
comfort.SetEnabled("mapLearnCrossings", false)
assert(sample == nil and count(1413, "cross") == 0)
''')
print("World map options, navigation, exploration, travel markers, and crossing tracking passed.")

lua.execute(r'''
local map, world, comfort = WorldMapFrame, app.worldMap, app.comfort
local journalName = "Wailing Caverns"
local selections = {}
local journalFrame = CreateFrame("Frame")
journalFrame:Hide()
ForeverDungeonJournalFrame = journalFrame
ForeverDungeonJournal_NS = {
    DB = { [journalName] = {
        quests = { {id = 10} }, bosses = { {name = "Boss"} },
        entrance = { mapID = 1413, x = .46, y = .36 },
    } },
    ORDER = { journalName },
    DUNGEON_MAPS = { [journalName] = {} },
    INSTANCE_ID_TO_DUNGEON = { [43] = journalName },
    LocalizeDungeonName = function() return "Höhlen des Wehklagens" end,
    OpenDungeonMap = function(name)
        assert(journalFrame:IsShown() and name == journalName)
        selections[#selections + 1] = "map"
    end,
    OpenQuestPage = function(name, id)
        assert(journalFrame:IsShown() and name == journalName and id == nil)
        selections[#selections + 1] = "quests"
    end,
    OpenBossPage = function(name, index)
        assert(journalFrame:IsShown() and name == journalName and index == 1)
        selections[#selections + 1] = "boss"
    end,
}
local entrances = {
    wailingcaverns = { map = 1413, x = .4599, y = .3627 },
    testnorth = { map = 1413, x = .6, y = .66 },
    testsouth = { map = 1413, x = .615, y = .655 },
}
ForeverDungeonRoutes = {
    Dungeons = {
        {key = "wailingcaverns", instanceID = 43, name = journalName},
        {key = "testnorth", instanceID = 5001, name = "North"},
        {key = "testsouth", instanceID = 5001, name = "South"},
    },
    GetEntrance = function(_, key) return entrances[key] end,
    Window = {Open = function(_, key) selections[#selections + 1] = key end},
}
UiMapPoint = {CreateFromCoordinates = function(mapID, x, y) return {mapID, x, y} end}
C_Map.CanSetUserWaypointOnMap = function(id) return id == 1413 end
C_Map.SetUserWaypoint = function(point) selectedWaypoint = point end
C_SuperTrack = {SetSuperTrackedUserWaypoint = function(active) trackingWaypoint = active end}
C_EncounterJournal = {
    GetDungeonEntrancesForMap = function(id)
        if id == 1413 then return { {
            name = "Native", position = {x = .460, y = .363}, journalInstanceID = 107,
        } } end
    end,
}
function EJ_GetInstanceInfo(id)
    assert(id == 107)
    return "Native Title", nil, nil, nil, nil, nil, 0, nil, nil, 43
end
local enumerate = map.EnumeratePinsByTemplate
function map:EnumeratePinsByTemplate(template)
    if self.id == 1413 and template == "DungeonEntrancePinTemplate" then
        local returned
        return function()
            if returned then return end
            returned = true
            return {
                IsShown = function() return true end, GetPosition = function() return .46, .363 end,
                GetFrameLevel = function() return 35 end,
            }
        end
    end
    return enumerate(self, template)
end
map:Show()
map:SetMapID(1413)
flush()
local provider = map.providers[#map.providers]
local function findPin(predicate)
    for index = 1, provider.used do
        local pin = provider.pins[index]
        if predicate(pin.point) then return pin end
    end
    error("Dungeon entrance marker was not rendered")
end
local single = findPin(function(point) return point.dungeon and point.dungeon.route == "wailingcaverns" end)
assert(single.point.x == .46 and single.point.dungeon.journal == journalName)
local rootEntrance
for _, point in ipairs(world.Collect(947)) do
    if point.dungeon and point.dungeon.route == "wailingcaverns" then rootEntrance = point; break end
end
assert(rootEntrance and rootEntrance.dungeon.waypoint[1] == 1413)
single.scripts.OnClick(single, "LeftButton")
assert(selections[#selections] == "map")
single.scripts.OnClick(single, "RightButton")
local options = menu.children
combat = true
options["Instanzquests öffnen"].callback()
assert(#selections == 1)
combat = false
options["Instanzquests öffnen"].callback()
assert(selections[#selections] == "quests")
options["Bosse und Beute öffnen"].callback()
assert(selections[#selections] == "boss")
options["In Forever DungeonRoutes öffnen"].callback()
assert(selections[#selections] == "wailingcaverns")
options["Wegpunkt zum Eingang setzen"].callback()
assert(selectedWaypoint[1] == 1413 and selectedWaypoint[2] == .46 and trackingWaypoint)
local group = findPin(function(point) return point.dungeons and #point.dungeons == 2 end)
group.scripts.OnClick(group, "LeftButton")
menu.children.South.children["In Forever DungeonRoutes öffnen"].callback()
assert(selections[#selections] == "testsouth", "A shared entrance menu must open the selected wing")
ForeverDungeonJournal_NS.IsDungeonMapLocked = function() return true end
single.scripts.OnClick(single, "LeftButton")
assert(selections[#selections] == "wailingcaverns", "Routes can supply the preview if Journal cannot")
ForeverDungeonJournal_NS, ForeverDungeonJournalFrame = nil, nil
world.Refresh()
flush()
single = findPin(function(point) return point.dungeon and point.dungeon.route == "wailingcaverns" end)
assert(single.point.dungeon.journal == nil)
single.scripts.OnClick(single, "LeftButton")
assert(selections[#selections] == "wailingcaverns")
comfort.SetEnabled("mapDungeons", false)
flush()
for index = 1, provider.used do assert(provider.pins[index].point.kind ~= "dungeon") end
''')
print("Dungeon entrance links, Journal map and quests, Routes fallback and shared entrances passed.")
