local _, app = ...
app.bubbleDuration = 15

local rules = {
    login = { priority = 5, cooldown = 90, lifetime = 100, mood = "happy" },
    level = { priority = 10, cooldown = 3, lifetime = 120, mood = "excited" },
    death = { priority = 9, cooldown = 5, lifetime = 45, mood = "annoyed" },
    revive = { priority = 7, cooldown = 25, lifetime = 75, mood = "happy" },
    zone = { priority = 3, cooldown = 55, lifetime = 75 },
    quest = { priority = 5, cooldown = 35, lifetime = 100, mood = "happy" },
    afk = { priority = 6, cooldown = 30, lifetime = 75, mood = "tired" },
    back = { priority = 6, cooldown = 30, lifetime = 75, mood = "happy" },
    bags = { priority = 6, cooldown = 120, lifetime = 100 },
    idle = { priority = 1, cooldown = 95, lifetime = 15 },
    buffMissing = { priority = 4, cooldown = 120, lifetime = 15, mood = "annoyed" },
    buffReady = { priority = 4, cooldown = 120, lifetime = 15, mood = "happy" },
}
local images = { neutral = "idle", happy = "jubelt", excited = "jubelt", annoyed = "genervt", tired = "schlaeft" }
local intervals = { 90, 60, 45 }
local queued, cooldowns, sessionRecent = {}, {}, {}
local active, mood, moodAt, afk, globalAt = nil, "neutral", 0, false, 0
local timer, ticket = nil, 0

local function combat()
    return InCombatLockdown and InCombatLockdown()
end

local function willing()
    local settings = app.Profile()
    return settings.show and settings.comments and settings.bubbles
end

local function recent(key)
    for _, previous in ipairs(sessionRecent) do if previous == key then return true end end
    local data = app.Memory()
    if data then for _, previous in ipairs(data.recent) do if previous.key == key then return true end end end
    return false
end

