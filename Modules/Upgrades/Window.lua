local _, suite = ...
local app = suite.upgrades
if not app then return end
local style = suite.style
local gear = app.gear
local width, height, rowHeight, rowCount = 910, 628, 32, 13
local tableMargin, maxTableWidth = 53, 1400
local tableLeft, tableTop, headerHeight = 17, -137, 25
local tableHeight = headerHeight + rowCount * rowHeight
local GOLD, MUTED, TEXT, GREEN = style.gold, style.muted, style.cream, style.green
-- Native textures avoid missing arrow glyphs in the Forever UI fonts.
local downArrow = " |TInterface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up:12:12:0:0|t"
local upArrow = " |TInterface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up:12:12:0:0|t"
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
    { "all", "Alle Quellen" }, { "bag", "Eigene Taschen" }, { "quest", "Quests" }, { "boe", "BoE / Handel" },
    { "dungeon", "Instanzen" }, { "raid", "Raids" }, { "drop", "Sonstige Drops" }, { "vendor", "Händler" },
    { "craft", "Herstellung" },
    { "auction", "Auktionshaus" },
}
local qualities = { { 2, "Grün", { 0.38, 0.85, 0.38 } }, { 3, "Blau", { 0.34, 0.67, 1 } }, { 4, "Lila", { 0.77, 0.54, 1 } } }
local slots = { { 0, "Alle Slots" } }
for _, slot in ipairs(app.slots) do slots[#slots + 1] = slot end
local automatic = "auto"

local window, db, scan, finished, exportDialog, profileEditor
local choicePanel
local generation = 0
local resultsStale, pausedAt, resumeScan
local plannedLevel
local enteredWorld, waitingForGear, startAfterCombat
local requestToken = 0
local wakeRequestedScan, waitingItemID
local scanFailure, displayFailure
local display, offset = {}, 0
local hoveredRow, renderingRows
local extraColumns = {}
local search = ""

local function searchLevel()
    return math.max(gear.PlayerLevel(), plannedLevel or 0)
end

local function matchesSearchLevel(current)
    return current.level == searchLevel() and current.playerLevel == gear.PlayerLevel()
end

local function instanceSelection()
    local current = scan or finished
    return app.CurrentInstance(current and current.atlas, current and current.journal)
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
    local tag = source.isEstimate and " · [PREIS] " or " · "
    return app.sourceNames[source.kind] .. tag .. source.title
end

local function exportCell(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|[TA].-|[ta]", ""):gsub("|H.-|h(.-)|h", "%1")
        :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%c", " "):match("^%s*(.-)%s*$")
    -- A copied title must stay text when pasted into a spreadsheet.
    return text:match("^[=+@%-]") and "'" .. text or text
end

local function exportNumber(value, places, percent)
    if type(value) ~= "number" then return "" end
    return number(value, places) .. (percent and "%" or "")
end

local function exportResults()
    local headers = { "Gegenstand", "Slot", "Quelle", "Ort / Details", "Preis (Kupfer)", "Dropchance",
        "Punkte", "Zugewinn (Punkte)", "Zugewinn (%)", "Aufwand (1–10)" }
    for _, col in ipairs(extraColumns) do headers[#headers + 1] = col.option end
    headers[#headers + 1] = "Item-ID"
    headers[#headers + 1] = "Item-Link"
    local lines = { table.concat(headers, "\t") }
    for _, entry in ipairs(display) do
        local item, source = entry.item, entry.source
        local details = source.zone and source.detail and (source.zone .. " · " .. source.detail)
            or source.zone or source.detail
        local row = { exportCell(item.name), exportCell(app.slotNames[item.slot]), exportCell(sourceTitle(source)),
            exportCell(details), exportNumber(source.price, 0), exportNumber(source.pct, 1, true),
            exportNumber(item.new, 2), exportNumber(item.delta, 2), exportNumber(item.pct, 1, true),
            exportNumber(source.effort, 0) }
        for _, col in ipairs(extraColumns) do
            row[#row + 1] = exportNumber(app.ItemColumnValue(item, col.key), col.places or 0, col.percent)
        end
        row[#row + 1] = tostring(item.id)
        row[#row + 1] = item.link and (item.link:match("|H(item:[^|]+)|h") or item.link:match("^item:[%d:%-]+$")) or ""
        lines[#lines + 1] = table.concat(row, "\t")
    end
    return table.concat(lines, "\n")
end

local function exportReady()
    return #display > 0 and not scan and not waitingForGear and not resultsStale and not scanFailure and not displayFailure
end

local function auctionPrice(price)
    price = math.floor(price + 0.5)
    if GetCoinTextureString then return GetCoinTextureString(price) end
    return ("%d G %02d S %02d K"):format(math.floor(price / 10000), math.floor(price / 100) % 100, price % 100)
end

local function addPriceEstimate(source)
    local price = source.isEstimate and source.price or source.tsmPrice
    if not price then return end
    GameTooltip:AddDoubleLine("[PREIS] TSM-Schätzpreis pro Stück", auctionPrice(price))
    GameTooltip:AddLine("TSM DBMinBuyout · Verfügbarkeit im Auktionshaus prüfen.", unpack(MUTED))
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
    local lookup = Polestar and Polestar.Lookup
    local compat = Polestar and Polestar.Compat
    local message
    if compat and compat.IsQuestCompleted(source.quest) then
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
    if not message and C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(source.quest)
        and QuestMapFrame_OpenToQuestDetails then
        suite.CloseDashboard("upgrades")
        QuestMapFrame_OpenToQuestDetails(source.quest)
        return
    end
    print("Paulchen Upgrades · " .. (message or ("Kein Wegpunkt für „" .. source.title .. "“ verfügbar.")))
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
    app.showingUpgradeRow = true
    local linked = pcall(GameTooltip.SetHyperlink, GameTooltip, item.link)
    app.showingUpgradeRow = nil
    if not linked then
        GameTooltip:SetText(item.name, unpack(TEXT))
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Paulchen Upgrades · " .. app.ProfileName(), unpack(GOLD))
    local gain = "+" .. number(item.delta, 2)
    if item.pct then gain = gain .. " Punkte · +" .. number(item.pct, 1) .. " %"
    else gain = gain .. " Punkte" end
    local equipped = item.empty and "Freier Slot" or number(item.old, 2)
    GameTooltip:AddDoubleLine(equipped .. " -> " .. number(item.new, 2) .. " Punkte", gain, 0.8, 0.83, 0.88, unpack(GREEN))
    if item.future then GameTooltip:AddLine("Tragbar ab Charakterstufe " .. item.requiredLevel, unpack(GOLD)) end
    local action, quest = rowAction(entry)
    if isAuction(source) then
        if source.kind == "auction" then
            if source.price and not source.isEstimate then
                GameTooltip:AddDoubleLine(source.at and "Sofortkauf pro Stück" or "Preis in der AH-Übersicht", auctionPrice(source.price))
            end
            if source.at then GameTooltip:AddLine("Erfasst am " .. date("%d.%m. um %H:%M", source.at), unpack(MUTED)) end
            addPriceEstimate(source)
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
        addPriceEstimate(s)
    end
    addSource(source)
    for _, alternative in ipairs(item.sources) do
        if alternative ~= source then addSource(alternative) end
    end
    if action == "quest" then
        GameTooltip:AddLine("Rechtsklick · Quest öffnen · " .. quest.title, unpack(GOLD))
    elseif action == "auction" then
        GameTooltip:AddLine("Rechtsklick · Im Auktionshaus suchen", unpack(GOLD))
    end
    GameTooltip:Show()
end

local function renderRows()
    renderingRows = true
    local refreshTooltip
    local maxOffset = math.max(0, #display - rowCount)
    offset = math.min(offset, maxOffset)
    window.slider:SetMinMaxValues(0, math.max(1, maxOffset))
    window.slider:SetValue(offset)
    window.slider:SetShown(maxOffset > 0)
    for i, row in ipairs(window.rows) do
        local entry = display[offset + i]
        local previous = row.entry
        local ownsTooltip = GameTooltip:IsOwned(row)
        local changed = not previous or not entry or previous.item ~= entry.item or previous.source ~= entry.source
        row.entry = entry
        if ownsTooltip then
            if not entry then GameTooltip:Hide()
            elseif changed then refreshTooltip = row end
        end
        row:SetShown(entry ~= nil)
        if entry then
            local item, source = entry.item, entry.source
            local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
            row.icon:SetTexture(item.icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(item.id)) or 134400)
            row.name:SetText(item.future and ("|cffffcf75Ab Stufe " .. item.requiredLevel .. "|r · " .. item.name) or item.name)
            if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(unpack(TEXT)) end
            row.slot:SetText(app.slotNames[item.slot])
            row.source:SetText(sourceTitle(source))
            row.where:SetText(source.price and auctionPrice(source.price) or source.zone or source.detail
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
    renderingRows = false
    if refreshTooltip then tip(refreshTooltip) end
end

local function updateAuctionScanButton()
    local scanner = PaulchenAuktionsscan
    local auctions = db.tab == "overview" and db.source == "auction"
    window.auctionScan:SetShown(auctions and scanner and scanner.IsOpen() or false)
end

local function scanStatus(current)
    local status = ("Suche läuft · %d / %d Gegenstände geprüft"):format(math.min(current.cursor - 1, #current.ids), #current.ids)
    local outstanding = current.count + #current.deferred - current.nextDeferred + 1
    if outstanding > 0 then status = status .. (" · %d Itemdaten offen"):format(outstanding) end
    if current.errors > 0 then status = status .. (" · %d Datenfehler"):format(current.errors) end
    if current.limited then status = status .. " · Nachladen begrenzt" end
    status = status .. (" · %d neu bewertet · %d übernommen"):format(current.compared or 0, current.reused or 0)
    if (current.skippedContent or 0) > 0 then
        status = status .. (" · %d gesperrt übersprungen"):format(current.skippedContent)
    end
    return status
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
        window.instanceFilter.text:SetText(instanceCaption() .. downArrow)
    end
    local crafting = not instances and db.source == "craft"
    local sortKey = db.sortKey == "price" and (auctions and "price" or "effort") or db.sortKey
    -- Search steps may add higher-scoring rows. Keep the displayed items stable
    -- while one is being read; explicit filter/sort changes still apply at once.
    if reset or not (hoveredRow and hoveredRow.entry and GameTooltip:IsOwned(hoveredRow)) then
        display = app.VisibleRows(current and current.rows or {}, db.slot, db.source, search, sortKey, db.ascending,
            instance, {
                quality = db.quality, profession = crafting and db.profession ~= "" and db.profession or nil,
                maxRequiredLevel = searchLevel(),
            })
    end
    window.sourceFilter:SetShown(not instances)
    window.instanceFilter:SetShown(instances)
    window.professionFilter:SetShown(crafting)
    window.contentButton:SetShown(not crafting and not auctions)
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
    if pausedAt then
        status = "Suche pausiert im Kampf."
    elseif startAfterCombat then
        status = "Angeforderte Suche startet nach dem Kampf."
    elseif waitingForGear then
        status = "Warte auf Ausrüstungsdaten."
    elseif scan then
        status = scanStatus(scan)
    elseif scanFailure then
        status = "Suche abgebrochen · Details mit /pu diagnose"
    elseif resultsStale then
        status = "Liste veraltet · Für aktuelle Ergebnisse auf Aktualisieren klicken."
    elseif finished then
        status = instances and ("%d Instanz-Upgrades"):format(#display) or ("%d / %d Upgrades"):format(#display, #finished.rows)
        if instances and not finished.atlas.loaded and not finished.journal.loaded then
            status = status .. " · Keine zusätzlichen Instanzdaten"
        end
        if finished.unavailable > 0 then status = status .. (" · %d ohne vollständige Itemdaten"):format(finished.unavailable) end
        if finished.errors > 0 then status = status .. (" · %d Datenfehler"):format(finished.errors) end
        if finished.limited then status = status .. " · Teilergebnis, mit Aktualisieren weiterladen" end
        status = status .. (" · %d neu bewertet · %d übernommen"):format(finished.compared or 0, finished.reused or 0)
        if (finished.skippedContent or 0) > 0 then
            status = status .. (" · %d gesperrt übersprungen"):format(finished.skippedContent)
        end
    else
        status = "Auf Aktualisieren klicken, um Upgrades zu suchen."
    end
    if auctions and current and current.auctionAt then
        status = status .. " · AH-Stand " .. date("%d.%m. %H:%M", current.auctionAt)
    end
    window.status:SetText(status)
    local canExport = exportReady()
    window.exportButton:SetEnabled(canExport)
    window.exportButton.text:SetTextColor(unpack(canExport and TEXT or MUTED))
    window.profile:SetText("Profil · " .. (current and current.profile or app.ProfileName()) .. "   |")
    window.profile:SetWidth(math.min(260, window.profile:GetStringWidth() + 2))
    if not window.levelInput:HasFocus() then window.levelInput:SetText(tostring(searchLevel())) end
    window.autoLevel:SetShown(searchLevel() > gear.PlayerLevel())
    window.empty:SetShown(#display == 0 and finished ~= nil and not scan and not waitingForGear
        and not resultsStale and not scanFailure)
    local empty = finished and #finished.rows > 0 and "Keine Treffer für diese Filter." or "Keine erreichbaren Upgrades in den geladenen Daten."
    if finished and #finished.rows == 0 and finished.unavailable > 0 then
        empty = "Noch keine Upgrades gefunden. Itemdaten fehlen; mit Aktualisieren weiterladen."
    end
    if instances and type(instance) == "table" and db.slot == 0 and search == "" then
        empty = "Für die aktuelle Instanz sind keine erreichbaren Boss-Upgrades erfasst."
    elseif auctions then
        empty = current and current.auctionAt and "Keine AH-Angebote oder TSM-Preise für diese Filter."
            or "Keine AH-Angebote oder TSM-Preise gefunden. Lade Treffer im AH und klicke auf „Aktualisieren“."
    end
    window.empty:SetText(empty)
    for _, col in ipairs(columns) do
        local key = auctions and col.key == "source" and "price" or col.key
        local arrow = key == sortKey and (db.ascending and upArrow or downArrow) or ""
        local title = auctions and col.key == "source" and "AH-Preis"
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
    displayFailure = nil
    local ok, err = pcall(render, reset)
    if not ok then
        renderingRows = false
        displayFailure = tostring(err)
        window.exportButton:SetEnabled(false)
        window.exportButton.text:SetTextColor(unpack(MUTED))
        window.status:SetText("Anzeigefehler · Details mit /pu diagnose")
    end
end

local function startScan()
    pausedAt, resumeScan = nil, nil
    generation = generation + 1
    local token = generation
    scanFailure, displayFailure = nil, nil
    local ok, result = pcall(app.NewScan, searchLevel())
    if not ok then
        scan, scanFailure = nil, tostring(result)
        draw()
        return
    end
    resultsStale = false
    scan = result
    local lastDraw, lastRows, stepQueued
    local queueStep
    local function step()
        if InCombatLockdown() then pausedAt = pausedAt or GetTime() end
        if pausedAt then return end
        local now = GetTime()
        local worked, complete = pcall(app.ScanStep, scan, now)
        if not worked then
            finished, scan, scanFailure = scan, nil, tostring(complete)
            resumeScan = nil
            draw()
            return
        end
        if complete then
            finished, scan = scan, nil
            resumeScan = nil
            draw()
            return
        end
        queueStep(0.05)
        if not lastDraw or now - lastDraw >= 0.5 then
            if lastRows ~= #scan.rows then draw(); lastRows = #scan.rows
            elseif window and window:IsVisible() then window.status:SetText(scanStatus(scan)) end
            lastDraw = now
        end
    end
    queueStep = function(delay)
        if stepQueued then return end
        stepQueued = true
        C_Timer.After(delay or 0.01, function()
            if token ~= generation then return end
            stepQueued = false
            step()
        end)
    end
    resumeScan = queueStep
    queueStep()
    draw()
end

local function equipmentReady()
    local player = gear.GetPlayer()
    if not player.class or not player.level or player.level < 1 then return false end
    for slot = 1, 18 do
        if slot ~= 4 then
            local id = GetInventoryItemID and suite.Readable(GetInventoryItemID("player", slot))
            local link = gear.Client.InventoryLink(slot)
            if (id and id > 0 and not link) or (link and not gear.GetItemInfo(link)) then
                local itemID = gear.ItemID(link) or id
                if itemID and C_Item and C_Item.RequestLoadItemDataByID then
                    C_Item.RequestLoadItemDataByID(itemID)
                end
                return false, itemID
            end
        end
    end
    return true
end

function app.CheckUpgrades()
    requestToken = requestToken + 1
    local token, attempts = requestToken, 0
    local checkQueued
    waitingForGear, startAfterCombat, waitingItemID = true, false, nil
    local queueCheck
    local function check()
        if InCombatLockdown() then
            startAfterCombat = true
            draw()
            return
        end
        local ok, ready, itemID = pcall(equipmentReady)
        if not ok then
            waitingForGear, scanFailure = false, "Ausrüstungsdaten: " .. tostring(ready)
            wakeRequestedScan, waitingItemID = nil, nil
            draw()
            return
        end
        if not ready then
            waitingItemID = itemID
            attempts = attempts + 1
            if attempts == 1 then draw() end
            if attempts < 20 then queueCheck(0.5) end
            return
        end
        waitingForGear = false
        wakeRequestedScan, waitingItemID = nil, nil
        startScan()
    end
    queueCheck = function(delay)
        if checkQueued then return end
        checkQueued = true
        C_Timer.After(delay, function()
            if token ~= requestToken then return end
            checkQueued = false
            check()
        end)
    end
    wakeRequestedScan = queueCheck
    queueCheck(0.1)
end

local function invalidateResults(cancelScan)
    if not scan and not finished then return end
    local cancelled = cancelScan and scan ~= nil
    if cancelled then
        generation = generation + 1
        scan, pausedAt, resumeScan = nil, nil, nil
    end
    if resultsStale and not cancelled then return end
    resultsStale = true
    draw()
end

function app.OverviewUpgrade()
    local current = scan or finished
    local best
    for _, row in ipairs(current and current.rows or {}) do
        if not row.future and (row.requiredLevel or 0) <= gear.PlayerLevel() then
            local score = row.empty and math.huge or row.pct or 0
            local previous = best and (best.empty and math.huge or best.pct or 0)
            if not best or score > previous or score == previous and row.delta > best.delta then best = row end
        end
    end
    return { best = best, profile = current and current.profile or app.ProfileName(),
        state = (startAfterCombat or pausedAt) and "combat" or waitingForGear and "waiting" or scan and "scanning"
            or scanFailure and "error" or resultsStale and "stale" or finished and "ready" or "idle",
        error = scanFailure, partial = current and ((current.errors or 0) > 0 or (current.unavailable or 0) > 0) }
end

local function setSearchLevel(level)
    plannedLevel = level and level > gear.PlayerLevel() and level or nil
    local current = scan or finished
    if current and not matchesSearchLevel(current) then
        invalidateResults(true)
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

-- Long menus use addon-owned buttons. Blizzard's scrollable menu closes by
-- updating its ScrollBox, which can reject protected dimensions in Forever.
local choicesPerColumn, choiceRowHeight = 12, 25
local function layoutChoices(panel)
    local perPage = choicesPerColumn * (panel.multiple and 2 or 1)
    local last = math.min(#panel.choices, panel.page * perPage)
    local first = (panel.page - 1) * perPage + 1
    local rows = math.min(choicesPerColumn, last - first + 1)
    for index, control in ipairs(panel.buttons) do
        local choice = index <= perPage and first + index - 1 <= last and panel.choices[first + index - 1]
        control:SetShown(not not choice)
        if choice then
            local selected = panel.isSelected(choice[1])
            control.value = choice[1]
            control.tick:SetShown(selected)
            control.text:SetText(choice[2])
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", 8 + math.floor((index - 1) / choicesPerColumn) * 258,
                -34 - ((index - 1) % choicesPerColumn) * choiceRowHeight)
            style.SetButtonState(control, selected)
        end
    end
    local pages = math.ceil(#panel.choices / perPage)
    local footer = rows * choiceRowHeight + 39
    panel.previous:ClearAllPoints()
    panel.next:ClearAllPoints()
    panel.pageText:ClearAllPoints()
    panel.previous:SetPoint("TOPLEFT", 8, -footer)
    panel.next:SetPoint("TOPLEFT", 197, -footer)
    panel.pageText:SetPoint("TOPLEFT", 90, -footer)
    panel.previous:SetEnabled(panel.page > 1)
    panel.next:SetEnabled(panel.page < pages)
    panel.previous:SetShown(pages > 1)
    panel.next:SetShown(pages > 1)
    panel.pageText:SetShown(pages > 1)
    panel.pageText:SetText(("%d / %d"):format(panel.page, pages))
    panel:SetSize(panel.multiple and 532 or 274, footer + (pages > 1 and 28 or 0))
end

local function createChoicePanel()
    local panel = CreateFrame("Frame", "PaulchenUpgradeOptions", window, "BackdropTemplate")
    panel:Hide()
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:SetFrameLevel(window:GetFrameLevel() + 30)
    style.Panel(panel, style.background, style.accent)
    panel.title = label(panel, "GameFontNormal", GOLD, 12, -4, 220, 25)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -1)
    close:SetScript("OnClick", function() panel:Hide() end)
    panel.buttons = {}
    for index = 1, choicesPerColumn * 2 do
        local control = style.Button(panel)
        control:SetSize(248, 23)
        control.text = style.Label(control, "", 28, 0, 213, 23, "GameFontHighlightSmall", TEXT)
        control.tick = control:CreateTexture(nil, "OVERLAY")
        control.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        control.tick:SetSize(20, 20)
        control.tick:SetPoint("LEFT", 4, 0)
        control:SetScript("OnClick", function(self)
            if not panel.multiple then panel:Hide() end
            panel.choose(self.value)
            if panel:IsShown() then layoutChoices(panel) end
        end)
        panel.buttons[index] = control
    end
    panel.previous = button(panel, "Zurück", 8, 0, 68, 22)
    panel.next = button(panel, "Weiter", 197, 0, 68, 22)
    panel.pageText = label(panel, "GameFontHighlightSmall", MUTED, 90, 0, 93, 22, "CENTER")
    local function turnPage(delta)
        local perPage = choicesPerColumn * (panel.multiple and 2 or 1)
        local page = math.max(1, math.min(math.ceil(#panel.choices / perPage), panel.page + delta))
        if page == panel.page then return end
        panel.page = page
        layoutChoices(panel)
    end
    panel.previous:SetScript("OnClick", function() turnPage(-1) end)
    panel.next:SetScript("OnClick", function() turnPage(1) end)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta) turnPage(delta > 0 and -1 or 1) end)
    return panel
end

local function showChoices(owner, heading, choices, isSelected, choose, multiple)
    choicePanel = choicePanel or createChoicePanel()
    local panel = choicePanel
    if panel:IsShown() and panel.ownerButton == owner then panel:Hide(); return end
    panel.ownerButton, panel.choices, panel.isSelected, panel.choose = owner, choices, isSelected, choose
    panel.multiple, panel.page = multiple == true, 1
    if not multiple then
        for index, choice in ipairs(choices) do
            if isSelected(choice[1]) then panel.page = math.ceil(index / choicesPerColumn); break end
        end
    end
    panel.title:SetText(heading)
    panel:ClearAllPoints()
    if multiple then panel:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -3)
    else panel:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -3) end
    layoutChoices(panel)
    panel:Show()
end

local function hideChoices()
    if choicePanel then choicePanel:Hide() end
end

local function createProfileEditor(parent)
    local f = CreateFrame("Frame", "PaulchenStatProfilesFrame", parent, "BackdropTemplate")
    f:SetSize(700, 414)
    f:SetPoint("CENTER")
    f:SetFrameLevel(parent:GetFrameLevel() + 25)
    f:EnableMouse(true)
    style.Panel(f, style.background, style.accent)
    f:Hide()
    label(f, "GameFontNormalLarge", GOLD, 16, -11, 420, 27):SetText("Statprofile")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() f:Hide() end)
    local selector = button(f, "", 16, -45, 224, 26)
    local hint = label(f, "GameFontHighlightSmall", MUTED, 16, -76, 658, 19)
    hint:SetText("Punkte pro Attribut. Bei %-Werten gilt das Gewicht pro Prozentpunkt.")
    local boxes = {}
    for i, field in ipairs(app.weightFields) do
        local x = 16 + math.floor((i - 1) / 9) * 229
        local y = -108 - ((i - 1) % 9) * 26
        label(f, "GameFontHighlightSmall", TEXT, x, y, 150, 21):SetText(field[2])
        local box = style.EditBox(f)
        box:SetPoint("TOPLEFT", x + 151, y)
        box:SetSize(55, 21)
        box:SetMaxLetters(12)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        boxes[field[1]] = box
    end
    local tooltip = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    tooltip:SetPoint("TOPLEFT", 13, -346)
    tooltip:SetSize(23, 23)
    label(f, "GameFontHighlightSmall", TEXT, 40, -346, 222, 23):SetText("Vergleich im Item-Tooltip")
    local feedback = label(f, "GameFontHighlightSmall", GOLD, 16, -378, 380, 24)
    local function drawProfile()
        selector.text:SetText(app.ProfileName() .. downArrow)
        local weights = app.ProfileWeights()
        for key, box in pairs(boxes) do box:SetText((tostring(weights[key] or 0):gsub("%.", ","))) end
        tooltip:SetChecked(db.statTooltip ~= false)
        feedback:SetText("")
    end
    selector:SetScript("OnClick", function(owner)
        MenuUtil.CreateContextMenu(owner, function(_, menu)
            for _, profile in ipairs(app.ProfileChoices()) do
                local choice = profile
                menu:CreateRadio(choice.name, function() return app.ActiveProfile() == choice end, function()
                    app.SelectProfile(choice.key)
                    drawProfile()
                end)
            end
        end)
    end)
    tooltip:SetScript("OnClick", function(self) db.statTooltip = not not self:GetChecked() end)
    local reset = button(f, "Standardwerte", 439, -378, 115, 24)
    reset:SetScript("OnClick", function()
        local choice = app.ActiveProfile()
        if not choice then return end
        for key, box in pairs(boxes) do box:SetText((tostring(choice.weights[key] or 0):gsub("%.", ","))) end
        feedback:SetText("Zum Übernehmen speichern.")
    end)
    local save = button(f, "Speichern", 563, -378, 119, 24)
    save:SetScript("OnClick", function()
        local weights = {}
        for key, box in pairs(boxes) do weights[key] = tonumber((box:GetText():gsub(",", "."))) end
        if app.SaveProfileWeights(weights) then
            f:Hide()
        else
            feedback:SetText("Bitte Gewichte von 0 bis 1.000.000 eingeben.")
        end
    end)
    f:SetScript("OnShow", drawProfile)
    return f
end

local function createExportDialog(parent)
    local f = CreateFrame("Frame", "PaulchenUpgradesExportFrame", parent, "BackdropTemplate")
    f:SetSize(730, 405)
    f:SetPoint("CENTER")
    f:SetFrameLevel(parent:GetFrameLevel() + 25)
    f:EnableMouse(true)
    style.Panel(f, style.background, style.accent)
    f:Hide()
    label(f, "GameFontNormalLarge", GOLD, 16, -12, 664, 24):SetText("Upgrade-Export")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() f:Hide() end)
    local summary = label(f, "GameFontHighlightSmall", MUTED, 16, -40, 696, 18)
    local scroll = CreateFrame("ScrollFrame", "$parentScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -65)
    scroll:SetSize(674, 286)
    local box = style.EditBox(scroll, GameFontHighlightSmall)
    box:SetPoint("TOPLEFT")
    box:SetWidth(674)
    box:SetMultiLine(true)
    box:SetMaxBytes(0)
    box:SetTextInsets(8, 8, 6, 6)
    scroll:SetScrollChild(box)
    local measure = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    measure:SetWidth(658)
    measure:SetWordWrap(true)
    measure:Hide()
    local text
    local function selectAll()
        box:SetFocus()
        box:HighlightText()
    end
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self:GetText() ~= text then
            self:SetText(text or "")
            self:HighlightText()
        end
    end)
    f:SetScript("OnHide", function() box:ClearFocus() end)
    button(f, "Alles markieren", 16, -364, 142, 25):SetScript("OnClick", selectAll)
    label(f, "GameFontHighlightSmall", TEXT, 170, -364, 530, 25)
        :SetText("Strg+C kopiert den Text. In Excel oder Google Sheets ab A1 einfügen.")

    function f.ShowResults()
        text = exportResults()
        measure:SetText(text)
        box:SetHeight(math.max(286, measure:GetStringHeight() + 12, (#display + 1) * 13 + 12))
        box:SetText(text)
        box:SetCursorPosition(0)
        scroll:UpdateScrollChildRect()
        scroll:SetVerticalScroll(0)
        summary:SetText(("%d %s · Aktuelle Filter und Sortierung · Tabulatorgetrennt (TSV)")
            :format(#display, #display == 1 and "Upgrade" or "Upgrades"))
        f:Show()
        selectAll()
    end
    return f
end

local function dropdown(parent, options, key, x, w, currentLabel, y)
    local function caption()
        if currentLabel then return currentLabel() .. downArrow end
        for _, option in ipairs(options) do
            if option[1] == db[key] then return option[2] .. downArrow end
        end
    end
    local b = button(parent, caption(), x, y or -69, w, 27)
    local function selected(value) return db[key] == value end
    local function choose(value)
        db[key] = value
        b.text:SetText(caption())
        draw(true)
    end
    b:SetScript("OnClick", function(self)
        local choices = type(options) == "function" and options() or options
        if #choices > 14 then
            showChoices(self, "Auswahl", choices, selected, choose)
            return
        end
        hideChoices()
        MenuUtil.CreateContextMenu(self, function(_, menu)
            for _, option in ipairs(choices) do
                local value, text = option[1], option[2]
                menu:CreateRadio(text, function() return selected(value) end, function() choose(value) end)
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
    row:SetScript("OnEnter", function(self) hoveredRow = self; tip(self) end)
    row:SetScript("OnLeave", function(self)
        if hoveredRow == self then hoveredRow = nil end
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        if not renderingRows then draw() end
    end)
    row:SetScript("OnHide", function(self)
        if hoveredRow == self then hoveredRow = nil end
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
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
    f.profilesButton = button(titlebar, "Statprofile", 347, -12, 103, 27)
    f.profilesButton:SetScript("OnClick", function()
        profileEditor = profileEditor or createProfileEditor(f)
        profileEditor:SetShown(not profileEditor:IsShown())
    end)
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
    f.overviewTab:SetScript("OnClick", function() hideChoices(); db.tab = "overview"; draw(true) end)
    f.instancesTab:SetScript("OnClick", function() hideChoices(); db.tab = "instances"; draw(true) end)
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
    f.contentButton = button(f, "Spielinhalte" .. downArrow, 17, -103, 210, 27)
    f.contentButton:SetScript("OnClick", function(self)
        hideChoices()
        MenuUtil.CreateContextMenu(self, function(_, menu)
            if menu.CreateTitle then menu:CreateTitle("Auf deinem Server freigeschaltet") end
            for _, choice in ipairs(app.content.choices) do
                local key, caption = choice[1], choice[2]
                menu:CreateCheckbox(caption, function() return app.content.Snapshot()[key] end, function()
                    app.content.SetEnabled(key, not app.content.Snapshot()[key])
                    -- Source eligibility changes; cached stat comparisons stay reusable.
                    invalidateResults(true)
                end)
            end
        end)
    end)

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
    f.searchBox = box
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
    reload:SetScript("OnClick", app.CheckUpgrades)
    f.exportButton = button(f, "Exportieren", 350, -103, 118, 27)
    f.exportButton:SetEnabled(false)
    f.exportButton:SetScript("OnClick", function()
        if not exportReady() then return end
        exportDialog = exportDialog or createExportDialog(f)
        exportDialog.ShowResults()
    end)
    f.columnsMenu = button(f, "Spalten" .. downArrow, 764, -103, 128, 27)
    local columnChoices = {}
    for _, col in ipairs(columns) do
        if col.option then columnChoices[#columnChoices + 1] = {col.key, col.option} end
    end
    f.columnsMenu:SetScript("OnClick", function(self)
        showChoices(self, "Sichtbare Spalten", columnChoices, function(key) return db.columns[key] == true end,
            function(key)
                db.columns[key] = not db.columns[key] or nil
                if db.sortKey == key and not db.columns[key] then db.sortKey, db.ascending = "pct", false end
                layoutColumns(f, db.columns[key] and key or nil)
                draw(true)
            end, true)
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
        draw()
    end)
    f:SetScript("OnHide", function()
        hideChoices()
        if hoveredRow then
            if GameTooltip:IsOwned(hoveredRow) then GameTooltip:Hide() end
            hoveredRow = nil
        end
        if exportDialog then exportDialog:Hide() end
        if profileEditor then profileEditor:Hide() end
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

function app.OpenOverviewUpgrade()
    local best = app.OverviewUpgrade().best
    suite.OpenDashboard("upgrades")
    if best and window then
        db.tab, db.slot, db.source, db.profession = "overview", 0, "all", ""
        db.quality[best.quality] = true
        window.searchBox:SetText(best.name)
        draw(true)
    end
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

app.On("GEAR_UPDATED", function(reason)
    if reason == "bags" or reason == "bagItems" then
        invalidateResults(false)
    elseif reason == "profile" or reason == "equipment" or reason == "level" or reason == "skills" then
        invalidateResults(true)
    end
end)
app.On("PAULCHEN_VARIANT_ADDED", function() invalidateResults(false) end)

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
            if plannedLevel and plannedLevel <= gear.PlayerLevel() then plannedLevel = nil end
            draw()
        end)
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        if window and window:IsVisible() then layoutColumns(window) end
    elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
        if window and window:IsVisible() then C_Timer.After(0, updateAuctionScanButton) end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if event == "PLAYER_ENTERING_WORLD" and (not enteredWorld or suite.Readable(id) or suite.Readable(success)) then
            enteredWorld = true
            app.CheckUpgrades()
        end
        if window and window:IsVisible() and db.tab == "instances" and db.instanceSelection == automatic then
            draw(true)
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        id, success = suite.Readable(id), suite.Readable(success)
        if scan and id then app.ItemDataReady(scan, id, success) end
        if wakeRequestedScan and not startAfterCombat and id and id == waitingItemID and success ~= false then
            wakeRequestedScan(0)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if startAfterCombat then
            startAfterCombat = false
            wakeRequestedScan(0)
        elseif scan and pausedAt then
            local elapsed = math.max(0, GetTime() - pausedAt)
            -- The scan's timeout budget excludes time spent in combat.
            if scan.tailStarted then scan.tailStarted = scan.tailStarted + elapsed end
            for _, pending in pairs(scan.waiting) do
                pending.deadline = pending.deadline + elapsed
                pending.nextPoll = 0
            end
            pausedAt = nil
            resumeScan()
            draw()
        end
    elseif event == "PLAYER_REGEN_DISABLED" and scan then
        pausedAt = pausedAt or GetTime()
        draw()
    end
end)
