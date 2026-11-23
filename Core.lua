local addonName, app = ...

local hearthstone = 6948
local container = C_Container
local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local getItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
app.artPath = "Interface\\AddOns\\" .. addonName .. "\\Textures\\paulchen_"
app.avatar = app.artPath .. "idle.tga"
app.markOrder = { "keep", "cat", "bear", "auction", "vendor" }
app.marks = {
    keep = { app.L("Behalten"), { 0.61, 0.85, 0.63 } },
    cat = { app.L("DPS-Ausrüstung"), { 0.95, 0.72, 0.37 } },
    bear = { app.L("Tank-Ausrüstung"), { 0.95, 0.72, 0.37 } },
    auction = { "AH", { 0.65, 0.79, 1 } },
    vendor = { app.L("Händler"), { 1, 0.57, 0.43 } },
}

local function readable(value)
    if not issecretvalue or not issecretvalue(value) then return value end
end
app.Readable = readable

local function lastBag()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

local function generalBag(family)
    family = readable(family)
    return not family or family == 0
end

function app.Settings()
    if type(PaulchenQoLDB) ~= "table" then PaulchenQoLDB = {} end
    if type(PaulchenQoLDB.marks) ~= "table" then PaulchenQoLDB.marks = {} end
    -- Discard progress from the retired minigame mode on character load.
    PaulchenQoLDB.pet = nil
    return PaulchenQoLDB
end

function app.BagItemCount(itemID)
    return getItemCount and (readable(getItemCount(itemID, false)) or 0) or 0
end

function app.ReadTravel()
    local free, capacity = 0, 0
    if container and container.GetContainerNumFreeSlots and container.GetContainerNumSlots then
        for bag = 0, lastBag() do
            local count, family = container.GetContainerNumFreeSlots(bag)
            if generalBag(family) then
                free = free + (readable(count) or 0)
                capacity = capacity + (readable(container.GetContainerNumSlots(bag)) or 0)
            end
        end
    end
    local durability
    for slot = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 19 do
        local current, maximum
        if GetInventoryItemDurability then current, maximum = GetInventoryItemDurability(slot) end
        current, maximum = readable(current), readable(maximum)
        if current and maximum and maximum > 0 then
            local percent = current / maximum * 100
            durability = durability and math.min(durability, percent) or percent
        end
    end
    local hasHearth = app.BagItemCount(hearthstone) > 0
    local readyAt
    if hasHearth and C_Item and C_Item.GetItemCooldown then
        local start, duration = C_Item.GetItemCooldown(hearthstone)
        start, duration = readable(start), readable(duration)
        if start and duration and start > 0 and duration > 1.5 then readyAt = start + duration end
    end
    return {
        free = free, capacity = capacity, durability = durability,
        hasHearth = hasHearth, readyAt = readyAt,
        bind = hasHearth and GetBindLocation and readable(GetBindLocation()) or nil,
    }
end

function app.TravelWarning(travel)
    if travel.capacity > 0 and travel.free == 0 then
        return "full", app.L("Mein Gepäck platzt aus allen Nähten. Deine Taschen sind voll!")
    end
    if travel.durability and travel.durability <= 30 then
        return "repair", (app.L("Psst, Zeit für den Schmied. Dein am stärksten abgenutztes Teil hat noch %d %% Haltbarkeit."))
            :format(math.floor(travel.durability))
    end
    if travel.capacity > 0 and travel.free <= 4 then
        local space = travel.free == 1 and app.L("1 Platz ist") or travel.free .. app.L(" Plätze sind")
        return "space", "Nur noch " .. space .. app.L(" frei. Soll ich schon mal nach einem Händler Ausschau halten?")
    end
end

