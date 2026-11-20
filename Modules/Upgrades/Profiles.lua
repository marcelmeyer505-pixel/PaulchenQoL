local _, suite = ...
local app = suite.upgrades
if not app then return end

app.weightFields = {
    { "str", "Stärke" }, { "agi", "Beweglichkeit" }, { "sta", "Ausdauer" },
    { "int", "Intelligenz" }, { "spi", "Willenskraft" }, { "armor", "Rüstung" },
    { "ap", "Angriffskraft" }, { "rap", "Distanzangriffskraft" },
    { "dps", "Nahkampfwaffen-DPS" }, { "rdps", "Fernkampfwaffen-DPS" },
    { "hit", "Nahkampftreffer (%)" }, { "crit", "Nahkampfkrit (%)" },
    { "hastePercent", "Angriffstempo (%)" }, { "expertise", "Waffenkundewertung" },
    { "armorPen", "Rüstungsdurchschlag" }, { "defense", "Verteidigung" },
    { "dodge", "Ausweichen (%)" }, { "parry", "Parieren (%)" }, { "block", "Blocken (%)" },
    { "blockValue", "Blockwert" }, { "sp", "Zauberschaden" }, { "heal", "Heilbonus" },
    { "spellHit", "Zaubertreffer (%)" }, { "spellCrit", "Zauberkrit (%)" },
    { "spellHaste", "Zaubertempo (%)" }, { "mp5", "Mana je 5 Sek." },
}

local melee = { str = 1, agi = 0.7, sta = 0.15, ap = 0.5, dps = 5,
    hit = 10, crit = 8, hastePercent = 5, expertise = 0.8, armorPen = 0.2 }
local ranged = { agi = 1, sta = 0.15, int = 0.25, ap = 0.45, rap = 0.45,
    rdps = 5.5, hit = 10, crit = 7, hastePercent = 4, mp5 = 0.3, armorPen = 0.15 }
local caster = { int = 0.5, spi = 0.2, sta = 0.15, sp = 1,
    spellHit = 11, spellCrit = 8, spellHaste = 6, mp5 = 0.6 }
local healer = { int = 0.65, spi = 0.5, sta = 0.15, heal = 1,
    spellCrit = 4, spellHaste = 5, mp5 = 2 }
local tank = { sta = 1, armor = 0.07, str = 0.45, agi = 0.65, ap = 0.2, dps = 2,
    defense = 0.65, dodge = 10, parry = 10, block = 5, blockValue = 0.45, hit = 5, expertise = 0.55 }

local function profile(key, name, base, changes, schools)
    local weights = {}
    for stat, value in pairs(base) do weights[stat] = value end
    for stat, value in pairs(changes or {}) do weights[stat] = value end
    return { key = key, name = name, weights = weights, schools = schools }
end

