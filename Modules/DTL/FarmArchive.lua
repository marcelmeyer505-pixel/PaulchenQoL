local _, suite = ...
local addon = suite.timeline
if not addon then return end
local style = suite.style

function addon.CreateFarmArchivePanel(panel, label, farm, back)
    label(panel, "GameFontNormal", "TOPLEFT", "TOPLEFT", 12, -35):SetText(suite.L("Farmarchiv"))
    local function button(text, x, y, width)
        local control = style.TextButton(panel)
        control:SetPoint("TOPRIGHT", x, y)
        control:SetSize(width, 20)
        control:SetText(text)
        return control
    end
    button(suite.L("Zur Farm"), -12, -32, 67):SetScript("OnClick", back)
    local favorites = button(suite.L("Alle Runden"), -12, -56, 90)
    label(panel, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -60):SetText(suite.L("Suche"))
    local search = style.EditBox(panel)
    search:SetPoint("TOPLEFT", 59, -56)
    search:SetSize(185, 20)
    search:SetMaxLetters(80)
    search:SetText("")
    search:SetScript("OnEnterPressed", search.ClearFocus)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnHide", search.ClearFocus)
    local summary = label(panel, "GameFontNormalSmall", "TOPLEFT", "TOPLEFT", 12, -82)
    local difference = label(panel, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -98)
    local pageText = label(panel, "GameFontHighlightSmall", "BOTTOMLEFT", "BOTTOMLEFT", 12, 8)
    local previous, nextPage = button("<", -41, -283, 26), button(">", -12, -283, 26)
    label(panel, "GameFontNormalSmall", "TOPLEFT", "TOPLEFT", 33, -117):SetText(suite.L("Runde · Gebiet"))
    label(panel, "GameFontNormalSmall", "TOPRIGHT", "TOPRIGHT", -126, -117):SetText(suite.L("Dauer"))
    label(panel, "GameFontNormalSmall", "TOPRIGHT", "TOPRIGHT", -68, -117):SetText(suite.L("EP"))
    label(panel, "GameFontNormalSmall", "TOPRIGHT", "TOPRIGHT", -12, -117):SetText(suite.L("EP/h"))
    local rows, page, onlyFavorites, render = {}, 1, false
    for index = 1, 8 do
        local row = CreateFrame("Button", nil, panel)
        local y = -132 - (index - 1) * 18
        row:SetPoint("TOPLEFT", 8, y)
        row:SetPoint("TOPRIGHT", -8, y)
        row:SetHeight(17)
        style.Row(row, index)
        row.star = CreateFrame("Button", nil, row)
        row.star:SetPoint("LEFT")
        row.star:SetSize(22, 17)
        row.star:SetNormalFontObject("GameFontNormalSmall")
        row.star:SetHighlightFontObject("GameFontHighlightSmall")
        row.name = label(row, "GameFontHighlightSmall", "LEFT", "LEFT", 25, 0)
        row.name:SetWidth(140)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.duration = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -118, 0)
        row.xp = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -60, 0)
        row.rate = label(row, "GameFontHighlightSmall", "RIGHT", "RIGHT", -4, 0)
        row:SetScript("OnClick", function()
            if row.run and farm.State() == "idle" then
                farm.Select(row.run)
                render()
            end
        end)
        row.star:SetScript("OnClick", function()
            if row.run then
                row.run.favorite = not row.run.favorite or nil
                farm.Prune()
                render()
            end
        end)
        row:SetScript("OnEnter", function(self)
            local run = self.run
            if not run then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(farm.AreaText(run), 1, 1, 1)
            if run.name then GameTooltip:AddLine(run.name:gsub("|", "||"), 1, 0.82, 0.38) end
            GameTooltip:AddLine((run.partial and "≥ " or "") .. BreakUpLargeNumbers(run.xp) .. suite.L(" EP"), 0.8, 0.85, 0.9)
            if run.item then
                GameTooltip:AddLine(("%d × %s"):format(run.itemCount or 0, ((run.itemLabel or run.item):gsub("|", "||"))), 0.8, 0.85, 0.9)
                if run.goal then
                    GameTooltip:AddLine((suite.L("Farmziel · %d/%d")):format(run.itemCount or 0, run.goal), 0.8, 0.85, 0.9)
                end
            end
            if farm.State() == "idle" then GameTooltip:AddLine(suite.L("Klick wählt die Runde für A/B."), 0.7, 0.75, 0.82) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[index] = row
    end

    render = function()
        local query = search:GetText():lower():match("^%s*(.-)%s*$")
        local matches = {}
        for _, run in ipairs(farm.History) do
            if (not onlyFavorites or run.favorite) and
                ((run.area or ""):lower():find(query, 1, true) or (run.name or ""):lower():find(query, 1, true)
                    or (run.item or ""):lower():find(query, 1, true) or (run.itemLabel or ""):lower():find(query, 1, true)) then
                matches[#matches + 1] = run
            end
        end
        local pages = math.max(1, math.ceil(#matches / #rows))
        page = math.min(page, pages)
        for index, row in ipairs(rows) do
            local run = matches[(page - 1) * #rows + index]
            row.run = run
            row:SetShown(run ~= nil)
            if run then
                local choice = farm.Mark(run)
                local name = run.name and (run.name:gsub("|", "||") .. " · ") or ""
                row.star:SetText(run.favorite and "★" or "☆")
                row.name:SetText((choice and choice .. " · " or "") .. name .. farm.AreaText(run))
                row.duration:SetText(farm.DurationText(run.elapsed))
                row.xp:SetText((run.partial and "≥ " or "") .. BreakUpLargeNumbers(run.xp))
                row.rate:SetText(farm.RateText(run, run.elapsed))
            end
        end
        local result, delta = farm.Compare()
        summary:SetText(result)
        difference:SetText(delta)
        pageText:SetText(suite.LF("%d Runden  ·  Seite %d/%d", #matches, page, pages))
        previous:SetEnabled(page > 1)
        nextPage:SetEnabled(page < pages)
    end
    search:SetScript("OnTextChanged", function()
        page = 1
        render()
    end)
    favorites:SetScript("OnClick", function()
        onlyFavorites = not onlyFavorites
        favorites:SetText(onlyFavorites and "Nur Favoriten" or suite.L("Alle Runden"))
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
