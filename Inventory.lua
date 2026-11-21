local _, app = ...
local C, style, readable = C_Container, app.style, app.Readable
local inventory = { slots = {}, offset = 0, query = "", searchCollapsed = {}, categoryHeaders = {} }
local bank = { slots = {}, offset = 0, query = "", searchCollapsed = {}, categoryHeaders = {}, isBank = true }
app.inventory = inventory
inventory.bank = bank
local window, settings, refreshQueued, suppress, pendingAction, markMenu, categoryEditor
local layout, refreshView, openBank, depositCategory, transfer
local rowHeight, rowCount = 32, 14
local builtinMarkCount = #app.markOrder
local clearMarkLabel = "Ohne Markierung"
local itemCategories = {
    { "equipment", "Ausrüstung" }, { "consumables", "Verbrauchbares" },
    { "materials", "Handwerksmaterial" }, { "recipes", "Rezepte" },
    { "bags", "Taschen" }, { "keys", "Schlüssel" },
    { "quests", "Questgegenstände" }, { "junk", "Plunder" }, { "other", "Sonstiges" },
}
local categories, categoryNames = {}, {}
local columns = {
    { "name", "Gegenstand", 52, 268 }, { "count", "Anzahl", 324, 54 },
    { "quality", "Qualität", 382, 92 }, { "value", "Händler / Gesamt", 478, 128 },
    { "bag", "Tasche", 610, 76 },
}
local function lastBag() return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function characterBankType() return Enum and Enum.BankType and Enum.BankType.Character end
local function canBank()
    if not bank.atBank then return false end
    local bankType = characterBankType()
    if bankType ~= nil and C_Bank and C_Bank.CanUseBank then
        return readable(C_Bank.CanUseBank(bankType)) == true
    end
    return BANK_CONTAINER ~= nil
end
local function canDeposit()
    return canBank() and C.PickupContainerItem and GetCursorInfo and ClearCursor
