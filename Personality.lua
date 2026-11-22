local _, app = ...
app.bubbleDuration = 15

local rules = {
    login = { priority = 5, cooldown = 90, mood = "happy" },
    level = { priority = 10, cooldown = 3, mood = "excited", afterCombat = true },
    death = { priority = 9, cooldown = 5, mood = "annoyed", afterCombat = true, family = "death" },
    repeatedDeath = { priority = 9, cooldown = 60, mood = "annoyed", afterCombat = true, family = "death" },
    revive = { priority = 7, cooldown = 25, mood = "happy", lifetime = 90, family = "death" },
    zone = { priority = 3, cooldown = 75, lifetime = 45, family = "zone" },
    repeatedZone = { priority = 4, cooldown = 600, lifetime = 45, family = "zone" },
    quest = { priority = 5, cooldown = 70, mood = "happy" },
    afk = { priority = 6, cooldown = 60, mood = "tired", lifetime = 60 },
    back = { priority = 6, cooldown = 60, mood = "happy", lifetime = 60 },
    bags = { priority = 6, cooldown = 300, family = "bags" },
    inventoryFull = { priority = 8, cooldown = 300, family = "bags" },
    bankOrganized = { priority = 5, cooldown = 180, family = "bags" },
    rareLoot = { priority = 4, cooldown = 480, mood = "happy", family = "loot" },
    valuableLoot = { priority = 5, cooldown = 360, mood = "happy", family = "loot" },
    dungeonFinished = { priority = 9, cooldown = 180, mood = "happy", afterCombat = true, family = "success" },
    afterSuccess = { priority = 8, cooldown = 120, mood = "happy", afterCombat = true, family = "success" },
    groupReady = { priority = 5, cooldown = 120, family = "group" },
    groupChaos = { priority = 4, cooldown = 180, family = "group" },
    buffMissing = { priority = 4, cooldown = 120, mood = "annoyed", family = "buff" },
    buffReady = { priority = 4, cooldown = 120, mood = "happy", family = "buff" },
    repairWarning = { priority = 8, cooldown = 1500, mood = "annoyed", setting = "repairHints", family = "repair" },
    repairCritical = { priority = 9, cooldown = 1500, mood = "annoyed", setting = "repairHints", family = "repair" },
    repairMerchant = { priority = 8, cooldown = 1500, mood = "neutral", setting = "repairHints", family = "repair" },
    repaired = { priority = 8, cooldown = 900, mood = "happy", setting = "repairHints", family = "repair" },
    sessionTime = { priority = 7, setting = "pauseHints", family = "pause" },
    sessionBreak = { priority = 7, setting = "pauseHints", family = "pause" },
}
for _, category in ipairs({ "idle", "ambient", "ambientCity", "ambientQuiet", "ambientTravel", "longIdle" }) do
    rules[category] = { priority = 1, cooldown = 120, setting = "ambientComments", ambient = true }
end

local images = { neutral = "idle", happy = "jubelt", excited = "jubelt", annoyed = "genervt", tired = "schlaeft" }
local intervals = { 75, 45, 30 }
local pending, cooldowns, familyAt, lineAt = {}, {}, {}, {}
local active, afterCombat, afk, globalAt, ambientAt = nil, nil, false, 0, 0
local expression
local timer, timerAt
local generation = 0

local function blocked()
    if app.CompanionDialogueBlocked then return app.CompanionDialogueBlocked() end
    return InCombatLockdown and app.ReadGameValue(InCombatLockdown) ~= false
end

local function willing(rule, preview)
    local settings = app.Profile()
    return settings.show and settings.comments and settings.bubbles
        and (preview or settings[rule.setting or "situationalComments"])
end

local function history()
    local keys, texts, order, lastAmbient = {}, {}, 0
    local current, saved = app.CommentHistory()
    local function collect(list)
        for _, entry in ipairs(list or {}) do
            if type(entry) == "table" and type(entry.key) == "string" and not keys[entry.key] and order < 40 then
                order = order + 1
                keys[entry.key] = order
                if type(entry.text) == "string" then texts[entry.text] = texts[entry.text] or order end
                local category = entry.category or entry.key:match("^([^:]+):")
                local rule = rules[category]
                if not lastAmbient and rule and rule.ambient then lastAmbient = category end
            end
        end
    end
    collect(current)
    collect(saved)
    local latest = current[1] or saved and saved[1]
    return keys, texts, active and active.text or type(latest) == "table" and latest.text, lastAmbient
