local _, app = ...
local world, options, style, L = app.worldMap, app.comfort, app.style, app.L
local mapAPI, read, plain = C_Map, app.ReadGameValue, app.Readable
local explorationAPI = C_MapExplorationInfo
local markerLayers = setmetatable({}, { __mode = "k" })

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
    dungeon = { "Instanzeingang", "I", 0.32, 0.74, 1.00 },
    travel = { "Reisepunkte", "", 0.73, 0.81, 0.94 },
    discovery = { "Unerforschtes Teilgebiet", "?", 1.00, 0.84, 0.38 },
    discovered = { "Erforschtes Teilgebiet", "+", 0.58, 0.86, 0.60 },
    level = { "Gebietsstufe", "", 0.96, 0.87, 0.66 },
}

local stockAtlases = {
    cross = "Garr_LevelUpgradeArrow",
    healer = "Vehicle-TempleofKotmogu-GreenBall",
}
local flightAtlases = {
    Alliance = "TaxiNode_Alliance", Horde = "TaxiNode_Horde", Neutral = "TaxiNode_Neutral",
}

-- Leatrix Maps uses these Blizzard atlases directly. Only reference client artwork.
local function markerAtlas(point)
    local atlasAPI = C_Texture and C_Texture.GetAtlasInfo
    if not atlasAPI or point.members then return end
    local atlas = stockAtlases[point.kind]
    if point.kind == "dungeon" then
        atlas = point.raid and "Raid" or "Dungeon"
    elseif point.kind == "flight" then
        atlas = flightAtlases[point.faction] or flightAtlases.Neutral
    elseif point.kind == "portal" then
        local horde = point.faction == "Horde" or not point.faction and point.atlas == "MagePortalHorde"
        atlas = horde and "MagePortalHorde" or "MagePortalAlliance"
    elseif point.kind == "transport" then
        atlas = point.atlas or "Vehicle-TempleofKotmogu-CyanBall"
    end
    if atlas and read(atlasAPI, atlas) then return atlas end
    if point.atlas and point.atlas ~= atlas and read(atlasAPI, point.atlas) then return point.atlas end
    if point.kind == "transport" and read(atlasAPI, "Vehicle-TempleofKotmogu-CyanBall") then
        return "Vehicle-TempleofKotmogu-CyanBall"
    end
end

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

local function createPin(canvas, map, layer)
    local anchor
    if not layer then
        anchor = CreateFrame("Frame", nil, canvas)
        anchor:SetSize(1, 1)
    end
    local pin = CreateFrame("Button", nil, layer or anchor)
    if anchor then
        pin.positionAnchor = anchor
        pin:SetPoint("CENTER", anchor, "CENTER")
    end
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
    local atlas = markerAtlas(point)
    local size = dungeon and (overview and 23 or 30) or (overview and 17 or 22)
    pin:SetSize(point.kind == "level" and 44 or size, size)
    local iconSize = atlas and size or size - 6
    pin.icon:SetSize(atlas == "Garr_LevelUpgradeArrow" and iconSize * 48 / 54 or iconSize, iconSize)
    local acceptsLeft = point.dungeons ~= nil
    if acceptsLeft ~= pin.acceptsLeft then
        if acceptsLeft then pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        else pin:RegisterForClicks("RightButtonUp") end
        pin.acceptsLeft = acceptsLeft
    end
    local showCount = atlas ~= nil and dungeon and point.label ~= nil
    pin.badge:ClearAllPoints()
    pin.text:ClearAllPoints()
    if showCount then
        pin.badge:SetDrawLayer("OVERLAY", -1)
        pin.badge:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 1, -1)
        pin.badge:SetSize(13, 13)
        pin.text:SetPoint("CENTER", pin.badge, "CENTER")
    else
        pin.badge:SetDrawLayer("BACKGROUND")
        pin.badge:SetAllPoints()
        pin.text:SetPoint("CENTER", 0, 0)
    end
    pin.badge:SetShown(showCount or not atlas and point.kind ~= "level")
    pin.badge:SetVertexColor(choice[3], choice[4], choice[5])
    pin.text:SetText(label)
    if showCount then pin.text:SetTextColor(unpack(style.cream))
    else pin.text:SetTextColor(choice[3], choice[4], choice[5]) end
    local dungeonIcon = not atlas and dungeon and not point.label
    pin.icon:SetShown(atlas ~= nil or dungeonIcon)
    pin.text:SetShown(showCount or not atlas and not dungeonIcon)
    if dungeonIcon then
        pin.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        pin.icon:SetTexCoord(0, 1, 0, 1)
    elseif atlas then
        pin.icon:SetAtlas(atlas)
    end
    if pin.SetMouseClickEnabled then
        pin:SetMouseClickEnabled(acceptsLeft or point.members ~= nil or destination(point, mapID) ~= nil)
    end
    if pin.SetMouseMotionEnabled then pin:SetMouseMotionEnabled(true) end
