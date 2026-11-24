local _, app = ...
local guide, planner, provider = app.instances, app.dungeonQuests, app.DungeonQuestData

-- Several wings share an instance ID in both catalogs. Link by stable wing key.
local questKeys = {
    alcazprison = "ALCAZ", blackfathom = "BFD", blackmawhold = "BLACKMAW", blackrockdepths = "BRD",
    dalaran = "DALARAN", deadmines = "DM", diremaul_east = "DM_E", diremaul_north = "DM_N",
    diremaul_west = "DM_W", drownedcity = "DROWNED", excavationsite = "EXCAVATION",
    gnomeregan = "GNOMER", hallofthanes = "THANES", kroldok = "KROLDOK", lowerblackrock = "LBRS",
    maraudon = "MARA", ragefire = "RFC", razorfendowns = "RFD", razorfenkraul = "RFK",
    ruinsoflordaeron = "LORDAERON", scholomance = "SCHOLO", shadowfang = "SFK", shapersterrace = "SHAPERS",
    sm_armory = "SM_ARM", sm_cathedral = "SM_CATH", sm_graveyard = "SM_GY", sm_library = "SM_LIB",
    stockade = "STOCKS", stratholme_living = "STRAT_LIVE", stratholme_undead = "STRAT_UD",
    sunkentemple = "ST", uldaman = "ULDA", upperblackrock = "UBRS", wailingcaverns = "WC", zulfarrak = "ZF",
}

function guide.HasQuestPoint(point)
    return point and type(point.map) == "number" and app.ValidMapPoint(point.x, point.y)
end

local function addMapPoint(points, legacy)
    if not legacy then return points end
    for _, point in ipairs(points) do if guide.HasQuestPoint(point) then return points end end
    local merged = { unpack(points) }
    merged[#merged + 1] = { name = app.L("Kartenpunkt"), map = legacy[1], x = legacy[2], y = legacy[3] }
    return merged
end

function guide.QuestSnapshot(entry)
    local key = questKeys[entry.key]
    local primary = key and planner.Build(key)
    local snapshot = { key = key, provider = provider, quests = {}, done = 0, active = 0,
        incomplete = not primary or primary.dungeon.incomplete }
    local byID, added = {}, {}
    local function add(row)
        if added[row.id] or row.status == "OTHER" then return end
        added[row.id] = true
        snapshot.quests[#snapshot.quests + 1] = row
        if row.status == "DONE" then snapshot.done = snapshot.done + 1 end
        if row.status == "READY" or row.status == "ACTIVE" then snapshot.active = snapshot.active + 1 end
    end
    for _, row in ipairs(primary and primary.quests or {}) do
        byID[row.id] = row
        add(row)
    end
    for _, known in ipairs(entry.quests) do
        if guide.AllowedFaction(known.faction) then
            local row = byID[known.id] or planner.FindQuest(known.id, snapshot)
            if not row then
                local faction = known.faction == "Horde" and "H" or known.faction == "Alliance" and "A" or nil
                local title = provider and provider.QuestTitle(known.id)
                if not title or title == "Quest #" .. known.id then title = guide.QuestTitle(known) end
                row = planner.DescribeQuest({ id = known.id, title = title, faction = faction,
                    minLevel = known.min })
            elseif row.title == "Quest #" .. known.id then
                row.title = guide.QuestTitle(known)
            end
            row.givers = addMapPoint(row.entry.givers or {}, known.start)
            row.enders = addMapPoint(row.entry.enders or {}, known.finish)
            row.rewards = known.rewards
            add(row)
        end
    end
    return snapshot
end

function guide.QuestPrerequisites(snapshot, id)
    local result = {}
    if not snapshot.key or not provider then return result end
    for _, prior in ipairs(provider.Prerequisites(id) or {}) do
        local row = planner.FindQuest(prior, snapshot)
        if row then result[#result + 1] = row end
    end
    return result
end
