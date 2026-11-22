local _, app = ...

local states = { login = false, entered = false }
local previousDeath, previousAFK, previousLevel
local welcome
local recentQuests = {}
local readable = app.Readable
local life = app.companionLife
local pouch, soil, seeds = 11020, 11018, 11022
local pouchTimer, pouchRetryAt
local wildBuffs = {
    [1126] = true, [5232] = true, [6756] = true, [5234] = true, [8907] = true,
    [9884] = true, [9885] = true, [21849] = true, [21850] = true,
}

local levelUpSound = "Interface\\AddOns\\PaulchenQoL\\Sounds\\level-up.mp3"
local stockLevelUpSound = 569593 -- sound/spells/levelup.ogg
local stockSoundMuted = false

function app.ApplyLevelUpSound()
    if app.Profile().levelUpSound and PlaySoundFile and MuteSoundFile then
        local ok = pcall(MuteSoundFile, stockLevelUpSound)
        stockSoundMuted = ok
    elseif stockSoundMuted and UnmuteSoundFile then
        if pcall(UnmuteSoundFile, stockLevelUpSound) then stockSoundMuted = false end
    end
end

function app.PlayLevelUpSound()
    if not PlaySoundFile then return false end
    local ok, playing = pcall(PlaySoundFile, levelUpSound, "SFX")
    if ok and readable(playing) then return true end
    if stockSoundMuted and UnmuteSoundFile then
        if pcall(UnmuteSoundFile, stockLevelUpSound) then stockSoundMuted = false end
    end
    return false
end

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
    local name = app.ReadGameValue(GetRealZoneText)
    if not name or name == "" then name = app.ReadGameValue(GetZoneText) end
    return name
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
    -- BuffCheck owns this same reminder key when installed. Keep the old
    -- implementation only as a compatibility fallback, never a second watcher.
    if app.buffCheck then return end
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
    local changed, remembered = app.VisitZone(zone)
    life.Activity()
    if changed then
        app.CancelReaction("zone")
        app.CancelReaction("repeatedZone")
        app.React(remembered and "repeatedZone" or "zone", { zone = zone, valid = function() return app.CurrentZone() == zone end })
    end
end

local function updateAFK(report)
    local value = unitState(UnitIsAFK)
    if value == nil or value == previousAFK then return end
    local changed = previousAFK ~= nil
    previousAFK = value
    app.CancelReaction(value and "back" or "afk")
    app.SetAFKMood(value)
    life.Activity()
    life.Update(true)
    if report and changed then app.React(value and "afk" or "back") end
end

local function death()
    if previousDeath == true then return end
    previousDeath = true
    app.SetCompanionReminder("mark")
    app.CancelReaction("revive")
    local localDeaths, sessionDeaths, recentDeaths = app.RememberDeath(zoneName())
    local special = localDeaths and localDeaths >= 2 and "repeatDeath"
        or sessionDeaths and sessionDeaths >= 3 and "sessionDeaths"
    app.React(recentDeaths and recentDeaths >= 3 and "repeatedDeath" or "death", { special = special })
    life.Update(true)
end

local function checkAlive()
    if previousDeath and unitState(UnitIsDeadOrGhost) == false then
        previousDeath = false
        app.CancelReaction("death")
        app.CancelReaction("repeatedDeath")
        app.React("revive")
        life.Activity()
        life.Update(true)
        checkWildBuff()
    end
end

local handlers = {}
local function greet()
    if welcome and not app.CompanionDialogueBlocked() then
        if GetTime() < welcome.untilAt then app.React("login", welcome) end
        welcome = nil
    end
end

handlers.PLAYER_LOGIN = function()
    app.Profile()
    app.ApplyLevelUpSound()
    SLASH_PAULCHENQOLCOMPANION1 = "/paulchen"
    SLASH_PAULCHENQOLCOMPANION2 = "/pq"
    SlashCmdList.PAULCHENQOLCOMPANION = app.CompanionCommand
    app.BootCompanion()
end
handlers.PLAYER_LOGOUT = function()
    app.SaveCompanionSession()
    if stockSoundMuted and UnmuteSoundFile then
        if pcall(UnmuteSoundFile, stockLevelUpSound) then stockSoundMuted = false end
    end
