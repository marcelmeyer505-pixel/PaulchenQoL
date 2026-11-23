local _, app = ...
local world, options, style, L = app.worldMap, app.comfort, app.style, app.L
local read, plain = app.ReadGameValue, app.Readable
local view, battlefield, queued

BINDING_HEADER_PAULCHENQOLMAP = "Paulchen QoL"
BINDING_NAME_PAULCHENQOLPLAYERMAP = L("Weltkarte am eigenen Standort öffnen")

local function settings()
    local db = app.Settings()
    if type(db.mapView) ~= "table" then db.mapView = {} end
    return db.mapView
end

local function canEdit()
    local combat, known = options.Read(InCombatLockdown)
    return known and not combat
end

local function number(value, minimum, maximum, default)
    if type(value) ~= "number" or value ~= value then return default end
    return math.min(maximum, math.max(minimum, value))
end

local function button(parent, name, x, width, action)
    local control = style.TextButton(parent)
    control:SetSize(width, 22)
    control:SetPoint("LEFT", parent, "LEFT", x, 0)
    control:SetText(L(name))
    control:SetScript("OnClick", action)
    return control
end

local function playerMapID()
    return C_Map and read(C_Map.GetBestMapForUnit, "player")
end

function PaulchenQoLOpenPlayerMap()
    if not canEdit() or not WorldMapFrame then return end
    if not WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
    world.Navigate(WorldMapFrame, playerMapID())
end

local function showZones(self, map)
    if not canEdit() or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local current = read(map.GetMapID, map)
    local continent, root = world.JumpContext(current)
    MenuUtil.CreateContextMenu(self, function(_, menu)
        if menu.SetScrollMode then menu:SetScrollMode(345) end
        local playerMap = playerMapID()
        if world.Info(playerMap) then
            menu:CreateButton(L("Zum eigenen Standort"), function() world.Navigate(map, playerMap) end)
        end
        if world.Info(root) then menu:CreateButton(world.Name(root, L("Weltkarte")), function() world.Navigate(map, root) end) end
        local continents = world.Children(root, world.types.Continent, false)
        for _, entry in ipairs(continents) do
            local branch = menu:CreateButton(entry.name)
            if branch.SetScrollMode then branch:SetScrollMode(320) end
            branch:CreateButton(L("Kontinentkarte öffnen"), function() world.Navigate(map, entry.id) end)
            local zones = world.Children(entry.id, world.types.Zone, true)
            for _, zone in ipairs(zones) do
                local range = options.Enabled("mapZoneLevels") and world.levels[zone.id]
                local title = range and ("%s · %d–%d"):format(zone.name, range[1], range[2]) or zone.name
                branch:CreateButton(title, function() world.Navigate(map, zone.id) end)
            end
        end
        for _, zone in ipairs(world.Children(root, world.types.Zone, false)) do
            menu:CreateButton(zone.name, function() world.Navigate(map, zone.id) end)
        end
        if continent then
            menu:CreateButton(L("Aktueller Kontinent"), function() world.Navigate(map, continent) end)
        end
    end)
end

local function showDiscovery(self, map)
    if not canEdit() or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local art, missing = world.Unexplored(read(map.GetMapID, map))
    MenuUtil.CreateContextMenu(self, function(_, menu)
        menu:CreateTitle(L("Unerforschte Teilgebiete"))
        if not art or #missing == 0 then
            menu:CreateTitle(L(art and "Dieses Gebiet ist vollständig erkundet." or "Für diese Karte liegen keine Erkundungsdaten vor."))
            return
        end
        if menu.SetScrollMode then menu:SetScrollMode(330) end
        for index, area in ipairs(missing) do
            local label = read(C_Map.GetAreaInfo, area[5]) or L("Unerforschtes Teilgebiet")
            local x, y = (area[1] + area[3] / 2) / art[1], (area[2] + area[4] / 2) / art[2]
            local position = app.LocalizeDecimal(("%.1f / %.1f"):format(x * 100, y * 100))
            menu:CreateTitle(("%d. %s · %s"):format(index, label, position))
        end
    end)
end

