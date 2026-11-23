local _, app = ...

local TTL = 60
local prices, tsmMisses, minBuyouts, observed = {}, {}, {}, {}
local cleanAt, scannerIndex = 0, nil
local tsmAPI, tsmLoaded
local onChanged
local sources = {
    { "auto", app.L("Automatisch") },
    { "tsm", app.L("TradeSkillMaster bevorzugen") },
    { "scanner", app.L("Nur Paulchens Scanner") },
}
app.AuctionPriceModes = sources

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, first, second = pcall(fn, ...)
    if ok then return app.Readable(first), app.Readable(second) end
end

local function positive(value)
    if type(value) == "number" and value > 0 and value < math.huge then return value end
end

-- Match the scanner's saved links without per-instance identity and viewer level.
-- Preserve the suffix, bonus IDs, modifiers, enchants and gems.
local function itemKey(link, itemID)
    if link == nil and positive(itemID) then return tostring(itemID), itemID end
    if type(link) ~= "string" then return end
    local payload = link:match("|[Hh]item:([%d:%-]+)|h") or link:match("^item:([%d:%-]+)$")
    if not payload then return end
    local fields = {}
    for field in (payload .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = field end
    local id = positive(tonumber(fields[1]))
    if not id or (itemID and itemID ~= id) then return end
    fields[1] = tostring(id)
    for index = 2, #fields do
        if index == 8 or index == 9 or fields[index] == "" then fields[index] = "0" end
    end
    while fields[#fields] == "0" do fields[#fields] = nil end
    local suffix = (tonumber(fields[7]) or 0) ~= 0
    local bonuses = (tonumber(fields[13]) or 0) > 0 or #fields > 13
    return table.concat(fields, ":"), id, suffix, bonuses
end

local function invalidate()
    prices, tsmMisses, minBuyouts, observed = {}, {}, {}, {}
    cleanAt, scannerIndex = 0, nil
end

local function changed()
    invalidate()
    if onChanged then onChanged() end
end

function app.OnAuctionPricesChanged(callback)
    onChanged = callback
end
app.RefreshAuctionPrices = changed

function app.GetAuctionPriceMode()
    local mode = app.Profile().auctionPriceSource
    return (mode == "tsm" or mode == "scanner") and mode or "auto"
end

function app.SetAuctionPriceMode(mode)
    for _, entry in ipairs(sources) do
        if mode == entry[1] and mode ~= app.GetAuctionPriceMode() then
            app.Profile().auctionPriceSource = mode
            changed()
            return
        end
    end
end

local function availableTSM()
    local api = TSM_API
    if type(api) ~= "table" or type(api.ToItemString) ~= "function"
        or type(api.GetCustomPriceValue) ~= "function" then api = nil end
    if api ~= tsmAPI then
        tsmLoaded = nil
        tsmAPI = api
        invalidate()
    end
    if api and tsmLoaded == nil then
        tsmLoaded = call(C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded, "TradeSkillMaster") == true
    end
    return tsmLoaded and api or nil
end

local function getTSMPrice(api, source, link, id, suffix, bonuses)
    local itemString = call(api.ToItemString, link or ("item:" .. id))
    if type(itemString) ~= "string" or tonumber(itemString:match("^i:(%d+)")) ~= id then return end
    local variant = itemString:match("^i:%d+:([^:]*)")
    if suffix and (tonumber(variant) or 0) == 0 then return end
    -- Some link formats collapse bonus items to their base or suffix-only TSM key.
    if bonuses and not itemString:match("^i:%d+:[^:]*:[^:]*:.+") then return end
    return positive(call(api.GetCustomPriceValue, source, itemString))
end

local function cacheTime()
    local now = call(GetTime) or 0
    if now >= cleanAt then
        for _, cache in ipairs({ prices, minBuyouts }) do
            for variant, cached in pairs(cache) do
                if now >= cached.expires then cache[variant] = nil end
            end
        end
        for variant, expires in pairs(tsmMisses) do
            if now >= expires then tsmMisses[variant] = nil end
        end
        scannerIndex, cleanAt = nil, now + TTL
    end
    return now
end

function app.GetTSMMinBuyout(itemLink, itemID)
    local tsm = app.GetAuctionPriceMode() ~= "scanner" and availableTSM()
    if not tsm then return end
    itemLink = app.Readable(itemLink)
    local key, id, suffix, bonuses = itemKey(itemLink, app.Readable(itemID))
    if not key then return end
    local now = cacheTime()
    local cached = minBuyouts[key]
    if cached and now < cached.expires then return cached.price end
    local price = getTSMPrice(tsm, "DBMinBuyout", itemLink, id, suffix, bonuses)
    minBuyouts[key] = { price = price, expires = now + TTL }
    return price
end

local function readScanner()
    local scanner = app.auction or PaulchenAuktionsscan
    local full, searches = call(scanner and scanner.GetSnapshot)
    local index = {}
    for _, search in pairs(type(searches) == "table" and searches or {}) do
        if type(search) == "table" and positive(search.id) and positive(search.at) then
            local entry = index[search.id] or { latestComplete = 0 }
            index[search.id] = entry
            entry[#entry + 1] = search
            if search.complete then entry.latestComplete = math.max(entry.latestComplete, search.at) end
        end
    end
    return {
        items = type(full) == "table" and type(full.items) == "table" and full.items or {},
        at = type(full) == "table" and positive(full.at) or nil,
        searches = index,
    }
end

local function getScannerPrice(id, key, now)
    scannerIndex = scannerIndex or readScanner()
    local index = scannerIndex
    local scans = index.searches[id]
    local cutoff = scans and scans.latestComplete or 0
    local best, at, expires
    local function consider(offers, scannedAt)
        if type(offers) ~= "table" or (at and scannedAt < at) then return end
        for rawLink, offer in pairs(offers) do
            local price = type(offer) == "table" and positive(offer.price)
            if price and itemKey(offer.link or rawLink, id) == key then
                local ends = positive(offer.timeLeft) and scannedAt + offer.timeLeft
                if (not ends or not now or ends > now)
                    and (not best or scannedAt > at or price < best) then
                    best, at, expires = price, scannedAt, ends
                end
            end
        end
    end
    if index.at and index.at > cutoff then consider(index.items[id], index.at) end
    for _, scan in ipairs(scans or {}) do
        if scan.at >= cutoff and scan.at >= (index.at or 0) then consider(scan.offers, scan.at) end
    end
    return best, at, expires
end

function app.GetAuctionPrice(itemLink, itemID)
    itemLink = app.Readable(itemLink)
    local key, id, suffix, bonuses = itemKey(itemLink, app.Readable(itemID))
    if not key then return nil, "NONE" end
    local tsm = app.GetAuctionPriceMode() ~= "scanner" and availableTSM()
    local now = cacheTime()
    local cached = prices[key]
    if cached and now < cached.expires then return cached.price, cached.source, cached.info end

    local price
    if tsm and now >= (tsmMisses[key] or 0) then
        price = getTSMPrice(tsm, "DBMarket", itemLink, id, suffix, bonuses)
        if not price then tsmMisses[key] = now + TTL end
    end
    local source, info, expires = "NONE", nil, now + TTL
    if price then
        source = "TSM_DBMarket"
    else
        local serverNow = call(GetServerTime)
        local at, ends
        price, at, ends = getScannerPrice(id, key, serverNow)
        if price then
            source, info = "PAULCHEN_SCAN", { at = at }
            if ends and serverNow then expires = math.min(expires, now + ends - serverNow) end
        end
    end
    if price then observed[source] = now + TTL end
    prices[key] = { price = price, source = source, info = info, expires = expires }
    return price, source, info
end

function app.GetAuctionPriceStatus()
    local tsm = availableTSM()
    local installed = tsm or call(C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo, "TradeSkillMaster")
    local now = call(GetTime) or 0
    local status
    if not installed then
        status = app.L("TSM nicht installiert")
    elseif app.GetAuctionPriceMode() == "scanner" then
        status = app.L("TSM in Paulchen deaktiviert")
    elseif (observed.TSM_DBMarket or 0) > now then
        status = app.L("TSM aktiv · DBMarket")
    else
        status = app.L("TSM installiert · Preisdaten nicht verfügbar")
    end
    return status, (observed.PAULCHEN_SCAN or 0) > now
        and app.L("Paulchens Scanner aktiv") or app.L("Scanner · keine Preise in der aktuellen Abfrage")
end

local scanner = app.auction or PaulchenAuktionsscan
if scanner then
    call(scanner.OnUpdated, function()
        scannerIndex, observed.PAULCHEN_SCAN = nil, nil
        for variant, cached in pairs(prices) do
            if cached.source ~= "TSM_DBMarket" then prices[variant] = nil end
        end
        if onChanged then onChanged() end
    end)
end
local events = CreateFrame("Frame")
app.RegisterSupported(events, "ADDON_LOADED")
app.RegisterSupported(events, "PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == "TradeSkillMaster" then
        tsmLoaded = nil
        changed()
    end
end)
