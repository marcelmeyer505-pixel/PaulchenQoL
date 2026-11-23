local _, suite = ...
local addon = suite.timeline
if not addon then return end
local style = suite.style
local historySize = 4
local enemySampleSize = 10
local rollingSeconds = 15 * 60
local blockSeconds, trendSize = 5 * 60, 12
local sources = {
    { "quest", suite.L("Quests"), 0.85, 0.63, 0.29 },
    { "enemy", suite.L("Gegner"), 0.62, 0.43, 0.89 },
    { "explore", suite.L("Erkundung"), 0.31, 0.68, 0.80 },
    { "other", suite.L("Sonstiges"), 0.47, 0.52, 0.60 },
}

local function readableNumber(value)
    return not issecretvalue(value) and type(value) == "number" and value >= 0 and value < math.huge
end

local function snapshot()
    local level, xp, maximum = UnitLevel("player"), UnitXP("player"), UnitXPMax("player")
    if not readableNumber(level) or level == 0 or not readableNumber(xp) or not readableNumber(maximum) then
        return
    end
    local cap = GameRulesUtil and GameRulesUtil.GetEffectiveMaxLevelForPlayer and GameRulesUtil.GetEffectiveMaxLevelForPlayer()
    if not readableNumber(cap) and GetMaxPlayerLevel then
        cap = GetMaxPlayerLevel()
    end
    if maximum == 0 or (readableNumber(cap) and cap > 0 and level >= cap) then
        xp, maximum = 0, 0
    elseif xp > maximum then
        return -- XP and level can briefly describe different levels.
    end
    return { level = level, xp = xp, maximum = maximum }
end

local function initAnalysis(session)
    if not session.sources then
        session.sources = { quest = 0, enemy = 0, explore = 0, other = session.total }
    end
    if not session.trend then
        session.trend, session.trendStarted = {}, GetTime()
    end
    if not session.enemyGains then
        session.enemyGains = session.lastEnemy and { session.lastEnemy.xp } or {}
    end
end

local function startSession()
    local session = { started = GetTime(), total = 0, count = 0, best = 0, levels = 0, recent = {}, rolling = {} }
    session.last = snapshot()
    initAnalysis(session)
    PaulchenQoLTimelineDB.xpSession = session
    return session
end

local function trendBlock(session, now)
    return math.max(0, math.floor((now - session.trendStarted) / blockSeconds))
end

local function recentExperience(session, now)
    local total = 0
    local cutoff = math.floor(now) - rollingSeconds
    for second, amount in pairs(session.rolling) do
        if second <= cutoff then
            session.rolling[second] = nil
        else
            total = total + amount
        end
    end
    return total
end

local function recordProgress(session, current)
    local previous = session.last
    if not previous then
        session.last = current
        return 0
    end

    local levels = current.level - previous.level
    if levels < 0 or (levels == 0 and current.xp < previous.xp) then
        return nil -- Wait for the matching level update before rebasing XP.
    end
    session.last = current
    local gain = current.xp - previous.xp
    if levels > 0 then
        session.levels = session.levels + levels
        gain = math.max(0, previous.maximum - previous.xp) + current.xp
        session.partial = session.partial or levels > 1
    end
    if gain <= 0 then
        return 0, levels > 1
    end

    session.total = session.total + gain
    session.count = session.count + 1
    session.best = math.max(session.best, gain)
    local now = GetTime()
    local block = trendBlock(session, now)
    session.trend[block] = (session.trend[block] or 0) + gain
    for index in pairs(session.trend) do
        if index <= block - trendSize then
            session.trend[index] = nil
        end
    end
    session.sources.other = session.sources.other + gain
    local second = math.floor(now)
    session.rolling[second] = (session.rolling[second] or 0) + gain
    recentExperience(session, now)

    local zone = GetRealZoneText()
    if issecretvalue(zone) or not zone or zone == "" then
        zone = suite.L("EP-Gewinn")
    end
    table.insert(session.recent, 1, { gain = gain, at = time(), zone = zone, level = levels > 0 and current.level or nil })
    if #session.recent > historySize then
        table.remove(session.recent)
    end
    return gain, levels > 1
