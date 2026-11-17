local _, app = ...

local states = { login = false, entered = false, bagsLow = false }
local previousDeath, previousAFK, previousLevel
local recentQuests = {}
local idleTimer, idleToken = nil, 0
local idleWait = { 145, 110, 80 }
local readable = app.Readable
local pouch, soil, seeds = 11020, 11018, 11022
local pouchTimer, pouchRetryAt
local wildBuffs = {
    [1126] = true, [5232] = true, [6756] = true, [5234] = true, [8907] = true,
    [9884] = true, [9885] = true, [21849] = true, [21850] = true,
}

local function unitState(api)
    if not api then return end
    local ok, value = pcall(api, "player")
    if ok then
        value = readable(value)
        if type(value) == "boolean" then return value end
        if type(value) == "number" then return value > 0 end
    end
end

local function zoneName()
    local name = GetRealZoneText and readable(GetRealZoneText())
    if not name or name == "" then name = GetZoneText and readable(GetZoneText()) end
    return name
end

local function safeIdle()
    return not (InCombatLockdown and InCombatLockdown())
        and unitState(UnitIsDeadOrGhost) == false and unitState(UnitIsAFK) == false
        and not unitState(UnitOnTaxi) and (not GetUnitSpeed or readable(GetUnitSpeed("player")) == 0)
end

function app.RestartIdle()
    idleToken = idleToken + 1
    if idleTimer then idleTimer:Cancel(); idleTimer = nil end
    local settings = app.Profile()
    if not (states.entered and settings.show and settings.comments and settings.bubbles and C_Timer) then return end
    local token = idleToken
    local delay = idleWait[settings.frequency] + math.random(5, 30)
    local function wake()
        if token ~= idleToken then return end
        idleTimer = nil
        if safeIdle() then app.React("idle") end
        app.RestartIdle()
    end
    if C_Timer.NewTimer then idleTimer = C_Timer.NewTimer(delay, wake)
    elseif C_Timer.After then C_Timer.After(delay, wake) end
end

function app.ObserveTravel(travel)
    if not states.entered or travel.capacity <= 0 then return end
    local low = travel.free <= 4
    if low == states.bagsLow then return end
    states.bagsLow = low
    if low then app.React("bags", { free = travel.free })
    else app.CancelReaction("bags") end
end

local function retryPouchAt(readyAt)
    if pouchRetryAt == readyAt then return end
    if pouchTimer then pouchTimer:Cancel(); pouchTimer = nil end
    pouchRetryAt = readyAt
    if readyAt then
        pouchTimer = C_Timer.NewTimer(math.max(0.05, readyAt - GetTime()), function()
            pouchTimer, pouchRetryAt = nil, nil
            app.SecureCall("Immergrünbeutel", app.CheckEvergreenPouch)
        end)
    end
end

function app.CheckEvergreenPouch()
    if not states.entered or (InCombatLockdown and InCombatLockdown()) then return end
    if app.BagItemCount(pouch) < 1 or app.BagItemCount(soil) < 2 or app.BagItemCount(seeds) < 1 then
        retryPouchAt(nil)
        app.SetCompanionReminder("pouch")
        return
    end

    if not (C_Item and C_Item.GetItemCooldown) then return end
    local start, duration = C_Item.GetItemCooldown(pouch)
    start, duration = readable(start), readable(duration)
    if type(start) ~= "number" or type(duration) ~= "number" then return end
    local readyAt = start + duration
    if start > 0 and duration > 0 and readyAt > GetTime() then
        -- A short global cooldown should not hide an outstanding reminder.
        if duration > 3 then app.SetCompanionReminder("pouch") end
        retryPouchAt(readyAt + 0.05)
        return
    end
    retryPouchAt(nil)
    local usable = not C_Item.IsUsableItem or readable(C_Item.IsUsableItem(pouch)) == true
    app.SetCompanionReminder("pouch", usable and "Immergrünbeutel bereit." or nil)
end

local function hasWildBuff()
    local getAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not getAura then return end
    local unknown
    for index = 1, 255 do
        local aura = getAura("player", index, "HELPFUL")
        if issecretvalue and issecretvalue(aura) then return end
        if not aura then
            if not unknown then return false end
            return
        end
        local id = readable(aura.spellId)
        if id and wildBuffs[id] then return true end
        if not id then unknown = true end
    end
end

local function knowsWildBuff()
    local isKnown = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsPlayerSpell or IsSpellKnown
    if not isKnown then return true end
    for id in pairs(wildBuffs) do
        if readable(isKnown(id)) == true then return true end
    end
    return false
end

