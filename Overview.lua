local _, app = ...
local overview, style, readable = {}, app.style, app.Readable
app.overview = overview
local session, panel, copyWindow

local function numeric(value)
    value = readable(value)
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
end
local function amount(api, ...)
    return api and numeric(api(...))
end
local function duration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end
local function count(value)
    return value and (BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(value + 0.5)) or tostring(math.floor(value + 0.5))) or "–"
end
local function played()
    return session and (session.elapsed + (session.clock and math.max(0, GetTime() - session.clock) or 0)) or 0
end
local function recordMoney()
    local current = amount(GetMoney)
    if not session or not current then return end
    if session.money then session.gold = session.gold + current - session.money end
    session.money = current
end
local function openBags(query)
    app.CloseDashboard()
    if not app.inventory then return end
    app.inventory.Show()
    if app.inventory.window then app.inventory.window.search:SetText(query or "") end
end
local function openXP() app.OpenModule("dtl", "xp") end
local function openFarm() app.OpenModule("dtl", "farm") end
local function copyLocation(text)
    if not copyWindow then
        local f = CreateFrame("Frame", "PaulchenQoLCopyLocation", UIParent, "BackdropTemplate")
        f:SetSize(430, 100); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        style.Panel(f, style.background)
        style.Label(f, app.L("Standort kopieren · Strg+C"), 14, -10, 380, 22, "GameFontNormal", style.gold)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT"); close:SetScript("OnClick", function() f:Hide() end)
        f.box = style.EditBox(f)
        f.box:SetPoint("TOPLEFT", 14, -46); f.box:SetSize(402, 30)
        f.box:SetScript("OnEscapePressed", function() f:Hide() end)
        f.box:SetScript("OnEnterPressed", function() f:Hide() end)
        f:SetScript("OnHide", function() f.box:ClearFocus() end)
        UISpecialFrames[#UISpecialFrames + 1] = f:GetName()
        copyWindow = f
    end
    copyWindow.box:SetText(text); copyWindow:Show()
    copyWindow.box:SetFocus(); copyWindow.box:HighlightText()
end
function overview.Data()
    local data = { elapsed = played(), gold = session and session.gold or 0, deaths = session and session.deaths or 0, tasks = {} }
    local travel = app.ReadTravel()
    local mark, pouch = app.CompanionReminders()
    if mark then data.tasks[#data.tasks + 1] = { text = mark .. app.L(" · Zauberbuch"), action = function()
        if ToggleSpellBook and not (InCombatLockdown and InCombatLockdown()) then ToggleSpellBook("spell") end
    end } end
    if pouch then data.tasks[#data.tasks + 1] = { text = pouch, action = function() openBags("11020") end } end
    if travel.durability and travel.durability <= 30 then
        data.tasks[#data.tasks + 1] = { text = "Reparieren · " .. math.floor(travel.durability) .. " % Haltbarkeit", action = function() openBags(app.L("Ausrüstung")) end }
    end
    if travel.capacity > 0 and travel.free <= 4 then
        data.tasks[#data.tasks + 1] = { text = app.L("Taschen aufräumen · ") .. travel.free .. app.L(" Plätze frei"), action = function() openBags() end }
    end
    local timeline = app.timeline
    data.xp = timeline and timeline.OverviewExperience and timeline.OverviewExperience()
    if not data.xp then
        local level, xp, maximum = amount(UnitLevel, "player"), amount(UnitXP, "player"), amount(UnitXPMax, "player")
        if level and xp and maximum and xp <= maximum then data.xp = { level = level, xp = xp, maximum = maximum } end
    end
    local controls = timeline and timeline.FarmControls
    data.farm = controls and controls.Snapshot and controls.Snapshot() or { ready = false }
    data.upgrade = app.upgrades and app.upgrades.OverviewUpgrade and app.upgrades.OverviewUpgrade()
    local zone = GetRealZoneText and readable(GetRealZoneText()) or "Unbekanntes Gebiet"
    local subzone = GetSubZoneText and readable(GetSubZoneText()) or ""
    data.zone, data.subzone = zone, subzone
    local map = C_Map and C_Map.GetBestMapForUnit and readable(C_Map.GetBestMapForUnit("player"))
    local position = map and C_Map.GetPlayerMapPosition and readable(C_Map.GetPlayerMapPosition(map, "player"))
    if position then
        local x, y
        if position.GetXY then x, y = position:GetXY() else x, y = position.x, position.y end
        x, y = numeric(x), numeric(y)
        if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            data.coordinates = ("%.1f, %.1f"):format(x * 100, y * 100)
        end
    end
    data.location = zone .. (subzone ~= "" and subzone ~= zone and (" · " .. subzone) or "")
        .. (data.coordinates and (" (" .. data.coordinates .. ")") or "")
    return data
end

local function card(parent, title, x, y, width, height)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetPoint("TOPLEFT", x, y); f:SetSize(width, height)
    style.Panel(f, {0.15, 0.105, 0.077})
    style.Label(f, title, 10, -5, width - 20, 20, "GameFontNormal", style.gold)
    return f
end
local function text(parent, y, width, height)
    local f = style.Label(parent, "", 10, y, width, height, "GameFontHighlightSmall", style.cream)
    f:SetWordWrap(true)
    return f
end
local function control(parent, title, x, y, width, action)
    local b = style.TextButton(parent)
    b:SetPoint("TOPLEFT", x, y); b:SetSize(width, 21); b:SetText(title)
    b:SetScript("OnClick", action)
    return b
end
local function progress(parent, x, y, width, color)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetPoint("TOPLEFT", x, y); b:SetSize(width, 12)
    b:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    b:SetStatusBarColor(unpack(color)); b:SetMinMaxValues(0, 1)
    style.Fill(b, "BACKGROUND", unpack(style.track))
    return b
end

function app.CreateOverviewPanel(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 18, -166); f:SetSize(644, 378)
    panel = f
    local needs = card(f, app.L("Das steht gerade an"), 0, 0, 644, 80)
    needs.empty = text(needs, -28, 620, 30)
    needs.empty:SetText(app.L("Alles bereit für die nächste Runde."))
    needs.tasks = {}
    for i = 1, 4 do
        local index = i
        needs.tasks[i] = control(needs, "", 10 + (i - 1) % 2 * 316, -27 - math.floor((i - 1) / 2) * 25, 308, function()
            local task = overview.Data().tasks[index]
            if task then task.action() end
        end)
    end
    f.needs = needs
    f.session = card(f, "Deine Sitzung", 0, -90, 316, 96)
    f.session.body = text(f.session, -26, 296, 62)
    control(f.session, app.L("Logbuch"), 237, -4, 69, openXP)
    f.level = card(f, app.L("Bis zum nächsten Level"), 328, -90, 316, 96)
    f.level.progress = progress(f.level, 10, -29, 296, {0.6, 0.35, 0.85})
    f.level.body = text(f.level, -46, 296, 45)
    f.farm = card(f, "Aktuelle Farmrunde", 0, -196, 644, 80)
    f.farm.body = text(f.farm, -27, 400, 43)
    f.farm.progress = progress(f.farm, 422, -57, 212, style.green)
    f.farm.toggle = control(f.farm, "Start", 422, -28, 70, function()
        local farm = app.timeline and app.timeline.FarmControls
        if farm then farm.Toggle() end
        overview.Render()
    end)
    f.farm.stop = control(f.farm, "Stopp", 496, -28, 60, function()
        local farm = app.timeline and app.timeline.FarmControls
        if farm then farm.Stop() end
        overview.Render()
    end)
    control(f.farm, app.L("Ziel / Details"), 550, -3, 84, openFarm)
    f.location = card(f, "Standort", 0, -286, 316, 92)
    f.location.body = text(f.location, -26, 296, 34)
    f.location.body:SetWordWrap(false)
    control(f.location, "Kopieren", 10, -64, 144, function() copyLocation(overview.Data().location) end)
    control(f.location, "Karte", 162, -64, 144, function() if ToggleWorldMap then ToggleWorldMap() end end)
    f.upgrade = card(f, "Bestes bekanntes Upgrade", 328, -286, 316, 92)
    f.upgrade.body = text(f.upgrade, -26, 296, 34)
    f.upgrade.body:SetWordWrap(false)
    control(f.upgrade, app.L("Anzeigen"), 10, -64, 144, function()
        if app.upgrades and app.upgrades.OpenOverviewUpgrade then app.upgrades.OpenOverviewUpgrade()
        else app.OpenModule("upgrades") end
    end)
    control(f.upgrade, app.L("Aktualisieren"), 162, -64, 144, function()
        if app.upgrades and app.upgrades.CheckUpgrades then app.upgrades.CheckUpgrades() end
    end)
    f:SetScript("OnShow", function() overview.Render() end)
    return f
end

function overview.Render()
    if not panel or not panel:IsVisible() then return end
    local data, f = overview.Data(), panel
    f.needs.empty:SetShown(#data.tasks == 0)
    for i, button in ipairs(f.needs.tasks) do
        local task = data.tasks[i]
        button:SetShown(task ~= nil)
        if task then button:SetText(task.text) end
    end
    local xp = data.xp
    local balance = (data.gold < 0 and "−" or data.gold > 0 and "+" or "") .. app.inventory.MoneyText(math.abs(data.gold))
    f.session.body:SetText((app.L("Spielzeit %s · Tode %d\n%s EP · %s EP/h\nGoldbilanz %s"))
        :format(duration(data.elapsed), data.deaths, (xp and xp.partial and "≥ " or "") .. count(xp and xp.total),
            (xp and xp.partial and "≥ " or "") .. count(xp and xp.rate), balance))
    if xp and xp.maximum > 0 then
        local remaining = math.max(0, xp.maximum - xp.xp)
        f.level.progress:SetValue(xp.xp / xp.maximum)
        f.level.body:SetText(("Stufe %d · %.1f %% · noch %s EP\n%s · %s Gegner")
            :format(xp.level, xp.xp / xp.maximum * 100, count(remaining),
                xp.paused and "EP-Stopp" or xp.eta and ("ca. " .. duration(xp.eta)) or "Zeit noch offen", count(xp.mobs)))
    else
        f.level.progress:SetValue(xp and 1 or 0)
        f.level.body:SetText(xp and app.L("Maximalstufe erreicht") or app.L("EP-Daten werden geladen …"))
    end
    local farm = data.farm
    f.farm.toggle:SetEnabled(farm.ready == true)
    f.farm.stop:SetEnabled(farm.ready == true and farm.active == true)
    f.farm.toggle:SetText(farm.active and (farm.paused and app.L("Fortsetzen") or "Pause") or "Start")
    f.farm.progress:SetValue(farm.goal and math.min(1, farm.itemCount / farm.goal) or 0)
    if farm.active then
        local target = farm.goal and (" · Ziel %d/%d"):format(farm.itemCount, farm.goal) or ""
        f.farm.body:SetText(("%s · %s · %s\n%s EP%s"):format(farm.paused and "Pausiert" or app.L("Läuft"),
            farm.area or "Unbekanntes Gebiet", duration(farm.elapsed), (farm.partial and "≥ " or "") .. count(farm.xp), target))
    else f.farm.body:SetText(app.L("Keine aktive Runde.\nFarmziele unter Ziel / Details einstellen.")) end
    f.location.body:SetText(data.zone .. " · " .. (data.coordinates or app.L("Koordinaten nicht verfügbar"))
        .. (data.subzone ~= "" and data.subzone ~= data.zone and ("\n" .. data.subzone) or ""))
    local upgrade = data.upgrade
    local statuses = { waiting = app.L("Warte auf Ausrüstungsdaten …"), scanning = app.L("Suche läuft …"), combat = app.L("Im Kampf pausiert"),
        stale = "Liste veraltet · Aktualisieren",
        error = "Suchfehler · /pu diagnose", idle = "Noch kein Suchlauf", ready = "Keine bekannten Upgrades" }
    if upgrade and upgrade.best then
        local best = upgrade.best
        local gain = best.pct and ("%+.1f %%"):format(best.pct) or ("+%s Punkte"):format(count(best.delta))
        f.upgrade.body:SetText(best.name .. " · " .. gain .. "\n" .. upgrade.profile
            .. (upgrade.state ~= "ready" and (" · " .. (statuses[upgrade.state] or "")) or upgrade.partial and " · Teilergebnis" or ""))
    else
        local status = upgrade and (upgrade.state == "ready" and upgrade.partial and app.L("Teilergebnis · Itemdaten fehlen") or statuses[upgrade.state])
        f.upgrade.body:SetText(upgrade and ((status or "") .. "\n" .. upgrade.profile) or app.L("Bewertung nicht verfügbar"))
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_MONEY", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
    app.RegisterSupported(events, event)
end
events:SetScript("OnEvent", function(_, event, initial, reloaded)
    if event == "PLAYER_ENTERING_WORLD" then
        local db, now = app.Settings(), GetTime()
        if not session then
            local saved = db.overviewSession
            if readable(initial) ~= true and readable(reloaded) == true and type(saved) == "table"
                and type(saved.elapsed) == "number" and type(saved.gold) == "number" and type(saved.deaths) == "number" then
                session = saved
            else session = { elapsed = 0, gold = 0, deaths = 0 } end
            session.clock, session.money = now, amount(GetMoney)
            db.overviewSession = session
        end
        session.dead = UnitIsDeadOrGhost and readable(UnitIsDeadOrGhost("player")) == true
    elseif event == "PLAYER_LOGOUT" and session then
        recordMoney(); session.elapsed, session.clock = played(), nil
    elseif event == "PLAYER_MONEY" then recordMoney()
    elseif event == "PLAYER_DEAD" and session then
        if not session.dead then session.deaths = session.deaths + 1 end
        session.dead = true
    elseif session and (event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST") then
        session.dead = UnitIsDeadOrGhost and readable(UnitIsDeadOrGhost("player")) == true
    end
    overview.Render()
end)
