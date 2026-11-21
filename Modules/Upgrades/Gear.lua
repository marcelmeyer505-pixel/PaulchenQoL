local _, suite = ...
local app = suite.upgrades
if not app then return end

local gear, clients = {}, {}
app.gear, gear.Client = gear, clients
local readable = suite.Readable
local items, container = C_Item, C_Container

local listeners = {}
function app.On(message, handler)
    local list = listeners[message] or {}
    listeners[message] = list
    list[#list + 1] = handler
end
function app.Fire(message, ...)
    for _, handler in ipairs(listeners[message] or {}) do handler(...) end
end

local events = CreateFrame("Frame")
local handlers = {}
function app.RegisterEvent(event, handler)
    if not handlers[event] then
        if not pcall(events.RegisterEvent, events, event) then return end
        handlers[event] = {}
    end
    local list = handlers[event]
    list[#list + 1] = handler
end
events:SetScript("OnEvent", function(_, event, ...)
    for _, handler in ipairs(handlers[event] or {}) do handler(event, ...) end
end)

-- Blizzard's inventory type and character equipment slot IDs.
gear.EQUIP_LOC = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9,
    INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12, INVTYPE_WEAPON = 13,
    INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17,
    INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22,
    INVTYPE_HOLDABLE = 23, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_RELIC = 28,
}
gear.SLOTS_OF = {
    [1] = {1}, [2] = {2}, [3] = {3}, [5] = {5}, [20] = {5}, [6] = {6}, [7] = {7}, [8] = {8},
    [9] = {9}, [10] = {10}, [11] = {11, 12}, [12] = {13, 14}, [16] = {15},
    [13] = {16, 17}, [17] = {16}, [21] = {16}, [14] = {17}, [22] = {17}, [23] = {17},
    [15] = {18}, [25] = {18}, [26] = {18}, [28] = {18},
}
local ranged = { [15] = true, [25] = true, [26] = true }
local armorExempt = { [2] = true, [11] = true, [12] = true, [16] = true, [23] = true }
local function set(...)
    local values = {}
    for i = 1, select("#", ...) do values[select(i, ...)] = true end
    return values
end
local proficiency = {
    WARRIOR = { armor = 3, promotes = true, shield = true, dual = 20, weapons = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18) },
    PALADIN = { armor = 3, promotes = true, shield = true, relic = 7, weapons = set(0, 1, 4, 5, 6, 7, 8) },
    HUNTER = { armor = 2, promotes = true, dual = 20, weapons = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18) },
    ROGUE = { armor = 2, dual = 10, weapons = set(0, 2, 3, 4, 7, 13, 15, 16, 18) },
    PRIEST = { armor = 1, weapons = set(4, 10, 15, 19) },
    SHAMAN = { armor = 2, promotes = true, shield = true, relic = 9, weapons = set(0, 1, 4, 5, 10, 13, 15) },
    MAGE = { armor = 1, weapons = set(7, 10, 15, 19) },
    WARLOCK = { armor = 1, weapons = set(7, 10, 15, 19) },
    DRUID = { armor = 2, relic = 8, weapons = set(4, 5, 6, 10, 13, 15) },
}
local weaponSkills = { [0]=44, [1]=172, [2]=45, [3]=46, [4]=54, [5]=160, [6]=229, [7]=43,
    [8]=55, [10]=136, [13]=473, [15]=173, [16]=176, [18]=226, [19]=228 }

function gear.PlayerLevel()
    return UnitLevel and tonumber(readable(UnitLevel("player"))) or 1
end

function gear.GetPlayer()
    local name, class, id = UnitClass("player")
    local _, race = UnitRace("player")
    return { class = readable(class), className = readable(name), classID = readable(id), race = readable(race),
        level = gear.PlayerLevel(), faction = readable(UnitFactionGroup("player")) }
end

function clients.InventoryLink(slot)
    if slot == (INVSLOT_HAND or 10) and suite.UpgradeGloveLink then
        local link = suite.UpgradeGloveLink()
        if link then return link end
    end
    return GetInventoryItemLink and readable(GetInventoryItemLink("player", slot))
end
function clients.BagSlots(bag)
    return container and container.GetContainerNumSlots and readable(container.GetContainerNumSlots(bag)) or 0
