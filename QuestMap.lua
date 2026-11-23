local _, app = ...

local template = "QuestPinTemplate"
local provider

local function call(fn, ...)
    if not fn then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return app.Readable(a), app.Readable(b), app.Readable(c), app.Readable(d) end
end

local function validPoint(x, y)
    return type(x) == "number" and type(y) == "number"
        and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (x > 0 or y > 0)
end

local function mapRect(source, target, x, y)
    local left, right, top, bottom = call(C_Map.GetMapRectOnMap, source, target)
    if type(left) == "number" and type(right) == "number" and right > left
        and type(top) == "number" and type(bottom) == "number" and bottom > top then
        x, y = left + (right - left) * x, top + (bottom - top) * y
        if validPoint(x, y) then return x, y end
    end
end

local function project(source, target, x, y)
    if source == target then return x, y end
    local px, py = mapRect(source, target, x, y)
    if px then return px, py end
    -- The world map may expose only the rectangles between a map and its parent.
    for _ = 1, 10 do
        local info = call(C_Map.GetMapInfo, source)
        local parent = info and app.Readable(info.parentMapID)
        if not parent or parent == 0 or parent == source then break end
        x, y = mapRect(source, parent, x, y)
        if not x or parent == target then return x, y end
        source = parent
    end
end

app.ProjectMapPoint = project
app.ValidMapPoint = validPoint

local function polestarLocation(id)
    local codex = Polestar and Polestar.Codex
    local lookup = Polestar and Polestar.Lookup
    if not (codex and lookup and lookup.QuestEnd) then return end
    local entry = call(codex.Quest, id)
    local destination = entry and call(lookup.QuestEnd, entry["end"])
    local spawn = destination and not destination.hostile and destination.spawn
    if spawn and type(spawn.map) == "number" and type(spawn.x) == "number" and type(spawn.y) == "number" then
        return spawn.map, spawn.x / 100, spawn.y / 100, destination.name
    end
end

local function mapPoints(map, mapID)
    local native, onMap, destinations = {}, {}, {}
    if map.EnumeratePinsByTemplate then
        for pin in map:EnumeratePinsByTemplate(template) do
            local id = pin.GetQuestID and app.Readable(pin:GetQuestID())
            local x, y = call(pin.GetGlobalPosition or pin.GetPosition, pin)
            if id and validPoint(x, y) then native[id] = { x = x, y = y } end
        end
    end
    for _, poi in ipairs(call(C_QuestLog.GetQuestsOnMap, mapID) or {}) do
        local id = app.Readable(poi.questID)
        local x, y = app.Readable(poi.x), app.Readable(poi.y)
        if id and validPoint(x, y) then onMap[id] = { x = x, y = y } end
    end
    local count = call(C_QuestLog.GetNumQuestLogEntries) or 0
    for index = 1, count do
        local info = call(C_QuestLog.GetInfo, index)
        local id = info and not app.Readable(info.isHeader) and not app.Readable(info.isHidden)
            and app.Readable(info.questID)
        if type(id) == "number" and id > 0 and call(C_QuestLog.ReadyForTurnIn, id) == true then
            local x, y = call(C_QuestLog.GetNextWaypointForMap, id, mapID)
            local name = call(C_QuestLog.GetNextWaypointText, id)
            if not validPoint(x, y) then
                local pin = native[id] or onMap[id]
                if pin then
                    x, y = pin.x, pin.y
                else
                    local source, sx, sy = call(C_QuestLog.GetNextWaypoint, id)
                    if type(source) ~= "number" or source <= 0 or not validPoint(sx, sy) then
                        local destination
                        source, sx, sy, destination = polestarLocation(id)
                        name = name or destination
                    end
                    if type(source) == "number" and validPoint(sx, sy) then x, y = project(source, mapID, sx, sy) end
                end
            end
            if validPoint(x, y) then
                local title = app.Readable(info.title) or call(C_QuestLog.GetTitleForQuestID, id)
                destinations[#destinations + 1] = {
                    x = x, y = y, title = title or (app.L("Quest #") .. id), name = name, native = native[id] ~= nil,
                }
            end
        end
    end
    return destinations
end

