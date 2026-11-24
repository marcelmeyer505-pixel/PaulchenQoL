-- Minimal in-memory Forever/Polestar fixture. Run: lua5.1 tests/dungeon_quest_fixture.lua
local app = {
    style = {},
    Readable = function(value) return value end,
    GetLanguage = function() return "deDE" end,
    RegisterSupported = function() return true end,
}
_G.CreateFrame = function()
    return {
        SetScript = function() end,
        RegisterEvent = function() end,
    }
end
_G.UnitFactionGroup = function() return "Horde" end
_G.UnitLevel = function() return 60 end
local done = { [101] = true }
local active = { [103] = true }
_G.C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return done[id] == true end,
    IsOnQuest = function(id) return active[id] == true end,
    ReadyForTurnIn = function(id) return false end,
}
local rows = {
    { id = 103, title = "Third step", faction = "H", chain = { 101, 102 },
        start = { kind = "npc", name = "Quest NPC", map = 1, x = 0.5, y = 0.6 },
        finish = { kind = "npc", name = "Turn-in NPC", map = 1, x = 0.4, y = 0.8 } },
    { id = 104, title = "Fourth step", faction = "H", chain = { 101, 102, 103 },
        start = { kind = "npc", name = "Quest NPC 2", map = 1, x = 0.5, y = 0.6 } },
    { id = 105, title = "Alliance step", faction = "A", chain = {} },
}
local all = {}
for _, q in ipairs(rows) do all[q.id] = q end
all[101] = { id = 101, title = "First step", start = {kind = "npc", name = "Intro NPC"} }
all[102] = { id = 102, title = "Second step", start = {kind = "npc", name = "Second NPC"} }

_G.Polestar = {
    Dungeons = {
        Load = function() return true end,
        List = function() return { {key = "sample", name = "Sample Dungeon"} } end,
        Quests = function(_, faction)
            local out = {}
            for _, q in ipairs(rows) do
                if not q.faction or q.faction == faction then out[#out + 1] = q end
            end
            return out
        end,
        Quest = function(_, id) return all[id] end,
    },
    Codex = {
        Quest = function(id)
            if id == 104 then return {pre = {103}} end
            if id == 103 then return {pre = {102}} end
            return {}
        end
    }
}

local chunk, err = loadfile("DungeonQuests.lua")
assert(chunk, err)
chunk("PaulchenQoL", app)

local planner = assert(app.dungeonQuests)
local list = assert(planner.ListDungeons())
assert(#list == 1)
local result = assert(planner.Build("sample"))
assert(result.total == 2, "Faction filtering must exclude Alliance-only quests")
assert(result.active == 1 and result.done == 0)
assert(result.quests[1].status == "ACTIVE")
assert(result.quests[2].status == "LOCKED", "Quest 104 waits for 103")
local chain, completed = planner.Chain(104, result)
assert(#chain == 4 and completed == 1, "Chain should include predecessors and completion progress")
assert(chain[1].id == 101 and chain[4].id == 104)
assert(chain[1].status == "DONE")
assert(chain[2].status == "NOT_STARTED")
assert(chain[3].status == "ACTIVE")

done[102] = true
active[103] = nil
local update = assert(planner.Build("sample"))
assert(update.quests[1].status == "NOT_STARTED")
assert(update.quests[2].status == "LOCKED")
active[103] = true
_G.C_QuestLog.ReadyForTurnIn = function(id) return id == 103 end
assert(planner.Build("sample").quests[1].status == "READY")

_G.Polestar = nil
local none, reason = planner.ListDungeons()
assert(none == nil and reason == "missing", "Optional provider must fail safely")
print("Dungeon quest planner fixture passed.")
