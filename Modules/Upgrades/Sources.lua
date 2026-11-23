local _, suite = ...
local app = suite.upgrades
if not app then return end
local pole = Polestar
local availability = app.content
local moduleName = "AtlasLootClassic_DungeonsAndRaids"
local pixXizzix = 227853
-- Honor and battleground sellers can also be listed as ordinary vendors in the Codex.
local pvpVendors = {
    [12777] = true, [12781] = true, [12782] = true, [12784] = true, [12785] = true, [12792] = true,
    [12795] = true, [12799] = true, [12805] = true, [14581] = true,
    [12096] = true, [12097] = true, [13216] = true, [13217] = true, [13218] = true, [13219] = true,
    [14753] = true, [14754] = true, [15126] = true, [15127] = true, [263569] = true, [263570] = true,
}
local sourceNames = {
    quest = "Quest", boe = "BoE", dungeon = suite.L("Instanz"), raid = suite.L("Raid"), drop = suite.L("Drop"), vendor = suite.L("Händler"),
    craft = suite.L("Herstellung"), auction = suite.L("Auktionshaus"), bag = suite.L("Taschen"), undermine = "Undermine Real",
    pvp = suite.L("PvP-Händler"),
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
app.professionChoices = { { "", suite.L("Alle Berufe") } }
local professionByName = {}
for _, profession in ipairs(professions) do
    local name, label, line = unpack(profession)
    app.professionChoices[#app.professionChoices + 1] = { name, suite.L(label) }
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
    local detail = skill and (suite.L("Benötigt Skill ") .. skill) or suite.L("Skill unbekannt")
    if rank then detail = detail .. suite.L(" · Dein Skill ") .. rank end
    list[#list + 1] = {
        kind = "craft", title = suite.L(info[2]), detail = detail,
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

local bundledIndex = {}
local function bundledSources(faction)
    local key = faction or ""
    if bundledIndex[key] then return bundledIndex[key] end
    local guide = suite.instances
    local result = { items = {}, quests = {}, zones = {}, npcs = {}, locations = {}, loaded = guide ~= nil }
    for _, entry in ipairs(guide and guide.entries or {}) do
        local location = guide.Location(entry)
        result.locations[#result.locations + 1] = location
        if location.map and not result.zones[location.map] then result.zones[location.map] = location end
        for _, boss in ipairs(entry.loot) do
            local source = guide.Location(entry)
            source.boss = boss.name
            markNPCs(result.npcs, boss.npcs, source)
            for _, item in ipairs(boss.items) do
                if not item[3] or item[3] == faction then
                    availability.NoteItem(item[1], source)
                    add(result.items, item[1], { location = source, pct = item[2] > 0 and item[2] or nil })
                end
            end
        end
        for _, quest in ipairs(entry.quests) do
            if not quest.faction or quest.faction == faction then
                for _, item in ipairs(quest.rewards) do
                    add(result.quests, item, { quest = quest, location = location })
                end
            end
        end
    end
    bundledIndex[key] = result
    return result
end

local atlasIndex
local function atlasSources(faction)
    local atlas = AtlasLoot
    if atlasIndex and atlasIndex.faction == faction and atlasIndex.api == atlas then return atlasIndex end
    local result = { items = {}, zones = {}, npcs = {}, locations = {}, faction = faction, api = atlas }
    if not atlas then atlasIndex = result end
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
                kind = kind, name = clean(label), key = key, map = map, instanceID = content.InstanceID,
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
                        kind = kind, name = location.name, key = location.key, map = location.map,
                        instanceID = location.instanceID, min = location.min, suggested = location.suggested,
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
                                        availability.NoteItem(id, bossLocation)
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

local function localizedName(localize, name)
    if localize then
        local ok, value = pcall(localize, name)
        if ok and type(value) == "string" and value ~= "" then return clean(value) end
    end
    return name
end

local journalIndex
local function journalSources(faction, atlas)
    local journal = _G.ForeverDungeonJournal_NS
    if not (journal and type(journal.DB) == "table" and type(journal.ORDER) == "table") then
        return { items = {}, npcs = {}, locations = {} }
    end
    if journalIndex and journalIndex.db == journal.DB and journalIndex.atlas == atlas
        and journalIndex.faction == faction then return journalIndex end
    local result = { items = {}, npcs = {}, locations = {}, db = journal.DB, atlas = atlas, faction = faction, loaded = true }
    local atlasByName, instanceByName = {}, {}
    for _, location in ipairs(atlas.locations) do
        atlasByName[normalized(location.name)] = location
        if location.key then atlasByName[normalized(location.key)] = location end
    end
    for id, name in pairs(journal.INSTANCE_ID_TO_DUNGEON or {}) do instanceByName[name] = id end
    local rates = AtlasLoot and AtlasLoot.Data and AtlasLoot.Data.Droprate

    for _, key in ipairs(journal.ORDER) do
        local dungeon = journal.DB[key]
        if type(dungeon) == "table" then
            local name = localizedName(journal.LocalizeDungeonName, key)
            local known = atlasByName[normalized(key)] or atlasByName[normalized(name)]
                or atlasByName[normalized(key:gsub("^The ", ""))]
            local min = type(dungeon.level) == "string" and tonumber(dungeon.level:match("%d+")) or 1
            local location = {
                name = known and known.name or name, key = key, localName = name,
                kind = known and known.kind or "dungeon", active = not known or known.active,
                instanceID = known and known.instanceID or instanceByName[key],
                min = known and known.min or min, suggested = known and known.suggested or min,
            }
            result.locations[#result.locations + 1] = location
            for _, boss in ipairs(dungeon.bosses or {}) do
                if type(boss) == "table" and not boss.recipeTab and not boss.childOf and not boss.fdjDungeon
                    and (not boss.factionOnly or boss.factionOnly == faction) then
                    local fromAtlas = type(boss.npcID) == "number" and atlas.npcs[boss.npcID]
                    local bossLocation
                    if fromAtlas and fromAtlas.name == location.name then
                        bossLocation = fromAtlas
                    else
                        bossLocation = {
                            name = location.name, key = location.key, instanceID = location.instanceID,
                            kind = location.kind, active = location.active,
                            min = location.min, suggested = location.suggested,
                            boss = type(boss.name) == "string" and localizedName(journal.LocalizeBossName, boss.name) or nil,
                        }
                    end
                    markNPCs(result.npcs, boss.npcID, bossLocation)
                    if bossLocation.active then
                        local seen = {}
                        local function addLoot(loot)
                            for _, entry in ipairs(type(loot) == "table" and loot or {}) do
                                local id = type(entry) == "table" and tonumber(entry[1])
                                if id and id > 0 and not seen[id] then
                                    availability.NoteItem(id, bossLocation)
                                    seen[id] = true
                                    add(result.items, id, { location = bossLocation, pct = dropRate(rates, boss.npcID, id) })
                                end
                            end
                        end
                        addLoot(boss.loot)
                        if journal.GetBossSharedLoot then
                            local ok, shared = pcall(journal.GetBossSharedLoot, key, boss)
                            if ok then addLoot(shared) end
                        end
                    end
                end
            end
        end
    end
    journalIndex = result
    return result
end

function app.CurrentInstance(atlas, journal)
    if not GetInstanceInfo then return nil end
    local readable = suite.Readable
    local name, kind, _, _, _, _, _, id = GetInstanceInfo()
    kind, id = readable(kind), readable(id)
    if kind ~= "party" and kind ~= "raid" then return nil end
    name = readable(name)
    if type(name) ~= "string" then name = nil end
    local zone = normalized(name)
    if not atlas and not journal then return nil, name, id end

    local result = {}
    local function include(location) result[location.name] = true end
    local function matchLocations(index)
        for _, location in ipairs(index and index.locations or {}) do
            if (id and id > 0 and location.instanceID == id) or (zone ~= "" and (normalized(location.name) == zone
                or normalized(location.key) == zone or normalized(location.localName) == zone)) then
                include(location)
            end
        end
    end
    matchLocations(atlas)
    matchLocations(journal)
    -- Some instances have several loot tables under one world map. Their labels
    -- often include a wing suffix, even when the client's instance name doesn't.
    if not next(result) and zone ~= "" and atlas then
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
    if not availability.QuestAllowed(scan, id) then return end
    if not (pole and pole.Compat and pole.ItemDB) then
        if not live then return end
        local ready = C_QuestLog.ReadyForTurnIn and suite.Readable(C_QuestLog.ReadyForTurnIn(id))
        return { kind = "quest", title = live.title or ("Quest " .. id), quest = id,
            detail = ready and "Abgabebereit" or "Im Questlog", effort = ready and 1 or 2 }
    end
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
    if not availability.QuestAllowed(scan, id, q, codexQuest) then return nil end
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
    scan.content = availability.Snapshot()
    local db = pole and pole.QuestDB
    if db and not db.IsLoaded() then db.Load() end
    scan.codexLoaded = pole and pole.Codex and pole.Codex.Load()
    scan.player = pole and pole.Lookup and pole.Lookup.PlayerInfo and pole.Lookup.PlayerInfo()
    scan.questContext = db and db.PlayerContext() or { level = scan.level }
    scan.questContext.level = scan.level
    if scan.player and scan.level > scan.playerLevel then
        local player = {}
        for key, value in pairs(scan.player) do player[key] = value end
        player.level = scan.level
        scan.player = player
    end
    local skillRank = pole and pole.Compat and pole.Compat.GetSkillRank or app.gear.SkillRank
    scan.questOptions = { lowLevel = true, skillRank = skillRank }
    scan.questMemo = {}
    scan.activeRewards = liveRewards()
    local bundled = bundledSources(scan.faction)
    scan.atlas = atlasSources(scan.faction)
    if not scan.atlas.loaded and bundled.loaded then scan.atlas = bundled end
    scan.instanceQuestRewards = bundled.quests
    scan.journal = journalSources(scan.faction, scan.atlas)
    scan.crafting = craftingSources()
    scan.professionRanks = {}
    for _, profession in ipairs(professions) do
        scan.professionRanks[profession[3]] = skillRank(profession[3])
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
    if not availability.LocationAllowed(scan, location or { name = worldZone }) then return end
    if location and (not location.active or scan.level < location.min) then return end
    local kind = location and location.kind or "drop"
    local zone = location and location.name or worldZone
    local key = kind .. "\031" .. normalized(zone) .. "\031" .. normalized(title)
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
    local purchase = route.type == "vendor" or route.type == "pvp"
    if not item or (not purchase and route.type ~= "gift") then return false end
    local faction, standing
    if pole.Lookup.PurchaseRep then
        faction, standing = pole.Lookup.PurchaseRep(item, raw.npc, purchase)
    end
    if faction and (pole.Compat.GetFactionStanding(faction) or 4) < standing then return false end
    return not purchase or not item.reqSkill or not item.reqSkillRank
        or (pole.Compat.GetSkillRank(item.reqSkill) or 0) >= item.reqSkillRank
end

local function codexLocation(scan, raw, instanceKey)
    local location = scan.atlas.npcs[raw.npc] or scan.journal.npcs[raw.npc]
    if location then return location end
    local codex = pole and pole.Codex
    if not codex then return end
    local npc = raw.npc and codex.Npc and codex.Npc(raw.npc)
    local key = instanceKey or raw.instance or npc and npc.instance
    local instance = key and codex.Instance and codex.Instance(key)
    if instance then
        local levels, raid = instance.levels, instance.kind == "raid"
        local minimum = levels and levels[1] or (raid and 60 or scan.level)
        return { kind = raid and "raid" or "dungeon", name = instance.name, key = key,
            instanceID = type(key) == "number" and key or nil,
            min = minimum, suggested = levels and levels[2] or minimum, active = true }
    end
end

-- Only known locked IDs need the exception checks. This uses local source
-- metadata, never item tooltips, score calculations or item-data requests.
function app.CanSearchItem(scan, id)
    if availability.ItemAllowed(scan, id) or scan.presentItems and scan.presentItems[id] then return true end
    local function open(location)
        return location and location.active and scan.level >= location.min
            and availability.LocationAllowed(scan, location)
    end
    for _, index in ipairs({ scan.atlas, scan.journal }) do
        for _, drop in ipairs(index.items[id] or {}) do if open(drop.location) then return true end end
    end
    for _, source in ipairs(pole and pole.ItemDB and pole.ItemDB.Sources(id) or {}) do
        if source.kind == "drop" then
            local location = scan.atlas.npcs[source.npc] or scan.journal.npcs[source.npc] or scan.atlas.zones[source.zone]
            if open(location) then return true end
        end
    end
    local item = scan.codexLoaded and pole.Codex.Item and pole.Codex.Item(id)
    for _, source in ipairs(item and item.sources or {}) do
        if source.type == "drop" or source.type == "world" then
            if open(codexLocation(scan, source)) then return true end
        end
    end
    return false
end

local function addCodexSources(scan, id, list, quests, drops, crafts, restricted)
    local lookup = pole and pole.Lookup
    if not (scan.codexLoaded and lookup and lookup.Sources) then return end
    local ok, routes, item = pcall(lookup.Sources, "item", id, true)
    if not ok then
        app.RecordIssue(scan, id, routes)
        return
    end
    local vendors, pvpSellers = {}, {}
    local pvpEnabled = scan.content and scan.content.pvp
    for _, route in ipairs(routes) do
        if route.type == "pvp" and route.src and route.src.npc then pvpSellers[route.src.npc] = true end
    end
    for _, route in ipairs(routes) do
        local raw = route.src
        local pvp = route.type == "pvp" or raw and route.type == "vendor"
            and (pvpVendors[raw.npc] or pvpSellers[raw.npc])
        if raw and route.type == "craft" and not restricted then
            addCraft(scan, list, crafts, raw.skillLine, raw.skill, raw.spell)
        elseif raw and (not pvp or pvpEnabled) and (route.available or futureCodexSource(scan, route, item)) then
            if route.type == "quest" and raw.quest and not restricted then
                addQuest(scan, list, quests, raw.quest)
            elseif route.type == "drop" or route.type == "world" then
                local location = codexLocation(scan, raw, route.instance)
                local title = (location and location.boss) or route.label or suite.L("Weltbeute")
                availability.NoteItem(id, location)
                if not restricted or location and not availability.LocationGroup(location) then
                    addDrop(scan, list, drops, location, title, route.chance, route.zone)
                end
            elseif not restricted and (pvp and raw.npc or route.type == "vendor" or route.type == "gift") then
                local undermine = route.type == "vendor" and raw.npc == pixXizzix
                local kind = pvp and "pvp" or undermine and "undermine" or "vendor"
                local key = kind .. ":" .. tostring(raw.npc or route.label)
                local rank = pvp and type(raw.rank) == "number" and raw.rank > 0 and ("PvP-Rang " .. raw.rank) or nil
                local existing = vendors[key]
                if existing then
                    if rank then existing.detail = rank end
                else
                    local price = not pvp and type(route.price) == "number" and route.price or nil
                    local effort = pvp and 7 or raw.limited and 4 or price and price >= 100000 and 3 or 2
                    local source = {
                        kind = kind, title = route.label, zone = route.zone, effort = effort,
                        detail = price and price > 0 and GetCoinTextureString and GetCoinTextureString(price)
                            or rank or (raw.limited and "Begrenzter Vorrat") or nil,
                    }
                    vendors[key] = source
                    list[#list + 1] = source
                end
            end
        end
    end
end

function app.GetSources(scan, id, item)
    local list, quests, drops, crafts = {}, {}, {}, {}
    local released = availability.ItemAllowed(scan, id)
    for _, quest in ipairs(released and scan.activeRewards[id] or {}) do
        addQuest(scan, list, quests, quest.questID, quest)
    end
    for _, row in ipairs(released and scan.instanceQuestRewards and scan.instanceQuestRewards[id] or {}) do
        local quest = row.quest
        if not quests[quest.id] and (not quest.min or scan.level >= quest.min)
            and availability.LocationAllowed(scan, row.location) and availability.QuestAllowed(scan, quest.id)
            and not suite.ReadGameValue(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, quest.id) then
            quests[quest.id] = true
            list[#list + 1] = { kind = "quest", title = suite.instances.QuestTitle(quest), quest = quest.id,
                zone = row.location.localName, detail = suite.L("Instanzquest"), effort = 3 }
        end
    end
    for _, drop in ipairs(scan.atlas.items[id] or {}) do
        local location = drop.location
        addDrop(scan, list, drops, location, location.boss or "Instanzbeute", drop.pct)
    end
    for _, drop in ipairs(scan.journal.items[id] or {}) do
        local location = drop.location
        addDrop(scan, list, drops, location, location.boss or "Instanzbeute", drop.pct)
    end
    for _, source in ipairs(pole and pole.ItemDB and pole.ItemDB.Sources(id) or {}) do
        if source.kind == "quest" and released then
            addQuest(scan, list, quests, source.quest)
        elseif source.kind == "craft" and released then
            addCraft(scan, list, crafts, source.profession, source.skill, source.spell)
        elseif source.kind == "drop" then
            local location = scan.atlas.npcs[source.npc] or scan.journal.npcs[source.npc] or scan.atlas.zones[source.zone]
            availability.NoteItem(id, location)
            local title = (location and location.boss) or source.npcName or source.zoneName or suite.L("Fundort unbekannt")
            if released or location and not availability.LocationGroup(location) then
                addDrop(scan, list, drops, location, title, source.pct, source.zoneName)
            end
        end
    end
    for _, recipe in ipairs(released and scan.crafting[id] or {}) do
        addCraft(scan, list, crafts, recipe.profession, recipe.skill, recipe.spell)
    end
    addCodexSources(scan, id, list, quests, drops, crafts, not released)
    local key = item and (app.VariantKey(item.link) or id) or id
    if scan.bagItems and scan.bagItems[key] then
        list[#list + 1] = { kind = "bag", title = suite.L("In deinen Taschen"), effort = 1 }
    end
    local offers = item and scan.auctions and scan.auctions[id]
    local offer = offers and offers[key]
    local browse = scan.browseItems and scan.browseItems[key]
    local tradeable = released and item and item.boe
    local estimate
    if item and (tradeable or offer or browse) and suite.GetTSMMinBuyout then
        estimate = suite.GetTSMMinBuyout(item.link, id)
    end
    if offer then
        list[#list + 1] = {
            kind = "auction", title = suite.L("Sofortkauf"), price = offer.price, at = offer.at, tsmPrice = estimate, effort = 2,
        }
    elseif browse then
        list[#list + 1] = {
            kind = "auction", title = suite.L("AH-Übersicht"), price = browse.price or estimate,
            isEstimate = not browse.price and estimate ~= nil, tsmPrice = browse.price and estimate, effort = 2,
        }
    end
    if tradeable then
        local effort = item.quality >= 4 and 7 or item.quality >= 3 and 5 or 3
        if estimate and not offer and not browse then
            list[#list + 1] = { kind = "auction", title = suite.L("TSM-Schätzpreis"), price = estimate, isEstimate = true, effort = effort }
        end
        list[#list + 1] = { kind = "boe", title = suite.L("Auktionshaus / Handel"), detail = suite.L("Bestand und Preis unbekannt"), effort = effort }
    end
    table.sort(list, function(a, b)
        if a.effort ~= b.effort then return a.effort < b.effort end
        if a.kind ~= b.kind then return a.kind < b.kind end
        if a.title ~= b.title then return a.title < b.title end
        return (a.zone or "") < (b.zone or "")
    end)
    return list
end
