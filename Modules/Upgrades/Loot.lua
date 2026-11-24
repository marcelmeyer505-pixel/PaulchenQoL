local _, suite = ...
local app = suite.upgrades
if not app then return end
local gear, read, plain = app.gear, suite.ReadGameValue, suite.Readable
local history = C_LootHistory
local loot = { drops = {} }
app.loot = loot
local byRoll, announced = {}, {}
local lastSound

function app.LootAlertsEnabled()
    return not PaulchenQoLUpgradesDB or PaulchenQoLUpgradesDB.lootAlerts ~= false
end

local function key(link)
    return app.VariantKey(link) or gear.ItemID(link)
end

function loot.TimeLeft(drop)
    if not drop.rollID or drop.closed or drop.winner or drop.allPassed then return 0 end
    local ms = read(GetLootRollTimeLeft, drop.rollID)
    return math.max(0, type(ms) == "number" and ms / 1000 or drop.deadline - GetTime())
end

local function findDrop(itemKey, predicate)
    local match
    for _, drop in ipairs(loot.drops) do
        if drop.key == itemKey and predicate(drop) then
            if match then return end
            match = drop
        end
    end
    return match
end

local function recentRoll(drop)
    return drop.rollID and GetTime() <= (drop.finishedAt or drop.deadline) + 8
end

local function addRoll(rollID, link, icon, count, deadline)
    local id = gear.ItemID(link)
    if not id then return end
    local drop = {
        id = id, rollID = rollID, key = key(link), link = link, icon = icon, count = count, players = {}, deadline = deadline,
        name = link:match("|h%[(.-)%]|h") or read(C_Item and C_Item.GetItemNameByID, id) or ("Item " .. id),
    }
    table.insert(loot.drops, 1, drop)
    for index = #loot.drops, 41, -1 do
        local old = loot.drops[index]
        if loot.TimeLeft(old) == 0 then
            if byRoll[old.rollID] == old then byRoll[old.rollID] = nil end
            table.remove(loot.drops, index)
        end
    end
    return drop
end

local function announce(drop)
    if not app.LootAlertsEnabled() then return end
    local now = GetTime()
    for itemKey, expires in pairs(announced) do
        if expires <= now then announced[itemKey] = nil end
    end
    if announced[drop.key] then return end
    announced[drop.key] = math.max(now + 8, (drop.deadline or 0) + 6)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cfffad176Paulchen Upgrades|r · " .. drop.link .. " · |cff87eaae" .. drop.gain .. "|r")
    end
    local sound = SOUNDKIT and (SOUNDKIT.UI_EPICLOOT_TOAST or SOUNDKIT.RAID_WARNING)
    if sound and PlaySound and (not lastSound or now - lastSound > 1) then
        lastSound = now
        pcall(PlaySound, sound, "SFX")
    end
end

local function checkUpgrade(drop, attempt)
    local result = read(gear.CompareToEquipped, drop.link)
    if result then
        local player = read(gear.GetPlayer)
        if player and app.IsUpgrade(result, player.level) then
            local gain = result.pct and ("+%.1f %%"):format(result.pct) or suite.LF("+%.2f Punkte", result.delta)
            if result.pct and result.pct < 0.05 then gain = "+<0.1 %" end
            if result.empty then gain = gain .. suite.L(" · Freier Slot") end
            drop.gain = suite.LocalizeDecimal(gain)
            announce(drop)
        end
    else
        local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
        local ok, _, _, _, location
        if instant then ok, _, _, _, location = pcall(instant, drop.link) end
        if ok and plain(location) == "" then return end
        if attempt < 3 then
            if attempt == 0 then read(C_Item and C_Item.RequestLoadItemDataByID, drop.id) end
            C_Timer.After(0.3 * 2 ^ attempt, function() checkUpgrade(drop, attempt + 1) end)
            return
        end
    end
    if loot.Refresh then loot.Refresh() end
end

local function rollOptions(id)
    if not GetLootRollItemInfo then return end
    local ok, icon, name, count, _, _, need, greed, _, _, _, _, _, transmog = pcall(GetLootRollItemInfo, id)
    if ok then
        return plain(icon), plain(name), plain(count), plain(need) == true, plain(greed) == true, plain(transmog) == true
    end
end

