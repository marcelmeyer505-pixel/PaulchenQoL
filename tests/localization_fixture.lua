-- Standalone localization regression test; run with lua5.1 tests/localization_fixture.lua
local app = {}
local locale = "deDE"
_G.GetLocale = function() return locale end
_G.PaulchenQoLSettings = { language = "auto" }

local function loadAddon(path)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    chunk("PaulchenQoL", app)
end

loadAddon("Localization.lua")
loadAddon("Dialogue.lua")
loadAddon("Dialogue_enUS.lua")

assert(app.GetLanguageSetting() == "auto")
assert(app.GetLanguage() == "deDE")
assert(app.L("Einstellungen") == "Einstellungen")

locale = "enUS"
assert(app.GetLanguage() == "enUS")
assert(app.L("Einstellungen") == "Settings")
assert(app.L("Paulchens Logbuch") == "Paulchen's Logbook")
assert(app.L("untranslated test sentinel") == "untranslated test sentinel")
assert(app.LF("%d Treffer · %d / %d Plätze frei", 2, 3, 10) == "2 matches · 3 / 10 slots free")

PaulchenQoLSettings.language = "deDE"
assert(app.GetLanguage() == "deDE")
assert(app.L("Einstellungen") == "Einstellungen")
PaulchenQoLSettings.language = "enUS"
locale = "deDE"
assert(app.GetLanguage() == "enUS")
assert(app.L("Einstellungen") == "Settings")

PaulchenQoLSettings.language = "invalid"
assert(app.GetLanguageSetting() == "auto")
assert(app.GetLanguage() == "deDE")
locale = "enUS"

local function placeholders(line)
    local result = {}
    for value in line:gmatch("{(%a+)}") do result[value] = (result[value] or 0) + 1 end
    return result
end
local function samePlaceholders(a, b)
    local left, right = placeholders(a), placeholders(b)
    for key, count in pairs(left) do if right[key] ~= count then return false end end
    for key, count in pairs(right) do if left[key] ~= count then return false end end
    return true
end

local categoryCount, lineCount = 0, 0
for category, german in pairs(app.Dialogue) do
    categoryCount = categoryCount + 1
    local english = assert(app.DialogueEnglish[category], "Missing category " .. category)
    assert(#english == #german, "Dialogue count mismatch for " .. category)
    for i, de in ipairs(german) do
        local en = english[i]
        assert(type(en) == "string" and #en > 0, "Missing English line " .. category .. ":" .. i)
        assert(samePlaceholders(type(de) == "table" and de.text or de, en), "Placeholder mismatch " .. category .. ":" .. i)
        lineCount = lineCount + 1
    end
end
for category in pairs(app.DialogueEnglish) do
    assert(app.Dialogue[category], "Unknown English category " .. category)
end
for key in pairs(app.ContextLines) do
    assert(app.ContextLinesEnglish[key], "Missing English context: " .. key)
end
print(("Localization fixture passed: %d categories, %d translated lines."):format(categoryCount, lineCount))
