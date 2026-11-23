local addonName, suite = ...
local addon = suite.timeline
if not addon then return end
local style = suite.style

local slotSeconds, slotCount, packetLimit = 30, 4096, 512

local function unsigned(bytes, index, size)
    local value = 0
    for offset = 0, size - 1 do
        value = value * 256 + bytes:byte(index + offset)
    end
    return value
end

local function checksum(bytes)
    local a, b = 1, 0
    for index = 1, #bytes do
        a = (a + bytes:byte(index)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

local function readFont(meter, epoch, received)
    local path = ("Interface\\AddOns\\%s\\Modules\\DTL\\CritFonts\\s%04d.ttf"):format(addonName, epoch % slotCount)
    local assigned, result = pcall(meter.SetFont, meter, path, 64, "")
    meter:SetText("!~")
    local current = meter:GetFont()
    if not assigned or (not result and (not current or current:lower() ~= path:lower())) then
        return
    end

    local base = meter:GetStringWidth()
    meter:SetText('"~')
    local step = (meter:GetStringWidth() - base) / 255
    if base <= 0 or step < 0.35 then
        return
    end

    local function readBytes(first, last)
        local bytes = {}
        for index = first, last do
            local point = 0xE000 + index - 1
            local glyph = string.char(224 + math.floor(point / 4096), 128 + math.floor(point / 64) % 64, 128 + point % 64)
            meter:SetText(glyph .. "~")
            local value = math.floor((meter:GetStringWidth() - base) / step + 0.5)
            if value < 0 or value > 255 then
                return
            end
            bytes[#bytes + 1] = string.char(value)
        end
        return table.concat(bytes)
    end

    local header = readBytes(1, 15)
    if not header or header:sub(1, 4) ~= "DTL1" or unsigned(header, 5, 4) ~= epoch then
        return
    end
    local guidSize, count = unsigned(header, 13, 1), unsigned(header, 14, 2)
    local length = 15 + guidSize + count * 10
    if guidSize == 0 or count == 0 or length > packetLimit then
        return
    end
    local guid = UnitGUID("player")
    if issecretvalue(guid) or readBytes(16, 15 + guidSize) ~= guid then
        return false
    end
    local expectedChecksum = unsigned(header, 9, 4)
    if received[expectedChecksum] then
        return false, expectedChecksum
    end
    local body = readBytes(16, length)
    if not body or checksum(body) ~= expectedChecksum then
        return
    end
    local hits = {}
    for index = guidSize + 1, #body, 10 do
        hits[unsigned(body, index, 4)] = unsigned(body, index + 4, 6)
    end
    return hits, expectedChecksum
end

local function getRecords()
    local saved = PaulchenQoLTimelineDB.critRecords or {}
    PaulchenQoLTimelineDB.critRecords = saved
    local guid = UnitGUID("player")
    local imported = not issecretvalue(guid) and addon.importedCritRecords[guid]
    for id, record in pairs(imported or {}) do
        if not saved[id] or record.damage > saved[id].damage then
            saved[id] = record
        end
    end

    local byName = {}
    for id, record in pairs(saved) do
        local name = id == 0 and "Nahkampfangriff" or C_Spell.GetSpellName(id) or record.name
        if not byName[name] or record.damage > byName[name].damage then
            byName[name] = { id = id, name = name, damage = record.damage }
        end
    end

    local sorted = {}
    for _, record in pairs(byName) do
        sorted[#sorted + 1] = record
    end
    table.sort(sorted, function(a, b)
        if a.damage == b.damage then
            return a.name < b.name
        end
        return a.damage > b.damage
    end)
    return sorted
end

function addon.CreateCritPanel(panel, width, rowHeight, visibleRows, label)
    local records = getRecords()
    local heading = label(panel, "GameFontNormalLarge", "TOPLEFT", "TOPLEFT", 12, -34)
    heading:SetText(suite.L("Crit-Rekorde"))
    local sync = label(panel, "GameFontDisableSmall", "TOPRIGHT", "TOPRIGHT", -12, -38)
    sync:SetText(suite.L("Warte auf Abgleich"))
    local description = label(panel, "GameFontHighlightSmall", "TOPLEFT", "TOPLEFT", 12, -55)
    description:SetTextColor(unpack(style.muted))
    description:SetText(suite.L("Höchster kritischer Einzeltreffer pro Fähigkeit"))

    local empty = label(panel, "GameFontHighlight", "TOP", "TOP", 0, -109)
    empty:SetWidth(width - 40)
    empty:SetText(suite.L("Noch keine Crits geladen.\n\nStarte die Crit-Erfassung und aktiviere /combatlog."))

    local rows = {}
    for index = 1, visibleRows do
        local row = CreateFrame("Frame", nil, panel)
        row:SetPoint("TOPLEFT", 6, -75 - (index - 1) * rowHeight)
        row:SetPoint("TOPRIGHT", -6, -75 - (index - 1) * rowHeight)
        row:SetHeight(rowHeight - 2)
        style.Row(row, index)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetSize(15, 15)
        row.name = label(row, "GameFontHighlightSmall", "LEFT", "LEFT", 25, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -78, 0)
        row.name:SetWordWrap(false)
        row.name:SetJustifyH("LEFT")
        row.damage = label(row, "GameFontNormal", "RIGHT", "RIGHT", -5, 0)
        rows[index] = row
    end

    local page = 1
    local pages
    local footer = label(panel, "GameFontDisableSmall", "BOTTOMLEFT", "BOTTOMLEFT", 11, 11)
    local function pageButton(text, x)
        local button = style.TextButton(panel)
        button:SetPoint("BOTTOMRIGHT", x, 6)
        button:SetSize(22, 19)
        button:SetText(text)
        return button
    end
    local back = pageButton("<", -32)
    local forward = pageButton(">", -8)

    local function renderPage()
        pages = math.ceil(#records / visibleRows)
        page = math.max(1, math.min(pages, page))
        empty:SetShown(#records == 0)
        footer:SetText(#records > 0 and (suite.L("%d Fähigkeiten · Seite %d/%d")):format(#records, page, pages) or "")
        back:SetShown(pages > 1)
        forward:SetShown(pages > 1)
        back:SetEnabled(page > 1)
        forward:SetEnabled(page < pages)
        for index, row in ipairs(rows) do
            local record = records[(page - 1) * visibleRows + index]
            row:SetShown(record ~= nil)
            if record then
                row.icon:SetTexture(record.id > 0 and C_Spell.GetSpellTexture(record.id) or 132223)
                row.name:SetText((record.name:gsub("|", "||")))
                row.damage:SetText(BreakUpLargeNumbers(record.damage))
            end
        end
    end

    local function changePage(direction)
        page = math.max(1, math.min(pages, page + direction))
        renderPage()
    end
    back:SetScript("OnClick", function() changePage(-1) end)
    forward:SetScript("OnClick", function() changePage(1) end)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta) changePage(delta > 0 and -1 or 1) end)
    renderPage()

    local meter = UIParent:CreateFontString(nil, "OVERLAY")
    meter:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    meter:SetAlpha(0)
    meter:SetWordWrap(false)
    meter:SetNonSpaceWrap(false)
    local finished, attempted, tries
    local received = {}
    C_Timer.NewTicker(2, function()
        if not panel:IsVisible() or InCombatLockdown() then
            return
        end
        local now = time()
        local epoch = math.floor(now / slotSeconds)
        if now % slotSeconds < 3 or epoch == finished then
            return
        end
        if epoch ~= attempted then
            attempted, tries = epoch, 0
        end
        if tries >= 3 then
            return
        end
        tries = tries + 1
        local ok, hits, signature = pcall(readFont, meter, epoch, received)
        if not ok or hits == nil then
            return
        end
        finished = epoch
        if signature then
            received[signature] = true
            sync:SetText(suite.L("Abgleich ") .. date("%H:%M:%S"))
        end
        if not hits then
            return
        end
        local changed = false
        local saved = PaulchenQoLTimelineDB.critRecords
        for id, damage in pairs(hits) do
            if damage > 0 and (not saved[id] or damage > saved[id].damage) then
                local name = id == 0 and "Nahkampfangriff" or C_Spell.GetSpellName(id) or (suite.L("Fähigkeit #%d")):format(id)
                saved[id] = { damage = damage, name = name }
                changed = true
            end
        end
        if changed then
            records = getRecords()
            renderPage()
        end
    end)
end