local function checkWildBuff()
    if not states.entered or not UnitClass or (InCombatLockdown and InCombatLockdown()) then return end
    local _, class = UnitClass("player")
    if readable(class) ~= "DRUID" or unitState(UnitIsDeadOrGhost) == true then
        app.SetCompanionReminder("mark")
        return
    end
    local active = hasWildBuff()
    if active ~= nil then
        app.SetCompanionReminder("mark", not active and knowsWildBuff() and "Mal der Wildnis fehlt." or nil)
    end
end

local function updateZone()
    local zone = zoneName()
    if app.VisitZone(zone) then app.React("zone", { zone = zone }) end
end

local function updateAFK(report)
    local value = unitState(UnitIsAFK)
    if value == nil or value == previousAFK then return end
    local changed = previousAFK ~= nil
    previousAFK = value
    app.CancelReaction(value and "back" or "afk")
    app.SetAFKMood(value)
    if report and changed then app.React(value and "afk" or "back") end
end

local function death()
    if previousDeath == true then return end
    previousDeath = true
    app.SetCompanionReminder("mark")
    app.CancelReaction("revive")
    local localDeaths, sessionDeaths = app.RememberDeath(zoneName())
    local special = localDeaths and localDeaths >= 2 and "repeatDeath"
        or sessionDeaths and sessionDeaths >= 3 and "sessionDeaths"
    app.React("death", { special = special })
end

local function checkAlive()
    if previousDeath and unitState(UnitIsDeadOrGhost) == false then
        previousDeath = false
        app.CancelReaction("death")
        app.React("revive")
        checkWildBuff()
    end
end

local handlers = {}
handlers.PLAYER_LOGIN = function()
    app.Profile()
    SLASH_PAULCHENQOLCOMPANION1 = "/paulchen"
    SLASH_PAULCHENQOLCOMPANION2 = "/pq"
    SlashCmdList.PAULCHENQOLCOMPANION = app.CompanionCommand
    app.BootCompanion()
end
handlers.PLAYER_ENTERING_WORLD = function(initial, reloaded)
    local first = not states.entered
    states.entered = true
    if first then
        previousDeath = unitState(UnitIsDeadOrGhost)
        previousLevel = UnitLevel and readable(UnitLevel("player"))
        app.RememberLevel(previousLevel)
        updateAFK(false)
        app.RestartIdle()
    end
    if readable(initial) == true and readable(reloaded) ~= true and not states.login then
        states.login = true
        local longPause = app.LogArrival(true)
        app.React("login", { special = longPause and "longPause" or nil })
    end
    updateZone()
    app.CheckEvergreenPouch()
    checkWildBuff()
end
handlers.PLAYER_LEVEL_UP = function(level)
    level = readable(level)
    if type(level) ~= "number" or level < 1 or (previousLevel and level <= previousLevel) then return end
    previousLevel = level
    app.RememberLevel(level)
    app.React("level", { level = level })
end
handlers.PLAYER_DEAD = death
handlers.PLAYER_ALIVE = checkAlive
handlers.PLAYER_UNGHOST = function()
    checkAlive()
    if previousDeath and C_Timer and C_Timer.After then C_Timer.After(0.3, checkAlive) end
end
handlers.ZONE_CHANGED_NEW_AREA = updateZone
handlers.QUEST_TURNED_IN = function(quest)
    quest = readable(quest)
    if type(quest) ~= "number" or quest <= 0 then return end
    local now = GetTime()
    for index = #recentQuests, 1, -1 do
        local recent = recentQuests[index]
        if now - recent.at >= 5 then table.remove(recentQuests, index)
        elseif quest == recent.id then return end
    end
    recentQuests[#recentQuests + 1] = { id = quest, at = now }
    app.RememberQuest()
    app.React("quest")
end
handlers.PLAYER_FLAGS_CHANGED = function(unit)
    if readable(unit) == "player" then
        updateAFK(true)
        checkAlive()
    end
end
handlers.UNIT_FLAGS = handlers.PLAYER_FLAGS_CHANGED
handlers.BAG_UPDATE_DELAYED = app.CheckEvergreenPouch
handlers.BAG_UPDATE_COOLDOWN = app.CheckEvergreenPouch
handlers.ITEM_DATA_LOAD_RESULT = function(id, success)
    if readable(id) == pouch and readable(success) then app.CheckEvergreenPouch() end
end
handlers.UNIT_AURA = function(unit)
    if readable(unit) == "player" then checkWildBuff() end
end
handlers.SPELLS_CHANGED = checkWildBuff
handlers.ADDON_RESTRICTION_STATE_CHANGED = checkWildBuff
handlers.PLAYER_REGEN_DISABLED = app.RefreshDialogue
handlers.PLAYER_REGEN_ENABLED = function()
    app.CheckEvergreenPouch()
    checkWildBuff()
    app.RefreshDialogue()
end

local frame = CreateFrame("Frame")
for event in pairs(handlers) do app.RegisterSupported(frame, event) end
frame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then app.SecureCall(event, handler, ...) end
end)
