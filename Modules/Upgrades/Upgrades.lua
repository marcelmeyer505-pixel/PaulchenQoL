local _, suite = ...
local app = suite.upgrades
if not app then return end
local pole, gear = Polestar, Polestar.Gear

-- Polestar's shared proficiency table also drives its item tooltips.
-- Forever Druids can train polearms (weapon subclass 6).
local druid = gear.PROFICIENCY and gear.PROFICIENCY.DRUID
if druid and druid.weapons and druid.weapons[6] == nil then
    druid.weapons[6] = true
end

local itemDB = pole.ItemDB
local itemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local detailedItemLevel = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
local cachedInfo = C_Item and C_Item.IsItemDataCachedByID
local instantInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local boe = Enum and Enum.ItemBind and Enum.ItemBind.OnEquip or 2
local requestLimit, batchSize, requestTimeout = 40, 100, 5
local readable = pole.Compat.Readable

pole.OnLogin(function()
    local scales = gear.Scales
    local db = pole.DB()
    if db.paulchenCatWeightsUpdated or not scales or not scales.SetWeight then return end

    for _, scale in ipairs(scales.List("DRUID")) do
        if scale.name == "Katze (Schaden)" then
            local weights = scale.weights
            if not scale.edited and weights.ap == 0.4 and weights.crit == 5.1
                and weights.str == 1.3 and weights.agi == 1 and weights.dps == 3 then
                -- The character sheet shows 2 AP per strength, 1 AP per
                -- agility in cat form and 9.4% crit from 144 agility.
                scales.SetWeight("DRUID", scale.id, "str", 2 * weights.ap)
                local agility = weights.ap + (9.4 / 144) * weights.crit
                scales.SetWeight("DRUID", scale.id, "agi", math.floor(agility * 1000 + 0.5) / 1000)
                scales.SetWeight("DRUID", scale.id, "dps", 14 * weights.ap)
            end
            db.paulchenCatWeightsUpdated = true
            return
        end
    end
end)

-- Polestar expects percentage points. Convert only ratings from the client,
-- since the database already stores percentage points.
local ratingsPerPercent = {
    hit = 10, spellHit = 10,
    crit = 14, spellCrit = 14,
    hastePercent = 10,
    dodge = 12, parry = 15, block = 5,
}
local ratingIndex = {
    hit = CR_HIT_MELEE, spellHit = CR_HIT_SPELL,
    crit = CR_CRIT_MELEE, spellCrit = CR_CRIT_SPELL,
    hastePercent = CR_HASTE_MELEE,
    dodge = CR_DODGE, parry = CR_PARRY, block = CR_BLOCK,
}
local ratingBonus = GetCombatRatingBonusForCombatRatingValue

local function ratingPercent(stat, value)
    local index = ratingIndex[stat]
    if ratingBonus and index and value ~= 0 then
        local ok, bonus = pcall(ratingBonus, index, math.abs(value))
        if ok then
            bonus = readable(bonus)
            if type(bonus) == "number" and bonus > 0 and bonus < math.huge then
                return value < 0 and -bonus or bonus
            end
        end
    end
    return value / ratingsPerPercent[stat]
end

local duplicateRating = {
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "ITEM_MOD_HIT_RATING_SHORT",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "ITEM_MOD_CRIT_RATING_SHORT",
}

