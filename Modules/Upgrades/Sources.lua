local _, suite = ...
local app = suite.upgrades
if not app then return end
local pole = Polestar
local moduleName = "AtlasLootClassic_DungeonsAndRaids"
local sourceNames = {
    quest = "Quest", boe = "BoE", dungeon = "Instanz", raid = "Raid", drop = "Drop", vendor = "Händler",
    craft = "Herstellung", auction = "Auktionshaus",
}
app.sourceNames = sourceNames

local professions = {
    { "Leatherworking", "Lederverarbeitung", 165 },
    { "Blacksmithing", "Schmiedekunst", 164 },
    { "Tailoring", "Schneiderei", 197 },
    { "Engineering", "Ingenieurskunst", 202 },
    { "Alchemy", "Alchemie", 171 },
    { "Enchanting", "Verzauberkunst", 333 },
    { "Jewelcrafting", "Juwelierskunst", 755 },
}
app.professionChoices = { { "", "Alle Berufe" } }
local professionByName = {}
for _, profession in ipairs(professions) do
    local name, label, line = unpack(profession)
    app.professionChoices[#app.professionChoices + 1] = { name, label }
    professionByName[name], professionByName[line] = profession, profession
end

local function clean(text)
    return (text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+$", ""))
end

local function add(index, id, source)
    local list = index[id]
    if not list then
        list = {}
        index[id] = list
    end
    list[#list + 1] = source
end

local craftingIndex
local function craftingSources()
    if craftingIndex then return craftingIndex end
    local atlas = AtlasLoot
    local db = atlas and atlas.ItemDB
    local recipes = atlas and atlas.Data and atlas.Data.Profession
    if not (db and recipes and recipes.GetProfessionData) then return {} end
    local name = "AtlasLootClassic_Crafting"
    if not db:Get(name) and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, name)
    end
    local module = db:Get(name)
    if not module then return {} end
    local index = {}
    for _, profession in ipairs(professions) do
        local content = module[profession[1]]
        if content then
            local seen = {}
            for _, group in ipairs(content.items) do
                for difficulty in ipairs(module:GetDifficultys()) do
                    local rows = group[difficulty]
                    if type(rows) == "table" then
                        for _, row in pairs(rows) do
                            local spell = type(row) == "table" and row[2]
                            if type(spell) == "number" and not seen[spell] then
                                seen[spell] = true
                                local recipe = recipes.GetProfessionData(spell)
                                if recipe and type(recipe[1]) == "number" and recipe[1] > 0 then
                                    add(index, recipe[1], { profession = profession[1], spell = spell, skill = recipe[3] })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    craftingIndex = index
    return index
end

local function addCraft(scan, list, seen, profession, skill, spell)
    local info = professionByName[profession]
    if not info or seen[info[1]] then return end
    seen[info[1]] = true
    skill = type(skill) == "number" and skill > 0 and skill or nil
    local rank = scan.professionRanks[info[3]]
    local detail = skill and ("Benötigt Skill " .. skill) or "Skill unbekannt"
    if rank then detail = detail .. " · Dein Skill " .. rank end
    list[#list + 1] = {
        kind = "craft", title = info[2], detail = detail,
        profession = info[1], skill = skill, spell = spell,
        effort = skill and math.min(9, 3 + math.floor((skill - 1) / 75)) or 4,
    }
end

local function rarity(pct)
    if not pct or pct <= 0 then return 1 end
    if pct >= 35 then return 0 end
    if pct >= 15 then return 1 end
    if pct >= 5 then return 2 end
    if pct >= 1 then return 3 end
    return 4
end

local function dropRate(rates, npcs, item)
    if not rates then return nil end
    if type(npcs) == "number" then return rates:GetData(npcs, item) end
    local best
    for _, npc in ipairs(type(npcs) == "table" and npcs or {}) do
        local chance = rates:GetData(npc, item)
        if chance and (not best or chance > best) then best = chance end
    end
    return best
end

local function markNPCs(index, npc, location)
    if type(npc) == "number" then
        index[npc] = location
    elseif type(npc) == "table" then
        for _, id in ipairs(npc) do index[id] = location end
    end
end

local atlasIndex
local function atlasSources(faction)
    if atlasIndex and atlasIndex.faction == faction then return atlasIndex end
    local result = { items = {}, zones = {}, npcs = {}, locations = {}, faction = faction }
    local atlas = AtlasLoot
    if not (atlas and atlas.ItemDB) then return result end
    local db = atlas.ItemDB
    if not db:Get(moduleName) and C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn(moduleName)
    end
    local module = db:Get(moduleName)
    if not module then return result end

    local classic = atlas.CLASSIC_VERSION_NUM
    local phases = atlas.Data and atlas.Data.ContentPhase
    local rates = atlas.Data and atlas.Data.Droprate
    local otherFaction = faction == "Horde" and "alliance" or "horde"
    local difficulties = module:GetDifficultys()
    local allowed = {}
    for difficulty, info in ipairs(difficulties) do
        allowed[difficulty] = info.uniqueName ~= otherFaction
    end

    for _, key in ipairs(db:GetModuleList(moduleName)) do
        local content = module[key]
        if content.gameVersion == classic and not content.IgnoreAsSource then
            local range = content.LevelRange
            local kind = range and "dungeon" or "raid"
            local label = content.name or (content.MapID and C_Map and C_Map.GetAreaInfo(content.MapID)) or key
            local phaseOK = not phases or phases:IsActive(content.ContentPhase, classic)
            local map = content.MapID or content.AreaID
            local location = {
                kind = kind, name = clean(label), map = map, instanceID = content.InstanceID,
                min = range and range[1] or 60,
                suggested = range and (range[2] or range[1]) or 60, active = phaseOK,
            }
            result.locations[#result.locations + 1] = location
            if map then
                local prior = result.zones[map]
                if not prior or location.min < prior.min then result.zones[map] = location end
            end
            for _, boss in pairs(content.items) do
                if type(boss) == "table" and not boss.IgnoreAsSource and not boss.ExtraList then
                    local bossActive = phaseOK and (not phases or phases:IsActive(boss.ContentPhase, classic))
                    local bossLocation = {
                        kind = kind, name = location.name, min = location.min, suggested = location.suggested,
                        active = bossActive, boss = type(boss.name) == "string" and clean(boss.name) or nil,
                    }
                    markNPCs(result.npcs, boss.npcID, bossLocation)
                    if bossActive then
                        local seen = {}
                        for difficulty, loot in pairs(boss) do
                            if allowed[difficulty] and type(loot) == "table" then
                                for _, row in pairs(loot) do
                                    local id = type(row) == "table" and row[2]
                                    if type(id) == "number" and id > 0 and not seen[id] then
                                        seen[id] = true
                                        local pct = dropRate(rates, boss.npcID, id)
                                        add(result.items, id, { location = bossLocation, pct = pct })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    result.loaded = true
    atlasIndex = result
    return result
end

local function normalized(name)
    if type(name) ~= "string" then return "" end
    return clean(name):lower():gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"):gsub("[%p%s]", "")
end

function app.CurrentInstance(atlas)
    if not GetInstanceInfo then return nil end
    local readable = pole.Compat.Readable
    local name, kind, _, _, _, _, _, id = GetInstanceInfo()
    kind, id = readable(kind), readable(id)
    if kind ~= "party" and kind ~= "raid" then return nil end
    name = readable(name)
    if type(name) ~= "string" then name = nil end
    local zone = normalized(name)
    if not atlas then return nil, name, id end

    local result = {}
    local function include(location) result[location.name] = true end
    for _, location in ipairs(atlas.locations) do
        if (id and id > 0 and location.instanceID == id) or (zone ~= "" and normalized(location.name) == zone) then
            include(location)
        end
    end
    -- Some instances have several loot tables under one world map. Their labels
    -- often include a wing suffix, even when the client's instance name doesn't.
    if not next(result) and zone ~= "" then
        for _, location in ipairs(atlas.locations) do
            local candidate = normalized(location.name)
            local area = location.map and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(location.map)
            if normalized(area) == zone or (#zone >= 5 and candidate:find(zone, 1, true) == 1) then
                include(location)
            end
        end
    end
    if not next(result) then
        if zone == "" then return nil, name, id end
        result[name] = true
    end
    return result, name, id
end

local function isAllowed(mask, flag)
    return not mask or mask <= 0 or not flag or math.floor(mask / flag) % 2 == 1
end

local function questSource(scan, id, live)
    local compat, db, ctx = pole.Compat, pole.QuestDB, scan.questContext
    local q = pole.ItemDB.Quest(id)
    local record = db and db.QuestRecord(id)
    if compat.IsQuestCompleted(id) then return nil end
    if q and (q.req > scan.level or not isAllowed(q.reqClass, ctx.classBit)
        or not isAllowed(q.reqRace, ctx.raceBit)
        or (q.side ~= 0 and q.side ~= 3 and ctx.faction and q.side ~= ctx.faction)) then
        return nil
    end
    local active = live or compat.IsOnQuest(id)
    if record and not active and not db.CheckAvailable(id, ctx, compat.IsQuestCompleted, compat.IsOnQuest, scan.questOptions) then
        return nil
    end
    local codexQuest = scan.codexLoaded and pole.Codex.Quest(id)
    if codexQuest and not active then
        if pole.Lookup and pole.Lookup.QuestBlock and pole.Lookup.QuestBlock(codexQuest, scan.player) then return nil end
        if codexQuest.repFaction and codexQuest.repStanding
            and (compat.GetFactionStanding(codexQuest.repFaction) or 4) < codexQuest.repStanding then
            return nil
        end
        for _, pre in ipairs(codexQuest.pre or {}) do
            if not compat.IsQuestCompleted(pre) then return nil end
        end
        if codexQuest.preAny and #codexQuest.preAny > 0 then
            local complete
            for _, pre in ipairs(codexQuest.preAny) do
                if compat.IsQuestCompleted(pre) then complete = true; break end
            end
            if not complete then return nil end
        end
    end
    local ready = active and compat.IsQuestReadyForTurnIn(id)
    local level = q and q.level or (record and record[db.F.LEVEL]) or (codexQuest and codexQuest.level) or scan.level
    local grouped = (q and q.dungeon) or (live and live.group and live.group > 1)
    local objectiveData = record and record[db.F.OBJ]
    local extra = objectiveData and #objectiveData >= 9 and 1 or 0
    local effort = ready and 1 or (active and 2 or 3) + (grouped and 2 or 0)
        + math.min(2, math.max(0, math.ceil((level - scan.level) / 3))) + extra
    return {
        kind = "quest", title = (live and live.title) or (q and q.name) or (db and db.GetQuestTitle(id))
            or (codexQuest and codexQuest.title) or ("Quest " .. id),
        detail = ready and "Abgabebereit" or active and "Im Questlog" or record and "Annehmbar laut Questdaten" or "Voraussetzungen teilweise unbekannt",
        zone = q and q.zoneName, quest = id, effort = effort,
    }
end

local function liveRewards()
    local index = {}
    if not (C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetNumQuestLogEntries) then return index end
    local function readRewards(quest, count, info)
        if not count or not info then return end
        for i = 1, count(quest.questID) or 0 do
            local _, _, _, _, _, id = info(i, quest.questID)
            if type(id) == "number" and id > 0 then
                add(index, id, quest)
            end
        end
    end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local q = C_QuestLog.GetInfo(i)
        if q and not q.isHeader and type(q.questID) == "number" and q.questID > 0 then
            local entry = { questID = q.questID, title = q.title, group = q.suggestedGroup }
            readRewards(entry, GetNumQuestLogRewards, GetQuestLogRewardInfo)
            readRewards(entry, GetNumQuestLogChoices, GetQuestLogChoiceInfo)
        end
    end
    return index
end

function app.PrepareSources(scan)
    local db = pole.QuestDB
    if db and not db.IsLoaded() then db.Load() end
    scan.codexLoaded = pole.Codex and pole.Codex.Load()
    scan.player = pole.Lookup and pole.Lookup.PlayerInfo and pole.Lookup.PlayerInfo()
    scan.questContext = db and db.PlayerContext() or { level = scan.level }
    scan.questContext.level = scan.level
    if scan.player and scan.level > scan.playerLevel then
        local player = {}
        for key, value in pairs(scan.player) do player[key] = value end
        player.level = scan.level
        scan.player = player
    end
    scan.questOptions = { lowLevel = true, skillRank = pole.Compat.GetSkillRank }
    scan.questMemo = {}
    scan.activeRewards = liveRewards()
    scan.atlas = atlasSources(scan.faction)
    scan.crafting = craftingSources()
    scan.professionRanks = {}
    for _, profession in ipairs(professions) do
        scan.professionRanks[profession[3]] = pole.Compat.GetSkillRank(profession[3])
    end
    scan.questDBLoaded = db and db.IsLoaded()
end

local function addQuest(scan, list, seen, id, live)
    if seen[id] then return end
    seen[id] = true
    local source = scan.questMemo[id]
    if source == nil then
        source = questSource(scan, id, live) or false
        scan.questMemo[id] = source
    end
    if source then list[#list + 1] = source end
end

local function addDrop(scan, list, seen, location, title, pct, worldZone)
    if location and (not location.active or scan.level < location.min) then return end
    local kind = location and location.kind or "drop"
    local zone = location and location.name or worldZone
    local key = kind .. (zone or "") .. title
    local prior = seen[key]
    if prior and (prior.pct or 0) >= (pct or 0) then return end
    local group = kind == "raid" and 7 or kind == "dungeon" and 4 or 5
    local gap = location and math.max(0, location.suggested - scan.level) or 0
    local effort = math.min(10, group + rarity(pct) + math.min(2, math.ceil(gap / 4)))
    local source = prior or {}
    source.kind, source.title, source.zone, source.pct, source.effort = kind, title, zone, pct, effort
    if not prior then
        seen[key] = source
        list[#list + 1] = source
    end
end

local function futureCodexSource(scan, route, item)
    if scan.level <= scan.playerLevel or route.why ~= "level" then return false end
    local raw = route.src
    if route.type == "quest" then return true end -- addQuest checks the planned level and prerequisites.
    if route.type == "drop" or route.type == "world" then
        local npc = raw.npc and pole.Codex.Npc and pole.Codex.Npc(raw.npc)
        return math.max(raw.minLevel or 0, npc and npc.level or 0) <= scan.level + 5
    end
    if (route.type ~= "vendor" and route.type ~= "gift") or not item then return false end
    local faction, standing
    if pole.Lookup.PurchaseRep then
        faction, standing = pole.Lookup.PurchaseRep(item, raw.npc, route.type == "vendor")
    end
    if faction and (pole.Compat.GetFactionStanding(faction) or 4) < standing then return false end
    return route.type ~= "vendor" or not item.reqSkill or not item.reqSkillRank
        or (pole.Compat.GetSkillRank(item.reqSkill) or 0) >= item.reqSkillRank
end

local function addCodexSources(scan, id, list, quests, drops, crafts)
    local lookup = pole.Lookup
    if not (scan.codexLoaded and lookup and lookup.Sources) then return end
    local ok, routes, item = pcall(lookup.Sources, "item", id, true)
    if not ok then
        app.RecordIssue(scan, id, routes)
        return
    end
    local vendors = {}
    for _, route in ipairs(routes) do
        local raw = route.src
        if raw and route.type == "craft" then
            addCraft(scan, list, crafts, raw.skillLine, raw.skill, raw.spell)
        elseif raw and (route.available or futureCodexSource(scan, route, item)) then
            if route.type == "quest" and raw.quest then
                addQuest(scan, list, quests, raw.quest)
            elseif route.type == "drop" or route.type == "world" then
                local location = scan.atlas.npcs[raw.npc]
                if not location and route.instance then
                    local instance = pole.Codex.Instance(route.instance)
                    if instance then
                        local levels = instance.levels
                        local raid = instance.kind == "raid"
                        local minimum = levels and levels[1] or (raid and 60 or scan.level)
                        location = {
                            kind = raid and "raid" or "dungeon", name = instance.name,
                            min = minimum, suggested = levels and levels[2] or minimum, active = true,
                        }
                    end
                end
                local title = (location and location.boss) or route.label or "Weltbeute"
                addDrop(scan, list, drops, location, title, route.chance, route.zone)
            elseif route.type == "vendor" or route.type == "gift" then
                local key = raw.npc or route.label
                if not vendors[key] then
                    vendors[key] = true
                    local price = type(route.price) == "number" and route.price or nil
                    local effort = raw.limited and 4 or price and price >= 100000 and 3 or 2
                    list[#list + 1] = {
                        kind = "vendor", title = route.label, zone = route.zone, effort = effort,
                        detail = price and price > 0 and GetCoinTextureString and GetCoinTextureString(price)
                            or (raw.limited and "Begrenzter Vorrat") or nil,
                    }
                end
            end
        end
    end
end

function app.GetSources(scan, id, item)
    local list, quests, drops, crafts = {}, {}, {}, {}
    for _, quest in ipairs(scan.activeRewards[id] or {}) do
        addQuest(scan, list, quests, quest.questID, quest)
    end
    for _, drop in ipairs(scan.atlas.items[id] or {}) do
        local location = drop.location
        addDrop(scan, list, drops, location, location.boss or "Instanzbeute", drop.pct)
    end
    for _, source in ipairs(pole.ItemDB.Sources(id) or {}) do
        if source.kind == "quest" then
            addQuest(scan, list, quests, source.quest)
        elseif source.kind == "craft" then
            addCraft(scan, list, crafts, source.profession, source.skill, source.spell)
        elseif source.kind == "drop" then
            local location = scan.atlas.npcs[source.npc] or scan.atlas.zones[source.zone]
            local title = (location and location.boss) or source.npcName or source.zoneName or "Fundort unbekannt"
            addDrop(scan, list, drops, location, title, source.pct, source.zoneName)
        end
    end
    for _, recipe in ipairs(scan.crafting[id] or {}) do
        addCraft(scan, list, crafts, recipe.profession, recipe.skill, recipe.spell)
    end
    addCodexSources(scan, id, list, quests, drops, crafts)
    local offers = item and scan.auctions and scan.auctions[id]
    local offer = offers and offers[app.VariantKey(item.link) or id]
    if offer then
        list[#list + 1] = { kind = "auction", title = "Sofortkauf", price = offer.price, at = offer.at, effort = 2 }
    end
    if item and item.boe then
        local effort = item.quality >= 4 and 7 or item.quality >= 3 and 5 or 3
        list[#list + 1] = { kind = "boe", title = "Auktionshaus / Handel", detail = "Bestand und Preis unbekannt", effort = effort }
    end
    table.sort(list, function(a, b)
        if a.effort ~= b.effort then return a.effort < b.effort end
        if a.kind ~= b.kind then return a.kind < b.kind end
        if a.title ~= b.title then return a.title < b.title end
        return (a.zone or "") < (b.zone or "")
    end)
    return list
end
