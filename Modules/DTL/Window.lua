local _, suite = ...
local addon = suite.timeline
if not addon then return end
local style = suite.style
local addonName = "Details_CombatTimeline"
local details = Details
local limit = addon.limit
local rowHeight = 21
local width = 352
local firstRow = 91
local fullHeight, miniHeight = firstRow + 8 + limit * rowHeight, 26
local barTexture = "Interface\\Buttons\\WHITE8X8"
local page, miniWindow, average, comparison, empty, rows
local showExperiencePage, renderProfiles
local compactButton, miniButtons, latestDps, meanDps
local farmToggle, farmStop
local views, tabs = {}, {}
local pendingTimer, retries

local function label(parent, template, point, relativePoint, x, y)
    local font = parent:CreateFontString(nil, "OVERLAY", template)
    font:SetPoint(point, parent, relativePoint, x, y)
    local color = template:find(suite.L("Normal"), 1, true) and style.gold
        or (template == "GameFontDisableSmall" and style.muted or style.cream)
    font:SetTextColor(unpack(color))
    return font
end

local function formatDps(dps)
    return dps and BreakUpLargeNumbers(math.floor(dps + 0.5)) or "–"
end

local function fightName(name)
    if name == "Kampf" or name == "Fight" then return suite.L("Kampf") end
    local id = name:match("^Kampf #(%d+)$") or name:match("^Fight #(%d+)$")
    return id and suite.LF("Kampf #%d", tonumber(id)) or name
end

local function formatDuration(duration)
    if not duration then
        return "–"
    end
    local seconds = math.floor(duration + 0.5)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function setComparison(latest, sum, count)
    comparison:SetTextColor(unpack(style.muted))
    if not latest or latest.dps == nil then
        comparison:SetText(latest and suite.L("Letzter Kampf · DPS fehlen") or "")
    elseif count == 0 then
        comparison:SetText(suite.L("Letzter Kampf · warte auf frühere DPS"))
    elseif sum == 0 then
        comparison:SetText(suite.L("Letzter Kampf · Ø davor war 0 DPS"))
    else
        local percent = (latest.dps / (sum / count) - 1) * 100
        if percent >= 0.05 then
            comparison:SetTextColor(unpack(style.green))
        elseif percent <= -0.05 then
            comparison:SetTextColor(unpack(style.orange))
        else
            percent = 0
        end
        local delta = suite.LocalizeDecimal(("%+.1f"):format(percent))
        if percent == 0 then
            delta = suite.LocalizeDecimal("0.0")
        end
        comparison:SetText((suite.L("Letzter Kampf  %s %% zum Ø davor")):format(delta))
    end
end