-- Ignore viewer level, enchants and unique IDs so an item keeps its mark
-- when it moves bags. Random suffixes and bonus lists stay distinct.
local function itemKey(id, link)
    local item = link and link:match("|Hitem:([^|]+)|h")
    if not item then return tostring(id) end
    local fields = {}
    for field in (item .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = field end
    local suffix = tonumber(fields[7]) or 0
    local bonuses = ""
    for _, index in ipairs({ 13, 12 }) do
        local count = tonumber(fields[index]) or 0
        if count > 0 and index + count <= #fields then
            local valid = true
            for i = index + 1, index + count do
                if (tonumber(fields[i]) or 0) <= 0 then valid = false; break end
            end
            if valid then
                bonuses = table.concat(fields, ":", index + 1, index + count)
                break
            end
        end
    end
    if suffix == 0 and bonuses == "" then return tostring(id) end
    return ("%d:%d:%s"):format(id, suffix, bonuses)
end

app.BagItemKey = itemKey

local function canClearSlot(bag, slot)
    local questInfo = container.GetContainerItemQuestInfo and readable(container.GetContainerItemQuestInfo(bag, slot))
    return not questInfo or (readable(questInfo.isQuestItem) ~= true and (readable(questInfo.questID) or 0) == 0)
end

function app.ReadBags(marks)
    local items, byKey, pending = {}, {}, {}
    if not (container and container.GetContainerNumSlots and container.GetContainerItemInfo and getItemInfo) then
        return items, pending
    end
    local occupied = marks and {} or nil
    for bag = 0, lastBag() do
        local scanSlots = false
        if occupied and container.GetContainerNumFreeSlots then
            local _, family = container.GetContainerNumFreeSlots(bag)
            scanSlots = generalBag(family)
        end
        for slot = 1, readable(container.GetContainerNumSlots(bag)) or 0 do
            local info = readable(container.GetContainerItemInfo(bag, slot))
            local id = info and readable(info.itemID)
            if id then
                local link = readable(info.hyperlink)
                local key = itemKey(id, link)
                local item = byKey[key]
                if not item then
                    item = {
                        id = id, key = key, link = link or ("item:" .. id),
                        name = link and link:match("|h%[(.-)%]|h"),
                        quality = readable(info.quality), icon = readable(info.iconFileID),
                        count = 0, sellable = 0,
                    }
                    byKey[key] = item
                    items[#items + 1] = item
                end
                local count = readable(info.stackCount) or 1
                item.count = item.count + count
                if readable(info.hasNoValue) == false then
                    item.sellable = item.sellable + count
                    local mark = marks and marks[key]
                    if scanSlots and (not mark or mark == "vendor") and readable(info.isLocked) == false
                        and link and canClearSlot(bag, slot) then
                        occupied[#occupied + 1] = { bag = bag, slot = slot, count = count, item = item, link = link }
                    end
                end
            end
        end
    end
    for _, item in ipairs(items) do
        local name, _, quality, _, _, _, _, _, _, icon, price, class = getItemInfo(item.link)
        item.name = item.name or readable(name) or (app.L("Gegenstand ") .. item.id)
        item.quality = item.quality or readable(quality)
        item.icon = item.icon or readable(icon) or 134400
        item.vendorPrice = readable(price)
        item.isQuest = readable(class) == (Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12)
        if item.vendorPrice == nil then pending[item.id] = true end
    end
    table.sort(items, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    local cheapest
    for _, stack in ipairs(occupied or {}) do
        local price = stack.item.vendorPrice
        if price and price > 0 and not stack.item.isQuest then
            stack.value = price * stack.count
            if not cheapest or stack.value < cheapest.value then cheapest = stack end
        end
    end
    return items, pending, cheapest
end

-- Event registration is optional for features whose client events differ.
function app.RegisterSupported(frame, event)
    if pcall(frame.RegisterEvent, frame, event) then return true end
    if app.Debug then app.Debug(app.L("Ereignis fehlt: ") .. event) end
end

function app.SecureCall(label, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and app.Debug then app.Debug(label .. " · " .. tostring(err)) end
    return ok
end

function app.StackStillThere(stack)
    local info = readable(container.GetContainerItemInfo(stack.bag, stack.slot))
    return info and readable(info.hyperlink) == stack.link and readable(info.stackCount) == stack.count
        and readable(info.isLocked) == false
end

function app.FindItems(items, marks, group, query)
    local result, vendorCount, vendorTotal = {}, 0, 0
    local function lower(text)
        return text:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"):lower()
    end
    query = lower(query:match("^%s*(.-)%s*$"))
    for _, item in ipairs(items) do
        local mark = marks[item.key]
        if group == "all" or group == mark or (group == "keep" and (mark == "cat" or mark == "bear")) then
            local tag = app.marks[mark]
            if query == "" or lower(item.name):find(query, 1, true) or query == tostring(item.id)
                or tag and lower(tag[1]):find(query, 1, true) then
                result[#result + 1] = item
                if mark == "vendor" and item.vendorPrice and item.vendorPrice > 0 then
                    vendorCount = vendorCount + item.sellable
                    vendorTotal = vendorTotal + item.vendorPrice * item.sellable
                end
            end
        end
    end
    return result, vendorCount, vendorTotal
end