-- Existing Polestar scales use hit/crit percentages. Keep the raw rating
-- keys alongside them so a scale can assign a weight per rating point.
local rawRatings = { hit = "hitRating", crit = "critRating", hastePercent = "haste" }
local extraRatingNames = {
    { "hitRating", "HitRatingPoints" }, { "critRating", "CritRatingPoints" },
    { "expertise", "ExpertiseRating" }, { "haste", "HasteRating" }, { "armorPen", "ArmorPenetration" },
    { "hastePercent", "MeleeHastePercent" },
}
local ratingKeys = {
    ITEM_MOD_EXPERTISE_RATING_SHORT = "expertise",
    ITEM_MOD_HASTE_RATING_SHORT = "hastePercent",
    ITEM_MOD_HASTE_MELEE_RATING_SHORT = "hastePercent",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "armorPen",
}
local pawn = gear.Pawn
local extraPawnKeys = {}
for _, entry in ipairs(extraRatingNames) do
    local stat, name = unpack(entry)
    gear.STAT_KEYS[#gear.STAT_KEYS + 1] = stat
    gear.PAWN_STATS[#gear.PAWN_STATS + 1] = { pawn = name, to = { stat } }
    extraPawnKeys[name:lower()] = stat
end
-- Polestar builds its import lookup before dependent addons load.
local pawnWeights = pawn.Weights
function pawn.Weights(parsed)
    local weights, mapped, ignored = pawnWeights(parsed)
    local remaining = {}
    for _, name in ipairs(ignored) do
        local stat = extraPawnKeys[name:lower()]
        if stat and parsed.stats[name] ~= nil then
            weights[stat] = parsed.stats[name]
            mapped = mapped + 1
        else
            remaining[#remaining + 1] = name
        end
    end
    return weights, mapped, remaining
end

for clientKey, stat in pairs(ratingKeys) do gear.CLIENT_STATS[clientKey] = stat end
duplicateRating.ITEM_MOD_HASTE_MELEE_RATING_SHORT = "ITEM_MOD_HASTE_RATING_SHORT"
for _, raw in pairs(rawRatings) do gear.CLIENT_STATS[raw] = raw end

-- For uncached items, Polestar's database has percent values only.
local databaseItem = itemDB.Get
function itemDB.Get(id)
    local item = databaseItem(id)
    if item then
        for stat, raw in pairs(rawRatings) do
            if item.stats[raw] == nil and item.stats[stat] ~= nil then
                item.stats[raw] = item.stats[stat] * ratingsPerPercent[stat]
            end
        end
    end
    return item
end

-- The database also supplies weapon DPS when the client omits this base stat.
local dpsStat = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
if gear.Client and type(gear.Client.ItemStats) == "function"
    and gear.CLIENT_STATS and gear.CLIENT_STATS[dpsStat] == "dps" then
    local clientStats = gear.Client.ItemStats
    function gear.Client.ItemStats(link)
        local stats = clientStats(link)
        if not stats or not next(stats) then return stats end

        local dps
        if readable(stats[dpsStat]) == nil then
            local id = gear.ItemID(link)
            local item = id and itemDB.Get(id)
            dps = item and item.class == 2 and item.stats.dps
        end
        local merged = {}
        for key, value in pairs(stats) do
            local stat = gear.CLIENT_STATS[key]
            local alias = duplicateRating[key]
            if not alias or type(readable(stats[alias])) ~= "number" then
                if ratingsPerPercent[stat] and type(readable(value)) == "number" then
                    merged[key] = ratingPercent(stat, value)
                    local raw = rawRatings[stat]
                    if raw then merged[raw] = value end
                else
                    merged[key] = value
                end
            end
        end
        if dps then merged[dpsStat] = dps end
        return merged
    end
end

local previousCatScale = '( Pawn: v1: "Feral Katze": Class=Druid, Agility=1, Strength=0.98, HitRatingPoints=0.88, '
    .. 'ExpertiseRating=0.85, CritRatingPoints=0.73, HasteRating=0.48, Ap=0.40, ArmorPenetration=0.13 )'
local catScale = '( Pawn: v1: "Feral Katze": Class=Druid, Agility=1.90, Strength=0.80, HitRating=8.77, '
    .. 'ExpertiseRating=0.85, CritRating=10.2, MeleeHastePercent=4.78, Ap=0.40, MeleeDps=5.60, ArmorPenetration=0.13 )'

local function updateCatDamageWeights(db, scales)
    if db.paulchenFeralCatWeaponDpsUpdated and db.paulchenFeralCatGearAgilityUpdated then return end
    for _, scale in ipairs(scales.List("DRUID")) do
        if scale.name:lower() == "feral katze" then
            local wasEdited = scale.edited
            local parsed = pawn.Parse(scale.original or scale.source)
            local original = parsed and pawn.Weights(parsed)
            -- Gear agility is weighted for the player's observed twofold increase in Cat Form.
            local updates = db.paulchenFeralCatWeaponDpsUpdated and { agi = 1.90 }
                or { str = 0.80, agi = 1.90, dps = 5.60 }
            for key, value in pairs(updates) do
                if not scales.SetWeight("DRUID", scale.id, key, value) then return end
                if original then original[key] = value end
            end
            scale.original = original and pawn.Build(scale.name, "DRUID", original) or scale.source
            scale.edited = wasEdited
            db.paulchenFeralCatWeaponDpsUpdated = true
            db.paulchenFeralCatGearAgilityUpdated = true
            return
        end
    end
end

pole.OnLogin(function()
    gear.Invalidate("items")
    local db = pole.DB()
    local scales = gear.Scales
    if db.paulchenFeralCatPercentUpdated then
        updateCatDamageWeights(db, scales)
        return
    end

    for _, scale in ipairs(scales.List("DRUID")) do
        if scale.name:lower() == "feral katze" then
            if scale.original == previousCatScale then
                if scale.edited then
                    scales.RemoveWeight("DRUID", scale.id, "hitRating")
                    scales.RemoveWeight("DRUID", scale.id, "critRating")
                    scales.RemoveWeight("DRUID", scale.id, "haste")
                    scales.SetWeight("DRUID", scale.id, "hit", 8.77)
                    scales.SetWeight("DRUID", scale.id, "crit", 10.2)
                    scales.SetWeight("DRUID", scale.id, "hastePercent", 4.78)
                    scale.original = catScale
                elseif not scales.Import(catScale, "DRUID") then
                    return
                end
            end
            db.paulchenFeralCatPercentUpdated = true
            updateCatDamageWeights(db, scales)
            return
        end
    end
    local selected = scales.FromSetting("DRUID", pole.Get("gear.spec.DRUID"))
    local ok, result = scales.Import(catScale, "DRUID")
    if ok then
        db.paulchenFeralCatPercentUpdated = true
        updateCatDamageWeights(db, scales)
        if not db.paulchenFeralCatImported and selected and selected.name == "Katze (Schaden)" then
            pole.Set("gear.spec.DRUID", "custom:" .. result.scale.id)
        end
    end
end)

app.slots = {
    { 1, "Kopf" }, { 2, "Hals" }, { 3, "Schultern" }, { 15, "Rücken" },
    { 5, "Brust" }, { 9, "Handgelenke" }, { 10, "Hände" }, { 6, "Taille" },
    { 7, "Beine" }, { 8, "Füße" }, { 11, "Finger" }, { 13, "Schmuck" },
    { 16, "Waffenhand" }, { 17, "Nebenhand" }, { 18, "Fernwaffe / Relikt" },
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
    if not quiet then pole.Fire("PAULCHEN_VARIANT_ADDED") end
end

if pole.Hooks and pole.Hooks.ItemLines then
    pole.Hooks.ItemLines("PaulchenVariants", function(_, link) app.ObserveVariant(link) end)
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
    local name = item and item.name or itemDB.ItemName(id) or ("Item " .. id)
    local record = itemDB.Get(id)
    local link = item and item.link or ("item:" .. id)
    local info = gear.GetItemInfo(item and link or id)
    local itemLevel
    if item and detailedItemLevel then
        local ok, value = pcall(detailedItemLevel, link)
        if ok then itemLevel = readable(value) end
    end
    if not itemLevel or itemLevel <= 0 then itemLevel = item and item.itemLevel end
    if not itemLevel or itemLevel <= 0 then itemLevel = record and record.ilvl end
    scan.rows[#scan.rows + 1] = {
        id = id, name = name, link = link, icon = item and item.icon,
        quality = item and item.quality or record and record.quality or 1,
        slot = slot, old = result.old, new = result.new, delta = result.delta, pct = result.pct,
        itemLevel = itemLevel and itemLevel > 0 and itemLevel or nil,
        requiredLevel = requiredLevel, future = requiredLevel > scan.playerLevel,
        stats = info and info.stats or record and record.stats,
        empty = result.empty, sources = sources,
    }
end

function app.NewScan(maxRequiredLevel)
    itemDB.Load()
    local player = gear.GetPlayer()
    local _, profile = gear.GetSpec()
    local scan = {
        level = math.max(player.level, maxRequiredLevel or player.level), playerLevel = player.level,
        faction = player.faction, profile = profile and pole.L[profile] or "–",
        ids = {}, cursor = 1, waiting = {}, count = 0, rows = {}, unavailable = 0, errors = 0,
        itemDBLoaded = itemDB.IsLoaded(),
    }
    app.PrepareSources(scan)
    scan.auctions, scan.auctionAt = auctionOffers()
    local seen = {}
    local function include(id)
        if not seen[id] then
            seen[id] = true
            scan.ids[#scan.ids + 1] = id
        end
    end
    -- Prioritize loot from the current instance so its upgrades appear first.
    local here = app.CurrentInstance(scan.atlas)
    if here then
        for id, drops in pairs(scan.atlas.items) do
            for _, drop in ipairs(drops) do
                if here[drop.location.name] then include(id); break end
            end
        end
    end
    for id in pairs(scan.activeRewards) do include(id) end
    for id in pairs(scan.atlas.items) do include(id) end
    for id in pairs(scan.crafting) do include(id) end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, gear.Client.BagSlots(bag) do
            app.ObserveVariant(gear.Client.BagLink(bag, slot), true)
        end
    end
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
    for id, offers in pairs(scan.auctions) do
        if next(offers) then include(id) end
        for key, offer in pairs(offers) do
            if key ~= id then includeVariant(offer.link) end
        end
    end
    for _, link in pairs(type(savedVariants) == "table" and savedVariants or {}) do
        includeVariant(link)
    end
    for id in pairs(app.catalog) do include(id) end
    if scan.codexLoaded and instantInfo then
        pole.Codex.Each("item", function(id, _, _, status)
            if not seen[id] and status ~= "retired" then
                local _, _, _, inv = instantInfo(id)
                if inv and gear.SLOTS_OF[gear.EQUIP_LOC[inv]] then include(id) end
            end
        end)
    end
    return scan
end

local function withoutItemData(scan, id, result, message)
    scan.unavailable = scan.unavailable + 1
    if message then app.RecordIssue(scan, id, message) end
    storeResult(scan, id, nil, result)
end

local function scoreItem(scan, id, item)
    local variants = scan.variants[id]
    if variants then
        for _, link in ipairs(variants) do
            local variant = readCachedItem(id, link)
            local stats = variant and gear.Client.ItemStats(link)
            if stats and next(stats) then
                storeResult(scan, id, variant, gear.CompareToEquipped(link))
            end
        end
        local baseOffer = scan.auctions[id] and scan.auctions[id][id]
        if not baseOffer then return end
        item = readCachedItem(id, baseOffer.link)
        if not item or app.VariantKey(item.link) then return end
    end
    storeResult(scan, id, item, gear.CompareToEquipped(item.link))
end

local function analyze(scan, id, now)
    local record = itemDB.Get(id)
    if record then
        if not gear.SLOTS_OF[record.inv] or record.req > scan.level then return end
    elseif instantInfo then
        local _, _, _, inv = instantInfo(id)
        if inv and not gear.SLOTS_OF[gear.EQUIP_LOC[inv]] then return end
    end

    local item, itemError = readCachedItem(id)
    if item then
        scoreItem(scan, id, item)
        return
    end

    local result = record and gear.CompareToEquipped(id)
    if record and not scan.variants[id] and not app.IsUpgrade(result, scan.level) then return end
    if itemError then
        withoutItemData(scan, id, result, itemError)
        return
    end
    if C_Item and C_Item.DoesItemExistByID then
        local ok, exists = pcall(C_Item.DoesItemExistByID, id)
        if ok and readable(exists) == false then return end
    end
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if not request then
        withoutItemData(scan, id, result)
        return
    end
    scan.waiting[id] = { deadline = now + requestTimeout, result = result }
    local ok, err = pcall(request, id)
    if not ok then
        scan.waiting[id] = nil
        withoutItemData(scan, id, result, err)
        return
    end
    scan.count = scan.count + 1
end

function app.ItemFailed(scan, id)
    if scan.waiting[id] then scan.waiting[id].failed = true end
end

local function finishRequest(scan, id, pending, now)
    if pending.failed then
        scan.unavailable = scan.unavailable + 1
        return true
    end
    local item, itemError = readCachedItem(id)
    if item then
        scoreItem(scan, id, item)
    elseif itemError or now >= pending.deadline then
        withoutItemData(scan, id, pending.result, itemError)
    else
        return false
    end
    return true
end

function app.ScanStep(scan, now)
    for id, pending in pairs(scan.waiting) do
        local ok, complete = pcall(finishRequest, scan, id, pending, now)
        if not ok then app.RecordIssue(scan, id, complete) end
        if not ok or complete then
            scan.waiting[id] = nil
            scan.count = scan.count - 1
        end
    end

    local stop = math.min(#scan.ids, scan.cursor + batchSize - 1)
    while scan.cursor <= stop and scan.count < requestLimit do
        local id = scan.ids[scan.cursor]
        scan.cursor = scan.cursor + 1
        local ok, err = pcall(analyze, scan, id, now)
        if not ok then app.RecordIssue(scan, id, err) end
    end
    return scan.cursor > #scan.ids and scan.count == 0
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
    table.insert(choices, 1, { "", "Alle Instanzen & Raids" })
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
