local _, app = ...
local guide, style, L, read = app.instances, app.style, app.L, app.ReadGameValue
local page, queued, mapQueued
local width, height, rowCount = 984, 546, 13
local mapWidth, mapHeight = 594, 396
local requestedItems, requestedQuests = {}, {}
local tabs = { { "map", "Karte" }, { "route", "Route" }, { "quests", "Quests" }, { "loot", "Beute" } }

local function button(parent, text, x, y, w, onClick)
    local b = style.TextButton(parent)
    b:SetSize(w, 23)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(L(text))
    b:SetScript("OnClick", onClick)
    return b
end

local function menu(owner, build)
    local locked, known = app.comfort.Read(InCombatLockdown)
    if known and not locked and MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root) build(root) end)
    end
end

local function itemText(id)
    local api = C_Item and C_Item.GetItemInfo or GetItemInfo
    local name, link = read(api, id)
    if not name and not requestedItems[id] and C_Item and C_Item.RequestLoadItemDataByID then
        requestedItems[id] = true
        app.ReadGameValue(C_Item.RequestLoadItemDataByID, id)
    end
    return name or app.LF("Gegenstand #%d", id), link
end

local function requestQuest(id)
    if not requestedQuests[id] and C_QuestLog and C_QuestLog.RequestLoadQuestByID then
        requestedQuests[id] = true
        app.ReadGameValue(C_QuestLog.RequestLoadQuestByID, id)
    end
end

local function current()
    if not guide.selection then
        local entry = guide.entries[1]
        guide.selection = { entry = entry, tab = "map", floor = entry.floors[1] }
    end
    return guide.selection
end

local function showLoot(name)
    local s = current()
    s.tab, s.boss, s.offset = "loot", name, 0
    guide.Refresh(true)
end

local function moveFloor(delta)
    local s = current()
    for index, id in ipairs(s.entry.floors) do
        if id == s.floor then
            local nextFloor = s.entry.floors[index + delta]
            if nextFloor then s.floor = nextFloor; guide.Refresh(true) end
            return
        end
    end
end

local function showQuest(quest)
    local s = current()
    s.tab, s.quest, s.offset = "quests", quest, 0
    guide.Refresh(true)
end