function loot.CanReplaceRoll(id)
    local drop = byRoll[id]
    return RollOnLoot and drop and drop.hasOptions and loot.TimeLeft(drop) > 0
end

function loot.CanChoose(drop)
    return RollOnLoot ~= nil and drop ~= nil and drop.hasOptions and loot.TimeLeft(drop) > 0
        and not drop.voted and (drop.requestUntil or 0) <= GetTime()
end

function loot.Roll(drop, choice)
    if not loot.CanChoose(drop) then return end
    local _, name, _, need, greed, transmog = rollOptions(drop.rollID)
    if not name or not (choice == 0 or choice == 1 and need or choice == 2 and greed and not transmog
        or choice == 4 and transmog) then return end
    local ok, accepted = pcall(RollOnLoot, drop.rollID, choice)
    ok = ok and plain(accepted) ~= false
    if ok then drop.requestUntil = GetTime() + 1 end
    if loot.Refresh then loot.Refresh() end
    return ok
end

local pending = {}
local function startRoll(id, ms, restored)
    local previous = byRoll[id]
    if pending[id] or previous and (loot.TimeLeft(previous) > 0 or not restored and recentRoll(previous)) then return end
    local deadline = GetTime() + (type(ms) == "number" and ms / 1000 or 60)
    local historyTime = not restored and read(history and history.GetLootHistoryTime) or nil
    local token = {}
    pending[id] = token
    local function load(attempt)
        if pending[id] ~= token then return end
        local icon, name, count, need, greed, transmog = rollOptions(id)
        local link = read(GetLootRollItemLink, id)
        if gear.ItemID(link) and (name or attempt == 3) then
            pending[id] = nil
            local drop = addRoll(id, link, icon, count, deadline)
            drop.historyTime = historyTime
            drop.need, drop.greed, drop.transmog, drop.hasOptions = need, greed, transmog, name ~= nil
            byRoll[id] = drop
            app.ObserveVariant(drop.link)
            checkUpgrade(drop, 0)
            if loot.ShowNew then loot.ShowNew(drop) end
        elseif attempt < 3 then
            C_Timer.After(0.25, function() load(attempt + 1) end)
        else
            pending[id] = nil
        end
    end
    load(0)
end

local states = {}
local rollStates = Enum and Enum.EncounterLootDropRollState
if rollStates then
    for name, choice in pairs({ NeedMainSpec = "need", NeedOffSpec = "need", Greed = "greed",
        Pass = "pass", Transmog = "transmog" }) do
        local state = rollStates[name]
        if type(state) == "number" then states[state] = choice end
    end
end

local function updateHistory(encounterID, lootKey)
    if not (history and rollStates) then return end
    local info = read(history.GetSortedInfoForDrop, encounterID, lootKey)
    if not info then return end
    local itemKey = key(plain(info.itemHyperlink))
    if not itemKey then return end
    local startTime = plain(info.startTime)
    local drop = findDrop(itemKey, function(row)
        return row.encounter == encounterID and row.lootKey == lootKey
    end) or findDrop(itemKey, function(row)
        if not recentRoll(row) or row.lootKey then return false end
        return type(startTime) ~= "number" or type(row.historyTime) ~= "number"
            or math.abs(startTime - row.historyTime) <= 3
    end)
    if not drop then return end
    drop.encounter, drop.lootKey = encounterID, lootKey
    local playerRoll = states[plain(info.playerRollState)]
    if playerRoll then drop.voted = playerRoll end
    local rolls = plain(info.rollInfos)
    if type(rolls) == "table" then
        for _, roll in ipairs(rolls) do
            roll = plain(roll)
            local name = roll and plain(roll.playerName)
            local choice = roll and states[plain(roll.state)]
            if type(name) == "string" and choice then
                drop.players[name] = { choice = choice, number = plain(roll.roll) }
            end
        end
    end
    local winner = plain(info.winner)
    if winner then drop.winner = plain(winner.playerName) end
    if plain(info.allPassed) == true then drop.allPassed = true end
    if drop.winner or drop.allPassed then drop.finishedAt = drop.finishedAt or GetTime() end
end

