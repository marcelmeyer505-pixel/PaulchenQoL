local _, app = ...

local memory, zone
local recentLimit = 12

function app.Memory()
    if not app.Profile().memory then return end
    if not memory then
        local db = app.Settings()
        if type(db.memory) ~= "table" then db.memory = {} end
        memory = db.memory
        for _, key in ipairs({ "levels", "places", "recent" }) do
            if type(memory[key]) ~= "table" then memory[key] = {} end
        end
        for _, key in ipairs({ "deaths", "sessionDeaths", "quests" }) do
            if type(memory[key]) ~= "number" then memory[key] = 0 end
        end
    end
    return memory
end

function app.LogArrival(initialLogin)
    local data = app.Memory()
    if not data or not initialLogin then return end
    data.sessionDeaths = 0
    local now = GetServerTime and app.Readable(GetServerTime())
    if not now then return end
    local longPause = type(data.lastLogin) == "number" and now - data.lastLogin >= 3 * 86400
    data.lastLogin = now
    return longPause
end

local function place(name)
    local data = app.Memory()
    if not data or not name then return end
    if not data.places[name] then data.places[name] = { visits = 0, deaths = 0 } end
    return data.places[name]
end

function app.VisitZone(name)
    if type(name) ~= "string" or name == "" or name == zone then return false end
    local changed = zone ~= nil
    zone = name
    local data = app.Memory()
    if data and data.lastZone ~= name then
        local entry = place(name)
        entry.visits = entry.visits + 1
        data.lastZone = name
    end
    return changed
end

function app.CurrentZone() return zone end

function app.RememberDeath(name)
    local data = app.Memory()
    if not data then return end
    data.deaths, data.sessionDeaths = data.deaths + 1, data.sessionDeaths + 1
    local entry = place(name or zone)
    if entry then entry.deaths = entry.deaths + 1 end
    return entry and entry.deaths or 0, data.sessionDeaths
end

function app.RememberLevel(level)
    local data = app.Memory()
    if data and type(level) == "number" and level > 0 then data.levels[level] = true end
end

function app.RememberQuest()
    local data = app.Memory()
    if data then data.quests = data.quests + 1 end
end

function app.RememberComment(key, text)
    local data = app.Memory()
    if not data then return end
    table.insert(data.recent, 1, { key = key, text = text, at = GetServerTime and app.Readable(GetServerTime()) or nil })
    for i = #data.recent, recentLimit + 1, -1 do data.recent[i] = nil end
end
