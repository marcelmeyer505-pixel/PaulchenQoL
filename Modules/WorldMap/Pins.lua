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
    travel = { "Reisepunkte", "", 0.73, 0.81, 0.94 },
    discovery = { "Unerforschtes Teilgebiet", "?", 1.00, 0.84, 0.38 },
    discovered = { "Erforschtes Teilgebiet", "+", 0.58, 0.86, 0.60 },
    level = { "Gebietsstufe", "", 0.96, 0.87, 0.66 },
}

local function navigate(map, target)
    local combat, known = options.Read(InCombatLockdown)
    if target and known and not combat and world.Info(target) then map:SetMapID(target) end
end
world.Navigate = navigate

local function nameOf(point)
    return point.name or L(colors[point.kind][1])
end

local function destination(point, mapID)
    return point.target or point.source ~= mapID and point.source or nil
end

local function showTravelMenu(pin, map, members)
    local locked, known = options.Read(InCombatLockdown)
    if not known or locked or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local mapID = read(map.GetMapID, map)
    MenuUtil.CreateContextMenu(pin, function(_, menu)
        menu:CreateTitle(L("Reisepunkte"))
        if menu.SetScrollMode then menu:SetScrollMode(300) end
        for _, member in ipairs(members) do
            local target = destination(member, mapID)
            if target then menu:CreateButton(nameOf(member), function() navigate(map, target) end)
            else menu:CreateTitle(nameOf(member)) end
        end
    end)
end

local function createPin(canvas, map)
    local anchor = CreateFrame("Frame", nil, canvas)
    anchor:SetSize(1, 1)
    local pin = CreateFrame("Button", nil, anchor)
    pin.positionAnchor = anchor
    pin:SetPoint("CENTER", anchor, "CENTER")
    pin:RegisterForClicks("RightButtonUp")
    pin.badge = pin:CreateTexture(nil, "BACKGROUND")
    pin.badge:SetAllPoints()
    pin.badge:SetTexture(app.artPath .. "map_pin.tga")
    pin.text = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pin.text:SetPoint("CENTER", 0, 0)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetPoint("CENTER")
    pin.icon:SetSize(14, 14)
    pin:SetScript("OnClick", function(self, button)
        local point = self.point
        if point and point.dungeons then world.DungeonClick(self, point.dungeons, button)
        elseif point and point.members then showTravelMenu(self, map, point.members)
        elseif point and button == "RightButton" then navigate(map, destination(point, read(map.GetMapID, map))) end
    end)
    pin:SetScript("OnEnter", function(self)
        local point = self.point
        if not point or not GameTooltip or GameTooltip:IsForbidden() then return end
        local kind = colors[point.kind]
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(nameOf(point), kind[3], kind[4], kind[5])
        if point.name and not point.members then GameTooltip:AddLine(L(kind[1]), unpack(style.muted)) end
        if point.note and point.note ~= "" then
            GameTooltip:AddLine(point.note, style.cream[1], style.cream[2], style.cream[3], true)
        end
        if point.members then
            for _, member in ipairs(point.members) do GameTooltip:AddLine(nameOf(member), unpack(style.cream)) end
            GameTooltip:AddLine(L("Rechtsklick zeigt die Reisepunkte."), unpack(style.muted))
        elseif point.dungeons then
            if #point.dungeons > 1 then
                for _, entry in ipairs(point.dungeons) do GameTooltip:AddLine(entry.name, unpack(style.cream)) end
            end
            GameTooltip:AddLine(L("Linksklick öffnet die Instanz. Rechtsklick zeigt die Optionen."), unpack(style.muted))
        elseif point.kind == "dungeon" and not (app.instances or _G.ForeverDungeonJournal_NS or _G.ForeverDungeonRoutes) then
            GameTooltip:AddLine(L("Für Innenkarten DungeonJournal oder Forever DungeonRoutes aktivieren."),
                style.muted[1], style.muted[2], style.muted[3], true)
        end
        if not point.members and destination(point, read(map.GetMapID, map)) then
            GameTooltip:AddLine(L("Rechtsklick öffnet die Zielkarte."), unpack(style.muted))
        end
        GameTooltip:Show()
    end)
    local function clear()
        if GameTooltip and GameTooltip:IsOwned(pin) then GameTooltip:Hide() end
    end
    pin:SetScript("OnLeave", clear)
    pin:SetScript("OnHide", clear)
    return pin
end