-- Compile the client's own localized loot strings, including reordered printf arguments.
local patterns = {}
local function pattern(global, kind, who, item, value)
    local template = _G[global]
    if type(template) ~= "string" then return end
    local tokens, captures, cursor = {}, {}, 1
    local function literal(str)
        return (str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
    end
    while true do
        local first, last, position, format = template:find("%%(%d*%$?)([sd])", cursor)
        if not first then break end
        tokens[#tokens + 1] = literal(template:sub(cursor, first - 1))
        tokens[#tokens + 1] = format == "d" and "(%d+)" or "(.+)"
        captures[#captures + 1] = tonumber(position:match("%d+")) or #captures + 1
        cursor = last + 1
    end
    tokens[#tokens + 1] = literal(template:sub(cursor))
    patterns[#patterns + 1] = { "^" .. table.concat(tokens) .. "$", captures, kind, who, item, value }
end

pattern("LOOT_ROLL_ROLLED_NEED", "need", 3, 2, 1)
pattern("LOOT_ROLL_ROLLED_GREED", "greed", 3, 2, 1)
pattern("LOOT_ROLL_ROLLED_DE", "disenchant", 3, 2, 1)
pattern("LOOT_ROLL_NEED", "need", 1, 2)
pattern("LOOT_ROLL_GREED", "greed", 1, 2)
pattern("LOOT_ROLL_PASSED", "pass", 1, 2)
pattern("LOOT_ROLL_NEED_SELF", "need", nil, 1)
pattern("LOOT_ROLL_GREED_SELF", "greed", nil, 1)
pattern("LOOT_ROLL_PASSED_SELF", "pass", nil, 1)
pattern("LOOT_ROLL_WON", "winner", 1, 2)
pattern("LOOT_ROLL_YOU_WON", "winner", nil, 1)
pattern("LOOT_ROLL_ALL_PASSED", "allPassed", nil, 1)

local function chatLoot(message)
    if type(message) ~= "string" then return end
    for _, parsed in ipairs(patterns) do
        local found = { message:match(parsed[1]) }
        if found[1] then
            local args = {}
            for index, slot in ipairs(parsed[2]) do args[slot] = found[index] end
            local kind, link, name = parsed[3], args[parsed[5]], args[parsed[4]] or read(UnitName, "player")
            if name then name = name:match("|Hplayer:([^:|]+)") or name end
            local value = tonumber(args[parsed[6]])
            local itemKey = key(link)
            if not itemKey then return end
            local drop = findDrop(itemKey, recentRoll)
            if not drop then return end
            if kind == "allPassed" then
                drop.allPassed = true
                drop.finishedAt = drop.finishedAt or GetTime()
            elseif name and kind == "winner" then
                drop.winner = drop.winner or name
                drop.finishedAt = drop.finishedAt or GetTime()
            elseif name then
                local previous = drop.players[name]
                if not previous or not previous.number or value then
                    drop.players[name] = { choice = kind, number = value }
                end
                if not parsed[4] or name == read(UnitName, "player") then drop.voted = kind end
            end
            return true
        end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "START_LOOT_ROLL", "CANCEL_LOOT_ROLL",
    "CANCEL_ALL_LOOT_ROLLS", "CHAT_MSG_LOOT", "LOOT_HISTORY_UPDATE_DROP", "PLAYER_ENTERING_WORLD" }) do
    suite.RegisterSupported(events, event)
end
events:SetScript("OnEvent", function(_, event, first, second)
    first, second = plain(first), plain(second)
    if event == "START_LOOT_ROLL" and type(first) == "number" then
        startRoll(first, second)
    elseif event == "CANCEL_LOOT_ROLL" and type(first) == "number" then
        pending[first] = nil
        local drop = byRoll[first]
        if drop then drop.closed, drop.finishedAt = true, drop.finishedAt or GetTime() end
    elseif event == "CANCEL_ALL_LOOT_ROLLS" then
        for _, drop in pairs(byRoll) do drop.closed, drop.finishedAt = true, drop.finishedAt or GetTime() end
        pending = {}
    elseif event == "CHAT_MSG_LOOT" then
        if not chatLoot(first) then return end
    elseif event == "LOOT_HISTORY_UPDATE_DROP" and type(first) == "number" and type(second) == "number" then
        updateHistory(first, second)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local active = read(GetActiveLootRollIDs)
        if type(active) == "table" then
            for _, id in ipairs(active) do
                id = plain(id)
                if type(id) == "number" then startRoll(id, read(GetLootRollTimeLeft, id), true) end
            end
        end
    end
    if loot.Refresh then loot.Refresh() end
end)