local function showLayout(self)
    if not canEdit() or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(self, function(_, menu)
        menu:CreateButton(L("Karteneinstellungen öffnen"), function() options.Open("Weltkarte & Erkundung") end)
        if options.Enabled("mapScale") then
            local branch = menu:CreateButton(L("Kartengröße"))
            for _, mode in ipairs({ { "windowScale", "Fenstermodus" }, { "fullScale", "Vollbild" } }) do
                local key = mode[1]
                local choices = branch:CreateButton(L(mode[2]))
                for _, scale in ipairs({ 70, 85, 100, 115, 130 }) do
                    choices:CreateRadio(scale .. " %", function() return (settings()[key] or 100) == scale end,
                        function() settings()[key] = scale; world.Refresh() end)
                end
            end
        end
        if options.Enabled("mapBattlefield") then
            local branch = menu:CreateButton(L("Schlachtfeldkarte"))
            for _, scale in ipairs({ 75, 100, 125, 150 }) do
                branch:CreateRadio(L("Größe") .. " · " .. scale .. " %", function()
                    return (settings().battleScale or 100) == scale
                end, function() settings().battleScale = scale; world.Refresh() end)
            end
            for _, alpha in ipairs({ 40, 65, 85, 100 }) do
                branch:CreateRadio(L("Deckkraft") .. " · " .. alpha .. " %", function()
                    return (settings().battleAlpha or 85) == alpha
                end, function() settings().battleAlpha = alpha; world.Refresh() end)
            end
            local icons = branch:CreateButton(L("Symbole auf der Schlachtfeldkarte"))
            for _, size in ipairs({ 100, 125, 150, 175 }) do
                icons:CreateRadio(size .. " %", function() return (settings().battleIcons or 100) == size end,
                    function() settings().battleIcons = size; world.Refresh() end)
            end
        end
        if options.Enabled("mapMove") or options.Enabled("mapScale") then
            menu:CreateButton(L("Kartenlayout zurücksetzen"), function()
                local db = settings()
                db.windowPosition, db.fullPosition, db.windowScale, db.fullScale = nil, nil, nil, nil
                view.positionMode = nil
                if view.map.SetUserPlaced then view.map:SetUserPlaced(false) end
                if view.map.SynchronizeDisplayState then view.map:SynchronizeDisplayState() end
                if UpdateUIPanelPositions then UpdateUIPanelPositions(view.map) end
                world.Refresh()
            end)
        end
    end)
end

local function coords(x, y)
    if not app.ValidMapPoint(x, y) then return "–" end
    return app.LocalizeDecimal(("%.1f / %.1f"):format(x * 100, y * 100))
end

local function syncTitanCoordinates(state, active)
    local function sync(region, covered)
        if not (region and region.GetAlpha and region.SetAlpha) then return end
        local previous = state.titanAlpha[region]
        if covered then
            local alpha = read(region.GetAlpha, region)
            if alpha and alpha ~= 0 then
                if previous == nil then state.titanAlpha[region] = alpha end
                region:SetAlpha(0)
            end
        elseif previous ~= nil then
            region:SetAlpha(previous)
            state.titanAlpha[region] = nil
        end
    end
    sync(_G.TitanMapPlayerLocation, active and options.Enabled("mapPlayerCoords"))
    sync(_G.TitanMapCursorLocation, active and options.Enabled("mapMouseCoords"))
end

