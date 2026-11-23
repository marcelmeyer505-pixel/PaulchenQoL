"""Exercise opt-in vendor and quest automation without a WoW client or Leatrix."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / "lua_runtime"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime()
lua.execute(r'''
app, frames, timers, messages = {}, {}, {}, {}
secret, now, copper = {}, 250, 1000
combat, shift, alt, cursor, npc = false, false, false, nil, true
function issecretvalue(value) return value == secret end
function GetLocale() return "deDE" end
function GetTime() return now end
function InCombatLockdown() return combat end
function IsShiftKeyDown() return shift end
function IsAltKeyDown() return alt end
function GetCursorInfo() return cursor end
function GetMoney() return copper end
function UnitExists(unit) return npc and (unit == "questnpc" or unit == "npc") end
function print(message) messages[#messages + 1] = message end

local function frame(visible)
    return { visible = visible, IsVisible = function(self) return self.visible end }
end
MerchantFrame, BankFrame, StaticPopup1 = frame(false), frame(false), frame(false)
GossipFrame, QuestFrame = frame(false), frame(false)
QuestFrameGreetingPanel, QuestFrameDetailPanel, QuestFrameProgressPanel, QuestFrameRewardPanel =
    frame(false), frame(false), frame(false), frame(false)
function CreateFrame()
    local f = { events = {}, scripts = {} }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    frames[#frames + 1] = f
    return f
end
function fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] then f.scripts.OnEvent(f, event, ...) end
    end
end

C_Timer = { After = function(delay, fn) timers[#timers + 1] = { now + delay, fn } end }
function advance(seconds)
    local untilTime = now + seconds
    while true do
        local first
        for i, timer in ipairs(timers) do
            if timer[1] <= untilTime and (not first or timer[1] < timers[first][1]) then first = i end
        end
        if not first then break end
        local timer = table.remove(timers, first)
        now = timer[1]
        timer[2]()
    end
    now = untilTime
end

items, sales, bagSize = {}, {}, 20
function item(slot, id, fields)
    local value = {
        hyperlink = "|Hitem:" .. id .. ":0:0:0:0:0:0|h[Item]|h",
        itemID = id, quality = 0, stackCount = 1, isLocked = false,
        hasNoValue = false, isReadable = false, hasLoot = false, class = 0, price = 20,
    }
    for key, info in pairs(fields or {}) do value[key] = info end
    items[slot] = value
    return value
end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and bagSize or 0 end,
    GetContainerItemInfo = function(_, slot) return items[slot] end,
    GetContainerItemQuestInfo = function(_, slot)
        local item = items[slot]
        if item.unknownQuest then return secret end
        return { isQuestItem = item.quest == true, isActive = false }
    end,
    UseContainerItem = function(bag, slot)
        assert(bag == 0 and MerchantFrame.visible and not BankFrame.visible)
        local selected = assert(items[slot])
        sales[#sales + 1] = selected.itemID
        if not selected.fail then
            C_Timer.After(.08, function()
                assert(items[slot] == selected)
                items[slot], copper = nil, copper + selected.price * selected.stackCount
            end)
        end
    end,
}
C_Item = {
    GetItemInfo = function(link)
        for _, item in pairs(items) do
            if item.hyperlink == link then
                return nil, nil, item.quality, nil, nil, nil, nil, nil, nil, nil, item.price, item.class
            end
        end
    end,
    GetItemInfoInstant = function(link)
        local id = tonumber(link:match("item:(%d+)"))
        return id, nil, nil, nil, nil, id == 300 and 12 or 7
    end,
}

quest, actions = {}, {}
offers, availableQuests, activeQuests = {}, {}, {}
local function record(action, value) actions[#actions + 1] = { action, value } end
function GetQuestID() return quest.id end
function QuestIsDaily() return quest.daily or false end
function QuestIsWeekly() return quest.weekly or false end
function QuestGetAutoAccept() return quest.auto or false end
function GetQuestMoneyToGet() return quest.money or 0 end
function GetNumQuestCurrencies() return quest.currency or 0 end
function GetNumQuestItems() return #(quest.items or {}) end
function GetQuestItemLink(_, index) return quest.items[index] end
function IsQuestCompletable() return quest.ready ~= false end
function GetNumQuestChoices() return quest.choices or 0 end
function AcceptQuest() record("accept", quest.id) end
function CompleteQuest() record("progress", quest.id) end
function GetQuestReward(choice) record("reward", choice) end
function GetNumActiveQuests() return #activeQuests end
function GetNumAvailableQuests() return #availableQuests end
function GetActiveTitle(i) return "Active", activeQuests[i].isComplete end
function GetAvailableQuestInfo(i) return false, availableQuests[i].frequency, false, false, availableQuests[i].questID end
function SelectActiveQuest(i) record("classicActive", i) end
function SelectAvailableQuest(i) record("classicAvailable", i) end
C_GossipInfo = {
    GetActiveQuests = function() return activeQuests end,
    GetAvailableQuests = function() return availableQuests end,
    GetOptions = function() return offers end,
    SelectActiveQuest = function(id) record("active", id) end,
    SelectAvailableQuest = function(id) record("available", id) end,
    SelectOption = function(id, text, confirmed)
        assert(text == nil and confirmed == nil, "Never approve a gossip confirmation")
        record("gossip", id)
    end,
}
function page(event, data)
    quest = data or quest
    QuestFrame.visible = event ~= "GOSSIP_SHOW"
    GossipFrame.visible = not QuestFrame.visible
    QuestFrameGreetingPanel.visible = event == "QUEST_GREETING"
    QuestFrameDetailPanel.visible = event == "QUEST_DETAIL"
    QuestFrameProgressPanel.visible = event == "QUEST_PROGRESS"
    QuestFrameRewardPanel.visible = event == "QUEST_COMPLETE"
    fire(event)
    advance(0)
end
''')
load = lua.eval('function(code, name) assert(loadstring(code, "@" .. name))("PaulchenQoL", app) end')
for path in ("Localization.lua", "Core.lua", "Style.lua", "Modules/Comfort/Window.lua",
             "Modules/Comfort/Vendor.lua", "Modules/Comfort/Quests.lua"):
    load((root / path).read_text(encoding="utf-8-sig"), path)

lua.execute(r'''
app.inventory = { MoneyText = function(balance) return tostring(balance) .. "c" end }
local comfort = app.comfort
assert(not comfort.Enabled("sellPoor") and comfort.Enabled("sellSummary"))
local marks = app.Settings().marks
item(1, 11, {stackCount = 3})
item(2, 12); marks["12"] = "vendor"
item(3, 13); marks["13"] = "keep"
item(4, 14); marks["14"] = "auction"
item(5, 15); marks["15"] = "cat"
item(6, 16); marks["16"] = "bear"
local custom = item(7, 17, {hyperlink = "|Hitem:17:0:0:0:0:0:-76|h[Variant]|h"})
marks[app.BagItemKey(custom.itemID, custom.hyperlink)] = "custom_1"
item(8, 17) -- An unmarked variant is still eligible.
item(9, 18, {quality = 1}); marks["18"] = "vendor"
item(10, 19, {isLocked = true})
item(11, 20, {quest = true})
item(12, 21, {class = 12})
item(13, 22, {hasNoValue = true})
item(14, 23, {isReadable = true})
item(15, 24, {hasLoot = true})
item(16, 25, {unknownQuest = true})
item(17, 26, {quality = secret})
item(18, 27, {price = secret})
item(19, 28, {hyperlink = secret})
item(20, 29)
MerchantFrame.visible = true
fire("MERCHANT_SHOW"); advance(2)
assert(#sales == 0, "The feature is off by default")
comfort.SetEnabled("sellPoor", true)
shift = true; fire("MERCHANT_SHOW"); advance(2)
shift = false
combat = true; fire("MERCHANT_SHOW"); advance(2)
combat = false
BankFrame.visible = true; fire("MERCHANT_SHOW"); advance(2)
BankFrame.visible = false
cursor = secret; fire("MERCHANT_SHOW"); advance(2)
cursor, shift, combat = nil, nil, nil
assert(#sales == 0, "No sales on shift, in combat, at the bank, or with an unknown cursor")
fire("MERCHANT_SHOW"); advance(0)
assert(#sales == 1 and sales[1] == 11 and items[1])
marks["29"] = "keep" -- A mark added after planning still protects the stack.
advance(2)
assert(#sales == 3 and sales[2] == 12 and sales[3] == 17)
assert(items[3] and items[7] and items[9] and items[19] and items[20])
assert(copper == 1100 and messages[1]:find("3 Stapel (5 Stück) · 100c", 1, true))

items = {}
item(1, 31, {fail = true})
item(2, 32)
fire("MERCHANT_SHOW"); advance(2)
assert(#sales == 4 and sales[4] == 31 and items[2] and #messages == 1)
fire("MERCHANT_SHOW"); advance(0)
MerchantFrame.visible = false; fire("MERCHANT_CLOSED"); advance(2)
assert(#sales == 5 and items[2], "Closed visits must cancel delayed work")

local function detail(id, fields)
    fields = fields or {}
    fields.id = id
    page("QUEST_DETAIL", fields)
end
detail(40); assert(#actions == 0)
comfort.SetEnabled("questRegular", true)
detail(41); assert(actions[1][1] == "accept" and actions[1][2] == 41)
detail(41); assert(#actions == 1, "Repeated events cannot accept the same offer again")
detail(42, {daily = true}); detail(43, {weekly = true}); detail(44, {auto = true})
assert(#actions == 1)
comfort.SetEnabled("questDaily", true)
comfort.SetEnabled("questWeekly", true)
detail(45, {daily = true}); detail(46, {weekly = true})
assert(#actions == 3)
shift = true; detail(47); shift = false
assert(#actions == 3)
QuestFrame.visible, QuestFrameDetailPanel.visible = true, true
quest = { id = 48 }; fire("QUEST_DETAIL"); quest.id = 49; advance(0)
assert(#actions == 3, "A delayed event cannot act on another quest")

comfort.SetEnabled("questTurnIn", true)
page("QUEST_PROGRESS", {id = 50})
page("QUEST_COMPLETE", {id = 50, choices = 0})
assert(actions[4][1] == "progress" and actions[5][1] == "reward" and actions[5][2] == 0)
page("QUEST_COMPLETE", {id = 51, choices = 1})
assert(actions[6][1] == "reward" and actions[6][2] == 1)
page("QUEST_COMPLETE", {id = 52, choices = 2})
page("QUEST_COMPLETE", {id = 53, money = 1})
page("QUEST_PROGRESS", {id = 54, currency = 3})
page("QUEST_COMPLETE", {id = 54})
page("QUEST_PROGRESS", {id = 55, items = {"item:301"}})
page("QUEST_COMPLETE", {id = 55})
page("QUEST_PROGRESS", {id = 56, ready = false})
assert(#actions == 6, "Costs, choice rewards and incomplete quests need a player")
page("QUEST_PROGRESS", {id = 57, items = {"item:300"}})
assert(actions[7][1] == "progress")
app.Settings().marks["300"] = "keep"
page("QUEST_PROGRESS", {id = 58, items = {"item:300"}})
assert(#actions == 7)

availableQuests = {{questID = 70, frequency = 0}}
page("GOSSIP_SHOW")
page("GOSSIP_SHOW")
assert(actions[8][1] == "available" and actions[8][2] == 70 and #actions == 8)
fire("GOSSIP_CLOSED", true)
activeQuests = {{questID = 66, isComplete = false}, {questID = 67, isComplete = true}}
availableQuests = {{questID = 70, frequency = 0}, {questID = 68, frequency = 1}}
offers = {{gossipOptionID = 71, status = 0}}
page("GOSSIP_SHOW")
assert(#actions == 9 and actions[9][1] == "active" and actions[9][2] == 67)
page("GOSSIP_SHOW")
assert(#actions == 10 and actions[10][1] == "available" and actions[10][2] == 68)
actions[9], actions[10] = nil, nil
fire("GOSSIP_CLOSED")
activeQuests, availableQuests = {}, {}
comfort.SetEnabled("gossipAlt", true)
page("GOSSIP_SHOW"); assert(#actions == 8)
alt = true; page("GOSSIP_SHOW")
assert(actions[9][1] == "gossip" and actions[9][2] == 71)
fire("GOSSIP_CLOSED")
offers = {}; activeQuests = {{questID = 72, isComplete = true}}
page("GOSSIP_SHOW")
assert(actions[10][1] == "active" and actions[10][2] == 72)
page("QUEST_GREETING")
assert(actions[11][1] == "classicActive")
activeQuests, availableQuests = {}, {{questID = 74, frequency = 2}}
page("QUEST_GREETING")
assert(actions[12][1] == "classicAvailable")
StaticPopup1.visible = true; detail(73)
assert(#actions == 12)
''')
print("Comfort automation passed: marked variants, protected slots, verified sales, quest types, costs, rewards, NPC choices and cancellation.")
