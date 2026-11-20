local _, app = ...
local C, style, readable = C_Container, app.style, app.Readable
local inventory = { slots = {}, offset = 0, query = "", searchCollapsed = {} }
app.inventory = inventory
local window, settings, refreshQueued, suppress, pendingAction
local layout
local rowHeight, rowCount = 32, 14
local categories = {
    { "equipment", "Ausrüstung" }, { "consumables", "Verbrauchbares" },
    { "materials", "Handwerksmaterial" }, { "recipes", "Rezepte" },
    { "bags", "Taschen" }, { "keys", "Schlüssel" },
    { "quests", "Questgegenstände" }, { "junk", "Plunder" }, { "other", "Sonstiges" },
}
-- Explicit player marks take precedence over the normal item-class buckets.
for index, key in ipairs(app.markOrder) do
    local mark = app.marks[key]
    table.insert(categories, index, { "mark_" .. key, mark[1], mark[2] })
end
local categoryHeaders = {}
local columns = {
    { "name", "Gegenstand", 52, 268 }, { "count", "Anzahl", 324, 54 },
    { "quality", "Qualität", 382, 92 }, { "value", "Händler / Gesamt", 478, 128 },
    { "bag", "Tasche", 610, 76 },
}
local function lastBag() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function lower(text)
    return text:gsub("Ä", "ä"):gsub("Ö", "ö"):gsub("Ü", "ü"):lower()
end
local function money(value)
    if value == nil then return "…" end
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(value, 12)
    end
    return ("%d|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t %d|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t %d|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t")
        :format(math.floor(value / 10000), math.floor(value / 100) % 100, value % 100)
