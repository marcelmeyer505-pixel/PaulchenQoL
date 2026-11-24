"""Exercise Paulchen loot, group roll, and upgrade handling with a simulated client."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / "lua_runtime"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime()
lua.execute((root / "tests/buff_watcher_fixture.lua").read_text(encoding="utf-8"))
lua.execute(r'''
function GetLocale() return "deDE" end
function UnitName() return "Paul" end
secrets = {}
function issecretvalue(value) return value == secrets end
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ROLL_ROLLED_NEED = "Für %2$s würfelt %3$s Bedarf (%1$d)."
LOOT_ROLL_GREED = "%s has selected Greed for: %s."
LOOT_ROLL_PASSED_SELF = "You passed on: %s."
LOOT_ROLL_WON = "%s won: %s."
LOOT_ROLL_ALL_PASSED = "Everyone passed on: %s."
link = "|cff0070dd|Hitem:42::::::::|h[Armor]|h|r"
junk = "|cff9d9d9d|Hitem:43::::::::|h[Junk]|h|r"
lateLink = "|cff00ff00|Hitem:44::::::::|h[Delayed]|h|r"
links = {}
lootSlots, itemData, rollInfo, active = {}, {}, {}, {}
messages, votes = {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) messages[#messages + 1] = msg end }
function GetNumLootItems() return #lootSlots end
function GetLootSlotLink(slot) return lootSlots[slot] end
function GetLootSlotInfo() return 44, "loot", 2 end
function GetLootRollItemLink(id) return links[id] end
function GetLootRollItemInfo(id)
    local available = rollInfo[id]
    if available then return 55, "roll item", 1, 3, true, available.need, available.greed end
end
function GetLootRollTimeLeft(id) return active[id] end
function RollOnLoot(id, choice) votes[#votes + 1] = { id, choice } end
C_Item = {
    GetItemInfoInstant = function(item) return nil, nil, nil, item == junk and "" or "INVTYPE_CHEST" end,
    RequestLoadItemDataByID = function(id) itemData[id] = "requested" end,
}
Enum = { EncounterLootDropRollState = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 } }
history = {}
C_LootHistory = {
    GetSortedInfoForDrop = function(_, id) return history[id] end,
    GetLootHistoryTime = function() return now end,
}
''')
load = lua.eval('function(source,name) assert(loadstring(source, "@" .. name))("PaulchenQoL", app) end')
for name in ("Localization.lua", "Core.lua", "Style.lua"):
    load((root / name).read_text(encoding="utf-8-sig"), name)
lua.execute(r'''
local function itemID(value)
    if type(value) == "string" then return tonumber(value:match("item:(%d+)")) end
end
app.upgrades = {
    gear = {
        ItemID = itemID,
        CompareToEquipped = function(value)
            local id = itemID(value)
            if id == 42 or itemData[id] == "ready" then return { delta = 3, pct = 10, usable = true } end
        end,
        GetPlayer = function() return { level = 60 } end,
    },
    VariantKey = function() end,
    ObserveVariant = function() end,
    IsUpgrade = function(result) return result.usable and result.delta > 0 end,
    ProfileName = function() return "Testprofil" end,
}
''')
for name in ("Modules/Upgrades/Loot.lua", "Modules/Upgrades/LootWindow.lua"):
    load((root / name).read_text(encoding="utf-8-sig"), name)
lua.execute(r'''
local loot = app.upgrades.loot
loot.Open()
local window = assert(PaulchenQoLLootWindow)
assert(window:IsShown() and window.empty:IsVisible() and not window.need:IsVisible())
lootSlots = { junk }
fire("LOOT_READY")
fire("LOOT_OPENED")
fire("LOOT_CLOSED")
fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF_MULTIPLE:format(junk, 2))
assert(#loot.drops == 1 and loot.drops[1].received and not loot.drops[1].gain)
assert(window.items[1].caption:GetText() == "2× Junk" and not window.greed:IsVisible())
assert(next(itemData) == nil, "Ordinary junk does not start item data retries")

links[1], rollInfo[1], active[1] = link, { need = true, greed = true }, 60000
fire("START_LOOT_ROLL", 1, 60000)
assert(#loot.drops == 2 and #messages == 1 and #votes == 0)
local roll = loot.drops[1]
assert(window.need:IsEnabled() and window.greed:IsEnabled() and window.pass:IsEnabled())
assert(window.gain:GetText():find("Testprofil", 1, true))
window.need.scripts.OnClick()
window.need.scripts.OnClick()
assert(#votes == 1 and votes[1][1] == 1 and votes[1][2] == 1)
assert(not window.need:IsEnabled())

fire("CHAT_MSG_LOOT", "Für " .. link .. " würfelt Mara Bedarf (99).")
fire("CHAT_MSG_LOOT", LOOT_ROLL_GREED:format("Theo", link))
assert(roll.players.Mara.number == 99 and roll.players.Theo.choice == "greed")
history[7] = { itemHyperlink = link, startTime = now, playerRollState = 0, rollInfos = {
    { playerName = "Paul", state = 0, roll = 34 },
    { playerName = "Mara", state = 0, roll = 99 },
    { playerName = "Theo", state = 3, roll = 64 },
    { playerName = "Lina", state = 5 },
    { playerName = "Nils", state = 4 },
    { playerName = secrets, state = 1 },
}, winner = { playerName = "Mara" } }
fire("LOOT_HISTORY_UPDATE_DROP", 35, 7)
assert(roll.winner == "Mara" and roll.players.Lina.choice == "pass" and not roll.players.Nils)
assert(window.players[1].name:GetText() == "Mara" and window.players[1].number:GetText() == 99)
assert(window.status:GetText() == "Gewonnen von Mara" and not window.need:IsEnabled())
fire("CANCEL_LOOT_ROLL", 1)
loot.Roll(roll, 2)
assert(#votes == 1)

links[2], active[2] = lateLink, 60000
fire("START_LOOT_ROLL", 2, 60000)
assert(#loot.drops == 2)
rollInfo[2] = { need = false, greed = true }
advance(0.26)
assert(#loot.drops == 3 and itemData[44] == "requested")
assert(not window.need:IsEnabled() and window.greed:IsEnabled())
itemData[44] = "ready"
PaulchenQoLUpgradesDB = { lootAlerts = false }
advance(0.31)
assert(loot.drops[1].gain and #messages == 1)
loot.Roll(loot.drops[1], 1)
assert(#votes == 1)
window.greed.scripts.OnClick()
assert(#votes == 2 and votes[2][2] == 2 and votes[2][1] == 2)
fire("CHAT_MSG_LOOT", LOOT_ROLL_PASSED_SELF:format(lateLink))
assert(loot.drops[1].voted == "pass")
fire("CANCEL_ALL_LOOT_ROLLS")
assert(not window.greed:IsEnabled())

links[3], rollInfo[3], active[3] = link, { need = true, greed = true }, 60000
links[4], rollInfo[4], active[4] = link, { need = true, greed = true }, 60000
fire("START_LOOT_ROLL", 3, 60000)
fire("START_LOOT_ROLL", 4, 60000)
fire("CHAT_MSG_LOOT", LOOT_ROLL_GREED:format("Dina", link))
assert(loot.drops[1].rollID == 4 and loot.drops[2].rollID == 3)
assert(not loot.drops[1].players.Dina and not loot.drops[2].players.Dina,
    "Identical simultaneous rolls stay separate when a chat line does not identify the copy")
loot.Roll(loot.drops[1], 0)
assert(#votes == 3 and votes[3][1] == 4 and votes[3][2] == 0)
''')
print("Loot window: deduplication, localized votes, winner, item-cache retries, eligibility and manual choices passed.")
