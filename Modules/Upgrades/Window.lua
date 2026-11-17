local _, suite = ...
local app = suite.upgrades
if not app then return end
local style = suite.style
local width, height, rowHeight, rowCount = 910, 628, 32, 13
local tableMargin, maxTableWidth = 53, 1400
local tableLeft, tableTop, headerHeight = 17, -137, 25
local tableHeight = headerHeight + rowCount * rowHeight
local GOLD, MUTED, TEXT, GREEN = style.gold, style.muted, style.cream, style.green
local columns = {
    { key = "name", text = "Gegenstand", w = 214 },
    { key = "slot", text = "Slot", w = 100 },
    { key = "source", text = "Quelle", w = 220 },
    { key = "new", text = "Punkte", w = 75, numeric = true },
    { key = "delta", text = "+ Punkte", w = 75, numeric = true },
    { key = "pct", text = "+ %", w = 78, numeric = true },
    { key = "effort", text = "Aufwand", w = 95, numeric = true },
    { key = "itemLevel", text = "Itemlevel", option = "Gegenstandsstufe", w = 91 },
    { key = "requiredLevel", text = "Ab Stufe", option = "Benötigte Charakterstufe", w = 88 },
    { key = "str", text = "Stärke", option = "Stärke", w = 72 },
    { key = "agi", text = "Bew.", option = "Beweglichkeit", w = 69 },
    { key = "sta", text = "Ausd.", option = "Ausdauer", w = 69 },
    { key = "int", text = "Int.", option = "Intelligenz", w = 65 },
    { key = "spi", text = "Will.", option = "Willenskraft", w = 65 },
    { key = "armor", text = "Rüstung", option = "Rüstung", w = 85 },
    { key = "ap", text = "AP", option = "Angriffskraft", w = 65 },
    { key = "dps", text = "Waffen-DPS", option = "Waffen-DPS", w = 105, places = 1 },
    { key = "crit", text = "Krit %", option = "Kritische Trefferchance", w = 76, places = 2, percent = true },
    { key = "hit", text = "Treffer %", option = "Trefferchance", w = 88, places = 2, percent = true },
    { key = "hitRating", text = "Trefferw.", option = "Trefferwertung", w = 85 },
    { key = "critRating", text = "Kritwert.", option = "Kritische Trefferwertung", w = 85 },
    { key = "expertise", text = "Waffenk.", option = "Waffenkunde", w = 85 },
    { key = "haste", text = "Tempo", option = "Tempowertung", w = 76 },
    { key = "hastePercent", text = "Tempo %", option = "Angriffstempo (%)", w = 87, places = 2, percent = true },
    { key = "armorPen", text = "Rüst.-DS", option = "Rüstungsdurchschlag", w = 85 },
    { key = "defense", text = "Vert.", option = "Verteidigung", w = 68 },
    { key = "dodge", text = "Ausw. %", option = "Ausweichchance", w = 85, places = 2, percent = true },
    { key = "sp", text = "Zaubersch.", option = "Zauberschaden", w = 95 },
    { key = "heal", text = "Heilbonus", option = "Heilbonus", w = 92 },
}
local sources = {
    { "all", "Alle Quellen" }, { "quest", "Quests" }, { "boe", "BoE / Handel" },
    { "dungeon", "Instanzen" }, { "raid", "Raids" }, { "drop", "Sonstige Drops" }, { "vendor", "Händler" },
    { "craft", "Herstellung" },
    { "auction", "Auktionshaus · gescannt" },
}
local qualities = { { 2, "Grün", { 0.38, 0.85, 0.38 } }, { 3, "Blau", { 0.34, 0.67, 1 } }, { 4, "Lila", { 0.77, 0.54, 1 } } }
local slots = { { 0, "Alle Slots" } }
for _, slot in ipairs(app.slots) do slots[#slots + 1] = slot end
local automatic = "auto"

local window, db, scan, finished
local generation, refreshPending = 0, false
local plannedLevel
local scanFailure, displayFailure
local display, offset = {}, 0
local extraColumns = {}
local search = ""

local function searchLevel()
    return math.max(Polestar.Gear.PlayerLevel(), plannedLevel or 0)
end

local function matchesSearchLevel(current)
    return current.level == searchLevel() and current.playerLevel == Polestar.Gear.PlayerLevel()
end

local function instanceSelection()
    local current = scan or finished
    return app.CurrentInstance(current and current.atlas)
end

local function instanceCaption()
    if db.instanceSelection == automatic then
        local _, name = instanceSelection()
        return name and ("Aktuell · " .. name) or "Automatisch · Alle"
    end
    return db.instanceSelection ~= "" and db.instanceSelection or "Alle Instanzen & Raids"
end

local function label(parent, font, color, x, y, w, h, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetSize(w, h)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    fs:SetTextColor(unpack(color))
    return fs
end

local function number(n, places)
    if type(n) ~= "number" then return "–" end
    return (("%." .. places .. "f"):format(n):gsub("%.", ","))
end

local function sourceTitle(source)
    return app.sourceNames[source.kind] .. " · " .. source.title
end

local function auctionPrice(source)
    if GetCoinTextureString then return GetCoinTextureString(source.price) end
    return ("%d G %02d S %02d K"):format(math.floor(source.price / 10000), math.floor(source.price / 100) % 100, source.price % 100)
end

local function isAuction(source)
    return source.kind == "auction" or source.kind == "boe"
end

local function rowAction(entry)
    if isAuction(entry.source) then return "auction" end
    if entry.source.quest then return "quest", entry.source end
    local auction
    for _, source in ipairs(entry.item.sources) do
        if source.quest then return "quest", source end
        if isAuction(source) then auction = "auction" end
    end
    return auction
end

local function startQuestRoute(source)
    local lookup = Polestar.Lookup
    local message
    if Polestar.Compat.IsQuestCompleted(source.quest) then
        message = "Diese Quest ist bereits abgeschlossen."
    elseif lookup and lookup.Guide then
        local ok, guide, reason = pcall(lookup.Guide, "quest", source.quest)
        if ok and guide then
            Polestar.Set("ui.shown", true)
            suite.CloseDashboard("upgrades")
            return
        end
        if reason == "tabs" then
            message = "Schließe einen Polestar-Reiter, um die Route zu öffnen."
        elseif reason == "disabled" then
            message = "Aktiviere die Suche in den Polestar-Einstellungen."
        end
    end
    print("Paulchen Upgrades · " .. (message or ("Polestar hat keine Route für „" .. source.title .. "“ gefunden.")))
end

local function searchAuctionHouse(item)
    local auction = AuctionHouseFrame
    if not auction or not auction:IsShown() then
        print("Paulchen Upgrades · Öffne das Auktionshaus und klicke das Upgrade erneut mit der rechten Maustaste an.")
        return
    end
    local name = item.link:match("|h%[([^%]]+)%]|h") or item.name
    if not name or name == "" then return end
    local ok = pcall(function()
        auction:GetCategoriesList():SetSelectedCategory(nil)
        auction.SearchBar:SetSearchText(name)
        auction:SendBrowseQuery(name, 0, 0, {})
    end)
    if not ok then
        print("Paulchen Upgrades · Die Suche im Auktionshaus konnte nicht gestartet werden.")
        return
    end
    suite.CloseDashboard("upgrades")
end

local function tip(row)
    local entry = row.entry
    if not entry or (GameTooltip.IsForbidden and GameTooltip:IsForbidden()) then return end
    local item, source = entry.item, entry.source
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
    if not pcall(GameTooltip.SetHyperlink, GameTooltip, item.link) then
        GameTooltip:SetText(item.name, unpack(TEXT))
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Paulchen Upgrades", unpack(GOLD))
    local gain = "+" .. number(item.delta, 2)
    if item.pct then gain = gain .. " Punkte · +" .. number(item.pct, 1) .. " %"
    else gain = gain .. " Punkte" end
    local equipped = item.empty and "Freier Slot" or number(item.old, 2)
    GameTooltip:AddDoubleLine(equipped .. " → " .. number(item.new, 2) .. " Punkte", gain, 0.8, 0.83, 0.88, unpack(GREEN))
    if item.future then GameTooltip:AddLine("Tragbar ab Charakterstufe " .. item.requiredLevel, unpack(GOLD)) end
    local action, quest = rowAction(entry)
    if isAuction(source) then
        if source.kind == "auction" then
            GameTooltip:AddDoubleLine("Sofortkauf pro Stück", auctionPrice(source))
            GameTooltip:AddLine("Erfasst am " .. date("%d.%m. um %H:%M", source.at), unpack(MUTED))
        else
            GameTooltip:AddLine("BoE", unpack(MUTED))
        end
        GameTooltip:AddLine("Rechtsklick · Im Auktionshaus suchen", unpack(GOLD))
        GameTooltip:Show()
        return
    end
    local function addSource(s)
        GameTooltip:AddDoubleLine(sourceTitle(s), s.effort .. "/10", 0.9, 0.92, 0.95, 0.98, 0.81, 0.46)
        local text = s.zone or s.detail
        if s.zone and s.detail then text = s.zone .. " · " .. s.detail end
        if s.pct and s.pct > 0 then
            text = (text and text .. " · " or "") .. number(s.pct, 1) .. " % Dropchance"
        end
        if text then GameTooltip:AddLine(text, unpack(MUTED)) end
    end
    addSource(source)
    for _, alternative in ipairs(item.sources) do
        if alternative ~= source then addSource(alternative) end
    end
    if action == "quest" then
        GameTooltip:AddLine("Rechtsklick · Polestar-Route für " .. quest.title, unpack(GOLD))
    elseif action == "auction" then
        GameTooltip:AddLine("Rechtsklick · Im Auktionshaus suchen", unpack(GOLD))
    end
    GameTooltip:Show()
end

local function renderRows()
    local maxOffset = math.max(0, #display - rowCount)
    offset = math.min(offset, maxOffset)
    window.slider:SetMinMaxValues(0, math.max(1, maxOffset))
    window.slider:SetValue(offset)
    window.slider:SetShown(maxOffset > 0)
    for i, row in ipairs(window.rows) do
        local entry = display[offset + i]
        if row.entry ~= entry and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            local item, source = entry.item, entry.source
            local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
            row.icon:SetTexture(item.icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item.id)) or 134400)
            row.name:SetText(item.future and ("|cffffcf75Ab Stufe " .. item.requiredLevel .. "|r · " .. item.name) or item.name)
            if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(unpack(TEXT)) end
            row.slot:SetText(app.slotNames[item.slot])
            row.source:SetText(sourceTitle(source))
            row.where:SetText(source.price and auctionPrice(source) or source.zone or source.detail
                or (source.pct and source.pct > 0 and number(source.pct, 1) .. " % Dropchance") or "")
            row.new:SetText(number(item.new, 2))
            row.delta:SetText("+" .. number(item.delta, 2))
            row.pct:SetText(item.pct and ("+" .. number(item.pct, 1) .. " %") or "–")
            row.effort:SetText(source.effort .. "/10")
            row.effort:SetTextColor(0.50 + source.effort * 0.047, 0.91 - source.effort * 0.038, 0.50 - source.effort * 0.018)
            for _, col in ipairs(extraColumns) do
                local value = app.ItemColumnValue(item, col.key)
                row[col.key]:SetText(number(value, col.places or 0) .. (value and col.percent and " %" or ""))
            end
        end
    end
end

local function updateAuctionScanButton()
    local scanner = PaulchenAuktionsscan
    local auctions = db.tab == "overview" and db.source == "auction"
    window.auctionScan:SetShown(auctions and scanner and scanner.IsOpen() or false)
end

local function render(reset)
    if reset then offset = 0 end
    local current = scan or finished
    local instances = db.tab == "instances"
    local auctions = not instances and db.source == "auction"
    local instance
    if instances then
        instance = db.instanceSelection
        if instance == automatic then instance = instanceSelection() or "" end
        window.instanceFilter.text:SetText(instanceCaption() .. "  ▾")
    end
    local crafting = not instances and db.source == "craft"
    local sortKey = db.sortKey == "price" and (auctions and "price" or "effort") or db.sortKey
    display = app.VisibleRows(current and current.rows or {}, db.slot, db.source, search, sortKey, db.ascending,
        instance, {
            quality = db.quality, profession = crafting and db.profession ~= "" and db.profession or nil,
            maxRequiredLevel = searchLevel(),
        })
    window.sourceFilter:SetShown(not instances)
    window.instanceFilter:SetShown(instances)
    window.professionFilter:SetShown(crafting)
    updateAuctionScanButton()
    style.SetButtonState(window.overviewTab, not instances)
    style.SetButtonState(window.instancesTab, instances)
    window.overviewTab.text:SetTextColor(unpack(instances and MUTED or GOLD))
    window.instancesTab.text:SetTextColor(unpack(instances and GOLD or MUTED))
    local alerts = app.LootAlertsEnabled()
    style.SetButtonState(window.lootToggle, alerts)
    window.lootToggle.text:SetText(alerts and "Loot-Alarm: An" or "Loot-Alarm: Aus")
    window.lootToggle.text:SetTextColor(unpack(alerts and GREEN or MUTED))
    local status
    if scan then
        status = ("Suche läuft · %d / %d Gegenstände geprüft"):format(math.min(scan.cursor - 1, #scan.ids), #scan.ids)
        if scan.count > 0 then status = status .. (" · %d Itemdaten offen"):format(scan.count) end
        if scan.errors > 0 then status = status .. (" · %d Datenfehler"):format(scan.errors) end
    elseif scanFailure then
        status = "Suche abgebrochen · Details mit /pu diagnose"
    elseif refreshPending then
        status = "Suche wird nach dem Kampf aktualisiert."
    elseif finished then
        status = instances and ("%d Instanz-Upgrades"):format(#display) or ("%d / %d Upgrades"):format(#display, #finished.rows)
        if not finished.atlas.loaded then status = status .. " · AtlasLoot-Instanzdaten fehlen" end
        if not finished.itemDBLoaded then status = status .. " · Polestar-Itemdaten fehlen" end
        if not finished.codexLoaded then status = status .. " · Polestar-Codex fehlt" end
        if not finished.questDBLoaded then status = status .. " · Questvoraussetzungen teilweise unbekannt" end
        if finished.unavailable > 0 then status = status .. (" · %d ohne vollständige Itemdaten"):format(finished.unavailable) end
        if finished.errors > 0 then status = status .. (" · %d Datenfehler"):format(finished.errors) end
    else
        status = "Daten werden vorbereitet."
    end
    if auctions and current and current.auctionAt then
        status = status .. " · AH-Stand " .. date("%d.%m. %H:%M", current.auctionAt)
    end
    window.status:SetText(status)
    window.profile:SetText(current and ("Polestar · " .. current.profile .. "   |") or "Polestar   |")
    window.profile:SetWidth(math.min(260, window.profile:GetStringWidth() + 2))
    if not window.levelInput:HasFocus() then window.levelInput:SetText(tostring(searchLevel())) end
    window.autoLevel:SetShown(searchLevel() > Polestar.Gear.PlayerLevel())
    window.empty:SetShown(#display == 0 and not scan and not refreshPending and not scanFailure)
    local empty = finished and #finished.rows > 0 and "Keine Treffer für diese Filter." or "Keine erreichbaren Upgrades in den geladenen Daten."
    if instances and type(instance) == "table" and db.slot == 0 and search == "" then
        empty = "Für die aktuelle Instanz sind keine erreichbaren Boss-Upgrades erfasst."
    elseif auctions then
        if not PaulchenAuktionsscan then
            empty = "Aktiviere Paulchen Auktionsscan in der Addon-Liste."
        elseif not current or not current.auctionAt then
            empty = "Starte am Auktionshaus einen Scan mit /pah. Klicke danach auf „Aktualisieren“."
        else
            empty = "Im gespeicherten AH-Stand gibt es keine Upgrades für diese Filter."
        end
    end
    window.empty:SetText(empty)
    for _, col in ipairs(columns) do
        local key = auctions and col.key == "source" and "price" or col.key
        local arrow = key == sortKey and (db.ascending and " ▲" or " ▼") or ""
        local title = auctions and col.key == "source" and "Sofortkauf"
            or instances and col.key == "source" and "Boss / Instanz" or col.text
        local header = window.headers[col.key]
        style.SetButtonState(header, key == sortKey)
        header.text:SetText(title .. arrow)
        header.text:SetTextColor(unpack(key == sortKey and GOLD or MUTED))
    end
    renderRows()
end

local function draw(reset)
    if not window or not window:IsVisible() then return end
    local ok, err = pcall(render, reset)
    if not ok then
        displayFailure = tostring(err)
        window.status:SetText("Anzeigefehler · Details mit /pu diagnose")
    end
end

local function refresh()
    if InCombatLockdown() then
        refreshPending = true
        draw()
        return
    end
    generation = generation + 1
    local token = generation
    refreshPending = false
    scanFailure, displayFailure = nil, nil
    local ok, result = pcall(app.NewScan, searchLevel())
    if not ok then
        scan, scanFailure = nil, tostring(result)
        draw()
        return
    end
    scan = result
    local lastDraw
    local function step()
        if token ~= generation then return end
        local now = GetTime()
        local worked, complete = pcall(app.ScanStep, scan, now)
        if not worked then
            finished, scan, scanFailure = scan, nil, tostring(complete)
            draw()
            return
        end
        if complete then
            finished, scan = scan, nil
            draw()
            return
        end
        C_Timer.After(0.025, step)
        if not lastDraw or now - lastDraw >= 0.25 then
            draw()
            lastDraw = now
        end
    end
    C_Timer.After(0.01, step)
    draw(true)
end

local function setSearchLevel(level)
    plannedLevel = level and level > Polestar.Gear.PlayerLevel() and level or nil
    local current = scan or finished
    if not current or not matchesSearchLevel(current) then
        refresh()
    else
        draw()
    end
end

local function button(parent, caption, x, y, w, h)
    local b = style.Button(parent)
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(w, h)
    b.text = label(b, "GameFontHighlightSmall", TEXT, 7, 0, w - 14, h, "CENTER")
    b.text:SetText(caption)
    return b
end

local function dropdown(parent, options, key, x, w, currentLabel, y)
    local function caption()
        if currentLabel then return currentLabel() .. "  ▾" end
        for _, option in ipairs(options) do
            if option[1] == db[key] then return option[2] .. "  ▾" end
        end
    end
    local b = button(parent, caption(), x, y or -69, w, 27)
    b:SetScript("OnClick", function(self)
        MenuUtil.CreateContextMenu(self, function(_, menu)
            local choices = type(options) == "function" and options() or options
            if #choices > 14 and menu.SetScrollMode then menu:SetScrollMode(390) end
            for _, option in ipairs(choices) do
                local value, text = option[1], option[2]
                menu:CreateRadio(text, function() return db[key] == value end, function()
                    db[key] = value
                    b.text:SetText(caption())
                    draw(true)
                end)
            end
        end)
    end)
    return b
end

local function makeRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", 0, -headerHeight - (index - 1) * rowHeight)
    row:SetHeight(rowHeight - 1)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    style.Row(row, index)
    row:SetHighlightTexture(style.Fill(row, "HIGHLIGHT", 0.90, 0.62, 0.32, 0.20))
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(23, 23)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    for _, col in ipairs(columns) do
        local padding = col.key == "name" and 34 or 5
        local w = col.w - padding - 5
        local isSource = col.key == "source"
        row[col.key] = label(row, col.key == "name" and "GameFontHighlight" or "GameFontHighlightSmall",
            (col.key == "delta" or col.key == "pct") and GREEN or TEXT, padding, isSource and -2 or 0, w, isSource and 15 or 31,
            (col.numeric or col.option) and "RIGHT" or "LEFT")
        if isSource then row.where = label(row, "GameFontHighlightSmall", MUTED, padding, -16, w, 13) end
    end
    row:SetScript("OnEnter", tip)
    row:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    row:SetScript("OnClick", function(self, mouseButton)
        if not self.entry then return end
        if mouseButton == "RightButton" then
            local action, quest = rowAction(self.entry)
            if action == "auction" then
                searchAuctionHouse(self.entry.item)
            elseif action == "quest" then
                startQuestRoute(quest)
            end
        elseif mouseButton == "LeftButton" and IsShiftKeyDown() then
            ChatEdit_InsertLink(self.entry.item.link)
        end
    end)
    return row
end

local function layoutColumns(f, revealKey)
    local total, revealStart, revealEnd = 0, nil, nil
    local previousScroll = f.viewport:GetHorizontalScroll() or 0
    extraColumns = {}
    for _, col in ipairs(columns) do
        local key = col.key
        local visible = not col.option or db.columns[key] == true
        local header = f.headers[key]
        header:SetShown(visible)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", total, 0)
        for _, row in ipairs(f.rows) do
            local cell = row[key]
            cell:SetShown(visible)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", total + (key == "name" and 34 or 5), key == "source" and -2 or 0)
            if key == "source" then
                row.where:ClearAllPoints()
                row.where:SetPoint("TOPLEFT", total + 5, -16)
            end
        end
        if visible then
            if key == revealKey then revealStart, revealEnd = total, total + col.w end
            total = total + col.w
            if col.option then extraColumns[#extraColumns + 1] = col end
        end
    end
    local scale = suite.DashboardScale(width, height + 17)
    local available = math.floor((UIParent:GetWidth() - 20) / scale) - tableMargin
    local view = math.min(total, math.max(width - tableMargin, math.min(maxTableWidth, available)))
    local overflow = total - view
    local footerShift = overflow > 0 and 17 or 0
    f:SetSize(view + tableMargin, height + footerShift)
    f.viewport:SetWidth(view)
    f.tableBody:SetWidth(total)
    for _, row in ipairs(f.rows) do row:SetWidth(total) end
    f.viewport:UpdateScrollChildRect()
    f.slider:ClearAllPoints()
    f.slider:SetPoint("TOPLEFT", tableLeft + view + 4, -163)
    f.horizontal:SetWidth(view)
    f.horizontal:SetMinMaxValues(0, math.max(1, overflow))
    local scroll = previousScroll
    if revealEnd then scroll = math.max(revealEnd - view, math.min(scroll, revealStart)) end
    scroll = math.max(0, math.min(overflow, scroll))
    f.horizontal:SetValue(scroll)
    f.viewport:SetHorizontalScroll(scroll)
    f.horizontal:SetShown(overflow > 0)
    f.empty:SetWidth(view)
    f.status:SetWidth(view + 13)
    f.status:ClearAllPoints()
    f.status:SetPoint("TOPLEFT", tableLeft, -583 - footerShift)
    f.hints:ClearAllPoints()
    f.hints:SetPoint("TOPLEFT", tableLeft, -603 - footerShift)
    if f:IsVisible() then suite.LayoutDashboard() end
end

local function createPage(parent)
    PaulchenQoLUpgradesDB = PaulchenQoLUpgradesDB or {}
    db = PaulchenQoLUpgradesDB
    db.minRequiredLevel, db.maxRequiredLevel = nil, nil
    if type(db.quality) ~= "table" then db.quality = {} end
    if type(db.columns) ~= "table" then db.columns = {} end
    local knownProfession
    for _, choice in ipairs(app.professionChoices) do
        if db.profession == choice[1] then knownProfession = true; break end
    end
    if not knownProfession then db.profession = "" end
    if not app.slotNames[db.slot] then db.slot = 0 end
    if not app.sourceNames[db.source] then db.source = "all" end
    if db.tab ~= "instances" then db.tab = "overview" end
    if type(db.instanceSelection) ~= "string" then db.instanceSelection = automatic end
    local validSort = db.sortKey == "price"
    for _, col in ipairs(columns) do
        if col.key == db.sortKey and (not col.option or db.columns[col.key] == true) then validSort = true end
    end
    if not validSort then db.sortKey, db.ascending = "pct", false end

    local f = CreateFrame("Frame", "PaulchenUpgradesFrame", parent)
    window = f
    f:Hide()
    f:EnableMouse(true)
    local titlebar = CreateFrame("Frame", nil, f)
    titlebar:SetPoint("TOPLEFT", 1, -1)
    titlebar:SetPoint("TOPRIGHT", -1, -1)
    titlebar:SetHeight(57)
    style.Fill(titlebar, "BACKGROUND", unpack(style.header))
    style.Portrait(titlebar, 42, 10, -7)
    label(titlebar, "GameFontNormalLarge", GOLD, 59, -5, 390, 30):SetText("Paulchen Upgrades")
    f.profile = label(titlebar, "GameFontHighlightSmall", MUTED, 59, -34, 260, 17)
    local levelControl = CreateFrame("Frame", nil, titlebar)
    levelControl:SetSize(120, 22)
    levelControl:SetPoint("LEFT", f.profile, "RIGHT", 6, 0)
    label(levelControl, "GameFontHighlightSmall", MUTED, 0, 0, 32, 22):SetText("Stufe")
    local levelInput = style.EditBox(levelControl)
    levelInput:SetPoint("LEFT", 33, 0)
    levelInput:SetSize(30, 21)
    levelInput:SetTextInsets(2, 2, 0, 0)
    levelInput:SetJustifyH("CENTER")
    levelInput:SetNumeric(true)
    levelInput:SetMaxLetters(3)
    levelInput:SetText(tostring(searchLevel()))
    levelInput:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    levelInput:SetScript("OnEditFocusLost", function(self)
        if f:IsVisible() then setSearchLevel(tonumber(self:GetText())) end
    end)
    levelInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    levelInput:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(searchLevel()))
        self:ClearFocus()
    end)
    levelInput:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Stufe für die Upgrade-Suche", unpack(GOLD))
        GameTooltip:AddLine("Gib eine höhere Stufe ein, um zukünftige Upgrades zu sehen.", unpack(TEXT))
        GameTooltip:Show()
    end)
    levelInput:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    f.levelInput = levelInput
    f.autoLevel = button(levelControl, "Auto", 68, -1, 46, 20)
    f.autoLevel:SetScript("OnClick", function() setSearchLevel(nil) end)
    f.autoLevel:Hide()
    f.overviewTab = button(titlebar, "Übersicht", 463, -12, 106, 27)
    f.instancesTab = button(titlebar, "Instanzen", 575, -12, 106, 27)
    f.overviewTab:SetScript("OnClick", function() db.tab = "overview"; draw(true) end)
    f.instancesTab:SetScript("OnClick", function() db.tab = "instances"; draw(true) end)
    f.lootToggle = button(titlebar, "", 699, -12, 146, 27)
    f.lootToggle:SetScript("OnClick", function()
        db.lootAlerts = not app.LootAlertsEnabled()
        draw()
    end)
    dropdown(f, slots, "slot", 17, 141)
    f.sourceFilter = dropdown(f, sources, "source", 166, 218)
    f.instanceFilter = dropdown(f, function()
        local current = scan or finished
        local choices = app.InstanceChoices(current and current.rows or {})
        local _, name = instanceSelection()
        table.insert(choices, 1, { automatic, name and ("Automatisch · " .. name) or "Automatisch · Aktuelle Instanz" })
        return choices
    end, "instanceSelection", 166, 218, instanceCaption)
    f.professionFilter = dropdown(f, app.professionChoices, "profession", 17, 210, nil, -103)
    f.auctionScan = button(f, "AH scannen", 17, -103, 141, 27)
    f.auctionScan:SetScript("OnClick", function() PaulchenAuktionsscan.Start() end)

    f.qualityChecks = {}
    for i, entry in ipairs(qualities) do
        local id, name, color = unpack(entry)
        local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 478 + (i - 1) * 83, -103)
        check:SetSize(25, 25)
        check:SetChecked(db.quality[id] ~= false)
        label(check, "GameFontHighlight", color, 27, 0, 54, 25):SetText(name)
        check:SetScript("OnClick", function(self)
            db.quality[id] = not not self:GetChecked()
            draw(true)
        end)
        f.qualityChecks[id] = check
    end
    local box = style.EditBox(f, GameFontHighlight)
    box:SetPoint("TOPLEFT", 392, -69)
    box:SetSize(364, 27)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetMaxLetters(100)
    local placeholder = label(box, "GameFontHighlight", MUTED, 8, 0, 348, 27)
    placeholder:SetText("Gegenstand, Boss oder Ort suchen")
    box:SetScript("OnTextChanged", function(self)
        search = self:GetText()
        placeholder:SetShown(search == "")
        draw(true)
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local reload = button(f, "Aktualisieren", 764, -69, 128, 27)
    reload:SetScript("OnClick", refresh)
    f.columnsMenu = button(f, "Spalten  ▾", 764, -103, 128, 27)
    f.columnsMenu:SetScript("OnClick", function(self)
        MenuUtil.CreateContextMenu(self, function(_, menu)
            if menu.SetScrollMode then menu:SetScrollMode(390) end
            for _, col in ipairs(columns) do
                local key = col.key
                if col.option then
                    menu:CreateCheckbox(col.option, function() return db.columns[key] == true end, function()
                        db.columns[key] = not db.columns[key] or nil
                        if db.sortKey == key and not db.columns[key] then db.sortKey, db.ascending = "pct", false end
                        layoutColumns(f, db.columns[key] and key or nil)
                        draw(true)
                        return MenuResponse and MenuResponse.Refresh
                    end)
                end
            end
        end)
    end)

    f.viewport = CreateFrame("ScrollFrame", nil, f)
    f.viewport:SetPoint("TOPLEFT", tableLeft, tableTop)
    f.viewport:SetSize(width - tableMargin, tableHeight)
    f.tableBody = CreateFrame("Frame", nil, f.viewport)
    f.tableBody:SetSize(width - tableMargin, tableHeight)
    f.viewport:SetScrollChild(f.tableBody)

    f.headers, f.rows = {}, {}
    for _, col in ipairs(columns) do
        local h = button(f.tableBody, col.text, 0, 0, col.w - 1, headerHeight - 1)
        h.text:SetJustifyH((col.numeric or col.option) and "RIGHT" or "LEFT")
        h:SetScript("OnClick", function()
            local key = db.tab == "overview" and db.source == "auction" and col.key == "source" and "price" or col.key
            if db.sortKey == key then
                db.ascending = not db.ascending
            else
                db.sortKey = key
                db.ascending = not (col.numeric or col.option) or col.key == "effort"
            end
            draw(true)
        end)
        if col.option then
            h:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(col.option, unpack(GOLD))
                GameTooltip:Show()
            end)
            h:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
        end
        f.headers[col.key] = h
    end
    f.headers.effort:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Geschätzter Aufwand", unpack(GOLD))
        GameTooltip:AddLine("1 = schnell erreichbar, 10 = sehr aufwendig.", unpack(TEXT))
        GameTooltip:AddLine("Questfortschritt, Gruppenbedarf, Stufenabstand und bekannte Dropchancen zählen mit.", 0.64, 0.69, 0.75, true)
        GameTooltip:AddLine("Bei BoEs dient die Seltenheit als Schätzung für den Handel.", 0.64, 0.69, 0.75, true)
        GameTooltip:Show()
    end)
    f.headers.effort:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    for i = 1, rowCount do f.rows[i] = makeRow(f.tableBody, i) end
    local slider = CreateFrame("Slider", nil, f)
    slider:SetSize(14, rowCount * rowHeight - 2)
    slider:SetOrientation("VERTICAL")
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    slider:GetThumbTexture():SetSize(14, 24)
    style.Fill(slider, "BACKGROUND", unpack(style.track))
    slider:SetScript("OnValueChanged", function(_, value)
        local nextOffset = math.floor(value + 0.5)
        if nextOffset ~= offset then offset = nextOffset; renderRows() end
    end)
    f.slider = slider
    local horizontal = CreateFrame("Slider", nil, f)
    horizontal:SetPoint("TOPLEFT", tableLeft, tableTop - tableHeight - 4)
    horizontal:SetHeight(13)
    horizontal:SetOrientation("HORIZONTAL")
    horizontal:SetValueStep(1)
    horizontal:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    horizontal:GetThumbTexture():SetSize(18, 13)
    style.Fill(horizontal, "BACKGROUND", unpack(style.track))
    horizontal:SetScript("OnValueChanged", function(_, value) f.viewport:SetHorizontalScroll(value) end)
    f.horizontal = horizontal
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta * 3)
        renderRows()
    end)
    f.empty = label(f, "GameFontHighlight", MUTED, 17, -240, 860, 40, "CENTER")
    f.status = label(f, "GameFontHighlightSmall", TEXT, 17, -583, 870, 17)
    f.hints = label(f, "GameFontHighlightSmall", MUTED, 17, -603, 870, 16)
    f.hints:SetText("Aufwand · 1 leicht, 10 hoch    |    Rechtsklick · AH-Suche oder Quest-Route    |    Umschalt-Klick · Item verlinken")
    layoutColumns(f)

    f:SetScript("OnShow", function()
        layoutColumns(f)
        local current = scan or finished
        if not refreshPending and ((not current and not scanFailure) or (current and not matchesSearchLevel(current))) then
            refresh()
        else
            draw()
        end
    end)
    f:SetScript("OnHide", function()
        box:ClearFocus()
        levelInput:ClearFocus()
    end)
    return f
