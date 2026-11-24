-- Self-contained dungeon quest planner regression tests (Lua 5.1).
-- No Polestar globals/addon/quest data are loaded. Run from repo root.
local characterDB = {}
local app = {
    style = {},
    Readable = function(v) return v end,
    GetLanguage = function() return "deDE" end,
    RegisterSupported = function() return true end,
    Settings = function() return characterDB end,
}
_G.Polestar = nil
local frames = {}
_G.CreateFrame = function()
    local f = { RegisterEvent=function() end }
    f.SetScript = function(self, event, fn) self[event] = fn end
    frames[#frames+1] = f
    return f
end
_G.UnitFactionGroup = function() return "Horde" end
_G.UnitLevel = function() return 60 end
_G.UnitClass = function() return "Druid", "DRUID", 11 end
local done = {}
local active = {}
local ready = {}
_G.C_QuestLog = {
    GetTitleForQuestID = function(id) return "Test Quest " .. id end,
    IsQuestFlaggedCompleted = function(id) return done[id] == true end,
    IsOnQuest = function(id) return active[id] == true end,
    ReadyForTurnIn = function(id) return ready[id] == true end,
}
local function loadAddon(path)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    chunk("PaulchenQoL", app)
end

loadAddon("Data/DungeonSeedDungeons.lua")
loadAddon("Data/DungeonSeedQuests.lua")
loadAddon("Data/DungeonSeedPlaces.lua")
loadAddon("Data/DungeonQuestHints.lua")
loadAddon("DungeonQuestProvider.lua")
loadAddon("DungeonQuests.lua")

local provider = assert(app.DungeonQuestData)
assert(provider.Load() == true)
local dungeons = provider.List()
assert(#dungeons == 35, "35 bundled dungeons / wings expected")
assert(#(app.dungeonQuestSeed.quests or {}) == 0, "quest data is keyed, not an array")
local questCount, placeCount, references = 0, 0, 0
for _ in pairs(app.dungeonQuestSeed.quests) do questCount = questCount + 1 end
for _ in pairs(app.dungeonQuestSeed.places) do placeCount = placeCount + 1 end
for _, d in ipairs(app.dungeonQuestSeed.dungeons) do references = references + #(d.quests or {}) end
assert(questCount == 480 and placeCount == 309 and references == 395,
    "MIT seed counts changed unexpectedly")

assert(#provider.Quests("ALCAZ", "H") == 0, "known missing Forever catalog remains empty")
assert(provider.Quests("BRD", "H")[1], "BRD Horde quests should exist")
local function contains(quests, wanted)
    for _, q in ipairs(quests) do if q.id == wanted then return q end end
end
local horde = provider.Quests("BRD", "H")
local alliance = provider.Quests("BRD", "A")
assert(contains(horde, 4082), "BRD Horde kill-on-sight quest missing")
assert(not contains(alliance, 4082), "Horde-only quest shown to Alliance")
assert(contains(alliance, 4126), "BRD Alliance quest missing")
assert(not contains(horde, 4126), "Alliance-only quest shown to Horde")

local reference = assert(provider.Quest("BRD", 4082))
assert(reference.title == "Test Quest 4082")
assert(reference.faction == "H")
assert(type(reference.givers) == "table" and #reference.givers > 0)
assert(type(reference.start.name) == "string")
local westfallQuest = assert(provider.Quest("DM", 166))
assert(westfallQuest.start and westfallQuest.start.map == 1436, "Deadmines quest giver map")
assert(math.abs(westfallQuest.start.x - 0.562) < 0.00001, "Waypoints need 0..1 coordinates")
local waypoint
_G.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return {map=map, x=x, y=y} end }
_G.C_Map = { SetUserWaypoint = function(point) waypoint=point end }
assert(provider.GuideToPoint(westfallQuest.start) == true)
assert(waypoint and waypoint.map == 1436 and math.abs(waypoint.x - 0.562) < 0.00001)

-- NPCs inside dungeons are known, but must not have invented outdoor coordinates.
local thaelrid = assert(provider.Quest("BFD", 6561))
assert(thaelrid.start.kind == "npc" and thaelrid.start.id == 4787)
assert(thaelrid.start.inside and thaelrid.start.map == nil)
assert(provider.RecordSighting(6561, "giver", 99999, "Wrong NPC", 1440, 0.45, 0.4) == false)
assert(provider.RecordSighting(6561, "giver", 4787, "Argent Guard Thaelrid", 1440, 0.45, 0.40))
assert(characterDB.dungeonQuestLocations[6561].giver.id == 4787)
local observed = assert(provider.Quest("BFD", 6561)).start
assert(observed.map == 1440 and observed.observed and observed.x == 0.45)

-- A low-confidence Classic coordinate is shown only as a reference.
local bodley = assert(provider.Quest("DM_E", 8994)).start
assert(bodley.id == 16033 and bodley.map == 1428 and bodley.referenceOnly)
assert(provider.RecordSighting(8994, "giver", 16033, "Bodley", 1428, 0.324, 0.259))
local confirmed = assert(provider.Quest("DM_E", 8994)).start
assert(confirmed.observed and not confirmed.referenceOnly)
assert(math.abs(confirmed.x - 0.324) < 0.00001)

-- The optional live observation hook reads quest ID, NPC and map coordinates.
_G.GetQuestID = function() return 6561 end
_G.UnitExists = function(unit) return unit == "npc" end
_G.UnitGUID = function() return "Creature-0-0-0-0-4787-00000ABC" end
_G.UnitName = function() return "Argent Guard Thaelrid" end
_G.C_Map.GetBestMapForUnit = function() return 1440 end
_G.C_Map.GetPlayerMapPosition = function()
    return { GetXY=function() return 0.51, 0.55 end }
end
for _, f in ipairs(frames) do
    if f.OnEvent then f:OnEvent("QUEST_DETAIL") end
end
assert(characterDB.dungeonQuestLocations[6561].giver.x == 0.51)
local chainSource = provider.Quest("WC", 914)
assert(chainSource and #chainSource.chain == 3)
assert(provider.Prerequisites(914)[1] == 1489)

local planner = assert(app.dungeonQuests)
local built = assert(planner.Build("BRD"))
assert(built.total > 15 and built.done == 0)
assert(contains(built.quests, 4082).status == "NOT_STARTED")
done[4082] = true
assert(contains(assert(planner.Build("BRD")).quests, 4082).status == "DONE")
done[4082] = nil
active[4082] = true
assert(contains(assert(planner.Build("BRD")).quests, 4082).status == "ACTIVE")
ready[4082] = true
assert(contains(assert(planner.Build("BRD")).quests, 4082).status == "READY")

local caverns = assert(planner.Build("WC"))
local quest = assert(contains(caverns.quests, 914))
assert(quest.status == "LOCKED", "chain predecessors are not yet complete")
done[1489], done[1490] = true, true
assert(contains(assert(planner.Build("WC")).quests, 914).status == "NOT_STARTED")
local chain, completed = planner.Chain(914, planner.Build("WC"))
assert(#chain == 3 and completed == 2)
assert(chain[1].id == 1489 and chain[3].id == 914)

assert(planner.ListDungeons(), "planner must work with Polestar=nil")
print("Standalone dungeon planner passed: " .. #dungeons .. " dungeons, " ..
    references .. " quest references, " .. questCount .. " quests, " .. placeCount .. " places.")
