local _, suite = ...
local addon = suite.timeline
if not addon then return end
local style = suite.style
local limit = 12

function addon.CreateLevelPanel(panel, label, sourceList, numberText, durationText)
    PaulchenQoLTimelineDB.levelSummary = PaulchenQoLTimelineDB.levelSummary or { history = {} }
    local data = PaulchenQoLTimelineDB.levelSummary
    local started, online

    local function elapsed(entry)
        return entry.elapsed + (entry == data.active and started and math.max(0, GetTime() - started) or 0)
    end

    local function rate(entry, seconds)
        return seconds >= 1 and numberText(entry.xp * 3600 / seconds) or "–"
    end

    local function compare(entry, first)
        if entry.partial or entry.elapsed < 1 then return end
        for index = first, #data.history do
            local previous = data.history[index]
            if not previous.partial and previous.elapsed >= 1 and previous.xp > 0 then
                entry.comparisonLevel = previous.level
                entry.comparisonPercent = (entry.xp * previous.elapsed / (entry.elapsed * previous.xp) - 1) * 100
                return
            end
        end
    end

    local function comparisonText(entry)
        local delta = entry and entry.comparisonPercent
        if not delta then return end
        local text = math.abs(delta) < 0.05 and "0,0" or ("%+.1f"):format(delta):gsub("%.", ",")
        return ("Stufe %d · %s %% EP/h gegenüber Stufe %d"):format(entry.level, text, entry.comparisonLevel)
    end

    for index, entry in ipairs(data.history) do
        if not entry.comparisonLevel then compare(entry, index + 1) end
    end

    local function topSource(entry)
        local name, highest = "–", 0
        for _, source in ipairs(sourceList) do
            local amount = entry.sources[source[1]] or 0
            if amount > highest then
                name, highest = source[2], amount
            elseif amount > 0 and amount == highest then
                name = "Gleichstand"
            end
        end
        return name
    end

    label(panel, "GameFontNormalLarge", "TOPLEFT", "TOPLEFT", 12, -34):SetText("Stufenbilanz")
    local activeText = label(panel, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -61)
    local comparisonLabel = label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12, -80)
    label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12, -101):SetText("STUFE")
    label(panel, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -231, -101):SetText("DAUER")
    label(panel, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -130, -101):SetText("EP/H")
    label(panel, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -12, -101):SetText("TOP-QUELLE")
    local empty = label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12, -130)
    empty:SetText("Die Bilanz füllt sich bei deinen nächsten Stufenaufstiegen.")

    local rows = {}
    for index = 1, limit do
        local row = CreateFrame("Frame", nil, panel)
        row:SetPoint("TOPLEFT", 6, -116 - (index - 1) * 15)
        row:SetPoint("TOPRIGHT", -6, -116 - (index - 1) * 15)
        row:SetHeight(14)
        style.Row(row, index)
        row.level = label(row, "GameFontNormalSmall", "LEFT", "LEFT", 6, 0)
        row.duration = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -225, 0)
        row.rate = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -124, 0)
        row.source = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -6, 0)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            local entry = self.entry
            if not entry then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(("Stufe %d · %s EP"):format(entry.level, numberText(entry.xp)), 1, 0.82, 0)
            for _, source in ipairs(sourceList) do
                local amount = entry.sources[source[1]] or 0
                GameTooltip:AddDoubleLine(source[2], numberText(amount) .. " EP", source[3], source[4], source[5], 1, 1, 1)
            end
            if entry.partial then
                GameTooltip:AddLine("Zeit und EP für den aufgezeichneten Teil der Stufe.", 0.7, 0.75, 0.82, true)
            end
            local comparison = comparisonText(entry)
            if comparison then GameTooltip:AddLine(comparison, 0.7, 0.75, 0.82, true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[index] = row
    end

    local function render()
        local active = data.active
        if active then
            local seconds = elapsed(active)
            activeText:SetText(("Stufe %d%s läuft · %s · %s EP/h"):format(active.level, active.partial and " *" or "", durationText(seconds), rate(active, seconds)))
        else
            activeText:SetText("")
        end
        comparisonLabel:SetText(comparisonText(data.history[1]) or "Gemessene Spielzeit · * teilweise erfasst")
        empty:SetShown(#data.history == 0)
        for index, row in ipairs(rows) do
            local entry = data.history[index]
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then
                row.level:SetText(tostring(entry.level) .. (entry.partial and " *" or ""))
                row.duration:SetText(durationText(entry.elapsed))
                row.rate:SetText(rate(entry, entry.elapsed))
                row.source:SetText(topSource(entry))
            end
        end
    end

    local function begin(progress, partial)
        if progress.maximum > 0 then
            data.active = { level = progress.level, elapsed = 0, xp = 0, sources = { other = 0 }, partial = partial }
            started = GetTime()
        end
    end

    local function finish(partial)
        local entry = data.active
        entry.elapsed = elapsed(entry)
        entry.partial = entry.partial or partial
        compare(entry, 1)
        table.insert(data.history, 1, entry)
        if #data.history > limit then
            table.remove(data.history)
        end
        data.active, started = nil, nil
    end

    local function credit(amount, shares)
        local entry = data.active
        if entry and amount > 0 then
            entry.xp = entry.xp + amount
            entry.sources.other = entry.sources.other + amount
            shares[entry] = (shares[entry] or 0) + amount
        end
    end

    local function progress(previous, current, gain, shares)
        if not online then
            return
        end
        previous = previous or current
        if data.active and data.active.level ~= previous.level then
            if data.active.level < previous.level then
                finish(true)
            else
                return
            end
        end
        if not data.active then
            begin(previous.maximum == 0 and previous.level == current.level and current or previous, true)
        elseif not started then
            started = GetTime()
        end
        if current.level > previous.level then
            local carried = math.min(gain, math.max(0, previous.maximum - previous.xp))
            credit(carried, shares)
            if data.active then
                finish(false)
            end
            begin(current, false)
            credit(gain - carried, shares)
        else
            credit(gain, shares)
        end
    end

    local function attribute(shares, claims, claimed)
        local entry, observed = next(shares)
        if not entry then
            return
        end
        local another = next(shares, entry)
        if not another and claimed <= observed then
            for kind, amount in pairs(claims) do
                entry.sources[kind] = (entry.sources[kind] or 0) + amount
            end
            entry.sources.other = entry.sources.other - claimed
            return
        end
        local kind = next(claims)
        if next(claims, kind) then
            return
        end
        local total = 0
        for _, amount in pairs(shares) do
            total = total + amount
        end
        if total == claimed then
            for record, amount in pairs(shares) do
                record.sources[kind] = (record.sources[kind] or 0) + amount
                record.sources.other = record.sources.other - amount
            end
        end
    end

    return {
        Render = render,
        Progress = progress,
        Attribute = attribute,
        EnterWorld = function() online = true end,
        LeaveWorld = function()
            if data.active then
                data.active.elapsed = elapsed(data.active)
            end
            started, online = nil, false
        end,
    }
end
