local _, app = ...
local life = {}
app.companionLife = life

local read = app.ReadGameValue
local world, loading, fighting, encounter = false, false, false, false
local ranges = { { 300, 480 }, { 180, 360 }, { 100, 210 } }
local repairCooldown, idleAfter, hourWindow = 1500, 480, 600
local timer, timerAt, ambientDue, lastActivity, idleSpoken
local timerGeneration = 0
local lowBags, freeBags
local repairAtMerchant, previousDamage, previousEquipment, merchantVisit
local readyCheck

local function active(api, ...)
    return type(api) == "function" and read(api, ...) ~= false
end

local function restricted(kind)
    local api, types = C_RestrictedActions, Enum and Enum.AddOnRestrictionType
    local value = types and types[kind]
    if not api or value == nil then return false end
    if api.GetAddOnRestrictionState then
        return read(api.GetAddOnRestrictionState, value) ~= (Enum.AddOnRestrictionState and Enum.AddOnRestrictionState.Inactive or 0)
    end
    return active(api.IsAddOnRestrictionActive, value)
end

function app.CompanionDialogueBlocked()
    return not world or loading or fighting or encounter or active(InCombatLockdown)
        or active(UnitAffectingCombat, "player") or active(IsEncounterInProgress)
        or restricted("Combat") or restricted("Encounter") or restricted("PvP")
end

function app.CanHoldCompanionReaction()
    return world and not loading
end

local function usable()
    return not app.CompanionDialogueBlocked() and not active(UnitIsAFK, "player") and not active(UnitIsDeadOrGhost, "player")
end

local function enabled(settings)
    return settings.show and settings.comments and settings.bubbles
end

function life.Activity()
    lastActivity, idleSpoken = GetTime(), false
end

local function nextAmbient(now, frequency)
    local timing = ranges[frequency]
    return now + math.random(timing[1], timing[2])
end

