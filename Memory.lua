local _, app = ...

local memory, zone, session, clockStarted
local recentLimit, visitLimit = 40, 24
local sessionRecent, temporaryDeaths = {}, {}

local function nonnegative(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value or nil
end

local function prepend(list, entry, limit)
    table.insert(list, 1, entry)
    for i = #list, limit + 1, -1 do list[i] = nil end
end

local function timestamp()
    return app.ReadGameValue(GetServerTime)
end

function app.Memory()
    if not app.Profile().memory then return end
    if not memory then
        local db = app.Settings()
        if type(db.memory) ~= "table" then db.memory = {} end
        memory = db.memory
        for _, key in ipairs({ "levels", "places", "recent", "recentZones", "recentAmbient" }) do
            if type(memory[key]) ~= "table" then memory[key] = {} end
        end
        for _, key in ipairs({ "deaths", "sessionDeaths", "quests" }) do
            memory[key] = nonnegative(memory[key]) or 0
        end
    end
    return memory
end

function app.StartCompanionSession(initial, reloaded)
    if session then return session end
    local db, now = app.Settings(), GetTime()
    local previous = db.companionSession
    local resume = initial ~= true and reloaded == true and type(previous) == "table"
        and nonnegative(previous.elapsed) and nonnegative(previous.closedAt)
        and now >= previous.closedAt and now - previous.closedAt <= 300
    session = resume and previous or { elapsed = 0 }
    session.recentDeaths = type(session.recentDeaths) == "table" and session.recentDeaths or {}
    session.lastHour = nonnegative(session.lastHour) or 0
    session.closedAt, clockStarted = nil, now
    db.companionSession = session
    return session
end

function app.CompanionSession()
    if session then
        return session, session.elapsed + (clockStarted and math.max(0, GetTime() - clockStarted) or 0)
    end
end

function app.SaveCompanionSession()
    local data, elapsed = app.CompanionSession()
    if data then
        data.elapsed, data.closedAt, clockStarted = elapsed, GetTime(), nil
    end
end

function app.LogArrival(initialLogin)
    if initialLogin then
        local saved = app.Settings().memory
        if type(saved) == "table" then saved.sessionDeaths = 0 end
    end
    local data = app.Memory()
    if not data or not initialLogin then return end
    data.sessionDeaths = 0
    local now = timestamp()
    if not now then return end
    local longPause = nonnegative(data.lastLogin) and now - data.lastLogin >= 3 * 86400
    data.lastLogin = now
    return longPause
end

local function place(data, name)
    if not data or type(name) ~= "string" or name == "" then return end
    local entry = data.places[name]
    if type(entry) ~= "table" then entry = {}; data.places[name] = entry end
    entry.visits, entry.deaths = nonnegative(entry.visits) or 0, nonnegative(entry.deaths) or 0
    return entry
end

function app.VisitZone(name)
    if type(name) ~= "string" or name == "" or name == zone then return false end
    local changed = zone ~= nil
    zone = name
    local data = app.Memory()
    local entry = place(data, name)
    local remembered = entry and entry.visits > 0 and entry.deaths >= 2
    if entry and data.lastZone ~= name then
        entry.visits = entry.visits + 1
        data.lastZone = name
        prepend(data.recentZones, { name = name, at = timestamp() }, visitLimit)
    end
    return changed, remembered == true
end

function app.CurrentZone() return zone end

function app.RememberDeath(name)
    local data = app.Memory()
    local sessionData, elapsed = app.CompanionSession()
    local count
    if sessionData then
        local recent = data and sessionData.recentDeaths or temporaryDeaths
        for index = #recent, 1, -1 do
            local at = nonnegative(recent[index])
            if not at or elapsed < at or elapsed - at > 900 then table.remove(recent, index) end
        end
        prepend(recent, elapsed, 12)
        count = #recent
    end
    if not data then return nil, nil, count end
    data.deaths, data.sessionDeaths = data.deaths + 1, data.sessionDeaths + 1
    local entry = place(data, name or zone)
    if entry then entry.deaths = entry.deaths + 1 end
    return entry and entry.deaths or 0, data.sessionDeaths, count
end

function app.RememberLevel(level)
    local data = app.Memory()
    if data and nonnegative(level) and level > 0 then data.levels[level] = true end
end

function app.RememberQuest()
    local data = app.Memory()
    if data then data.quests = data.quests + 1 end
end

function app.CommentHistory()
    local data = app.Memory()
    return sessionRecent, data and data.recent
end

function app.RememberComment(key, text, category, ambient)
    local entry = { key = key, text = text, category = category, at = timestamp() }
    prepend(sessionRecent, entry, recentLimit)
    local data = app.Memory()
    if data then
        prepend(data.recent, entry, recentLimit)
        if ambient then prepend(data.recentAmbient, entry, 12) end
    end
end
