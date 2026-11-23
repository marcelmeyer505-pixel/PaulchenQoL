local _, suite = ...
local addon = suite.timeline
if not addon then return end
local style = suite.style
local sampleLimit = 300

function addon.TrackOpponentFights(history)
    local db = PaulchenQoLTimelineDB
    db.opponentFights = db.opponentFights or {}
    local archive = db.opponentFights
    local sequence = db.opponentSequence or 0
    for index = #history, 1, -1 do
        local fight = history[index]
        local name = fight.name
        if name and name ~= "Kampf" and name ~= "Unknown" and name ~= "Unbekannt"
            and name ~= "Fight" and not name:match("^Kampf #%d+$") and not name:match("^Fight #%d+$") then
            if not fight.profileId then
                sequence = sequence + 1
                fight.profileId = sequence
            end
            if fight.profileId > sequence - sampleLimit then
                archive[fight.profileId] = { name = name, duration = fight.duration, dps = fight.dps }
            end
        end
    end
    for id = (db.opponentSequence or 0) + 1, sequence do
        archive[id - sampleLimit] = nil
    end
    db.opponentSequence = sequence
end

local function summarize(query)
    local byName, result = {}, {}
    for id, fight in pairs(PaulchenQoLTimelineDB.opponentFights) do
        if fight.name:lower():find(query, 1, true) then
            local profile = byName[fight.name]
            if not profile then
                profile = { name = fight.name, dpsSum = 0, dpsCount = 0, count = 0 }
                byName[fight.name] = profile
                result[#result + 1] = profile
            end
            profile.count = profile.count + 1
            if fight.duration and fight.duration > 0 and (not profile.bestTime or fight.duration < profile.bestTime) then
                profile.bestTime = fight.duration
            end
            if fight.dps then
                profile.dpsSum = profile.dpsSum + fight.dps
                profile.dpsCount = profile.dpsCount + 1
            end
            if not profile.lastId or id > profile.lastId then
                profile.lastId, profile.last = id, fight
            end
        end
    end
    table.sort(result, function(a, b) return a.lastId > b.lastId end)
    return result
end

function addon.CreateOpponentPanel(panel, label, formatDuration, formatDps)
    label(panel, "GameFontNormal", "TOPLEFT", "TOPLEFT", 12, -35):SetText(suite.L("Gegnerprofile"))
    local search = style.EditBox(panel)
    search:SetPoint("TOPRIGHT", -12, -32)
    search:SetSize(150, 20)
    search:SetMaxLetters(80)
    search:SetText("")
    search:SetScript("OnEnterPressed", search.ClearFocus)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnHide", search.ClearFocus)
    label(panel, "GameFontHighlightSmall", "TOPRIGHT", "TOPRIGHT", -170, -37):SetText(suite.L("Suche"))
    label(panel, "GameFontNormalSmall", "TOPLEFT", "TOPLEFT", 12, -62):SetText(suite.L("Gegner"))
    label(panel, "GameFontNormalSmall", "TOPRIGHT", "TOPRIGHT", -152, -62):SetText(suite.L("Bestzeit"))
    label(panel, "GameFontNormalSmall", "TOPRIGHT", "TOPRIGHT", -81, -62):SetText(suite.L("Ø DPS"))
    label(panel, "GameFontNormalSmall", "TOPRIGHT", "TOPRIGHT", -12, -62):SetText(suite.L("Letzte DPS"))
    local pageText = label(panel, "GameFontHighlightSmall", "BOTTOMLEFT", "BOTTOMLEFT", 12, 8)
    local function arrow(text, x)
        local button = style.TextButton(panel)
        button:SetPoint("BOTTOMRIGHT", x, 6)
        button:SetSize(26, 20)
        button:SetText(text)
        return button
    end
    local previous, nextPage = arrow("<", -41), arrow(">", -12)
    local rows, page = {}, 1
    for index = 1, 10 do
        local row = CreateFrame("Frame", nil, panel)
        local y = -80 - (index - 1) * 20
        row:SetPoint("TOPLEFT", 8, y)
        row:SetPoint("TOPRIGHT", -8, y)
        row:SetHeight(19)
        row:EnableMouse(true)
        style.Row(row, index)
        row.name = label(row, "GameFontHighlightSmall", "LEFT", "LEFT", 4, 0)
        row.name:SetWidth(145)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.best = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -144, 0)
        row.average = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -73, 0)
        row.last = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -4, 0)
        row:SetScript("OnEnter", function(self)
            local profile = self.profile
            if not profile then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(profile.name:gsub("|", "||"), 1, 1, 1)
            GameTooltip:AddLine((suite.L("%d Kämpfe · %d mit DPS")):format(profile.count, profile.dpsCount), 0.8, 0.85, 0.9)
            GameTooltip:AddLine(suite.L("Letzter Kampf · ") .. formatDuration(profile.last.duration), 0.8, 0.85, 0.9)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[index] = row
    end
    local function render()
        local query = search:GetText():lower():match("^%s*(.-)%s*$")
        local profiles = summarize(query)
        local pages = math.max(1, math.ceil(#profiles / #rows))
        page = math.min(page, pages)
        for index, row in ipairs(rows) do
            local profile = profiles[(page - 1) * #rows + index]
            row.profile = profile
            row:SetShown(profile ~= nil)
            if profile then
                row.name:SetText(profile.name:gsub("|", "||"))
                row.best:SetText(formatDuration(profile.bestTime))
                row.average:SetText(formatDps(profile.dpsCount > 0 and profile.dpsSum / profile.dpsCount))
                row.last:SetText(formatDps(profile.last.dps))
            end
        end
        pageText:SetText(suite.LF("%d Gegnerprofile  ·  Seite %d/%d", #profiles, page, pages))
        previous:SetEnabled(page > 1)
        nextPage:SetEnabled(page < pages)
    end
    search:SetScript("OnTextChanged", function()
        page = 1
        render()
    end)
    previous:SetScript("OnClick", function()
        page = page - 1
        render()
    end)
    nextPage:SetScript("OnClick", function()
        page = page + 1
        render()
    end)
    return render
end