local function updateFooter(state)
    local map, footer = state.map, state.footer
    local active = footer:IsVisible()
    syncTitanCoordinates(state, active)
    if not active then return end
    local id = read(map.GetMapID, map)
    if not id then return end
    local entries = {}
    if options.Enabled("mapPlayerCoords") then
        local x, y = world.Vector(read(C_Map.GetPlayerMapPosition, id, "player"))
        entries[#entries + 1] = L("Spieler") .. "  " .. coords(x, y)
    end
    if options.Enabled("mapMouseCoords") then
        local x, y
        if state.scroll:IsMouseOver() then x, y = read(map.GetNormalizedCursorPosition, map) end
        entries[#entries + 1] = L("Maus") .. "  " .. coords(x, y)
    end
    if options.Enabled("mapFishing") then
        local fishing = world.fishing[id]
        if fishing then entries[#entries + 1] = app.LF("Angeln · Grundfertigkeit etwa %d", fishing) end
    end
    footer.text:SetText(table.concat(entries, "     ·     "))
end

local function positionKey(map)
    return read(map.IsMaximized, map) and "fullPosition" or "windowPosition"
end

local function setFading(state, disabled)
    local fader, map = PlayerMovementFrameFader, state.map
    if not fader or not fader.AddDeferredFrame or not fader.RemoveFrame then return end
    if disabled then
        fader.RemoveFrame(map)
        map:SetAlpha(1)
    elseif state.noFade then
        fader.AddDeferredFrame(map, .5, 1, .5, function()
            return GetCVarBool and GetCVarBool("mapFade") and not map:IsMouseOver()
        end)
    end
    state.noFade = disabled
end

local function setScale(state)
    local map = state.map
    if options.Enabled("mapScale") then
        local key = read(map.IsMaximized, map) and "fullScale" or "windowScale"
        local wanted = number(settings()[key], 70, 130, 100) / 100
        local width, height = map:GetSize()
        if width > 0 and height > 0 then
            local fit = math.min((UIParent:GetWidth() - 12) / width, (UIParent:GetHeight() - 12) / height)
            map:SetScale(math.min(state.baseScale * wanted, fit))
        end
        state.scaled = true
    elseif state.scaled then
        map:SetScale(state.baseScale)
        state.scaled = nil
    end
end

local function compactFrame(state, compact)
    local map, border = state.map, state.map.BorderFrame
    local parts = { "TitleContainer", "TitleText", "PortraitContainer", "NineSlice", "Bg", "InsetBorderTop" }
    for _, name in ipairs(parts) do
        local part = border and border[name]
        if part and part.GetAlpha and part.SetAlpha then
            if compact then
                if state.alpha[part] == nil then state.alpha[part] = part:GetAlpha() end
                part:SetAlpha(0)
            elseif state.alpha[part] ~= nil then
                part:SetAlpha(state.alpha[part])
                state.alpha[part] = nil
            end
        end
    end
    local spacer = map.TitleCanvasSpacerFrame
    if not spacer or not map.OnFrameSizeChanged then return end
    local offset, y
    for index = 1, spacer:GetNumPoints() do
        local point, _, _, x, anchorY = spacer:GetPoint(index)
        if point == "BOTTOMRIGHT" then offset, y = x, anchorY; break end
    end
    if offset == nil then return end
    local target = compact and -49 or state.compacted and -67
    state.compacted = compact
    if target and y ~= target then
        spacer:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", offset, target)
        map:OnFrameSizeChanged()
    end
end

local function updateCities(state)
    for pin, original in pairs(state.hiddenCities) do
        pin:SetAlpha(original[1])
        pin:SetMouseMotionEnabled(original[2])
        pin:SetMouseClickEnabled(original[3])
        state.hiddenCities[pin] = nil
    end
    local map = state.map
    if not options.Enabled("mapHideCities") or not map.EnumeratePinsByTemplate then return end
    local info = world.Info(read(map.GetMapID, map))
    if not info or plain(info.mapType) ~= world.types.Continent then return end
    for pin in map:EnumeratePinsByTemplate("AreaPOIPinTemplate") do
        local poi = plain(pin.poiInfo)
        local atlas, texture = poi and plain(poi.atlasName), poi and plain(poi.textureIndex)
        atlas = type(atlas) == "string" and atlas:lower() or ""
        if (texture == 4 or texture == 5 or atlas == "poi-town" or atlas == "poi-city")
            and pin.IsMouseMotionEnabled and pin.IsMouseClickEnabled then
            state.hiddenCities[pin] = { pin:GetAlpha(), pin:IsMouseMotionEnabled(), pin:IsMouseClickEnabled() }
            pin:SetAlpha(0)
            pin:SetMouseMotionEnabled(false)
            pin:SetMouseClickEnabled(false)
        end
    end
end

local function updateView(state)
    local map = state.map
    if not map:IsVisible() then return end
    local compact = options.Enabled("mapCompact")
    local id = read(map.GetMapID, map)
    if canEdit() then
        compactFrame(state, compact)
        setScale(state)
        local movable = options.Enabled("mapMove")
        if movable ~= state.movable then
            state.movable = movable
            map:SetMovable(movable or state.baseMovable)
            if not movable and state.positionMode then
                if map.SetUserPlaced then map:SetUserPlaced(false) end
                if map.SynchronizeDisplayState then map:SynchronizeDisplayState() end
                if UpdateUIPanelPositions then UpdateUIPanelPositions(map) end
            end
            state.positionMode = nil
        end
        local key = positionKey(map)
        local saved = settings()[key]
        if movable and state.positionMode ~= key and type(saved) == "table" and type(saved[1]) == "string"
            and type(saved[2]) == "string" and type(saved[3]) == "number" and type(saved[4]) == "number" then
            map:ClearAllPoints()
            map:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
            state.positionMode = key
        end
    end
    if map.BlackoutFrame then
        if options.Enabled("mapNoBlackout") then
            map.BlackoutFrame:Hide()
            state.blackoutHidden = true
        elseif state.blackoutHidden then
            map.BlackoutFrame:SetShown(read(map.IsMaximized, map) == true)
            state.blackoutHidden = nil
        end
    end
    setFading(state, options.Enabled("mapNoFade"))
    updateCities(state)
    local hideReset = options.Enabled("mapHideReset")
    for _, child in ipairs({ map:GetChildren() }) do
        local reset = child.ResetButton
        if reset and reset.SetAlpha and reset.IsMouseEnabled then
            local previous = state.resetAlpha[reset]
            if hideReset and not previous then
                state.resetAlpha[reset] = { reset:GetAlpha(), reset:IsMouseEnabled() }
                reset:SetAlpha(0)
                reset:EnableMouse(false)
            elseif not hideReset and previous then
                reset:SetAlpha(previous[1])
                reset:EnableMouse(previous[2])
                state.resetAlpha[reset] = nil
            end
        end
    end

    local bar = state.header
    if state.compactHeader ~= compact then
        state.compactHeader = compact
        bar:ClearAllPoints()
        if compact then
            bar:SetPoint("TOPLEFT", map, "TOPLEFT", 3, -4)
            bar:SetPoint("TOPRIGHT", map, "TOPRIGHT", -65, -4)
        else
            bar:SetPoint("BOTTOMLEFT", state.scroll, "BOTTOMLEFT", 5, 31)
            bar:SetPoint("BOTTOMRIGHT", state.scroll, "BOTTOMRIGHT", -5, 31)
        end
    end
    local navigation, discovery = options.Enabled("mapZoneMenu"), options.Enabled("mapDiscovery")
    bar:SetShown(compact or navigation or discovery or options.Enabled("mapMove") or options.Enabled("mapScale")
        or options.Enabled("mapBattlefield"))
    bar.zones:SetShown(navigation)
    bar.discovery:SetShown(discovery)
    if state.zonesVisible ~= navigation or state.discoveryVisible ~= discovery then
        state.zonesVisible, state.discoveryVisible = navigation, discovery
        local x = navigation and 278 or 196
        bar.discovery:ClearAllPoints()
        bar.discovery:SetPoint("LEFT", bar, "LEFT", x, 0)
        bar.layout:ClearAllPoints()
        bar.layout:SetPoint("LEFT", bar, "LEFT", x + (discovery and 98 or 0), 0)
    end
    bar.title:SetText(world.Name(id, L("Weltkarte")))
    local footer = state.footer
    local showBackground = options.Enabled("mapCoordsBackground")
    footer:SetBackdropColor(style.background[1], style.background[2], style.background[3], showBackground and .98 or 0)
    footer:SetBackdropBorderColor(style.edge[1], style.edge[2], style.edge[3], showBackground and 1 or 0)
    footer:SetShown(options.Enabled("mapMouseCoords") or options.Enabled("mapPlayerCoords") or options.Enabled("mapFishing"))
    updateFooter(state)
end

local function attach()
    local map = WorldMapFrame
    if view or not (map and map.ScrollContainer and map.GetMapID and map.GetSize and C_Map) then return end
    local canvas = map.ScrollContainer
    view = { map = map, scroll = canvas, baseScale = map:GetScale(), baseMovable = map:IsMovable(),
        alpha = {}, resetAlpha = {}, titanAlpha = {}, hiddenCities = setmetatable({}, { __mode = "k" }) }
    local state = view
    local header = CreateFrame("Frame", nil, map, "BackdropTemplate")
    header:SetHeight(23)
    header:SetFrameStrata("HIGH")
    header:SetFrameLevel((map.BorderFrame or map):GetFrameLevel() + 3)
    style.Panel(header, style.header, style.accent)
    state.header = header
    header.title = style.Label(header, "", 8, 0, 183, 22, "GameFontNormal", style.gold)
    header.zones = button(header, "Gebiete", 196, 77, function(self) showZones(self, map) end)
    header.discovery = button(header, "Erkundung", 278, 93, function(self) showDiscovery(self, map) end)
    header.layout = button(header, "Kartenoptionen", 376, 112, showLayout)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if options.Enabled("mapMove") and canEdit() then
            state.dragging = true
            map:StartMoving()
        end
    end)
    header:SetScript("OnDragStop", function()
        if not state.dragging then return end
        state.dragging = nil
        map:StopMovingOrSizing()
        local point, _, relativePoint, x, y = map:GetPoint()
        if point and relativePoint and x and y then
            local key = positionKey(map)
            settings()[key] = { point, relativePoint, x, y }
            state.positionMode = key
        end
    end)

    local footer = CreateFrame("Frame", nil, map, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 5, 4)
    footer:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -37, 4)
    footer:SetHeight(21)
    footer:SetFrameStrata("HIGH")
    footer:SetFrameLevel(header:GetFrameLevel())
    style.Panel(footer, style.background)
    footer.text = style.Label(footer, "", 8, 0, 700, 21, "GameFontHighlightSmall", style.cream)
    footer.text:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -8, 0)
    state.footer = footer
    local elapsed = 0
    footer:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.10 then elapsed = 0; updateFooter(state) end
    end)

    map:HookScript("OnShow", function()
        state.positionMode = nil
        world.Refresh()
    end)
    map:HookScript("OnHide", function()
        syncTitanCoordinates(state, false)
        if state.dragging then map:StopMovingOrSizing(); state.dragging = nil end
    end)
    if hooksecurefunc then
        for _, method in ipairs({ "OnMapChanged", "SynchronizeDisplayState", "UpdateSpacerFrameAnchoring" }) do
            if type(map[method]) == "function" then hooksecurefunc(map, method, world.Refresh) end
        end
    end
    state.pins = world.AttachPins(map, true)
