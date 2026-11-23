local _, suite = ...
local app = suite.upgrades
if not app then return end
local pole, gear = Polestar, app.gear
local itemDB = pole and pole.ItemDB
local function sourceRecord(id) return itemDB and itemDB.Get(id) end
local itemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local detailedItemLevel = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
local cachedInfo = C_Item and C_Item.IsItemDataCachedByID
local instantInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local boe = Enum and Enum.ItemBind and Enum.ItemBind.OnEquip or 2
local requestLimit, batchSize, requestTimeout = 40, 128, 5
local requestBurst, cpuBudget, tailSeconds = 8, 1.5, 20
local readable = suite.Readable

local itemScores, weaponScores = {}, {}
local savedScoreVersion = 3
local savedScores, savedEquipment
local linkScores, savedLinks = {}, nil
app.On("GEAR_UPDATED", function(what, id)
    if what == "items" and id then
        itemScores[id], weaponScores[id] = nil, nil
        linkScores[id] = nil
        if savedLinks then savedLinks[id] = nil end
        return
    end
    if what == "bagItems" then return end
    if what == "bags" then
        for _, links in pairs(linkScores) do
            for key, entry in pairs(links) do if entry.pairing then links[key] = nil end end
        end
    else linkScores = {} end
    weaponScores = {}
    if what ~= "bags" then itemScores = {} end
    if what ~= "bags" and what ~= "items" and what ~= "skills" then savedScores = nil end
end)

local missingCache, missingCount
local function missingData()
    PaulchenQoLUpgradesDB = PaulchenQoLUpgradesDB or {}
    local key = tostring(GetBuildInfo and select(2, GetBuildInfo()) or "") .. ":" .. (GetRealmName and GetRealmName() or "")
    local cache = PaulchenQoLUpgradesDB.missingItemData
    if type(cache) ~= "table" or cache.key ~= key or type(cache.items) ~= "table" then
        cache = { key = key, items = {} }
        PaulchenQoLUpgradesDB.missingItemData = cache
    end
    if missingCache ~= cache then
        missingCache, missingCount = cache, 0
        local now = (GetServerTime or time)()
        for id, expiry in pairs(cache.items) do
            if type(expiry) ~= "number" or expiry <= now then cache.items[id] = nil
            else missingCount = missingCount + 1 end
        end
    end
    return cache.items
end
local function forgetMissing(id)
    local cache = missingData()
    if cache[id] then cache[id], missingCount = nil, missingCount - 1 end
end
local function rememberMissing(id)
    local cache = missingData()
    if cache[id] or missingCount < 5000 then
        if not cache[id] then missingCount = missingCount + 1 end
        cache[id] = (GetServerTime or time)() + 300
    end
end
local function recentlyMissing(id)
    local expiry = missingData()[id]
    if not expiry then return false end
    if expiry > (GetServerTime or time)() then return true end
    forgetMissing(id)
    return false
end

local function itemDataReceived(_, id, success)
    id = tonumber(readable(id))
    if not id or readable(success) == false then return end
    forgetMissing(id)
    itemScores[id], weaponScores[id] = nil, nil
    linkScores[id] = nil
    local cache = PaulchenQoLUpgradesDB and PaulchenQoLUpgradesDB.scoreCache
    if type(cache) == "table" and type(cache.items) == "table" then cache.items[id] = nil end
    if type(cache) == "table" and type(cache.links) == "table" then cache.links[id] = nil end
    if savedEquipment and savedEquipment[id] then savedScores, savedLinks = nil, nil end
end
app.RegisterEvent("GET_ITEM_INFO_RECEIVED", itemDataReceived)
app.RegisterEvent("ITEM_DATA_LOAD_RESULT", itemDataReceived)

