local _, app = ...
local style, L = app.style, app.L
local comfort = {}
app.comfort = comfort

local defaults = {
    sellSummary = true,
    mapCompact = true, mapMouseCoords = true, mapPlayerCoords = true, mapZoneMenu = true,
    mapCoordsBackground = true, mapDungeons = true,
    mapNoBlackout = true, mapNoFade = true, mapFlight = true, mapPortals = true, mapCrossings = true, mapLearnCrossings = true,
}

function comfort.Enabled(key)
    local settings = app.Settings().comfort
    if type(settings) == "table" and type(settings[key]) == "boolean" then return settings[key] end
    return defaults[key] == true
end

function comfort.SetEnabled(key, enabled)
    local settings = app.Settings()
    if type(settings.comfort) ~= "table" then settings.comfort = {} end
    settings.comfort[key] = enabled == true
    if app.worldMap and key:sub(1, 3) == "map" then app.worldMap.SettingsChanged() end
end

-- Distinguish an empty slot or cursor from a protected value or a failed read.
function comfort.Read(api, ...)
    if type(api) ~= "function" then return nil, false end
    local ok, value = pcall(api, ...)
    if not ok or issecretvalue and issecretvalue(value) then return nil, false end
    return value, true
end

function comfort.CanInteract()
    local combat, combatKnown = comfort.Read(InCombatLockdown)
    local shift, shiftKnown = comfort.Read(IsShiftKeyDown)
    return combatKnown and shiftKnown and not combat and not shift
end

function comfort.Visible(frame)
    return frame ~= nil and app.ReadGameValue(frame.IsVisible, frame) == true
end

function comfort.HasDialog()
    for i = 1, STATICPOPUP_NUMDIALOGS or 4 do
        if comfort.Visible(_G["StaticPopup" .. i]) then return true end
    end
    return false
end

local categories = {
    { "Händler & Taschen", {
        { "sellPoor", "Graue Gegenstände automatisch verkaufen",
            "Verkauft graue Ware beim Händler. Vormerkungen außer „Händler“ schützen den Stapel. Halte Umschalt beim Ansprechen, um den Verkauf zu überspringen." },
        { "sellSummary", "Verkauf im Chat zusammenfassen", nil, "sellPoor" },
    } },
    { "Quests & Dialoge", {
        { "questRegular", "Normale Quests automatisch annehmen" },
        { "questDaily", "Tägliche Quests automatisch annehmen" },
        { "questWeekly", "Wöchentliche Quests automatisch annehmen" },
        { "questTurnIn", "Fertige Quests automatisch abgeben",
            "Belohnungsauswahl, Kosten sowie normale oder vorgemerkte Abgabeitems bleiben zur manuellen Prüfung offen." },
        { "gossipAlt", "Einzelnen NPC-Dialog per Alt auswählen",
            "Halte Alt beim Ansprechen. Paulchen wählt einen einzelnen Dialogeintrag, wenn keine Quest zur Auswahl steht." },
    } },
    { "Weltkarte & Erkundung", {
        { "mapCompact", "Kompakter Kartenrahmen" },
        { "mapMouseCoords", "Mauskoordinaten anzeigen" },
        { "mapPlayerCoords", "Spielerkoordinaten anzeigen" },
        { "mapCoordsBackground", "Hintergrund der Kartenkoordinaten" },
        { "mapZoneMenu", "Gebiets- und Kontinentmenü" },
        { "mapMove", "Karte verschieben", "Ziehe die Paulchen-Leiste. Fenster- und Vollbildposition werden getrennt gespeichert." },
        { "mapScale", "Karte skalieren", "Die Größe stellst du über Kartenoptionen auf der Weltkarte ein." },
        { "mapNoBlackout", "Dunklen Kartenhintergrund ausblenden" },
        { "mapNoFade", "Karte beim Laufen sichtbar lassen" },
        { "mapHideCities", "Stadt- und Ortsmarker ausblenden" },
        { "mapHideReset", "Filter-Reset der Karte ausblenden" },
        { "questTurnIns", "Questabgaben auf der Weltkarte", nil, nil, true },
        { "mapFlight", "Zusätzliche Flugpunkte anzeigen" },
        { "mapPortals", "Portale anzeigen" },
        { "mapCrossings", "Gebietsübergänge anzeigen" },
        { "mapLearnCrossings", "Gelaufene Übergänge merken" },
        { "mapTransport", "Boote, Zeppeline und Bahnen anzeigen" },
        { "mapOtherFaction", "Verkehrspunkte der anderen Fraktion anzeigen" },
        { "mapSpiritHealers", "Geistheiler auf der Karte anzeigen" },
        { "mapDungeons", "Instanz- und Raideingänge anzeigen",
            "Öffnet Innenkarten, Quests und Routen aus den installierten Instanz-Addons." },
        { "mapZoneLevels", "Ungefähre Gebietsstufen anzeigen" },
        { "mapFishing", "Ungefähre Angelfertigkeit anzeigen" },
        { "mapReveal", "Unerforschte Karte aufdecken" },
        { "mapRevealTint", "Unerforschte Flächen einfärben" },
        { "mapDiscovery", "Unerforschte Teilgebiete markieren" },
        { "mapShowDiscovered", "Erforschte Teilgebiete ebenfalls markieren", nil, "mapDiscovery" },
        { "mapBattlefield", "Schlachtfeldkarte anpassen", "Größe, Deckkraft und Gruppensymbole stellst du über Kartenoptionen ein." },
        { "mapMinimap", "Weltkarte im Minimap-Menü anbieten" },
    } },
    { "Reisen & Flugmeister", { { "mountGloves", "Reithandschuhe automatisch wechseln", nil, nil, true } } },
    { "Gruppe & PvP", {} },
    { "Chat & Meldungen", {} },
    { "HUD & Minimap", { { "moduleIcons", "Separate Modul-Minimapknöpfe", nil, nil, true } } },
    { "Ton & Grafik", { { "levelUpSound", "Eigener Level-up-Sound", nil, nil, true } } },
}

