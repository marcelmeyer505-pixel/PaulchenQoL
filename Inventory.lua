local _, app = ...
local C, style, readable = C_Container, app.style, app.Readable
local inventory = { slots = {}, offset = 0, query = "", searchCollapsed = {} }
app.inventory = inventory
local window, settings, refreshQueued, suppress, pendingAction, markMenu, categoryEditor
local layout
local rowHeight, rowCount = 32, 14
local clearMarkLabel = "Ohne Markierung"
local itemCategories = {
    { "equipment", "Ausrüstung" }, { "consumables", "Verbrauchbares" },
    { "materials", "Handwerksmaterial" }, { "recipes", "Rezepte" },
    { "bags", "Taschen" }, { "keys", "Schlüssel" },
    { "quests", "Questgegenstände" }, { "junk", "Plunder" }, { "other", "Sonstiges" },
}
local categories, categoryNames = {}, {}
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
local function customCategoryIndex(key)
    if key then return tonumber(key:match("^custom_(%d+)$")) end
end
local function updateCategories()
    categories, categoryNames = {}, {}
    -- Explicit marks come before the automatic item-class categories.
    for _, key in ipairs(app.markOrder) do
        local mark = app.marks[key]
        categories[#categories + 1] = { "mark_" .. key, mark[1], mark[2] }
    end
    for _, category in ipairs(itemCategories) do categories[#categories + 1] = category end
    for _, category in ipairs(categories) do categoryNames[category[1]] = category[2] end
end
local function loadMarkCategories()
    local saved = settings.markCategories
    for _, key in ipairs(app.markOrder) do app.marks[key] = saved[key] or app.marks[key] end
    local indices = {}
    for index in pairs(saved) do
        if type(index) == "number" then indices[#indices + 1] = index end
    end
    table.sort(indices)
    settings.nextMarkCategoryId = math.max(tonumber(settings.nextMarkCategoryId) or 1, (indices[#indices] or 0) + 1)
    for _, index in ipairs(indices) do
        local key = "custom_" .. index
        if not app.marks[key] then app.markOrder[#app.markOrder + 1] = key end
        app.marks[key] = saved[index]
    end
    updateCategories()
end
local function refreshMarkCategories()
    updateCategories()
    inventory.Refresh()
    if app.RefreshOverview then app.RefreshOverview() end
end
local function saveMarkCategory(key, name, color)
    local saved = settings.markCategories
    local storageKey = customCategoryIndex(key) or key
    if not key then
        storageKey = settings.nextMarkCategoryId
        settings.nextMarkCategoryId = storageKey + 1
        key = "custom_" .. storageKey
        app.markOrder[#app.markOrder + 1] = key
    end
    local definition = { name, color }
    saved[storageKey], app.marks[key] = definition, definition
    refreshMarkCategories()
    return key
end
local function deleteMarkCategory(key)
    local index = customCategoryIndex(key)
    if not index or not settings.markCategories[index] then return end
    settings.markCategories[index], app.marks[key] = nil, nil
    for position, mark in ipairs(app.markOrder) do
        if mark == key then table.remove(app.markOrder, position); break end
    end

    local category = "mark_" .. key
    settings.collapsed[category], inventory.searchCollapsed[category] = nil, nil
    local header = categoryHeaders[category]
    if header then header:Hide() end
    categoryHeaders[category] = nil
    local marks = app.Settings().marks
    for itemKey, mark in pairs(marks) do
        if mark == key then marks[itemKey] = nil end
    end
    refreshMarkCategories()
end
local function colorHex(r, g, b)
    return ("#%02X%02X%02X"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end
local function readColor(text)
    local r, g, b = text:match("^%s*#?(%x%x)(%x%x)(%x%x)%s*$")
    if r then return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 } end
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
local function categoryButton(parent, text, x, y, width, onClick)
    local button = style.TextButton(parent)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width, 24)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end
local function createMarkList(parent, width, visibleRows, choose, allowClear)
    local list = CreateFrame("Frame", nil, parent)
    list.options, list.page, list.selected = {}, 1, false
    local markRows = visibleRows - (allowClear and 1 or 0)
    local function paint()
        local pages = math.ceil(#app.markOrder / markRows)
        local first = (list.page - 1) * markRows
        local shownMarks = math.min(markRows, #app.markOrder - first)
        for index, option in ipairs(list.options) do
            local key = index <= shownMarks and app.markOrder[first + index] or nil
            local definition = app.marks[key]
            local shown = definition ~= nil or allowClear == true and index == shownMarks + 1
            option.key = key
            option.button:SetShown(shown)
            option.title:SetText(definition and definition[1] or clearMarkLabel)
            option.title:SetTextColor(unpack(definition and definition[2] or style.cream))
            local active = shown and (key or false) == list.selected
            option.check:SetShown(active)
            style.SetButtonState(option.button, active)
        end
        list.previous:SetEnabled(list.page > 1)
        list.next:SetEnabled(list.page < pages)
        list.previous:SetShown(pages > 1)
        list.next:SetShown(pages > 1)
        list.pageText:SetShown(pages > 1)
        list.pageText:SetText(("%d / %d"):format(list.page, pages))
        local height = pages > 1 and visibleRows * 26 + 28 or (shownMarks + (allowClear and 1 or 0)) * 26
        list:SetSize(width, height)
    end
    for index = 1, visibleRows do
        local button = style.Button(list)
        button:SetSize(width, 24)
        button:SetPoint("TOPLEFT", 0, -(index - 1) * 26)
        local title = style.Label(button, "", 28, 0, width - 34, 24, "GameFontHighlightSmall", style.cream)
        local check = button:CreateTexture(nil, "OVERLAY")
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check:SetSize(18, 18)
        check:SetPoint("LEFT", 4, 0)
        local option = { button = button, title = title, check = check }
        list.options[index] = option
        button:SetScript("OnClick", function()
            if button:IsVisible() then choose(option.key) end
        end)
    end
    local function turnPage(delta)
        list.page = math.max(1, math.min(list.page + delta, math.ceil(#app.markOrder / markRows)))
        paint()
    end
    local footer = -visibleRows * 26 - 2
    list.previous = categoryButton(list, "<", 0, footer, 38, function() turnPage(-1) end)
    list.next = categoryButton(list, ">", width - 38, footer, 38, function() turnPage(1) end)
    list.pageText = style.Label(list, "", 40, footer, width - 80, 24, "GameFontHighlightSmall", style.muted, "CENTER")
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) turnPage(delta > 0 and -1 or 1) end)
    function list.Select(key, jumpToSelection)
        list.selected = key or false
        if jumpToSelection then
            list.page = 1
            for index, mark in ipairs(app.markOrder) do
                if mark == key then list.page = math.ceil(index / markRows); break end
            end
        end
        paint()
    end
    return list
end
local function createMarkMenu()
    local menu = CreateFrame("Frame", "PaulchenInventoryMarkMenu", window, "BackdropTemplate")
    menu:Hide()
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    menu:SetFrameLevel(window:GetFrameLevel() + 20)
    style.Panel(menu, style.background, style.accent)
    menu.title = style.Label(menu, "", 10, -3, 192, 28, "GameFontNormal", style.gold)
    local close = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -1, -1)
    close:SetScript("OnClick", function() menu:Hide() end)

    menu.list = createMarkList(menu, 222, 8, function(key)
        local item = menu.item
        menu:Hide()
        inventory.Mark(item, key)
    end, true)
    menu.list:SetPoint("TOPLEFT", 8, -32)

    menu:SetScript("OnShow", function(self) app.RegisterSupported(self, "GLOBAL_MOUSE_DOWN") end)
    menu:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        self.ownerRow, self.item = nil, nil
    end)
    menu:SetScript("OnEvent", function(self)
        if not self:IsMouseOver() then self:Hide() end
    end)
    return menu
end
local function showMarkMenu(row)
    if categoryEditor and categoryEditor:IsShown() then return end
    markMenu = markMenu or createMarkMenu()
    markMenu.ownerRow, markMenu.item = row, row.item
    markMenu.title:SetText(row.item.name)
    markMenu.list.Select(app.Settings().marks[row.item.markKey], true)
    markMenu:SetSize(238, 38 + markMenu.list:GetHeight())
    markMenu:ClearAllPoints()
    markMenu:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 36, -2)
    GameTooltip:Hide()
    markMenu:Show()
end
local function createCategoryEditor()
    local editor = CreateFrame("Frame", "PaulchenBagCategoryEditor", window, "BackdropTemplate")
    editor:Hide()
    editor:EnableMouse(true)
    editor:SetFrameLevel(window:GetFrameLevel() + 25)
    editor:SetPoint("CENTER")
    editor:SetSize(534, 328)
    style.Panel(editor, style.background, style.accent)
    style.Label(editor, "Taschenkategorien", 14, -5, 430, 28, "GameFontNormalLarge", style.gold)
    local close = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() editor:Hide() end)

    editor.heading = style.Label(editor, "", 246, -42, 270, 24, "GameFontNormal", style.gold)
    style.Label(editor, "Name", 246, -74, 270, 18, "GameFontHighlightSmall", style.muted)
    editor.nameBox = style.EditBox(editor)
    editor.nameBox:SetPoint("TOPLEFT", 246, -96)
    editor.nameBox:SetSize(270, 26)
    editor.nameBox:SetMaxLetters(32)
    style.Label(editor, "Farbe", 246, -134, 270, 18, "GameFontHighlightSmall", style.muted)
    editor.hexBox = style.EditBox(editor)
    editor.hexBox:SetPoint("TOPLEFT", 422, -155)
    editor.hexBox:SetSize(94, 24)
    editor.hexBox:SetMaxLetters(7)
    editor.status = style.Label(editor, "", 246, -238, 270, 48, "GameFontHighlightSmall", style.muted)
    editor.status:SetWordWrap(true)
    for _, input in ipairs({ editor.nameBox, editor.hexBox }) do
        input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end

    local function edit(key, jumpToSelection)
        editor.key, editor.colorSession = key or false, false
        local definition = app.marks[key]
        local removable = customCategoryIndex(key) ~= nil
        editor.heading:SetText(definition and "Kategorie bearbeiten" or "Neue Kategorie")
        editor.nameBox:SetText(definition and definition[1] or "")
        editor.hexBox:SetText(colorHex(unpack(definition and definition[2] or style.gold)))
        editor.status:SetText("")
        editor.deletePrompt:Hide()
        editor.deleteCategory:SetShown(removable)
        editor.saveCategory:SetWidth(removable and 170 or 270)
        editor.list.Select(key or false, jumpToSelection)
    end
    editor.list = createMarkList(editor, 210, 8, function(key) edit(key) end)
    editor.list:SetPoint("TOPLEFT", 14, -76)
    editor.newCategory = categoryButton(editor, "+ Neue Kategorie", 14, -42, 210, function()
        edit(nil, true)
        editor.nameBox:SetFocus()
    end)

    editor.colorButton = categoryButton(editor, "Farbe wählen", 246, -155, 163, function()
        local picker = ColorPickerFrame
        if not (picker and picker.SetupColorPickerAndShow and picker.GetColorRGB) then
            editor.hexBox:SetFocus()
            return
        end
        local previous = editor.hexBox:GetText()
        local color = readColor(previous) or style.gold
        local session = {}
        editor.colorSession = session
        picker:SetupColorPickerAndShow({
            r = color[1], g = color[2], b = color[3],
            swatchFunc = function()
                if editor:IsVisible() and editor.colorSession == session then
                    editor.hexBox:SetText(colorHex(picker:GetColorRGB()))
                end
            end,
            cancelFunc = function()
                if editor:IsVisible() and editor.colorSession == session then editor.hexBox:SetText(previous) end
            end,
        })
    end)
    local swatch = editor.colorButton:CreateTexture(nil, "OVERLAY")
    swatch:SetSize(16, 16)
    swatch:SetPoint("LEFT", 8, 0)
    editor.hexBox:SetScript("OnTextChanged", function(self)
        local color = readColor(self:GetText())
        swatch:SetShown(color ~= nil)
        if color then swatch:SetColorTexture(unpack(color)) end
    end)

    editor.saveCategory = categoryButton(editor, "Speichern", 246, -198, 270, function()
        local name = editor.nameBox:GetText():match("^%s*(.-)%s*$")
        if name == "" or name:find("[|%c]") then
            editor.status:SetText("Gib einen gültigen Kategorienamen ein.")
            return
        end
        local color = readColor(editor.hexBox:GetText())
        if not color then
            editor.status:SetText("Wähle eine Farbe oder gib einen Hex-Code ein, z. B. #4DA6FF.")
            return
        end
        local normalized = lower(name)
        if normalized == lower(clearMarkLabel) then
            editor.status:SetText("Dieser Name ist bereits vergeben.")
            return
        end
        for _, key in ipairs(app.markOrder) do
            if key ~= editor.key and lower(app.marks[key][1]) == normalized then
                editor.status:SetText("Dieser Name ist bereits vergeben.")
                return
            end
        end
        edit(saveMarkCategory(editor.key, name, color), true)
        editor.status:SetText("Gespeichert")
        editor.nameBox:ClearFocus()
        editor.hexBox:ClearFocus()
    end)
    local deletePrompt = CreateFrame("Frame", nil, editor)
    deletePrompt:SetPoint("TOPLEFT", 246, -234)
    deletePrompt:SetSize(270, 78)
    deletePrompt:Hide()
    editor.deletePrompt = deletePrompt
    local deleteText = style.Label(deletePrompt, "", 0, 0, 270, 38, "GameFontHighlightSmall", style.cream)
    deleteText:SetWordWrap(true)
    editor.confirmDelete = categoryButton(deletePrompt, "Löschen bestätigen", 0, -43, 170, function()
        if not deletePrompt:IsVisible() then return end
        deleteMarkCategory(editor.key)
        edit(nil, true)
        editor.status:SetText("Kategorie gelöscht")
    end)
    editor.cancelDelete = categoryButton(deletePrompt, "Abbrechen", 178, -43, 92, function() deletePrompt:Hide() end)
    editor.deleteCategory = categoryButton(editor, "Löschen", 426, -198, 90, function()
        editor.status:SetText("")
        deleteText:SetText(("„%s“ löschen? Die Gegenstände werden automatisch einsortiert."):format(app.marks[editor.key][1]))
        deletePrompt:Show()
    end)
    editor:SetScript("OnShow", function() edit(nil, true) end)
    editor:SetScript("OnHide", function()
        editor.colorSession = false
        editor.nameBox:ClearFocus()
        editor.hexBox:ClearFocus()
    end)
    return editor
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
        if mouseButton == "RightButton" and self.item and self.item.markKey then showMarkMenu(self) end
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
    if query == "" or query == tostring(item.id) then return true end
    local categoryName = categoryNames[inventory.Category(item)] or ""
    return lower(item.name .. " " .. item.category .. " " .. item.subcategory .. " " .. categoryName):find(query, 1, true) ~= nil
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
    if markMenu and markMenu:IsShown() then
        local owner = markMenu.ownerRow
        if not displayed[owner] or owner.item.markKey ~= markMenu.item.markKey then markMenu:Hide() end
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
                header:SetScript("OnClick", function()
                    local folds = inventory.query:find("%S") and inventory.searchCollapsed or settings.collapsed
                    folds[key] = not folds[key]
                    inventory.Refresh()
                end)
                categoryHeaders[key] = header
            end
            if color then
                header.caption:SetTextColor(unpack(color))
                header:SetBackdropColor(color[1] * 0.22, color[2] * 0.22, color[3] * 0.22, 1)
                header:SetBackdropBorderColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65, 1)
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
    f.categories = categoryButton(f, "Kategorien", 550, -82, 136, function()
        if markMenu then markMenu:Hide() end
        categoryEditor = categoryEditor or createCategoryEditor()
        categoryEditor:SetShown(not categoryEditor:IsShown())
    end)
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
    f:SetScript("OnHide", function()
        if markMenu then markMenu:Hide() end
        if categoryEditor then categoryEditor:Hide() end
    end)
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
        if type(settings.markCategories) ~= "table" then settings.markCategories = {} end
        loadMarkCategories()
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