local function groupPoints(points, width, height)
    local groups = {}
    for _, point in ipairs(points) do
        local group
        for _, candidate in ipairs(groups) do
            local dx, dy = (point.x - candidate.x) * width, (point.y - candidate.y) * height
            if dx * dx + dy * dy <= 16 * 16 then group = candidate; break end
        end
        if not group then
            group = { x = point.x, y = point.y, quests = {} }
            groups[#groups + 1] = group
        end
        group.quests[#group.quests + 1] = point
    end
    return groups
end

local function createPin(canvas)
    local pin = CreateFrame("Frame", nil, canvas)
    pin:SetSize(22, 22)
    pin:SetFrameLevel(canvas:GetFrameLevel() + 40)
    pin:SetMouseMotionEnabled(true)
    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
    pin.count = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pin.count:SetPoint("BOTTOMRIGHT", 2, 0)
    pin:SetScript("OnEnter", function(self)
        local group = self.group
        if not group or GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(#group.quests == 1 and app.L("Questabgabe") or app.LF("%d Questabgaben", #group.quests),
            unpack(app.style.gold))
        for _, quest in ipairs(group.quests) do
            GameTooltip:AddLine(quest.title, 1, 1, 1, true)
            if #group.quests == 1 and quest.name and quest.name ~= "" then
                GameTooltip:AddLine(quest.name, unpack(app.style.muted))
            end
        end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    pin:SetScript("OnHide", pin:GetScript("OnLeave"))
    return pin
end

local function placePins(self)
    if self.used == 0 then return end
    local map = self:GetMap()
    local canvas = map:GetCanvas()
    local width, height, scale = canvas:GetWidth(), canvas:GetHeight(), map:GetCanvasScale()
    if scale <= 0 then return end
    for i = 1, self.used do
        local pin = self.pins[i]
        pin:SetScale(1 / scale)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT", pin.group.x * width * scale, -pin.group.y * height * scale)
    end
end

local function hidePins(self)
    for index = 1, self.used do self.pins[index]:Hide() end
    self.used = 0
end

local function draw(self)
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local canvas = map:GetCanvas()
    if not (map:IsVisible() and mapID and canvas and app.Profile().questTurnIns) then
        hidePins(self)
        return
    end
    local used = 0
    for _, group in ipairs(groupPoints(mapPoints(map, mapID), canvas:GetWidth(), canvas:GetHeight())) do
        -- Leave stand-alone native markers in place. A shared pin lists every quest at the destination.
        local count = #group.quests
        if count > 1 or not group.quests[1].native then
            used = used + 1
            local pin = self.pins[used] or createPin(canvas)
            self.pins[used] = pin
            pin.group = group
            pin.count:SetText(count > 1 and tostring(count) or "")
            pin:Show()
            if pin:IsMouseOver() and GameTooltip:IsOwned(pin) then pin:GetScript("OnEnter")(pin) end
        end
    end
    for i = used + 1, self.used do self.pins[i]:Hide() end
    self.used = used
    placePins(self)
end

function app.RefreshQuestMap()
    if provider then provider:RefreshAllData() end
end

local function attach()
    local map = WorldMapFrame
    if provider or not (map and map.AddDataProvider and MapCanvasDataProviderMixin and CreateFromMixins) then return end
    if not (C_Map and C_QuestLog and C_QuestLog.ReadyForTurnIn and C_QuestLog.GetInfo) then return end
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    provider.pins, provider.used = {}, 0
    provider.RefreshAllData = function(self)
        if self.pending or not self:GetMap():IsVisible() then return end
        self.pending = true
        -- Other providers can add the selected quest pin during the same map update.
        C_Timer.After(0, function()
            self.pending = nil
            app.SecureCall(app.L("Questabgaben auf der Weltkarte"), draw, self)
        end)
    end
    provider.OnHide = hidePins
    provider.OnShow = provider.RefreshAllData
    provider.OnCanvasScaleChanged = placePins
    provider.OnCanvasSizeChanged = provider.RefreshAllData
    provider.OnMapChanged = function(self)
        hidePins(self)
        self:RefreshAllData()
    end
    map:AddDataProvider(provider)
    if map.RegisterCallback then
        map:RegisterCallback("SetFocusedQuestID", app.RefreshQuestMap, provider)
        map:RegisterCallback("ClearFocusedQuestID", app.RefreshQuestMap, provider)
    end
    provider:RefreshAllData()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE",
    "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_DATA_LOAD_RESULT", "SUPER_TRACKING_CHANGED", "WAYPOINT_UPDATE" }) do
    app.RegisterSupported(events, event)
end
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and name == "Blizzard_WorldMap") then
        attach()
    elseif event ~= "ADDON_LOADED" then
        app.RefreshQuestMap()
    end
end)
