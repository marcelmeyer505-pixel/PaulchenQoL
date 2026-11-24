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

for path in ("Modules/Instances/Data.lua", "Modules/Instances/Guide.lua", "Modules/Instances/Window.lua"):
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
textWidget("Quests").scripts.OnClick()
textWidget("Instanzquests")
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
instancePage.nextFloor.scripts.OnClick()
assert(guide.selection.floor == custom.floors[2])
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
assert(dungeonCanvas.roomStatus.text.textValue == "Position nicht verfügbar")
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
assert(not roomLine:IsShown() and dungeonCanvas.roomStatus.text.textValue == "Position nicht verfügbar",
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
Minimap:SetScale(.92)
Minimap:SetFrameStrata("LOW")
Minimap:SetFrameLevel(12)
Minimap:SetPoint("CENTER", home, "CENTER", 12, -8)
function Minimap:GetZoom() return self.zoom or 3 end
function Minimap:SetZoom(zoom) self.zoom = zoom end
function Minimap:CanChangeProtectedState() return not combat end
MinimapBackdrop = CreateFrame("Frame", nil, Minimap)
MinimapBackdrop:SetAlpha(.85)
PaulchenQoLMinimapButton = CreateFrame("Button", nil, Minimap)
local launcher = CreateFrame("Button", nil, Minimap)
function launcher:GetName() return "LibDBIcon10_Test" end
local north = false
C_Minimap = {
    IsRotateMinimapIgnored = function() return north end,
    SetIgnoreRotateMinimap = function(value) north = value end,
    GetViewRadius = function() return 120 end,
    GetUiMapID = function() return interiorFloor end,
}
function GetCVarBool(name) assert(name == "rotateMinimap"); return true end
local function restoreChecked()
    local point, anchor, relative, x, y = Minimap:GetPoint()
    assert(Minimap:GetParent() == home and not north and Minimap:GetScale() == .92)
    assert(Minimap:GetWidth() == 198 and Minimap:GetHeight() == 198 and Minimap:GetZoom() == 3)
    assert(Minimap:GetFrameStrata() == "LOW" and Minimap:GetFrameLevel() == 12 and Minimap:IsVisible())
    assert(point == "CENTER" and anchor == home and relative == "CENTER" and x == 12 and y == -8)
    assert(MinimapBackdrop:GetAlpha() == .85 and PaulchenQoLMinimapButton:IsShown() and launcher:IsShown())
end
guide.UpdateWorldOverlay(map)
local liveSwitch = textWidget("Live-Minimap")
local fullWidth = dungeonCanvas:GetWidth()
liveSwitch.scripts.OnClick()
local dock = Minimap:GetParent()
assert(dock ~= home and Minimap:IsVisible() and north and Minimap:GetWidth() > 198 and Minimap:GetZoom() == 0)
assert(not dungeonCanvas:IsVisible() and liveSwitch.textValue == "Routenkarte",
    "The live view never shows the floor map beside the minimap")
assert(MinimapBackdrop:GetAlpha() == 0 and not PaulchenQoLMinimapButton:IsShown() and not launcher:IsShown())
Minimap:SetZoom(1)
textWidget("Ganze Etage").scripts.OnClick()
restoreChecked()
assert(dungeonCanvas:IsVisible() and dungeonCanvas:GetWidth() == fullWidth and dungeonCanvas.lines[1]:IsVisible())
assert(liveSwitch.textValue == "Zur Live-Minimap")
local artFloor = guide.floors[dungeonCanvas.positionFloor]
assert(dungeonCanvas.art[1].textureID == artFloor.art[1][1], "The full-floor view uses the local minimap artwork")
local firstTexture = dungeonCanvas.art[1]
local setTexture = firstTexture.SetTexture
local missing = {}
for _, part in ipairs(artFloor.art) do missing[part[1]] = true end
function firstTexture:SetTexture(file, ...)
    if missing[file] then return false end
    return setTexture(self, file, ...)
end
guide.UpdateWorldOverlay(map)
assert(firstTexture.textureID == artFloor.tiles[1] and dungeonCanvas.pins[1]:IsVisible(),
    "Unavailable minimap assets fall back to normal art with all boss pins intact")
firstTexture.SetTexture = nil
guide.UpdateWorldOverlay(map)
assert(firstTexture.textureID == artFloor.art[1][1] and dungeonCanvas.pins[1]:IsVisible())
liveSwitch.scripts.OnClick()
assert(not dungeonCanvas:IsVisible() and Minimap:GetParent() == dock and Minimap:GetZoom() == 1,
    "Returning from the floor view preserves the live zoom")
local boss = dungeonCanvas.positionEntry.stops[1]
interiorFloor, coords = boss.floor, {x = boss.x, y = boss.y}
guide.UpdateWorldOverlay(map)
local projected
for _, frame in ipairs(dock.children) do
    if frame.pins and frame.lines then projected = frame; break end
end
assert(projected and projected:IsVisible() and projected.pins[1].stop == boss)
assert(select(2, projected.pins[1]:GetPoint()) == Minimap and select(4, projected.pins[1]:GetPoint()) == 0)
assert(projected.lines[1]:IsVisible())
for _, line in ipairs(projected.lines) do
    if line:IsShown() then
        for _, endpoint in ipairs({line.startPoint, line.endPoint}) do
            assert(endpoint[2] == Minimap and endpoint[3] ^ 2 + endpoint[4] ^ 2 <= (Minimap:GetWidth() / 2) ^ 2)
        end
    end
end
coords = {x = boss.x + .003, y = boss.y}
dock.scripts.OnUpdate(dock, .11)
assert(projected.pins[1].stop == boss and select(4, projected.pins[1]:GetPoint()) < 0,
    "Moving east shifts the projected boss west on the north-up minimap")
coords = secret
dock.scripts.OnUpdate(dock, .11)
assert(not projected:IsShown() and not dungeonCanvas:IsVisible(),
    "Unavailable coordinates never open an unsolicited second map")
local speed = 0
function GetUnitSpeed() return speed end
function dungeonCanvas:GetEffectiveScale() return .8 end
function dungeonCanvas:GetLeft() return 70 end
function dungeonCanvas:GetTop() return 500 end
function GetCursorPosition()
    return (70 + boss.x * dungeonCanvas:GetWidth()) * .8, (500 - boss.y * dungeonCanvas:GetHeight()) * .8
end
local function settingPosition()
    textWidget("Position setzen").scripts.OnClick()
    assert(dungeonCanvas:IsVisible() and Minimap:GetParent() == home)
    for _, child in ipairs(dungeonCanvas.children) do
        if child:IsVisible() and child.scripts.OnClick then return child end
    end
    error("Missing position picker")
end
local picker = settingPosition()
fire("PLAYER_STARTED_MOVING")
picker.scripts.OnClick()
assert(dungeonCanvas:IsVisible(), "A moving player cannot set a stationary reference")
fire("PLAYER_STOPPED_MOVING")
picker.scripts.OnClick()
assert(Minimap:GetParent() == dock and not dungeonCanvas:IsVisible() and projected:IsVisible())
assert(projected.pins[1].stop == boss and math.abs(select(4, projected.pins[1]:GetPoint())) < .001)
assert(textWidget("Manuell ausgerichtet"):IsVisible())
map:Hide()
restoreChecked()
map:Show()
flush()
assert(projected:IsVisible(), "The manual alignment survives closing the map while standing still")
fire("PLAYER_STARTED_MOVING")
assert(not projected:IsShown() and not dungeonCanvas:IsVisible(), "Moving clears the manual alignment")
fire("PLAYER_STOPPED_MOVING")
picker = settingPosition()
picker.scripts.OnClick()
assert(projected:IsVisible())
speed = 1
dock.scripts.OnUpdate(dock, .11)
assert(not projected:IsShown(), "A readable speed can also invalidate the manual position")
speed = 0
Minimap:SetZoom(2)
local hostWidth, hostHeight = map.ScrollContainer:GetSize()
map.ScrollContainer:SetSize(hostWidth, hostHeight - 50)
guide.UpdateWorldOverlay(map)
assert(Minimap:GetParent() == dock and Minimap:GetZoom() == 2, "Resizing the live view keeps its destination and zoom")
map.ScrollContainer:SetSize(hostWidth, hostHeight)
liveSwitch.scripts.OnClick()
restoreChecked()
assert(dungeonCanvas:IsVisible() and dungeonCanvas:GetWidth() == fullWidth)
assert(dungeonCanvas.art[1].textureID == artFloor.tiles[1], "The normal route tab retains its original artwork")

liveSwitch.scripts.OnClick()
textWidget("Weltkarte").scripts.OnClick()
restoreChecked()
textWidget("Instanzkarte").scripts.OnClick()
assert(Minimap:GetParent() == dock and north)
map:Hide()
restoreChecked()
map:Show()
flush()
assert(Minimap:GetParent() == dock and north, "Reopening the indoor map remembers its live mode")
combat = true
map:Hide()
assert(not Minimap:IsVisible() and Minimap:GetParent() == dock)
combat = false
fire("PLAYER_REGEN_ENABLED")
restoreChecked()
map:Show()
flush()
liveSwitch.scripts.OnClick()
combat = true
liveSwitch.scripts.OnClick()
restoreChecked()
assert(dungeonCanvas:IsVisible(), "An unavailable Minimap leaves the route view and the HUD in place")
combat = false
Minimap, C_Minimap, GetCVarBool, GetUnitSpeed, GetCursorPosition = nil, nil, nil, nil, nil
MinimapBackdrop, PaulchenQoLMinimapButton = nil, nil

C_Map.GetPlayerMapPosition = oldPositionAPI
GetPlayerFacing, UnitPosition, GetSubZoneText = nil, nil, nil
inDungeon, dungeonID, interiorFloor, outdoorMap = false, nil, nil, nil
fire("PLAYER_ENTERING_WORLD")
flush()
assert(not guide.CurrentMap())

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