local function listRows(s)
    local rows, entry = {}, s.entry
    if s.tab == "quests" then
        if s.quest then
            local quest = s.quest
            local status, color = guide.QuestStatus(quest.id)
            rows[1] = { left = status, right = quest.min and app.LF("Ab Stufe %d", quest.min), color = color }
            for _, destination in ipairs({ {quest.start, "Questgeber auf der Karte"}, {quest.finish, "Abgabe auf der Karte"} }) do
                local point = destination[1]
                if point then
                    rows[#rows + 1] = { left = L(destination[2]), right = app.worldMap.Name(point[1]),
                        action = function() guide.ShowWaypoint(point) end }
                end
            end
            if #quest.rewards > 0 then
                rows[#rows + 1] = { left = L("Questbelohnungen"), color = style.gold }
                for _, id in ipairs(quest.rewards) do rows[#rows + 1] = { item = id } end
            end
        else
            for _, quest in ipairs(entry.quests) do
                if guide.AllowedFaction(quest.faction) then
                    local status, color = guide.QuestStatus(quest.id)
                    rows[#rows + 1] = { quest = quest, right = status, color = color,
                        action = function() showQuest(quest) end }
                end
            end
        end
    elseif s.tab == "loot" then
        for _, boss in ipairs(entry.loot) do
            if not s.boss or boss.name == s.boss then
                local start = #rows
                rows[#rows + 1] = { left = boss.name, color = style.gold }
                for _, item in ipairs(boss.items) do
                    if guide.AllowedFaction(item[3]) then
                        rows[#rows + 1] = { item = item[1], right = item[2] > 0
                            and app.LocalizeDecimal(("%.1f"):format(item[2])) .. " %" or nil }
                    end
                end
                if #rows == start + 1 then rows[#rows] = nil end
            end
        end
    else
        for index, stop in ipairs(entry.stops) do
            local done = guide.IsDefeated(entry, index)
            rows[#rows + 1] = { left = ("%d. %s"):format(index, guide.Name(stop)), right = done and L("Besiegt") or nil,
                color = done and style.green or style.cream, action = function()
                    s.floor = stop.floor
                    s.highlight = index
                    guide.Refresh(true)
                end }
        end
    end
    return rows
end

local function scroll(delta)
    local s = current()
    s.offset = (s.offset or 0) + delta
    guide.Refresh()
end

local function renderList()
    local f, s = page, current()
    local rows = listRows(s)
    local offset = math.min(math.max(s.offset or 0, 0), math.max(#rows - rowCount, 0))
    s.offset = offset
    for index, widget in ipairs(f.rows) do
        local row = rows[index + offset]
        widget.row = row
        if row then
            local name, link
            if row.item then name, link = itemText(row.item)
            elseif row.quest then
                requestQuest(row.quest.id)
                name = guide.QuestTitle(row.quest)
            else name = row.left end
            widget.link = link
            widget.left:SetText(name or "")
            widget.left:SetTextColor(unpack(row.color or style.cream))
            widget.right:SetText(row.right or "")
        end
        widget:SetShown(row ~= nil)
    end
    f.counter:SetText(#rows > 0 and ("%d–%d / %d"):format(offset + 1, math.min(offset + rowCount, #rows), #rows)
        or L("Keine Einträge verfügbar"))
    f.previous:SetEnabled(offset > 0)
    f.next:SetEnabled(offset + rowCount < #rows)
    f.listTitle:SetText(s.tab == "loot" and (s.boss or L("Alle Bosse")) or s.tab == "quests"
        and (s.quest and guide.QuestTitle(s.quest) or L("Instanzquests")) or L("Bossreihenfolge"))
    f.chooseBoss:SetShown(s.tab == "loot")
    f.backQuest:SetShown(s.tab == "quests" and s.quest ~= nil)
end

local function artTexture(view, index)
    local texture = view.art[index]
    if not texture then
        texture = view:CreateTexture(nil, "ARTWORK")
        view.art[index] = texture
    end
    texture:ClearAllPoints()
    return texture
end

local function renderArt(view, floor, scheme)
    local used = 0
    if floor and not scheme then
        local tiles = floor.tiles
        for index, file in ipairs(tiles) do
            local texture = artTexture(view, index)
            if texture:SetTexture(file) == false then used = 0; break end
            local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
            local w, h = math.min(256, 1002 - column * 256), math.min(256, 668 - row * 256)
            texture:SetTexCoord(0, w / 256, 0, h / 256)
            texture:SetSize(w * mapWidth / 1002, h * mapHeight / 668)
            texture:SetPoint("TOPLEFT", view, "TOPLEFT", column * 256 * mapWidth / 1002, -row * 256 * mapHeight / 668)
            texture:SetDrawLayer("ARTWORK", 0)
            texture:Show()
            used = index
        end
        if used == 0 then
            for _, part in ipairs(floor.art) do
                local texture = artTexture(view, used + 1)
                if texture:SetTexture(part[1], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "TRILINEAR") ~= false then
                    texture:SetTexCoord(unpack(part, 6, 13))
                    texture:SetSize(part[4] * mapWidth / 1002, part[5] * mapHeight / 668)
                    texture:SetPoint("TOPLEFT", view, "TOPLEFT", part[2] * mapWidth / 1002, -part[3] * mapHeight / 668)
                    texture:SetDrawLayer("ARTWORK", math.min(7, math.max(-8, part[14] or 0)))
                    texture:Show()
                    used = used + 1
                end
            end
        end
    end
    for index = used + 1, #view.art do view.art[index]:Hide() end
    return used > 0
end

local function renderMap()
    local f, s = page, current()
    local view, entry = f.map, s.entry
    local floor = guide.floors[s.floor]
    local art = renderArt(view, floor, s.tab == "route")
    local lineCount, pinCount = 0, 0
    for _, path in ipairs(entry.paths) do
        if path.floor == s.floor then
            for i = 1, #path.pts - 3, 2 do
                local x, y, nextX, nextY = unpack(path.pts, i, i + 3)
                if x ~= nextX or y ~= nextY then
                    lineCount = lineCount + 1
                    local line = view.lines[lineCount] or view.overlay:CreateLine(nil, "OVERLAY")
                    view.lines[lineCount] = line
                    line:SetThickness(path.side and 1.5 or 2.5)
                    line:SetColorTexture(path.side and .60 or .96, path.side and .71 or .72, .35, .94)
                    line:SetStartPoint("TOPLEFT", view, x * mapWidth, -y * mapHeight)
                    line:SetEndPoint("TOPLEFT", view, nextX * mapWidth, -nextY * mapHeight)
                    line:Show()
                end
            end
        end
    end
    for index, stop in ipairs(entry.stops) do
        if stop.floor == s.floor then
            pinCount = pinCount + 1
            local pin = view.pins[pinCount]
            if not pin then
                pin = style.TextButton(view.overlay)
                pin:SetSize(22, 22)
                pin:SetScript("OnClick", function(self) showLoot(self.stop.loot) end)
                pin:SetScript("OnEnter", function(self)
                    if not GameTooltip or GameTooltip:IsForbidden() then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(guide.Name(self.stop), unpack(style.gold))
                    GameTooltip:Show()
                end)
                pin:SetScript("OnLeave", function(self)
                    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                end)
                view.pins[pinCount] = pin
            end
            pin.stop = stop
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", view, "TOPLEFT", stop.x * mapWidth, -stop.y * mapHeight)
            pin:SetText(tostring(index))
            style.SetButtonState(pin, s.highlight == index or guide.IsDefeated(entry, index))
            pin:Show()
        end
    end
    for index = lineCount + 1, #view.lines do view.lines[index]:Hide() end
    for index = pinCount + 1, #view.pins do view.pins[index]:Hide() end
    f.mapNote:SetText(art and "" or lineCount + pinCount > 0 and L("Schematische Route") or L("Keine Innenkartendaten"))
    f.floorName:SetText(floor and guide.Name(floor) or "")
    local number
    for index, id in ipairs(entry.floors) do if s.floor == id then number = index; break end end
    f.prevFloor:SetEnabled(number and number > 1 or false)
    f.nextFloor:SetEnabled(number and number < #entry.floors or false)
end

function guide.Refresh(drawMap)
    if not page or not page:IsVisible() then return end
    local s = current()
    local entry = s.entry
    page.title:SetText(guide.Name(entry))
    local range = entry.levels[1] and (" · %d–%d"):format(entry.levels[1], entry.levels[2] or entry.levels[1]) or ""
    local content = app.upgrades and app.upgrades.content
    local group = content and content.LocationGroup(guide.Location(entry))
    local locked = group and not content.Snapshot()[group]
    page.level:SetText((entry.raid and L("Schlachtzug") or L("Instanz")) .. range
        .. (locked and " · " .. L("Im Inhaltsfilter gesperrt") or ""))
    page.entrance:SetEnabled(entry.entrance ~= nil)
    for key, tab in pairs(page.tabs) do style.SetButtonState(tab, key == s.tab) end
    if drawMap then renderMap() end
    renderList()
end

function guide.QueueRefresh(drawMap)
    if not page or not page:IsVisible() then return end
    mapQueued = mapQueued or drawMap
    if queued then return end
    queued = true
    C_Timer.After(.15, function()
        local redraw = mapQueued
        queued, mapQueued = nil, nil
        guide.Refresh(redraw)
    end)
end

function guide.GetPage(parent)
    if page then return page end
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    f:Hide()
    page = f
    f.title = style.Label(f, "", 16, -9, 580, 27, "GameFontNormalLarge", style.gold)
    f.level = style.Label(f, "", 16, -39, 580, 19, "GameFontHighlightSmall", style.muted)
    button(f, "Instanz wählen", 691, -13, 140, function(self)
        menu(self, function(root)
            for _, section in ipairs({ { L("Instanzen"), false }, { L("Schlachtzüge"), true } }) do
                local group = root:CreateButton(section[1])
                if group.SetScrollMode then group:SetScrollMode(350) end
                for _, entry in ipairs(guide.entries) do
                    if (entry.raid == true) == section[2] then
                        group:CreateButton(guide.Name(entry), function() guide.Open(entry.key) end)
                    end
                end
            end
        end)
    end)
    f.entrance = button(f, "Eingang", 838, -13, 128, function()
        local entry = current().entry
        if entry.entrance then guide.ShowWaypoint(entry.entrance) end
    end)
    f.tabs = {}
    for index, definition in ipairs(tabs) do
        local key = definition[1]
        f.tabs[key] = button(f, definition[2], 16 + (index - 1) * 100, -66, 95, function()
            local s = current()
            s.tab, s.offset, s.quest, s.boss = key, 0, nil, nil
            guide.Refresh(true)
        end)
    end
    local view = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.map = view
    view:SetSize(mapWidth, mapHeight)
    view:SetPoint("TOPLEFT", 16, -98)
    style.Panel(view, style.background)
    view.art, view.lines, view.pins = {}, {}, {}
    view.overlay = CreateFrame("Frame", nil, view)
    view.overlay:SetAllPoints(view)
    if view.SetClipsChildren then view:SetClipsChildren(true) end
    f.mapNote = style.Label(f, "", 16, -503, 245, 22, "GameFontHighlightSmall", style.muted)
    f.floorName = style.Label(f, "", 297, -503, 282, 22, "GameFontHighlightSmall", style.cream, "CENTER")
    f.prevFloor = button(f, "<", 265, -503, 25, function() moveFloor(-1) end)
    f.nextFloor = button(f, ">", 585, -503, 25, function() moveFloor(1) end)

    local panel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    panel:SetSize(342, 404)
    panel:SetPoint("TOPRIGHT", -18, -66)
    style.Panel(panel, style.header)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta) scroll(delta > 0 and -3 or 3) end)
    f.listTitle = style.Label(panel, "", 10, -3, 251, 26, "GameFontNormal", style.gold)
    f.chooseBoss = button(panel, "Bosse", 266, -5, 68, function(self)
        menu(self, function(root)
            root:CreateButton(L("Alle Bosse"), function() showLoot(nil) end)
            for _, boss in ipairs(current().entry.loot) do
                root:CreateButton(boss.name, function() showLoot(boss.name) end)
            end
        end)
    end)
    f.backQuest = button(panel, "Zurück", 266, -5, 68, function() showQuest(nil) end)
    f.rows = {}
    for index = 1, rowCount do
        local row = style.Button(panel)
        row:SetPoint("TOPLEFT", 8, -35 - (index - 1) * 27)
        row:SetSize(326, 25)
        row.left = style.Label(row, "", 7, 0, 207, 24, "GameFontHighlightSmall", style.cream)
        row.right = style.Label(row, "", 216, 0, 104, 24, "GameFontHighlightSmall", style.muted, "RIGHT")
        row:SetScript("OnEnter", function(self)
            if not self.row or not self.row.item or not GameTooltip or GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.link then GameTooltip:SetHyperlink(self.link)
            elseif GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.row.item) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        row:SetScript("OnClick", function(self)
            if self.row and self.row.action then self.row.action()
            elseif self.link and read(IsShiftKeyDown) and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link) end
        end)
        f.rows[index] = row
    end
    f.counter = style.Label(f, "", 665, -479, 252, 23, "GameFontHighlightSmall", style.muted, "CENTER")
    f.previous = button(f, "<", 625, -479, 30, function() scroll(-rowCount) end)
    f.next = button(f, ">", 936, -479, 30, function() scroll(rowCount) end)
    f:SetScript("OnShow", function() guide.Refresh(true) end)
    return f
end
