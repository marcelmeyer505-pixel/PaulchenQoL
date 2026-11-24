local _, app = ...
local loot = app.upgrades and app.upgrades.loot
if not loot then return end
local style, L, read = app.style, app.L, app.ReadGameValue
local window, selected
local itemOffset, playerOffset = 0, 0
local itemRows, playerRows = 7, 6
local openRolls = {}
local resultDisplayTime = 10
local closeAt, finalResultShown
local choices = { need = "Bedarf", greed = "Gier", pass = "Passen", disenchant = "Entzaubern", transmog = "Transmog" }
local nativeRolls = {}

local function captureMouse(frame, mouse)
    if frame:IsForbidden() or frame:IsProtected() then return false end
    local click = read(frame.IsMouseClickEnabled, frame)
    local motion = read(frame.IsMouseMotionEnabled, frame)
    if type(click) ~= "boolean" or type(motion) ~= "boolean" then return false end
    mouse[frame] = { click, motion }
    for _, child in ipairs({ frame:GetChildren() }) do
        if not captureMouse(child, mouse) then return false end
    end
    return true
end

local function syncNativeRoll(frame)
    local state = nativeRolls[frame]
    local id = app.Readable(frame.rollID)
    local visible = window and window:IsVisible() and frame:IsShown()

    if state.mouse and (not visible or state.id ~= id) then
        frame:SetAlpha(state.alpha)
        for widget, flags in pairs(state.mouse) do
            widget:SetMouseClickEnabled(flags[1])
            widget:SetMouseMotionEnabled(flags[2])
        end
        state.mouse = nil
    end

    -- Native OnHide unregisters cancellation events and clears roll state.
    if visible and not state.mouse and loot.CanReplaceRoll(id) then
        local mouse = {}
        local alpha = read(frame.GetAlpha, frame)
        if type(alpha) ~= "number" or not captureMouse(frame, mouse) then return end
        state.id, state.alpha, state.mouse = id, alpha, mouse
        frame:SetAlpha(0)
        for widget in pairs(mouse) do
            widget:SetMouseClickEnabled(false)
            widget:SetMouseMotionEnabled(false)
        end
    end
end

local function syncNativeRolls()
    for index = 1, 4 do
        local frame = _G["GroupLootFrame" .. index]
        if frame and not frame:IsForbidden() then
            if not nativeRolls[frame] then
                nativeRolls[frame] = {}
                frame:HookScript("OnShow", syncNativeRoll)
                frame:HookScript("OnHide", syncNativeRoll)
            end
            syncNativeRoll(frame)
        end
    end
end

local function button(parent, name, x, y, w, h, action)
    local control = style.TextButton(parent)
    control:SetPoint("TOPLEFT", x, y)
    control:SetSize(w, h)
    control:SetText(L(name))
    control:SetScript("OnClick", action)
    return control
end

local function tooltip(item)
    item:SetScript("OnEnter", function(self)
        if self.drop and GameTooltip and (not GameTooltip.IsForbidden or not GameTooltip:IsForbidden()) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.drop.link)
            GameTooltip:Show()
        end
    end)
    item:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end

local function itemColor(label, drop)
    local r, g, b = drop.link:match("|c%x%x(%x%x)(%x%x)(%x%x)")
    if r then
        label:SetTextColor(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255)
    else
        label:SetTextColor(unpack(style.cream))
    end
end

local function icon(drop)
    return drop.icon or read(C_Item and C_Item.GetItemIconByID, drop.id) or 134400
end

local function updateOpenRolls()
    local previousCount = #openRolls
    local count, changed = 0, false
    for _, drop in ipairs(loot.drops) do
        if loot.TimeLeft(drop) > 0 then
            count = count + 1
            if openRolls[count] ~= drop then
                openRolls[count], changed = drop, true
            end
        end
    end
    if count > 0 then
        closeAt = nil
    elseif previousCount > 0 then
        local last = openRolls[1]
        local now = GetTime()
        for index = 2, previousCount do
            local drop = openRolls[index]
            if (drop.finishedAt or now) > (last.finishedAt or now) then last = drop end
        end
        selected, playerOffset = last, 0
        closeAt, finalResultShown = now + resultDisplayTime, false
    end
    for index = previousCount, count + 1, -1 do
        openRolls[index], changed = nil, true
    end
    return changed
end