end

local function placeOverlayPins(provider, canvas, scale)
    local map, layer = provider:GetMap(), provider.layer
    local viewport = map.ScrollContainer
    local left = read(viewport.GetHorizontalScroll, viewport) or 0
    local top = read(viewport.GetVerticalScroll, viewport) or 0
    local width, height = canvas:GetSize()
    local visibleWidth, visibleHeight = viewport:GetSize()
    -- The scroll offsets are in canvas units. The marker layer itself stays unscaled.
    for i = 1, provider.used do
        local pin = provider.pins[i]
        local x = (pin.point.x * width - left) * scale
        local y = (pin.point.y * height - top) * scale
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", layer, "TOPLEFT", x, -y)
        pin:SetShown(x >= 0 and x <= visibleWidth and y >= 0 and y <= visibleHeight)
    end
end

local function placePins(provider)
    local map = provider:GetMap()
    local canvas = map:GetCanvas()
    local scale = read(map.GetCanvasScale, map) or canvas and read(canvas.GetScale, canvas)
    if not canvas or type(scale) ~= "number" or scale <= 0 then return end
    if provider.layer then return placeOverlayPins(provider, canvas, scale) end
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
            if entrancesOnly and not point.raid then group.raid = false end
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
    local layer = provider.layer
    if layer then
        local strata = map:GetFrameStrata()
        if strata ~= "FULLSCREEN" and strata ~= "FULLSCREEN_DIALOG" and strata ~= "TOOLTIP" then strata = "DIALOG" end
        layer:SetFrameStrata(strata)
        layer:SetFrameLevel(math.max(map:GetFrameLevel(), canvas:GetFrameLevel(),
            (map.BorderFrame or map):GetFrameLevel()) + 60)
    end
    for _, point in ipairs(points) do
        used = used + 1
        local pin = provider.pins[used] or createPin(canvas, map, layer)
        provider.pins[used] = pin
        local level = layer and layer:GetFrameLevel() + (entrancesOnly and 2 or 1) or canvas:GetFrameLevel() + 18
        pin:SetFrameLevel(level)
        configure(pin, point, provider.overview, provider.drawingMap)
        if not layer then pin:Show() end
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
    if not entrancesOnly then
        app.SecureCall(L("Weltkarte"), explore, provider, canvas, mapID, points)
        if provider.showLevels then levelMarkers(mapID, points) end
    end
    provider.points, provider.drawingMap = points, mapID
    layoutPins(provider, map, canvas, scale)
end

function world.SetMarkerLayerCovered(map, covered)
    local layer = markerLayers[map]
    if layer then layer:SetShown(not covered) end
end

function world.AttachPins(map, showLevels, entrancesOnly)
    if not (map.AddDataProvider and map.GetCanvas and MapCanvasDataProviderMixin and CreateFromMixins and C_Timer) then return end
    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    provider.pins, provider.tiles, provider.used, provider.tileCount = {}, {}, 0, 0
    provider.showLevels, provider.entrancesOnly = showLevels, entrancesOnly == true
    if map.ScrollContainer and (showLevels or entrancesOnly) then
        -- Keep addon markers independent of artwork, exploration textures and native pin visibility.
        local layer = markerLayers[map]
        if not layer then
            layer = CreateFrame("Frame", nil, map)
            layer:SetAllPoints(map.ScrollContainer)
            layer:EnableMouse(false)
            if layer.SetClipsChildren then layer:SetClipsChildren(true) end
            markerLayers[map] = layer
        end
        provider.layer = layer
        provider.OnCanvasPanChanged = placePins
    end
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