local function configure(pin, point, overview, mapID)
    pin.point = point
    local choice = colors[point.kind]
    local label = point.label or choice[2]
    local dungeon = point.kind == "dungeon"
    local size = dungeon and (overview and 19 or 22) or (overview and 16 or 19)
    pin:SetSize(point.kind == "level" and 44 or size, size)
    pin.icon:SetSize(size - 6, size - 6)
    local acceptsLeft = point.dungeons ~= nil
    if acceptsLeft ~= pin.acceptsLeft then
        if acceptsLeft then pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        else pin:RegisterForClicks("RightButtonUp") end
        pin.acceptsLeft = acceptsLeft
    end
    pin.badge:SetShown(point.kind ~= "level")
    pin.badge:SetVertexColor(choice[3], choice[4], choice[5])
    pin.text:SetText(label)
    pin.text:SetTextColor(choice[3], choice[4], choice[5])
    local atlas = point.atlas
    local icon = not dungeon and not point.members and type(atlas) == "string" and C_Texture and read(C_Texture.GetAtlasInfo, atlas)
    local dungeonIcon = dungeon and not point.label
    pin.icon:SetShown(not not icon or dungeonIcon)
    pin.text:SetShown(not icon and not dungeonIcon)
    if dungeonIcon then
        pin.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        pin.icon:SetTexCoord(0, 1, 0, 1)
    elseif icon then
        pin.icon:SetAtlas(atlas)
    end
    if pin.SetMouseClickEnabled then
        pin:SetMouseClickEnabled(acceptsLeft or point.members ~= nil or destination(point, mapID) ~= nil)
    end
    if pin.SetMouseMotionEnabled then pin:SetMouseMotionEnabled(true) end
end

local function placePins(provider)
    local map = provider:GetMap()
    local canvas = map:GetCanvas()
    local scale = read(map.GetCanvasScale, map) or canvas and read(canvas.GetScale, canvas)
    if not canvas or type(scale) ~= "number" or scale <= 0 then return end
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    for i = 1, provider.used do
        local pin = provider.pins[i]
        local anchor = pin.positionAnchor
        if anchor:GetParent() ~= canvas then anchor:SetParent(canvas) end
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", canvas, "TOPLEFT", pin.point.x * width, -pin.point.y * height)
        pin:SetScale(1 / scale)
    end
end

