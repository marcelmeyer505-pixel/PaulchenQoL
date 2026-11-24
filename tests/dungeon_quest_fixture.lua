-- Self-contained dungeon quest planner regression tests (Lua 5.1).
-- No Polestar globals/addon/quest data are loaded. Run from repo root.
local app = {
    style = {},
    Readable = function(v) return v end,
    GetLanguage = function() return "deDE" end,
    RegisterSupported = function() return true end,
}
_G.Polestar = nil
_G.CreateFrame = function() return { SetScript=function() end, RegisterEvent=function() end } end
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