end

local function attachBattlefield()
    local map = BattlefieldMapFrame
    if battlefield or not options.Enabled("mapBattlefield") or not (map and map.AddDataProvider and map.GetScale) then return end
    battlefield = { map = map, scale = map:GetScale() }
    battlefield.pins = world.AttachPins(map, false)
    map:HookScript("OnShow", world.Refresh)
    if hooksecurefunc and map.UpdateUnitsVisibility then hooksecurefunc(map, "UpdateUnitsVisibility", world.Refresh) end
end

local function refreshBattlefield()
    if not battlefield then return end
    local map = battlefield.map
    local enabled = options.Enabled("mapBattlefield")
    local data = settings()
    local wasEnabled = battlefield.enabled
    if enabled then
        map:SetScale(battlefield.scale * number(data.battleScale, 75, 150, 100) / 100)
        local alpha = number(data.battleAlpha, 40, 100, 85) / 100
        if map.SetGlobalAlpha then map:SetGlobalAlpha(alpha) end
        if map.BorderFrame then map.BorderFrame:SetAlpha(alpha) end
    elseif wasEnabled then
        map:SetScale(battlefield.scale)
        if map.RefreshAlpha then map:RefreshAlpha() end
    end
    local groups = map.groupMembersDataProvider
    if groups and groups.SetUnitPinSize and (enabled or wasEnabled) then
        local scale = enabled and number(data.battleIcons, 100, 175, 100) / 100 or 1
        groups:SetUnitPinSize("player", (BATTLEFIELD_MAP_PLAYER_SIZE or 14) * scale)
        local showGroups = not BattlefieldMapOptions or BattlefieldMapOptions.showPlayers
        groups:SetUnitPinSize("party", showGroups and (BATTLEFIELD_MAP_PARTY_MEMBER_SIZE or 12) * scale or 0)
        groups:SetUnitPinSize("raid", showGroups and (BATTLEFIELD_MAP_RAID_MEMBER_SIZE or 10) * scale or 0)
    end
    battlefield.enabled = enabled
    if battlefield.pins then battlefield.pins:RefreshAllData() end
end

function world.Refresh()
    if queued or not C_Timer or not C_Timer.After then return end
    queued = true
    C_Timer.After(0, function()
        queued = nil
        if view then
            app.SecureCall(L("Weltkarte"), updateView, view)
            if view.pins then view.pins:RefreshAllData() end
        end
        app.SecureCall(L("Schlachtfeldkarte"), refreshBattlefield)
    end)
end

function world.SettingsChanged()
    world.UpdateCrossings()
    attachBattlefield()
    world.Refresh()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "TAXI_NODE_STATUS_CHANGED",
    "MAP_EXPLORATION_UPDATED", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
    app.RegisterSupported(events, event)
end
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" and name == "Blizzard_WorldMap" then
        if event == "PLAYER_LOGIN" then
            world.UpdateCrossings()
            attachBattlefield()
        end
        attach()
    elseif event == "ADDON_LOADED" then
        if name == "Blizzard_BattlefieldMap" then attachBattlefield()
        elseif name ~= "ForeverDungeonJournal" and name ~= "ForeverDungeonRoutes" then return end
    end
    world.Refresh()
end)