end

local function numberText(value)
    return BreakUpLargeNumbers(math.floor(value + 0.5))
end

local function xpIsPaused()
    local paused = IsXPUserDisabled and IsXPUserDisabled()
    return not issecretvalue(paused) and paused == true
end

local function enemyEstimate(session, remaining)
    local enemyTotal = 0
    for _, amount in ipairs(session.enemyGains) do
        enemyTotal = enemyTotal + amount
    end
    return enemyTotal > 0 and math.ceil(remaining * #session.enemyGains / enemyTotal) or nil
end

local function sessionRate(session, elapsed)
    return elapsed >= 60 and session.total * 3600 / elapsed or nil
end

local function durationText(seconds)
    local minutes = math.floor(seconds / 60)
    if minutes >= 60 then
        return ("%d h %02d min"):format(math.floor(minutes / 60), minutes % 60)
    end
    return ("%d:%02d"):format(minutes, math.floor(seconds) % 60)
end

local function experiencePattern(template)
    if type(template) ~= "string" then
        return
    end
    local parts = { "^" }
    local index, argument, found = 1, 0, false
    while index <= #template do
        local marker = template:find("%", index, true) or #template + 1
        parts[#parts + 1] = template:sub(index, marker - 1):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        if marker > #template then
            break
        end
        if template:sub(marker + 1, marker + 1) == "%" then
            parts[#parts + 1] = "%%"
            index = marker + 2
        else
            argument = argument + 1
            local format = template:sub(marker)
            local position, kind, after = format:match("^%%(%d+)%$([ds])()")
            if not kind then
                kind, after = format:match("^%%([ds])()")
            end
            if not kind then
                return
            end
            if (tonumber(position) or argument) == 2 and kind == "d" then
                parts[#parts + 1] = "(%d+)"
                found = true
            else
                parts[#parts + 1] = kind == "d" and "%d+" or ".-"
            end
            index = marker + after - 1
        end
    end
    if found then
        parts[#parts + 1] = "$"
        return table.concat(parts)
    end
end

local function enemyPatterns()
    local formats = { "COMBATLOG_XPGAIN_FIRSTPERSON" }
    for index = 1, 5 do
        formats[#formats + 1] = "COMBATLOG_XPGAIN_EXHAUSTION" .. index
    end
    local patterns = {}
    for _, name in ipairs(formats) do
        for _, suffix in ipairs({ "", "_GROUP", "_RAID" }) do
            local pattern = experiencePattern(_G[name .. suffix])
            if pattern then
                patterns[#patterns + 1] = pattern
            end
        end
    end
    return patterns
end

local function createAnalysis(panel, label, barTexture)
    label(panel, "GameFontNormalLarge", "TOPLEFT", "TOPLEFT", 12, -34):SetText(suite.L("EP-Quellen"))
    local sourceRows = {}
    for index, source in ipairs(sources) do
        local row = CreateFrame("Frame", nil, panel)
        row:SetPoint("TOPLEFT", 8, -56 - (index - 1) * 19)
        row:SetPoint("TOPRIGHT", -8, -56 - (index - 1) * 19)
        row:SetHeight(17)
        style.Row(row, index)
        label(row, "GameFontHighlightSmall", "LEFT", "LEFT", 5, 0):SetText(source[2])
        row.bar = CreateFrame("StatusBar", nil, row)
        row.bar:SetPoint("LEFT", 92, 0)
        row.bar:SetSize(112, 9)
        row.bar:SetStatusBarTexture(barTexture)
        row.bar:SetStatusBarColor(source[3], source[4], source[5], 1)
        row.bar:SetMinMaxValues(0, 1)
        row.amount = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -5, 0)
        sourceRows[index] = row
    end

    label(panel, "GameFontNormalSmall", "TOPLEFT", "TOPLEFT", 12, -150):SetText(suite.L("EP PRO 5 MINUTEN"))
    local peakText = label(panel, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -12, -150)
    label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12, -280):SetText(suite.L("Älter"))
    label(panel, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -12, -280):SetText(suite.L("Aktueller Block"))
    local bars = {}
    for index = 1, trendSize do
        local bar = CreateFrame("StatusBar", nil, panel)
        bar:SetPoint("BOTTOMLEFT", 12 + (index - 1) * 27, 35)
        bar:SetSize(24, 102)
        bar:SetOrientation("VERTICAL")
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        if index == trendSize then
            bar:SetStatusBarColor(unpack(style.gold))
        else
            bar:SetStatusBarColor(0.63, 0.36, 0.18)
        end
        style.Fill(bar, "BACKGROUND", unpack(style.track))
        bar:EnableMouse(true)
        bar:SetScript("OnEnter", function(self)
            if not self.block or self.block < 0 then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local title = index == trendSize and suite.L("Aktueller Block") or "Abgeschlossener Block"
            GameTooltip:SetText(title, 1, 0.82, 0)
            GameTooltip:AddLine(numberText(self.amount) .. suite.L(" EP"), 1, 1, 1)
            if index ~= trendSize then
                GameTooltip:AddLine(numberText(self.amount * 3600 / blockSeconds) .. suite.L(" EP/h"), 1, 1, 1)
            end
            GameTooltip:AddLine(suite.LF("%s bis %s seit Sitzungsstart", durationText(self.from), durationText(self.from + blockSeconds)), 0.7, 0.75, 0.82)
            GameTooltip:Show()
        end)
        bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bars[index] = bar
    end

    return function(session)
        local total = session and session.total or 0
        for index, row in ipairs(sourceRows) do
            local amount = session and session.sources[sources[index][1]] or 0
            local share = total > 0 and amount / total or 0
            local percent = suite.LocalizeDecimal(("%.1f"):format(100 * share))
            row.amount:SetText(suite.LF("%s EP · %s %%", numberText(amount), percent))
            row.bar:SetValue(share)
        end
        local block = session and trendBlock(session, GetTime()) or -1
        local peak = 0
        for index, bar in ipairs(bars) do
            bar.block = block - trendSize + index
            bar:SetShown(bar.block >= 0)
            bar.from = session and session.trendStarted - session.started + bar.block * blockSeconds or 0
            bar.amount = session and session.trend[bar.block] or 0
            peak = math.max(peak, bar.amount)
        end
        peakText:SetText((suite.L("Höchster Block: %s EP")):format(numberText(peak)))
        for _, bar in ipairs(bars) do
            bar:SetMinMaxValues(0, math.max(peak, 1))
            bar:SetValue(bar.amount)
        end
    end
end

function addon.CreateExperiencePanel(parent, label, barTexture)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    local analysis = CreateFrame("Frame", nil, parent)
    analysis:SetAllPoints()
    local renderAnalysis = createAnalysis(analysis, label, barTexture)
    local farmPanel = CreateFrame("Frame", nil, parent)
    farmPanel:SetAllPoints()
    local levelPanel = CreateFrame("Frame", nil, parent)
    levelPanel:SetAllPoints()
    local levelSummary = addon.CreateLevelPanel(levelPanel, label, sources, numberText, durationText)
    local questPanel = CreateFrame("Frame", nil, parent)
    questPanel:SetAllPoints()
    local renderQuests, invalidateQuests = addon.CreateQuestExperiencePanel(questPanel, label, numberText)
    local archivePanel = CreateFrame("Frame", nil, parent)
    archivePanel:SetAllPoints()
    local pages = { overview = panel, analysis = analysis, farm = farmPanel, archive = archivePanel, levels = levelPanel, quests = questPanel }
    local pageButtons = {}

    local levelText = label(panel, "GameFontNormalLarge", "TOPLEFT", "TOPLEFT", 12, -34)
    local bar = CreateFrame("StatusBar", nil, panel)
    bar:SetPoint("TOPLEFT", 11, -58)
    bar:SetPoint("TOPRIGHT", -11, -58)
    bar:SetHeight(15)
    style.Fill(bar, "BACKGROUND", unpack(style.track))
    bar:SetStatusBarTexture(barTexture)
    bar:SetStatusBarColor(0.28, 0.52, 0.72, 0.75)
    local xpBar = CreateFrame("StatusBar", nil, bar)
    xpBar:SetAllPoints()
    xpBar:SetStatusBarTexture(barTexture)
    xpBar:SetStatusBarColor(0.65, 0.43, 0.89, 1)
    local progressText = label(xpBar, "GameFontHighlightSmall", "CENTER", "CENTER", 0, 0)

    local remainingText = label(panel, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -80)
    local restedText = label(panel, "GameFontHighlightSmall", "TOPRIGHT", "TOPRIGHT", -12, -80)
    restedText:SetTextColor(0.50, 0.74, 1)
    local enemyText = label(panel, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -94)
    enemyText:SetPoint("RIGHT", panel, "RIGHT", -108, 0)
    enemyText:SetJustifyH("LEFT")
    enemyText:SetWordWrap(false)
    enemyText:SetText(suite.L("Letzter erfasster Gegner · –"))
    local mobsText = label(panel, "GameFontNormalSmall", "TOPRIGHT", "TOPRIGHT", -12, -94)
    mobsText:SetText(suite.L("Ø: Noch – Mobs"))
    local sessionText = label(panel, "GameFontNormalSmall", "TOPLEFT", "TOPLEFT", 12, -108)
    sessionText:SetText(suite.L("SITZUNG"))

    local labels = { suite.L("EP gesamt"), suite.L("EP pro Stunde"), suite.L("Letzte 15 Min."), suite.L("Aufstieg in"), suite.L("Größter Gewinn"), suite.L("Ø je Gewinn"), suite.L("EP-Gewinne"), suite.L("Stufenaufstiege") }
    local values = {}
    for index, name in ipairs(labels) do
        local column = (index - 1) % 2
        local y = -131 - math.floor((index - 1) / 2) * 18
        local key = label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12 + column * 170, y)
        key:SetText(name)
        values[index] = label(panel, "GameFontHighlightSmall", "TOPRIGHT", "TOPRIGHT", column == 0 and -182 or -12, y)
    end

    local history = label(panel, "GameFontNormalSmall", "TOPLEFT", "TOPLEFT", 12, -209)
    history:SetText(suite.L("LETZTE EP-GEWINNE"))
    local empty = label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12, -232)
    empty:SetText(suite.L("Warte auf den ersten EP-Gewinn dieser Sitzung …"))
    local rows = {}
    for index = 1, historySize do
        local row = CreateFrame("Frame", nil, panel)
        row:SetPoint("TOPLEFT", 6, -226 - (index - 1) * 18)
        row:SetPoint("TOPRIGHT", -6, -226 - (index - 1) * 18)
        row:SetHeight(16)
        style.Row(row, index)
        row.at = label(row, "GameFontDisableSmall", "LEFT", "LEFT", 6, 0)
        row.zone = label(row, "GameFontHighlightSmall", "LEFT", "LEFT", 63, 0)
        row.zone:SetPoint("RIGHT", row, "RIGHT", -86, 0)
        row.zone:SetJustifyH("LEFT")
        row.zone:SetWordWrap(false)
        row.gain = label(row, "GameFontNormalSmall", "RIGHT", "RIGHT", -6, 0)
        rows[index] = row
    end

    local session, sampleTimer, pendingLevel, farm, renderArchive
    addon.OverviewExperience = function()
        local current = session and session.last
        if not current then return end
        local elapsed = math.max(0, GetTime() - session.started)
        local rate = sessionRate(session, elapsed)
        local paused = xpIsPaused()
        local remaining = math.max(0, current.maximum - current.xp)
        local usable = current.maximum > 0 and not paused
        return {
            level = current.level, xp = current.xp, maximum = current.maximum,
            total = session.total, elapsed = elapsed, rate = rate, partial = session.partial, paused = paused,
            mobs = usable and enemyEstimate(session, remaining) or nil,
            eta = usable and not session.partial and rate and rate > 0 and 3600 * remaining / rate or nil,
        }
    end
    addon.GetMiniExperience = function()
        local current = session and session.last
        if not current then
            return
        end
        local rate = sessionRate(session, GetTime() - session.started)
        if current.maximum == 0 then
            return nil, rate
        end
        local mobs = not xpIsPaused() and enemyEstimate(session, current.maximum - current.xp) or nil
        return mobs, rate, current.xp / current.maximum * 100
    end
    local function render()
        local page = PaulchenQoLTimelineDB.xpPage
        if page == "analysis" then
            renderAnalysis(session)
            return
        elseif page == "farm" then
            farm.Render()
            return
        elseif page == "archive" then
            renderArchive()
            return
        elseif page == "levels" then
            levelSummary.Render()
            return
        elseif page == "quests" then
            renderQuests(session and session.last, xpIsPaused())
            return
        end
        local current = session and session.last
        if not current then
            levelText:SetText(suite.L("Erfahrung"))
            return
        end

        levelText:SetText((suite.L("Stufe %d")):format(current.level))
        local capped = current.maximum == 0
        local xpPaused = xpIsPaused()
        local remaining = math.max(0, current.maximum - current.xp)
        local rested = GetXPExhaustion()
        rested = readableNumber(rested) and rested or 0
        if capped then
            progressText:SetText(suite.L("Maximalstufe"))
            remainingText:SetText("")
            restedText:SetText("")
            bar:SetMinMaxValues(0, 1)
            xpBar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            xpBar:SetValue(0)
        else
            local percent = suite.LocalizeDecimal(("%.1f"):format(100 * current.xp / current.maximum))
            progressText:SetText((suite.L("%s / %s EP · %s %%")):format(numberText(current.xp), numberText(current.maximum), percent))
            remainingText:SetText(xpPaused and suite.L("EP-Stopp aktiv") or (suite.L("Noch %s EP")):format(numberText(remaining)))
            restedText:SetText((suite.L("Erholt: %s EP")):format(numberText(rested)))
            bar:SetMinMaxValues(0, current.maximum)
            xpBar:SetMinMaxValues(0, current.maximum)
            bar:SetValue(math.min(current.maximum, current.xp + rested))
            xpBar:SetValue(current.xp)
        end

        local enemy = session.lastEnemy
        local enemyValue = enemy and (numberText(enemy.xp) .. suite.L(" EP")) or "–"
        if enemy and enemy.maximum and enemy.maximum > 0 then
            local share = 100 * enemy.xp / enemy.maximum
            local percent = suite.LocalizeDecimal(share < 0.005 and "< 0.01" or ("%.2f"):format(share))
            enemyValue = enemyValue .. " · " .. percent .. " %"
        end
        enemyText:SetText(suite.L("Letzter erfasster Gegner · ") .. enemyValue)
        local mobs = not capped and not xpPaused and enemyEstimate(session, remaining)
        mobsText:SetText((suite.L("Ø: Noch %s Mobs")):format(mobs and numberText(mobs) or "–"))

        local now = GetTime()
        local elapsed = math.max(0, now - session.started)
        local rate = sessionRate(session, elapsed)
        local eta = rate and rate > 0 and not (session.partial or capped or xpPaused) and 3600 * remaining / rate or nil
        local prefix = session.partial and "≥ " or ""
        sessionText:SetText(suite.L("SITZUNG · ") .. durationText(elapsed))
        values[1]:SetText(prefix .. numberText(session.total))
        values[2]:SetText(rate and prefix .. numberText(rate) or "–")
        values[3]:SetText(numberText(recentExperience(session, now)) .. suite.L(" EP"))
        values[4]:SetText(eta and (suite.L("ca. ") .. durationText(eta)) or "–")
        values[5]:SetText(numberText(session.best) .. suite.L(" EP"))
        values[6]:SetText(session.count > 0 and numberText(session.total / session.count) .. suite.L(" EP") or "–")
        values[7]:SetText(tostring(session.count))
        values[8]:SetText(tostring(session.levels))
        empty:SetShown(#session.recent == 0)
        for index, row in ipairs(rows) do
            local event = session.recent[index]
            row:SetShown(event ~= nil)
            if event then
                row.at:SetText(date("%H:%M:%S", event.at))
                row.zone:SetText(event.level and (suite.L("Aufstieg auf Stufe %d")):format(event.level) or (event.zone:gsub("|", "||")))
                row.gain:SetText("+" .. numberText(event.gain) .. suite.L(" EP"))
            end
        end
    end

    local function setPage(page)
        page = pages[page] and page or "overview"
        PaulchenQoLTimelineDB.xpPage = page
        for name, frame in pairs(pages) do
            local selected = name == page
            frame:SetShown(selected)
            if pageButtons[name] then
                style.SetButtonState(pageButtons[name], selected or (name == "farm" and page == "archive"))
            end
        end
        render()
    end
    local questsButton = style.TextButton(panel)
    questsButton:SetPoint("TOPRIGHT", -94, -108)
    questsButton:SetSize(67, 20)
    questsButton:SetText(suite.L("Quests"))
    questsButton:SetScript("OnClick", function() setPage("quests") end)

    local x = -10
    for _, definition in ipairs({ { "levels", suite.L("Stufen"), 52 }, { "farm", suite.L("Farm"), 42 }, { "analysis", suite.L("Analyse"), 54 }, { "overview", suite.L("Übersicht"), 64 } }) do
        local name, text, width = unpack(definition)
        local button = style.TextButton(parent)
        button:SetPoint("TOPRIGHT", x, -31)
        button:SetSize(width, 20)
        button:SetText(text)
        button:SetScript("OnClick", function() setPage(name) end)
        pageButtons[name] = button
        x = x - width - 3
    end

    local claims, pendingGain, attributionTimer = {}, 0, nil
    local enemyAmounts, levelShares = {}, {}
    local pendingMaximum, crossedLevel
    local function clearAttribution()
        if attributionTimer then
            attributionTimer:Cancel()
        end
        claims, pendingGain, attributionTimer = {}, 0, nil
        enemyAmounts, levelShares = {}, {}
        pendingMaximum, crossedLevel = nil, nil
    end

    local function settleAttribution()
        local claimed = 0
        for _, amount in pairs(claims) do
            claimed = claimed + amount
        end
        if session and claimed > 0 and claimed <= pendingGain then
            for kind, amount in pairs(claims) do
                session.sources[kind] = session.sources[kind] + amount
            end
            session.sources.other = session.sources.other - claimed
            levelSummary.Attribute(levelShares, claims, claimed)
            local lastEnemyAmount = enemyAmounts[#enemyAmounts]
            if lastEnemyAmount then
                -- A single level-up gain uses the threshold of the level it completed.
                local maximum = (not crossedLevel or lastEnemyAmount == pendingGain) and pendingMaximum or nil
                session.lastEnemy = { xp = lastEnemyAmount, maximum = maximum }
                for _, amount in ipairs(enemyAmounts) do
                    table.insert(session.enemyGains, amount)
                    if #session.enemyGains > enemySampleSize then
                        table.remove(session.enemyGains, 1)
                    end
                end
            end
        end
        clearAttribution()
        if parent:IsVisible() then
            render()
        end
    end

    local function queueAttribution()
        if not attributionTimer then
            attributionTimer = C_Timer.NewTimer(0.55, function()
                attributionTimer = nil
                settleAttribution()
            end)
        end
    end

    local function claim(kind, amount)
        if session and readableNumber(amount) and amount > 0 then
            claims[kind] = (claims[kind] or 0) + amount
            if kind == "enemy" then
                table.insert(enemyAmounts, amount)
                if #enemyAmounts > enemySampleSize then
                    table.remove(enemyAmounts, 1)
                end
            end
            queueAttribution()
        end
    end

    local combatPatterns = enemyPatterns()
    local discoveryPattern = experiencePattern(ERR_ZONE_EXPLORED_XP)
    local lastDiscovery, lastDiscoveryEvent, lastDiscoveryAt
    local function claimMessage(event, message)
        if issecretvalue(message) or type(message) ~= "string" then
            return
        end
        local amount = discoveryPattern and tonumber(message:match(discoveryPattern))
        if amount then
            local now = GetTime()
            if lastDiscovery ~= message or lastDiscoveryEvent == event or now - lastDiscoveryAt > 0.5 then
                claim("explore", amount)
                lastDiscovery, lastDiscoveryEvent, lastDiscoveryAt = message, event, now
            end
        elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
            for _, pattern in ipairs(combatPatterns) do
                amount = tonumber(message:match(pattern))
                if amount then
                    claim("enemy", amount)
                    return
                end
            end
        end
    end

    local reset = style.TextButton(panel)
    reset:SetPoint("TOPRIGHT", -10, -108)
    reset:SetSize(78, 20)
    reset:SetText(suite.L("Neu starten"))
    local function sample(retries)
        local current = snapshot()
        local previous = session and session.last
        local gain, partial
        if session and current and (not pendingLevel or current.level >= pendingLevel) then
            gain, partial = recordProgress(session, current)
        end
        if gain ~= nil then
            pendingLevel = nil
            farm.Record(gain, partial)
            levelSummary.Progress(previous, current, gain, levelShares)
            if gain > 0 then
                if pendingGain == 0 then
                    pendingMaximum = previous.maximum
                end
                crossedLevel = crossedLevel or previous.level ~= current.level or current.maximum ~= pendingMaximum
                pendingGain = pendingGain + gain
                queueAttribution()
            end
            if parent:IsVisible() then
                render()
            end
            return true
        elseif session and retries > 0 then
            sampleTimer = C_Timer.NewTimer(0.2, function()
                sampleTimer = nil
                sample(retries - 1)
            end)
        end
        return false
    end

    farm = addon.CreateFarmPanel(farmPanel, label, function() return sample(0) end, function() setPage("archive") end)
    renderArchive = addon.CreateFarmArchivePanel(archivePanel, label, farm, function() setPage("farm") end)
    addon.FarmControls = farm
    reset:SetScript("OnClick", function()
        if sample(0) then
            settleAttribution()
            session = startSession()
            pendingLevel = nil
            render()
        end
    end)

    local events = CreateFrame("Frame", nil, panel)
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_XP_UPDATE")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("UPDATE_EXHAUSTION")
    events:RegisterEvent("QUEST_TURNED_IN")
    events:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
    events:RegisterEvent("CHAT_MSG_SYSTEM")
    events:RegisterEvent("UI_INFO_MESSAGE")
    events:RegisterEvent("PLAYER_LOGOUT")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("QUEST_LOG_UPDATE")
    events:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event, value, detail)
        if event == "QUEST_TURNED_IN" then
            invalidateQuests()
            claim("quest", detail)
            return
        elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_DATA_LOAD_RESULT" or event == "PLAYER_REGEN_ENABLED" then
            invalidateQuests()
            return
        elseif event == "UI_INFO_MESSAGE" then
            claimMessage(event, detail)
            return
        elseif event == "CHAT_MSG_COMBAT_XP_GAIN" or event == "CHAT_MSG_SYSTEM" then
            claimMessage(event, value)
            return
        elseif event == "PLAYER_LOGOUT" then
            if session then
                sample(0)
                settleAttribution()
            end
            farm.LeaveWorld()
            levelSummary.LeaveWorld()
            return
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            farm.UpdateArea()
            return
        elseif event == "PLAYER_ENTERING_WORLD" then
            invalidateQuests()
            if value or not session then
                clearAttribution()
                local saved = detail and PaulchenQoLTimelineDB.xpSession
                session = saved and saved.started <= GetTime() and saved or startSession()
                initAnalysis(session)
            end
            farm.EnterWorld()
            levelSummary.EnterWorld()
        elseif event == "PLAYER_XP_UPDATE" and value ~= "player" then
            return
        elseif event == "PLAYER_LEVEL_UP" and readableNumber(value) then
            invalidateQuests()
            pendingLevel = value
        end
        if session and not sampleTimer then
            sampleTimer = C_Timer.NewTimer(0.1, function()
                sampleTimer = nil
                sample(4)
            end)
        end
    end)

    setPage(PaulchenQoLTimelineDB.xpPage or (PaulchenQoLTimelineDB.xpAnalysis and "analysis" or "overview"))
    parent:SetScript("OnShow", render)
    C_Timer.NewTicker(1, function()
        if parent:IsVisible() then
            render()
        end
        addon.RefreshMini()
    end)
    return setPage
end