local function selectLine(category, context, expression)
    local settings = app.Profile()
    local english = app.GetLanguage and app.GetLanguage() == "enUS"
    local lists = (english and app.DialogueEnglish and app.DialogueEnglish[category]) or app.Dialogue[category]
    local special = context and context.special
    if settings.sarcasm >= 2 and special and app.ContextLines[special] and not recent(special) then
        return (english and app.ContextLinesEnglish and app.ContextLinesEnglish[special]) or app.ContextLines[special], special
    end
    local first = (settings.sarcasm - 1) * 5
    -- Good moods favor a gentler delivery, even on the harsh setting.
    if expression == "happy" and settings.sarcasm == 3 and math.random(3) == 1 then first = 5 end
    local preferred, alternatives = {}, {}
    for index in ipairs(lists) do
        local key = category .. ":" .. index
        if index > first and index <= first + 5 then
            if not recent(key) then preferred[#preferred + 1] = index end
        elseif index <= first and not recent(key) then
            alternatives[#alternatives + 1] = index
        end
    end
    local choices = #preferred > 0 and preferred or alternatives
    local index
    if #choices > 0 then
        index = choices[math.random(#choices)]
    else
        -- If the entire tone was used recently, cycle back to its oldest line.
        local latest, rank = {}, 0
        for _, key in ipairs(sessionRecent) do rank = rank + 1; latest[key] = latest[key] or rank end
        local data = app.Memory()
        for _, entry in ipairs(data and data.recent or {}) do
            rank = rank + 1
            latest[entry.key] = latest[entry.key] or rank
        end
        local oldest = -1
        for i = first + 1, first + 5 do
            local age = latest[category .. ":" .. i] or math.huge
            if age > oldest then oldest, index = age, i end
        end
    end
    local text = lists[index]:gsub("{(%a+)}", function(key) return tostring(app.LocalizeContext(context and context[key]) or "?") end)
    return text, category .. ":" .. index
end

local function refresh()
    if app.RenderCompanion then app.SecureCall("Begleiter", app.RenderCompanion) end
end

local function cancelTimer()
    ticket = ticket + 1
    if timer then timer:Cancel(); timer = nil end
end

local pump
local function schedule(now, nextAt)
    if not nextAt or not C_Timer then return end
    local token = ticket
    local function wake()
        if token ~= ticket then return end
        timer = nil
        pump()
    end
    local delay = math.max(0.05, nextAt - now)
    if C_Timer.NewTimer then timer = C_Timer.NewTimer(delay, wake)
    elseif C_Timer.After then C_Timer.After(delay, wake) end
end

local function start(event, now)
    local expression = event.rule.mood or (afk and "tired" or mood)
    local text, key = selectLine(event.category, event.context, expression)
    active = { text = text, mood = expression, priority = event.rule.priority,
        untilAt = now + app.bubbleDuration }
    globalAt = now + intervals[app.Profile().frequency]
    cooldowns[event.category] = now + event.rule.cooldown
    table.insert(sessionRecent, 1, key)
    if #sessionRecent > 12 then table.remove(sessionRecent) end
    app.RememberComment(key, text)
    app.Debug("Dialog · " .. event.category)
end

pump = function()
    cancelTimer()
    local now = GetTime()
    if active and (active.untilAt <= now or combat() or not willing()) then active = nil end
    if moodAt > 0 and now >= moodAt then mood, moodAt = "neutral", 0 end
    local nextAt, best
    if active then nextAt = active.untilAt end
    if moodAt > 0 and (not nextAt or moodAt < nextAt) then nextAt = moodAt end
    for index = #queued, 1, -1 do
        local event = queued[index]
        if event.expires <= now or not willing() then
            table.remove(queued, index)
        elseif not combat() then
            local priority = event.rule.priority
            local important = priority >= 9
            local due = math.max(cooldowns[event.category] or 0, important and 0 or globalAt)
            if active and (not important or priority <= active.priority) then due = math.max(due, active.untilAt) end
            if due <= now and (not best or priority >= best.rule.priority) then
                best = event
            elseif due < event.expires and (not nextAt or due < nextAt) and due > now then
                nextAt = due
            end
        end
    end
    if best then
        for index, event in ipairs(queued) do
            if event == best then table.remove(queued, index); break end
        end
        start(best, now)
        nextAt = nextAt and math.min(nextAt, active.untilAt) or active.untilAt
    end
    refresh()
    schedule(now, nextAt)
end

function app.React(category, context)
    local rule = rules[category]
    if not rule then return end
    local now = GetTime()
    if rule.mood and not afk then
        mood, moodAt = rule.mood, now + (rule.priority >= 9 and 20 or 12)
    end
    if willing() and (category ~= "idle" or not combat()) then
        -- Replace pending notifications of the same kind and keep at most five.
        for index = #queued, 1, -1 do
            if queued[index].category == category then table.remove(queued, index) end
        end
        local event = { category = category, context = context, expires = now + rule.lifetime, rule = rule }
        queued[#queued + 1] = event
        if #queued > 5 then
            local weakest = 1
            for index = 2, #queued do
                if queued[index].rule.priority < queued[weakest].rule.priority then weakest = index end
            end
            table.remove(queued, weakest)
        end
    end
    pump()
end

function app.CancelReaction(category)
    for index = #queued, 1, -1 do
        if queued[index].category == category then table.remove(queued, index) end
    end
end

function app.SetAFKMood(value)
    afk = value
    if afk then app.CancelReaction("idle") end
    pump()
end

function app.DialogueView()
    local state = afk and "tired" or mood
    local expression = active and active.mood or state
    local art = active and expression == "neutral" and "redet" or images[expression]
    return art, active and active.text
end

function app.DialogueProfileChanged()
    pump()
end
app.RefreshDialogue = pump

function app.TestComment()
    local text = selectLine("idle", nil, "neutral")
    if not willing() or combat() then print("Paulchen QoL · " .. text); return end
    active = { text = text, mood = "neutral", priority = 1, untilAt = GetTime() + app.bubbleDuration }
    pump()
end
