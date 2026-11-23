local _, app = ...

local defaults = {
    show = true, size = 128, opacity = 1, bubbles = true, comments = true,
    frequency = 2, language = "auto", hideCombat = true, memory = true, debug = false, moduleIcons = false,
    ambientComments = true, repairHints = true, pauseHints = false, situationalComments = true,
    questTurnIns = true, mountGloves = true, levelUpSound = true,
}
local profile, window
local L = app.L

local function clamp(number, minimum, maximum, fallback)
    number = tonumber(number)
    if not number or number ~= number then return fallback end
    return math.max(minimum, math.min(maximum, number))
end

function app.Profile()
    if profile then return profile end
    if type(PaulchenQoLSettings) ~= "table" then
        PaulchenQoLSettings = {}
        local legacy = app.Settings()
        PaulchenQoLSettings.show = legacy.companion ~= false
        if type(legacy.companionX) == "number" and type(legacy.companionY) == "number" then
            PaulchenQoLSettings.x, PaulchenQoLSettings.y = legacy.companionX, legacy.companionY
        end
    end
    profile = PaulchenQoLSettings
    for key, value in pairs(defaults) do
        if type(profile[key]) ~= type(value) then profile[key] = value end
    end
    profile.size = math.floor(clamp(profile.size, 64, 256, 128) + 0.5)
    profile.opacity = clamp(profile.opacity, 0.2, 1, 1)
    profile.frequency = math.floor(clamp(profile.frequency, 1, 3, 2))
    profile.sarcasm = nil
    profile.language = app.GetLanguageSetting()
    return profile
end

function app.Debug(text)
    if profile and profile.debug then print("Paulchen QoL · " .. text) end
end

local dialogueSettings = {
    frequency = true, show = true, comments = true, bubbles = true, ambientComments = true,
    repairHints = true, pauseHints = true, situationalComments = true, memory = true,
}

local function write(key, value)
    local settings = app.Profile()
    if key == "language" then
        if (value ~= "auto" and value ~= "deDE" and value ~= "enUS") or settings.language == value then return end
        settings.language = value
        if InCombatLockdown and app.ReadGameValue(InCombatLockdown) ~= false then
            print(L("Sprachwechsel nach dem Kampf abschließen: /reload"))
        elseif ReloadUI then ReloadUI()
        else print(L("Sprache geändert. Bitte /reload eingeben.")) end
        return
    end
    settings[key] = value
    if app.DialogueProfileChanged then app.DialogueProfileChanged(key) end
    if app.ApplyProfile then app.ApplyProfile(key) end
    if key == "moduleIcons" then app.UpdateModuleIcons() end
    if key == "questTurnIns" then app.RefreshQuestMap() end
    if key == "mountGloves" then app.RefreshMountGloves() end
    if key == "levelUpSound" then app.ApplyLevelUpSound() end
    if app.companionLife and dialogueSettings[key] then
        app.companionLife.Update(key == "frequency" or key == "ambientComments")
    end
end
app.SetProfile = write