end
local function bankContainers()
    local bags, names = {}, {}
    local legacy = BANK_CONTAINER
    local bankType = characterBankType()
    if bankType ~= nil and C_Bank and C_Bank.FetchPurchasedBankTabData then
        local tabs = readable(C_Bank.FetchPurchasedBankTabData(bankType)) or {}
        for _, tab in ipairs(tabs) do
            local bag = readable(tab.ID)
            if type(bag) == "number" and bag > lastBag() and not names[bag] then
                bags[#bags + 1], names[bag] = bag, readable(tab.name) or "Bankfach " .. (#bags + 1)
            end
        end
    end
    if #bags == 0 and legacy and (readable(C.GetContainerNumSlots(legacy)) or 0) > 0 then
        bags[1], names[legacy] = legacy, "Bank"
        for bag = lastBag() + 1, lastBag() + (NUM_BANKBAGSLOTS or 0) do
            bags[#bags + 1], names[bag] = bag, "Banktasche " .. (bag - lastBag())
        end
    end
    return bags, names
end
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
    for index = 1, builtinMarkCount do
        local key = app.markOrder[index]
        app.marks[key] = saved[key] or app.marks[key]
    end
    for index = #app.markOrder, builtinMarkCount + 1, -1 do
        app.marks[app.markOrder[index]] = nil
        app.markOrder[index] = nil
    end
    local indices = {}
    for index in pairs(saved) do
        if type(index) == "number" then indices[#indices + 1] = index end
    end
    table.sort(indices)
    settings.nextMarkCategoryId = math.max(tonumber(settings.nextMarkCategoryId) or 1, (indices[#indices] or 0) + 1)
    local loaded = {}
    local function loadCategory(index)
        if type(index) ~= "number" or not saved[index] or loaded[index] then return end
        local key = "custom_" .. index
        app.markOrder[#app.markOrder + 1] = key
        app.marks[key] = saved[index]
        loaded[index] = true
    end
    if type(settings.customCategoryOrder) == "table" then
        for _, index in ipairs(settings.customCategoryOrder) do loadCategory(index) end
    end
    for _, index in ipairs(indices) do loadCategory(index) end
    updateCategories()
end
local function refreshMarkCategories()
    local order = {}
    for index = builtinMarkCount + 1, #app.markOrder do
        order[#order + 1] = customCategoryIndex(app.markOrder[index])
    end
    settings.customCategoryOrder = order
    updateCategories()
    inventory.Refresh()
    if app.RefreshOverview then app.RefreshOverview() end
end
local function moveMarkCategory(source, target, after)
    local from, to
    for index = builtinMarkCount + 1, #app.markOrder do
        local key = app.markOrder[index]
        if key == source then from = index end
        if key == target then to = index end
    end
    if not from or not to or from == to then return false end
    local insertion = to + (after and 1 or 0) - (from < to and 1 or 0)
    if insertion == from then return false end
    table.remove(app.markOrder, from)
    table.insert(app.markOrder, insertion, source)
    refreshMarkCategories()
    return true
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
    for _, view in ipairs({ inventory, bank }) do
        view.settings.collapsed[category], view.searchCollapsed[category] = nil, nil
        local header = view.categoryHeaders[category]
        if header then header:Hide() end
        view.categoryHeaders[category] = nil
    end
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
local function slotText(row)
    local names = row.view.containerNames
    return ((names and names[row.bag]) or (row.bag == 0 and "Rucksack" or tostring(row.bag))) .. ":" .. row.slot
end
local function groupTooltip(row)
    local mark = row.item and app.marks[row.item.mark]
    if mark then GameTooltip:AddLine("Vormerkung: " .. mark[1], unpack(mark[2])) end
    local group = row.group
    if not group or #group.members < 2 then return end
    GameTooltip:AddLine(("Gesamt: %d · %d Stapel"):format(row.item.count, #group.members), 1, 0.82, 0.45)
    GameTooltip:AddLine(("Aktionen betreffen diesen Stapel: %d Stück (%s)")
        :format(group.stackCount, slotText(row)), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end
function inventory.Mark(item, mark, view)
    if not item or not item.markKey or mark and not app.marks[mark] then return end
    app.Settings().marks[item.markKey] = mark
    view = view or inventory
    if mark and view.settings then
        view.settings.collapsed["mark_" .. mark] = nil
        view.searchCollapsed["mark_" .. mark] = nil
    end
    inventory.Refresh()
    -- Keep the moved item visible after its category changes. Slot identities
    -- remain fixed; only the row's visual position and viewport move.
    for index, row in ipairs(view.displayRows or {}) do
        if row.categoryHeader ~= true and row.item.markKey == item.markKey then
            view.offset = math.max(0, index - 2)
            layout(view)
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
local function enableCategoryDrag(list)
    local draggedKey, markedRow, markedAfter
    local line = list:CreateTexture(nil, "OVERLAY")
    line:SetHeight(2)
    line:SetColorTexture(unpack(style.gold))
    line:Hide()

    local function dropTarget()
        local _, cursorY = GetCursorPosition()
        for _, option in ipairs(list.options) do
            local row = option.button
            if option.key ~= draggedKey and option.handle:IsVisible() and row:IsMouseOver() then
                local _, middle = row:GetCenter()
                if middle then return option, cursorY < middle * row:GetEffectiveScale() end
            end
        end
    end
    local function cancel()
        draggedKey, markedRow, markedAfter = nil, nil, nil
        list:SetScript("OnUpdate", nil)
        line:Hide()
    end
    local function finish()
        if not draggedKey then return end
        local target, after = dropTarget()
        local source = draggedKey
        cancel()
        if target and moveMarkCategory(source, target.key, after) then list.Select(list.selected, false) end
    end
    local function update()
        if not IsMouseButtonDown("LeftButton") then finish(); return end
        local target, after = dropTarget()
        if markedRow == target and markedAfter == after then return end
        markedRow, markedAfter = target, after
        line:SetShown(target ~= nil)
        if target then
            local edge = after and "BOTTOM" or "TOP"
            line:ClearAllPoints()
            line:SetPoint("LEFT", target.button, edge .. "LEFT", 0, after and -1 or 1)
            line:SetPoint("RIGHT", target.button, edge .. "RIGHT", 0, after and -1 or 1)
        end
    end
    for _, option in ipairs(list.options) do
        local grip = CreateFrame("Button", nil, option.button)
        option.handle = grip
        grip:SetPoint("RIGHT", -1, 0)
        grip:SetSize(24, 24)
        grip:EnableMouse(true)
        grip:RegisterForDrag("LeftButton")
        for row = 0, 2 do
            for column = 0, 1 do
                local dot = grip:CreateTexture(nil, "ARTWORK")
                dot:SetSize(2, 2)
                dot:SetPoint("CENTER", -3 + column * 6, 5 - row * 5)
                dot:SetColorTexture(unpack(style.gold))
            end
        end
        grip:SetScript("OnDragStart", function(self)
            if not self:IsVisible() then return end
            draggedKey = option.key
            list:SetScript("OnUpdate", update)
            update()
        end)
        grip:SetScript("OnDragStop", function()
            if not IsMouseButtonDown("LeftButton") then finish() end
        end)
    end
    list:SetScript("OnHide", cancel)
end
local function createMarkList(parent, width, visibleRows, choose, allowClear, reorder)
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
            if option.handle then option.handle:SetShown(customCategoryIndex(key) ~= nil) end
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
        local title = style.Label(button, "", 28, 0, width - (reorder and 56 or 34), 24,
            "GameFontHighlightSmall", style.cream)
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
    if reorder then enableCategoryDrag(list) end
    return list
end
local function createMarkMenu()
    local menu = CreateFrame("Frame", "PaulchenInventoryMarkMenu", UIParent, "BackdropTemplate")
    menu:Hide()
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    menu:SetFrameStrata("DIALOG")
    style.Panel(menu, style.background, style.accent)
    menu.title = style.Label(menu, "", 10, -3, 192, 28, "GameFontNormal", style.gold)
    local close = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -1, -1)
    close:SetScript("OnClick", function() menu:Hide() end)

    menu.list = createMarkList(menu, 222, 8, function(key)
        local item, view = menu.item, menu.ownerRow.view
        menu:Hide()
        inventory.Mark(item, key, view)
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
    markMenu:SetFrameLevel(row.view.window:GetFrameLevel() + 20)
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
    editor.list = createMarkList(editor, 210, 8, function(key) edit(key) end, false, true)
    editor.list:SetPoint("TOPLEFT", 14, -76)
    style.Label(editor, "Eigene Kategorien am Griff ziehen", 14, -310, 210, 15, "GameFontHighlightSmall", style.muted)
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
local function updateMoney(view)
    local frame = view.window
    if frame and frame.money then
        frame.money:SetText(money(GetMoney and readable(GetMoney())))
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
local function createSlot(view, bag, slot)
    local row = CreateFrame("Frame", nil, view.window)
    row:SetSize(672, rowHeight - 1)
    row:EnableMouse(true)
    row.button = makeButton(row, bag, slot)
    row.view, row.bag, row.slot = view, bag, slot
    if view.isBank and C.UseContainerItem then
        local onClick = row.button:GetScript("OnClick")
        row.button:SetScript("OnClick", function(self, mouseButton)
            if not canBank() or combat() then return end
            if mouseButton == "RightButton" and not (IsModifiedClick and IsModifiedClick()) then
                if not GetCursorInfo or not GetCursorInfo() then C.UseContainerItem(bag, slot) end
            elseif onClick then onClick(self, mouseButton) end
        end)
    end
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
    view.slots[bag .. ":" .. slot] = row
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
    if not row.view.isBank and b.UpdateCooldown then b:UpdateCooldown(id ~= nil) end
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
    row.labels.bag:SetText(slotText(row))
end
function inventory.Compare(a, b, viewSettings)
    viewSettings = viewSettings or settings
    local x, y = a.item, b.item
    if not x.id ~= not y.id then return x.id ~= nil end
    local key = viewSettings.sort
    local av, bv = x[key], y[key]
    if key == "name" then av, bv = lower(av), lower(bv) end
    -- Uncached merchant values always come last, including descending order.
    if av == nil or bv == nil then
        if av ~= bv then return av ~= nil end
    elseif av ~= bv then
        if viewSettings.ascending then return av < bv else return av > bv end
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
function inventory.Matches(item, view)
    view = view or inventory
    if not item.id then return false end
    if view.settings.hideQuestItems and item.isQuest then return false end
    local query = lower(view.query:match("^%s*(.-)%s*$"))
    if query == "" or query == tostring(item.id) then return true end
    local categoryName = categoryNames[inventory.Category(item)] or ""
    return lower(item.name .. " " .. item.category .. " " .. item.subcategory .. " " .. categoryName):find(query, 1, true) ~= nil
end
layout = function(view)
    local window, settings = view.window, view.settings
    local rows = view.displayRows or {}
    local maxOffset = math.max(0, #rows - rowCount)
    view.offset = math.max(0, math.min(maxOffset, view.offset))
    local displayed = {}
    for index = 1, rowCount do
        local row = rows[index + view.offset]
        if row then displayed[row] = true end
    end
    if markMenu and markMenu:IsShown() and markMenu.ownerRow.view == view then
        local owner = markMenu.ownerRow
        if not displayed[owner] or owner.item.markKey ~= markMenu.item.markKey then markMenu:Hide() end
    end
    for _, row in pairs(view.slots) do if not displayed[row] then row:Hide() end end
    for _, header in pairs(view.categoryHeaders) do if not displayed[header] then header:Hide() end end
    for index = 1, rowCount do
        local row = rows[index + view.offset]
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
    window.slider:SetValue(view.offset)
    window.slider:SetShown(maxOffset > 0)
    window.noItems:SetShown(#(view.filtered or {}) == 0)
    window.status:SetText(("%d Treffer · %d / %d Plätze frei"):format(#(view.filtered or {}), view.free, view.capacity))
    for _, col in ipairs(columns) do
        local arrow = settings.sort == col[1] and (settings.ascending and " ^" or " v") or ""
        window.headers[col[1]]:SetText(col[2] .. arrow)
    end
end
local function categorize(view, rows)
    local buckets, display = {}, {}
    local window, settings, categoryHeaders = view.window, view.settings, view.categoryHeaders
    -- Search starts expanded and has its own temporary folds, preserving the
    -- character's normal category layout when the query is cleared.
    local collapsed = view.query:find("%S") and view.searchCollapsed or settings.collapsed
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
                    local folds = view.query:find("%S") and view.searchCollapsed or settings.collapsed
                    folds[key] = not folds[key]
                    categorize(view, view.filtered)
                    layout(view)
                end)
                if not view.isBank then
                    header.deposit = categoryButton(header, "Einlagern", 552, -4, 110, function() depositCategory(key) end)
                end
                categoryHeaders[key] = header
            end
            if not view.isBank then
                header.deposit:SetShown(not not canDeposit())
                header.deposit:SetEnabled(not transfer and not combat())
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
    view.displayRows = display
end
refreshView = function(view)
    if not view.window or not view.window:IsShown() or (view.isBank and not canBank()) then return end
    updateMoney(view)
    local marks = app.Settings().marks
    local filtered, free, capacity = {}, 0, 0
    local groups, bySlot = {}, {}
    local bags = {}
    if view.isBank then bags, view.containerNames = bankContainers()
    else for bag = 0, lastBag() do bags[#bags + 1] = bag end end
    for _, bag in ipairs(bags) do
        for slot = 1, readable(C.GetContainerNumSlots(bag)) or 0 do
            capacity = capacity + 1
            local row = view.slots[bag .. ":" .. slot]
            -- ItemButton bag attributes are initialized out of combat only.
            if not row and not combat() then row = createSlot(view, bag, slot) end
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
            or slotText(row))
        SetItemButtonCount(row.button, row.item.count > 1 and row.item.count or 0)
        if inventory.Matches(row.item, view) then filtered[#filtered + 1] = row end
    end
    view.groupsBySlot = bySlot
    table.sort(filtered, function(a, b) return inventory.Compare(a, b, view.settings) end)
    view.filtered, view.free, view.capacity = filtered, free, capacity
    categorize(view, filtered)
    layout(view)
end
function inventory.Refresh()
    refreshView(inventory)
    refreshView(bank)
end
-- Use fixed, verified slots so this action can only move items to the personal bank.
local function physicalStack(bag, slot)
    local raw = C.GetContainerItemInfo(bag, slot)
    local info = readable(raw)
    if info == nil then
        if issecretvalue and issecretvalue(raw) then return false end
        return nil
    end
    local id, link, count = readable(info.itemID), readable(info.hyperlink), readable(info.stackCount)
    if not id or not link or not count then return false end
    return { key = groupKey(id, link), link = link, count = count, locked = readable(info.isLocked) ~= false }
end
local function stackGUID(bag, slot)
    if C_Item and C_Item.GetItemGUID and ItemLocation then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        if location:IsValid() then return readable(C_Item.GetItemGUID(location)) end
    end
end
local function permittedInBank(bag, slot)
    local bankType = characterBankType()
    if bankType == nil or not (C_Bank and C_Bank.IsItemAllowedInBankType and ItemLocation) then return true end
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    return location:IsValid() and readable(C_Bank.IsItemAllowedInBankType(bankType, location)) == true
end
local function bankDestination(bags, source)
    local itemAPI = C_Item and C_Item.GetItemInfo or GetItemInfo
    local maxStack = readable(select(8, itemAPI(source.link))) or 1
    local getFamily = C_Item and C_Item.GetItemFamily or GetItemFamily
    local itemFamily = getFamily and readable(getFamily(source.link)) or 0
    local empty
    for _, bag in ipairs(bags) do
        local _, family
        if C.GetContainerNumFreeSlots then _, family = C.GetContainerNumFreeSlots(bag) end
        family = readable(family) or 0
        if family == 0 or (bit and bit.band(itemFamily, family) ~= 0) then
            for slot = 1, readable(C.GetContainerNumSlots(bag)) or 0 do
                local target = physicalStack(bag, slot)
                if target == nil and not empty then
                    empty = { bag = bag, slot = slot, count = 0 }
                elseif target and not target.locked and target.key == source.key and target.count < maxStack then
                    return { bag = bag, slot = slot, count = target.count }
                end
            end
        end
    end
    return empty
end
local function transferMessage(text)
    for _, view in ipairs({ inventory, bank }) do
        if view.window then view.window.transferStatus:SetText(text or view.window.defaultActions) end
    end
end
local function finishTransfer(state, reason)
    if transfer ~= state then return end
    transfer = nil
    local remaining = state.total - state.moved
    local text = ("%d Stück eingelagert"):format(state.moved)
    if remaining > 0 then text = text .. (" · %d übrig"):format(remaining) end
    if reason then text = text .. " · " .. reason end
    bank.transferMessage = text
    transferMessage(text)
    inventory.Refresh()
end
local stepTransfer
local function confirmMove(state, entry, target, tries)
    if transfer ~= state then return end
    if not canBank() then finishTransfer(state, "Bank geschlossen"); return end
    local sourceNow = physicalStack(entry.bag, entry.slot)
    local targetNow = physicalStack(target.bag, target.slot)
    local remainder = sourceNow and sourceNow.key == entry.key and sourceNow.count or 0
    local moved = 0
    if sourceNow ~= false and targetNow and targetNow.key == entry.key then
        moved = math.min(entry.count - remainder, targetNow.count - target.count)
    end
    if moved > 0 then
        state.moved = state.moved + moved
        entry.count = entry.count - moved
        if entry.count == 0 then state.index = state.index + 1 end
        transferMessage(("Einlagern … %d / %d Stück"):format(state.moved, state.total))
        C_Timer.After(0.12, function() stepTransfer(state) end)
    elseif tries >= 8 then
        state.index = state.index + 1
        stepTransfer(state)
    else
        C_Timer.After(0.12, function() confirmMove(state, entry, target, tries + 1) end)
    end
end
stepTransfer = function(state)
    if transfer ~= state then return end
    if not canBank() then finishTransfer(state, "Bank geschlossen"); return end
    if combat() or GetCursorInfo() then finishTransfer(state, "Einlagern unterbrochen"); return end
    local last = math.min(#state.entries, state.index + 7)
    while state.index <= last do
        local entry = state.entries[state.index]
        local current = physicalStack(entry.bag, entry.slot)
        if current and not current.locked and current.key == entry.key and current.count == entry.count
            and (not entry.guid or stackGUID(entry.bag, entry.slot) == entry.guid)
            and permittedInBank(entry.bag, entry.slot) then
            local target = bankDestination(state.bags, current)
            if target then
                local picked = pcall(C.PickupContainerItem, entry.bag, entry.slot)
                if GetCursorInfo() == "item" then
                    local contents = physicalStack(target.bag, target.slot)
                    local unchanged = (target.count == 0 and contents == nil)
                        or (contents and not contents.locked and contents.key == entry.key and contents.count == target.count)
                    local placed = picked and unchanged and canBank() and pcall(C.PickupContainerItem, target.bag, target.slot)
                    -- A merge may leave a remainder on the cursor. Return it to the source slot.
                    if GetCursorInfo() == "item" then ClearCursor() end
                    if placed then
                        C_Timer.After(0.12, function() confirmMove(state, entry, target, 1) end)
                        return
                    end
                end
            end
        end
        state.index = state.index + 1
    end
    if state.entries[state.index] then
        C_Timer.After(0, function() stepTransfer(state) end)
    else
        finishTransfer(state, state.moved < state.total and "Rest blieb in den Taschen" or nil)
    end
end
depositCategory = function(key)
    if transfer or not canDeposit() or not window:IsShown() or combat() then return end
    if GetCursorInfo() then transferMessage("Leere zuerst den Mauszeiger."); return end
    refreshView(inventory)
    local state = { entries = {}, index = 1, total = 0, moved = 0, bags = bankContainers() }
    for bag = 0, lastBag() do
        for slot = 1, readable(C.GetContainerNumSlots(bag)) or 0 do
            local group = inventory.groupsBySlot[bag .. ":" .. slot]
            if group and inventory.Category(group.item) == key then
                local item = physicalStack(bag, slot)
                if item then
                    item.bag, item.slot, item.guid = bag, slot, stackGUID(bag, slot)
                    state.entries[#state.entries + 1] = item
                    state.total = state.total + item.count
                end
            end
        end
    end
    if state.total == 0 then return end
    transfer = state
    transferMessage(("Einlagern … 0 / %d Stück"):format(state.total))
    categorize(inventory, inventory.filtered)
    layout(inventory)
    stepTransfer(state)
end
local function createWindow(view)
    local isBank, settings = view.isBank, view.settings
    local f = CreateFrame("Frame", isBank and "PaulchenQoLBank" or "PaulchenQoLInventory", UIParent, "BackdropTemplate")
    view.window = f
    if not isBank then window = f end
    f:SetSize(718, 678)
    f:SetFrameStrata(isBank and "DIALOG" or "HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    style.Panel(f, style.background)
    if type(settings.x) == "number" and type(settings.y) == "number" then
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", settings.x, settings.y)
    else
        local native = isBank and BankFrame
        local frames = isBank and Bagnon and Bagnon.Frames
        local bagnonBank = frames and frames.Get and frames:Get("bank")
        if bagnonBank and bagnonBank:IsVisible() then native = bagnonBank end
        if native and native:IsVisible() then f:SetPoint("TOPLEFT", native, "TOPLEFT")
        else f:SetPoint("CENTER") end
    end
    local title = CreateFrame("Frame", nil, f)
    title:SetPoint("TOPLEFT"); title:SetSize(420, 42)
    title:EnableMouse(true); title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() f:StartMoving() end)
    title:SetScript("OnDragStop", function()
        f:StopMovingOrSizing(); settings.x, settings.y = f:GetCenter()
    end)
    style.Label(title, isBank and "Paulchens Bank" or "Paulchens Taschen", 18, -9, 390, 28, "GameFontNormalLarge", style.gold)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function()
        f:Hide()
        if isBank and canBank() then
            local closeBank = C_Bank and C_Bank.CloseBankFrame or CloseBankFrame
            if closeBank then closeBank() end
        end
    end)
    local original = style.TextButton(f)
    original:SetSize(130, 25); original:SetPoint("TOPRIGHT", -42, -9)
    original:SetText(isBank and "Standardbank" or "Standardtaschen")
    original:SetScript("OnClick", function()
        if isBank then f:Hide(); return end
        settings.enabled = false; pendingAction = nil; f:Hide()
        if OpenAllBags then OpenAllBags() end
        print("Paulchen: Standardtaschen aktiv. /ptaschen aktiviert die Liste wieder.")
    end)
    if isBank then
        f.bagTab = categoryButton(f, "Taschen", 430, -9, 108, function() inventory.Show() end)
    else
        f.bankTab = categoryButton(f, "Bank", 430, -9, 108, function() openBank() end)
        f.bankTab:Hide()
    end
    local search = style.EditBox(f)
    search:SetPoint("TOPLEFT", 18, -48); search:SetSize(420, 28)
    local prompt = style.Label(search, "Name, Gegenstandsart oder ID suchen", 8, 0, 400, 28, "GameFontHighlightSmall", style.muted)
    search:SetScript("OnTextChanged", function(self)
        view.query, view.offset = self:GetText(), 0
        view.searchCollapsed = {}
        prompt:SetShown(view.query == ""); refreshView(view)
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
        settings.hideQuestItems, view.offset = not not self:GetChecked(), 0
        refreshView(view)
    end)
    f.hideQuestItems = hideQuest
    if not isBank then
        f.categories = categoryButton(f, "Kategorien", 550, -82, 136, function()
            if markMenu then markMenu:Hide() end
            categoryEditor = categoryEditor or createCategoryEditor()
            categoryEditor:SetShown(not categoryEditor:IsShown())
        end)
    end
    f.headers = {}
    for _, col in ipairs(columns) do
        local key = col[1]
        local b = style.TextButton(f)
        b:SetPoint("TOPLEFT", col[3], -119); b:SetSize(col[4] - 4, 25); b:SetText(col[2])
        b:SetScript("OnClick", function()
            if settings.sort == key then settings.ascending = not settings.ascending
            else settings.ascending = key == "name" or key == "bag" end
            settings.sort, view.offset = key, 0
            refreshView(view)
        end)
        f.headers[key] = b
    end
    local slider = CreateFrame("Slider", nil, f)
    slider:SetPoint("TOPRIGHT", -12, -152); slider:SetSize(14, rowHeight * rowCount)
    slider:SetOrientation("VERTICAL"); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        if value ~= view.offset then view.offset = value; layout(view) end
    end)
    f.slider = slider
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) view.offset = view.offset - delta * 3; layout(view) end)
    f.status = style.Label(f, "", 18, -608, 650, 20, "GameFontHighlightSmall", style.gold)
    local actions = isBank and "Rechtsklick aufs Symbol: Stapel auslagern · Ziehen: Stapel verschieben"
        or "Aktionen am Symbol betreffen einen Stapel: benutzen / verkaufen / verschieben"
    f.transferStatus = style.Label(f, actions, 18, -632, 680, 18, "GameFontHighlightSmall", style.muted)
    f.defaultActions = actions
    if bank.transferMessage then f.transferStatus:SetText(bank.transferMessage) end
    style.Label(f, "Zeile rechtsklicken: vormerken · Shift-Klick am Symbol: verlinken / Stapel teilen", 18, -652, 680, 18, "GameFontHighlightSmall", style.muted)
    f.noItems = style.Label(f, "Keine passenden Gegenstände.", 18, -183, 660, 30, "GameFontHighlight", style.muted)
    f:SetScript("OnShow", function() refreshView(view) end)
    f:SetScript("OnHide", function()
        if markMenu and markMenu:IsShown() and markMenu.ownerRow.view == view then markMenu:Hide() end
        if not isBank and categoryEditor then categoryEditor:Hide() end
    end)
    f:Hide()
    UISpecialFrames[#UISpecialFrames + 1] = f:GetName()
    -- Pre-create slot identities before combat; displaying the window is safe later.
    if not isBank then
        for bag = 0, lastBag() do
            for slot = 1, readable(C.GetContainerNumSlots(bag)) or 0 do createSlot(view, bag, slot) end
        end
    end
end
openBank = function()
    if not canBank() then return end
    pendingAction = nil
    if not bank.window then createWindow(bank) end
    window:Hide()
    if bank.window:IsShown() then refreshView(bank) else bank.window:Show() end
end
function inventory.Open()
    if not window then return end
    if bank.window then bank.window:Hide() end
    hideOtherBags()
    if window:IsShown() then refreshView(inventory) else window:Show() end
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
        elseif not (bank.window and bank.window:IsShown()) then inventory.Open() end
    end)
end
local function initializeViewSettings(view, config)
    view.settings = config
    if type(config.hideQuestItems) ~= "boolean" then config.hideQuestItems = true end
    if type(config.collapsed) ~= "table" then config.collapsed = {} end
    local valid = false
    for _, col in ipairs(columns) do if config.sort == col[1] then valid = true end end
    if not valid then config.sort, config.ascending = "name", true end
    if type(config.ascending) ~= "boolean" then config.ascending = true end
end
local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED",
    "GET_ITEM_INFO_RECEIVED", "QUEST_LOG_UPDATE", "PLAYER_MONEY", "PLAYER_REGEN_ENABLED", "MERCHANT_SHOW", "MERCHANT_CLOSED",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BANK_TABS_CHANGED", "PLAYERBANKSLOTS_CHANGED" }) do
    app.RegisterSupported(events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_MONEY" then updateMoney(inventory); updateMoney(bank); return end
    if event == "PLAYER_LOGIN" then
        if not C or not ContainerFrameItemButtonMixin then return end
        local db = app.Settings()
        if type(db.inventory) ~= "table" then db.inventory = {} end
        settings = db.inventory
        if settings.enabled == nil then settings.enabled = true end
        if type(settings.markCategories) ~= "table" then settings.markCategories = {} end
        if type(settings.bank) ~= "table" then settings.bank = {} end
        initializeViewSettings(inventory, settings)
        initializeViewSettings(bank, settings.bank)
        loadMarkCategories()
        createWindow(inventory)
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
    if not window then return end
    if event == "BANKFRAME_OPENED" then
        if bank.atBank then return end
        bank.atBank = true
        bank.transferMessage = nil
        transferMessage()
        C_Timer.After(0, function()
            window.bankTab:SetShown(canBank())
            openBank()
        end)
        return
    elseif event == "BANKFRAME_CLOSED" then
        bank.atBank = false
        if transfer then finishTransfer(transfer, "Bank geschlossen") end
        window.bankTab:Hide()
        if bank.window then bank.window:Hide() end
    end
    if (not window:IsShown() and not (bank.window and bank.window:IsShown())) or refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.1, function() refreshQueued = false; inventory.Refresh() end)
end)