local function ambient(now)
    local speed = read(GetUnitSpeed, "player")
    local flying = read(UnitOnTaxi, "player") == true or read(IsFlying) == true
    local mounted = read(IsMounted) == true and not flying
    local travelling = flying or mounted or type(speed) == "number" and speed > 0
    local resting = read(IsResting) == true
    if travelling then life.Activity() end
    local choices = { { "ambient", 8 } }
    if travelling then
        choices[#choices + 1] = { "ambientTravel", 15 }
    elseif speed == 0 then
        choices[#choices + 1] = { "ambientQuiet", 6 }
        choices[#choices + 1] = { "idle", 6 }
        if not idleSpoken and lastActivity and now - lastActivity >= idleAfter then
            choices[#choices + 1] = { "longIdle", 12 }
        end
    end
    if resting then choices[#choices + 1] = { "ambientCity", 15 } end
    local category = app.CompanionCommentNow(choices, { flying = flying, mounted = mounted })
    if category == "longIdle" then idleSpoken = true end
end

local function lastRepair(session)
    local at = type(session.repairWarningAt) == "number" and session.repairWarningAt or -repairCooldown
    local severity = type(session.repairSeverity) == "number" and session.repairSeverity or 0
    return at, severity
end

local function recordRepairWarning(session, elapsed, severity)
    session.repairWarningAt, session.repairSeverity = elapsed, severity
    local data = app.Memory()
    if data then data.lastRepairWarning = { at = read(GetServerTime), severity = severity } end
end

local function repairWarning(session, elapsed)
    local durability = app.ReadDurability()
    if not durability or durability >= 40 then return end
    local severity = durability < 20 and 2 or 1
    local previous, previousSeverity = lastRepair(session)
    if previous + repairCooldown > elapsed and severity <= previousSeverity then
        return previous + repairCooldown - elapsed
    end
    local category = severity == 2 and "repairCritical" or "repairWarning"
    if app.CompanionCommentNow(category) then
        recordRepairWarning(session, elapsed, severity)
        return repairCooldown
    end
    -- A message already on screen can take priority. Recheck the real durability before speaking.
    return 45
end

local function hourReminder(session, elapsed)
    local hour = math.floor(elapsed / 3600)
    if hour > 4 then hour = hour - hour % 2 end
    local nextHour = hour < 4 and hour + 1 or hour + 2
    local seconds = elapsed - hour * 3600
    if hour > session.lastHour and hour > 0 and seconds < hourWindow then
        local milestone = hour == 1 and "sessionTime" or "sessionBreak"
        if app.CompanionCommentNow(milestone, { hours = hour, extended = hour > 4 }) then
            session.lastHour = hour
        else
            return math.min(45, hourWindow - seconds)
        end
    end
    return nextHour * 3600 - elapsed
end

local function schedule(at)
    if timerAt == at then return end
    timerGeneration = timerGeneration + 1
    if timer then timer:Cancel(); timer = nil end
    timerAt = at
    if not at or not C_Timer then return end
    local token = timerGeneration
    local function wake()
        if token ~= timerGeneration then return end
        timer, timerAt = nil, nil
        life.Update()
    end
    local delay = math.max(0.05, at - GetTime())
    if C_Timer.NewTimer then timer = C_Timer.NewTimer(delay, wake)
    elseif C_Timer.After then C_Timer.After(delay, wake) end
end

function life.Update(resetAmbient)
    local settings = app.Profile()
    if not enabled(settings) or not usable() then
        ambientDue = nil
        schedule(nil)
        return
    end
    local now, nextAt = GetTime()
    local session, elapsed = app.CompanionSession()
    local function consider(delay)
        if delay then nextAt = math.min(nextAt or math.huge, now + delay) end
    end
    if session and settings.repairHints and not repairAtMerchant then consider(repairWarning(session, elapsed)) end
    if session and settings.pauseHints then consider(hourReminder(session, elapsed)) end
    if settings.ambientComments then
        if resetAmbient or not ambientDue then ambientDue = nextAmbient(now, settings.frequency) end
        if ambientDue <= now then
            local quietUntil = app.CompanionAmbientReadyAt()
            if quietUntil > now then ambientDue = quietUntil
            else
                ambient(now)
                ambientDue = nextAmbient(now, settings.frequency)
            end
        end
        nextAt = math.min(nextAt or math.huge, ambientDue)
    else ambientDue = nil end
    schedule(nextAt)
end

function life.Enter(initial, reloaded)
    world, fighting, encounter = true, false, false
    app.StartCompanionSession(initial, reloaded)
    life.Activity()
end

function life.Leave()
    world, fighting, encounter = false, false, false
    repairAtMerchant, previousDamage, previousEquipment, merchantVisit, readyCheck = nil, nil, nil, nil, nil
    app.ClearCompanionDialogue()
    life.Update(true)
end

function life.Loading(value)
    loading = value
    if value then app.ClearCompanionDialogue() else life.Activity() end
end

function life.Combat(value)
    fighting = value
    life.Activity()
    app.RefreshDialogue()
    life.Update(true)
end

function life.ObserveBags(free, capacity, known)
    if not world then return end
    if not known or capacity <= 0 then
        freeBags = nil
        app.CancelReaction("bags")
        app.CancelReaction("inventoryFull")
        return
    end
    local state = free == 0 and "inventoryFull" or free <= 4 and "bags" or nil
    if state == lowBags and free == freeBags then return end
    freeBags = free
    app.CancelReaction("bags")
    app.CancelReaction("inventoryFull")
    if not usable() then lowBags = nil; return end
    lowBags = state
    if state then
        app.React(state, { free = free, valid = function() return freeBags == free and lowBags == state end })
    end
end

function life.Merchant(open)
    life.Activity()
    merchantVisit = open and {} or nil
    repairAtMerchant = open and read(CanMerchantRepair) == true
    previousDamage, previousEquipment = nil, nil
    if repairAtMerchant and usable() then
        local minimum, damage, equipment = app.ReadDurability(true)
        previousDamage, previousEquipment = damage, equipment
        local session, elapsed = app.CompanionSession()
        local previous, priorSeverity = lastRepair(session or {})
        local severity = minimum and (minimum < 20 and 2 or minimum < 40 and 1 or 0) or 0
        if session and damage and damage > 0 and (elapsed >= previous + repairCooldown or severity > priorSeverity) then
            local visit = merchantVisit
            app.React("repairMerchant", { valid = function()
                return visit == merchantVisit and previousDamage and previousDamage > 0 and read(CanMerchantRepair) == true
            end, onShown = function()
                local current, played = app.CompanionSession()
                if current then recordRepairWarning(current, played, severity) end
            end })
        end
    end
    life.Update()
end

function life.DurabilityChanged(equipmentChanged)
    if not usable() then return end
    if repairAtMerchant then
        local _, damage, equipment = app.ReadDurability(true)
        if not equipmentChanged and equipment and equipment == previousEquipment and damage and previousDamage
            and damage < previousDamage and read(CanMerchantRepair) == true then
            app.CancelReaction("repairMerchant")
            app.React("repaired")
        end
        previousDamage, previousEquipment = damage, equipment
    end
    life.Update()
end

function life.Encounter(started, success)
    encounter = started
    life.Activity()
    if not started and (success == 1 or success == true) then app.React("afterSuccess") end
    app.RefreshDialogue()
    life.Update(true)
end

function life.DungeonFinished()
    local inside, kind = read(IsInInstance)
    if inside == true and kind == "party" then
        app.CancelReaction("afterSuccess")
        app.React("dungeonFinished")
    end
end

function life.BankOrganized()
    life.Activity()
    app.React("bankOrganized")
end

local function status(value)
    if value == "ready" or value == true or value == 1 then return "ready" end
    if value == "notready" or value == false or value == 0 then return "notready" end
end

function life.ReadyCheck()
    readyCheck = nil
    local count, raid = read(GetNumGroupMembers), read(IsInRaid)
    if not usable() or type(count) ~= "number" or not (count >= 2 and count <= 40 and count % 1 == 0)
        or type(raid) ~= "boolean" then return end
    local members = {}
    for index = 1, count do
        local unit = raid and ("raid" .. index) or index == 1 and "player" or ("party" .. (index - 1))
        local guid = read(UnitGUID, unit)
        if type(guid) ~= "string" or guid == "" or members[guid] then return end
        members[guid] = status(read(GetReadyCheckStatus, unit)) or "waiting"
    end
    readyCheck = members
end

function life.ReadyConfirmed(unit, result)
    if not readyCheck or type(unit) ~= "string" then return end
    local guid, value = read(UnitGUID, unit), status(result)
    if guid and readyCheck[guid] and value then readyCheck[guid] = value end
end

function life.ReadyFinished()
    if not readyCheck then return end
    local ready, unready, count = 0, 0, 0
    for _, value in pairs(readyCheck) do
        count = count + 1
        if value == "ready" then ready = ready + 1 elseif value == "notready" then unready = unready + 1 end
    end
    readyCheck = nil
    if not usable() then return end
    if ready == count then app.React("groupReady")
    elseif unready >= 2 then app.React("groupChaos", { unready = unready }) end
end

function life.RosterChanged() readyCheck = nil end

local lootFormats
local lastLoot, lastLootAt
local function lootPatterns()
    local result = {}
    for _, format in ipairs({ LOOT_ITEM_SELF_MULTIPLE or false, LOOT_ITEM_SELF or false }) do
        if type(format) == "string" then
            local pattern = format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            pattern = pattern:gsub("%%%%%d+%%%$s", "(.+)", 1):gsub("%%%%s", "(.+)", 1)
            pattern = pattern:gsub("%%%%%d+%%%$d", "(%%d+)"):gsub("%%%%d", "(%%d+)")
            result[#result + 1] = "^" .. pattern .. "$"
        end
    end
    return result
end

function life.Loot(message)
    local settings = app.Profile()
    if not enabled(settings) or not settings.situationalComments or not usable() or type(message) ~= "string" then return end
    local now = GetTime()
    if message == lastLoot and now - lastLootAt < 2 then return end
    lootFormats = lootFormats or lootPatterns()
    local link, quantity
    for _, pattern in ipairs(lootFormats) do
        local first, second = message:match(pattern)
        if first then
            if tonumber(first) then first, second = second, first end
            link, quantity = first, tonumber(second) or 1
            break
        end
    end
    local id, name
    if link then id, name = link:match("|Hitem:(%d+)[^|]*|h%[(.-)%]|h") end
    if not id then return end
    lastLoot, lastLootAt = message, now
    local info = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not info then return end
    local ok, _, _, quality, _, _, _, _, _, _, _, _, _, _, bind = pcall(info, link)
    if not ok then return end
    quality, bind = app.Readable(quality), app.Readable(bind)
    local price, source
    if app.GetAuctionPrice and (bind == 0 or bind == 2) then
        local readPrice, amount, origin = pcall(app.GetAuctionPrice, link, tonumber(id))
        if readPrice then price, source = app.Readable(amount), app.Readable(origin) end
    end
    life.Activity()
    if (source == "TSM_DBMarket" or source == "PAULCHEN_SCAN") and type(price) == "number" and price < math.huge
        and price * quantity >= 200000 then
        app.React("valuableLoot", { item = name })
    elseif type(quality) == "number" and quality >= 3 then
        app.React("rareLoot", { item = name })
    end
end