end

local function toggle(msg)
    if msg and msg:match("^%s*diagnose%s*$") then
        local current = scan or finished
        local err = scanFailure or displayFailure or (current and current.firstError)
        print("Paulchen Upgrades · " .. (err or "Kein Suchfehler aufgezeichnet."))
        return
    end
    suite.ToggleDashboard("upgrades")
end

SLASH_PAULCHENUPGRADES1 = "/paulchenupgrades"
SLASH_PAULCHENUPGRADES2 = "/pu"
SlashCmdList.PAULCHENUPGRADES = toggle

local function createMinimapButton(broker, icons)
    PaulchenQoLUpgradesDB = PaulchenQoLUpgradesDB or {}
    if type(PaulchenQoLUpgradesDB.minimap) ~= "table" then
        PaulchenQoLUpgradesDB.minimap = { minimapPos = 115 }
    end
    local launcher = broker:NewDataObject("PaulchenUpgrades", {
        type = "launcher",
        text = "Paulchen Upgrades",
        icon = "Interface\\Icons\\INV_Misc_Bag_10_Green",
        OnClick = function(_, mouseButton)
            if mouseButton == "LeftButton" then toggle() end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Paulchen Upgrades")
            tooltip:AddLine("Linksklick · Upgrade-Reiter öffnen oder schließen", 1, 1, 1)
            tooltip:AddLine("Ziehen · Position ändern", 0.65, 0.70, 0.75)
        end,
    })
    icons:Register("PaulchenUpgrades", launcher, PaulchenQoLUpgradesDB.minimap)