local function statKey(stats)
    local fields = {}
    for name, value in pairs(stats) do fields[#fields + 1] = ("%s=%.17g"):format(name, value) end
    table.sort(fields)
    return table.concat(fields, ",")
end

local function restoreScores(player, spec)
    savedScores, savedEquipment, savedLinks = nil, nil, nil
    local weights = gear.GetWeights()
    if not weights then return end
    local key = {
        GetBuildInfo and select(2, GetBuildInfo()) or "", GetLocale and GetLocale() or "",
        player.class or "", player.race or "", player.level, spec or "", statKey(weights),
    }
    local equipment = {}
    for slot = 1, 18 do
        if slot ~= 4 then
            local link = gear.Client.InventoryLink(slot)
            if link then
                local info = gear.GetItemInfo(link)
                if not info then return end
                equipment[info.id] = true
                key[#key + 1] = slot .. ":" .. link .. ":" .. statKey(info.stats)
            end
        end
    end
    local legacySignature = table.concat(key, "\031")
    key[#key + 1] = "eligibility:" .. gear.EligibilityKey()
    local signature = table.concat(key, "\031")
    PaulchenQoLUpgradesDB = PaulchenQoLUpgradesDB or {}
    local cache = PaulchenQoLUpgradesDB.scoreCache
    -- Older saved scores contain only armor without weapon-pair dependencies;
    -- preserve them when equipment, level and weights still match exactly.
    if type(cache) == "table" and cache.version == savedScoreVersion and cache.key == legacySignature
        and type(cache.items) == "table" then cache.key = signature end
    if type(cache) ~= "table" or cache.version ~= savedScoreVersion or cache.key ~= signature
        or type(cache.items) ~= "table" then
        itemScores, weaponScores, linkScores = {}, {}, {}
        cache = { version = savedScoreVersion, key = signature, items = {}, links = {} }
        PaulchenQoLUpgradesDB.scoreCache = cache
    end
    if type(cache.links) ~= "table" then cache.links = {} end
    savedScores, savedEquipment, savedLinks = cache.items, equipment, cache.links
end

local function knownScores(id)
    local current = itemScores[id] or weaponScores[id]
    if current and current.live then return current end
    return savedScores and savedScores[id] or current
end

local function usesBagPairing(inv)
    return inv == 13 or inv == 14 or inv == 21 or inv == 22 or inv == 23
end

local function canSaveScore(record)
    -- Equipment pairings and weapon proficiencies can change between sessions.
    return savedScores and record and record.class == 4 and not usesBagPairing(record.inv)
end

local function savedItemScores(id)
    local scores = savedScores[id]
    if not scores then
        scores = {}
        savedScores[id] = scores
    end
    return scores
end

local function cachedScores(id, record)
    local inv = record and record.inv
    -- Keep any weapon-pairing scores in the current session.
    local bagDependent = not inv or usesBagPairing(inv)
    local cache = bagDependent and weaponScores or itemScores
    local scores = cache[id]
    if not scores then
        scores = {}
        cache[id] = scores
    end
    return scores
end

app.slots = {
    { 1, suite.L("Kopf") }, { 2, suite.L("Hals") }, { 3, suite.L("Schultern") }, { 15, suite.L("Rücken") },
    { 5, suite.L("Brust") }, { 9, suite.L("Handgelenke") }, { 10, suite.L("Hände") }, { 6, suite.L("Taille") },
    { 7, suite.L("Beine") }, { 8, suite.L("Füße") }, { 11, suite.L("Finger") }, { 13, suite.L("Schmuck") },
    { 16, suite.L("Waffenhand") }, { 17, suite.L("Nebenhand") }, { 18, suite.L("Fernwaffe / Relikt") },
}
local slots = { [12] = 11, [14] = 13 }
app.slotNames = {}
for _, slot in ipairs(app.slots) do app.slotNames[slot[1]] = slot[2] end

local function readCachedItem(id, variant)
    if not itemInfo then return end
    if cachedInfo then
        local ok, cached = pcall(cachedInfo, id)
        if not ok then return nil, cached end
        if readable(cached) ~= true then return end
    end
    local ok, name, link, quality, itemLevel, requiredLevel, _, _, _, _, icon, _, _, _, bind = pcall(itemInfo, variant or id)
    if not ok then return nil, name end
    name, link = readable(name), readable(link)
    if type(name) == "string" and type(link) == "string" then
        return {
            name = variant and variant:match("|h%[(.-)%]|h") or name, link = variant or link,
            quality = readable(quality) or 1, itemLevel = readable(itemLevel), requiredLevel = readable(requiredLevel) or 0,
            icon = readable(icon), boe = readable(bind) == boe,
        }
    end
end

-- Ignore link metadata such as viewer level and enchants when identifying a roll.
function app.VariantKey(link)
    link = readable(link)
    if type(link) ~= "string" then return end
    local item = link:match("|H(item:[^|]+)|h") or link:match("^(item:[%d:%-]+)$")
    if not item then return end
    local fields = {}
    for field in (item:sub(6) .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = field end
    local id = tonumber(fields[1])
    if not id or id <= 0 then return end
    local suffix = tonumber(fields[7]) or 0
    local function bonusIDs(position)
        local count = tonumber(fields[position]) or 0
        if count <= 0 or count > #fields - position then return nil end
        for i = position + 1, position + count do
            if (tonumber(fields[i]) or 0) <= 0 then return nil end
        end
        return table.concat(fields, ":", position + 1, position + count)
    end
    local bonus = bonusIDs(13) or bonusIDs(12) or ""
    if suffix == 0 and bonus == "" then return end
    return id .. ":" .. suffix .. ":" .. bonus, id
end

function app.ObserveVariant(link, quiet)
    local key, id = app.VariantKey(link)
    if not key then return end
    if instantInfo then
        local ok, _, _, _, inv = pcall(instantInfo, id)
        inv = ok and readable(inv)
        if inv and not gear.SLOTS_OF[gear.EQUIP_LOC[inv]] then return end
    end
    PaulchenQoLUpgradesDB = PaulchenQoLUpgradesDB or {}
    local variants = PaulchenQoLUpgradesDB.variants
    if type(variants) ~= "table" then
        variants = {}
        PaulchenQoLUpgradesDB.variants = variants
    end
    if variants[key] then return end
    variants[key] = link
    if not quiet then app.Fire("PAULCHEN_VARIANT_ADDED") end
end

if C_AuctionHouse and C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetItemSearchResultInfo then
    local auctions = CreateFrame("Frame")
    auctions:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
    auctions:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
    auctions:SetScript("OnEvent", function(_, _, itemKey)
        if not itemKey then return end
        local ok, count = pcall(C_AuctionHouse.GetNumItemSearchResults, itemKey)
        if not ok or type(readable(count)) ~= "number" then return end
        for i = 1, count do
            local success, result = pcall(C_AuctionHouse.GetItemSearchResultInfo, itemKey, i)
            if success and result then app.ObserveVariant(result.itemLink) end
        end
    end)
end

local function auctionOffers()
    local scanner = PaulchenAuktionsscan
    if not scanner then return {}, nil end
    local full, searches = scanner.GetSnapshot()
    local now = GetServerTime()
    local items, lastSeen = {}, full and full.at
    local function merge(id, offers, at)
        local matches = items[id] or {}
        items[id] = matches
        for _, offer in pairs(offers) do
            if not offer.timeLeft or at + offer.timeLeft > now then
                local key = app.VariantKey(offer.link) or id
                local prior = matches[key]
                if not prior or at > prior.at or (at == prior.at and offer.price < prior.price) then
                    matches[key] = { link = offer.link, price = offer.price, at = at }
                end
            end
        end
    end
    local latestSearch = {}
    for _, search in pairs(searches or {}) do
        local previous = latestSearch[search.id]
        if search.complete and (not previous or search.at > previous) then latestSearch[search.id] = search.at end
        lastSeen = math.max(lastSeen or 0, search.at)
    end
    for id, offers in pairs(full and full.items or {}) do
        if not latestSearch[id] or latestSearch[id] < full.at then merge(id, offers, full.at) end
    end
    for _, search in pairs(searches or {}) do
        if search.at >= (latestSearch[search.id] or 0) then merge(search.id, search.offers, search.at) end
    end
    return items, lastSeen
end

function app.RecordIssue(scan, id, message)
    scan.errors = scan.errors + 1
    scan.firstError = scan.firstError or ("Item %d · %s"):format(id, tostring(message))
end

function app.IsUpgrade(result, level)
    return result and result.usable and not result.equipped and result.delta and result.delta > 0
        and (result.minLevel or 0) <= level
end

local function browseItems()
    local ah = C_AuctionHouse
    local rows = AuctionHouseFrame and AuctionHouseFrame:IsShown() and ah and ah.GetBrowseResults and readable(ah.GetBrowseResults())
    local observed = {}
    for _, row in ipairs(rows or {}) do
        local key = readable(row.itemKey)
        local link, id
        if key then link, id = gear.AuctionItemLink(key) end
        if link then
            local bucket = app.VariantKey(link) or id
            local price = readable(row.minPrice)
            price = price and price > 0 and price or nil
            local prior = observed[bucket]
            if not prior or price and (not prior.price or price < prior.price) then
                observed[bucket] = { id = id, link = link, price = price }
            end
        end
    end
    return observed
end

local function storeResult(scan, id, item, result)
    if not app.IsUpgrade(result, scan.level) then return end
    local codex = scan.codexLoaded and pole.Codex.Item(id)
    if codex and codex.status == "retired" then return end
    local requiredLevel = math.max(result.minLevel or 0, item and item.requiredLevel or 0, codex and codex.reqLevel or 0)
    if requiredLevel > scan.level then return end
    local slot = slots[result.slot] or result.slot
    if not app.slotNames[slot] then return end
    local sources = app.GetSources(scan, id, item)
    if #sources == 0 then return end
    local name = item and item.name or (itemDB and itemDB.ItemName(id)) or ("Item " .. id)
    local record = sourceRecord(id)
    local link = item and item.link or ("item:" .. id)
    local stats, itemLevel
    if item and item.detailsReady then
        stats, itemLevel = item.stats, item.itemLevel
    else
        local info = gear.GetItemInfo(item and link or id)
        stats = info and info.stats or record and record.stats
        if item and detailedItemLevel then
            local ok, value = pcall(detailedItemLevel, link)
            if ok then itemLevel = readable(value) end
        end
        if not itemLevel or itemLevel <= 0 then itemLevel = item and item.itemLevel end
        if not itemLevel or itemLevel <= 0 then itemLevel = record and record.ilvl end
        if item then
            item.stats, item.itemLevel, item.detailsReady = stats, itemLevel, true
        end
    end
    scan.rows[#scan.rows + 1] = {
        id = id, name = name, link = link, icon = item and item.icon,
        quality = item and item.quality or record and record.quality or 1,
        slot = slot, old = result.old, new = result.new, delta = result.delta, pct = result.pct,
        itemLevel = itemLevel and itemLevel > 0 and itemLevel or nil,
        requiredLevel = requiredLevel, future = requiredLevel > scan.playerLevel,
        stats = stats,
        empty = result.empty, sources = sources,
    }
end

function app.NewScan(maxRequiredLevel)
    if itemDB then itemDB.Load() end
    local player = gear.GetPlayer()
    local profile, class = app.ActiveProfile()
    local spec = profile and class .. ":" .. profile.key
    local scan = {
        level = math.max(player.level, maxRequiredLevel or player.level), playerLevel = player.level,
        faction = player.faction, profile = app.ProfileName(), spec = spec,
        ids = {}, cursor = 1, waiting = {}, count = 0, deferred = {}, nextDeferred = 1,
        rows = {}, unavailable = 0, errors = 0, compared = 0, reused = 0, skippedContent = 0,
        presentItems = {},
    }
    app.PrepareSources(scan)
    restoreScores(player, spec)
    scan.auctions, scan.auctionAt = auctionOffers()
    scan.browseItems, scan.bagItems = browseItems(), {}
    local seen = {}
    local function include(id)
        if not seen[id] then
            seen[id] = true
            scan.ids[#scan.ids + 1] = id
        end
    end
    -- Prioritize loot from the current instance so its upgrades appear first.
    local instanceIndexes = { scan.atlas, scan.journal }
    local here = app.CurrentInstance(scan.atlas, scan.journal)
    if here then
        for _, index in ipairs(instanceIndexes) do
            for id, drops in pairs(index.items) do
                for _, drop in ipairs(drops) do
                    if here[drop.location.name] then include(id); break end
                end
            end
        end
    end
    for id in pairs(scan.activeRewards) do include(id) end
    for _, index in ipairs(instanceIndexes) do
        for id in pairs(index.items) do include(id) end
    end
    for id in pairs(scan.crafting) do include(id) end
    local savedVariants = PaulchenQoLUpgradesDB and PaulchenQoLUpgradesDB.variants
    scan.variants = {}
    local variantKeys = {}
    local function includeVariant(link)
        local key, id = app.VariantKey(link)
        if key and not variantKeys[key] then
            variantKeys[key] = true
            local variants = scan.variants[id] or {}
            variants[#variants + 1] = link
            scan.variants[id] = variants
            include(id)
        end
    end
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        for slot = 1, gear.Client.BagSlots(bag) do
            local link = gear.Client.BagLink(bag, slot)
            local id = gear.ItemID(link)
            if id then
                scan.presentItems[id] = true
                local key = app.VariantKey(link) or id
                scan.bagItems[key] = scan.bagItems[key] or link
                include(id)
                includeVariant(link)
            end
        end
    end
    for _, item in pairs(scan.browseItems) do
        scan.presentItems[item.id] = true
        include(item.id)
        includeVariant(item.link)
    end
    for id, offers in pairs(scan.auctions) do
        if next(offers) then scan.presentItems[id] = true; include(id) end
        for key, offer in pairs(offers) do
            if key ~= id then includeVariant(offer.link) end
        end
    end
    for _, link in pairs(type(savedVariants) == "table" and savedVariants or {}) do
        includeVariant(link)
    end
    if itemDB then
        for id in pairs(app.catalog) do include(id) end
    end
    -- Ownership and concrete offers are collected first, including variants.
    -- Compact before any candidate stats or asynchronous metadata are requested.
    local kept = {}
    for _, id in ipairs(scan.ids) do
        if app.CanSearchItem(scan, id) then kept[#kept + 1] = id
        else scan.skippedContent = scan.skippedContent + 1 end
    end
    scan.ids = kept
    if scan.codexLoaded and instantInfo then
        pole.Codex.Each("item", function(id, _, _, status)
            if not seen[id] and status ~= "retired" then
                if not app.CanSearchItem(scan, id) then
                    seen[id] = true
                    scan.skippedContent = scan.skippedContent + 1
                    return
                end
                local _, _, _, inv = instantInfo(id)
                if inv and gear.SLOTS_OF[gear.EQUIP_LOC[inv]] then include(id) end
            end
        end)
    end
    return scan
end

local function withoutItemData(scan, id, message)
    scan.unavailable = scan.unavailable + 1
    if message then app.RecordIssue(scan, id, message) end
end

local function hasClientStats(link)
    local stats = gear.Client.ItemStats(link)
    for key, value in pairs(stats or {}) do
        if type(key) == "string" and type(readable(value)) == "number" then return true end
    end
    return false
end

local function memoized(id, link)
    local key = gear.ItemKey(link)
    local links = linkScores[id]
    local entry = key and links and links[key]
    if not entry and savedLinks and savedLinks[id] then entry = savedLinks[id][key] end
    if not entry then
        local scores = knownScores(id)
        if scores and scores.live and key and (scores.key == key
            or scores.item and gear.ItemKey(scores.item.link) == key) then entry = scores end
    end
    return entry, key
end

local function comparison(scan, id, item, keepLink)
    local previous, key = memoized(id, item.link)
    if previous then scan.reused = scan.reused + 1; return previous.live end
    local result, cached = gear.CompareToEquipped(item.link)
    if result then
        if cached then scan.reused = scan.reused + 1 else scan.compared = scan.compared + 1 end
        if keepLink and key then
            local info = gear.GetItemInfo(item.link)
            local entry = { live = result, item = item, pairing = not info or usesBagPairing(info.inv) }
            linkScores[id] = linkScores[id] or {}
            linkScores[id][key] = entry
            if canSaveScore(info) and savedLinks then
                savedLinks[id] = savedLinks[id] or {}
                savedLinks[id][key] = entry
            end
        end
    end
    return result
end

local function replayLinks(scan, id)
    local links, entries = {}, {}
    local variants = scan.variants[id]
    if variants then
        for _, link in ipairs(variants) do links[#links + 1] = link end
        local offer = scan.auctions[id] and scan.auctions[id][id]
        local browse = scan.browseItems[id]
        local base = scan.bagItems[id] or offer and offer.link or browse and browse.link
        if base and not app.VariantKey(base) then links[#links + 1] = base end
    else
        local link = scan.bagItems[id] or scan.browseItems[id] and scan.browseItems[id].link
        if not link then return false end
        links[1] = link
    end
    for _, link in ipairs(links) do
        local entry = memoized(id, link)
        if not entry then return false end
        entries[#entries + 1] = entry
    end
    for _, entry in ipairs(entries) do
        scan.reused = scan.reused + 1
        storeResult(scan, id, entry.item, entry.live)
    end
    return #entries > 0
end

local function scoreItem(scan, id, item)
    local variants = scan.variants[id]
    if variants then
        for _, link in ipairs(variants) do
            local variant = readCachedItem(id, link)
            local stats = variant and gear.Client.ItemStats(link)
            if stats and next(stats) then
                storeResult(scan, id, variant, comparison(scan, id, variant, true))
            end
        end
        local baseOffer = scan.auctions[id] and scan.auctions[id][id]
        local browseOffer = scan.browseItems[id]
        local link = scan.bagItems[id] or (baseOffer and baseOffer.link) or (browseOffer and browseOffer.link)
        if not link then return end
        item = readCachedItem(id, link)
        if not item or app.VariantKey(item.link) then return end
    elseif scan.bagItems[id] then
        item = readCachedItem(id, scan.bagItems[id]) or item
    elseif scan.browseItems[id] then
        item = readCachedItem(id, scan.browseItems[id].link) or item
    end
    local result = comparison(scan, id, item, scan.bagItems[id] or scan.browseItems[id])
    if result and not variants and not scan.bagItems[id] and not scan.browseItems[id] then
        local record = sourceRecord(id) or result
        local scores = cachedScores(id, record)
        scores.live = result
        scores.key = gear.ItemKey(item.link)
        scores.item = app.IsUpgrade(result, math.huge) and item or nil
        if canSaveScore(record) and not app.VariantKey(item.link) and hasClientStats(item.link) then
            local saved = savedItemScores(id)
            saved.live, saved.item, saved.key = result, scores.item, scores.key
        end
    end
    storeResult(scan, id, item, result)
end

local function requestData(scan, id, now)
    if scan.skipUncached or recentlyMissing(id) then withoutItemData(scan, id); return end
    if C_Item and C_Item.DoesItemExistByID then
        local ok, exists = pcall(C_Item.DoesItemExistByID, id)
        if ok and readable(exists) == false then rememberMissing(id); withoutItemData(scan, id); return end
    end
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if not request then
        withoutItemData(scan, id)
        return
    end
    if scan.count >= requestLimit or (scan.requestsThisStep or 0) >= requestBurst then
        scan.deferred[#scan.deferred + 1] = id
        return
    end
    scan.waiting[id] = { deadline = now + requestTimeout }
    scan.requestsThisStep = (scan.requestsThisStep or 0) + 1
    local ok, err = pcall(request, id)
    if not ok then
        scan.waiting[id] = nil
        withoutItemData(scan, id, err)
        return
    end
    scan.count = scan.count + 1
end

local function analyze(scan, id, now)
    local record = sourceRecord(id)
    if record then
        if not gear.SLOTS_OF[record.inv] or record.req > scan.level then return end
    elseif instantInfo then
        local _, _, _, inv = instantInfo(id)
        if inv and not gear.SLOTS_OF[gear.EQUIP_LOC[inv]] then return end
    end

    local previous = knownScores(id)
    if previous and previous.live and not (scan.variants[id] or scan.bagItems[id] or scan.browseItems[id]) then
        scan.reused = scan.reused + 1
        storeResult(scan, id, previous.item, previous.live)
        return
    end
    if replayLinks(scan, id) then return end
    local item, itemError = readCachedItem(id)
    if item then
        scoreItem(scan, id, item)
        return
    end

    local result
    if record then
        local scores = cachedScores(id, record)
        local saved = savedScores and savedScores[id]
        result = scores.database or saved and saved.database
        if not result then
            result = gear.EstimateRecord(id, record)
            scores.database = result
            if result and canSaveScore(record) then savedItemScores(id).database = result end
        end
        if result and not (scan.variants[id] or scan.bagItems[id] or scan.browseItems[id] or scan.activeRewards[id])
            and not app.IsUpgrade(result, scan.level) then return end
    end
    if itemError then
        withoutItemData(scan, id, itemError)
        return
    end
    requestData(scan, id, now)
end

function app.ItemFailed(scan, id)
    if scan.waiting[id] then scan.waiting[id].failed = true end
end

function app.ItemDataReady(scan, id, success)
    id, success = tonumber(readable(id)), readable(success)
    if not id then return end
    local pending = scan.waiting[id]
    if pending then
        pending.nextPoll = 0
        if success == false then pending.failed = true end
    end
end

local function finishRequest(scan, id, pending, now)
    if pending.failed then
        rememberMissing(id)
        scan.unavailable = scan.unavailable + 1
        return true
    end
    local item, itemError = readCachedItem(id)
    if item then
        scoreItem(scan, id, item)
    elseif itemError or now >= pending.deadline or scan.skipUncached then
        if now >= pending.deadline then rememberMissing(id) end
        withoutItemData(scan, id, itemError)
    else
        pending.nextPoll = now + 0.25
        return false
    end
    return true
end

function app.ScanStep(scan, now)
    local function cpuTime()
        if debugprofilestop then return debugprofilestop() end
        return GetTimePreciseSec and GetTimePreciseSec() * 1000 or 0
    end
    local started, budget = cpuTime(), batchSize
    local function available() return budget > 0 and cpuTime() - started < cpuBudget end
    scan.requestsThisStep = 0
    if scan.tailStarted and now - scan.tailStarted >= tailSeconds then
        scan.skipUncached, scan.limited = true, true
    end
    for id, pending in pairs(scan.waiting) do
        if not available() then break end
        if pending.failed or scan.skipUncached or not pending.nextPoll or now >= pending.nextPoll then
            budget = budget - 1
            local ok, complete = pcall(finishRequest, scan, id, pending, now)
            if not ok then app.RecordIssue(scan, id, complete) end
            if not ok or complete then
                scan.waiting[id] = nil
                scan.count = scan.count - 1
            end
        end
    end

    local function resolveQueued(id)
        local item, err = readCachedItem(id)
        if item then scoreItem(scan, id, item)
        elseif err then withoutItemData(scan, id, err)
        else requestData(scan, id, now) end
    end
    while available() and scan.nextDeferred <= #scan.deferred
        and (scan.skipUncached or scan.count < requestLimit and scan.requestsThisStep < requestBurst) do
        local id = scan.deferred[scan.nextDeferred]
        scan.nextDeferred = scan.nextDeferred + 1
        budget = budget - 1
        local ok, err = pcall(resolveQueued, id)
        if not ok then app.RecordIssue(scan, id, err) end
    end
    local inspected = 0
    while available() and inspected < 4096 and scan.cursor <= #scan.ids do
        local id = scan.ids[scan.cursor]
        scan.cursor = scan.cursor + 1
        inspected = inspected + 1
        local scores = knownScores(id)
        if not scores or not scores.live or scan.variants[id] or scan.bagItems[id] or scan.browseItems[id]
            or app.IsUpgrade(scores.live, scan.level) then
            budget = budget - 1
            local ok, err = pcall(analyze, scan, id, now)
            if not ok then app.RecordIssue(scan, id, err) end
        else scan.reused = scan.reused + 1 end
    end
    if scan.cursor > #scan.ids and not scan.tailStarted then scan.tailStarted = now end
    return scan.cursor > #scan.ids and scan.nextDeferred > #scan.deferred and scan.count == 0
end

local function lower(text)
    return text:lower():gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"):gsub("ẞ", "ß")
end

local function isInstance(source)
    return source.kind == "dungeon" or source.kind == "raid"
end

function app.InstanceChoices(rows)
    local counts = {}
    for _, item in ipairs(rows) do
        local seen = {}
        for _, source in ipairs(item.sources) do
            local zone = source.zone
            if isInstance(source) and zone and not seen[zone] then
                seen[zone] = true
                counts[zone] = (counts[zone] or 0) + 1
            end
        end
    end
    local choices = {}
    for name, count in pairs(counts) do
        choices[#choices + 1] = { name, ("%s (%d)"):format(name, count) }
    end
    table.sort(choices, function(a, b) return lower(a[1]) < lower(b[1]) end)
    table.insert(choices, 1, { "", suite.L("Alle Instanzen & Raids") })
    return choices
end

local function matchesSource(source, filter, query, instance, profession)
    if instance ~= nil then
        if not isInstance(source) then return false end
        if type(instance) == "table" then
            if not instance[source.zone] then return false end
        elseif instance ~= "" and source.zone ~= instance then
            return false
        end
    elseif filter ~= "all" and source.kind ~= filter then
        return false
    end
    if profession and source.profession ~= profession then return false end
    if not query then return true end
    local text = table.concat({ app.sourceNames[source.kind], source.title, source.zone or "" }, " ")
    return lower(text):find(query, 1, true) ~= nil
end

function app.ItemColumnValue(item, key)
    return item[key] or item.stats and item.stats[key]
end

local function sortValue(entry, key)
    if key == "source" then return entry.source.kind .. entry.source.title end
    if key == "effort" then return entry.source.effort end
    if key == "price" then return entry.source.price end
    if key == "name" then return lower(entry.item.name) end
    if key == "slot" then return app.slotNames[entry.item.slot] end
    return app.ItemColumnValue(entry.item, key)
end

function app.VisibleRows(rows, slot, sourceKind, search, sortKey, ascending, instance, filters)
    local result = {}
    local query = lower(search:match("^%s*(.-)%s*$"))
    if query == "" then query = nil end
    local maxRequiredLevel = filters and filters.maxRequiredLevel
    for _, item in ipairs(rows) do
        if (slot == 0 or item.slot == slot)
            and (not maxRequiredLevel or item.requiredLevel and item.requiredLevel <= maxRequiredLevel)
            and (not filters or not filters.quality or filters.quality[item.quality] ~= false) then
            local sourceQuery = query
            if query and (lower(item.name):find(query, 1, true) or tostring(item.id) == query) then
                sourceQuery = nil
            end
            for _, source in ipairs(item.sources) do
                if matchesSource(source, sourceKind, sourceQuery, instance, filters and filters.profession) then
                    result[#result + 1] = { item = item, source = source }
                    break
                end
            end
        end
    end
    table.sort(result, function(a, b)
        local av, bv = sortValue(a, sortKey), sortValue(b, sortKey)
        if av == bv then
            if a.item.id ~= b.item.id then return a.item.id < b.item.id end
            return a.item.link < b.item.link
        end
        if av == nil then return false end
        if bv == nil then return true end
        if ascending then return av < bv end
        return av > bv
    end)
    return result
end