local function render()
    local history = PaulchenQoLTimelineDB.history
    addon.TrackOpponentFights(history)
    if PaulchenQoLTimelineDB.view == "profiles" then renderProfiles() end
    local sum, count, highest = 0, 0, 0
    local priorSum, priorCount = 0, 0
    for index, fight in ipairs(history) do
        if fight.dps then
            sum = sum + fight.dps
            count = count + 1
            highest = math.max(highest, fight.dps)
            if index > 1 then
                priorSum = priorSum + fight.dps
                priorCount = priorCount + 1
            end
        end
    end
    local mean = count > 0 and sum / count or nil
    latestDps, meanDps = history[1] and history[1].dps, mean
    local value = formatDps(mean)
    if count < #history then
        average:SetText((suite.L("Ø %s DPS  |cffbaa894· %d/%d mit DPS|r")):format(value, count, #history))
    else
        average:SetText((suite.L("Ø %s DPS  |cffbaa894· %d/%d Kämpfe|r")):format(value, count, limit))
    end
    setComparison(history[1], priorSum, priorCount)
    empty:SetShown(#history == 0)

    local maxValue = math.max(1, highest)
    local barWidth = width - 12
    local meanX = mean and math.min(barWidth - 1, mean / maxValue * barWidth)
    for index, row in ipairs(rows) do
        local fight = history[index]
        row.fight = fight
        row:SetShown(fight ~= nil)
        if fight then
            row.name:SetText(fightName(fight.name))
            row.duration:SetText(formatDuration(fight.duration))
            row.dps:SetText(formatDps(fight.dps))
            row.bar:SetMinMaxValues(0, maxValue)
            row.bar:SetValue(fight.dps or 0)
            row.link:SetShown(index < #history)
            row.mean:SetShown(meanX ~= nil)
            if meanX then
                row.mean:ClearAllPoints()
                row.mean:SetPoint("TOPLEFT", row.bar, "TOPLEFT", meanX, 0)
                row.mean:SetHeight(index < #history and rowHeight or rowHeight - 2)
            end
        end
    end
end

local function setMiniShown(shown)
    PaulchenQoLTimelineDB.miniShown = shown
    miniWindow:SetShown(shown)
    style.SetButtonState(compactButton, shown)
    if shown then
        if miniWindow.Raise then miniWindow:Raise() end
        addon.RefreshMini()
    end
end

local function toggleMiniWindow()
    setMiniShown(not miniWindow:IsShown())
end

local function restorePosition()
    local position = PaulchenQoLTimelineDB.position
    miniWindow:ClearAllPoints()
    if position then
        miniWindow:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", position.x, position.y + fullHeight)
    else
        miniWindow:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", -65, 145 + fullHeight)
    end
end

local function showView(view)
    view = views[view] and view or "dps"
    PaulchenQoLTimelineDB.view = view
    for name, panel in pairs(views) do
        local selected = name == view
        panel:SetShown(selected)
        if tabs[name] then
            local tabSelected = selected or (name == "dps" and view == "profiles")
            style.SetButtonState(tabs[name], tabSelected)
            tabs[name]:SetNormalFontObject(tabSelected and "GameFontNormalSmall" or "GameFontHighlightSmall")
        end
    end
    if view == "profiles" then renderProfiles() end
end

local miniMetrics = { suite.L("Noch %s Mobs"), suite.L("%s EP/h"), suite.L("%s %% Stufe"), suite.L("%s letzte DPS"), suite.L("Ø %s DPS"), "%s" }
local farmLabels = { idle = suite.L("Start"), active = suite.L("Pause"), paused = suite.L("Weiter") }

function addon.RefreshMini()
    if not miniButtons or not miniWindow:IsShown() then
        return
    end
    local mobs, rate, progress = addon.GetMiniExperience()
    local farm = addon.FarmControls
    local state = farm.State()
    local values = { mobs, rate, progress, latestDps, meanDps, farm.Mini() }
    for index, button in ipairs(miniButtons) do
        local metric = PaulchenQoLTimelineDB.miniMetrics[index]
        local value = values[metric]
        local text
        if metric == 6 then
            text = value
        elseif metric == 3 and value then
            text = suite.LocalizeDecimal(("%.1f"):format(value))
        else
            text = formatDps(value)
        end
        button:SetText(miniMetrics[metric]:format(text))
    end
    farmToggle:SetText(farmLabels[state])
    farmStop:SetEnabled(state ~= "idle")
end

local function createLogbook()
    page = CreateFrame("Frame", "PaulchenQoLLogbookPage", UIParent, "BackdropTemplate")
    page:Hide()
    page:SetSize(width, fullHeight)
    style.Panel(page, style.background)

    local titleBar = CreateFrame("Frame", nil, page)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(26)
    style.Fill(titleBar, "BACKGROUND", unpack(style.header))
    style.Portrait(titleBar, 21, 5, -2)
    label(titleBar, "GameFontNormal", "LEFT", "LEFT", 29, 0):SetText(suite.logbookName)

    compactButton = style.TextButton(titleBar)
    compactButton:SetPoint("RIGHT", -4, 0)
    compactButton:SetSize(65, 22)
    compactButton:SetText(suite.L("Kompakt"))
    compactButton:SetScript("OnClick", toggleMiniWindow)
    local previous = compactButton
    for _, definition in ipairs({ { "xp", suite.L("EP"), 29 }, { "crits", suite.L("Crits"), 39 }, { "dps", "DPS", 35 } }) do
        local name, titleText, tabWidth = unpack(definition)
        local panel = CreateFrame("Frame", nil, page)
        panel:SetAllPoints()
        views[name] = panel

        local button = style.TextButton(titleBar)
        button:SetPoint("RIGHT", previous, "LEFT", -2, 0)
        button:SetSize(tabWidth, 22)
        button:SetText(titleText)
        button:SetScript("OnClick", function()
            showView(name)
        end)
        tabs[name] = button
        previous = button
    end

    local timeline = views.dps
    addon.CreateCritPanel(views.crits, width, rowHeight, limit, label)
    showExperiencePage = addon.CreateExperiencePanel(views.xp, label, barTexture)
    views.profiles = CreateFrame("Frame", nil, page)
    views.profiles:SetAllPoints()
    renderProfiles = addon.CreateOpponentPanel(views.profiles, label, formatDuration, formatDps)
    local profilesButton = style.TextButton(timeline)
    profilesButton:SetPoint("TOPRIGHT", -12, -32)
    profilesButton:SetSize(60, 20)
    profilesButton:SetText(suite.L("Profile"))
    profilesButton:SetScript("OnClick", function() showView("profiles") end)
    PaulchenQoLTimelineDB.view = PaulchenQoLTimelineDB.view or (PaulchenQoLTimelineDB.showCrits and "crits" or "dps")

    average = label(timeline, "GameFontNormalLarge", "TOPLEFT", "TOPLEFT", 12, -34)
    comparison = label(timeline, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -54)
    local fightHeading = label(timeline, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 29, -76)
    fightHeading:SetText(suite.L("KAMPF · NEUESTE ZUERST"))
    local timeHeading = label(timeline, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -83, -76)
    timeHeading:SetText(suite.L("DAUER"))
    local dpsHeading = label(timeline, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -11, -76)
    dpsHeading:SetText("DPS")

    empty = label(timeline, "GameFontHighlight", "TOP", "TOP", 0, -137)
    empty:SetText(suite.L("Warte auf abgeschlossene Kämpfe …"))

    rows = {}
    for index = 1, limit do
        local row = CreateFrame("Frame", nil, timeline)
        row:SetPoint("TOPLEFT", 6, -firstRow - (index - 1) * rowHeight)
        row:SetPoint("TOPRIGHT", -6, -firstRow - (index - 1) * rowHeight)
        row:SetHeight(rowHeight - 2)
        row:EnableMouse(true)
        style.Row(row, index)

        row.bar = CreateFrame("StatusBar", nil, row)
        row.bar:SetAllPoints()
        row.bar:SetStatusBarTexture(barTexture)
        row.bar:SetStatusBarColor(0.62, 0.34, 0.16, index == 1 and 0.68 or 0.46)

        row.mean = row.bar:CreateTexture(nil, "ARTWORK", nil, 2)
        row.mean:SetWidth(1.25)
        row.mean:SetColorTexture(style.gold[1], style.gold[2], style.gold[3], 0.92)

        row.link = row.bar:CreateTexture(nil, "ARTWORK")
        row.link:SetPoint("TOPLEFT", 9, -9)
        row.link:SetSize(1, rowHeight)
        row.link:SetColorTexture(0.66, 0.50, 0.34, 0.70)
        local marker = row.bar:CreateTexture(nil, "OVERLAY")
        marker:SetPoint("LEFT", 7, 0)
        marker:SetSize(5, 5)
        if index == 1 then
            marker:SetColorTexture(unpack(style.gold))
        else
            marker:SetColorTexture(unpack(style.muted))
        end

        row.dps = label(row.bar, "GameFontHighlight", "RIGHT", "RIGHT", -5, 0)
        row.duration = label(row.bar, "GameFontHighlightSmall", "RIGHT", "RIGHT", -77, 0)
        row.duration:SetTextColor(unpack(style.muted))
        row.name = label(row.bar, "GameFontHighlightSmall", "LEFT", "LEFT", 23, 0)
        row.name:SetPoint("RIGHT", row.bar, "RIGHT", -124, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row:SetScript("OnEnter", function(self)
            local fight = self.fight
            if not fight then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(fightName(fight.name), unpack(style.gold))
            GameTooltip:AddDoubleLine(suite.L("Deine DPS"), formatDps(fight.dps), 1, 1, 1)
            GameTooltip:AddDoubleLine(suite.L("Dein Schaden"), formatDps(fight.damage), 1, 1, 1)
            GameTooltip:AddDoubleLine(suite.L("Dauer"), formatDuration(fight.duration), 1, 1, 1)
            if fight.endTime then
                GameTooltip:AddDoubleLine(suite.L("Kampfende"), fight.endTime, 1, 1, 1)
            end
            if not fight.dps then
                GameTooltip:AddLine(suite.L("Für dich liegen hier keine auswertbaren DPS vor."), 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        rows[index] = row
    end
    showView(PaulchenQoLTimelineDB.view)
    render()
end

function addon.GetPage(parent)
    if not page then return end
    page:SetParent(parent)
    return page
end

local function createMiniWindow()
    miniWindow = CreateFrame("Frame", "PaulchenQoLLogbookMini", UIParent, "BackdropTemplate")
    miniWindow:Hide()
    miniWindow:SetSize(width, miniHeight)
    miniWindow:SetMovable(true)
    miniWindow:SetClampedToScreen(true)
    miniWindow:SetFrameStrata("DIALOG")
    miniWindow:EnableMouse(true)
    style.Panel(miniWindow, style.header)
    restorePosition()
    miniWindow:RegisterForDrag("LeftButton")
    miniWindow:SetScript("OnDragStart", function() miniWindow:StartMoving() end)
    miniWindow:SetScript("OnDragStop", function()
        miniWindow:StopMovingOrSizing()
        local y = miniWindow:GetBottom() + miniHeight - fullHeight
        PaulchenQoLTimelineDB.position = { x = miniWindow:GetLeft(), y = y }
        restorePosition()
    end)
    style.Portrait(miniWindow, 21, 5, -2)

    local close = CreateFrame("Button", nil, miniWindow, "UIPanelCloseButton")
    close:SetPoint("RIGHT", 0, 0)
    close:SetSize(24, 24)
    close:SetScript("OnClick", function() setMiniShown(false) end)

    local open = style.TextButton(miniWindow)
    open:SetPoint("RIGHT", close, "LEFT", -2, 0)
    open:SetSize(20, 22)
    open:SetText("+")
    open:SetScript("OnClick", function() suite.OpenDashboard("logbook") end)
    open:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(suite.logbookName, unpack(style.gold))
        GameTooltip:Show()
    end)
    open:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local miniBar = CreateFrame("Frame", nil, miniWindow)
    miniBar:SetPoint("LEFT", 29, 0)
    miniBar:SetSize(270, miniHeight - 2)
    miniButtons = {}
    local metrics = PaulchenQoLTimelineDB.miniMetrics or { 1, 2 }
    PaulchenQoLTimelineDB.miniMetrics = metrics
    for index = 1, 2 do
        if not miniMetrics[metrics[index]] then
            metrics[index] = index
        end
        local button = style.TextButton(miniBar)
        button:SetPoint("LEFT", (index - 1) * 104, 0)
        button:SetSize(102, miniHeight - 4)
        button:SetScript("OnClick", function()
            metrics[index] = metrics[index] % #miniMetrics + 1
            addon.RefreshMini()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(suite.L("Klick wechselt die Kennzahl"), 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        miniButtons[index] = button
    end
    local function miniFarmButton(text, hint, x, buttonWidth, action)
        local button = style.TextButton(miniBar)
        button:SetPoint("LEFT", x, 0)
        button:SetSize(buttonWidth, miniHeight - 4)
        button:SetNormalFontObject("GameFontNormalSmall")
        button:SetText(text)
        button:SetScript("OnClick", function()
            action()
            addon.RefreshMini()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(hint, 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return button
    end
    farmToggle = miniFarmButton(suite.L("Start"), suite.L("Farmrunde starten, pausieren oder fortsetzen"), 208, 45, addon.FarmControls.Toggle)
    farmStop = miniFarmButton("■", suite.L("Farmrunde beenden und speichern"), 254, 17, addon.FarmControls.Stop)

    local db = PaulchenQoLTimelineDB
    if db.miniShown == nil then db.miniShown = db.mini == true and db.hidden ~= true end
    setMiniShown(db.miniShown)
end

local function refresh()
    pendingTimer = nil
    local waiting = addon.RefreshHistory()
    render()
    if waiting and retries > 0 and not InCombatLockdown() then
        retries = retries - 1
        pendingTimer = C_Timer.NewTimer(1, refresh)
    end
end

local function queueRefresh()
    if not page or InCombatLockdown() then
        return
    end
    retries = 8
    if not pendingTimer then
        pendingTimer = C_Timer.NewTimer(0.4, refresh)
    end
end

local function createMinimapButton(broker, icons)
    local db = PaulchenQoLTimelineDB
    if type(db.minimap) ~= "table" then
        db.minimap = { minimapPos = 155 }
    end
    local launcher = broker:NewDataObject(addonName, {
        type = "launcher",
        label = suite.logbookName,
        icon = suite.avatar,
        OnClick = function(_, button)
            if button == "LeftButton" then
                suite.ToggleDashboard("logbook")
            elseif button == "RightButton" then
                toggleMiniWindow()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(suite.logbookName, unpack(style.gold))
            tooltip:AddLine(suite.L("Linksklick · Logbuch-Reiter öffnen oder schließen"), 1, 1, 1)
            tooltip:AddLine(suite.L("Rechtsklick · Kompaktansicht umschalten"), 1, 1, 1)
            tooltip:AddLine(suite.L("Ziehen · Position ändern"), 0.7, 0.7, 0.7)
        end,
    })
    icons:Register(addonName, launcher, db.minimap)
end

function addon.UpdateMinimap(shown)
    if not miniWindow then return end
    local broker = LibStub and LibStub("LibDataBroker-1.1", true)
    local icons = broker and LibStub("LibDBIcon-1.0", true)
    if not icons then return end
    if icons:IsRegistered(addonName) then
        if shown and not PaulchenQoLTimelineDB.minimap.hide then icons:Show(addonName) else icons:Hide(addonName) end
    elseif shown then
        createMinimapButton(broker, icons)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("ENCOUNTER_END")
events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
suite.RegisterSupported(events, "DAMAGE_METER_COMBAT_SESSION_UPDATED")
suite.RegisterSupported(events, "DAMAGE_METER_RESET")
events:SetScript("OnEvent", function(_, event, argument, isReloadingUI)
    if event == "PLAYER_LOGIN" then
        PaulchenQoLTimelineDB = PaulchenQoLTimelineDB or {}
        PaulchenQoLTimelineDB.history = PaulchenQoLTimelineDB.history or {}
        addon.MigrateHistory(PaulchenQoLTimelineDB)
        createLogbook()
        page:SetScript("OnShow", queueRefresh)
        createMiniWindow()
        addon.UpdateMinimap(suite.Profile().moduleIcons)

        if details and details.CreateEventListener then
            local listener = details:CreateEventListener()
            listener:RegisterEvent("COMBAT_PLAYER_LEAVE", queueRefresh)
            listener:RegisterEvent("SERVER_COMBAT_ENDED", queueRefresh)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if (argument or isReloadingUI) and LoggingCombat and not LoggingCombat() then
            LoggingCombat(true)
        end
    elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        if issecretvalue(argument) or not Enum or not Enum.DamageMeterType or argument ~= Enum.DamageMeterType.DamageDone then
            return
        end
    elseif event == "DAMAGE_METER_RESET" then
        addon.ResetMeterAssociation()
    end
    queueRefresh()
end)

local experiencePages = { farm = "farm", stufen = "levels", quests = "quests", archiv = "archive" }
local logbookViews = { profile = "profiles", crits = "crits", dps = "dps", xp = "xp", ep = "xp", exp = "xp" }

function addon.Open(command)
    if not page then return end
    if command == "mini" then
        setMiniShown(true)
    else
        if experiencePages[command] then
            showExperiencePage(experiencePages[command])
            showView("xp")
        elseif logbookViews[command] then
            showView(logbookViews[command])
        end
        suite.OpenDashboard("logbook")
    end
    queueRefresh()
end

SLASH_DETAILSCOMBATTIMELINE1 = "/kampftimeline"
SLASH_DETAILSCOMBATTIMELINE2 = "/dtl"
SLASH_DETAILSCOMBATTIMELINE3 = "/logbuch"
SlashCmdList.DETAILSCOMBATTIMELINE = function(command)
    if not page then return end
    command = (command or ""):lower():match("^%s*(.-)%s*$")
    if command == "reset" then
        PaulchenQoLTimelineDB.position = nil
        restorePosition()
        setMiniShown(true)
    elseif command == "mini" then
        toggleMiniWindow()
    elseif experiencePages[command] or logbookViews[command] then
        addon.Open(command)
    else
        suite.ToggleDashboard("logbook")
    end
end