end
function clients.BagLink(bag, slot)
    return container and container.GetContainerItemLink and readable(container.GetContainerItemLink(bag, slot))
end
function clients.ItemStats(link)
    return items and items.GetItemStats and readable(items.GetItemStats(link))
end

local function itemString(link)
    link = readable(link)
    if type(link) == "number" then return "item:" .. link end
    if type(link) == "string" then return link:match("|H(item:[^|]+)|h") or link:match("^(item:[%d:%-]+)$") end
end
gear.ItemKey = itemString

function gear.ItemID(link)
    local item = itemString(link)
    return item and tonumber(item:match("^item:(%d+)"))
end

function gear.AuctionItemLink(key)
    local id = readable(key.itemID)
    if type(id) ~= "number" or id <= 0 then return end
    local ah = C_AuctionHouse
    local info = readable(ah.GetItemKeyInfo(key))
    if not (info and readable(info.isEquipment)) then return end
    local link = ah.GetItemKeySampleLink and readable(ah.GetItemKeySampleLink(key))
    local suffix = readable(key.itemSuffix) or 0
    if not link then
        local _, base, _, level = items.GetItemInfo(id)
        local expected = readable(key.itemLevel) or 0
        if expected > 0 and readable(level) ~= expected then return end
        link = readable(base)
        if suffix ~= 0 then link = ("item:%d::::::%d"):format(id, suffix) end
    end
    if suffix ~= 0 and link then
        local raw = clients.ItemStats(link)
        if not raw or not next(raw) then return end
    end
    return link, id
end

-- Rating aliases can appear alongside the general rating in a single tooltip.
local function stat(raw, token)
    local value = readable(raw[token])
    if type(value) == "number" and value > -math.huge and value < math.huge then return value end
end

local statsByToken = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi",
    RESISTANCE0_NAME = "armor", ITEM_MOD_ARMOR_SHORT = "armor",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "sp", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "expertise", ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "armorPen",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defense", ITEM_MOD_BLOCK_VALUE_SHORT = "blockValue",
    ITEM_MOD_ARCANE_SPELL_DAMAGE_DONE_SHORT = "spArcane", ITEM_MOD_FIRE_SPELL_DAMAGE_DONE_SHORT = "spFire",
    ITEM_MOD_FROST_SPELL_DAMAGE_DONE_SHORT = "spFrost", ITEM_MOD_HOLY_SPELL_DAMAGE_DONE_SHORT = "spHoly",
    ITEM_MOD_NATURE_SPELL_DAMAGE_DONE_SHORT = "spNature", ITEM_MOD_SHADOW_SPELL_DAMAGE_DONE_SHORT = "spShadow",
}
local ratingFields = {
    { "hit", "HIT", CR_HIT_MELEE, 10 }, { "spellHit", "HIT_SPELL", CR_HIT_SPELL, 10, "HIT" },
    { "crit", "CRIT", CR_CRIT_MELEE, 14 }, { "spellCrit", "CRIT_SPELL", CR_CRIT_SPELL, 14, "CRIT" },
    { "hastePercent", "HASTE", CR_HASTE_MELEE, 10 }, { "spellHaste", "HASTE_SPELL", CR_HASTE_SPELL, 10, "HASTE" },
    { "dodge", "DODGE", CR_DODGE, 12 }, { "parry", "PARRY", CR_PARRY, 15 }, { "block", "BLOCK", CR_BLOCK, 5 },
}
local rawFields = { hit = "hitRating", crit = "critRating", hastePercent = "haste" }
local function percent(index, rating, divisor)
    if index and rating > 0 and GetCombatRatingBonusForCombatRatingValue then
        local ok, value = pcall(GetCombatRatingBonusForCombatRatingValue, index, rating)
        value = ok and readable(value)
        if type(value) == "number" and value > 0 and value < math.huge then return value end
    end
    return rating / divisor
end

local function rating(raw, kind)
    return stat(raw, "ITEM_MOD_" .. kind .. "_RATING_SHORT")
end
local function itemTooltip(link)
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok then return readable(data) end
    end
end

local function pattern(token, format, capture)
    if type(format) ~= "string" then return end
    local first, last = format:find(token)
    if not first then return end
    local function literal(text) return (text:gsub("([^%w%s])", "%%%1")) end
    return "^%s*" .. literal(format:sub(1, first - 1)) .. capture .. literal(format:sub(last + 1)) .. "%s*$"
