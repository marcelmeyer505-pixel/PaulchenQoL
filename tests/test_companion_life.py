"""Exercise the companion in simulated Lua 5.1 game sessions."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / "lua_runtime"))
from lupa.lua51 import LuaRuntime, lua_type


SETUP = r'''
app, timers, frames, spoken, reminders = {}, {}, {}, {}, {}
now, server, speed, zone, durability, free = 1000, 200000, 0, "Durotar", 100, 10
combat, encounter, dead, afk, mounted, flying, resting = false, false, false, false, false, false, false
repairable, groupSize, instance = false, 3, "party"
quality, bind, auctionPrice, priceSource = 1, 2, nil, nil
secret = {}
function issecretvalue(value) return value == secret end
function GetTime() return now end
function GetServerTime() return server + math.floor(now) end
function GetRealZoneText() return zone end
function UnitLevel() return 52 end
function UnitClass() return "Druid", "DRUID" end
function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
function IsEncounterInProgress() return encounter end
function UnitIsDeadOrGhost() return dead end
function UnitIsAFK() return afk end
function GetUnitSpeed() return speed end
function UnitOnTaxi() return flying end
function IsFlying() return flying end
function IsMounted() return mounted end
function IsResting() return resting end
function CanMerchantRepair() return repairable end
function GetInventoryItemLink(_, slot) if slot == 1 then return equipped or "item:900" end end
function GetInventoryItemDurability(slot)
    if slot == 1 then return durability, 100 end
end
function IsInInstance() return instance ~= "none", instance end
function GetNumGroupMembers() return groupSize end
function IsInRaid() return false end
function UnitGUID(unit) return "player-" .. unit end
function GetReadyCheckStatus(unit) return unit == "player" and "ready" or "waiting" end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
    GetContainerNumFreeSlots = function() return free, 0 end,
}
C_Item = { GetItemInfo = function(link)
    return "Test item", link, quality, 60, 1, "", "", 1, "", 1, 0, 4, 0, bind
end }
LOOT_ITEM_SELF = "Ihr erhaltet Beute: %s."
LOOT_ITEM_SELF_MULTIPLE = "Ihr erhaltet Beute: %1$s x%2$d."
function app.GetAuctionPrice() return auctionPrice, priceSource end
function app.BootCompanion() end
function app.RenderCompanion() end
function app.SetCompanionReminder(key, value) reminders[key] = value end
SlashCmdList = {}
function CreateFrame()
    local f = {events = {}}
    function f:RegisterEvent(name) self.events[name] = true end
    function f:RegisterUnitEvent(name, unit) self.events[name] = unit end
    function f:SetScript(_, callback) self.onEvent = callback end
    frames[#frames + 1] = f
    return f
end
function fire(event, ...)
    for _, frame in ipairs(frames) do
        local unit = frame.events[event]
        if unit == true or unit == select(1, ...) and unit then frame.onEvent(frame, event, ...) end
    end
end
C_Timer = { NewTimer = function(delay, fn)
    local t = {at = now + delay, run = fn}
    function t:Cancel() self.cancelled = true end
    timers[#timers + 1] = t
    return t
end }
C_Timer.After = C_Timer.NewTimer
function advance(seconds)
    local endAt = now + seconds
    for _ = 1, 7500 do
        local chosen
        for index, t in ipairs(timers) do
            if not t.cancelled and t.at <= endAt and (not chosen or t.at < timers[chosen].at) then chosen = index end
        end
        if not chosen then now = endAt; return end
        local t = table.remove(timers, chosen)
        now = t.at
        t.run()
    end
    error("companion timers failed to settle")
end
function liveTimers()
    local count = 0
    for _, t in ipairs(timers) do if not t.cancelled then count = count + 1 end end
    return count
end
function latest() return spoken[#spoken] and spoken[#spoken].category end
function count(category)
    local n = 0
    for _, entry in ipairs(spoken) do if entry.category == category then n = n + 1 end end
    return n
end
function enter(initial, reload)
    fire("PLAYER_LOGIN")
    fire("PLAYER_ENTERING_WORLD", initial, reload)
end
math.randomseed(349)
'''


def copy(value, lua):
    if lua_type(value) == "table":
        return lua.table_from({key: copy(entry, lua) for key, entry in value.items()})
    return value


def runtime(previous=None, elapsed=2, life=True):
    lua = LuaRuntime()
    lua.execute(SETUP)
    if previous:
        for key in ("PaulchenQoLDB", "PaulchenQoLSettings"):
            lua.globals()[key] = copy(previous.globals()[key], lua)
        lua.globals().now = previous.globals().now + elapsed
    files = ["Core.lua", "Memory.lua", "Dialogue.lua", "Personality.lua", "Config.lua"]
    if life:
        files += ["CompanionLife.lua", "Events.lua"]
    load = lua.eval('function(code, name) assert(loadstring(code, "@" .. name))("PaulchenQoL", app) end')
    for path in files:
        load((root / path).read_text(encoding="utf-8-sig"), path)
    lua.execute(r'''
    local remember = app.RememberComment
    function app.RememberComment(key, text, category, ambient)
        spoken[#spoken + 1] = {key = key, text = text, category = category, ambient = ambient, at = now}
        remember(key, text, category, ambient)
    end
    local secureCall = app.SecureCall
    function app.SecureCall(label, callback, ...)
        assert(secureCall(label, callback, ...), label .. " failed")
        return true
    end
    ''')
    return lua


pools = runtime(life=False)
pools.execute(r'''
PaulchenQoLSettings = {sarcasm = 3, frequency = 2}
local profile = app.Profile()
assert(profile.sarcasm == nil and profile.frequency == 2)
for _, category in ipairs({"buffMissing", "buffReady", "login", "level", "death", "revive",
    "zone", "quest", "afk", "back", "bags", "idle"}) do
    local seen, previous = {}, nil
    assert(#app.Dialogue[category] == 15)
    for _ = 1, 19 do
        advance(310)
        app.React(category, {zone="Durotar", level=55, free=3, name="Test", buff="Wildnis"})
        local entry = spoken[#spoken]
        assert(entry.category == category and entry.text ~= previous and not entry.text:find("{", 1, true), category)
        previous = entry.text
        seen[entry.key] = true
    end
    for index = 1, 15 do assert(seen[category .. ":" .. index], category .. ":" .. index) end
end
assert(#app.Memory().recent == 40)
print("Every line in the 12 legacy pools is reachable. Legacy settings and bounded history verified.")
''')

journey = runtime()
journey.execute(r'''
speed, mounted = 7, true
enter(true, false)
advance(12 * 3600)
local seen, last, total = {}, nil, 0
for _, entry in ipairs(spoken) do
    if entry.ambient then
        if last then
            assert(entry.at - last.at >= 180 and entry.at - last.at <= 360)
            assert(entry.text ~= last.text)
        end
        assert(entry.category == "ambientTravel" or entry.category == "ambient")
        assert(not entry.text:find("Von hier oben", 1, true))
        seen[entry.key], last, total = true, entry, total + 1
    end
end
local variety = 0
for _ in pairs(seen) do variety = variety + 1 end
assert(total >= 120 and variety >= 20, "unexpected travel cadence or variety")
assert(count("ambientTravel") > 25 and count("sessionTime") == 0)
assert(#app.Memory().recentAmbient == 12 and liveTimers() <= 2)
local baseline = #spoken
combat = true; fire("PLAYER_REGEN_DISABLED")
fire("QUEST_TURNED_IN", 10)
advance(720)
assert(#spoken == baseline and not select(2, app.DialogueView()))
combat = false; fire("PLAYER_REGEN_ENABLED")
advance(179)
assert(#spoken == baseline, "Ambient or combat history was replayed")
advance(181)
assert(#spoken == baseline + 1)
afk = true; fire("PLAYER_FLAGS_CHANGED", "player")
advance(600)
assert(count("afk") == 1)
baseline = #spoken
assert(app.DialogueView() == "schlaeft")
fire("PLAYER_FLAGS_CHANGED", "player")
advance(600)
assert(#spoken == baseline)
afk = false; fire("PLAYER_FLAGS_CHANGED", "player")
advance(75)
assert(latest() == "back")
local totalAfterReturn = #spoken
fire("LOADING_SCREEN_ENABLED")
advance(600)
assert(#spoken == totalAfterReturn and liveTimers() == 0)
fire("LOADING_SCREEN_DISABLED")
combat = secret
fire("ADDON_RESTRICTION_STATE_CHANGED")
advance(600)
assert(#spoken == totalAfterReturn)
combat = false
print(("Twelve-hour travel simulation: %d ambient comments, %d distinct lines, normal cadence and no backlog."):format(total, variety))
''')

quiet = runtime()
quiet.execute(r'''
resting = true
fire("LOADING_SCREEN_ENABLED")
enter(true, false)
advance(10)
assert(#spoken == 0 and liveTimers() == 0)
fire("LOADING_SCREEN_DISABLED")
assert(latest() == "login")
advance(3 * 3600)
assert(count("ambientCity") >= 5 and count("ambientQuiet") >= 4 and count("longIdle") == 1,
    ("city=%d quiet=%d long idle=%d"):format(count("ambientCity"), count("ambientQuiet"), count("longIdle")))
speed = 6; fire("PLAYER_STARTED_MOVING")
advance(360)
speed = 0; fire("PLAYER_STOPPED_MOVING")
advance(3 * 3600)
assert(count("longIdle") == 2)
app.SetProfile("bubbles", false)
local total = #spoken
fire("PLAYER_LEVEL_UP", 53)
assert(app.DialogueView() == "jubelt" and not select(2, app.DialogueView()) and #spoken == total)
advance(8)
assert(app.DialogueView() == "idle")
print("Resting areas, real idle breaks, loading-screen greeting and silent expressions verified.")
''')

for frequency, minimum, maximum in ((1, 300, 480), (3, 100, 210)):
    cadence = runtime()
    cadence.globals().frequency = frequency
    cadence.globals().minimum = minimum
    cadence.globals().maximum = maximum
    cadence.execute(r'''
    app.SetProfile("frequency", frequency)
    enter(false, true)
    advance(minimum - 1)
    assert(#spoken == 0)
    advance(maximum - minimum + 1)
    assert(#spoken >= 1 and spoken[1].ambient and spoken[1].at >= 1000 + minimum)
    ''')

important = runtime()
important.execute(r'''
enter(false, true)
advance(179)
app.DelayCompanionAmbient(300)
advance(299)
assert(#spoken == 0)
advance(1)
assert(#spoken == 1 and spoken[1].ambient)
print("Alternate cadence settings and priority for freshly displayed reminders verified.")
''')

repair = runtime()
repair.execute(r'''
app.SetProfile("ambientComments", false)
enter(false, true)
assert(#spoken == 0)
durability = secret; fire("UPDATE_INVENTORY_DURABILITY")
assert(#spoken == 0)
durability = 39; fire("UPDATE_INVENTORY_DURABILITY")
assert(count("repairWarning") == 1)
for _ = 1, 5 do fire("UPDATE_INVENTORY_DURABILITY"); advance(10) end
assert(count("repairWarning") == 1)
durability = 19; fire("UPDATE_INVENTORY_DURABILITY")
assert(count("repairCritical") == 1 and app.Memory().lastRepairWarning.severity == 2)
advance(1499)
assert(count("repairCritical") == 1)
advance(1)
assert(count("repairCritical") == 2)
durability = 100; fire("UPDATE_INVENTORY_DURABILITY")
advance(1550)
assert(count("repairCritical") == 2)
durability = 85; fire("UPDATE_INVENTORY_DURABILITY")
fire("MERCHANT_SHOW"); assert(count("repairMerchant") == 0)
fire("MERCHANT_CLOSED")
repairable = true; fire("MERCHANT_SHOW")
assert(count("repairMerchant") == 1)
durability, equipped = 95, "item:901"; fire("UPDATE_INVENTORY_DURABILITY")
assert(count("repaired") == 0)
durability = 100; fire("UPDATE_INVENTORY_DURABILITY")
advance(15)
assert(count("repaired") == 1)
fire("MERCHANT_CLOSED")
app.SetProfile("repairHints", false)
durability = 5; fire("UPDATE_INVENTORY_DURABILITY")
advance(1800)
assert(count("repairCritical") == 2)
free = secret; fire("BAG_UPDATE_DELAYED")
assert(count("inventoryFull") == 0)
free = 0; fire("BAG_UPDATE_DELAYED")
assert(count("inventoryFull") == 1)
fire("BAG_UPDATE_DELAYED")
assert(count("inventoryFull") == 1)
print("Verified measured repair thresholds, cooldown, merchant capability, same-gear repair and readable bag space.")
''')

session = runtime()
session.execute(r'''
app.SetProfile("ambientComments", false)
app.SetProfile("repairHints", false)
app.SetProfile("pauseHints", true)
enter(true, false)
advance(3599); assert(count("sessionTime") == 0)
advance(1); assert(count("sessionTime") == 1)
advance(599)
fire("PLAYER_LEAVING_WORLD")
fire("PLAYER_ENTERING_WORLD", false, false)
assert(select(2, app.CompanionSession()) == 4199)
fire("PLAYER_LOGOUT")
''')
reload = runtime(session)
reload.execute(r'''
enter(false, true)
assert(select(2, app.CompanionSession()) == 4199)
advance(3000); assert(#spoken == 0)
advance(1); assert(count("sessionBreak") == 1)
advance(7200); assert(count("sessionBreak") == 3)
advance(3600); assert(count("sessionBreak") == 3)
advance(3600); assert(count("sessionBreak") == 4)
app.SetProfile("pauseHints", false)
advance(7200); assert(count("sessionBreak") == 4)
fire("PLAYER_LOGOUT")
''')
fresh = runtime(reload)
fresh.execute(r'''
enter(true, false)
assert(select(2, app.CompanionSession()) == 0)
''')
stale = runtime(reload, elapsed=100000)
stale.execute(r'''
enter(false, true)
assert(select(2, app.CompanionSession()) == 0)
print("Session thresholds, opt-out, zoning, valid reload, fresh login and stale restore verified.")
''')

situations = runtime()
situations.execute(r'''
app.SetProfile("ambientComments", false)
enter(false, true)
local item = "|cff0070dd|Hitem:123|h[Test item]|h|r"
priceSource, auctionPrice = "TSM_DBMarket", 250000
fire("CHAT_MSG_LOOT", "Jemand erhält Beute: " .. item .. ".")
assert(#spoken == 0)
fire("CHAT_MSG_LOOT", "Ihr erhaltet Beute: " .. item .. " x2.")
assert(latest() == "valuableLoot")
fire("CHAT_MSG_LOOT", "Ihr erhaltet Beute: " .. item .. " x2.")
assert(#spoken == 1)
advance(56)
quality, priceSource = 3, "NONE"
fire("CHAT_MSG_LOOT", "Ihr erhaltet Beute: " .. item .. ".")
assert(latest() == "rareLoot")
advance(50)
fire("READY_CHECK", "player", 30)
fire("READY_CHECK_CONFIRM", "party1", true)
fire("READY_CHECK_FINISHED")
assert(count("groupReady") == 0)
fire("READY_CHECK", "player", 30)
fire("READY_CHECK_CONFIRM", "party1", true)
fire("READY_CHECK_CONFIRM", "party2", true)
fire("READY_CHECK_FINISHED")
assert(latest() == "groupReady")
advance(56)
fire("READY_CHECK", "player", 30)
fire("READY_CHECK_CONFIRM", "party1", false)
fire("READY_CHECK_CONFIRM", "party2", false)
fire("READY_CHECK_FINISHED")
assert(latest() == "groupChaos")
advance(50)
encounter = true; fire("ENCOUNTER_START")
fire("ENCOUNTER_END", 16, "Boss", 1, 5, secret)
assert(count("afterSuccess") == 0)
encounter = false
fire("ENCOUNTER_END", 16, "Boss", 1, 5, 1)
assert(latest() == "afterSuccess")
fire("LFG_COMPLETION_REWARD")
assert(latest() == "dungeonFinished")
advance(80)
for _ = 1, 3 do
    dead = true; fire("PLAYER_DEAD"); fire("PLAYER_DEAD")
    advance(10)
    dead = false; fire("PLAYER_UNGHOST")
    advance(65)
end
assert(app.Memory().deaths == 3 and count("repeatedDeath") == 1)
advance(75)
zone = "Brachland"; fire("ZONE_CHANGED_NEW_AREA")
advance(75)
zone = "Durotar"; fire("ZONE_CHANGED_NEW_AREA")
assert(latest() == "repeatedZone")
assert(app.Memory().recentZones[1].name == "Durotar")
app.SetProfile("situationalComments", false)
advance(360)
local total = #spoken
fire("QUEST_TURNED_IN", 567)
fire("LFG_COMPLETION_REWARD")
assert(#spoken == total)
print("Verified self-only loot, price evidence, ready checks, completion, repeated experiences and per-feature switches.")
''')

limited = runtime()
limited.execute(r'''
GetInventoryItemDurability, CanMerchantRepair = nil, nil
GetUnitSpeed, IsResting, IsMounted, IsFlying, UnitOnTaxi = nil, nil, nil, nil, nil
GetReadyCheckStatus, GetNumGroupMembers, IsInRaid = nil, nil, nil
enter(false, true)
free = secret
fire("UPDATE_INVENTORY_DURABILITY")
fire("MERCHANT_SHOW")
fire("BAG_UPDATE_DELAYED")
fire("READY_CHECK")
fire("READY_CHECK_FINISHED")
advance(360)
assert(#spoken == 1 and latest() == "ambient")
Enum = { AddOnRestrictionType = { Combat = 0 } }
C_RestrictedActions = { GetAddOnRestrictionState = function() return secret end }
fire("ADDON_RESTRICTION_STATE_CHANGED")
advance(720)
assert(#spoken == 1 and not select(2, app.DialogueView()))
print("Missing and protected client data leave unsupported contexts silent.")
''')
