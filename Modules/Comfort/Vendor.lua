local _, app = ...
local comfort, C = app.comfort, C_Container
local readable, read = app.Readable, comfort.Read
local itemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local poor = Enum and Enum.ItemQuality and Enum.ItemQuality.Poor or 0
local questClass = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
local active

local function canSell()
    if not comfort.Enabled("sellPoor") or not comfort.CanInteract() or not comfort.Visible(MerchantFrame)
        or comfort.Visible(BankFrame) or comfort.Visible(TradeFrame) or comfort.Visible(MailFrame)
        or comfort.HasDialog() then return false end
    local cursor, known = read(GetCursorInfo)
    return known and cursor == nil
end

local function candidate(bag, slot, marks)
    local info = read(C.GetContainerItemInfo, bag, slot)
    if not info or readable(info.quality) ~= poor or readable(info.isLocked) ~= false
        or readable(info.hasNoValue) ~= false or readable(info.hasLoot) ~= false
        or readable(info.isReadable) ~= false then return end
    local id, link, count = readable(info.itemID), readable(info.hyperlink), readable(info.stackCount)
    if type(id) ~= "number" or id <= 0 or type(count) ~= "number" or count <= 0
        or type(link) ~= "string" or not link:find("|Hitem:", 1, true) then return end
    local mark = marks[app.BagItemKey(id, link)]
    if mark ~= nil and mark ~= "vendor" then return end
    local quest, known = read(C.GetContainerItemQuestInfo, bag, slot)
    if not known or not quest or readable(quest.isQuestItem) ~= false
        or readable(quest.isActive) ~= false then return end
    local questID = quest.questID
    if (issecretvalue and issecretvalue(questID)) or (questID ~= nil and questID ~= 0) then return end
    local ok, _, _, quality, _, _, _, _, _, _, _, price, classID = pcall(itemInfo, link)
    price, classID = readable(price), readable(classID)
    if not ok or readable(quality) ~= poor or type(price) ~= "number" or price <= 0
        or type(classID) ~= "number" or classID == questClass then return end
    return { bag = bag, slot = slot, link = link, count = count, price = price * count }
end

local function finish(visit)
    if active ~= visit then return end
    active = nil
    if visit.stacks > 0 and comfort.Enabled("sellSummary") then
        local money = app.inventory and app.inventory.MoneyText
        if money then
            print(app.LF("Paulchen · Grauverkauf · %d Stapel (%d Stück) · %s",
                visit.stacks, visit.items, money(visit.total)))
        end
    end
end

local step
local function checkSale(visit)
    if active ~= visit then return end
    local sale = visit.pending
    local info, known = read(C.GetContainerItemInfo, sale.bag, sale.slot)
    local balance = read(GetMoney)
    -- Count a sale only when the stack leaves its slot and the client credits the expected gold.
    if known and not info and type(balance) == "number" and balance >= sale.balance + sale.price then
        visit.pending = nil
        visit.stacks, visit.items, visit.total = visit.stacks + 1, visit.items + sale.count, visit.total + sale.price
        return step(visit)
    end
    if not canSell() or GetTime() >= sale.untilTime then
        return finish(visit)
    end
    C_Timer.After(0.12, function() checkSale(visit) end)
end

step = function(visit)
    if active ~= visit then return end
    if not canSell() then return finish(visit) end
    local marks = app.Settings().marks
    while visit.index < #visit.queue do
        visit.index = visit.index + 1
        local previous = visit.queue[visit.index]
        local item = candidate(previous.bag, previous.slot, marks)
        if item and item.link == previous.link and item.count == previous.count and item.price == previous.price then
            local money = read(GetMoney)
            if type(money) ~= "number" or money < 0 then return finish(visit) end
            item.balance, item.untilTime = money, GetTime() + 1.5
            visit.pending = item
            if not app.SecureCall(app.L("Grauverkauf"), C.UseContainerItem, item.bag, item.slot) then
                return finish(visit)
            end
            C_Timer.After(0.12, function() checkSale(visit) end)
            return
        end
    end
    finish(visit)
end

local function start()
    if active then return end
    if not C or not C.GetContainerItemQuestInfo or not C.UseContainerItem or not itemInfo
        or not C_Timer or not C_Timer.After or not comfort.Enabled("sellPoor") or not comfort.CanInteract() then return end
    local visit = { queue = {}, index = 0, stacks = 0, items = 0, total = 0 }
    active = visit
    C_Timer.After(0, function()
        if active ~= visit then return end
        if not canSell() then return finish(visit) end
        local marks = app.Settings().marks
        local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
        for bag = 0, lastBag do
            local slots = read(C.GetContainerNumSlots, bag)
            for slot = 1, type(slots) == "number" and slots or 0 do
                local item = candidate(bag, slot, marks)
                if item then visit.queue[#visit.queue + 1] = item end
            end
        end
        step(visit)
    end)
end

local events = CreateFrame("Frame")
app.RegisterSupported(events, "MERCHANT_SHOW")
app.RegisterSupported(events, "MERCHANT_CLOSED")
app.RegisterSupported(events, "PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then start()
    elseif active then finish(active) end
end)