end

local dpsPattern = pattern("%%[%d%.]*f", DPS_TEMPLATE, "([%d.,]+)")
local classPattern = pattern("%%[%d%$]*s", ITEM_CLASSES_ALLOWED, "(.+)")
local function tooltipDetails(data)
    local dps, allowed
    for _, line in ipairs(data and readable(data.lines) or {}) do
        local text = readable(line.leftText)
        if type(text) == "string" then
            text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local amount = dpsPattern and text:match(dpsPattern)
            if amount then dps = tonumber((amount:gsub(",", "."))) end
            local classes = classPattern and text:match(classPattern)
            if classes then allowed = classes end
        end
    end
    return dps, allowed
end

local itemCache, cacheSize = {}, 0
function gear.GetItemInfo(link)
    local key, id = itemString(link), gear.ItemID(link)
    if not id or not (items and items.GetItemInfo) then return end
    local bucket = itemCache[id]
    if bucket and bucket[key] then return bucket[key] end
    local ok, name, display, quality, ilvl, req, _, _, _, equip, _, _, class, subclass = pcall(items.GetItemInfo, key)
    if not ok then return end
    local inv = gear.EQUIP_LOC[readable(equip)]
    if not (readable(name) and gear.SLOTS_OF[inv]) then return end
    if items.IsItemDataCachedByID and readable(items.IsItemDataCachedByID(id)) == false then return end
    local raw = clients.ItemStats(key)
    if type(raw) ~= "table" then raw = {} end
    local stats = {}
    for token, label in pairs(statsByToken) do
        local amount = stat(raw, token)
        if amount then stats[label] = math.max(stats[label] or 0, amount) end
    end
    local combined = stat(raw, "ITEM_MOD_SPELL_POWER_SHORT") or 0
    if combined ~= 0 then stats.sp, stats.heal = (stats.sp or 0) + combined, (stats.heal or 0) + combined end
    stats.mp5 = stat(raw, "ITEM_MOD_MANA_REGENERATION_SHORT") or stat(raw, "ITEM_MOD_POWER_REGEN0_SHORT")
    for _, field in ipairs(ratingFields) do
        local label, kind, index, divisor, alias = unpack(field)
        local amount = rating(raw, kind)
        if not amount and alias then amount = rating(raw, alias) end
        if not amount then
            amount = rating(raw, kind .. (ranged[inv] and "_RANGED" or "_MELEE")) or rating(raw, kind .. "_MELEE") or rating(raw, kind .. "_RANGED")
        end
        if amount then
            stats[label] = percent(index, amount, divisor)
            if rawFields[label] then stats[rawFields[label]] = amount end
        end
    end
    local dps, allowed = tooltipDetails(itemTooltip(key))
    local weaponDps = stat(raw, "ITEM_MOD_DAMAGE_PER_SECOND_SHORT") or dps
    if ranged[inv] then stats.rdps, stats.dps = weaponDps, weaponDps
    elseif readable(class) == 2 then stats.dps = weaponDps end
    local unique, _, limit, category
    if items.GetItemUniquenessByID then unique, _, limit, category = items.GetItemUniquenessByID(id) end
    local info = { id = id, key = key, link = readable(display) or key, inv = inv, stats = stats,
        req = readable(req) or 0, quality = readable(quality), ilvl = readable(ilvl),
        class = readable(class), subclass = readable(subclass), allowed = allowed,
        unique = readable(unique), limit = readable(limit), category = readable(category) }
    if cacheSize >= 6000 then itemCache, cacheSize, bucket = {}, 0, nil end
    bucket = bucket or {}
    itemCache[id], bucket[key], cacheSize = bucket, info, cacheSize + 1
    return info
end

local function knownSpell(id)
    if IsPlayerSpell and readable(IsPlayerSpell(id)) then return true end
    if IsSpellKnown and readable(IsSpellKnown(id)) then return true end
    local book = C_SpellBook
    if book and book.IsSpellKnown and Enum and Enum.SpellBookSpellBank then
        return readable(book.IsSpellKnown(id, Enum.SpellBookSpellBank.Player))
    end
end
local function canDualWield(player, prof)
    if prof.dual and player.level >= prof.dual then return true end
    return knownSpell(674) or knownSpell(30798)
