local _, suite = ...
local addon = suite.timeline
if not addon then return end
local style = suite.style
local historySize, archiveSize, comparisonMinimum = 10, 200, 300

local function areaName()
    local area = GetRealZoneText()
    if not issecretvalue(area) and type(area) == "string" and area ~= "" then
        return area
    end
end

local function durationText(seconds)
    local total = math.floor(seconds)
    local hours, minutes = math.floor(total / 3600), math.floor(total / 60) % 60
    if hours > 0 then
        return ("%d:%02d:%02d"):format(hours, minutes, total % 60)
    end
    return ("%d:%02d"):format(minutes, total % 60)
end

local function rateText(run, elapsed)
    if elapsed < 1 then
        return "–"
    end
    return (run.partial and "≥ " or "") .. BreakUpLargeNumbers(math.floor(run.xp * 3600 / elapsed + 0.5))
end

local function displayArea(run)
    return ((run.area or "Unbekanntes Gebiet"):gsub("|", "||")) .. (run.mixed and " *" or "")
end

local function comparable(run, seconds)
    return run.area and not run.mixed and not run.partial and seconds >= comparisonMinimum
end

local function moneyText(copper)
    return ("%d G %02d S %02d K"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function signed(value, formatter)
    return (value < 0 and "−" or value > 0 and "+" or "") .. formatter(math.abs(value))
end

function addon.CreateFarmPanel(panel, label, syncProgress, openArchive)
    PaulchenQoLTimelineDB.farmRounds = PaulchenQoLTimelineDB.farmRounds or { history = {} }
    local data = PaulchenQoLTimelineDB.farmRounds
    local started, ready, selectRound
    local selected = {}
    local function pruneHistory()
        local ordinary = 0
        for _, run in ipairs(data.history) do
            if not run.favorite then
                ordinary = ordinary + 1
            end
        end
        for index = #data.history, 1, -1 do
            if ordinary <= archiveSize then break end
            local run = data.history[index]
            if not run.favorite then
                table.remove(data.history, index)
                if selected[1] == run then
                    table.remove(selected, 1)
                elseif selected[2] == run then
                    selected[2] = nil
                end
                ordinary = ordinary - 1
            end
        end
    end
    local function mark(run)
        return run == selected[1] and "A" or run == selected[2] and "B" or nil
    end
    local function compare()
        local a, b = selected[1], selected[2]
        if not b then
            return "", a and suite.L("Klicke eine zweite Runde für den Vergleich.") or ""
        end
        local summary = "B − A  ·  " .. signed(b.elapsed - a.elapsed, durationText)
        if a.partial or b.partial then
            return summary, "EP teilweise erfasst"
        end
        summary = summary .. "  ·  " .. signed(b.xp - a.xp, BreakUpLargeNumbers) .. " EP"
        if a.elapsed < 1 or b.elapsed < 1 then
            return summary, ""
        end
        local delta = b.xp * 3600 / b.elapsed - a.xp * 3600 / a.elapsed
        return summary, signed(delta, function(value) return BreakUpLargeNumbers(math.floor(value + 0.5)) end) .. " EP/h Unterschied"
    end
    local function saveBest(run)
        if comparable(run, run.elapsed) and run.xp > 0 then
            local rate = run.xp * 3600 / run.elapsed
            data.best[run.area] = math.max(data.best[run.area] or 0, rate)
        end
    end
    if not data.best then
        data.best = {}
        for _, run in ipairs(data.history) do
            saveBest(run)
        end
    end

    label(panel, "GameFontNormalLarge", "TOPLEFT", "TOPLEFT", 12, -34):SetText("Farmrunden")
    local status = label(panel, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -62)
    status:SetPoint("RIGHT", panel, "RIGHT", -143, 0)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(false)
    label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12, -83):SetText("Name")
    local nameBox = style.EditBox(panel)
    nameBox:SetPoint("TOPLEFT", 54, -77)
    nameBox:SetWidth(114)
    nameBox:SetHeight(20)
    nameBox:SetMaxLetters(48)
    nameBox:SetText(data.active and data.active.name or "")
    local function roundName()
        local name = (nameBox:GetText() or ""):match("^%s*(.-)%s*$")
        return name ~= "" and name or nil
    end
    nameBox:SetScript("OnTextChanged", function(_, userInput)
        if userInput and data.active then
            data.active.name = roundName()
        end
    end)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnHide", function(self) self:ClearFocus() end)
    label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 175, -83):SetText(suite.L("Item/Ziel"))
    local itemBox = style.EditBox(panel)
    itemBox:SetPoint("TOPLEFT", 211, -77)
    itemBox:SetPoint("TOPRIGHT", -66, -77)
    itemBox:SetHeight(20)
    itemBox:SetMaxLetters(128)
    itemBox:SetText(data.active and data.active.item or "")
    itemBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    itemBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    itemBox:SetScript("OnHide", function(self) self:ClearFocus() end)
    local goalBox = style.EditBox(panel)
    goalBox:SetPoint("TOPRIGHT", -12, -77)
    goalBox:SetSize(43, 20)
    goalBox:SetTextInsets(3, 3, 0, 0)
    goalBox:SetNumeric(true)
    goalBox:SetMaxLetters(6)
    goalBox:SetText(data.active and tostring(data.active.goal or "") or "")
    goalBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    goalBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    goalBox:SetScript("OnHide", function(self) self:ClearFocus() end)
    goalBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(suite.L("Stückziel für das ausgewählte Item"), 1, 1, 1)
        GameTooltip:Show()
    end)
    goalBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local metrics = label(panel, "GameFontNormal", "TOPLEFT", "TOPLEFT", 12, -103)
    local comparison = label(panel, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -122)
    local lootText = label(panel, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -137)
    lootText:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
    lootText:SetJustifyH("LEFT")
    lootText:SetWordWrap(false)
    local archiveButton = style.TextButton(panel)
    archiveButton:SetPoint("TOPRIGHT", -12, -100)
    archiveButton:SetSize(57, 20)
    archiveButton:SetText("Archiv")
    archiveButton:SetScript("OnClick", openArchive)

    local function control(text, x)
        local button = style.TextButton(panel)
        button:SetPoint("TOPRIGHT", x, -55)
        button:SetSize(53, 21)
        button:SetText(text)
        return button
    end
    local startButton = control(suite.L("Start"), -69)
    startButton:SetWidth(68)
    local stopButton = control("Stopp", -10)

    label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12, -153):SetText("RUNDE / GEBIET")
    label(panel, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -125, -153):SetText("DAUER")
    label(panel, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -68, -153):SetText("EP")
    label(panel, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -12, -153):SetText("EP/H")
    local empty = label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12, -175)
    empty:SetText("Abgeschlossene Runden erscheinen hier.")

    local rows = {}
    for index = 1, historySize do
        local row = CreateFrame("Frame", nil, panel)
        row:SetPoint("TOPLEFT", 6, -166 - (index - 1) * 14)
        row:SetPoint("TOPRIGHT", -6, -166 - (index - 1) * 14)
        row:SetHeight(13)
        style.Row(row, index)
        row.area = label(row, "GameFontHighlightSmall", "LEFT", "LEFT", 6, 0)
        row.area:SetPoint("RIGHT", row, "RIGHT", -172, 0)
        row.area:SetJustifyH("LEFT")
        row.area:SetWordWrap(false)
        row.duration = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -119, 0)
        row.xp = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -62, 0)
        row.rate = label(row, "GameFontNormalSmall", "RIGHT", "RIGHT", -6, 0)
        row:EnableMouse(true)
        row:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and self.run and not data.active then selectRound(self.run) end
        end)
        row:SetScript("OnEnter", function(self)
            local run = self.run
            if not run then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(run.name and (run.name:gsub("|", "||")) or displayArea(run), 1, 0.82, 0)
            if run.name then
                GameTooltip:AddLine(displayArea(run), 1, 1, 1)
            end
            GameTooltip:AddLine("Abgeschlossen am " .. date("%d.%m. um %H:%M", run.ended), 1, 1, 1)
            if run.copper then GameTooltip:AddLine(suite.L("Münzbeute · ") .. moneyText(run.copper), 1, 1, 1) end
            if run.item then GameTooltip:AddLine(("%d × %s"):format(run.itemCount or 0, ((run.itemLabel or run.item):gsub("|", "||"))), 1, 1, 1) end
            if run.goal then GameTooltip:AddLine(("Farmziel · %d/%d"):format(run.itemCount or 0, run.goal), 1, 1, 1) end
            if not data.active then GameTooltip:AddLine(suite.L("Klick markiert die Runde für den Vergleich."), 0.7, 0.75, 0.82) end
            if run.mixed then
                GameTooltip:AddLine(suite.L("Diese Runde führte durch mehrere Gebiete."), 0.7, 0.75, 0.82)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[index] = row
    end

    local function renderHistory()
        empty:SetShown(#data.history == 0)
        for index, row in ipairs(rows) do
            local run = data.history[index]
            row.run = run
            row:SetShown(run ~= nil)
            if run then
                local name = run.name and ((run.name:gsub("|", "||")) .. " · ") or ""
                local choice = mark(run)
                row.area:SetText((choice and choice .. " · " or "") .. name .. displayArea(run))
                row.duration:SetText(durationText(run.elapsed))
                row.xp:SetText((run.partial and "≥ " or "") .. BreakUpLargeNumbers(run.xp))
                row.rate:SetText(rateText(run, run.elapsed))
            end
        end
    end

    local function elapsed(run)
        return run.elapsed + (started and math.max(0, GetTime() - started) or 0)
    end

    local function render()
        local run = data.active
        startButton:SetEnabled(ready == true)
        startButton:SetText(run and (run.paused and "Fortsetzen" or suite.L("Pause")) or suite.L("Start"))
        stopButton:SetEnabled(ready == true and run ~= nil)
        itemBox:SetEnabled(not run)
        goalBox:SetEnabled(not run)
        if run then
            local seconds = elapsed(run)
            status:SetText((run.paused and "Pausiert · " or suite.L("Läuft · ")) .. displayArea(run))
            local experience = (run.partial and "≥ " or "") .. BreakUpLargeNumbers(run.xp)
            metrics:SetText(("%s  ·  %s EP  ·  %s EP/h"):format(durationText(seconds), experience, rateText(run, seconds)))
            local count = run.itemCount or 0
            local item = run.item and ("  ·  %d × %s"):format(count, ((run.itemLabel or run.item):gsub("|", "||"))) or ""
            if run.goal then
                local hint = ""
                if count >= run.goal then
                    hint = suite.L(" · Ziel erreicht")
                elseif count > 0 and seconds > 0 then
                    hint = " · noch ca. " .. durationText(math.ceil((run.goal - count) * seconds / count))
                end
                item = (suite.L(" · Ziel %d/%d%s")):format(count, run.goal, hint)
            end
            lootText:SetText(moneyText(run.copper or 0) .. item)
            local best = run.area and data.best[run.area]
            comparison:SetTextColor(unpack(style.muted))
            if comparable(run, seconds) and best then
                local delta = (run.xp * 3600 / seconds / best - 1) * 100
                local text = math.abs(delta) < 0.05 and "0,0" or ("%+.1f"):format(delta):gsub("%.", ",")
                comparison:SetText(text .. " % EP/h zur besten Runde im Gebiet")
                if delta >= 0.05 then
                    comparison:SetTextColor(unpack(style.green))
                elseif delta <= -0.05 then
                    comparison:SetTextColor(unpack(style.orange))
                end
            elseif not run.mixed and not run.partial and best then
                comparison:SetText("Vergleich zur besten Runde ab 5 Minuten")
            elseif not run.mixed and not run.partial then
                comparison:SetText("Erste Vergleichsrunde im Gebiet ab 5 Minuten")
            else
                comparison:SetText(run.mixed and "Gebietswechsel · Vergleich pausiert" or "EP teilweise erfasst · Vergleich pausiert")
            end
        else
            status:SetText(suite.L("Bereit für eine Runde"))
            comparison:SetTextColor(unpack(style.muted))
            lootText:SetText("")
            local summary, delta = compare()
            metrics:SetText(summary)
            comparison:SetText(delta)
        end
    end

    selectRound = function(run)
        if selected[1] == run then
            table.remove(selected, 1)
        elseif selected[2] == run then
            selected[2] = nil
        elseif selected[2] then
            selected[2] = run
        else
            selected[#selected + 1] = run
        end
        renderHistory()
        render()
    end
    addon.ListenFarmLoot(function() return ready and data.active and not data.active.paused and data.active end, function()
        if panel:IsVisible() then render() end
    end)

    local function updateArea()
        local run, area = data.active, areaName()
        if run and not run.paused and area then
            if not run.area then
                run.area = area
            elseif run.area ~= area then
                run.mixed = true
            end
        end
    end

    local function saveElapsed()
        if data.active and started then
            data.active.elapsed = elapsed(data.active)
        end
        started = nil
    end

    local function toggle()
        if not ready then
            return
        end
        if not syncProgress() then
            status:SetText("EP-Daten werden geladen …")
            return
        end
        if data.active then
            if data.active.paused then
                data.active.paused = nil
                started = GetTime()
                updateArea()
            else
                saveElapsed()
                data.active.paused = true
            end
            render()
            return
        end
        local item = (itemBox:GetText() or ""):match("^%s*(.-)%s*$")
        local goal = tonumber(goalBox:GetText()) or 0
        data.active = { area = areaName(), elapsed = 0, xp = 0, name = roundName(), copper = 0,
            item = item ~= "" and item or nil, itemCount = 0, goal = item ~= "" and goal > 0 and goal or nil }
        selected = {}
        renderHistory()
        nameBox:ClearFocus()
        itemBox:ClearFocus()
        goalBox:ClearFocus()
        started = GetTime()
        render()
    end
    local function stop()
        if not ready or not data.active then
            return
        end
        if not syncProgress() then
            status:SetText("EP-Daten werden geladen …")
            return
        end
        updateArea()
        saveElapsed()
        local run = data.active
        run.name = roundName()
        run.paused = nil
        run.ended = time()
        saveBest(run)
        table.insert(data.history, 1, run)
        data.active = nil
        nameBox:SetText("")
        nameBox:ClearFocus()
        pruneHistory()
        renderHistory()
        render()
    end
    startButton:SetScript("OnClick", toggle)
    stopButton:SetScript("OnClick", stop)

    renderHistory()
    render()
    return {
        History = data.history,
        Select = selectRound,
        Mark = mark,
        Compare = compare,
        Prune = pruneHistory,
        AreaText = displayArea,
        DurationText = durationText,
        RateText = rateText,
        Render = render,
        Toggle = toggle,
        Stop = stop,
        Snapshot = function()
            local run = data.active
            if not run then return { ready = ready == true } end
            return { ready = ready == true, active = true, paused = run.paused,
                area = run.area, name = run.name, elapsed = elapsed(run), xp = run.xp, partial = run.partial,
                goal = run.goal, item = run.itemLabel or run.item, itemCount = run.itemCount or 0 }
        end,
        Mini = function()
            local run = data.active
            if run and run.goal then
                return (suite.L("Ziel %d/%d")):format(run.itemCount or 0, run.goal)
            end
            return run and (run.paused and "Farm pausiert" or "Farm " .. durationText(elapsed(run))) or "Farm bereit"
        end,
        State = function()
            return data.active and (data.active.paused and "paused" or "active") or "idle"
        end,
        Record = function(gain, partial)
            if data.active and not data.active.paused then
                data.active.xp = data.active.xp + gain
                data.active.partial = data.active.partial or partial
                updateArea()
            end
        end,
        EnterWorld = function()
            ready = true
            if data.active and not data.active.paused and not started then
                started = GetTime()
            end
            updateArea()
        end,
        LeaveWorld = function()
            saveElapsed()
            ready = false
        end,
        UpdateArea = updateArea,
    }
end
