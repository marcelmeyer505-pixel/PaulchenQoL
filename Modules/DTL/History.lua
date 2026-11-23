local _, suite = ...
local addon = suite.timeline
if not addon then return end
local details = Details
local meter = details and details.DM or C_DamageMeter
local damageDone = Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone
local limit = 10
local liveRows = {}
local canMatchSavedRows = true

addon.limit = limit

local function readable(value, expectedType)
    return not issecretvalue(value) and type(value) == expectedType
end

local function number(value)
    if readable(value, "number") and value >= 0 and value < math.huge then
        return value
    end
end

local function text(value)
    if readable(value, "string") and value ~= "" then
        return value
    end
end

local function importDetailsHistory()
    local playerName = details:GetFullName("player")
    local playerGUID = UnitGUID("player")
    local history = {}

    for _, combat in ipairs(details:GetCombatSegments()) do
        local kind = combat:GetCombatType()
        if kind ~= DETAILS_SEGMENTTYPE_OVERALL and kind ~= DETAILS_SEGMENTTYPE_DUNGEON_OVERALL
            and kind ~= DETAILS_SEGMENTTYPE_MYTHICDUNGEON_OVERALL
            and kind ~= DETAILS_SEGMENTTYPE_MYTHICDUNGEON_TRASHOVERALL then
            local duration = number(combat:GetCombatTime())
            local damageActors = combat:GetActorList(DETAILS_ATTRIBUTE_DAMAGE)
            if duration and duration > 0 and (#damageActors > 0 or #combat:GetActorList(DETAILS_ATTRIBUTE_HEAL) > 0) then
                local actor = combat:GetActor(DETAILS_ATTRIBUTE_DAMAGE, playerName)
                if not actor and text(playerGUID) then
                    for _, candidate in ipairs(damageActors) do
                        if text(candidate.serial) == playerGUID then
                            actor = candidate
                            break
                        end
                    end
                end

                local damage = actor and number(actor.total) or nil
                local dps = actor and number(actor.last_dps) or nil
                if not dps or (dps == 0 and damage and damage > 0) then
                    dps = damage and damage / duration
                end
                local _, endTime = combat:GetDate()
                history[#history + 1] = {
                    id = number(combat.twinIdentifier),
                    detailsKey = text(combat.combatSessionId),
                    name = text(combat:GetCombatName(true, true)) or suite.L("Kampf"),
                    duration = duration,
                    damage = damage,
                    dps = dps,
                    endTime = text(endTime),
                }
                if #history == limit then
                    break
                end
            end
        end
    end
    return history
end

local function readFight(info, playerGUID)
    local id = number(info.sessionID)
    if not id or id == 0 then
        return
    end

    local segment = meter.GetCombatSessionFromID(id, damageDone)
    local duration = number(info.durationSeconds)
    local sources
    if readable(segment, "table") then
        sources = segment.combatSources
        duration = number(segment.durationSeconds) or duration
    end

    local name = text(info.name)
    local row = {
        id = id,
        native = true,
        meterName = name,
        name = name or (suite.L("Kampf #%d")):format(id),
        duration = duration,
    }

    if not readable(sources, "table") then
        return row, true
    end

    for _, source in ipairs(sources) do
        if readable(source, "table") then
            local localPlayer = source.isLocalPlayer
            local guid = text(source.sourceGUID)
            if (readable(localPlayer, "boolean") and localPlayer) or (playerGUID and guid == playerGUID) then
                row.damage = number(source.totalAmount)
                row.dps = number(source.amountPerSecond)
                if row.dps == 0 and row.damage ~= 0 then
                    row.dps = nil
                end
                if not row.dps and row.damage and duration and duration > 0 and not issecretvalue(source.amountPerSecond) then
                    row.dps = row.damage / duration
                end
                return row, row.dps == nil
            end
        end
    end
    return row, true
end

local function findSavedRow(history, row, used)
    for _, previous in ipairs(history) do
        if not used[previous] and previous.id == row.id then
            if previous.native then
                if previous.meterName == row.meterName and previous.duration == row.duration
                    and (not previous.damage or not row.damage or previous.damage == row.damage) then
                    return previous
                end
            elseif previous.detailsKey and row.meterName and previous.detailsKey == row.meterName .. row.id then
                return previous
            end
        end
    end
end

function addon.ResetMeterAssociation()
    liveRows = {}
    canMatchSavedRows = false
end

function addon.MigrateHistory(db)
    if db.historyVersion == 2 then
        return
    end
    -- Version 1 also recorded missing sources as zero damage.
    for index = #db.history, 1, -1 do
        local row = db.history[index]
        if row.dps == 0 and row.damage == 0 then
            if row.native then
                row.dps, row.damage = nil, nil
            else
                table.remove(db.history, index)
            end
        end
    end
    db.historyVersion = 2
end

function addon.RefreshHistory()
    if InCombatLockdown() or IsEncounterInProgress() or (details and details.ArePlayersInCombat and details:ArePlayersInCombat()) then
        return true
    end

    local history = PaulchenQoLTimelineDB.history
    if #history == 0 and details and details.GetCombatSegments and details.GetFullName then
        history = importDetailsHistory()
        PaulchenQoLTimelineDB.history = history
    end

    if not (meter and damageDone and meter.GetAvailableCombatSessions and meter.GetCombatSessionFromID) then return false end
    local sessions = meter.GetAvailableCombatSessions()
    if not readable(sessions, "table") or #sessions == 0 then
        return false
    end

    local newest, used, current = {}, {}, {}
    local pending = false
    local playerGUID = text(UnitGUID("player"))
    -- Details and Blizzard list the live meter's newest session at the end.
    for index = #sessions, math.max(1, #sessions - limit + 1), -1 do
        local row, needsData = readFight(sessions[index], playerGUID)
        if row then
            local previous = liveRows[row.id]
            if not previous and canMatchSavedRows then
                previous = findSavedRow(history, row, used)
            end
            if previous then
                used[previous] = true
                row.endTime = previous.endTime
                row.profileId = previous.profileId
                row.duration = row.duration or previous.duration
                if row.dps == nil then
                    row.dps = previous.dps
                    row.damage = row.damage or previous.damage
                end
            end
            if row.duration or row.dps then
                newest[#newest + 1] = row
                current[row.id] = row
            end
            pending = pending or needsData
        end
    end

    for _, previous in ipairs(history) do
        if #newest == limit then
            break
        end
        if not used[previous] then
            newest[#newest + 1] = previous
        end
    end

    liveRows = current
    canMatchSavedRows = false
    PaulchenQoLTimelineDB.history = newest
    return pending
end
