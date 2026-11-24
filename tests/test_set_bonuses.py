"""Verify set thresholds in the native equipment comparison and upgrade gate."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / "lua_runtime"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime()
lua.execute((root / "tests/buff_watcher_fixture.lua").read_text(encoding="utf-8"))
lua.execute(r'''
function GetLocale() return "deDE" end
function UnitClass() return "Druide", "DRUID", 11 end
function UnitLevel() return 60 end
function UnitRace() return "Tauren", "Tauren" end
function UnitFactionGroup() return "Horde" end
local function chest(stats) return { "INVTYPE_CHEST", 4, 2, stats } end
local function shoulder(stats) return { "INVTYPE_SHOULDER", 4, 2, stats } end
local function legs(stats) return { "INVTYPE_LEGS", 4, 2, stats } end
items = {
    [15066] = chest({ ITEM_MOD_INTELLECT_SHORT = 12, ITEM_MOD_SPIRIT_SHORT = 28, ITEM_MOD_SPELL_POWER_SHORT = 21 }),
    [15067] = shoulder({}),
    [22409] = chest({ ITEM_MOD_INTELLECT_SHORT = 12, ITEM_MOD_SPIRIT_SHORT = 11, ITEM_MOD_STAMINA_SHORT = 14,
        ITEM_MOD_SPELL_POWER_SHORT = 15, ITEM_MOD_CRIT_SPELL_RATING_SHORT = 14 }),
    [900001] = chest({ ITEM_MOD_SPELL_POWER_SHORT = 10 }),
    [900002] = shoulder({}),
    [900003] = legs({}),
    [900004] = chest({ ITEM_MOD_SPELL_POWER_SHORT = 30 }),
    [900005] = { "INVTYPE_2HWEAPON", 2, 10, { ITEM_MOD_SPELL_POWER_SHORT = 11 } },
    [900006] = { "INVTYPE_WEAPONMAINHAND", 2, 4, { ITEM_MOD_SPELL_POWER_SHORT = 5 } },
    [900007] = { "INVTYPE_HOLDABLE", 4, 0, { ITEM_MOD_SPELL_POWER_SHORT = 3 } },
    [900008] = { "INVTYPE_HOLDABLE", 4, 0, { ITEM_MOD_SPELL_POWER_SHORT = 6 } },
    [900009] = chest({ ITEM_MOD_SPELL_POWER_SHORT = 20 }),
}
local function info(link) return items[tonumber(tostring(link):match("(%d+)"))] end
worn, bags = {}, {}
local function link(id) return id and ("item:" .. id) end
function GetInventoryItemLink(_, slot) return link(worn[slot]) end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #bags or 0 end,
    GetContainerItemLink = function(_, slot) return link(bags[slot]) end,
}
C_Item = {
    GetItemInfo = function(value)
        local item = info(value)
        return "Item", value, 3, 55, 53, nil, nil, nil, item[1], nil, nil, item[2], item[3], nil, nil, item.setID
    end,
    GetItemStats = function(value) return info(value)[4] end,
    GetItemSetInfo = function(id) if id == 144 then return "Ironfeather Armor" end end,
}
''')
load = lua.eval('function(source,name) assert(loadstring(source, "@" .. name))("PaulchenQoL", app) end')
for name in ("Localization.lua", "Core.lua"):
    load((root / name).read_text(encoding="utf-8-sig"), name)
lua.execute('app.upgrades = {}; PaulchenQoLUpgradesDB = { activeStatProfile = "balance" }')
for name in ("Profiles.lua", "SetBonusData.lua"):
    load((root / "Modules/Upgrades" / name).read_text(encoding="utf-8-sig"), name)
lua.execute(r'''
local data = app.upgrades.setBonusData
data[900001] = { items = {900001, 900002, 900003, 900009},
    bonuses = { [2] = { stats = {sp = 5} }, [3] = {unknown = true} } }
data[900006] = { items = {900006, 900007}, bonuses = { [2] = { stats = {sp = 15} } } }
''')
for name in ("SetBonuses.lua", "Gear.lua", "Upgrades.lua"):
    load((root / "Modules/Upgrades" / name).read_text(encoding="utf-8-sig"), name)
lua.execute(r'''
local gear = app.upgrades.gear
local function equip(slots, weapons)
    worn, bags = slots, weapons or {}
    gear.Invalidate("equipment")
end
local function approx(actual, expected) assert(math.abs(actual - expected) < 0.0001, tostring(actual)) end
local function compare(id) return assert(gear.CompareToEquipped("item:" .. id)) end
equip({ [5] = 15066, [3] = 15067 })
local drop = compare(22409)
approx(drop.delta, -18.3)
assert(not app.upgrades.IsUpgrade(drop, 60) and not drop.unknownSetLoss)
assert(drop.setEffects[1].threshold == 2 and drop.setEffects[1].points == 20 and not drop.setEffects[1].gaining)
local estimate = gear.EstimateRecord(22409, { inv = 5, class = 4, subclass = 2, req = 53,
    stats = { int = 12, spi = 11, sta = 14, sp = 15, spellCrit = 1 } })
approx(estimate.delta, drop.delta)
local labels = {}
app.upgrades.setBonuses.AddTooltipLines({ AddDoubleLine = function(_, a, b) labels[#labels + 1] = {a, b} end }, drop)
assert(labels[1][1]:find("Ironfeather Armor", 1, true) and labels[1][2]:find("-20", 1, true))

equip({ [5] = 15066 })
drop = compare(22409)
approx(drop.delta, 1.7)
assert(not drop.setEffects and app.upgrades.IsUpgrade(drop, 60))
equip({ [5] = 22409, [3] = 15067 })
drop = compare(15066)
approx(drop.delta, 18.3)
assert(drop.setEffects[1].gaining and app.upgrades.IsUpgrade(drop, 60))

equip({ [5] = 900001, [3] = 900002, [7] = 900003 })
drop = compare(900004)
assert(drop.delta > 0 and drop.unknownSetLoss and not app.upgrades.IsUpgrade(drop, 60))
assert(drop.setEffects[1].threshold == 3 and drop.setEffects[1].unknown, "The 2-piece bonus is still active")
drop = compare(900009)
assert(drop.delta > 0 and not drop.setEffects and app.upgrades.IsUpgrade(drop, 60), "A same-set swap retains both thresholds")

equip({ [16] = 900005 }, { 900007, 900008 })
drop = compare(900006)
approx(drop.delta, 12)
assert(drop.setEffects[1].gaining and drop.setEffects[1].points == 15, "The best weapon pair uses the set threshold")
equip({ [16] = 900006, [17] = 900007 })
drop = compare(900005)
approx(drop.delta, -12)
assert(not drop.setEffects[1].gaining and #drop.setEffects == 1)
''')
print("Set bonuses: Ironfeather loss/gain, cache invalidation, multiple thresholds, unknown loss, and weapon pairs passed.")
