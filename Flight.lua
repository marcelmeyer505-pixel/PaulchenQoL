local _, app = ...

if not (UnitOnTaxi and GetServerTime and C_Timer and C_Timer.After) then
    app.FlightInfo = function() end
    return
end

local flightSpeed, stopTime = 30, 2
local minDuration, maxDuration = 5, 3600
local nodes, origin, picked, flying = {}, nil, nil, nil
local routeTimings = {}
local db, boardingUntil, groundedAt, lastDisplay

local readable = app.Readable

local function validTime(seconds)
    return type(seconds) == "number" and seconds >= minDuration and seconds <= maxDuration
end

local function onTaxi()
    return UnitOnTaxi and readable(UnitOnTaxi("player")) == true
end

local function worldPosition(map, position)
    if not (map and position and C_Map and C_Map.GetWorldPosFromMapPos) then return end
    local ok, continent, point = pcall(C_Map.GetWorldPosFromMapPos, map, position)
    if not ok then return end
    point = readable(point)
    if not point then return end
    local x, y = readable(point.x), readable(point.y)
    continent = readable(continent)
    if continent and x and y then return { continent = continent, x = x, y = y } end
end

local function distance(a, b)
    if not (a and b) or a.continent ~= b.continent then return end
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

local function readTaxiMap()
    nodes, origin = {}, nil
    routeTimings = {}
    local map = GetTaxiMapID and readable(GetTaxiMapID())
    local result = {}
    if map and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
        local ok, value = pcall(C_TaxiMap.GetAllTaxiNodes, map)
        if ok and type(value) == "table" then result = value end
    end
    for _, info in ipairs(result) do
        if info.slotIndex and info.slotIndex > 0 then
            nodes[info.slotIndex] = { id = info.nodeID, name = info.name, position = worldPosition(map, info.position) }
        end
    end
    if NumTaxiNodes and TaxiNodeName and TaxiNodeGetType then
        for index = 1, readable(NumTaxiNodes()) or 0 do
            local name = readable(TaxiNodeName(index))
            if name and name ~= "" then nodes[index] = nodes[index] or { name = name } end
            if readable(TaxiNodeGetType(index)) == "CURRENT" then origin = nodes[index] end
        end
    end
    if not origin and Enum and Enum.FlightPathState and Enum.FlightPathState.Current then
        for _, info in ipairs(result) do
            if info.state == Enum.FlightPathState.Current then origin = nodes[info.slotIndex]; break end
        end
    end
end

local function taxiDestination(slot)
    local node = nodes[slot]
    if node then return node end
    local name = TaxiNodeName and readable(TaxiNodeName(slot))
    if name and name ~= "" then return { name = name } end
end

local function routeKey(from, to)
    if not (from and to) then return end
    if from.id and to.id then return ("%d>%d"):format(from.id, to.id) end
    if from.name and to.name then return from.name:lower() .. ">" .. to.name:lower() end
end

local function flightEstimate(slot, destination)
    local hops = GetNumRoutes and readable(GetNumRoutes(slot))
    if hops and hops > 0 and TaxiGetNodeSlot then
        local seconds = 0
        for leg = 1, hops do
            local from = nodes[readable(TaxiGetNodeSlot(slot, leg, true))]
            local to = nodes[readable(TaxiGetNodeSlot(slot, leg, false))]
            local yards = distance(from and from.position, to and to.position)
            if not yards then seconds = nil; break end
            seconds = seconds + yards / flightSpeed + stopTime
        end
        if validTime(seconds) then return seconds end
    end
    local yards = distance(origin and origin.position, destination.position)
    local seconds = yards and yards / flightSpeed + stopTime
    if validTime(seconds) then return seconds end
end

local function routeTiming(slot, destination, key)
    local learned = key and db.flightTimes[key]
    if validTime(learned) then return learned, false end
    local cached = routeTimings[slot]
    if cached then return cached.duration, cached.estimate end

    local duration, estimated
    local maps = Polestar and Polestar.Maps
    if maps and maps.FlightSeconds then
        local ok, seconds, source = pcall(maps.FlightSeconds, origin and origin.id, destination.id,
            origin and origin.name, destination.name)
        if ok and validTime(seconds) then duration, estimated = seconds, source ~= "learned" end
    end
    if not duration then duration, estimated = flightEstimate(slot, destination), true end
    if duration then routeTimings[slot] = { duration = duration, estimate = estimated } end
    return duration, estimated
end

local function clockText(seconds)
    seconds = math.ceil(seconds)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function flightInfo()
    if not flying then return end
    local elapsed = math.max(0, math.floor(GetTime() - flying.started))
    if groundedAt then return flying.name, "Landung …" end
    local seconds = elapsed
    if flying.duration then
        local remaining = math.ceil(flying.duration - (GetTime() - flying.started))
        if remaining <= 0 then return flying.name, "Im Anflug …" end
        seconds = remaining
    end
    local clock = clockText(seconds)
    if not flying.duration then return flying.name, "Flugzeit · " .. clock end
    return flying.name, "Restzeit · " .. (flying.estimate and "ca. " or "") .. clock
end
app.FlightInfo = flightInfo

local function paint()
    local name, time = flightInfo()
    local state = name and (name .. " " .. time)
    if state == lastDisplay then return end
    lastDisplay = state
    if app.FlightChanged then app.FlightChanged() end
end

local function recordLanding(elapsed)
    if not (flying.key and flying.destination and validTime(elapsed)) then return end
    if UnitIsDeadOrGhost and readable(UnitIsDeadOrGhost("player")) then return end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local map = readable(C_Map.GetBestMapForUnit("player"))
    local position = map and C_Map.GetPlayerMapPosition(map, "player")
    local yards = distance(worldPosition(map, position), flying.destination)
    if yards and yards <= 300 then db.flightTimes[flying.key] = math.floor(elapsed + 0.5) end