local function label(parent, text, font, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(L(text))
    return fs
end

local function button(parent, text, x, y, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(L(text))
    return b
end

local function checkbox(parent, key, text, y, x)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetSize(24, 24)
    b:SetPoint("TOPLEFT", x or 17, y)
    label(b, text, nil, 29, -6)
    b:SetScript("OnClick", function(self) write(key, not not self:GetChecked()) end)
    return function() b:SetChecked(app.Profile()[key]) end
end

local function slider(parent, key, text, y, low, high, step, multiplier, unit)
    local title = label(parent, "", nil, 252, y)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetPoint("TOPLEFT", 252, y - 23)
    s:SetSize(204, 12)
    s:SetOrientation("HORIZONTAL")
    s:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    s:SetBackdropColor(0.29, 0.18, 0.13, 1)
    s:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    s:SetMinMaxValues(low, high)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    local syncing = false
    local function display(value)
        title:SetText(("%s · %d %s"):format(L(text), math.floor(value + 0.5), unit))
    end
    s:SetScript("OnValueChanged", function(_, value)
        display(value)
        if not syncing then write(key, value / multiplier) end
    end)
    return function()
        syncing = true
        local value = app.Profile()[key] * multiplier
        s:SetValue(value)
        display(value)
        syncing = false
    end
end

local function choices(parent, key, text, values, y)
    local caption = label(parent, text, "GameFontHighlightSmall", 252, y)
    local controls = {}
    local function sync()
        local selected = app.Profile()[key]
        for index, b in ipairs(controls) do b:EnableMouse(index ~= selected) end
        caption:SetText(L(text) .. " · " .. L(values[selected]))
    end
    for index, name in ipairs(values) do
        local b = button(parent, L(name), 252 + (index - 1) * 70, y - 18, 68)
        controls[index] = b
        b:SetScript("OnClick", function() write(key, index); sync() end)
    end
    return sync
end

local function refreshSettings()
    if window and window:IsShown() then for _, sync in ipairs(window.controls) do sync() end end
end
app.RefreshSettings = refreshSettings

local function createWindow()
    local f = CreateFrame("Frame", "PaulchenQoLConfig", UIParent, "BackdropTemplate")
    f:Hide()
    f:SetSize(542, 548)
    f:SetScale(math.min(1, (UIParent:GetWidth() - 20) / 542, (UIParent:GetHeight() - 20) / 548))
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.102, 0.071, 0.055, 0.98)
    f:SetBackdropBorderColor(0.64, 0.40, 0.23, 1)
    label(f, "Paulchen · Einstellungen", "GameFontNormalLarge", 18, -15)
    label(f, "Begleiter", "GameFontNormal", 19, -60)
    label(f, "Aussehen und Gespräche", "GameFontNormal", 252, -60)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() f:Hide() end)
    f.controls = {
        checkbox(f, "show", "Paulchen anzeigen", -83),
        checkbox(f, "bubbles", "Textblasen", -112),
        checkbox(f, "comments", "Kommentare", -141),
        checkbox(f, "hideCombat", "Im Kampf ausblenden", -170),
        checkbox(f, "memory", "Erinnerungen speichern", -199),
        checkbox(f, "debug", "Debugmodus", -228),
        slider(f, "size", "Größe", -90, 64, 256, 1, 1, "px"),
        slider(f, "opacity", "Deckkraft", -137, 20, 100, 1, 100, "%"),
        choices(f, "frequency", "Häufigkeit", { "Selten", "Normal", "Gesprächig" }, -184),
        checkbox(f, "ambientComments", "Spontanes Geplapper", -229, 249),
        checkbox(f, "situationalComments", "Situationskommentare", -258, 249),
        checkbox(f, "repairHints", "Reparaturhinweise", -287, 249),
        checkbox(f, "pauseHints", "Pausenerinnerungen", -316, 249),
    }
    local langCaption = label(f, "Sprache", "GameFontHighlightSmall", 252, -354)
    local langOptions = { { "auto", "Automatisch" }, { "deDE", "Deutsch" }, { "enUS", "Englisch" } }
    local langButtons = {}
    local function syncLanguage()
        local current = app.Profile().language
        langCaption:SetText(L("Sprache") .. " · " .. L(current == "deDE" and "Deutsch" or current == "enUS" and "Englisch" or "Automatisch"))
        for _, option in ipairs(langButtons) do option.button:EnableMouse(option.value ~= current) end
    end
    for index, entry in ipairs(langOptions) do
        local name = entry[1]
        local control = button(f, entry[2], 252 + (index - 1) * 84, -374, 80)
        langButtons[#langButtons+1] = { button = control, value = name }
        control:SetScript("OnClick", function() write("language", name); syncLanguage() end)
    end
    f.controls[#f.controls+1] = syncLanguage
    button(f, "Level-up-Sound testen", 252, -412, 248):SetScript("OnClick", function()
        if not app.PlayLevelUpSound() then print(L("Paulchen QoL · Der Level-up-Sound konnte nicht abgespielt werden.")) end
    end)
    button(f, "Buffwächter einstellen", 252, -448, 248):SetScript("OnClick", function()
        if app.buffCheck then app.buffCheck.OpenConfig() end
    end)
    button(f, "Taschen / Preise", 18, -304, 180):SetScript("OnClick", function()
        if app.inventory then app.inventory.OpenPriceSettings() end
    end)
    button(f, "Position zurücksetzen", 18, -342, 180):SetScript("OnClick", function() app.ResetCompanionPosition() end)
    button(f, "Komfort", 18, -266, 180):SetScript("OnClick", function()
        f:Hide()
        app.comfort.Open()
    end)
    button(f, "Testkommentar", 252, -484, 248):SetScript("OnClick", function() app.TestComment() end)
    label(f, "Links ziehen · Rechtsklick öffnet dieses Fenster", "GameFontHighlightSmall", 18, -525)
    table.insert(UISpecialFrames, f:GetName())
    f:SetScript("OnShow", refreshSettings)
    return f
end

function app.OpenConfig()
    window = window or createWindow()
    window:Show()
end

function app.CompanionCommand(message)
    local cmd = (message or ""):match("^%s*(%S*)"):lower()
    if cmd == "lang" or cmd == "language" then
        local value = (message or ""):match("^%s*%S+%s+(%S+)")
        value = value and value:lower() or nil
        local names = { de = "deDE", dede = "deDE", german = "deDE", deutsch = "deDE", en = "enUS", enus = "enUS", english = "enUS", englisch = "enUS", auto = "auto" }
        if value and names[value] then write("language", names[value]) else app.OpenConfig() end
    elseif (cmd == "karte" or cmd == "map") and ToggleWorldMap then
        ToggleWorldMap()
    elseif (cmd == "instanzen" or cmd == "instances") and app.instances then
        app.OpenDashboard("instances")
    elseif (cmd == "komfort" or cmd == "comfort") and app.comfort then
        if window then window:Hide() end
        app.comfort.Open()
    elseif cmd == "buffs" and app.buffCheck then
        app.buffCheck.Command((message or ""):match("^%s*%S+%s*(.-)%s*$"))
    elseif cmd == "show" or cmd == "hide" then
        write("show", cmd == "show")
    elseif cmd == "reset" then
        app.ResetCompanionPosition()
    elseif cmd == "test" then
        app.TestComment()
    elseif cmd == "debug" then
        write("debug", not app.Profile().debug)
        print(L("Paulchen QoL · Debugmodus ") .. (app.Profile().debug and L(" an") or L(" aus")))
    elseif cmd == "" then
        app.OpenConfig()
    else
        print("Paulchen QoL · /pq [show, hide, reset, test, debug, buffs, comfort, map, instances, lang auto|de|en]")
    end
    refreshSettings()
end
