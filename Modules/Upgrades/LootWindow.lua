local _, app = ...
local loot = app.upgrades and app.upgrades.loot
if not loot then return end
local style, L, read = app.style, app.L, app.ReadGameValue
local window, selected
local itemOffset, playerOffset = 0, 0
local itemRows, playerRows = 7, 6
local choices = { need = "Bedarf", greed = "Gier", pass = "Passen", disenchant = "Entzaubern", transmog = "Transmogrifikation" }

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

local function updateTimer()
    if not selected then return end
    local remaining = loot.TimeLeft(selected)
    local active = remaining > 0
    local ready = active and not selected.voted and (selected.requestUntil or 0) <= GetTime()
    local status
    if selected.winner then
        status = app.LF("Gewonnen von %s", selected.winner)
    elseif selected.allPassed then
        status = L("Alle haben gepasst")
    elseif active then
        status = app.LF("Noch %d Sek.", math.ceil(remaining))
        if selected.voted then status = status .. " · " .. L(choices[selected.voted]) end
    elseif selected.rollID then
        status = L("Würfeln beendet")
    else
        status = selected.received and L("Erhalten") or L("Gefunden")
    end
    window.status:SetText(status)
    window.need:SetEnabled(ready and selected.need == true and RollOnLoot ~= nil)
    window.greed:SetEnabled(ready and selected.greed == true and RollOnLoot ~= nil)
    window.pass:SetEnabled(ready and RollOnLoot ~= nil)
    for _, control in ipairs(window.rollButtons) do control:SetShown(selected.rollID ~= nil) end
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
    style.Label(list, "Letzte Beute", 10, 0, 205, 24, "GameFontNormal")
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        itemOffset = math.max(0, math.min(#loot.drops - itemRows, itemOffset - delta))
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
    f.need = button(detail, "Bedarf", 10, -54, 103, 24, function() loot.Roll(selected, 1) end)
    f.greed = button(detail, "Gier", 125, -54, 103, 24, function() loot.Roll(selected, 2) end)
    f.pass = button(detail, "Passen", 240, -54, 103, 24, function() loot.Roll(selected, 0) end)
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
    f.empty = style.Label(f, "In dieser Sitzung ist noch keine Beute erfasst.", 249, -117, 351, 32, "GameFontHighlightSmall")
    local elapsed = 0
    f:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.25 then elapsed = 0; updateTimer() end
    end)
    return f
end

function loot.Refresh()
    if not window or not window:IsShown() then return end
    itemOffset = math.max(0, math.min(itemOffset, #loot.drops - itemRows))
    local found
    for _, drop in ipairs(loot.drops) do if drop == selected then found = true; break end end
    if not found then selected, playerOffset = loot.drops[1], 0 end
    for index, item in ipairs(window.items) do
        local drop = loot.drops[itemOffset + index]
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