local function updateTimer()
    if not selected then return end
    local remaining = loot.TimeLeft(selected)
    local active = remaining > 0
    local ready = loot.CanChoose(selected) == true
    local status
    if selected.winner then
        status = app.LF("Gewonnen von %s", selected.winner)
    elseif selected.allPassed then
        status = L("Alle haben gepasst")
    elseif active then
        status = app.LF("Noch %d Sek.", math.ceil(remaining))
        if selected.voted then status = status .. " · " .. L(choices[selected.voted]) end
    else
        status = L("Würfeln beendet")
    end
    if closeAt and not finalResultShown and (selected.winner or selected.allPassed) then
        closeAt, finalResultShown = GetTime() + resultDisplayTime, true
    end
    window.status:SetText(status)
    window.need:SetEnabled(ready and selected.need == true and RollOnLoot ~= nil)
    local greedLabel = selected.transmog and "Transmog" or "Gier"
    window.greed:SetText(L(greedLabel))
    window.greed:SetEnabled(ready and (selected.transmog == true or selected.greed == true) and RollOnLoot ~= nil)
    window.pass:SetEnabled(ready and RollOnLoot ~= nil)
    for _, control in ipairs(window.rollButtons) do control:SetShown(active) end
end

local function chooseRoll(choice)
    local current, position = selected, 0
    for index, drop in ipairs(openRolls) do
        if drop == current then position = index; break end
    end
    if not loot.Roll(current, choice) or #openRolls == 0 then return end
    if openRolls[position] ~= current then position = position - 1 end
    for offset = 1, #openRolls do
        local index = (position + offset - 1) % #openRolls + 1
        local nextRoll = openRolls[index]
        if nextRoll ~= current and not nextRoll.requestUntil and loot.CanChoose(nextRoll) then
            selected, playerOffset = nextRoll, 0
            itemOffset = math.max(index - itemRows, math.min(itemOffset, index - 1))
            loot.Refresh()
            return
        end
    end
end

