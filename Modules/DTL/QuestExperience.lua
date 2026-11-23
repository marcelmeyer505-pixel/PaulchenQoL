local _, suite = ...
local addon = suite.timeline
if not addon then return end
local style = suite.style

local function safe(value)
    if not issecretvalue(value) then
        return value
    end
end

function addon.CreateQuestExperiencePanel(panel, label, numberText)
    label(panel, "GameFontNormalLarge", "TOPLEFT", "TOPLEFT", 12, -34):SetText(suite.L("Quest-EP"))
    local totalText = label(panel, "GameFontNormal", "TOPLEFT", "TOPLEFT", 12, -61)
    local remainingText = label(panel, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -81)
    label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12, -106):SetText(suite.L("ABGABEBEREITE QUESTS"))
    local rows = {}
    for index = 1, 10 do
        local row = CreateFrame("Frame", nil, panel)
        row:SetPoint("TOPLEFT", 6, -121 - (index - 1) * 17)
        row:SetPoint("TOPRIGHT", -6, -121 - (index - 1) * 17)
        row:SetHeight(16)
        style.Row(row, index)
        row.title = label(row, "GameFontHighlightSmall", "LEFT", "LEFT", 6, 0)
        row.title:SetPoint("RIGHT", row, "RIGHT", -87, 0)
        row.title:SetJustifyH("LEFT")
        row.title:SetWordWrap(false)
        row.xp = label(row, "GameFontNormalSmall", "RIGHT", "RIGHT", -6, 0)
        rows[index] = row
    end
    local footer = label(panel, "GameFontDisableSmall", "TOPLEFT", "TOPLEFT", 12, -294)
    local quests, total, unknown, dirty = {}, 0, 0, true
    local function scan()
        quests, total, unknown, dirty = {}, 0, 0, false
        for index = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = safe(C_QuestLog.GetInfo(index))
            local id = info and safe(info.questID)
            if id and id > 0 and safe(C_QuestLog.ReadyForTurnIn(id)) then
                local xp = GetQuestLogRewardXP and safe(GetQuestLogRewardXP(id))
                if type(xp) == "number" and xp >= 0 then
                    total = total + xp
                else
                    xp = nil
                    unknown = unknown + 1
                end
                local title = safe(info.title) or (suite.L("Quest #%d")):format(id)
                quests[#quests + 1] = { title = title, xp = xp }
            end
        end
        table.sort(quests, function(a, b)
            local left, right = a.xp or -1, b.xp or -1
            return left == right and a.title < b.title or left > right
        end)
    end
    return function(progress, paused)
        if dirty then scan() end
        totalText:SetText((suite.L("%d bereit · %s%s EP")):format(#quests, unknown > 0 and "≥ " or "", numberText(total)))
        if not progress or progress.maximum == 0 then
            remainingText:SetText(progress and suite.L("Maximalstufe") or suite.L("Lade Stufenfortschritt …"))
        elseif paused then
            remainingText:SetText(suite.L("EP-Stopp aktiv"))
        elseif total >= progress.maximum - progress.xp then
            remainingText:SetText((suite.L("Genug für Stufe %d")):format(progress.level + 1))
        else
            remainingText:SetText((suite.L("Nach Abgabe %snoch %s EP")):format(unknown > 0 and suite.L("höchstens ") or "", numberText(progress.maximum - progress.xp - total)))
        end
        for index, row in ipairs(rows) do
            local quest = quests[index]
            row:SetShown(quest ~= nil)
            if quest then
                row.title:SetText((quest.title:gsub("|", "||")))
                row.xp:SetText(quest.xp and numberText(quest.xp) .. suite.L(" EP") or "–")
            end
        end
        local extra = #quests - #rows
        footer:SetText((extra > 0 and (suite.L("+ %d weitere · ")):format(extra) or "") .. suite.L("EP laut Questlog"))
    end, function() dirty = true end
end