local nativeTemplates = { flight = "FlightPointPinTemplate", cross = "MapLinkPinTemplate", dungeon = "DungeonEntrancePinTemplate" }
local function nativePositions(map, entrancesOnly)
    local result = {}
    if not map.EnumeratePinsByTemplate then return result end
    for kind, template in pairs(nativeTemplates) do
        if (kind == "dungeon") == entrancesOnly then
            local positions = {}
            result[kind] = positions
            for pin in map:EnumeratePinsByTemplate(template) do
                local x, y = read(pin.GetPosition, pin)
                if app.ValidMapPoint(x, y) and pin:IsShown() then
                    positions[#positions + 1] = { x, y, read(pin.GetFrameLevel, pin) }
                end
            end
        end
    end
    if entrancesOnly then return result end
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
        if math.abs(point.x - location[1]) <= 0.008 and math.abs(point.y - location[2]) <= 0.008 then
            return true, location[3]
        end
    end
    return false
end

local travelKinds = { flight = true, portal = true, cross = true, transport = true, healer = true }

local function groupMarkers(points, canvas, scale, overview, entrancesOnly)
    if not overview and not entrancesOnly then return points end
    local result, groups = {}, {}
    local width, height = canvas:GetSize()
    width, height = width * scale, height * scale
    local distance = overview and (entrancesOnly and 29 or 26) or 13
    for _, point in ipairs(points) do
        if (entrancesOnly and point.dungeon) or (not entrancesOnly and travelKinds[point.kind]) then
            local group
            for _, candidate in ipairs(groups) do
                local dx, dy = (point.x - candidate.x) * width, (point.y - candidate.y) * height
                if dx * dx + dy * dy <= distance * distance then group = candidate; break end
            end
            if not group then
                group = { contents = {} }
                for key, value in pairs(point) do group[key] = value end
                groups[#groups + 1] = group
                result[#result + 1] = group
            end
            local contents = group.contents
            contents[#contents + 1] = entrancesOnly and point.dungeon or point
        else
            result[#result + 1] = point
        end
    end
    for _, group in ipairs(groups) do
        local contents = group.contents
        if entrancesOnly then group.dungeons = contents end
        if #contents > 1 then
            table.sort(contents, function(a, b)
                if entrancesOnly then return a.name < b.name end
                return nameOf(a) < nameOf(b)
            end)
            group.label, group.atlas, group.note = tostring(#contents), nil, nil
            group.name = L(entrancesOnly and "Instanzeingänge" or "Reisepunkte")
            if not entrancesOnly then group.kind, group.members = "travel", contents end
        end
    end
    return result
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
    provider.points, provider.drawingMap, provider.layoutScale = nil, nil, nil
end

local function layoutPins(provider, map, canvas, scale)
    local entrancesOnly = provider.entrancesOnly
    local points = groupMarkers(provider.points, canvas, scale, provider.overview, entrancesOnly)
    local used = 0
    for _, point in ipairs(points) do
        local nativePin, nativeLevel = hasNative(point, provider.native)
        if not nativePin or point.dungeons then
            used = used + 1
            local pin = provider.pins[used] or createPin(canvas, map)
            provider.pins[used] = pin
            local level = canvas:GetFrameLevel() + (entrancesOnly and 30 or 18)
            if entrancesOnly then
                pin:SetFrameStrata(map:GetFrameStrata())
            end
            pin:SetFrameLevel(nativeLevel and math.max(level, nativeLevel + 1) or level)
            configure(pin, point, provider.overview, provider.drawingMap)
            pin:Show()
        end
    end
    for i = used + 1, provider.used do provider.pins[i]:Hide() end
    provider.used = used
    provider.layoutScale = scale
    placePins(provider)
end

local function mapGeometry(map)
    local canvas = map:GetCanvas()
    if not canvas then return end
    local width, height = canvas:GetSize()
    local scale = read(map.GetCanvasScale, map) or read(canvas.GetScale, canvas)
    if type(scale) ~= "number" or scale <= 0 or width <= 0 or height <= 0 then return end
    return canvas, scale
end

local function draw(provider)
    local map = provider:GetMap()
    local mapID = read(map.GetMapID, map)
    if not mapID or not map:IsVisible() or (not provider.showLevels and not options.Enabled("mapBattlefield")) then
        return clear(provider)
    end
    local canvas, scale = mapGeometry(map)
    if not canvas then return end
    local entrancesOnly = provider.entrancesOnly
    local points = entrancesOnly and world.CollectEntrances(mapID) or world.Collect(mapID, true)
    local info = world.Info(mapID)
    local kind = info and plain(info.mapType)
    provider.overview = kind == world.types.World or kind == world.types.Continent
    local native
    app.SecureCall(L("Weltkarte"), function() native = nativePositions(map, entrancesOnly) end)
    provider.native = native or {}
    if not entrancesOnly then
        explore(provider, canvas, mapID, points)
        if provider.showLevels then levelMarkers(mapID, points) end
    end
    provider.points, provider.drawingMap = points, mapID
    layoutPins(provider, map, canvas, scale)
end

function world.AttachPins(map, showLevels, entrancesOnly)
    if not (map.AddDataProvider and map.GetCanvas and MapCanvasDataProviderMixin and CreateFromMixins and C_Timer) then return end
    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    provider.pins, provider.tiles, provider.used, provider.tileCount = {}, {}, 0, 0
    provider.showLevels, provider.entrancesOnly = showLevels, entrancesOnly == true
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
    provider.OnCanvasScaleChanged = function(self)
        local canvas, scale = mapGeometry(map)
        if not canvas or not map:IsVisible() then return end
        if not self.points or self.drawingMap ~= read(map.GetMapID, map) then self:RefreshAllData()
        elseif not self.layoutScale or math.abs(scale - self.layoutScale) > self.layoutScale * .1 then
            app.SecureCall(L("Weltkarte"), layoutPins, self, map, canvas, scale)
        else
            placePins(self)
        end
    end
    provider.OnCanvasSizeChanged = provider.RefreshAllData
    provider.OnMapChanged = function(self)
        clear(self)
        self:RefreshAllData()
        local mapID = read(map.GetMapID, map)
        -- Zoom navigation can deliver the new map ID before its canvas has a usable size.
        local transition = {}
        self.transition = transition
        C_Timer.After(.18, function()
            if self.transition == transition and read(map.GetMapID, map) == mapID then self:RefreshAllData() end
        end)
    end
    map:AddDataProvider(provider)
    provider:RefreshAllData()
    return provider
end