local function createWindow()
    local f = CreateFrame("Frame", "PaulchenQoLLootWindow", UIParent, "BackdropTemplate")
    f:Hide()
    f:SetSize(614, 331)
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -244, -168)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    style.Panel(f, style.background)
    table.insert(UISpecialFrames, f:GetName())
    f:SetScript("OnHide", function()
        closeAt = nil
        openRolls = {}
        syncNativeRolls()
    end)

    local bar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(34)
    style.Panel(bar, style.header)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    style.Portrait(bar, 25, 7, -4)
    style.Label(bar, "Paulchens Beute", 39, 0, 410, 33, "GameFontNormalLarge", style.gold)
    local close = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -1, -1)
    close:SetScript("OnClick", function() f:Hide() end)

    local list = CreateFrame("Frame", nil, f, "BackdropTemplate")
    list:SetSize(225, 269)
    list:SetPoint("TOPLEFT", 11, -51)
    style.Panel(list, style.header)
    style.Label(list, "Zum Würfeln", 10, 0, 205, 24, "GameFontNormal")
    f.noOpenRolls = style.Label(list, "Keine offenen Würfe.", 10, -26, 205, 25, "GameFontHighlightSmall", style.muted)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        itemOffset = math.max(0, math.min(#openRolls - itemRows, itemOffset - delta))
        loot.Refresh()
    end)
    f.items = {}
    for index = 1, itemRows do
        local item = button(list, "", 5, -25 - (index - 1) * 34, 215, 32, function(self)
            if not self.drop then return end
            if read(IsShiftKeyDown) and ChatEdit_InsertLink then
                ChatEdit_InsertLink(self.drop.link)
                return
            end
            selected, playerOffset = self.drop, 0
            loot.Refresh()
        end)
        item:EnableMouseWheel(true)
        item:SetScript("OnMouseWheel", list:GetScript("OnMouseWheel"))
        item.icon = item:CreateTexture(nil, "ARTWORK")
        item.icon:SetPoint("LEFT", 3, 0)
        item.icon:SetSize(23, 23)
        item.caption = style.Label(item, "", 33, 0, 128, 32, "GameFontHighlightSmall")
        item.mark = style.Label(item, "", 165, 0, 44, 32, "GameFontNormalSmall", style.green, "RIGHT")
        tooltip(item)
        f.items[index] = item
    end

    local detail = CreateFrame("Frame", nil, f, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", 245, -51)
    detail:SetPoint("BOTTOMRIGHT", -11, 11)
    style.Panel(detail, style.header)
    f.detail = detail
    f.preview = button(detail, "", 10, -9, 40, 40)
    f.preview.icon = f.preview:CreateTexture(nil, "ARTWORK")
    f.preview.icon:SetAllPoints()
    tooltip(f.preview)
    f.name = style.Label(detail, "", 60, -7, 282, 22, "GameFontNormal", style.gold)
    f.gain = style.Label(detail, "", 60, -30, 282, 20, "GameFontHighlightSmall", style.green)
    f.status = style.Label(detail, "", 11, -82, 338, 21, "GameFontNormalSmall", style.gold)
    f.need = button(detail, "Bedarf", 10, -54, 103, 24, function() chooseRoll(1) end)
    f.greed = button(detail, "Gier", 125, -54, 103, 24, function() chooseRoll(selected.transmog and 4 or 2) end)
    f.pass = button(detail, "Passen", 240, -54, 103, 24, function() chooseRoll(0) end)
    f.rollButtons = { f.need, f.greed, f.pass }

    local results = CreateFrame("Frame", nil, detail, "BackdropTemplate")
    results:SetPoint("TOPLEFT", 9, -107)
    results:SetSize(340, 153)
    style.Panel(results, style.background)
    style.Label(results, "Spieler", 7, 0, 170, 22, "GameFontNormalSmall", style.gold)
    style.Label(results, "Wahl", 176, 0, 98, 22, "GameFontNormalSmall", style.gold)
    style.Label(results, "Wurf", 275, 0, 56, 22, "GameFontNormalSmall", style.gold, "RIGHT")
    f.players = {}
    for index = 1, playerRows do
        local row = CreateFrame("Frame", nil, results)
        row:SetPoint("TOPLEFT", 2, -23 - (index - 1) * 21)
        row:SetSize(335, 21)
        style.Row(row, index)
        row.name = style.Label(row, "", 5, 0, 165, 21, "GameFontHighlightSmall")
        row.choice = style.Label(row, "", 174, 0, 97, 21, "GameFontHighlightSmall", style.muted)
        row.number = style.Label(row, "", 273, 0, 56, 21, "GameFontHighlightSmall", style.cream, "RIGHT")
        f.players[index] = row
    end
    f.noResults = style.Label(results, "Noch keine Würfe gemeldet.", 7, -26, 326, 23, "GameFontHighlightSmall", style.muted)
    results:EnableMouseWheel(true)
    results:SetScript("OnMouseWheel", function(_, delta)
        playerOffset = math.max(0, playerOffset - delta)
        loot.Refresh()
    end)
    f.empty = style.Label(f, "In dieser Sitzung gab es noch keine Gruppenwürfe.", 249, -117, 351, 32, "GameFontHighlightSmall")
    local elapsed = 0
    f:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.25 then
            elapsed = 0
            if updateOpenRolls() then
                loot.Refresh()
            else
                updateTimer()
                if selected then syncNativeRolls() end
            end
            if closeAt and GetTime() >= closeAt then f:Hide() end
        end
    end)
    return f
end

function loot.Refresh()
    if not window or not window:IsShown() then return end
    updateOpenRolls()
    itemOffset = math.max(0, math.min(itemOffset, #openRolls - itemRows))
    local found
    for _, drop in ipairs(loot.drops) do if drop == selected then found = true; break end end
    if not found then selected, playerOffset = openRolls[1] or loot.drops[1], 0 end
    window.noOpenRolls:SetShown(#openRolls == 0)
    for index, item in ipairs(window.items) do
        local drop = openRolls[itemOffset + index]
        item.drop = drop
        item:SetShown(drop ~= nil)
        if drop then
            item.icon:SetTexture(icon(drop))
            item.caption:SetText((drop.count and drop.count > 1 and ("%d× "):format(drop.count) or "") .. drop.name)
            itemColor(item.caption, drop)
            item.mark:SetText(drop.gain and L("Upgrade") or "")
            style.SetButtonState(item, drop == selected)
        end
    end
    window.detail:SetShown(selected ~= nil)
    window.empty:SetShown(selected == nil)
    syncNativeRolls()
    if not selected then return end
    window.preview.drop = selected
    window.preview.icon:SetTexture(icon(selected))
    window.name:SetText(selected.name)
    itemColor(window.name, selected)
    local profile = app.upgrades.ProfileName and app.upgrades.ProfileName()
    window.gain:SetText(selected.gain and L("Upgrade") .. " " .. selected.gain .. (profile and " · " .. profile or "") or "")

    local names = {}
    for name in pairs(selected.players) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        if (a == selected.winner) ~= (b == selected.winner) then return a == selected.winner end
        return a < b
    end)
    playerOffset = math.max(0, math.min(playerOffset, #names - playerRows))
    window.noResults:SetShown(#names == 0)
    for index, row in ipairs(window.players) do
        local name = names[playerOffset + index]
        row:SetShown(name ~= nil)
        if name then
            local vote = selected.players[name]
            row.name:SetText(name)
            row.name:SetTextColor(unpack(name == selected.winner and style.green or style.cream))
            row.choice:SetText(L(choices[vote.choice]))
            row.number:SetText(vote.number or "–")
        end
    end
    updateTimer()
end

function loot.Open()
    window = window or createWindow()
    window:Show()
    loot.Refresh()
end

function loot.ShowNew(drop)
    if not window or not window:IsShown() or not selected or loot.TimeLeft(selected) == 0 then
        selected, itemOffset, playerOffset = drop, 0, 0
    end
    loot.Open()
end