end
handlers.PLAYER_ENTERING_WORLD = function(initial, reloaded)
    initial, reloaded = readable(initial), readable(reloaded)
    local first = not states.entered
    states.entered = true
    life.Enter(initial, reloaded)
    if first then
        previousDeath = unitState(UnitIsDeadOrGhost)
        previousLevel = UnitLevel and readable(UnitLevel("player"))
        app.RememberLevel(previousLevel)
        updateAFK(false)
    end
    if initial == true and reloaded ~= true and not states.login then
        states.login = true
        local longPause = app.LogArrival(true)
        welcome = { special = longPause and "longPause" or nil, untilAt = GetTime() + 120 }
    end
    greet()
    updateZone()
    app.CheckEvergreenPouch()
    checkWildBuff()
    app.RefreshDialogue()
    life.Update(true)
    life.ObserveBags(app.ReadBagSpace())
end
handlers.PLAYER_LEAVING_WORLD = life.Leave
handlers.LOADING_SCREEN_ENABLED = function()
    life.Loading(true)
    life.Update(true)
end
handlers.LOADING_SCREEN_DISABLED = function()
    life.Loading(false)
    greet()
    life.Update(true)
    life.ObserveBags(app.ReadBagSpace())
end
handlers.PLAYER_LEVEL_UP = function(level)
    level = readable(level)
    if type(level) ~= "number" or level < 1 or (previousLevel and level <= previousLevel) then return end
    previousLevel = level
    app.RememberLevel(level)
    life.Activity()
    if app.Profile().levelUpSound then app.PlayLevelUpSound() end
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
    life.Activity()
    app.React("quest")
end
handlers.PLAYER_FLAGS_CHANGED = function(unit)
    if readable(unit) == "player" then
        updateAFK(true)
        checkAlive()
    end
end
handlers.UNIT_FLAGS = handlers.PLAYER_FLAGS_CHANGED
handlers.BAG_UPDATE_DELAYED = function()
    app.CheckEvergreenPouch()
    life.ObserveBags(app.ReadBagSpace())
end
handlers.BAG_UPDATE_COOLDOWN = app.CheckEvergreenPouch
handlers.ITEM_DATA_LOAD_RESULT = function(id, success)
    if readable(id) == pouch and readable(success) then app.CheckEvergreenPouch() end
end
handlers.UNIT_AURA = function(unit)
    if readable(unit) == "player" then checkWildBuff() end
end
handlers.SPELLS_CHANGED = checkWildBuff
handlers.ADDON_RESTRICTION_STATE_CHANGED = function()
    checkWildBuff()
    app.RefreshDialogue()
    life.Update()
end
handlers.PLAYER_REGEN_DISABLED = function() life.Combat(true) end
handlers.PLAYER_REGEN_ENABLED = function()
    app.CheckEvergreenPouch()
    checkWildBuff()
    life.Combat(false)
    life.ObserveBags(app.ReadBagSpace())
end
handlers.MERCHANT_SHOW = function() life.Merchant(true) end
handlers.MERCHANT_CLOSED = function() life.Merchant(false) end
handlers.UPDATE_INVENTORY_DURABILITY = function() life.DurabilityChanged(false) end
handlers.PLAYER_EQUIPMENT_CHANGED = function() life.DurabilityChanged(true) end
handlers.PLAYER_STARTED_MOVING = life.Activity
handlers.PLAYER_STOPPED_MOVING = life.Activity
handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit)
    if readable(unit) == "player" then life.Activity() end
end
handlers.CHAT_MSG_LOOT = function(message) life.Loot(readable(message)) end
handlers.ENCOUNTER_START = function() life.Encounter(true) end
handlers.ENCOUNTER_END = function(_, _, _, _, success) life.Encounter(false, readable(success)) end
handlers.LFG_COMPLETION_REWARD = life.DungeonFinished
handlers.GROUP_ROSTER_UPDATE = life.RosterChanged
handlers.READY_CHECK = life.ReadyCheck
handlers.READY_CHECK_CONFIRM = function(unit, ready) life.ReadyConfirmed(readable(unit), readable(ready)) end
handlers.READY_CHECK_FINISHED = life.ReadyFinished

local frame = CreateFrame("Frame")
for event in pairs(handlers) do
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" or not frame.RegisterUnitEvent
        or not pcall(frame.RegisterUnitEvent, frame, event, "player") then
        app.RegisterSupported(frame, event)
    end
end
frame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then app.SecureCall(event, handler, ...) end
end)
