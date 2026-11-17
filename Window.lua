local _, app = ...

local width, height, headerHeight, rowHeight, rowCount = 680, 624, 40, 32, 8
local compactHeaderHeight = 30
local style = app.style
local backgrounds = style.rowColors
local cream, muted = style.cream, style.muted
local gold, green, orange = style.gold, style.green, style.orange
local parchment, ink = { 0.94, 0.84, 0.68 }, { 0.20, 0.11, 0.07 }
local groupLabels = { { "all", "Alle Taschen" }, { "keep", "Behalten" }, { "auction", "AH" }, { "vendor", "Händler" } }
local pageTabs = {
    { "travel", "Reise & Taschen", 141, 105, 8, 100 },
    { "logbook", app.logbookLabel, 252, 71, 112, 59 },
    { "upgrades", "Upgrades", 329, 81, 175, 65 },
}
local db, dashboard, travelPage, travel
local items, group, query, offset = {}, "all", "", 0
local pendingItems = {}
local cheapest, bagMarker, bagWatcher
local refresh
local merchant, refreshQueued = false, false

local panel, texture, portrait = style.Panel, style.Fill, style.Portrait

local function label(parent, value, x, y, w, h, font, color, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    text:SetPoint("TOPLEFT", x, y)
    text:SetSize(w, h)
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    text:SetTextColor(unpack(color or cream))
    text:SetText(value)
    return text
end

local function button(parent, caption, x, y, w, h)
    local control = style.Button(parent)
    control:SetPoint("TOPLEFT", x, y)
    control:SetSize(w, h)
    control.text = label(control, caption, 4, 0, w - 8, h, "GameFontHighlightSmall", cream, "CENTER")
    return control
end

local function speaker(parent, x, y, w, h)
    local bubble = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bubble:SetPoint("TOPLEFT", x, y)
    bubble:SetSize(w, h)
    panel(bubble, parchment, { 0.71, 0.49, 0.28, 1 })
    local tail = bubble:CreateTexture(nil, "ARTWORK")
    tail:SetColorTexture(parchment[1], parchment[2], parchment[3], 1)
    tail:SetSize(16, 16)
    tail:SetPoint("LEFT", -7, 2)
    tail:SetRotation(math.pi / 4)
    local speech = label(bubble, "", 16, -8, w - 31, h - 16, "GameFontHighlight", ink)
    speech:SetWordWrap(true)
    speech:SetShadowColor(0, 0, 0, 0)
    return speech, bubble
end

local function readTravel()
    travel = app.ReadTravel()
    app.ObserveTravel(travel)
end

local function hearthText(info)
    if not info.hasHearth then return "Fehlt in den Taschen", muted end
    local seconds = math.max(0, math.ceil((info.readyAt or 0) - GetTime()))
    if seconds == 0 then return "Bereit", green end
    return ("%d:%02d min"):format(math.floor(seconds / 60), seconds % 60), gold
end

local function coinText(copper)
    return ("%d G %02d S %02d K"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function paintTravel()
    if not travelPage or not travelPage:IsVisible() or not travel then return end
    local _, warning = app.TravelWarning(travel)
    local art, comment = app.DialogueView()
    local speech = "Reise-Check bereit."
    local destination, flightTime = app.FlightInfo()
    if destination then
        speech = destination .. "\n" .. flightTime
    elseif comment then
        speech = comment
    elseif merchant then
        local _, count, total = app.FindItems(items, db.marks, "vendor", "")
        if count > 0 then
            speech = ("Beim Händler sind %d Stück vorgemerkt. Das gibt ungefähr %s."):format(count, coinText(total))
        else
            speech = "Du bist beim Händler. Unter „Händler“ liegen deine Verkaufsvormerkungen."
        end
    elseif warning then
        speech = warning
        if cheapest then
            speech = ("Taschen voll. Günstigster Stapel: %d × %s (%s beim Händler).")
                :format(cheapest.count, cheapest.item.name, coinText(cheapest.value))
        end
    end
    local profile = app.Profile()
    travelPage.avatar:SetTexture(app.artPath .. art .. ".tga")
    travelPage.speechFrame:SetShown(profile.bubbles)
    travelPage.speech:SetText(app.WithCompanionReminders(speech))
    travelPage.bags.value:SetText(travel.free .. " / " .. travel.capacity .. " frei")
    travelPage.bags.value:SetTextColor(unpack(travel.capacity > 0 and travel.free <= 4 and orange or cream))
    travelPage.durability.value:SetText(travel.durability and math.floor(travel.durability) .. " %" or "—")
    travelPage.durability.value:SetTextColor(unpack(travel.durability and travel.durability <= 30 and orange or cream))
    local hearth, color = hearthText(travel)
    travelPage.hearth.value:SetText(hearth)
    travelPage.hearth.value:SetTextColor(unpack(color))
    travelPage.hearth.detail:SetText(travel.bind or "Heimatort")
end

app.RefreshDashboardDialogue = paintTravel

local function paintStatus()
    local destination, flightTime = app.FlightInfo()
    if destination then
        app.SetCompanionStatus("Flug · " .. destination, flightTime)
    elseif cheapest then
        app.SetCompanionStatus("Günstigster Stapel: " .. cheapest.item.name,
            "Händlerwert · " .. coinText(cheapest.value))
    elseif merchant and db then
        local marked = app.FindItems(items, db.marks, "vendor", "")
        app.SetCompanionStatus(#marked > 0 and "Der Händler ist da. Deine Vormerkungen warten." or nil)
    else
        app.SetCompanionStatus()
    end
end

function app.FlightChanged()
    paintTravel()
    paintStatus()
end

local function paintItems(reset)
    if not travelPage or not travelPage:IsVisible() then return end
    if reset then offset = 0 end
    local list, vendorCount, vendorTotal = app.FindItems(items, db.marks, group, query)
    local maxOffset = math.max(0, #list - rowCount)
    offset = math.min(offset, maxOffset)
    travelPage.slider:SetMinMaxValues(0, math.max(1, maxOffset))
    travelPage.slider:SetValue(offset)
    travelPage.slider:SetShown(maxOffset > 0)
    for index, row in ipairs(travelPage.rows) do
        local item = list[offset + index]
        if item ~= row.item and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        row.item = item
        row:SetShown(item ~= nil)
        row.lowest:SetShown(item ~= nil and cheapest ~= nil and cheapest.item.key == item.key)
        if item then
            row.icon:SetTexture(item.icon)
            row.itemName:SetText(item.name)
            local quality = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
            if quality then row.itemName:SetTextColor(quality.r, quality.g, quality.b) else row.itemName:SetTextColor(unpack(cream)) end
            row.count:SetText(tostring(item.count))
            local mark = app.marks[db.marks[item.key]]
            row.tag.text:SetText(mark and mark[1] or "Markieren")
            row.tag.text:SetTextColor(unpack(mark and mark[2] or muted))
        end
    end
    for key, tab in pairs(travelPage.tabs) do
        style.SetButtonState(tab, key == group)
        tab.text:SetTextColor(unpack(key == group and gold or muted))
    end
    travelPage.empty:SetShown(#list == 0)
    travelPage.empty:SetText(query ~= "" and "Keine Treffer für deine Suche."
        or group ~= "all" and "Hier liegt aktuell nichts Vorgemerktes in deinen Taschen."
        or "Deine Taschen sind leer.")
    local status = ("%d Gegenstandsarten"):format(#list)
    if group == "vendor" and vendorCount > 0 then
        status = status .. ("  ·  %d verkaufbare Stück  ·  %s"):format(vendorCount, coinText(vendorTotal))
    end
    travelPage.listStatus:SetText(status)
end

local function chooseGroup(key)
    group = key
    paintItems(true)
end

local function markItem(item, key)
    db.marks[item.key] = key
    refresh()
end

local function createRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", 18, -278 - (index - 1) * rowHeight)
    row:SetSize(624, rowHeight - 1)
    texture(row, "BACKGROUND", unpack(backgrounds[(index % 2) + 1]))
    row.lowest = row:CreateTexture(nil, "OVERLAY")
    row.lowest:SetPoint("TOPLEFT")
    row.lowest:SetPoint("BOTTOMLEFT")
    row.lowest:SetWidth(3)
    row.lowest:SetColorTexture(orange[1], orange[2], orange[3], 1)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.itemName = label(row, "", 37, 0, 393, 31)
    row.count = label(row, "", 434, 0, 49, 31, "GameFontHighlightSmall", muted, "RIGHT")
    row.tag = button(row, "Markieren", 504, -3, 111, 25)
    row.tag:SetScript("OnClick", function(owner)
        local item = row.item
        if not item then return end
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        GameTooltip:Hide()
        MenuUtil.CreateContextMenu(owner, function(_, menu)
            menu:CreateTitle(item.name)
            for _, key in ipairs(app.markOrder) do
                menu:CreateRadio(app.marks[key][1], function() return db.marks[item.key] == key end,
                    function() markItem(item, key) end)
            end
            menu:CreateRadio("Ohne Markierung", function() return not db.marks[item.key] end, function() markItem(item, nil) end)
        end)
    end)
    row:SetScript("OnEnter", function(self)
        if not self.item or GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetHyperlink, GameTooltip, self.item.link) then GameTooltip:SetText(self.item.name) end
        if cheapest and cheapest.item.key == self.item.key then
            GameTooltip:AddLine(("Günstigster Stapel · %d Stück · %s Händlerwert"):format(cheapest.count, coinText(cheapest.value)), unpack(orange))
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    return row
end

local function travelCard(parent, x, title, subtitle)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", x, -127)
    card:SetSize(208, 65)
    panel(card, { 0.15, 0.105, 0.077 })
    label(card, title, 11, -5, 187, 16, "GameFontHighlightSmall", gold)
    card.value = label(card, "", 11, -23, 187, 20, "GameFontNormalLarge", cream)
    card.detail = label(card, subtitle, 11, -45, 187, 14, "GameFontHighlightSmall", muted)
    return card
end

local function visibleSlot()
    local bagnonFrames = Bagnon and Bagnon.Frames
    local inventory = bagnonFrames and bagnonFrames.Get and bagnonFrames:Get("inventory")
    if inventory and inventory.IsVisible and inventory:IsVisible() then
        if inventory:IsCached() then return end
        local grid = inventory.ItemGroup
        local slots = grid and grid.byBag and grid.byBag[cheapest.bag]
        return slots and slots[cheapest.slot]
    end

    for i = 0, NUM_CONTAINER_FRAMES or 13 do
        local frame = i == 0 and ContainerFrameCombinedBags or i > 0 and _G["ContainerFrame" .. i]
        if frame and frame:IsVisible() and frame.EnumerateValidItems then
            for _, button in frame:EnumerateValidItems() do
                if button:GetBagID() == cheapest.bag and button:GetID() == cheapest.slot then return button end
            end
        end
    end
end

local function paintBagMarker()
    local slot = cheapest and app.StackStillThere(cheapest) and visibleSlot()
    if slot and not slot:IsForbidden() and slot:IsVisible() then
        if bagMarker.slot ~= slot then
            bagMarker:ClearAllPoints()
            bagMarker:SetPoint("TOPLEFT", slot, "TOPLEFT", -1, 1)
            bagMarker:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 1, -1)
            bagMarker:SetFrameStrata(slot:GetFrameStrata())
            bagMarker:SetFrameLevel(slot:GetFrameLevel() + 5)
            bagMarker.slot = slot
        end
        bagMarker:Show()
    else
        bagMarker:Hide()
        if bagMarker.slot then
            bagMarker:ClearAllPoints()
            bagMarker.slot = nil
        end
    end
end

local function updateBagMarker()
    if cheapest and not bagWatcher then
        bagMarker = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        bagMarker:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        bagMarker:SetBackdropBorderColor(1, 0.48, 0.14, 1)
        bagMarker:EnableMouse(false)
        bagWatcher = CreateFrame("Frame", nil, UIParent)
        local elapsed = 0
        bagWatcher:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed >= 0.15 then
                elapsed = 0
                paintBagMarker()
            end
        end)
    end
    if bagWatcher then
        bagWatcher:SetShown(cheapest ~= nil)
        paintBagMarker()
    end
end

refresh = function()
    readTravel()
    local open = travelPage and travelPage:IsVisible()
    local full = travel.capacity > 0 and travel.free == 0
    cheapest = nil
    if open or merchant or full then
        items, pendingItems, cheapest = app.ReadBags(full and db.marks or nil)
    else
        pendingItems = {}
    end
    if open then
        paintTravel()
        paintItems()
    end
    updateBagMarker()
    paintStatus()
end

local function createTravelPage(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:Hide()
    f:SetSize(width, height - headerHeight)
    travelPage = f
    local bird = CreateFrame("Button", nil, f)
    bird:SetPoint("TOPLEFT", 16, -4)
    bird:SetSize(128, 118)
    f.avatar = portrait(bird, 121, 0, 0)
    bird:SetScript("OnClick", app.TestComment)
    f.speech, f.speechFrame = speaker(f, 151, -18, 511, 84)
    f.bags = travelCard(f, 18, "Taschenplätze", "Allgemeine Taschen")
    f.durability = travelCard(f, 236, "Haltbarkeit", "Niedrigster Ausrüstungswert")
    f.hearth = travelCard(f, 454, "Ruhestein", "Heimatort")

    label(f, "Taschen-Merkliste", 18, -203, 260, 27, "GameFontNormalLarge", gold)
    local search = style.EditBox(f, GameFontHighlight)
    search:SetPoint("TOPLEFT", 362, -204)
    search:SetSize(300, 27)
    search:SetTextInsets(8, 8, 0, 0)
    search:SetMaxLetters(100)
    local prompt = label(search, "Name oder Markierung suchen", 8, 0, 281, 27, "GameFontHighlightSmall", muted)
    search:SetScript("OnTextChanged", function(self)
        query = self:GetText()
        prompt:SetShown(query == "")
        paintItems(true)
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.search = search
    f.tabs = {}
    for index, tab in ipairs(groupLabels) do
        local key, caption = unpack(tab)
        local control = button(f, caption, 18 + (index - 1) * 90, -238, 85, 25)
        control:SetScript("OnClick", function() chooseGroup(key) end)
        f.tabs[key] = control
    end
    f.merchant = label(f, "Händler geöffnet", 390, -238, 272, 25, "GameFontHighlightSmall", gold, "RIGHT")
    f.merchant:Hide()

    f.rows = {}
    for index = 1, rowCount do f.rows[index] = createRow(f, index) end
    local slider = CreateFrame("Slider", nil, f)
    slider:SetPoint("TOPLEFT", 648, -278)
    slider:SetSize(14, rowCount * rowHeight - 1)
    slider:SetOrientation("VERTICAL")
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    texture(slider, "BACKGROUND", unpack(style.track))
    slider:SetScript("OnValueChanged", function(_, value)
        local nextOffset = math.floor(value + 0.5)
        if nextOffset ~= offset then offset = nextOffset; paintItems() end
    end)
    f.slider = slider
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - 3 * delta)
        paintItems()
    end)
    f.empty = label(f, "", 18, -350, 624, 45, "GameFontHighlight", muted, "CENTER")
    f.listStatus = label(f, "", 18, -543, 624, 25, "GameFontHighlightSmall", muted)

    local elapsed = 0
    f:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 1 or not travel then return end
        elapsed = 0
        local text, color = hearthText(travel)
        f.hearth.value:SetText(text)
        f.hearth.value:SetTextColor(unpack(color))
    end)
    f:SetScript("OnShow", function()
        f.merchant:SetShown(merchant)
        if merchant then
            group, offset = "vendor", 0
            search:SetText("")
        end
        app.SecureCall("Taschen und Reise-Check", refresh)
    end)
    f:SetScript("OnHide", function()
        search:ClearFocus()
    end)
    return f
end

function app.DashboardScale(pageWidth, pageHeight, titleHeight)
    return math.min(1, (UIParent:GetWidth() - 20) / pageWidth,
        (UIParent:GetHeight() - 20) / (pageHeight + (titleHeight or headerHeight)))
end

local function layoutHeader(f, compact, titleHeight)
    if f.compactHeader == compact then return end
    f.compactHeader = compact
    f.header:SetHeight(titleHeight - 1)
    f.body:ClearAllPoints()
    f.body:SetPoint("TOPLEFT", 0, -titleHeight)
    f.body:SetPoint("BOTTOMRIGHT")
    f.title:SetShown(not compact)
    f.companionCheck:SetShown(not compact)
    local closeSize = compact and 26 or 32
    f.close:SetSize(closeSize, closeSize)

    for _, definition in ipairs(pageTabs) do
        local key, _, x, w, compactX, compactWidth = unpack(definition)
        local tab = f.pageTabs[key]
        local tabWidth = compact and compactWidth or w
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", compact and compactX or x, compact and -2 or -7)
        tab:SetWidth(tabWidth)
        tab.text:SetWidth(tabWidth - 8)
    end

    local settingsWidth = compact and 66 or 117
    f.settings:SetWidth(settingsWidth)
    f.settings.text:SetWidth(settingsWidth - 8)
    f.settings.text:SetText(compact and "Optionen" or "Einstellungen")
end

function app.LayoutDashboard()
    if not dashboard or not dashboard.page then return end
    local page = dashboard.pages[dashboard.page]
    local pageWidth, pageHeight = page:GetWidth() * page:GetScale(), page:GetHeight() * page:GetScale()
    local compact = dashboard.page == "logbook" and pageWidth < width
    local windowWidth = compact and pageWidth or math.max(width, pageWidth)
    local titleHeight = compact and compactHeaderHeight or headerHeight
    dashboard:SetSize(windowWidth, pageHeight + titleHeight)
    dashboard:SetScale(app.DashboardScale(windowWidth, pageHeight, titleHeight))
    layoutHeader(dashboard, compact, titleHeight)
end

local function unavailablePage(parent, message)
    local page = CreateFrame("Frame", nil, parent)
    page:Hide()
    page:SetSize(width, 135)
    label(page, message, 17, -27, width - 34, 52, "GameFontHighlight", cream, "CENTER")
    return page
end

local function selectPage(f, key)
    if f.page == key then return end
    local page = f.pages[key]
    if not page then
        if key == "travel" then
            page = createTravelPage(f.body)
        elseif key == "logbook" then
            page = app.timeline and app.timeline.GetPage and app.timeline.GetPage(f.body)
                or unavailablePage(f.body, "Öffne das installierte Logbuch mit /dtl.")
        elseif key == "upgrades" then
            if app.upgrades and app.upgrades.GetPage then
                page = app.upgrades.GetPage(f.body)
            else
                local message = SlashCmdList.PAULCHENUPGRADES and "Öffne das installierte Upgrade-Fenster mit /pu."
                    or "Aktiviere Polestar für die Ausrüstungsbewertung."
                page = unavailablePage(f.body, message)
            end
        end
        page:SetPoint("TOP", f.body, "TOP")
        f.pages[key] = page
    end
    if f.page then f.pages[f.page]:Hide() end
    f.page = key
    for name, tab in pairs(f.pageTabs) do
        local selected = name == key
        style.SetButtonState(tab, selected)
        tab.text:SetTextColor(unpack(selected and gold or cream))
    end
    app.LayoutDashboard()
    page:Show()
end

local function createDashboard()
    local f = CreateFrame("Frame", "PaulchenQoLFrame", UIParent, "BackdropTemplate")
    f:Hide()
    f:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 0)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    panel(f, style.background)
    table.insert(UISpecialFrames, f:GetName())

    local header = CreateFrame("Frame", nil, f)
    f.header = header
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    texture(header, "BACKGROUND", unpack(style.header))
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local x, y = f:GetCenter()
        local cx, cy = UIParent:GetCenter()
        local scale = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
        db.x, db.y = x - cx / scale, y - cy / scale
    end)
    f.title = label(header, "Paulchen QoL", 17, -2, 116, 37, "GameFontNormalLarge", gold)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() f:Hide() end)
    f.close = close

    f.body = CreateFrame("Frame", nil, f)
    f.pages, f.pageTabs = {}, {}
    for _, definition in ipairs(pageTabs) do
        local key, caption, x, w = unpack(definition)
        local tab = button(header, caption, x, -7, w, 25)
        tab:SetScript("OnClick", function() selectPage(f, key) end)
        f.pageTabs[key] = tab
    end

    local settings = button(header, "Einstellungen", 0, -7, 117, 25)
    settings:ClearAllPoints()
    settings:SetPoint("RIGHT", header, "RIGHT", -40, 0)
    settings:SetScript("OnClick", app.OpenConfig)
    f.settings = settings
    local companionCheck = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
    companionCheck:SetPoint("RIGHT", settings, "LEFT", -76, 0)
    companionCheck:SetSize(24, 24)
    companionCheck:SetChecked(app.Profile().show)
    label(companionCheck, "Begleiter", 26, 0, 65, 24, "GameFontHighlightSmall", cream)
    companionCheck:SetScript("OnClick", function(self)
        app.SetProfile("show", not not self:GetChecked())
    end)
    f.companionCheck = companionCheck

    f:SetScript("OnShow", function() app.SetDashboardOpen(true) end)
    f:SetScript("OnHide", function() app.SetDashboardOpen(false) end)
    return f