end

function app.GetPage(parent)
    return window or createPage(parent)
end

function app.Open()
    suite.OpenDashboard("upgrades")
end

function app.UpdateMinimap(shown)
    local broker = LibStub and LibStub("LibDataBroker-1.1", true)
    local icons = broker and LibStub("LibDBIcon-1.0", true)
    if not icons then return end
    local name = "PaulchenUpgrades"
    if icons:IsRegistered(name) then
        if shown and not PaulchenQoLUpgradesDB.minimap.hide then icons:Show(name) else icons:Hide(name) end
    elseif shown then
        createMinimapButton(broker, icons)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event, id, success)
    if event == "PLAYER_LOGIN" then
        app.UpdateMinimap(suite.Profile().moduleIcons)
    elseif event == "PLAYER_LEVEL_UP" then
        C_Timer.After(0, function()
            if window and window:IsVisible() then setSearchLevel(plannedLevel) end
        end)
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        if window and window:IsVisible() then layoutColumns(window) end
    elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
        if window and window:IsVisible() then C_Timer.After(0, updateAuctionScanButton) end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if window and window:IsVisible() and db.tab == "instances" and db.instanceSelection == automatic then
            draw(true)
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        if scan and id and success == false then app.ItemFailed(scan, id) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if refreshPending then refresh() end
    elseif event == "PLAYER_REGEN_DISABLED" and scan then
        generation = generation + 1
        scan, refreshPending = nil, true
        draw()
    end
end)