end

local driver = CreateFrame("Frame")
driver:Hide()

local function startFlight(now)
    local saved = db.activeFlight
    if picked then
        flying = picked
        flying.started = now
    elseif type(saved) == "table" and type(saved.startedAt) == "number" then
        local elapsed = GetServerTime() - saved.startedAt
        if elapsed >= 0 and elapsed < maxDuration then
            flying = { name = saved.name, key = saved.key, duration = validTime(saved.duration) and saved.duration or nil, estimate = saved.estimate,
                started = now - elapsed, destination = saved.destination }
        end
    end
    flying = flying or { started = now }
    flying.name = flying.name or app.L("Unterwegs auf der Flugroute")
    picked, boardingUntil = nil, nil
    db.activeFlight = {
        name = flying.name, key = flying.key, duration = flying.duration, estimate = flying.estimate,
        startedAt = GetServerTime() - math.floor(now - flying.started), destination = flying.destination,
    }
end

local function updateFlight()
    if not db then return end
    local now = GetTime()
    if onTaxi() then
        groundedAt = nil
        if not flying then startFlight(now) end
    elseif flying then
        groundedAt = groundedAt or now
        -- Wait for the player's new map position and ignore brief transitions in flight.
        if now - groundedAt >= 1.5 then
            recordLanding(groundedAt - flying.started)
            flying, db.activeFlight, groundedAt = nil, nil, nil
        end
    elseif not boardingUntil or now >= boardingUntil then
        picked, boardingUntil, db.activeFlight = nil, nil, nil
    end
    paint()
    if not flying and not boardingUntil then driver:Hide() end
end

local tick = 0
driver:SetScript("OnUpdate", function(_, delta)
    tick = tick + delta
    if tick < 0.2 then return end
    tick = 0
    if not app.SecureCall("Flugtimer", updateFlight) then driver:Hide() end
end)

local function watch()
    driver:Show()
    if not app.SecureCall("Flugtimer", updateFlight) then driver:Hide() end
end

local function onTake(slot)
    if not db or flying then return end
    local destination = taxiDestination(slot)
    if not destination or not destination.name or destination.name == "" then return end
    local key = routeKey(origin, destination)
    local duration, estimated = routeTiming(slot, destination, key)
    picked = {
        name = destination.name:match("^([^,]+),") or destination.name,
        key = key, duration = duration, estimate = estimated, destination = destination.position,
    }
    boardingUntil = GetTime() + 10
    watch()
end

local function addFlightTooltip(owner, slot)
    if not db or not slot or GameTooltip:IsForbidden() or not GameTooltip:IsOwned(owner) then return end
    local destination = taxiDestination(slot)
    if not destination then return end
    local duration, estimated = routeTiming(slot, destination, routeKey(origin, destination))
    local display = duration and ((estimated and "ca. " or "") .. clockText(duration) .. " min") or "unbekannt"
    GameTooltip:AddLine("Flugzeit · " .. display, 0.98, 0.74, 0.40)
    GameTooltip:Show()
end

local hooked = setmetatable({}, { __mode = "k" })
local flightPin = "FlightMap_FlightPointPinTemplate"
local function hookHover(frame, onEnter)
    if not hooked[frame] then
        hooked[frame] = true
        frame:HookScript("OnEnter", onEnter)
    end
end

local function classicHover(button)
    local slot = button:GetID()
    if TaxiNodeGetType and readable(TaxiNodeGetType(slot)) == "REACHABLE" then addFlightTooltip(button, slot) end
end

local function pinHover(pin)
    local data = pin.taxiNodeData
    if data and not data.isMapLayerTransition and data.state == Enum.FlightPathState.Reachable then
        addFlightTooltip(pin, data.slotIndex)
    end
end

local function hookPins(map)
    for pin in map:EnumeratePinsByTemplate(flightPin) do hookHover(pin, pinHover) end
end

local mapWithHook, mapRefreshQueued
local function hookTooltips()
    for slot = 1, NumTaxiNodes and readable(NumTaxiNodes()) or 0 do
        local button = _G["TaxiButton" .. slot]
        if button then hookHover(button, classicHover) end
    end
    local map = FlightMapFrame
    if not (map and map.EnumeratePinsByTemplate and Enum and Enum.FlightPathState) then return end
    hookPins(map)
    if map == mapWithHook or not hooksecurefunc or not map.AcquirePin then return end
    mapWithHook = map
    hooksecurefunc(map, "AcquirePin", function(self, template)
        if template ~= flightPin or mapRefreshQueued then return end
        mapRefreshQueued = true
        C_Timer.After(0, function()
            mapRefreshQueued = nil
            if self:IsShown() then hookPins(self) end
        end)
    end)
end

if TakeTaxiNode and hooksecurefunc then hooksecurefunc("TakeTaxiNode", onTake) end
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "TAXIMAP_OPENED" }) do
    app.RegisterSupported(driver, event)
end
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        db = app.Settings()
        if type(db.flightTimes) ~= "table" then db.flightTimes = {} end
        if db.activeFlight then boardingUntil = GetTime() + 5 end
    elseif event == "TAXIMAP_OPENED" then
        readTaxiMap()
        hookTooltips()
        C_Timer.After(0, function()
            if not origin then readTaxiMap() end
            hookTooltips()
        end)
        return
    end
    if db and (onTaxi() or flying or boardingUntil) then watch() end
end)