end

function app.OpenDashboard(page)
    if not db then return end
    dashboard = dashboard or createDashboard()
    selectPage(dashboard, page or dashboard.page or "travel")
    dashboard:Show()
end

function app.CloseDashboard(page)
    if dashboard and (not page or page == dashboard.page) then dashboard:Hide() end
end

function app.ToggleDashboard(page)
    if dashboard and dashboard:IsShown() and (not page or page == dashboard.page) then
        app.CloseDashboard(page)
    else
        app.OpenDashboard(page)
    end
end

function app.RefreshDashboardSettings()
    if dashboard then dashboard.companionCheck:SetChecked(app.Profile().show) end
end

local function createMinimap()
    local icon = CreateFrame("Button", "PaulchenQoLMinimapButton", Minimap)
    icon:SetSize(31, 31)
    icon:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    icon:RegisterForDrag("LeftButton")
    local background = icon:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("CENTER")
    background:SetSize(25, 25)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    portrait(icon, 25, 3, -3)
    local border = icon:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    icon:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local function place()
        local angle = db.minimapAngle or 3.6
        local x, y = math.cos(angle), math.sin(angle)
        if GetMinimapShape and GetMinimapShape() == "SQUARE" then
            local side = math.max(math.abs(x), math.abs(y))
            x, y = x / side, y / side
        end
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth() / 2 + 4), y * (Minimap:GetHeight() / 2 + 4))
    end
    icon:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            if not cx or not cy then return end
            local scale = Minimap:GetEffectiveScale()
            db.minimapAngle = math.atan2(y / scale - cy, x / scale - cx)
            place()
        end)
    end)
    icon:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    icon:SetScript("OnClick", function(self, button)
        if button == "RightButton" then app.OpenModulesMenu(self) else app.ToggleDashboard() end
    end)
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Paulchen QoL", unpack(gold))
        local destination, flightTime = app.FlightInfo()
        if destination then
            GameTooltip:AddLine(destination .. "  ·  " .. flightTime, unpack(gold))
        end
        if travel then
            local hearth = hearthText(travel)
            GameTooltip:AddLine("Taschen · " .. travel.free .. " freie Plätze", unpack(cream))
            if travel.durability then GameTooltip:AddLine("Haltbarkeit · " .. math.floor(travel.durability) .. " %", unpack(cream)) end
            GameTooltip:AddLine("Ruhestein · " .. hearth, unpack(cream))
        end
        GameTooltip:AddLine("Linksklick · Paulchen öffnen  |  Rechtsklick · Schnellzugriff", unpack(muted))
        GameTooltip:AddLine("Ziehen · Verschieben", unpack(muted))
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    place()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN",
    "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED", "HEARTHSTONE_BOUND", "PLAYER_REGEN_ENABLED",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "ITEM_DATA_LOAD_RESULT", "ITEM_LOCK_CHANGED", "QUEST_LOG_UPDATE" }) do
    app.RegisterSupported(events, event)
end
events:SetScript("OnEvent", function(_, event, id, success)
    if event == "PLAYER_LOGIN" then
        db = app.Settings()
        SLASH_PAULCHENQOL1 = "/pqol"
        SlashCmdList.PAULCHENQOL = function() app.ToggleDashboard() end
        createMinimap()
    elseif not db then
        return
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        app.LayoutDashboard()
        return
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
        merchant = event == "MERCHANT_SHOW"
        if travelPage and travelPage:IsVisible() then
            travelPage.merchant:SetShown(merchant)
            if merchant then
                travelPage.search:SetText("")
                chooseGroup("vendor")
            end
        end
        refresh()
        return
    elseif event == "ITEM_DATA_LOAD_RESULT" and (not success or not pendingItems[id]) then
        return
    end
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.1, function()
        refreshQueued = false
        app.SecureCall("Taschen und Reise-Check", refresh)
    end)
end)