end
local function skillRank(id)
    local api = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID
    local entry = api and readable(api(id))
    return entry and readable(entry.rank)
end
gear.SkillRank = skillRank

function gear.EligibilityKey()
    local fields = { knownSpell(674) and "1" or "0", knownSpell(30798) and "1" or "0" }
    local ids = {}
    for _, id in pairs(weaponSkills) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local rank = skillRank(id)
        fields[#fields + 1] = id .. ":" .. (rank == nil and "?" or rank > 0 and "1" or "0")
    end
    return table.concat(fields, ",")
end

local function requiredLevel(info, player, prof)
    local req, sub = info.req, info.subclass
    if info.allowed and player.className and not info.allowed:find(player.className, 1, true) then return end
    if info.class == 2 and sub then
        if not prof.weapons[sub] or info.inv == 22 and not canDualWield(player, prof) then return end
        local line = weaponSkills[sub]
        if line and sub ~= 13 and skillRank(line) == 0 and (skillRank(43) or skillRank(54) or skillRank(136) or 0) > 0 then return end
    elseif info.class == 4 and sub and not armorExempt[info.inv] then
        if sub >= 1 and sub <= 4 and sub > prof.armor then
            if not prof.promotes or sub > prof.armor + 1 then return end
            req = math.max(40, req)
        elseif sub == 6 and not prof.shield then
            return
        elseif sub >= 7 and sub <= 9 and sub ~= prof.relic then
            return
        end
    end
    return req
end

local function score(info, weights, slot)
    local points = 0
    for key, amount in pairs(info.stats) do
        if key ~= "dps" or not ranged[info.inv] then
            local modifier = key == "dps" and slot == 17 and 0.5 or 1
            points = points + amount * (weights[key] or 0) * modifier
        end
    end
    return points
end

local equipment, results, weights, player, bagWeapons
local resultDependencies = {}
local resultIDs = {}
local function clearResult(key)
    if results then results[key] = nil end
    resultDependencies[key] = nil
    local id = gear.ItemID(key)
    local keys = resultIDs[id]
    if keys then
        keys[key] = nil
        if not next(keys) then resultIDs[id] = nil end
    end
end
function gear.GetWeights()
    if not weights then
        local choice, class = app.ActiveProfile()
        weights = app.ProfileWeights(choice, class)
        for school, share in pairs(choice and choice.schools or {}) do
            weights[school] = weights.sp * share
        end
    end
    return weights
end
function gear.Invalidate(reason)
    if reason == "bagItems" then app.Fire("GEAR_UPDATED", reason); return end
    if reason == "bags" then
        bagWeapons = nil
        for key, depends in pairs(resultDependencies) do
            if depends then clearResult(key) end
        end
        app.Fire("GEAR_UPDATED", reason)
        return
    end
    equipment, results, weights, player, bagWeapons = nil, nil, nil, nil, nil
    resultDependencies, resultIDs = {}, {}
    app.Fire("GEAR_UPDATED", reason)
end
local function equipped()
    if equipment then return equipment end
    local slots = {}
    for slot = 1, 18 do
        if slot ~= 4 then
            local link = clients.InventoryLink(slot)
            if link then
                local info = gear.GetItemInfo(link)
                if not info then return end
                slots[slot] = { info = info, score = score(info, gear.GetWeights(), slot) }
            end
        end
    end
    equipment = slots
    return slots
end

local function partnerScore(slot, candidate, playerInfo, prof, weightsNow)
    if not bagWeapons then
        bagWeapons = {}
        for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
            for index = 1, clients.BagSlots(bag) do
                local link = clients.BagLink(bag, index)
                local info = link and gear.GetItemInfo(link)
                if info and (info.inv == 13 or info.inv == 14 or info.inv >= 21 and info.inv <= 23) then
                    local req = requiredLevel(info, playerInfo, prof)
                    if req and req <= playerInfo.level then bagWeapons[#bagWeapons + 1] = info end
                end
            end
        end
    end
    local best
    for _, info in ipairs(bagWeapons) do
        local eligible = info.inv == 13 and (slot == 16 or canDualWield(playerInfo, prof))
            or slot == 16 and info.inv == 21
            or slot == 17 and (info.inv == 14 or info.inv == 22 or info.inv == 23)
        if eligible and info.key ~= candidate.key and (not candidate.unique or candidate.id ~= info.id) then
            local points = score(info, weightsNow, slot)
            best = best and math.max(best, points) or points
        end
    end
    return best
end

local function compare(info, estimated)
    player = player or gear.GetPlayer()
    local prof = proficiency[player.class]
    if not prof then return end
    local req = requiredLevel(info, player, prof)
    if not req then return { usable = false } end
    local slots = equipped()
    if not slots then return end
    local weightsNow = gear.GetWeights()
    local best
    local function option(slot, subtractOffhand, subtractMainhand)
        local chosen = slots[slot]
        local old = chosen and chosen.score or 0
        if subtractOffhand and slots[17] then old = old + slots[17].score end
        if subtractMainhand and slots[16] then old = old + slots[16].score end
        local new = score(info, weightsNow, slot)
        if not estimated and slots[16] and slots[16].info.inv == 17 and info.inv ~= 17 then
            if slot == 16 then new = new + (partnerScore(17, info, player, prof, weightsNow) or 0)
            elseif slot == 17 then
                local main = partnerScore(16, info, player, prof, weightsNow)
                if not main then return end
                new = new + main
            end
        end
        local delta = new - old
        if not best or delta > best.delta then
            best = { usable = true, slot = slot, minLevel = req, old = old, new = new, delta = delta,
                empty = not (chosen or subtractMainhand and slots[16] or subtractOffhand and slots[17]),
                inv = info.inv, class = info.class }
            if old > 0 then best.pct = delta / old * 100 end
        end
    end
    local limitSlot
    for _, slot in ipairs(gear.SLOTS_OF[info.inv]) do
        local worn = slots[slot] and slots[slot].info
        if worn then
            if not estimated and worn.key == info.key then
                return { usable = true, equipped = true, slot = slot, minLevel = req, delta = 0 }
            end
            if (info.unique and info.id == worn.id) or (info.limit == 1 and info.category and info.category > 0 and info.category == worn.category) then
                limitSlot = slot
            end
        end
    end
    if info.inv == 17 then
        option(16, true)
    elseif limitSlot then
        option(limitSlot)
    else
        for _, slot in ipairs(gear.SLOTS_OF[info.inv]) do
            if info.inv ~= 13 or slot == 16 or canDualWield(player, prof) then
                option(slot, false, slot == 17 and slots[16] and slots[16].info.inv == 17)
            end
        end
    end
    return best
end

function gear.CompareToEquipped(link)
    local key = itemString(link)
    if not key then return end
    results = results or {}
    if results[key] then return results[key], true end
    local info = gear.GetItemInfo(link)
    if not info then return end
    local result = compare(info)
    results[key] = result
    if result then
        resultIDs[info.id] = resultIDs[info.id] or {}
        resultIDs[info.id][key] = true
    end
    resultDependencies[key] = info.inv == 13 or info.inv == 14 or info.inv == 21 or info.inv == 22 or info.inv == 23
    return result, false
end

-- Optional database values can prioritize uncached candidates. Results shown
-- in game always go through the client-backed comparison above.
function gear.EstimateRecord(id, record)
    if not gear.SLOTS_OF[record.inv] then return end
    local stats = {}
    for statKey, amount in pairs(record.stats or {}) do stats[statKey] = amount end
    stats.hastePercent = stats.haste
    if ranged[record.inv] then stats.rdps = stats.rdps or stats.dps end
    return compare({ id = id, inv = record.inv, class = record.class, subclass = record.subclass,
        req = record.req or 0, unique = record.unique, stats = stats }, true)
end

local bagKey, pairingKey, eligibilityKey
local bagIDs = {}
local function bagState()
    local all, partners, seen, partnerSeen = {}, {}, {}, {}
    local ids = {}
    local handSlot = INVSLOT_HAND or 10
    local physicalHand = gear.ItemID(GetInventoryItemLink and readable(GetInventoryItemLink("player", handSlot)))
    local combatHand = gear.ItemID(clients.InventoryLink(handSlot))
    local function include(link, inBag)
        local key, id = itemString(link), gear.ItemID(link)
        if not key or not id then return end
        local inv
        if items and items.GetItemInfoInstant then
            local _, _, _, loc = items.GetItemInfoInstant(link)
            inv = gear.EQUIP_LOC[readable(loc)]
            if loc and not gear.SLOTS_OF[inv] then return end
        end
        if not inv and (id == physicalHand or id == combatHand
            or suite.IsRidingGloveItem and suite.IsRidingGloveItem(id)) then inv = 10 end
        if not seen[key] then seen[key] = true; all[#all + 1] = key end
        if inBag then
            ids[id] = true
            if not inv or inv == 13 or inv == 14 or inv == 21 or inv == 22 or inv == 23 then
                if not partnerSeen[key] then partnerSeen[key] = true; partners[#partners + 1] = key end
            end
        end
    end
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        for slot = 1, clients.BagSlots(bag) do include(clients.BagLink(bag, slot), true) end
    end
    -- Include physical and effective equipment: automatic riding-glove swaps
    -- move the same two items between bags/equipment and do not add an item.
    for slot = 1, 18 do
        if slot ~= 4 then
            include(GetInventoryItemLink and readable(GetInventoryItemLink("player", slot)), false)
            include(clients.InventoryLink(slot), false)
        end
    end
    table.sort(all); table.sort(partners)
    bagIDs = ids
    return table.concat(all, "\031"), table.concat(partners, "\031")
end

for event, reason in pairs({
    PLAYER_ENTERING_WORLD = "world", PLAYER_EQUIPMENT_CHANGED = "equipment", PLAYER_LEVEL_UP = "level",
    BAG_UPDATE_DELAYED = "bags", SKILL_LINES_CHANGED = "skills", SPELLS_CHANGED = "skills",
}) do
    local change = reason
    local equipmentEvent = event == "PLAYER_EQUIPMENT_CHANGED"
    local worldEvent = event == "PLAYER_ENTERING_WORLD"
    app.RegisterEvent(event, function(_, slot)
        if equipmentEvent and suite.IsAutomaticMountGloveChange
            and suite.IsAutomaticMountGloveChange(slot) then return end
        if worldEvent or equipmentEvent then bagKey, pairingKey = bagState(); eligibilityKey = gear.EligibilityKey() end
        if change == "bags" then
            local current, pairing = bagState()
            local changed, weaponsChanged = current ~= bagKey, pairing ~= pairingKey
            bagKey, pairingKey = current, pairing
            if weaponsChanged then gear.Invalidate("bags")
            elseif changed then gear.Invalidate("bagItems") end
            return
        elseif change == "skills" then
            local current = gear.EligibilityKey()
            if current == eligibilityKey then return end
            eligibilityKey = current
        end
        gear.Invalidate(change)
    end)
end
local function itemArrival(_, id, success)
    id = readable(id)
    if type(id) ~= "number" or readable(success) == false then return end
    local keys = resultIDs[id]
    if keys then for key in pairs(keys) do clearResult(key) end end
    local bucket = itemCache[id]
    local baseline = false
    for _, entry in pairs(equipment or {}) do
        if entry.info.id == id then baseline = true; break end
    end
    if bucket then
        itemCache[id] = nil
        if not equipment then
            for slot = 1, 18 do
                if gear.ItemID(clients.InventoryLink(slot)) == id then baseline = true; break end
            end
        end
        local pairing
        for key, info in pairs(bucket) do
            cacheSize = math.max(0, cacheSize - 1)
            clearResult(key)
            if info.inv == 13 or info.inv == 14 or info.inv >= 21 and info.inv <= 23 then pairing = true end
        end
        if pairing and not baseline then
            for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
                for slot = 1, clients.BagSlots(bag) do
                    if gear.ItemID(clients.BagLink(bag, slot)) == id then baseline = true; break end
                end
                if baseline then break end
            end
        end
        if baseline then gear.Invalidate("items")
        else app.Fire("GEAR_UPDATED", "items", id) end
    elseif baseline then gear.Invalidate("items")
    elseif bagIDs[id] and items and items.GetItemInfoInstant then
        local _, _, _, loc = items.GetItemInfoInstant(id)
        local inv = gear.EQUIP_LOC[readable(loc)]
        if inv == 13 or inv == 14 or inv == 21 or inv == 22 or inv == 23 then gear.Invalidate("bags") end
    end
end
app.RegisterEvent("GET_ITEM_INFO_RECEIVED", itemArrival)
app.RegisterEvent("ITEM_DATA_LOAD_RESULT", itemArrival)