-- Editable starting values for Forever. Each spec owns its own defaults.
local profiles = {
    WARRIOR = {
        profile("arms", "Waffen", melee, { dps = 5.7, armorPen = 0.28 }),
        profile("fury", "Furor", melee, { hit = 12, crit = 9, hastePercent = 6 }),
        profile("protection", "Schutz", tank),
    },
    PALADIN = {
        profile("retribution", "Vergeltung", melee, { str = 1.2, sp = 0.3, int = 0.3 }, { spHoly = 1 }),
        profile("protection", "Schutz", tank, { sp = 0.8, int = 0.4, dps = 0.5, blockValue = 0.7 }, { spHoly = 1 }),
        profile("holy", "Heilig", healer, { int = 1, spellCrit = 7, spi = 0.2 }),
    },
    HUNTER = {
        profile("beastmastery", "Tierherrschaft", ranged, { rdps = 6, hastePercent = 5 }),
        profile("marksmanship", "Treffsicherheit", ranged, { rap = 0.55, crit = 8 }),
        profile("survival", "Überleben", ranged, { agi = 1.2, crit = 8 }),
    },
    ROGUE = {
        profile("combat", "Kampf", melee, { str = 0.5, agi = 1, hit = 12, dps = 6, hastePercent = 6 }),
        profile("assassination", "Meucheln", melee, { str = 0.5, agi = 1, crit = 9, ap = 0.55 }),
        profile("subtlety", "Täuschung", melee, { str = 0.5, agi = 1.15, crit = 9, armorPen = 0.25 }),
    },
    PRIEST = {
        profile("shadow", "Schatten", caster, { spellCrit = 4, mp5 = 1 }, { spShadow = 1 }),
        profile("discipline", "Disziplin", healer, { int = 0.85, spellCrit = 6 }),
        profile("holy", "Heilig", healer, { spi = 0.8, spellHaste = 6 }),
    },
    SHAMAN = {
        profile("enhancement", "Verstärkung", melee, { int = 0.5, sp = 0.35, spellHit = 4, hastePercent = 6 }),
        profile("elemental", "Elementar", caster, { spellCrit = 10, mp5 = 1.1 }, { spNature = 0.8, spFire = 0.2 }),
        profile("restoration", "Wiederherstellung", healer, { mp5 = 2.4, spellCrit = 6 }),
    },
    MAGE = {
        profile("frost", "Frost", caster, { spellHit = 10, spellCrit = 7 }, { spFrost = 1 }),
        profile("fire", "Feuer", caster, { spellCrit = 11 }, { spFire = 1 }),
        profile("arcane", "Arkan", caster, { int = 0.85, mp5 = 1.2, spellHaste = 8 }, { spArcane = 1 }),
    },
    WARLOCK = {
        profile("affliction", "Gebrechen", caster, { spellCrit = 4, spi = 0.35, sta = 0.3 }, { spShadow = 1 }),
        profile("demonology", "Dämonologie", caster, { sta = 0.6, int = 0.6 }, { spShadow = 0.8, spFire = 0.2 }),
        profile("destruction", "Zerstörung", caster, { spellCrit = 11 }, { spShadow = 0.5, spFire = 0.5 }),
    },
    DRUID = {
        profile("cat", "Feral Katze", {}, { agi = 1.90, str = 0.80, ap = 0.40, dps = 5.60,
            hit = 8.77, crit = 10.2, hastePercent = 4.78, expertise = 0.85, armorPen = 0.13 }),
        profile("bear", "Feral Bär", tank, { armor = 0.13, agi = 1, parry = 0, block = 0, blockValue = 0 }),
        profile("balance", "Gleichgewicht", caster, { spellCrit = 9, int = 0.7 }, { spArcane = 0.6, spNature = 0.4 }),
        profile("restoration", "Wiederherstellung", healer, { spi = 0.8, spellCrit = 2 }),
    },
}
local maxWeight = 1000000

local function validWeight(value)
    return type(value) == "number" and value >= 0 and value <= maxWeight
end

local function database()
    PaulchenQoLUpgradesDB = PaulchenQoLUpgradesDB or {}
    local db = PaulchenQoLUpgradesDB
    if type(db.statProfiles) ~= "table" then db.statProfiles = {} end
    return db
end

local function characterClass()
    if UnitClass then
        local _, class = UnitClass("player")
        return suite.Readable(class)
    end
end

function app.ProfileChoices(class)
    return profiles[class or characterClass()] or {}
end

function app.ActiveProfile()
    local class = characterClass()
    local db, choices = database(), app.ProfileChoices(class)
    for _, choice in ipairs(choices) do
        if choice.key == db.activeStatProfile then return choice, class end
    end
    return choices[1], class
end

function app.ProfileName()
    local choice = app.ActiveProfile()
    return choice and choice.name or "–"
end

function app.ProfileWeights(choice, class)
    if not choice then choice, class = app.ActiveProfile() end
    if not choice then return {} end
    local saved = database().statProfiles[class .. ":" .. choice.key]
    local weights = {}
    for _, field in ipairs(app.weightFields) do
        local key = field[1]
        local value = type(saved) == "table" and saved[key] or nil
        if not validWeight(value) then value = choice.weights[key] or 0 end
        weights[key] = value
    end
    return weights
end

function app.SelectProfile(key)
    local current = app.ActiveProfile()
    if current and current.key == key then return end
    for _, choice in ipairs(app.ProfileChoices()) do
        if choice.key == key then
            database().activeStatProfile = key
            app.gear.Invalidate("profile")
            return
        end
    end
end

function app.SaveProfileWeights(weights)
    local choice, class = app.ActiveProfile()
    if not choice then return false end
    if weights then
        for _, field in ipairs(app.weightFields) do
            local value = weights[field[1]]
            if not validWeight(value) then return false end
        end
    end
    database().statProfiles[class .. ":" .. choice.key] = weights
    app.gear.Invalidate("profile")
    return true
end
