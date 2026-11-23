local _, suite = ...
local api = suite.auction
if not api then return end
PaulchenAuktionsscan = api
local ah = C_AuctionHouse
local instantInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local listeners = {}
local open, scan
local status = suite.L("Bereit")
local batchSize = 250

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function report(message)
    status = message
    print(suite.L("Paulchen Auktionsscan · ") .. message)
end

local function realmData()
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName())
    local faction = UnitFactionGroup("player")
    if not realm or realm == "" or not faction then return nil end
    local key = realm .. ":" .. faction
    PaulchenQoLAuctionDB = PaulchenQoLAuctionDB or {}
    local data = PaulchenQoLAuctionDB[key]
    if not data then
        data = { searches = {} }
        PaulchenQoLAuctionDB[key] = data
    end
    return data
end

-- Saved results are read-only to consumers.
function api.GetSnapshot()
    local data = realmData()
    return data and data.full, data and data.searches
end

function api.IsOpen() return open == true end

function api.OnUpdated(callback)
    listeners[#listeners + 1] = callback
end

local function updated()
    for _, callback in ipairs(listeners) do
        local ok, err = pcall(callback)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end

local function isEquipment(id)
    if not instantInfo then return nil end
    local ok, _, _, _, slot = pcall(instantInfo, id)
    slot = ok and plain(slot)
    if type(slot) ~= "string" then return nil end
    return slot:find("^INVTYPE_") ~= nil and slot ~= "INVTYPE_NON_EQUIP"
        and slot ~= "INVTYPE_BAG" and slot ~= "INVTYPE_AMMO" and slot ~= "INVTYPE_QUIVER"
end

local function addOffer(items, id, link, price, quantity, timeLeft)
    id, link, price, quantity = plain(id), plain(link), plain(price), plain(quantity)
    if type(id) ~= "number" or id <= 0 or type(link) ~= "string" or type(price) ~= "number" or price <= 0 then return end
    local target = link:match("|H(item:[^|]+)|h") or link:match("^(item:[%d:%-]+)$")
    if not target or tonumber(target:match("^item:(%d+)")) ~= id then return end
    local item = items[id]
    if not item then
        if not isEquipment(id) then return end
        item = {}
        items[id] = item
    end
    quantity = type(quantity) == "number" and math.max(1, quantity) or 1
    local unitPrice = math.floor(price / quantity + 0.5)
    local prior = item[target]
    if not prior or unitPrice < prior.price then
        item[target] = { link = link, price = unitPrice, timeLeft = plain(timeLeft) }
    end
end

local function finish(job)
    local data = realmData()
    scan = nil
    if not data then return end
    local count = 0
    for _ in pairs(job.items) do count = count + 1 end
    if count == 0 then
        report(suite.L("Der Vollscan hat keine Ausrüstung mit Sofortkaufpreis geliefert. Normale AH-Suchen werden weiter erfasst."))
        return
    end
    data.full = { at = job.at, items = job.items, count = count }
    for signature, search in pairs(data.searches) do
        if search.at <= job.at then data.searches[signature] = nil end
    end
    report((suite.L("Vollscan gespeichert · %d verschiedene Ausrüstungsgegenstände.")):format(count))
    updated()
end

local function readListing(job, index, retry)
    local ok, _, _, quantity, _, _, _, _, _, _, price, _, _, _, owner, _, _, id =
        pcall(ah.GetReplicateItemInfo, index)
    if not ok then return false end
    owner, price, id = plain(owner), plain(price), plain(id)
    if owner and owner ~= "" and owner == job.playerName then return true end
    if type(price) ~= "number" or price <= 0 or type(id) ~= "number" or id <= 0 then return true end
    local equipment = job.equipment[id]
    if equipment == nil then
        equipment = isEquipment(id)
        job.equipment[id] = equipment
    end
    if equipment == false then return true end
    local linkOK, link = pcall(ah.GetReplicateItemLink, index)
    link = linkOK and plain(link)
    if equipment and type(link) == "string" and link ~= "" then
        addOffer(job.items, id, link, price, quantity)
    elseif not retry and C_Item and C_Item.RequestLoadItemDataByID then
        job.pending[#job.pending + 1] = index
        if not job.requested[id] then
            job.requested[id] = true
            pcall(C_Item.RequestLoadItemDataByID, id)
        end
    end
    return true
end

local function readReplicate(job)
    if scan ~= job then return end
    local total = job.retry and #job.pending or job.total
    local stop = math.min(job.cursor + batchSize, total)
    while job.cursor < stop do
        local index = job.retry and job.pending[job.cursor + 1] or job.cursor
        if not readListing(job, index, job.retry) then
            scan = nil
            report(suite.L("Der Serverstand konnte nicht gelesen werden. Vorherige Daten bleiben verfügbar."))
            return
        end
        job.cursor = job.cursor + 1
    end
    if job.cursor < total then
        status = suite.LF(job.retry and "Lese nachgeladene Itemdaten · %d / %d" or "Lese Auktionen · %d / %d", job.cursor, total)
        C_Timer.After(0.01, function() readReplicate(job) end)
    elseif not job.retry and #job.pending > 0 then
        job.retry, job.cursor = true, 0
        status = suite.L("Warte auf nachgeladene Itemdaten.")
        C_Timer.After(2, function() readReplicate(job) end)
    else
        finish(job)
    end
end

function api.Start()
    if not open then report(suite.L("Öffne zuerst das Auktionshaus.")); return false end
    if scan then print(suite.L("Paulchen Auktionsscan · ") .. status); return false end
    if not (ah and ah.ReplicateItems and ah.GetNumReplicateItems and ah.GetReplicateItemInfo and ah.GetReplicateItemLink) then
        report(suite.L("Der Client bietet keinen Vollscan an. Normale AH-Suchen werden erfasst."))
        return false
    end
    local job = { items = {}, equipment = {}, pending = {}, requested = {}, cursor = 0, playerName = UnitName("player") }
    scan = job
    report(suite.L("Vollscan angefragt. Warte auf die Antwort des Auktionshauses."))
    if not pcall(ah.ReplicateItems) then
        scan = nil
        report(suite.L("Vollscan derzeit nicht möglich. Normale AH-Suchen werden erfasst."))
        return false
    end
    C_Timer.After(30, function()
        if scan == job and not job.total then
            scan = nil
            report(suite.L("Keine Antwort auf den Vollscan. Normale AH-Suchen werden weiter erfasst."))
        end
    end)
    return true
end

local function captureSearch(key)
    key = plain(key)
    if not open or type(key) ~= "table" or not (ah.GetNumItemSearchResults and ah.GetItemSearchResultInfo) then return end
    local id = plain(key.itemID)
    if type(id) ~= "number" or id <= 0 then return end
    local ok, total = pcall(ah.GetNumItemSearchResults, key)
    if not ok or type(plain(total)) ~= "number" then return end
    local items = {}
    for i = 1, total do
        local read, result = pcall(ah.GetItemSearchResultInfo, key, i)
        result = read and plain(result)
        if type(result) ~= "table" then return end
        local accountItem, ownerItem, price = result.containsAccountItem, result.containsOwnerItem, result.buyoutAmount
        -- An unreadable row cannot prove an item is no longer for sale.
        -- Keep the previous snapshot until this search can be read completely.
        if issecretvalue and (issecretvalue(accountItem) or issecretvalue(ownerItem) or issecretvalue(price)) then return end
        if not accountItem and not ownerItem and type(price) == "number" and price > 0 then
            local link = plain(result.itemLink)
            if type(link) ~= "string" or link == "" then return end
            addOffer(items, id, link, price, result.quantity, result.timeLeftSeconds)
        end
    end
    local data = realmData()
    if not data then return end
    local signature = ("%d:%d:%d"):format(id, plain(key.itemLevel) or 0, plain(key.itemSuffix) or 0)
    if not items[id] and not data.searches[signature] and not (data.full and data.full.items[id]) then return end
    local complete = false
    if ah.HasFullItemSearchResults and (plain(key.itemLevel) or 0) == 0 and (plain(key.itemSuffix) or 0) == 0 then
        local read, all = pcall(ah.HasFullItemSearchResults, key)
        complete = read and plain(all) == true
    end
    data.searches[signature] = { id = id, at = GetServerTime(), offers = items[id] or {}, complete = complete }
    updated()
end

if ah then
    local events = CreateFrame("Frame")
    events:RegisterEvent("AUCTION_HOUSE_SHOW")
    events:RegisterEvent("AUCTION_HOUSE_CLOSED")
    events:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
    events:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
    events:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
    events:SetScript("OnEvent", function(_, event, argument)
        if event == "AUCTION_HOUSE_SHOW" then
            open = true
        elseif event == "AUCTION_HOUSE_CLOSED" then
            open = false
            if scan then scan = nil; report(suite.L("Vollscan abgebrochen. Das Auktionshaus wurde geschlossen.")) end
        elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
            if not scan or scan.total then return end
            local ok, count = pcall(ah.GetNumReplicateItems)
            if not ok or type(plain(count)) ~= "number" or count <= 0 then
                scan = nil
                report(suite.L("Der Vollscan hat keine Daten geliefert. Normale AH-Suchen werden erfasst."))
                return
            end
            scan.total, scan.at = count, GetServerTime()
            readReplicate(scan)
        else
            captureSearch(argument)
        end
    end)
end

SLASH_PAULCHENAH1 = "/pah"
SlashCmdList.PAULCHENAH = function(message)
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "stop" then
        if scan then scan = nil; report(suite.L("Vollscan abgebrochen.")) end
    elseif command == "status" then
        print(suite.L("Paulchen Auktionsscan · ") .. status)
    elseif command == "" then
        api.Start()
    else
        print(suite.L("Paulchen Auktionsscan · /pah  ·  /pah status  ·  /pah stop"))
    end
end
