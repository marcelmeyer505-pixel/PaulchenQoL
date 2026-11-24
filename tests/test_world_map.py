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
cursorX, cursorY, mouseDown = 250, 320, false
function issecretvalue(value) return value == secret end
function GetLocale() return "deDE" end
function GetTime() return clock end
function InCombatLockdown() return combat end
function UnitFactionGroup() return "Horde" end
function CreateVector2D(x, y) return { x = x, y = y } end
function GetCursorPosition() return cursorX, cursorY end
function IsMouseButtonDown(button) return button == "LeftButton" and mouseDown end
C_Timer = {
    After = function(_, callback) timers[#timers + 1] = callback end,
    NewTicker = function(_, callback)
        sample = callback
        return { Cancel = function() sample = nil end }
    end,
}
function flush()
    for _ = 1, 96 do
        if #timers == 0 then return end
        local work = timers
        timers = {}
        for _, callback in ipairs(work) do callback() end
    end
    error("Map updates kept scheduling themselves")
end
function fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
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
    SetWidth = function(self, width) self.width = width end,
    GetSize = function(self) return self.width, self.height end,
    GetParent = function(self) return self.parent end,
    SetParent = function(self, parent) self.parent = parent end,
    GetWidth = function(self) return self.width end,
    GetHeight = function(self) return self.height end,
    GetFrameLevel = function(self) return self.level or 1 end,
    SetFrameLevel = function(self, level) self.level = level end,
    GetFrameStrata = function(self) return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end,
    SetFrameStrata = function(self, strata) self.strata = strata end,
    SetClipsChildren = function(self, enabled) self.clipsChildren = enabled end,
    GetScale = function(self) return self.scale or 1 end,
    SetScale = function(self, scale) self.scale = scale end,
    GetEffectiveScale = function(self) return self.effectiveScale or 1 end,
    GetLeft = function(self) return self.left or 0 end,
    GetTop = function(self) return self.top or self:GetHeight() end,
    GetAlpha = function(self) return self.alpha or 1 end,
    SetAlpha = function(self, alpha) self.alpha = alpha end,
    IsMovable = function(self) return self.movable or false end,
    SetMovable = function(self, value) self.movable = value end,
    SetPoint = function(self, ...) self.anchor = {...} end,
    GetPoint = function(self) return unpack(self.anchor or {}) end,
    GetNumPoints = function(self) return self.anchor and 1 or 0 end,
    ClearAllPoints = function(self) self.anchor = nil end,
    GetChildren = function(self) return unpack(self.children) end,
    SetScrollChild = function(self, child) self.scrollChild = child end,
    GetHorizontalScroll = function(self) return self.horizontalScroll or 0 end,
    GetVerticalScroll = function(self) return self.verticalScroll or 0 end,
    SetHorizontalScroll = function(self, value) self.horizontalScroll = value end,
    SetVerticalScroll = function(self, value) self.verticalScroll = value end,
    UpdateScrollChildRect = function() end,
    SetText = function(self, text) self.textValue = text end,
    SetTexture = function(self, id) self.textureID, self.atlasID = id, nil end,
    SetRotation = function(self, radians) self.rotation = radians end,
    SetDesaturated = function(self, value) self.desaturated = value end,
    SetAtlas = function(self, id) self.atlasID, self.textureID = id, nil end,
}
for _, name in ipairs({
    "SetAllPoints", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "EnableMouse", "RegisterForDrag", "RegisterForClicks", "SetJustifyH", "SetWordWrap", "SetTextColor",
    "SetHighlightTexture", "SetColorTexture", "SetNormalFontObject", "SetHighlightFontObject",
    "SetDisabledFontObject", "SetTexCoord", "SetMouseMotionEnabled", "SetMouseClickEnabled",
    "SetDrawLayer", "SetThickness", "SetColorTexture", "SetStartPoint", "SetEndPoint",
    "EnableMouseWheel", "SetEnabled",
}) do methods[name] = function() end end
methods.SetVertexColor = function(self, ...) self.tint = {...} end
methods.SetColorTexture = function(self, ...) self.color = {...} end
methods.SetAllPoints = function(self, target) self.allPoints = target or self.parent end
methods.SetStartPoint = function(self, ...) self.startPoint = {...} end
methods.SetEndPoint = function(self, ...) self.endPoint = {...} end
function CreateFrame(_, _, parent)
    local widget = setmetatable({ parent = parent, shown = true, children = {}, scripts = {}, events = {},
        width = 700, height = 500 }, { __index = methods })
    frames[#frames + 1] = widget
    if parent then table.insert(parent.children, widget) end
    return widget
end
methods.CreateTexture = function(self) return CreateFrame("Texture", nil, self) end
methods.CreateFontString = methods.CreateTexture
methods.CreateLine = function(self)
    local line = self:CreateTexture()
    line.isRouteLine = true
    return line
end
UIParent = CreateFrame("Frame")
UIParent:SetSize(1600, 900)
GameTooltip = { IsOwned = function() return false end }
WorldMapFrame = CreateFrame("Frame", nil, UIParent)
local map = WorldMapFrame
map.ScrollContainer = CreateFrame("Frame", nil, map)
map.ScrollContainer.Child = CreateFrame("Frame", nil, map.ScrollContainer)
function map.ScrollContainer:GetHorizontalScroll()
    return self.scrollX or self:GetWidth() * (1 - 1 / map:GetCanvasScale()) / 2
end
function map.ScrollContainer:GetVerticalScroll()
    return self.scrollY or self:GetHeight() * (1 - 1 / map:GetCanvasScale()) / 2
end
map.TitleCanvasSpacerFrame = CreateFrame("Frame", nil, map)
map.TitleCanvasSpacerFrame:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", -3, -67)
map.BorderFrame = CreateFrame("Frame", nil, map)
map.BorderFrame:SetFrameStrata("HIGH")
map.BorderFrame:SetFrameLevel(70)
map.BorderFrame.NineSlice = CreateFrame("Frame", nil, map.BorderFrame)
map.NavBar = CreateFrame("Frame", nil, map)
map.BlackoutFrame = CreateFrame("Frame", nil, map)
map.id, map.providers = 1411, {}
function map:GetMapID() return self.id end
function map:GetCanvas() return self.ScrollContainer.Child end
function map:GetCanvasScale() return self.canvasScale or 2 end
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
mapKeys, overrides = { "M" }, {}
function GetBindingKey(command)
    assert(command == "TOGGLEWORLDMAP")
    return unpack(mapKeys)
end
function ClearOverrideBindings(owner)
    assert(not combat)
    for key, frame in pairs(overrides) do
        if frame == owner then overrides[key] = nil end
    end
end
function SetOverrideBindingClick(owner, priority, key, name)
    assert(not combat and not priority and name == "PaulchenQoLInstanceMapBinding")
    overrides[key] = owner
end
function mapKey(key)
    local handler = overrides[key]
    if handler then
        handler.scripts.OnClick(handler, "LeftButton")
    else
        for _, native in ipairs(mapKeys) do if native == key then ToggleWorldMap(); return end end
    end
end
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
    [1415] = {mapID = 1415, name = "Östliche Königreiche", mapType = 2, parentMapID = 947},
    [1420] = {mapID = 1420, name = "Tirisfal", mapType = 3, parentMapID = 1415},
    [1423] = {mapID = 1423, name = "Östliche Pestländer", mapType = 3, parentMapID = 1415},
    [1445] = {mapID = 1445, name = "Düstermarschen", mapType = 3, parentMapID = 1414},
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
C_Texture = {GetAtlasInfo = function() return {} end}
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
app.SecureCall = function(_, call, ...) call(...); return true end -- Fail the fixture if any guarded path errors.
realFlightLandmarks, app.mapFlightLandmarks = app.mapFlightLandmarks, {}
local world, comfort = app.worldMap, app.comfort
local map = WorldMapFrame
local function count(id, kind)
    local n = 0
    for _, pin in ipairs(world.Collect(id)) do if pin.kind == kind then n = n + 1 end end
    return n
end
assert(count(1411, "flight") == 1 and count(1411, "portal") == 2 and count(1411, "cross") == 1)
assert(count(1414, "flight") == 1 and count(1414, "cross") == 2)
assert(count(947, "flight") == 0 and count(947, "dungeon") == 2)
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
assert(#map.providers == 3 and map.providers[1].used == 1, "Ready quests remain on the map without other addons")
local waypoints = map.providers[2]
local ownFlight
for index = 1, waypoints.used do
    local pin = waypoints.pins[index]
    if pin.point.name == "Horde" then ownFlight = pin end
end
assert(ownFlight and ownFlight:IsVisible(), "A native pin that reports shown cannot suppress the raised marker")
assert(select(5, map.TitleCanvasSpacerFrame:GetPoint()) == -31 and not map.NavBar:IsShown())
assert(map.BorderFrame.NineSlice:GetAlpha() == 0 and not map.BlackoutFrame:IsShown())
local background
for _, child in ipairs(map.children) do
    if child.allPoints == map and child.color and child.color[4] == 1 then background = child end
end
assert(background and background:IsShown(), "The compact window has an opaque backing")
comfort.SetEnabled("mapZoneMenu", false)
flush()
assert(map.NavBar:IsShown() and select(5, map.TitleCanvasSpacerFrame:GetPoint()) == -49)
comfort.SetEnabled("mapZoneMenu", true)
flush()
assert(not map.NavBar:IsShown() and select(5, map.TitleCanvasSpacerFrame:GetPoint()) == -31)
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
assert(map.NavBar:IsShown() and not background:IsShown())
assert(select(4, widget("Kartenoptionen"):GetPoint()) == 376)
local provider = map.providers[2]
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
    testsouth = { map = 1413, x = .605, y = .658 },
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
C_Map.SetUserWaypoint = function(point) selectedWaypoint = point; return true end
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

for path in ("Data/DungeonSeedDungeons.lua", "Data/DungeonSeedQuests.lua", "Data/DungeonSeedPlaces.lua", "Data/DungeonQuestHints.lua",
             "DungeonQuestProvider.lua", "DungeonQuests.lua", "Modules/Instances/Data.lua",
             "Modules/Instances/Guide.lua", "Modules/Instances/Quests.lua", "Modules/Instances/Window.lua"):
    load((root / path).read_text(encoding="utf-8-sig"), path)
lua.execute(r'''
ForeverDungeonJournal_NS, ForeverDungeonRoutes, AtlasLoot = nil, nil, nil
function SetPortraitTextureFromCreatureDisplayID(texture, display) texture.display = display end
local guide = app.instances
local map = WorldMapFrame
local wailing = assert(guide.byKey.wailingcaverns)
local custom = assert(guide.byKey.alcazprison)
assert(#guide.entries >= 40 and #wailing.quests >= 5 and #wailing.loot >= 5)
assert(#custom.floors > 1 and #guide.floors[custom.floors[1]].art > 0)
local instancePage
app.OpenDashboard = function(tab)
    assert(tab == "instances")
    instancePage = guide.GetPage(UIParent)
    instancePage:Show()
end
app.CloseDashboard = function() instancePage:Hide() end
local function textWidget(text)
    for _, frame in ipairs(frames) do
        if frame:IsVisible() and frame.textValue == text then return frame end
    end
    error("Missing instance guide text: " .. text)
end

app.comfort.SetEnabled("mapDungeons", true)
map:SetMapID(1413)
map:Show()
flush()
local provider = map.providers[#map.providers]
local entrance
for index = 1, provider.used do
    local marker = provider.pins[index]
    if marker.point.dungeon and marker.point.dungeon.guideKey == wailing.key then entrance = marker; break end
end
assert(entrance, "The entrance comes from Paulchen's own data")
entrance.scripts.OnClick(entrance, "LeftButton")
assert(guide.selection.entry == wailing and guide.selection.tab == "map")
textWidget("Höhlen des Wehklagens")
textWidget("Bossreihenfolge")
assert(not instancePage.tabs.route and instancePage.tabs.map:IsShown())
assert(instancePage.map.art[1]:IsShown() and instancePage.map.lines[1]:IsShown(),
    "The standard interior map shows its art and route together")
local bossPin = instancePage.map.pins[1]
assert(bossPin:IsVisible() and bossPin.portrait.display == bossPin.stop.display)
assert(bossPin:GetFrameLevel() > instancePage.map.overlay:GetFrameLevel())
local completed, accepted, ready = {}, {}, {}
local oldDone, oldOnQuest, oldReady = C_QuestLog.IsQuestFlaggedCompleted, C_QuestLog.IsOnQuest, C_QuestLog.ReadyForTurnIn
C_QuestLog.IsQuestFlaggedCompleted = function(id) return completed[id] or false end
C_QuestLog.IsOnQuest = function(id) return accepted[id] or false end
C_QuestLog.ReadyForTurnIn = function(id) return ready[id] or oldReady(id) end
local function questWidget(id)
    for _, widget in ipairs(instancePage.rows) do
        if widget.row and widget.row.questID == id then return widget end
    end
end
local function rowFor(quests, id)
    for _, row in ipairs(quests) do if row.id == id then return row end end
end
local catalog = {}
for _, entry in ipairs(guide.entries) do
    local data = guide.QuestSnapshot(entry)
    if data.key then
        assert(not catalog[data.key], "Each catalog wing belongs to exactly one map")
        catalog[data.key] = data
    end
end
for _, dungeon in ipairs(app.DungeonQuestData.List()) do assert(catalog[dungeon.key], dungeon.key) end
assert(rowFor(catalog.STRAT_LIVE.quests, 5262) and not rowFor(catalog.STRAT_LIVE.quests, 5263))
assert(rowFor(catalog.STRAT_UD.quests, 5263) and not rowFor(catalog.STRAT_UD.quests, 5262))
assert(rowFor(catalog.BRD.quests, 4082) and not rowFor(catalog.BRD.quests, 4126), "Horde sees the right quests")
assert(rowFor(catalog.WC.quests, 914).rewards[1] == 6504)
local originalFaction = UnitFactionGroup
function UnitFactionGroup() return "Alliance" end
assert(guide.QuestSnapshot(custom).incomplete and rowFor(guide.QuestSnapshot(custom).quests, 96772),
    "A gap in the new catalog preserves legacy instance quests")
UnitFactionGroup = originalFaction

textWidget("Quests").scripts.OnClick()
textWidget("Instanzquests")
local leaders = assert(questWidget(914))
assert(leaders.right.textValue == "Vorquests fehlen" and leaders.source.textValue:find("Nara Wildmane", 1, true))
local matching = 0
for _, quest in ipairs(guide.QuestSnapshot(wailing).quests) do if quest.id == 914 then matching = matching + 1 end end
assert(matching == 1, "A quest in both catalogs appears only once")
assert(instancePage.questProgress.textValue:match("^0/%d+ abgeschlossen"))
leaders.scripts.OnClick(leaders)
assert(guide.selection.quest == 914)
textWidget("Vorquests")
assert(questWidget(1489) and questWidget(1490), "Prerequisites appear directly in the detail view")
local firstPrior = questWidget(1489)
firstPrior.scripts.OnClick(firstPrior)
assert(guide.selection.quest == 1489 and instancePage.listTitle.textValue == "Quest #1489")
instancePage.backQuest.scripts.OnClick()
completed[1489], completed[1490], accepted[914], ready[914] = true, true, true, true
fire("QUEST_LOG_UPDATE")
flush()
assert(questWidget(914).right.textValue == "Abgabebereit" and instancePage.questProgress.textValue:find("1 im Questlog", 1, true))
completed[914] = true
fire("QUEST_TURNED_IN", 914)
flush()
assert(questWidget(914).right.textValue == "Abgeschlossen")
assert(instancePage.questProgress.textValue:match("^1/%d+ abgeschlossen"))

local deadmines = guide.byKey.deadmines
local oldCanSet = C_Map.CanSetUserWaypointOnMap
C_Map.CanSetUserWaypointOnMap = function(id) return id == 1436 end
function UnitFactionGroup() return "Alliance" end
local selector = textWidget("Instanz wählen")
selector.scripts.OnClick(selector)
menu.children.Instanzen.children[guide.Name(deadmines)].callback()
assert(guide.selection.entry == deadmines and guide.selection.tab == "quests", "Switching instances keeps the quest tab open")
local defias = assert(questWidget(166))
defias.scripts.OnClick(defias)
local clicked
for _, widget in ipairs(instancePage.rows) do
    if widget.row and widget.row.tip and widget.row.tip.title == "Gryan Stoutmantle" then
        assert(widget.row.action)
        widget.scripts.OnClick(widget)
        clicked = true
        break
    end
end
assert(clicked and math.abs(selectedWaypoint[2] - .562) < .00001)
UnitFactionGroup, C_Map.CanSetUserWaypointOnMap = originalFaction, oldCanSet

local function locationWidget(name)
    for _, widget in ipairs(instancePage.rows) do
        if widget.row and widget.row.left == name then return widget end
    end
end
guide.Open("stratholme_living", "quests")
guide.selection.quest = 8968
guide.Refresh()
local bodley = assert(locationWidget("Bodley"))
assert(bodley.right.textValue == "Classic-Referenz" and bodley.row.tip.text:find("für Forever nicht bestätigt", 1, true))

guide.Open("blackfathom", "quests")
local quest = assert(questWidget(6561))
quest.scripts.OnClick(quest)
local thaelrid = assert(locationWidget("Argent Guard Thaelrid"))
assert(thaelrid.right.textValue == "In der Instanz" and not thaelrid.row.action)
local oldQuest, oldExists, oldGUID, oldName = GetQuestID, UnitExists, UnitGUID, UnitName
local oldBestMap, oldMapPosition = C_Map.GetBestMapForUnit, C_Map.GetPlayerMapPosition
function GetQuestID() return 6561 end
function UnitExists(unit) return unit == "npc" end
function UnitGUID() return "Creature-0-0-0-0-4787-00000ABC" end
function UnitName() return "Argent Guard Thaelrid" end
C_Map.GetBestMapForUnit = function() return 1440 end
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return .41, .31 end } end
fire("QUEST_DETAIL")
flush()
thaelrid = assert(locationWidget("Argent Guard Thaelrid"))
assert(thaelrid.right.textValue == "Beobachtet" and thaelrid.row.action
    and thaelrid.row.tip.text:find("41,0 / 31,0", 1, true), "Quest dialogs update the open instance tab")
GetQuestID, UnitExists, UnitGUID, UnitName = oldQuest, oldExists, oldGUID, oldName
C_Map.GetBestMapForUnit, C_Map.GetPlayerMapPosition = oldBestMap, oldMapPosition
C_QuestLog.IsQuestFlaggedCompleted, C_QuestLog.IsOnQuest, C_QuestLog.ReadyForTurnIn = oldDone, oldOnQuest, oldReady
guide.Open(wailing.key, "quests")
textWidget("Beute").scripts.OnClick()
textWidget("Alle Bosse")
for _, row in ipairs(instancePage.rows) do
    if row.row and row.row.item then
        assert(row.left.textValue:match("^Gegenstand #%d+$"))
        assert(row.icon:IsShown() and row.icon.textureID == 134400 and row.upgrade.textValue == "–")
        assert(row.source:IsShown() and row.source.textValue ~= "")
        break
    end
end
local bossItem, second, other
for _, group in ipairs(wailing.loot) do
    if group.name == bossPin.stop.loot then
        bossItem, second = group.items[1][1], group.items[2][1]
    end
end
for _, group in ipairs(wailing.loot) do
    if group.name ~= bossPin.stop.loot and #group.items > 0 then
        other = group.items[1][1]
        if other ~= bossItem and other ~= second then break end
    end
end
assert(bossItem and second and other and other ~= bossItem and other ~= second)
local scored, available = {}, {}
local scores = { [bossItem] = 12.5, [second] = 32, [other] = 45 }
local onGearUpdate
app.upgrades = {
    On = function(message, handler) assert(message == "GEAR_UPDATED"); onGearUpdate = handler end,
    IsUpgrade = function(result, level) return result and result.delta > 0 and result.minLevel <= level end,
    gear = {
        PlayerLevel = function() return 60 end,
        CompareToEquipped = function(link)
            local id = tonumber(link:match("item:(%d+)"))
            scored[id] = true
            return { usable = true, pct = scores[id], delta = scores[id], minLevel = 20 }
        end,
    },
}
C_Item = {
    GetItemInfo = function(id)
        if available[id] then return "Geladene Beute " .. id, "item:" .. id end
    end,
    GetItemIconByID = function(id)
        if available[id] then return 135123 end
    end,
}
fire("PLAYER_LOGIN")
flush()
for id in pairs(scores) do
    available[id] = true
    fire("ITEM_DATA_LOAD_RESULT", id, true)
end
flush()
assert(instancePage.rows[1].row.item == other and instancePage.rows[2].row.item == second,
    "The all-boss loot list sorts across sources by numeric upgrade percent")
local loaded = textWidget("Geladene Beute " .. bossItem):GetParent()
assert(scored[bossItem] and loaded.icon.textureID == 135123 and loaded.upgrade.textValue == "+12,5 %")
instancePage.tabs.map.scripts.OnClick()
local firstBoss = instancePage.rows[1]
assert(firstBoss.right.textValue == "2 Upgrades")
firstBoss.scripts.OnClick(firstBoss)
assert(guide.selection.boss == bossPin.stop.loot and guide.selection.tab == "loot")
assert(instancePage.rows[1].row.item == second and instancePage.rows[2].row.item == bossItem,
    "Clicking a boss row opens that boss only and keeps percent sorting")
scores[bossItem] = -5
onGearUpdate("profile")
flush()
loaded = textWidget("Geladene Beute " .. bossItem):GetParent()
assert(loaded.upgrade.textValue == "-5,0 %")
instancePage.tabs.map.scripts.OnClick()
assert(instancePage.rows[1].right.textValue == "1 Upgrade")
app.upgrades = nil
C_Item = nil

for _, key in ipairs({"stratholme_living", "stratholme_undead", "diremaul_north", "maraudon", "zulgurub",
    "ruinsofahnqiraj", "templeofahnqiraj"}) do
    local entry = guide.byKey[key]
    assert(#entry.paths > 0 and #entry.stops > 0, "Built-in route variant missing for " .. key)
end
local living, undead = guide.byKey.stratholme_living, guide.byKey.stratholme_undead
for _, entry in ipairs({living, undead}) do
    guide.Open(entry.key, "map")
    local pin = instancePage.map.pins[1]
    assert(pin:IsVisible() and pin.stop.floor == entry.floors[1] and pin.stop.loot)
    assert(pin.portrait.display == pin.stop.display)
    pin.scripts.OnClick(pin)
    assert(guide.selection.tab == "loot" and guide.selection.boss == pin.stop.loot)
    assert(instancePage.map.lines[1]:IsVisible(), "Selecting boss loot keeps the route on the map")
end
guide.Open("zulgurub", "map")
local fallbackPin = instancePage.map.pins[1]
assert(fallbackPin:IsVisible() and fallbackPin.portrait.textureID:match("UI%-RaidTargetingIcon_8$"))
guide.Open(custom.key, "map")
assert(guide.selection.floor == custom.floors[1])
local guideViewport = instancePage.viewport
guideViewport.scripts.OnMouseWheel(guideViewport, 1)
assert(instancePage.map:GetWidth() == guideViewport:GetWidth() * 1.25)
instancePage.nextFloor.scripts.OnClick()
assert(guide.selection.floor == custom.floors[2])
assert(instancePage.map:GetWidth() == guideViewport:GetWidth() and guideViewport:GetHorizontalScroll() == 0,
    "Switching floors in the guide shows the new floor at its base zoom")
assert(instancePage.map.art[1]:IsShown() and type(instancePage.map.art[1].textureID) == "number")

local collect = app.worldMap.Collect
local guard = app.SecureCall
local travelError
app.worldMap.Collect = function() error("Simulated travel layer failure") end
app.SecureCall = function(_, callback, ...)
    local ok, message = pcall(callback, ...)
    if not ok then
        assert(message:find("Simulated travel layer failure", 1, true), message)
        travelError = true
    end
end
map:SetMapID(1423)
flush()
local stratholme = {}
for index = 1, provider.used do
    local entrance = provider.pins[index].point.dungeon
    if entrance then stratholme[entrance.guideKey] = true end
end
assert(travelError and stratholme.stratholme_living and stratholme.stratholme_undead,
    "Both Stratholme entrances render even if the travel and exploration layer fails")
app.worldMap.Collect, app.SecureCall = collect, guard

local travelProvider = map.providers[2]
local getTaxiNodes = C_TaxiMap.GetTaxiNodesForMap
C_TaxiMap.GetTaxiNodesForMap = function(id)
    if id ~= 1423 then return getTaxiNodes(id) end
    return {
        {name = "Flugpunkt Nord", faction = 1, position = {x = .56, y = .22}},
        {name = "Flugpunkt Süd", faction = 1, position = {x = .58, y = .24}},
    }
end
map.canvasScale = .75
map:SetMapID(1415)
flush()
local overviewGroup
for index = 1, travelProvider.used do
    local pin = travelProvider.pins[index]
    if pin.point.members then overviewGroup = pin; break end
end
assert(overviewGroup and #overviewGroup.point.members == 2, "Overview groups adjacent travel points")
assert(overviewGroup.badge.textureID:match("map_pin%.tga$"))
overviewGroup.scripts.OnClick(overviewGroup, "RightButton")
assert(menu.children["Flugpunkt Nord"] and menu.children["Flugpunkt Süd"])

local canvas = map:GetCanvas()
local originalAfter = C_Timer.After
local afterTransition = {}
C_Timer.After = function(delay, fn)
    if delay == .18 then afterTransition[#afterTransition + 1] = fn
    else originalAfter(delay, fn) end
end
canvas:SetSize(0, 0)
menu.children["Flugpunkt Nord"].callback()
flush()
assert(map:GetMapID() == 1423 and provider.used == 0, "The old overview pins are cleared while the zone canvas is resizing")
canvas:SetSize(700, 500)
map.canvasScale = 1
for _, callback in ipairs(afterTransition) do callback() end
C_Timer.After = originalAfter
flush()
local north, strath
for index = 1, travelProvider.used do
    local pin = travelProvider.pins[index]
    if pin.point.name == "Flugpunkt Nord" then north = pin end
end
for index = 1, provider.used do
    local pin = provider.pins[index]
    if pin.point.dungeon and pin.point.dungeon.guideKey == "stratholme_living" then strath = pin end
end
assert(north and not north.point.members and strath, "Zone redraw restores individual flight points and dungeon entrances")
local layer = assert(provider.layer)
assert(strath:GetParent() == layer and layer:GetParent() == map and layer.clipsChildren,
    "Entrance buttons sit in a separate clipped viewport, outside the map artwork")
assert(north:GetParent() == layer and travelProvider.layer == layer and north:GetFrameLevel() < strath:GetFrameLevel())
assert(layer:GetFrameStrata() == "DIALOG" and strath:GetFrameLevel() > map.BorderFrame:GetFrameLevel())
assert(strath.icon.atlasID == "Dungeon" and not strath.badge:IsShown(), "Use the game's blue dungeon icon")
assert(north.icon.atlasID == "TaxiNode_Horde")
local _, _, _, anchorX, anchorY = strath:GetPoint()
assert(anchorX == strath.point.x * 700 and anchorY == -strath.point.y * 500)
map.canvasScale = 1.8
provider:OnCanvasScaleChanged()
travelProvider:OnCanvasScaleChanged()
local viewport = map.ScrollContainer
viewport.scrollX, viewport.scrollY = 80, 30
provider:OnCanvasPanChanged()
travelProvider:OnCanvasPanChanged()
local _, _, _, zoomedX, zoomedY = strath:GetPoint()
assert(zoomedX == (anchorX - 80) * 1.8 and zoomedY == (anchorY + 30) * 1.8 and strath:GetScale() == 1,
    "Elevated entrances follow viewport zoom and pan without changing icon size")
assert(strath:IsVisible())
local _, _, _, travelX, travelY = north:GetPoint()
assert(travelX == (north.point.x * 700 - 80) * 1.8 and travelY == (30 - north.point.y * 500) * 1.8)
viewport.scrollX = 300
provider:OnCanvasPanChanged()
assert(not strath:IsShown(), "An off-map entrance does not leak beyond the viewport or intercept clicks")
viewport.scrollX, viewport.scrollY = nil, nil
map.canvasScale, C_TaxiMap.GetTaxiNodesForMap = nil, getTaxiNodes

map.canvasScale = 1
map:SetMapID(1445)
flush()
local onyxia
for index = 1, provider.used do
    local pin = provider.pins[index]
    if pin.point.dungeon and pin.point.dungeon.guideKey == "onyxia" then onyxia = pin; break end
end
assert(onyxia and onyxia.icon.atlasID == "Raid" and onyxia:IsVisible())
local getAtlas = C_Texture.GetAtlasInfo
C_Texture.GetAtlasInfo = function(atlas) if atlas ~= "Raid" then return getAtlas(atlas) end end
provider:RefreshAllData()
flush()
assert(onyxia.badge:IsVisible() and onyxia.icon.textureID:match("UI%-RaidTargetingIcon_8$"),
    "Missing stock artwork falls back to Paulchen's entrance symbol")
C_Texture.GetAtlasInfo = getAtlas
app.comfort.SetEnabled("mapPortals", true)
map:SetMapID(1411)
flush()
local seenAtlases = {}
for index = 1, travelProvider.used do
    local pin = travelProvider.pins[index]
    if pin.icon.atlasID then seenAtlases[pin.icon.atlasID] = true end
end
assert(seenAtlases.MagePortalHorde and seenAtlases.TaxiNode_Alliance and seenAtlases.Garr_LevelUpgradeArrow)

app.mapFlightLandmarks = realFlightLandmarks
explored = {}
C_TaxiMap.GetTaxiNodesForMap = function() return {} end
app.comfort.SetEnabled("mapReveal", false)
app.comfort.SetEnabled("mapOtherFaction", false)
fire("MAP_EXPLORATION_UPDATED")
flush()
local function visibleMarker(name, kind)
    for i = 1, travelProvider.used do
        local pin = travelProvider.pins[i]
        if pin:IsVisible() and pin.point.name == name and pin.point.kind == kind then return pin end
    end
end
local orgrimmar = assert(visibleMarker("Orgrimmar, Durotar", "flight"))
assert(orgrimmar:GetParent() == layer and orgrimmar.icon.atlasID == "TaxiNode_Horde" and travelProvider.tileCount == 0,
    "A completely unexplored map still has flight icons when the taxi API returns nothing")
assert(visibleMarker("Undercity", "portal") and map.providers[1].used == 1)
app.comfort.SetEnabled("mapReveal", true)
flush()
assert(visibleMarker("Orgrimmar, Durotar", "flight") and travelProvider.tileCount > 0)
assert(travelProvider.art:GetParent() == canvas and layer:GetFrameLevel() > travelProvider.art:GetFrameLevel())

map:SetMapID(1423)
flush()
local chapel = assert(visibleMarker("Kapelle des hoffnungsvollen Lichts, östliche Pestländer", "flight"))
assert(chapel.point.faction == "Horde" and chapel.point.x > .70 and chapel.point.x < .71)
local count = 0
for _, point in ipairs(app.worldMap.Collect(1423)) do
    if point.kind == "flight" then count = count + 1 end
end
assert(count == 1, "Fallback flight points respect the faction option")
app.comfort.SetEnabled("mapOtherFaction", true)
C_TaxiMap.GetTaxiNodesForMap = function(id)
    if id == 1423 then
        return {{ nodeID = 68, name = "Client flight name", faction = 1, position = {x = .67, y = .48},
            isUndiscovered = true }}
    end
end
fire("TAXI_NODE_STATUS_CHANGED")
flush()
chapel = assert(visibleMarker("Client flight name", "flight"))
assert(chapel.point.x == .67 and chapel.point.note == "Noch nicht entdeckt")
local allianceChapel = assert(visibleMarker("Kapelle des hoffnungsvollen Lichts, östliche Pestländer", "flight"))
assert(allianceChapel.point.faction == "Alliance")
for _, point in ipairs(app.worldMap.Collect(1423)) do
    assert(point.kind ~= "flight" or point.faction ~= "Horde" or point.name == "Client flight name",
        "The native taxi location supersedes the fallback with the same node ID")
end
app.comfort.SetEnabled("mapFlight", false)
flush()
assert(not visibleMarker("Client flight name", "flight") and not allianceChapel:IsVisible())
app.comfort.SetEnabled("mapFlight", true)
C_TaxiMap.GetTaxiNodesForMap = getTaxiNodes
map:SetMapID(1411)
flush()
map.canvasScale = nil

local inDungeon, dungeonID, interiorFloor = false, nil, nil
local outdoorMap, outdoorPosition
local bestMap = C_Map.GetBestMapForUnit
local playerPosition = C_Map.GetPlayerMapPosition
function IsInInstance() return inDungeon, inDungeon and "party" or "none" end
function GetInstanceInfo() return "Test", inDungeon and "party" or "none", nil, nil, nil, nil, nil, dungeonID end
C_Map.GetBestMapForUnit = function() return interiorFloor or outdoorMap or bestMap() end
C_Map.GetPlayerMapPosition = function(id)
    if outdoorMap == id then return outdoorPosition end
    return playerPosition(id)
end
instancePage:Hide()
outdoorMap, outdoorPosition = 1420, { x = .8529, y = .3028 }
fire("PLAYER_LEAVING_WORLD")
inDungeon, dungeonID = true, 189
fire("PLAYER_ENTERING_WORLD")
local entry = guide.CurrentMap()
assert(entry.key == "sm_cathedral", "The last portal identifies an otherwise ambiguous wing")
flush()
textWidget("Scharlachrotes Kloster: Kathedrale")
assert(not layer:IsShown(), "Outdoor entrances do not show on the instance overlay")
local function hasVisibleRoute()
    for _, frame in ipairs(frames) do
        if frame.isRouteLine and frame:IsVisible() then return true end
    end
    return false
end
assert(hasVisibleRoute())
app.comfort.SetEnabled("mapInteriorRoute", false) -- Legacy opt-out must not hide the route.
flush()
assert(hasVisibleRoute())
textWidget("Weltkarte").scripts.OnClick()
assert(not hasVisibleRoute())
assert(layer:IsShown())
textWidget("Instanzkarte").scripts.OnClick()
textWidget("Scharlachrotes Kloster: Kathedrale")
textWidget("Flügel").scripts.OnClick(textWidget("Flügel"))
menu.children["Scharlachrotes Kloster: Bibliothek"].callback()
textWidget("Scharlachrotes Kloster: Bibliothek")
app.comfort.SetEnabled("mapInterior", false)
flush()
for _, frame in ipairs(frames) do
    assert(not (frame:IsVisible() and frame.textValue == "Scharlachrotes Kloster: Bibliothek"))
end
app.comfort.SetEnabled("mapInterior", true)
flush()
map:Hide()
map:Show()
flush()
textWidget("Scharlachrotes Kloster: Bibliothek")
local undead = guide.byKey.stratholme_undead
dungeonID, interiorFloor = undead.id, undead.floors[1]
fire("PLAYER_ENTERING_WORLD")
flush()
local baron
for _, frame in ipairs(frames) do
    if frame:IsVisible() and frame.stop and frame.stop.name == "Baron Rivendare" then baron = frame; break end
end
assert(baron and baron.portrait.display == baron.stop.display and hasVisibleRoute(),
    "Opening the world map inside Stratholme shows the local bosses and route")
local dungeonCanvas = baron:GetParent():GetParent()
local arrow = dungeonCanvas.player
local function updatePosition(canvas) canvas.scripts.OnUpdate(canvas, .06) end
local coords, facing = {x = .28, y = .41}, .3
function GetPlayerFacing() return facing end
local oldPositionAPI = C_Map.GetPlayerMapPosition
C_Map.GetPlayerMapPosition = function(id)
    if id == interiorFloor then return coords end
    return oldPositionAPI(id)
end
updatePosition(dungeonCanvas)
local _, _, _, x, y = arrow:GetPoint()
assert(arrow:IsVisible() and arrow.arrow.rotation == .3 and not arrow.dot:IsShown())
assert(x == .28 * dungeonCanvas:GetWidth() and y == -.41 * dungeonCanvas:GetHeight())
coords, facing = {x = .32, y = .43}, math.pi / 2
updatePosition(dungeonCanvas)
assert(arrow.arrow.rotation == facing and select(4, arrow:GetPoint()) == .32 * dungeonCanvas:GetWidth())
coords = secret
function UnitPosition()
    local rect = guide.floors[interiorFloor].position
    local north = rect[3] - (rect[3] - rect[1]) * .4
    local west = rect[4] - (rect[4] - rect[2]) * .6
    return north, west, 0, dungeonID
end
facing = secret
updatePosition(dungeonCanvas)
assert(arrow:IsVisible() and arrow.dot:IsShown() and not arrow.arrow:IsShown())
assert(math.abs(select(4, arrow:GetPoint()) / dungeonCanvas:GetWidth() - .6) < .0001)
function UnitPosition() return secret, secret, nil, dungeonID end
updatePosition(dungeonCanvas)
assert(not arrow:IsShown(), "Protected position data never produces a stale marker")
assert(not dungeonCanvas.roomStatus:IsShown(), "The map stays clear when there is no position or room name")
local room = undead.rooms[1]
local subzone = room.de
function GetSubZoneText() return subzone end
updatePosition(dungeonCanvas)
local roomLine = dungeonCanvas.roomLayer.lines[1]
assert(not arrow:IsShown() and roomLine:IsVisible() and dungeonCanvas.roomStatus:IsVisible(),
    "A reported room has a footprint when the client withholds exact coordinates")
assert(dungeonCanvas.roomStatus.text.textValue == "Bereich · " .. room.de)
subzone = secret
updatePosition(dungeonCanvas)
assert(not roomLine:IsShown() and not dungeonCanvas.roomStatus:IsShown(),
    "A missing or protected room name clears the last outline")
subzone = room.name
coords, facing = {x = .31, y = .42}, .7
fire("BOSS_KILL", baron.stop.encounters[1])
flush()
assert(arrow:IsVisible() and not dungeonCanvas.roomStatus:IsShown() and not roomLine:IsShown(),
    "Live coordinates take priority over the room outline")
assert(baron.check:IsVisible() and baron.portrait.desaturated)
baron.scripts.OnClick(baron)
assert(guide.selection.entry == undead and guide.selection.boss == "Baron Rivendare")
assert(instancePage:IsVisible() and instancePage.map.lines[1]:IsVisible())
assert(instancePage.map.player:IsVisible() and instancePage.map.player.arrow.rotation == .7)
local mines = guide.byKey.deadmines
dungeonID, interiorFloor = mines.id, mines.floors[1]
map:Show()
fire("PLAYER_ENTERING_WORLD")
flush()
assert(dungeonCanvas.positionFloor == mines.floors[1])
interiorFloor = mines.floors[2]
updatePosition(dungeonCanvas)
assert(dungeonCanvas.positionFloor == mines.floors[2] and arrow:IsVisible(),
    "The world map follows a known floor change while walking")
interiorFloor, coords, subzone = nil, secret, "Mast Room"
updatePosition(dungeonCanvas)
assert(dungeonCanvas.positionFloor == mines.floors[1] and not arrow:IsShown())
assert(dungeonCanvas.roomStatus.text.textValue == "Bereich · Mastraum" and dungeonCanvas.roomLayer.lines[1]:IsShown(),
    "A named subzone can also move the instance view to the right floor without coordinates")
dungeonID, subzone = 189, "Gallery of Treasures"
fire("ZONE_CHANGED_INDOORS")
flush()
assert(dungeonCanvas.positionEntry.key == "sm_library" and dungeonCanvas.roomLayer.lines[1]:IsVisible(),
    "A room unique to one wing identifies that wing when the native map ID is missing")

local home = CreateFrame("Frame", nil, UIParent)
Minimap = CreateFrame("Minimap", nil, home)
Minimap:SetSize(198, 198)
Minimap:SetPoint("CENTER", home, "CENTER", 12, -8)
guide.UpdateWorldOverlay(map)
local viewport = dungeonCanvas:GetParent()
assert(viewport.scrollChild == dungeonCanvas, "Native scroll viewport clips the zoomed floor")
local width, height = viewport:GetSize()
local routeX, routeY = unpack(dungeonCanvas.lines[1].startPoint, 3, 4)
viewport.left, viewport.top, viewport.effectiveScale = 80, 550, .8
local pointX, pointY = width * .4, height * .25
cursorX = (viewport.left + pointX) * viewport.effectiveScale
cursorY = (viewport.top - pointY) * viewport.effectiveScale
viewport.scripts.OnMouseWheel(viewport, 1)
assert(dungeonCanvas:GetWidth() == width * 1.25 and dungeonCanvas:GetHeight() == height * 1.25)
assert(math.abs(viewport:GetHorizontalScroll() - .25 * pointX) < .001)
assert(math.abs(viewport:GetVerticalScroll() - .25 * pointY) < .001)
local pin = dungeonCanvas.pins[1]
local _, _, _, px, py = pin:GetPoint()
assert(pin:IsVisible() and px == pin.stop.x * dungeonCanvas:GetWidth() and py == -pin.stop.y * dungeonCanvas:GetHeight())
assert(dungeonCanvas.lines[1]:IsVisible() and dungeonCanvas.roomStatus:GetParent() == viewport)
local zoomedRouteX, zoomedRouteY = unpack(dungeonCanvas.lines[1].startPoint, 3, 4)
assert(math.abs(zoomedRouteX - routeX * 1.25) < .001 and math.abs(zoomedRouteY - routeY * 1.25) < .001)
guide.UpdateWorldOverlay(map)
assert(dungeonCanvas:GetWidth() == width * 1.25, "Refreshing the same indoor map preserves the zoom")

local startX, startY = viewport:GetHorizontalScroll(), viewport:GetVerticalScroll()
mouseDown = true
viewport.scripts.OnMouseDown(viewport, "LeftButton")
cursorX, cursorY = cursorX - 20, cursorY + 16
viewport.scripts.OnUpdate(viewport)
assert(math.abs(viewport:GetHorizontalScroll() - startX - 25) < .001)
assert(math.abs(viewport:GetVerticalScroll() - startY - 20) < .001)
cursorX, cursorY = cursorX - 5000, cursorY + 5000
viewport.scripts.OnUpdate(viewport)
assert(viewport:GetHorizontalScroll() == dungeonCanvas:GetWidth() - width)
assert(viewport:GetVerticalScroll() == dungeonCanvas:GetHeight() - height)
mouseDown = false
viewport.scripts.OnUpdate(viewport)
assert(not viewport.scripts.OnUpdate, "Releasing the mouse outside the viewport stops the drag")

for _ = 1, 12 do viewport.scripts.OnMouseWheel(viewport, 1) end
assert(dungeonCanvas:GetWidth() == width * 4, "The zoom is limited to 4x")
local center = (viewport:GetHorizontalScroll() + width / 2) / dungeonCanvas:GetWidth()
local hostWidth, hostHeight = map.ScrollContainer:GetSize()
map.ScrollContainer:SetSize(hostWidth, hostHeight - 60)
guide.UpdateWorldOverlay(map)
assert(dungeonCanvas:GetWidth() == viewport:GetWidth() * 4)
assert(math.abs((viewport:GetHorizontalScroll() + viewport:GetWidth() / 2) / dungeonCanvas:GetWidth() - center) < .001)
for _ = 1, 12 do viewport.scripts.OnMouseWheel(viewport, -1) end
assert(dungeonCanvas:GetWidth() == viewport:GetWidth() and dungeonCanvas:GetHeight() == viewport:GetHeight())
assert(viewport:GetHorizontalScroll() == 0 and viewport:GetVerticalScroll() == 0)

map.ScrollContainer:SetSize(hostWidth, hostHeight)
guide.UpdateWorldOverlay(map)
local _, target, _, offsetX, offsetY = Minimap:GetPoint()
assert(Minimap:GetParent() == home and target == home and offsetX == 12 and offsetY == -8)
assert(Minimap:GetWidth() == 198 and Minimap:GetHeight() == 198)
Minimap = nil

assert(overrides.M, "The native world-map key is redirected in a known instance")
mapKey("M")
assert(not map:IsShown() and instancePage:IsVisible() and guide.selection.entry.key == "sm_library"
    and guide.selection.tab == "map" and instancePage.map.lines[1]:IsVisible())
mapKey("M")
assert(not instancePage:IsVisible() and not map:IsShown(), "The map key closes Paulchen's open map")
mapKey("M")
local area = guide.selection.entry.entrance[1]
instancePage.worldMap.scripts.OnClick()
flush()
assert(map:IsShown() and layer:IsShown() and not instancePage:IsVisible() and map:GetMapID() == area,
    "The World Map button opens the outdoor zone and restores the outdoor markers")
mapKey("M")
assert(instancePage:IsVisible() and not map:IsShown(), "The map key returns from the outdoor map to Paulchen")
mapKeys = { "ALT-M", "SHIFT-M" }
fire("UPDATE_BINDINGS")
assert(not overrides.M and overrides["ALT-M"] and overrides["SHIFT-M"])
mapKey("ALT-M")
assert(not instancePage:IsVisible())
app.comfort.SetEnabled("mapInterior", false)
assert(not next(overrides))
mapKey("ALT-M")
assert(map:IsShown())
mapKey("ALT-M")
combat = true
app.comfort.SetEnabled("mapInterior", true)
assert(not next(overrides), "Changing the binding waits until combat ends")
combat = false
fire("PLAYER_REGEN_ENABLED")
assert(overrides["ALT-M"])
dungeonID = -1
fire("PLAYER_ENTERING_WORLD")
assert(not next(overrides))

C_Map.GetPlayerMapPosition = oldPositionAPI
GetPlayerFacing, UnitPosition, GetSubZoneText = nil, nil, nil
inDungeon, dungeonID, interiorFloor, outdoorMap = false, nil, nil, nil
fire("PLAYER_ENTERING_WORLD")
flush()
assert(not guide.CurrentMap())
assert(not next(overrides), "The native bindings have been restored outside instances")
mapKey("ALT-M")
assert(map:IsShown() and not instancePage:IsVisible())

app.upgrades = { gear = { SkillRank = function() return nil end } }
''')
for path in ("Modules/Upgrades/Content.lua", "Modules/Upgrades/Sources.lua"):
    load((root / path).read_text(encoding="utf-8-sig"), path)
lua.execute(r'''
local scan = { faction = "Horde", level = 60, playerLevel = 60 }
app.upgrades.PrepareSources(scan)
local drop = assert(scan.atlas.items[6473], "Wailing Caverns loot should be available without AtlasLoot")
assert(drop[1].location.instanceID == 43 and #app.upgrades.GetSources(scan, 6473) > 0)
assert(not app.upgrades.CanSearchItem(scan, 17063), "The standalone loot index respects locked raids")
assert(next(scan.instanceQuestRewards), "The standalone quest reward index is populated")
''')
print("Standalone instance guide, Stratholme markers, map switching, wings, routes, and loot passed with all three addons absent.")