local function enabled(option)
    if option[5] then return app.Profile()[option[1]] == true end
    return comfort.Enabled(option[1])
end

local window

local function createWindow()
    local width, height = 748, 470
    local f = CreateFrame("Frame", "PaulchenQoLComfort", UIParent, "BackdropTemplate")
    f:Hide()
    f:SetSize(width, height)
    f:SetScale(math.min(1, (UIParent:GetWidth() - 20) / width, (UIParent:GetHeight() - 20) / height))
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    style.Panel(f, style.background, style.accent)
    style.Label(f, "Paulchen · Komfort", 15, -6, 688, 26, "GameFontNormalLarge", style.gold)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -3)
    close:SetScript("OnClick", function() f:Hide() end)
    local search = style.EditBox(f)
    search:SetPoint("TOPLEFT", 228, -43)
    search:SetSize(485, 28)
    search:SetMaxLetters(80)
    local hint = style.Label(search, "Komfort-Optionen suchen", 7, 0, 463, 28, "GameFontHighlightSmall", style.muted)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 228, -81)
    scroll:SetPoint("BOTTOMRIGHT", -34, 44)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(486, 1)
    scroll:SetScrollChild(body)
    local empty = style.Label(body, "", 0, -7, 460, 35, "GameFontHighlight", style.muted)
    empty:SetWordWrap(true)

    local note = style.Label(f, "Mit Umschalt setzt du die Automatik für die aktuelle Aktion aus.", 228, -433, 485, 23,
        "GameFontHighlightSmall", style.muted)
    local back = style.TextButton(f)
    back:SetPoint("BOTTOMLEFT", 15, 14)
    back:SetSize(195, 25)
    back:SetText(L("Einstellungen"))
    back:SetScript("OnClick", function() f:Hide(); app.OpenConfig() end)

    local selected, saleDetails = 1, false
    local sections, refresh = {}, nil
    for index, category in ipairs(categories) do
        local group = { title = L(category[1]), rows = {} }
        sections[index] = group
        local button = style.TextButton(f)
        button:SetPoint("TOPLEFT", 15, -43 - (index - 1) * 36)
        button:SetSize(195, 29)
        button:SetText(group.title)
        button:SetScript("OnClick", function()
            selected = index
            search:SetText("")
            search:ClearFocus()
            refresh()
        end)
        group.button = button
        group.heading = style.Label(body, category[1], 0, 0, 460, 23, "GameFontNormal", style.gold)
        for _, option in ipairs(category[2]) do
            local row = CreateFrame("Frame", nil, body, "BackdropTemplate")
            row:SetSize(482, option[3] and 66 or 34)
            style.Panel(row, style.rowColors[1])
            local checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            checkbox:SetSize(24, 24)
            checkbox:SetPoint("TOPLEFT", option[4] and 22 or 6, -4)
            checkbox:SetHitRectInsets(0, option[1] == "sellPoor" and -371 or -406, 0, 0)
            local caption = style.Label(checkbox, option[2], 27, 0, option[4] and 404 or 420, 24)
            if option[3] then
                local detail = style.Label(checkbox, option[3], 27, -25, 418, 32, "GameFontHighlightSmall", style.muted)
                detail:SetWordWrap(true)
                detail:SetJustifyV("TOP")
            end
            checkbox:SetScript("OnClick", function(self)
                if option[5] then
                    app.SetProfile(option[1], not not self:GetChecked())
                else
                    comfort.SetEnabled(option[1], not not self:GetChecked())
                end
                refresh(true)
            end)
            if option[1] == "sellPoor" then
                local details = style.TextButton(row)
                details:SetPoint("TOPRIGHT", -5, -4)
                details:SetSize(69, 22)
                details:SetText("+ " .. L("Details"))
                details:SetScript("OnClick", function()
                    saleDetails = not saleDetails
                    details:SetText((saleDetails and "− " or "+ ") .. L("Details"))
                    refresh(true)
                end)
            end
            group.rows[#group.rows + 1] = { frame = row, check = checkbox, caption = caption, option = option }
        end
    end

    local function lower(value)
        return value:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"):lower()
    end
    refresh = function(keepPosition)
        local query = lower(search:GetText():match("^%s*(.-)%s*$"))
        hint:SetShown(search:GetText() == "")
        local y, found = 0, false
        for index, group in ipairs(sections) do
            style.SetButtonState(group.button, query == "" and index == selected)
            group.heading:Hide()
            local headingShown = false
            for _, row in ipairs(group.rows) do
                local option = row.option
                local matches = query == "" and index == selected and (not option[4] or saleDetails)
                    or query ~= "" and lower(group.title .. " " .. L(option[2]) .. " " .. L(option[3] or "")):find(query, 1, true)
                row.frame:SetShown(matches and true or false)
                if matches then
                    if not headingShown then
                        group.heading:ClearAllPoints()
                        group.heading:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
                        group.heading:Show()
                        headingShown, y = true, y + 27
                    end
                    found = true
                    row.frame:ClearAllPoints()
                    row.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
                    row.check:SetChecked(enabled(option))
                    local available = not option[4] or comfort.Enabled(option[4])
                    row.check:SetEnabled(available)
                    row.caption:SetTextColor(unpack(available and style.cream or style.muted))
                    y = y + row.frame:GetHeight() + 5
                end
            end
        end
        empty:SetShown(not found)
        empty:SetText(L(query == "" and "In dieser Kategorie sind noch keine Komfort-Optionen eingerichtet."
            or "Keine passenden Komfort-Optionen."))
        body:SetHeight(math.max(45, y))
        if not keepPosition then scroll:SetVerticalScroll(0) end
        note:SetShown(found)
    end
    search:SetScript("OnTextChanged", function() refresh() end)
    function f:Select(title)
        for index, category in ipairs(categories) do
            if category[1] == title then selected = index; break end
        end
        search:SetText("")
        refresh()
    end
    f:SetScript("OnShow", function() refresh(); search:ClearFocus() end)
    table.insert(UISpecialFrames, f:GetName())
    return f
end

function comfort.Open(category)
    window = window or createWindow()
    if category then window:Select(category) end
    window:Show()
end
