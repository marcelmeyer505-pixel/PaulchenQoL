local _, suite = ...
local app = suite.upgrades
if not app then return end
local pole, gear = Polestar, Polestar.Gear
local readable = pole.Compat.Readable
local recent, pending = {}, {}
local retryDelays = { 0.2, 0.5, 1, 2 }
local shown, available = {}, {}
local lastSound

function app.LootAlertsEnabled()
    return not PaulchenQoLUpgradesDB or PaulchenQoLUpgradesDB.lootAlerts ~= false
end

local function read(fn, ...)
    if not fn then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return readable(value) end
end

local function cardText(card, font, x, y, width)
    local text = card:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint("TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function createCard()
    local card = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    card:SetFrameStrata("HIGH")
    card:SetSize(400, 77)
    card:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    card:SetBackdropColor(0.056, 0.073, 0.077, 0.97)
    card:SetBackdropBorderColor(0.86, 0.65, 0.28)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(43, 43)
    card.icon:SetPoint("LEFT", 13, 0)
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local heading = cardText(card, "GameFontNormalSmall", 67, -11, 318)
    heading:SetText("UPGRADE GEDROPPT")
    heading:SetTextColor(0.98, 0.81, 0.46)
    card.nameText = cardText(card, "GameFontHighlightLarge", 67, -28, 318)
    card.gainText = cardText(card, "GameFontHighlightSmall", 67, -54, 318)
    card.gainText:SetTextColor(0.53, 0.92, 0.68)
    return card
end

local function layout()
    for i, card in ipairs(shown) do
        card:ClearAllPoints()
        card:SetPoint("TOP", UIParent, "TOP", 0, -146 - (i - 1) * 84)
    end
end

local function announce(link, id, result, now)
    local slot = app.slotNames[result.slot] or (result.slot == 12 and app.slotNames[11])
        or (result.slot == 14 and app.slotNames[13])
    local gain = result.pct and ("+%.1f %%"):format(result.pct) or ("+%.2f Punkte"):format(result.delta)
    if result.pct and result.pct < 0.05 then gain = "+<0.1 %" end
    gain = gain:gsub("%.", ",")
    if result.empty then gain = gain .. " · Freier Slot" end
    local detail = slot and (gain .. " · " .. slot) or gain
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cfffad176Paulchen Upgrades|r · " .. link .. " · |cff87eaae" .. detail .. "|r")
    end
    local card
    if #shown == 3 then card = table.remove(shown, 1)
    else card = table.remove(available) or createCard() end
    card.sequence = (card.sequence or 0) + 1
    local sequence = card.sequence
    local itemName = link:match("|h%[(.-)%]|h") or read(pole.Compat.GetItemName, id) or ("Item " .. id)
    local icon = read(pole.Compat.ItemIcon, id) or 134400
    card.icon:SetTexture(icon)
    card.nameText:SetText(itemName)
    card.gainText:SetText(detail)
    shown[#shown + 1] = card
    layout()
    card:Show()
    C_Timer.After(6, function()
        if card.sequence ~= sequence then return end
        for i, active in ipairs(shown) do
            if active == card then table.remove(shown, i); break end
        end
        card:Hide()
        available[#available + 1] = card
        layout()
    end)
    local sound = SOUNDKIT and (SOUNDKIT.UI_EPICLOOT_TOAST or SOUNDKIT.RAID_WARNING)
    if sound and PlaySound and (not lastSound or now - lastSound > 1) then
        lastSound = now
        pcall(PlaySound, sound, "SFX")
    end
end

local function evaluate(link)
    local result = gear.CompareToEquipped(link)
    if not result then return nil end
    return app.IsUpgrade(result, gear.GetPlayer().level) and result or false
end

local function watchLink(link, kind, rollTime)
    if not app.LootAlertsEnabled() or type(link) ~= "string" then return end
    local id = tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))
    if not id or id < 1 then return end
    local key = app.VariantKey(link) or id
    app.ObserveVariant(link)
    local now = GetTime()
    for key, alert in pairs(recent) do
        if now >= alert.untilTime and now >= alert.rollUntil then recent[key] = nil end
    end
    local rollUntil = kind == "roll" and (now + math.max(0, (tonumber(rollTime) or 60000) / 1000) + 6) or 0
    local alert = recent[key]
    if alert and (now < alert.untilTime or (kind == "chat" and now < alert.rollUntil)) then
        alert.rollUntil = math.max(alert.rollUntil, rollUntil)
        return
    end
    if pending[key] then
        pending[key].rollUntil = math.max(pending[key].rollUntil, rollUntil)
        return
    end
    local job = { rollUntil = rollUntil }
    pending[key] = job
    local function check(attempt)
        if not app.LootAlertsEnabled() then pending[key] = nil; return end
        local ok, result = pcall(evaluate, link)
        if ok and result ~= nil then
            pending[key] = nil
            if result then
                local time = GetTime()
                recent[key] = { untilTime = time + 8, rollUntil = job.rollUntil }
                announce(link, id, result, time)
            end
        elseif retryDelays[attempt] then
            if attempt == 1 and C_Item then read(C_Item.RequestLoadItemDataByID, id) end
            C_Timer.After(retryDelays[attempt], function() check(attempt + 1) end)
        else
            pending[key] = nil
        end
    end
    check(1)
end

local lootPatterns = {}
for _, key in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF" }) do
    local fmt = _G[key]
    if type(fmt) == "string" then
        local pattern = fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        pattern = pattern:gsub("%%%%%d+%%%$s", "(.+)", 1):gsub("%%%%s", "(.+)", 1)
        pattern = pattern:gsub("%%%%%d+%%%$d", "%%d+"):gsub("%%%%d", "%%d+")
        lootPatterns[#lootPatterns + 1] = "^" .. pattern .. "$"
    end
end

local function lootWindow()
    for slot = 1, read(GetNumLootItems) or 0 do
        watchLink(read(GetLootSlotLink, slot), "loot")
    end
end

local function roll(rollID, rollTime, attempt)
    if not app.LootAlertsEnabled() then return end
    local link = read(GetLootRollItemLink, rollID)
    if link then
        watchLink(link, "roll", rollTime)
    elseif attempt < 2 then
        C_Timer.After(0.25, function() roll(rollID, rollTime, attempt + 1) end)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("START_LOOT_ROLL")
events:RegisterEvent("CHAT_MSG_LOOT")
events:SetScript("OnEvent", function(_, event, first, second)
    if not app.LootAlertsEnabled() then return end
    if event == "START_LOOT_ROLL" then
        first, second = readable(first), readable(second)
        if type(first) == "number" then roll(first, second, 0) end
    elseif event == "CHAT_MSG_LOOT" then
        local message = readable(first)
        if type(message) ~= "string" then return end
        for _, pattern in ipairs(lootPatterns) do
            local link = message:match(pattern)
            if link then watchLink(link, "chat"); break end
        end
    else
        lootWindow()
    end
end)
