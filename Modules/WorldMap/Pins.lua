local _, app = ...
local world, options, style, L = app.worldMap, app.comfort, app.style, app.L
local mapAPI, read, plain = C_Map, app.ReadGameValue, app.Readable
local explorationAPI = C_MapExplorationInfo

local function rectKey(x, y, width, height)
    return x .. "/" .. y .. "/" .. width .. "/" .. height
end

function world.Unexplored(mapID)
    local artID = mapAPI and read(mapAPI.GetMapArtID, mapID)
    local data = artID and app.mapExplorationArt[artID]
    if not data or not explorationAPI then return end
    local textures = read(explorationAPI.GetExploredMapTextures, mapID)
    if type(textures) ~= "table" then return end
    local known, missing, discovered = {}, {}, {}
    for _, raw in ipairs(textures) do
        local texture = plain(raw)
        if texture then
            local x, y = plain(texture.offsetX), plain(texture.offsetY)
            local w, h = plain(texture.textureWidth), plain(texture.textureHeight)
            if type(x) == "number" and type(y) == "number" and type(w) == "number" and type(h) == "number" then
                known[rectKey(x, y, w, h)] = true
            else
                return
            end
        else
            return
        end
    end
    for _, row in ipairs(data[5]) do
        local entries = known[rectKey(row[1], row[2], row[3], row[4])] and discovered or missing
        entries[#entries + 1] = row
    end
    return data, missing, discovered
end

local colors = {
    flight = { "Flugpunkt", "F", 0.28, 0.72, 0.92 },
    portal = { "Portal", "P", 0.77, 0.55, 0.98 },
    cross = { "Gebietsübergang", ">", 1.00, 0.77, 0.34 },
    transport = { "Verkehrsverbindung", "V", 0.36, 0.78, 0.70 },
    healer = { "Geistheiler", "+", 0.73, 0.87, 0.96 },
    dungeon = { "Instanzeingang", "I", 0.93, 0.58, 0.34 },
    discovery = { "Unerforschtes Teilgebiet", "?", 1.00, 0.84, 0.38 },
    discovered = { "Erforschtes Teilgebiet", "+", 0.58, 0.86, 0.60 },
    level = { "Gebietsstufe", "", 0.96, 0.87, 0.66 },
}

local function navigate(map, target)
    local combat, known = options.Read(InCombatLockdown)
    if target and known and not combat and world.Info(target) then map:SetMapID(target) end
end
world.Navigate = navigate

local function createPin(canvas, map)
    local pin = CreateFrame("Button", nil, canvas, "BackdropTemplate")
    pin:SetFrameLevel(canvas:GetFrameLevel() + 18)
    pin:SetSize(18, 18)
    pin:RegisterForClicks("RightButtonUp")
    style.Panel(pin, { 0.10, 0.08, 0.07, 0.94 })
    pin.text = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pin.text:SetPoint("CENTER", 0, 0)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetPoint("CENTER")
    pin.icon:SetSize(14, 14)
    pin:SetScript("OnClick", function(self)
        if self.point then navigate(map, self.point.target) end
    end)
    pin:SetScript("OnEnter", function(self)
        local point = self.point
        if not point or not GameTooltip or GameTooltip:IsForbidden() then return end
        local kind = colors[point.kind]
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(point.name or L(kind[1]), kind[3], kind[4], kind[5])
        if point.name then GameTooltip:AddLine(L(kind[1]), unpack(style.muted)) end
        if point.note and point.note ~= "" then GameTooltip:AddLine(point.note, unpack(style.cream)) end
        if point.target then GameTooltip:AddLine(L("Rechtsklick öffnet die Zielkarte."), unpack(style.muted)) end
        GameTooltip:Show()
    end)
    local function clear()
        if GameTooltip and GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
    end
    pin:SetScript("OnLeave", clear)
    pin:SetScript("OnHide", clear)
    return pin
end

local function configure(pin, point)
    pin.point = point
    local choice = colors[point.kind]
    local label, width = point.label or choice[2], point.kind == "level" and 42 or 18
    pin:SetSize(width, 18)
    pin:SetBackdropBorderColor(choice[3], choice[4], choice[5], 0.96)
    pin.text:SetText(label)
    pin.text:SetTextColor(choice[3], choice[4], choice[5])
    local atlas = point.atlas
    local icon = type(atlas) == "string" and C_Texture and read(C_Texture.GetAtlasInfo, atlas)
    pin.icon:SetShown(not not icon)
    pin.text:SetShown(not icon)
    if icon then pin.icon:SetAtlas(atlas) end
    if pin.SetMouseClickEnabled then pin:SetMouseClickEnabled(point.target ~= nil) end
    if pin.SetMouseMotionEnabled then pin:SetMouseMotionEnabled(true) end
end

local function placePins(provider)
    local map = provider:GetMap()
    local canvas = map:GetCanvas()
    local scale = read(map.GetCanvasScale, map)
    if not canvas or type(scale) ~= "number" or scale <= 0 then return end
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    for i = 1, provider.used do
        local pin = provider.pins[i]
        pin:SetScale(1 / scale)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", canvas, "TOPLEFT", pin.point.x * width * scale, -pin.point.y * height * scale)
    end
end

local nativeTemplates = { flight = "FlightPointPinTemplate", cross = "MapLinkPinTemplate", dungeon = "DungeonEntrancePinTemplate" }
local function nativePositions(map)
    local result = {}
    if not map.EnumeratePinsByTemplate then return result end
    for kind, template in pairs(nativeTemplates) do
        local positions = {}
        result[kind] = positions
        for pin in map:EnumeratePinsByTemplate(template) do
            local x, y = read(pin.GetPosition, pin)
            if app.ValidMapPoint(x, y) and pin:IsShown() then positions[#positions + 1] = { x, y } end
        end
    end
    for _, template in ipairs({ "AreaPOIPinTemplate", "MapLinkPinTemplate" }) do
        for pin in map:EnumeratePinsByTemplate(template) do
            local poi = plain(pin.poiInfo)
            local kind = poi and world.PoiKind(plain(poi.atlasName))
            if kind and pin:IsShown() then
                local x, y = read(pin.GetPosition, pin)
                if app.ValidMapPoint(x, y) then
                    local positions = result[kind] or {}
                    positions[#positions + 1] = { x, y }
                    result[kind] = positions
                end
            end
        end
    end
    return result
end

local function hasNative(point, positions)
    for _, location in ipairs(positions[point.kind] or {}) do
        if math.abs(point.x - location[1]) <= 0.008 and math.abs(point.y - location[2]) <= 0.008 then return true end
    end
    return false
end

local function powerOfTwo(value)
    local result = 1
    while result < value do result = result * 2 end
    return result
end

local function explore(provider, canvas, mapID, points)
    local draw = options.Enabled("mapReveal")
    local mark = options.Enabled("mapDiscovery")
    local data, remaining, discovered
    if draw or mark then data, remaining, discovered = world.Unexplored(mapID) end
    local used = 0
    if data then
        local artWidth, artHeight, tileWidth, tileHeight = unpack(data, 1, 4)
        local xScale, yScale = canvas:GetWidth() / artWidth, canvas:GetHeight() / artHeight
        local tint = options.Enabled("mapRevealTint")
        if draw and not provider.art then
            provider.art = CreateFrame("Frame", nil, canvas)
            provider.art:SetAllPoints()
            provider.art:SetFrameLevel(canvas:GetFrameLevel() + 2)
        end
        if mark and options.Enabled("mapShowDiscovered") then
            for _, item in ipairs(discovered) do
                local x, y = (item[1] + item[3] / 2) / artWidth, (item[2] + item[4] / 2) / artHeight
                if app.ValidMapPoint(x, y) then
                    points[#points + 1] = {
                        kind = "discovered", name = read(mapAPI.GetAreaInfo, item[5]) or L("Erforschtes Teilgebiet"),
                        x = x, y = y,
                    }
                end
            end
        end
        for index, item in ipairs(remaining) do
            local x, y, width, height, area, files = unpack(item)
            if mark then
                local px, py = (x + width / 2) / artWidth, (y + height / 2) / artHeight
                if app.ValidMapPoint(px, py) then
                    local name = read(mapAPI.GetAreaInfo, area)
                    points[#points + 1] = {
                        kind = "discovery", name = name or L("Unerforschtes Teilgebiet"),
                        x = px, y = py, label = tostring(index),
                    }
                end
            end
            if draw then
                for i = 1, #files, 3 do
                    local dy, dx = files[i] * tileHeight, files[i + 1] * tileWidth
                    local sw, sh = math.min(tileWidth, width - dx), math.min(tileHeight, height - dy)
                    if sw > 0 and sh > 0 then
                        used = used + 1
                        local texture = provider.tiles[used] or provider.art:CreateTexture(nil, "ARTWORK")
                        provider.tiles[used] = texture
                        texture:SetTexture(files[i + 2])
                        texture:SetTexCoord(0, sw / powerOfTwo(sw), 0, sh / powerOfTwo(sh))
                        texture:ClearAllPoints()
                        texture:SetPoint("TOPLEFT", provider.art, "TOPLEFT", (x + dx) * xScale, -(y + dy) * yScale)
                        texture:SetSize(sw * xScale, sh * yScale)
                        if tint then texture:SetVertexColor(0.61, 0.66, 0.73)
                        else texture:SetVertexColor(1, 1, 1) end
                        texture:Show()
                    end
                end
            end
        end
    end
    for index = used + 1, provider.tileCount do provider.tiles[index]:Hide() end
    provider.tileCount = used
end

local function levelMarkers(id, points)
    local info = world.Info(id)
    if not options.Enabled("mapZoneLevels") or not info or plain(info.mapType) ~= world.types.Continent then return end
    for _, zone in ipairs(world.Children(id, world.types.Zone, true)) do
        local range = world.levels[zone.id]
        local x, y = app.ProjectMapPoint(zone.id, id, 0.50, 0.58)
        if range and x then
            local note = options.Enabled("mapFishing") and world.fishing[zone.id]
            points[#points + 1] = {
                kind = "level", name = zone.name, x = x, y = y, target = zone.id,
                label = ("%d–%d"):format(unpack(range)), note = note and app.LF("Angeln · Grundfertigkeit etwa %d", note),
            }
        end
    end
end

local function clear(provider)
    for i = 1, provider.used do provider.pins[i]:Hide() end
    for i = 1, provider.tileCount do provider.tiles[i]:Hide() end
    provider.used, provider.tileCount = 0, 0
end

local function draw(provider)
    local map = provider:GetMap()
    local canvas, mapID = map:GetCanvas(), read(map.GetMapID, map)
    if not canvas or not mapID or not map:IsVisible()
        or (not provider.showLevels and not options.Enabled("mapBattlefield")) then return clear(provider) end
    local points, native = world.Collect(mapID), nativePositions(map)
    explore(provider, canvas, mapID, points)
    if provider.showLevels then levelMarkers(mapID, points) end
    local used = 0
    for _, point in ipairs(points) do
        if not hasNative(point, native) then
            used = used + 1
            local pin = provider.pins[used] or createPin(canvas, map)
            provider.pins[used] = pin
            configure(pin, point)
            pin:Show()
        end
    end
    for i = used + 1, provider.used do provider.pins[i]:Hide() end
    provider.used = used
    placePins(provider)
end

function world.AttachPins(map, showLevels)
    if not (map.AddDataProvider and map.GetCanvas and MapCanvasDataProviderMixin and CreateFromMixins and C_Timer) then return end
    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    provider.pins, provider.tiles, provider.used, provider.tileCount = {}, {}, 0, 0
    provider.showLevels = showLevels
    provider.RefreshAllData = function(self)
        if self.pending or not self:GetMap():IsVisible() then return end
        self.pending = true
        C_Timer.After(0, function()
            self.pending = nil
            app.SecureCall(L("Weltkarte"), draw, self)
        end)
    end
    provider.OnHide = clear
    provider.RemoveAllData = clear
    provider.OnShow = provider.RefreshAllData
    provider.OnCanvasScaleChanged = placePins
    provider.OnCanvasSizeChanged = provider.RefreshAllData
    provider.OnMapChanged = function(self) clear(self); self:RefreshAllData() end
    map:AddDataProvider(provider)
    provider:RefreshAllData()
    return provider
end