end
inventory.MoneyText = money
local function groupKey(id, link)
    local payload = link and (link:match("|Hitem:([^|]+)|h") or link:match("^item:(.*)$"))
    if not payload then return tostring(id) end
    local fields = {}
    for field in (payload .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = field end
    -- Per-instance identity and viewer level do not affect the item variant.
    -- Keep enchants, gems, suffixes and bonus fields distinct.
    if #fields >= 9 then fields[8], fields[9] = "0", "0" end
    return table.concat(fields, ":")
end
local function groupTooltip(row)
    local mark = row.item and app.marks[row.item.mark]
    if mark then GameTooltip:AddLine("Vormerkung: " .. mark[1], unpack(mark[2])) end
    local group = row.group
    if not group or #group.members < 2 then return end
    GameTooltip:AddLine(("Gesamt: %d · %d Stapel"):format(row.item.count, #group.members), 1, 0.82, 0.45)
    GameTooltip:AddLine(("Aktionen betreffen diesen Stapel: %d Stück (%s:%d)")
        :format(group.stackCount, row.bag == 0 and "Rucksack" or row.bag, row.slot), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end
function inventory.Mark(item, mark)
    if not item or not item.markKey or mark and not app.marks[mark] then return end
    app.Settings().marks[item.markKey] = mark
    if mark and settings then
        settings.collapsed["mark_" .. mark] = nil
        inventory.searchCollapsed["mark_" .. mark] = nil
    end
    inventory.Refresh()
    -- Keep the moved item visible after its category changes. Slot identities
    -- remain fixed; only the row's visual position and viewport move.
    for index, row in ipairs(inventory.displayRows or {}) do
        if row.categoryHeader ~= true and row.item.markKey == item.markKey then
            inventory.offset = math.max(0, index - 2)
            layout()
            break
        end
    end
    if app.RefreshOverview then app.RefreshOverview() end
end
local function updateMoney()
    if window and window.money then
        window.money:SetText(money(GetMoney and readable(GetMoney())))
    end
end
local function hideOtherBags()
    suppress = true
    if CloseAllBags then CloseAllBags() end
    local frames = Bagnon and Bagnon.Frames
    local bag = frames and frames.Get and frames:Get("inventory")
    if bag and bag.Hide then bag:Hide() end
    suppress = false
end
local function makeButton(parent, bag, slot)
    -- Each button keeps the same physical slot for its entire lifetime. Sorting
    -- only moves rows; a delayed click or split can never act on a recycled slot.
    local button = CreateFrame("ItemButton", nil, parent, "ContainerFrameItemButtonTemplate")
    button:SetID(slot)
    button:SetBagID(bag)
    -- The template anchors BOTTOMRIGHT to its parent. Keep only our icon
    -- anchor, otherwise LEFT + BOTTOMRIGHT stretch it across the entire row.
    button:ClearAllPoints()
    button:SetSize(27, 27)
    button:SetPoint("LEFT", 6, 0)
    -- Blizzard's quest overlay has its own fixed 37x38 size. Bind it to our
    -- smaller icon so the gold border cannot extend into the next list row.
    button.IconQuestTexture:ClearAllPoints()
    button.IconQuestTexture:SetAllPoints(button)
    button:Show()
    return button
end
local function createSlot(bag, slot)
    local row = CreateFrame("Frame", nil, window)
    row:SetSize(672, rowHeight - 1)
    row:EnableMouse(true)
    row.button = makeButton(row, bag, slot)
    row.bag, row.slot = bag, slot
    row.group = false
    row.fill = style.Fill(row, "BACKGROUND", unpack(style.rowColors[1]))
    row.markAccent = row:CreateTexture(nil, "ARTWORK")
    row.markAccent:SetWidth(3)
    row.markAccent:SetPoint("TOPLEFT", 0, -2)
    row.markAccent:SetPoint("BOTTOMLEFT", 0, 2)
    row.markAccent:Hide()
    row.labels = {}
    for _, col in ipairs(columns) do
        row.labels[col[1]] = style.Label(row, "", col[3] - 14, 0, col[4] - 6, rowHeight - 1,
            "GameFontHighlightSmall", style.cream, col[1] == "count" and "RIGHT" or "LEFT")
    end
    row.button:HookScript("OnEnter", function() groupTooltip(row) end)
    row.button.UpdateTooltip = function(self) self:OnUpdate(); groupTooltip(row) end
    row:SetScript("OnEnter", function() row.button:OnEnter(); groupTooltip(row) end)
    row:SetScript("OnLeave", function() row.button:OnLeave() end)
    row:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton ~= "RightButton" or not self.item or not self.item.id
            or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        local item = self.item
        GameTooltip:Hide()
        MenuUtil.CreateContextMenu(self, function(_, menu)
            menu:CreateTitle(item.name)
            for _, key in ipairs(app.markOrder) do
                menu:CreateRadio(app.marks[key][1], function() return app.Settings().marks[item.markKey] == key end,
                    function() inventory.Mark(item, key) end)
            end
            menu:CreateRadio("Ohne Markierung", function() return not app.Settings().marks[item.markKey] end,
                function() inventory.Mark(item, nil) end)
        end)
    end)
    row:Hide()
    inventory.slots[bag .. ":" .. slot] = row
    return row
end
local function readSlot(row, marks)
    row.group = false
    local info = readable(C.GetContainerItemInfo(row.bag, row.slot))
    local id = info and readable(info.itemID)
    local link = info and readable(info.hyperlink)
    local name, quality, category, subcategory, price, classID
    if id then
        local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
        local n, _, q, _, _, c, s, _, _, _, p, itemClass = getInfo(link or id)
        name, quality, category, subcategory, price = readable(n), readable(q), readable(c), readable(s), readable(p)
        classID = readable(itemClass)
    end
    local quest = C.GetContainerItemQuestInfo and readable(C.GetContainerItemQuestInfo(row.bag, row.slot))
    local questID = quest and readable(quest.questID)
    local isQuestItem = quest and readable(quest.isQuestItem)
    if info and readable(info.hasNoValue) then price = 0 end
    local count = id and (readable(info.stackCount) or 1) or 0
    local markKey = app.BagItemKey(id, link)
    row.item = {
        id = id, name = name or (id and "Gegenstand " .. id or "Freier Platz"), count = count,
        quality = quality or (info and readable(info.quality)) or 0,
        value = price and price * count, category = category or "", subcategory = subcategory or "", classID = classID,
        bag = row.bag, slot = row.slot, link = link,
        key = groupKey(id, link), locked = info and readable(info.isLocked),
        markKey = markKey, mark = marks[markKey],
        isQuest = id ~= nil and (not not isQuestItem or type(questID) == "number" and questID > 0
            or classID == (Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12)),
    }
    local b = row.button
    b:SetHasItem(id ~= nil)
    b:SetReadable(info and readable(info.isReadable))
    SetItemButtonTexture(b, info and readable(info.iconFileID) or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    SetItemButtonCount(b, count > 1 and count or 0)
    SetItemButtonDesaturated(b, info and readable(info.isLocked) or false)
    SetItemButtonQuality(b, id and row.item.quality or nil, link, false, info and readable(info.isBound))
    if b.UpdateCooldown then b:UpdateCooldown(id ~= nil) end
    if b.UpdateQuestItem then
        b:UpdateQuestItem(isQuestItem, questID, quest and readable(quest.isActive))
    end
    local mark = app.marks[row.item.mark]
    local suffix = mark and ("  |cff%02x%02x%02x[%s]|r"):format(
        math.floor(mark[2][1] * 255 + 0.5), math.floor(mark[2][2] * 255 + 0.5),
        math.floor(mark[2][3] * 255 + 0.5), mark[1]) or ""
    row.labels.name:SetText(row.item.name .. suffix)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[row.item.quality]
    row.labels.name:SetTextColor(unpack(id and color and {color.r, color.g, color.b} or style.muted))
    row.labels.count:SetText(id and count or "–")
    row.labels.quality:SetText(id and (_G["ITEM_QUALITY" .. row.item.quality .. "_DESC"] or row.item.quality) or "–")
    row.labels.value:SetText(id and money(row.item.value) or "–")
    row.labels.bag:SetText((row.bag == 0 and "Rucksack" or tostring(row.bag)) .. ":" .. row.slot)
end
function inventory.Compare(a, b)
    local x, y = a.item, b.item
    if not x.id ~= not y.id then return x.id ~= nil end
    local key = settings.sort
    local av, bv = x[key], y[key]
    if key == "name" then av, bv = lower(av), lower(bv) end
    -- Uncached merchant values always come last, including descending order.
    if av == nil or bv == nil then
        if av ~= bv then return av ~= nil end
    elseif av ~= bv then
        if settings.ascending then return av < bv else return av > bv end
    end
    if x.bag ~= y.bag then return x.bag < y.bag end
    return x.slot < y.slot
end
function inventory.Category(item)
    if app.marks[item.mark] then return "mark_" .. item.mark end
    if item.isQuest then return "quests" end
    if item.quality == 0 then return "junk" end
    local class = item.classID
    if class == 2 or class == 4 then return "equipment" end
    if class == 0 then return "consumables" end
    if class == 3 or class == 5 or class == 7 or class == 19 then return "materials" end
    if class == 9 then return "recipes" end
    if class == 1 or class == 11 then return "bags" end
    if class == 13 then return "keys" end
    return "other"
end
function inventory.Matches(item)
    if not item.id then return false end
    if settings.hideQuestItems and item.isQuest then return false end
    local query = lower(inventory.query:match("^%s*(.-)%s*$"))
    local categoryName = ""
    for _, category in ipairs(categories) do
        if category[1] == inventory.Category(item) then categoryName = category[2]; break end
    end
    local mark = app.marks[item.mark]
    return query == "" or query == tostring(item.id)
        or lower(item.name .. " " .. item.category .. " " .. item.subcategory .. " " .. categoryName
            .. " " .. (mark and mark[1] or "")):find(query, 1, true) ~= nil
end
layout = function()
    local rows = inventory.displayRows or {}
    local maxOffset = math.max(0, #rows - rowCount)
    inventory.offset = math.max(0, math.min(maxOffset, inventory.offset))
    local displayed = {}
    for index = 1, rowCount do
        local row = rows[index + inventory.offset]
        if row then displayed[row] = true end
    end
    for _, row in pairs(inventory.slots) do if not displayed[row] then row:Hide() end end
    for _, header in pairs(categoryHeaders) do if not displayed[header] then header:Hide() end end
    for index = 1, rowCount do
        local row = rows[index + inventory.offset]
        if row then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 14, -152 - (index - 1) * rowHeight)
            if row.categoryHeader ~= true then
                local mark = app.marks[row.item.mark]
                local base = style.rowColors[index % 2 + 1]
                if mark then
                    local color = mark[2]
                    row.fill:SetColorTexture(base[1] * 0.82 + color[1] * 0.18,
                        base[2] * 0.82 + color[2] * 0.18, base[3] * 0.82 + color[3] * 0.18, 1)
                    row.markAccent:SetColorTexture(color[1], color[2], color[3], 1)
                else row.fill:SetColorTexture(unpack(base)) end
                row.markAccent:SetShown(mark ~= nil)
            end
            row:Show()
        end
    end
    window.slider:SetMinMaxValues(0, maxOffset)
    window.slider:SetValue(inventory.offset)
    window.slider:SetShown(maxOffset > 0)
    window.noItems:SetShown(#(inventory.filtered or {}) == 0)
    window.status:SetText(("%d Treffer · %d / %d Plätze frei"):format(#(inventory.filtered or {}), inventory.free, inventory.capacity))
    for _, col in ipairs(columns) do
        local arrow = settings.sort == col[1] and (settings.ascending and " ^" or " v") or ""
        window.headers[col[1]]:SetText(col[2] .. arrow)
    end
end
local function categorize(rows)
    local buckets, display = {}, {}
    -- Search starts expanded and has its own temporary folds, preserving the
    -- character's normal category layout when the query is cleared.
    local collapsed = inventory.query:find("%S") and inventory.searchCollapsed or settings.collapsed
    for _, row in ipairs(rows) do
        local key = inventory.Category(row.item)
        buckets[key] = buckets[key] or {}
        buckets[key][#buckets[key] + 1] = row
    end
    for _, category in ipairs(categories) do
        local key, caption, color = category[1], category[2], category[3]
        local items = buckets[key]
        if items then
            local header = categoryHeaders[key]
            if not header then
                header = style.TextButton(window)
                header:SetSize(672, rowHeight - 1)
                header.categoryHeader = true
                header.caption = style.Label(header, "", 8, 0, 650, rowHeight - 1, "GameFontNormal", style.gold)
                if color then
                    header.caption:SetTextColor(unpack(color))
                    header:SetBackdropColor(color[1] * 0.22, color[2] * 0.22, color[3] * 0.22, 1)
                    header:SetBackdropBorderColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65, 1)
                end
                header:SetScript("OnClick", function()
                    local folds = inventory.query:find("%S") and inventory.searchCollapsed or settings.collapsed
                    folds[key] = not folds[key]
                    inventory.Refresh()
                end)
                categoryHeaders[key] = header
            end
            header.caption:SetText((collapsed[key] and "[+] " or "[-] ") .. caption .. " (" .. #items .. ")")
            display[#display + 1] = header
            if not collapsed[key] then
                for _, row in ipairs(items) do display[#display + 1] = row end
            end
        end
    end
    inventory.displayRows, inventory.categoryHeaders = display, categoryHeaders
end
function inventory.Refresh()
    if not window or not window:IsShown() then return end
    updateMoney()
    local marks = app.Settings().marks
    local filtered, free, capacity = {}, 0, 0
    local groups, bySlot = {}, {}
    for bag = 0, lastBag() do
        for slot = 1, readable(C.GetContainerNumSlots(bag)) or 0 do
            capacity = capacity + 1
            local row = inventory.slots[bag .. ":" .. slot]
            -- ItemButton bag attributes are initialized out of combat only.
            if not row and not combat() then row = createSlot(bag, slot) end
            if row then
                readSlot(row, marks)
                if not row.item.id then free = free + 1 end
                if row.item.id then
                    local item = row.item
                    local group = groups[item.key]
                    if not group then
                        local total = {}
                        for key, value in pairs(item) do total[key] = value end
                        group = { item = total, representative = row, stackCount = item.count, members = {} }
                        groups[item.key] = group
                    else
                        group.item.count = group.item.count + item.count
                        group.item.value = group.item.value and item.value and (group.item.value + item.value)
                        group.item.isQuest = group.item.isQuest or item.isQuest
                        if group.item.locked and not item.locked then
                            group.representative, group.stackCount = row, item.count
                            group.item.bag, group.item.slot, group.item.locked = row.bag, row.slot, item.locked
                        end
                    end
                    group.members[#group.members + 1] = { bag = row.bag, slot = row.slot, count = item.count }
                    bySlot[row.bag .. ":" .. row.slot] = group
                end
            end
        end
    end
    for _, group in pairs(groups) do
        local row = group.representative
        row.item, row.group = group.item, group
        row.labels.count:SetText(row.item.count)
        row.labels.value:SetText(money(row.item.value))
        row.labels.bag:SetText(#group.members > 1 and (#group.members .. " Stapel")
            or ((row.bag == 0 and "Rucksack" or tostring(row.bag)) .. ":" .. row.slot))
        SetItemButtonCount(row.button, row.item.count > 1 and row.item.count or 0)
        if inventory.Matches(row.item) then filtered[#filtered + 1] = row end
    end
    inventory.groupsBySlot = bySlot
    table.sort(filtered, inventory.Compare)
    inventory.filtered, inventory.free, inventory.capacity = filtered, free, capacity
    categorize(filtered)
    layout()
end
local function createWindow()
    local f = CreateFrame("Frame", "PaulchenQoLInventory", UIParent, "BackdropTemplate")
    window, inventory.window = f, f
    f:SetSize(718, 678)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    style.Panel(f, style.background)
    if type(settings.x) == "number" and type(settings.y) == "number" then
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", settings.x, settings.y)
    else f:SetPoint("CENTER") end
    local title = CreateFrame("Frame", nil, f)
    title:SetPoint("TOPLEFT"); title:SetSize(520, 42)
    title:EnableMouse(true); title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() f:StartMoving() end)
    title:SetScript("OnDragStop", function()
        f:StopMovingOrSizing(); settings.x, settings.y = f:GetCenter()
    end)
    style.Label(title, "Paulchens Taschen", 18, -9, 390, 28, "GameFontNormalLarge", style.gold)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() f:Hide() end)
    local original = style.TextButton(f)
    original:SetSize(130, 25); original:SetPoint("TOPRIGHT", -42, -9); original:SetText("Standardtaschen")
    original:SetScript("OnClick", function()
        settings.enabled = false; pendingAction = nil; f:Hide()
        if OpenAllBags then OpenAllBags() end
        print("Paulchen: Standardtaschen aktiv. /ptaschen aktiviert die Liste wieder.")
    end)
    local search = style.EditBox(f)
    search:SetPoint("TOPLEFT", 18, -48); search:SetSize(420, 28)
    local prompt = style.Label(search, "Name, Gegenstandsart oder ID suchen", 8, 0, 400, 28, "GameFontHighlightSmall", style.muted)
    search:SetScript("OnTextChanged", function(self)
        inventory.query, inventory.offset = self:GetText(), 0
        inventory.searchCollapsed = {}
        prompt:SetShown(inventory.query == ""); inventory.Refresh()
    end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.search = search
    local funds = CreateFrame("Frame", nil, f, "BackdropTemplate")
    funds:SetPoint("TOPLEFT", 448, -48); funds:SetSize(238, 28)
    style.Panel(funds, style.input)
    f.money = style.Label(funds, "", 8, 0, 222, 28, "GameFontHighlight", style.gold, "RIGHT")
    local hideQuest = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    hideQuest:SetPoint("TOPLEFT", 18, -80)
    hideQuest:SetSize(24, 24)
    hideQuest:SetChecked(settings.hideQuestItems)
    style.Label(hideQuest, "Questitems ausblenden", 28, 0, 250, 24, "GameFontHighlightSmall", style.cream)
    hideQuest:SetScript("OnClick", function(self)
        settings.hideQuestItems, inventory.offset = not not self:GetChecked(), 0
        inventory.Refresh()
    end)
    f.hideQuestItems = hideQuest
    f.headers = {}
    for _, col in ipairs(columns) do
        local key = col[1]
        local b = style.TextButton(f)
        b:SetPoint("TOPLEFT", col[3], -119); b:SetSize(col[4] - 4, 25); b:SetText(col[2])
        b:SetScript("OnClick", function()
            if settings.sort == key then settings.ascending = not settings.ascending
            else settings.ascending = key == "name" or key == "bag" end
            settings.sort, inventory.offset = key, 0
            inventory.Refresh()
        end)
        f.headers[key] = b
    end
    local slider = CreateFrame("Slider", nil, f)
    slider:SetPoint("TOPRIGHT", -12, -152); slider:SetSize(14, rowHeight * rowCount)
    slider:SetOrientation("VERTICAL"); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        if value ~= inventory.offset then inventory.offset = value; layout() end
    end)
    f.slider = slider
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) inventory.offset = inventory.offset - delta * 3; layout() end)
    f.status = style.Label(f, "", 18, -608, 650, 20, "GameFontHighlightSmall", style.gold)
    style.Label(f, "Aktionen am Symbol betreffen einen Stapel: benutzen / verkaufen / verschieben", 18, -632, 680, 18, "GameFontHighlightSmall", style.muted)
    style.Label(f, "Zeile rechtsklicken: vormerken · Shift-Klick am Symbol: verlinken / Stapel teilen", 18, -652, 680, 18, "GameFontHighlightSmall", style.muted)
    f.noItems = style.Label(f, "Keine passenden Gegenstände.", 18, -183, 660, 30, "GameFontHighlight", style.muted)
    f:SetScript("OnShow", inventory.Refresh)
    f:Hide()
    UISpecialFrames[#UISpecialFrames + 1] = "PaulchenQoLInventory"
    -- Pre-create slot identities before combat; displaying the window is safe later.
    for bag = 0, lastBag() do
        for slot = 1, readable(C.GetContainerNumSlots(bag)) or 0 do createSlot(bag, slot) end
    end
end
function inventory.Open()
    if not window then return end
    hideOtherBags(); window:Show(); inventory.Refresh()
end
function inventory.Show()
    if settings then settings.enabled = true; inventory.Open() end
end
function inventory.Toggle()
    if window and window:IsShown() then window:Hide() else inventory.Open() end
end
function inventory.VisibleSlot(bag, slot)
    local group = inventory.groupsBySlot and inventory.groupsBySlot[bag .. ":" .. slot]
    local row = group and group.representative or inventory.slots[bag .. ":" .. slot]
    if row and row:IsVisible() then return row.button end
end
local function request(action)
    if suppress or not settings or not settings.enabled then return end
    -- Native bag functions call one another. The outermost call finishes last,
    -- replacing the nested request so one key press toggles exactly once.
    local queued = pendingAction ~= nil
    pendingAction = action
    if queued then return end
    C_Timer.After(0, function()
        local nextAction = pendingAction; pendingAction = nil
        if not settings.enabled or not nextAction then return end
        if nextAction == "close" then if window then window:Hide() end
        elseif nextAction == "toggle" then hideOtherBags(); inventory.Toggle()
        else inventory.Open() end
    end)
end
local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED",
    "GET_ITEM_INFO_RECEIVED", "QUEST_LOG_UPDATE", "PLAYER_MONEY", "PLAYER_REGEN_ENABLED", "MERCHANT_SHOW", "MERCHANT_CLOSED" }) do
    app.RegisterSupported(events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_MONEY" then updateMoney(); return end
    if event == "PLAYER_LOGIN" then
        if not C or not ContainerFrameItemButtonMixin then return end
        local db = app.Settings()
        if type(db.inventory) ~= "table" then db.inventory = {} end
        settings = db.inventory
        if settings.enabled == nil then settings.enabled = true end
        if type(settings.hideQuestItems) ~= "boolean" then settings.hideQuestItems = true end
        if type(settings.collapsed) ~= "table" then settings.collapsed = {} end
        local valid = false
        for _, col in ipairs(columns) do if settings.sort == col[1] then valid = true end end
        if not valid then settings.sort, settings.ascending = "name", true end
        if type(settings.ascending) ~= "boolean" then settings.ascending = true end
        createWindow()
        SLASH_PAULCHENINVENTORY1 = "/ptaschen"
        SlashCmdList.PAULCHENINVENTORY = function()
            settings.enabled = true; inventory.Toggle()
        end
        for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBackpack_Combined", "ToggleBag" }) do
            if _G[name] then hooksecurefunc(name, function(bag)
                if name ~= "ToggleBag" or type(bag) == "number" and bag >= 0 and bag <= lastBag() then request("toggle") end
            end) end
        end
        for _, name in ipairs({ "OpenAllBags", "OpenBackpack" }) do
            if _G[name] then hooksecurefunc(name, function() request("open") end) end
        end
        for _, name in ipairs({ "CloseAllBags", "CloseBackpack" }) do
            if _G[name] then hooksecurefunc(name, function() request("close") end) end
        end
        if OpenBag then hooksecurefunc("OpenBag", function(bag)
            if type(bag) == "number" and bag >= 0 and bag <= lastBag() then request("open") end
        end) end
        return
    end
    if not window or not window:IsShown() or refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.1, function() refreshQueued = false; inventory.Refresh() end)
end)