end

local function readyAt(category, rule)
    local due = math.max(cooldowns[category] or 0, rule.priority >= 8 and 0 or globalAt)
    if rule.family and rule.priority < 8 and category ~= "revive" then
        due = math.max(due, familyAt[rule.family] or 0)
    end
    if active and (rule.priority < 8 or rule.priority <= active.priority) then due = math.max(due, active.untilAt) end
    return rule.ambient and math.max(due, ambientAt) or due
end

local function choice(category, context, now, force)
    local options = type(category) == "string" and { { category, 1 } } or category
    local keys, texts, lastText, lastAmbient = history()
    local fresh, total, oldest = {}, 0, nil
    local function consider(name, id, entry, weight)
        local data = type(entry) == "table" and entry or { text = entry }
        if data.needs and not context[data.needs] or data.hour and data.hour ~= context.hours then return end
        if data.cooldown and (lineAt[id] or -math.huge) + data.cooldown > now then return end
        local text = data.text:gsub("{(%a+)}", function(key) return tostring(context[key] or "?") end)
        if text == lastText or texts[text] == 1 then return end
        local candidate = { text = text, key = id, category = name, mood = data.mood, weight = weight * (data.weight or 1) }
        local age = math.min(keys[id] or math.huge, texts[text] or math.huge)
        if age == math.huge then
            total = total + candidate.weight
            fresh[#fresh + 1] = candidate
        elseif not oldest or age > oldest.age or age == oldest.age and candidate.weight > oldest.weight then
            candidate.age, oldest = age, candidate
        end
    end
    for _, option in ipairs(options) do
        local name = option[1]
        local rule, lines = rules[name], app.Dialogue[name]
        if rule and lines and (force or willing(rule) and readyAt(name, rule) <= now) then
            local special = context.special
            if special and app.ContextLines[special] and not keys[special] and not texts[app.ContextLines[special]]
                and (special == "longPause" or math.random() < 0.25) then
                return { text = app.ContextLines[special], key = special, category = name }
            end
            local weight = option[2] / #lines
            if name == lastAmbient then weight = weight * 0.45 end
            for index, entry in ipairs(lines) do consider(name, name .. ":" .. index, entry, weight) end
        end
    end
    if total == 0 then return oldest end
    local roll = math.random() * total
    for _, candidate in ipairs(fresh) do
        roll = roll - candidate.weight
        if roll <= 0 then return candidate end
    end
    return fresh[#fresh]
end

local function refresh()
    if app.RenderCompanion then app.SecureCall("Begleiter", app.RenderCompanion) end
end

local pump
local function schedule(now, due)
    if timerAt == due then return end
    generation = generation + 1
    if timer then timer:Cancel(); timer = nil end
    timerAt = due
    if not due or not C_Timer then return end
    local token = generation
    local function wake()
        if token ~= generation then return end
        timer, timerAt = nil, nil
        pump()
    end
    local delay = math.max(0.05, due - now)
    if C_Timer.NewTimer then timer = C_Timer.NewTimer(delay, wake)
    elseif C_Timer.After then C_Timer.After(delay, wake) end
end

local function start(line, now, preview)
    local rule = rules[line.category]
    local mood = not preview and (line.mood or rule.mood)
    local untilAt = now + app.bubbleDuration
    expression = mood and mood ~= "neutral" and { art = images[mood], untilAt = untilAt, priority = rule.priority } or nil
    active = { text = line.text, category = line.category, priority = rule.priority, untilAt = untilAt, preview = preview }
    cooldowns[line.category] = now + (rule.cooldown or 0)
    if rule.family then familyAt[rule.family] = now + 55 end
    globalAt = math.max(globalAt, now + intervals[app.Profile().frequency])
    if not rule.ambient then app.DelayCompanionAmbient(rule.priority >= 7 and 75 or 45) end
    lineAt[line.key] = now
    app.RememberComment(line.key, line.text, line.category, rule.ambient)
    app.Debug("Dialog · " .. line.category)
end

local function valid(event, now)
    return event.expires > now and willing(event.rule)
        and (not afk or event.category == "afk")
        and (not event.context.valid or event.context.valid())
end

pump = function()
    local now, quiet = GetTime(), blocked()
    if active and (quiet or active.untilAt <= now or not willing(rules[active.category], active.preview)
        or afk and active.category ~= "afk") then active = nil end
    if expression and (quiet or expression.untilAt <= now or not app.Profile().show) then expression = nil end
    if afterCombat then
        if not valid(afterCombat, now) then afterCombat = nil
        elseif not quiet then pending[#pending + 1], afterCombat = afterCombat, nil end
    end
    local nextAt, best = active and active.untilAt
    if expression then nextAt = math.min(nextAt or math.huge, expression.untilAt) end
    for index = #pending, 1, -1 do
        local event = pending[index]
        if quiet or not valid(event, now) then
            table.remove(pending, index)
        else
            local due = readyAt(event.category, event.rule)
            if due >= event.expires then
                table.remove(pending, index)
            elseif due <= now then
                if not best or event.rule.priority >= best.rule.priority then best = event end
            else
                nextAt = not nextAt and due or math.min(nextAt, due)
            end
        end
    end
    if best then
        for index, event in ipairs(pending) do
            if event == best then table.remove(pending, index); break end
        end
        local line = choice(best.category, best.context, now)
        if line then
            start(line, now)
            if best.context.onShown then best.context.onShown() end
        end
        local due = active and active.untilAt or now + 0.05
        nextAt = nextAt and math.min(nextAt, due) or due
    end
    refresh()
    schedule(now, nextAt)
end

function app.DelayCompanionAmbient(seconds)
    ambientAt = math.max(ambientAt, GetTime() + seconds)
end

function app.CompanionAmbientReadyAt()
    return math.max(globalAt, ambientAt, active and active.untilAt or 0)
end

function app.CompanionCommentNow(category, context)
    if blocked() or afk then return false end
    pump()
    local now = GetTime()
    local line = choice(category, context or {}, now)
    if not line then return false end
    start(line, now)
    pump()
    return line.category
end

function app.React(category, context)
    local rule = rules[category]
    if not rule or (afk and category ~= "afk") then return end
    local now = GetTime()
    if not willing(rule) then
        local settings = app.Profile()
        if settings.show and settings[rule.setting or "situationalComments"] and rule.mood and rule.mood ~= "neutral"
            and not blocked() and (not expression or rule.priority >= expression.priority) then
            expression = { art = images[rule.mood], untilAt = now + 8, priority = rule.priority }
            pump()
        end
        return
    end
    local event = { category = category, context = context or {}, rule = rule, expires = now + (rule.lifetime or 30) }
    if blocked() then
        if rule.afterCombat and app.CanHoldCompanionReaction and app.CanHoldCompanionReaction()
            and (not afterCombat or not valid(afterCombat, now) or rule.priority >= afterCombat.rule.priority) then
            afterCombat = event
        end
        return
    end
    app.CancelReaction(category)
    pending[#pending + 1] = event
    if #pending > 3 then
        local weakest = 1
        for index = 2, #pending do
            if pending[index].rule.priority < pending[weakest].rule.priority then weakest = index end
        end
        table.remove(pending, weakest)
    end
    pump()
end

function app.CancelReaction(category)
    for index = #pending, 1, -1 do
        if pending[index].category == category then table.remove(pending, index) end
    end
    if afterCombat and afterCombat.category == category then afterCombat = nil end
end

function app.ClearCompanionDialogue()
    pending, afterCombat, active, expression = {}, nil, nil, nil
    pump()
end

function app.SetAFKMood(value)
    afk = value
    if afk then app.ClearCompanionDialogue() else pump() end
end

function app.DialogueView()
    if blocked() then return afk and "schlaeft" or "idle" end
    local art = expression and expression.art or afk and "schlaeft" or active and "redet" or "idle"
    return art, active and active.text
end

app.DialogueProfileChanged = pump
app.RefreshDialogue = pump

function app.TestComment()
    local now = GetTime()
    local line = choice("ambient", {}, now, true)
    if not line then return end
    if not willing(rules.ambient, true) or blocked() or afk then print("Paulchen QoL · " .. line.text); return end
    start(line, now, true)
    pump()
end
