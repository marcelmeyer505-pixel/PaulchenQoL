local _, app = ...
local guide, style, L, read, planner = app.instances, app.style, app.L, app.ReadGameValue, app.dungeonQuests
local page, queued, mapQueued, worldView, outdoorRequested, loot
local width, height, rowCount = 984, 546, 13
local mapWidth, mapHeight = 594, 396
local mapZoomLevels = { 1, 1.25, 1.6, 2, 2.5, 3.2, 4 }
local requestedItems = {}
local tabs = { { "map", "Karte" }, { "quests", "Quests" }, { "loot", "Beute" } }

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

local function compareItem(link)
    local gear = app.upgrades and app.upgrades.gear
    return link and gear and read(gear.CompareToEquipped, link) or nil
end

local function upgradePercent(result)
    if not result or not result.usable then return end
    if result.equipped then return 0 end
    return result.pct
end

local function itemUpgrade(pct)
    if not pct then return "–", style.muted end
    local color = pct > 0 and style.green or pct < 0 and style.orange or style.muted
    return app.LocalizeDecimal((pct == 0 and "%.1f %%" or "%+.1f %%"):format(pct)), color
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
    guide.Refresh()
end

local function scheduleLoot(scan)
    if scan.scheduled or scan.next > #scan.queue or not page:IsVisible() then return end
    scan.scheduled = true
    C_Timer.After(0, function()
        scan.scheduled = nil
        if loot ~= scan or not page:IsVisible() or current().entry ~= scan.entry or current().tab == "quests" then return end
        local upgrades = app.upgrades
        local level = upgrades and upgrades.gear and read(upgrades.gear.PlayerLevel)
        local deadline = debugprofilestop and debugprofilestop() + 2
        -- Spread tooltip and stat reads across frames, including on large raid loot tables.
        for _ = 1, 16 do
            local id = scan.queue[scan.next]
            if not id then break end
            scan.next = scan.next + 1
            local rating = scan.items[id]
            rating.queued = nil
            local _, link = itemText(id)
            local result = compareItem(link)
            rating.pct = upgradePercent(result)
            rating.upgrade = level and upgrades.IsUpgrade and upgrades.IsUpgrade(result, level)
            rating.checked = true
            if deadline and debugprofilestop() >= deadline then break end
        end
        if scan.next > #scan.queue then scan.queue, scan.next = {}, 1 end
        guide.QueueRefresh()
        scheduleLoot(scan)
    end)
end

local function lootFor(entry)
    if not loot or loot.entry ~= entry then
        loot = { entry = entry, items = {}, rows = {}, bosses = {}, queue = {}, next = 1 }
        local names = {}
        for _, stop in ipairs(entry.stops) do
            if stop.loot then names[stop.loot] = guide.Name(stop) end
        end
        for _, boss in ipairs(entry.loot) do
            local rows, seen = {}, {}
            loot.bosses[boss.name] = rows
            for _, item in ipairs(boss.items) do
                local id, rate, faction = unpack(item)
                if not seen[id] and guide.AllowedFaction(faction) then
                    seen[id] = true
                    local rating = loot.items[id]
                    if not rating then
                        rating = { queued = true }
                        loot.items[id] = rating
                        loot.queue[#loot.queue + 1] = id
                    end
                    local row = { item = id, rate = rate, rating = rating, source = names[boss.name] or boss.name }
                    rows[#rows + 1] = row
                    loot.rows[#loot.rows + 1] = row
                end
            end
        end
    end
    scheduleLoot(loot)
    return loot
end

function guide.LootItemUpdated(id)
    local rating = loot and loot.items[id]
    if rating and not rating.queued then
        rating.queued = true
        loot.queue[#loot.queue + 1] = id
        scheduleLoot(loot)
    end
end

function guide.RefreshLoot()
    loot = nil
    guide.QueueRefresh()
end

local function sortLoot(a, b)
    local left, right = a.rating.pct or -math.huge, b.rating.pct or -math.huge
    if left ~= right then return left > right end
    if a.rate ~= b.rate then return a.rate > b.rate end
    if a.item ~= b.item then return a.item < b.item end
    return a.source < b.source
end

local function bossUpgrades(rows)
    local count, pending = 0, false
    for _, row in ipairs(rows or {}) do
        if row.rating.upgrade then count = count + 1 end
        if not row.rating.checked then pending = true end
    end
    if pending then return "…" end
    return app.LF(count == 1 and "%d Upgrade" or "%d Upgrades", count)
end

local function questRow(quest)
    local status, color = planner.DescribeStatus(quest.status)
    local points = quest.givers or quest.entry.givers or {}
    local point = points[1]
    local label = point and point.referenceOnly and "Classic-Referenz" or "Questgeber"
    local source = point and point.name and (L(label) .. " · " .. point.name)
    return { left = quest.title, right = status, color = color, source = source, questID = quest.id,
        action = function() showQuest(quest.id) end, tip = { title = quest.title, text = planner.FormatLocation(point) } }
end

local function questLocations(rows, label, points)
    rows[#rows + 1] = { left = L(label), color = style.gold }
    if #points == 0 then rows[#rows + 1] = { left = planner.FormatLocation(), color = style.muted } end
    for _, point in ipairs(points) do
        local name = point.name or L("Unbekannt")
        local row = { left = name, tip = { title = name, text = planner.FormatLocation(point) } }
        if guide.HasQuestPoint(point) then
            row.right = point.referenceOnly and L("Classic-Referenz")
                or point.observed and L("Beobachtet") or app.worldMap.Name(point.map)
            row.action = function() guide.ShowWaypoint({ point.map, point.x, point.y }) end
        elseif point.inside then
            row.right = L("In der Instanz")
        elseif point.kind == "item" or point.kind == "object" then
            row.right = L("Fundort fehlt")
        end
        rows[#rows + 1] = row
    end
end

local function questRows(s)
    local data = guide.QuestSnapshot(s.entry)
    local rows, detail = {}, planner.FindQuest(s.quest, data)
    if not detail then
        s.quest = nil
        for _, quest in ipairs(data.quests) do rows[#rows + 1] = questRow(quest) end
        local progress = app.LF("%d/%d abgeschlossen", data.done, #data.quests) .. " · " .. app.LF("%d im Questlog", data.active)
        if data.incomplete then progress = progress .. " · " .. L("Questdaten unvollständig") end
        return rows, nil, progress
    end

    local status, color = planner.DescribeStatus(detail.status)
    local min = detail.entry.minLevel
    rows[1] = { left = status, right = min and app.LF("Ab Stufe %d", min), color = color }
    questLocations(rows, "Questgeber", detail.givers or detail.entry.givers or {})
    questLocations(rows, "Abgabe", detail.enders or detail.entry.enders or {})
    local prerequisites = guide.QuestPrerequisites(data, detail.id)
    if #prerequisites > 0 then
        local done = 0
        for _, quest in ipairs(prerequisites) do if quest.status == "DONE" then done = done + 1 end end
        rows[#rows + 1] = { left = L("Vorquests"), right = ("%d/%d"):format(done, #prerequisites), color = style.gold }
        for _, quest in ipairs(prerequisites) do rows[#rows + 1] = questRow(quest) end
    elseif detail.entry.chainIncomplete then
        rows[#rows + 1] = { left = L("Vorquests"), color = style.gold }
        rows[#rows + 1] = { left = L("Questdaten unvollständig"), color = style.muted }
    end
    if detail.rewards and #detail.rewards > 0 then
        rows[#rows + 1] = { left = L("Questbelohnungen"), color = style.gold }
        for _, id in ipairs(detail.rewards) do rows[#rows + 1] = { item = id } end
    end
    return rows, detail
end

local function listRows(s)
    if s.tab == "quests" then return questRows(s) end
    local rows, entry = {}, s.entry
    if s.tab == "loot" then
        local scan = lootFor(entry)
        local items = s.boss and (scan.bosses[s.boss] or {}) or scan.rows
        for i, row in ipairs(items) do rows[i] = row end
        table.sort(rows, sortLoot)
    else
        local scan = lootFor(entry)
        for index, stop in ipairs(entry.stops) do
            local done = guide.IsDefeated(entry, index)
            local name = guide.Name(stop)
            rows[#rows + 1] = { left = stop.alternate and name or ("%d. %s"):format(index, name),
                right = bossUpgrades(scan.bosses[stop.loot]),
                color = done and style.green or style.cream, action = function()
                    s.floor = stop.floor
                    s.highlight = index
                    showLoot(stop.loot or stop.name)
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
    local rows, quest, progress = listRows(s)
    local offset = math.min(math.max(s.offset or 0, 0), math.max(#rows - rowCount, 0))
    local hasItems = s.tab == "loot" or quest and quest.rewards and #quest.rewards > 0
    s.offset = offset
    f.questProgress:SetShown(progress ~= nil)
    f.questProgress:SetText(progress or "")
    f.dropTitle:SetShown(s.tab == "loot")
    f.upgradeTitle:SetShown(hasItems == true)
    for index, widget in ipairs(f.rows) do
        local row = rows[index + offset]
        local id = row and row.item
        local source = row and (s.tab == "quests" or s.tab == "loot" and not s.boss) and row.source
        local previous = widget.row
        if previous and (not row or previous.item ~= id or previous.questID ~= row.questID or previous.left ~= row.left)
            and GameTooltip and GameTooltip:IsOwned(widget) then GameTooltip:Hide() end
        widget.row = row
        widget.link = nil
        widget.icon:SetShown(id ~= nil)
        widget.drop:SetShown(id ~= nil and s.tab == "loot")
        widget.upgrade:SetShown(id ~= nil)
        widget.source:SetShown(type(source) == "string")
        if row then
            local name, link
            local color = row.color or style.cream
            if id then
                name, link = itemText(id)
                widget.icon:SetTexture(read(C_Item and C_Item.GetItemIconByID or GetItemIcon, id) or 134400)
                local pct
                if row.rating then pct = row.rating.pct
                else pct = upgradePercent(compareItem(link)) end
                local value, valueColor = itemUpgrade(pct)
                widget.upgrade:SetText(value)
                widget.upgrade:SetTextColor(unpack(valueColor))
                widget.drop:SetText(row.rate and row.rate > 0 and app.LocalizeDecimal(("%.1f %%"):format(row.rate)) or "–")
                local quality = read(C_Item and C_Item.GetItemQualityByID, id)
                local itemColor = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                if itemColor then color = { itemColor.r, itemColor.g, itemColor.b } end
            else name = row.left end
            widget.link = link
            widget:SetPoint("TOPLEFT", 8, ((hasItems or progress) and -53 or -35) - (index - 1) * 25)
            widget.left:SetPoint("TOPLEFT", id and 30 or 7, 0)
            widget.left:SetWidth(id and (s.tab == "loot" and 161 or 218) or s.tab == "quests" and not row.right and 305 or 207)
            widget.left:SetHeight(source and 13 or 24)
            widget.left:SetText(name or "")
            widget.left:SetTextColor(unpack(color))
            widget.source:SetPoint("TOPLEFT", id and 30 or 7, -12)
            widget.source:SetWidth(id and 161 or 207)
            widget.source:SetText(source or "")
            widget.right:SetText(row.right or "")
        end
        widget:SetShown(row ~= nil)
    end
    f.counter:SetText(#rows > 0 and ("%d–%d / %d"):format(offset + 1, math.min(offset + rowCount, #rows), #rows)
        or L("Keine Einträge verfügbar"))
    f.previous:SetEnabled(offset > 0)
    f.next:SetEnabled(offset + rowCount < #rows)
    f.listTitle:SetText(s.tab == "loot" and (s.boss or L("Alle Bosse")) or s.tab == "quests"
        and (quest and quest.title or L("Instanzquests")) or L("Bossreihenfolge"))
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

local function drawMapTiles(view, tiles, mapWidth, mapHeight)
    for index, file in ipairs(tiles) do
        local texture = artTexture(view, index)
        if texture:SetTexture(file) == false then return 0 end
        local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
        local w, h = math.min(256, 1002 - column * 256), math.min(256, 668 - row * 256)
        texture:SetTexCoord(0, w / 256, 0, h / 256)
        texture:SetSize(w * mapWidth / 1002, h * mapHeight / 668)
        texture:SetPoint("TOPLEFT", view, "TOPLEFT", column * 256 * mapWidth / 1002, -row * 256 * mapHeight / 668)
        texture:SetDrawLayer("ARTWORK", 0)
        texture:Show()
    end
    return #tiles
end

local function drawMinimapTiles(view, tiles, mapWidth, mapHeight)
    local used = 0
    for _, part in ipairs(tiles) do
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
    return used
end

local function renderArt(view, floor, mapWidth, mapHeight)
    local used = 0
    if floor then
        used = drawMapTiles(view, floor.tiles, mapWidth, mapHeight)
        if used == 0 then used = drawMinimapTiles(view, floor.art, mapWidth, mapHeight) end
    end
    for index = used + 1, #view.art do view.art[index]:Hide() end
    return used > 0
end

local function createBossPin(view, openBoss)
    local pin = CreateFrame("Button", nil, view.markers)
    pin:SetSize(30, 30)
    pin.ring = pin:CreateTexture(nil, "BACKGROUND")
    pin.ring:SetAllPoints()
    pin.ring:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    pin.fill = pin:CreateTexture(nil, "BORDER")
    pin.fill:SetSize(26, 26)
    pin.fill:SetPoint("CENTER")
    pin.fill:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    pin.fill:SetVertexColor(.13, .09, .06)
    pin.portrait = pin:CreateTexture(nil, "ARTWORK")
    pin.portrait:SetSize(24, 24)
    pin.portrait:SetPoint("CENTER")
    pin.badge = pin:CreateTexture(nil, "OVERLAY", nil, -1)
    pin.badge:SetSize(15, 15)
    pin.badge:SetPoint("BOTTOMRIGHT", 3, -3)
    pin.badge:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    pin.badge:SetVertexColor(.18, .11, .05)
    pin.rank = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pin.rank:SetPoint("CENTER", pin.badge, "CENTER")
    pin.check = pin:CreateTexture(nil, "OVERLAY")
    pin.check:SetSize(15, 15)
    pin.check:SetPoint("CENTER", pin.badge, "CENTER")
    pin.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    pin:SetScript("OnClick", function(self) openBoss(self.stop) end)
    pin:SetScript("OnEnter", function(self)
        if not GameTooltip or GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(guide.Name(self.stop), unpack(style.gold))
        if self.check:IsShown() then GameTooltip:AddLine(L("Besiegt"), unpack(style.green)) end
        if self.stop.loot then GameTooltip:AddLine(L("Linksklick zeigt die Beute."), unpack(style.cream)) end
        GameTooltip:Show()
    end)
    local function hideTip(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    pin:SetScript("OnLeave", hideTip)
    pin:SetScript("OnHide", hideTip)
    return pin
end

local function renderBossPin(pin, stop, index, defeated, highlight)
    pin.stop = stop
    if pin.display ~= (stop.display or false) then
        pin.display = stop.display or false
        local ok, result
        if stop.display and SetPortraitTextureFromCreatureDisplayID then
            ok, result = pcall(SetPortraitTextureFromCreatureDisplayID, pin.portrait, stop.display)
        end
        if not ok or result == false then
            pin.portrait:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        end
    end
    pin.portrait:SetDesaturated(defeated == true)
    pin.ring:SetVertexColor(unpack(defeated and style.green or highlight and style.cream or style.gold))
    pin.badge:SetShown(defeated == true or not stop.alternate)
    pin.rank:SetShown(not defeated and not stop.alternate)
    pin.rank:SetText(index)
    pin.check:SetShown(defeated == true)
end

local roomCorners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }

local function renderPlayerRoom(view, room, floor)
    local text = room and app.LF("Bereich · %s", guide.Name(room))
    local status = view.roomStatus
    if status.message ~= text then
        status.message = text
        status.text:SetText(text or "")
        status:SetShown(text ~= nil)
    end
    local shapes = room and floor == view.positionFloor and room.shapes[floor] or nil
    local w, h = view:GetSize()
    local layer = view.roomLayer
    if shapes == layer.shapes and w == layer.width and h == layer.height then return end
    layer.shapes, layer.width, layer.height = shapes, w, h
    local used = 0
    for _, box in ipairs(shapes or {}) do
        local cos, sin = math.cos(box[6]), math.sin(box[6])
        local points = {}
        for index, corner in ipairs(roomCorners) do
            local x, y = corner[1] * box[4] / 2, corner[2] * box[5] / 2
            local px = box[2] * w + (x * cos - y * sin) * w / 1002
            local py = -box[3] * h - (x * sin + y * cos) * h / 668
            points[index] = { px, py }
        end
        for i, point in ipairs(points) do
            local nextPoint = points[i % 4 + 1]
            used = used + 1
            local line = layer.lines[used]
            if not line then
                line = layer:CreateLine(nil, "ARTWORK")
                line:SetThickness(2)
                line:SetColorTexture(style.gold[1], style.gold[2], style.gold[3], .68)
                layer.lines[used] = line
            end
            line:SetStartPoint("TOPLEFT", view, point[1], point[2])
            line:SetEndPoint("TOPLEFT", view, nextPoint[1], nextPoint[2])
            line:Show()
        end
    end
    for i = used + 1, #layer.lines do layer.lines[i]:Hide() end
end

local function updatePlayerMarker(view, follow)
    local marker = view.player
    local floor, x, y, facing = guide.PlayerPosition(view.positionEntry, view.positionFloor)
    if not floor then
        local room, roomFloor = guide.PlayerRoom(view.positionEntry, view.positionFloor)
        if roomFloor and roomFloor ~= view.positionFloor and follow and view.followFloor then
            view.followFloor(roomFloor)
        end
        marker:Hide()
        renderPlayerRoom(view, room, roomFloor)
        return
    end
    renderPlayerRoom(view)
    if floor ~= view.positionFloor and follow and view.followFloor then
        view.followFloor(floor)
    end
    if floor ~= view.positionFloor then marker:Hide(); return end
    if facing then marker.arrow:SetRotation(facing) end
    marker.arrow:SetShown(facing ~= nil)
    marker.dot:SetShown(facing == nil)
    marker:ClearAllPoints()
    marker:SetPoint("CENTER", view, "TOPLEFT", x * view:GetWidth(), -y * view:GetHeight())
    marker:Show()
end

local function scrollMap(viewport, view, x, y)
    local width, height = viewport:GetSize()
    x = math.max(0, math.min(x, view:GetWidth() - width))
    y = math.max(0, math.min(y, view:GetHeight() - height))
    if viewport:GetHorizontalScroll() ~= x then viewport:SetHorizontalScroll(x) end
    if viewport:GetVerticalScroll() ~= y then viewport:SetVerticalScroll(y) end
end

local function stopMapDrag(viewport)
    viewport:SetScript("OnUpdate", nil)
end

local function layoutMap(viewport, view, x, y)
    local width, height = viewport:GetSize()
    if x == nil then
        x, y = viewport:GetHorizontalScroll(), viewport:GetVerticalScroll()
        local oldWidth, oldHeight = viewport.layoutWidth, viewport.layoutHeight
        -- Keep the same point centered when the surrounding window is resized.
        if oldWidth and oldWidth ~= width then x = (x + oldWidth / 2) * width / oldWidth - width / 2 end
        if oldHeight and oldHeight ~= height then y = (y + oldHeight / 2) * height / oldHeight - height / 2 end
    end
    viewport.layoutWidth, viewport.layoutHeight = width, height
    local zoom = mapZoomLevels[viewport.zoomLevel]
    local scaledWidth, scaledHeight = width * zoom, height * zoom
    if view:GetWidth() ~= scaledWidth or view:GetHeight() ~= scaledHeight then
        view:SetSize(scaledWidth, scaledHeight)
        viewport:UpdateScrollChildRect()
    end
    scrollMap(viewport, view, x, y)
    return scaledWidth, scaledHeight
end

local function renderMap(f, s)
    local view, entry = f.map, s.entry
    local viewport = f.viewport
    f.mapSelection = s
    local mapWidth, mapHeight
    if view.positionEntry ~= entry or view.positionFloor ~= s.floor then
        viewport.zoomLevel = 1
        stopMapDrag(viewport)
        mapWidth, mapHeight = layoutMap(viewport, view, 0, 0)
    else
        mapWidth, mapHeight = layoutMap(viewport, view)
    end
    local floor = guide.floors[s.floor]
    local art = renderArt(view, floor, mapWidth, mapHeight)
    view:SetFrameLevel(viewport:GetFrameLevel() + 1)
    view.roomLayer:SetFrameLevel(view:GetFrameLevel() + 1)
    view.overlay:SetFrameLevel(view:GetFrameLevel() + 2)
    view.markers:SetFrameLevel(view:GetFrameLevel() + 3)
    view.player:SetFrameLevel(view:GetFrameLevel() + 6)
    view.roomStatus:SetFrameLevel(view:GetFrameLevel() + 7)
    view.roomStatus:SetWidth(math.max(1, math.min(300, viewport:GetWidth() - 10)))
    view.positionEntry, view.positionFloor = entry, s.floor
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
            local pin = view.pins[pinCount] or createBossPin(view, f.openBoss)
            view.pins[pinCount] = pin
            pin:SetFrameLevel(view.markers:GetFrameLevel() + 1)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", view, "TOPLEFT", stop.x * mapWidth, -stop.y * mapHeight)
            renderBossPin(pin, stop, index, guide.IsDefeated(entry, index), s.highlight == index)
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
    updatePlayerMarker(view)
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
    if drawMap then renderMap(page, s) end
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

function guide.ToggleMap(entry, floor)
    if page and page:IsVisible() and current().entry == entry and current().tab == "map" then
        app.CloseDashboard("instances")
    else
        guide.Open(entry.key, "map", floor)
    end
end

local function createMap(f, parent)
    local viewport = CreateFrame("ScrollFrame", nil, parent, "BackdropTemplate")
    style.Panel(viewport, style.background)
    viewport.zoomLevel = 1
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    local view = CreateFrame("Frame", nil, viewport)
    view:SetSize(1, 1)
    viewport:SetScrollChild(view)
    f.viewport, f.map = viewport, view
    view.art, view.lines, view.pins = {}, {}, {}
    view.roomLayer = CreateFrame("Frame", nil, view)
    view.roomLayer:SetAllPoints(view)
    view.roomLayer.lines = {}
    view.overlay = CreateFrame("Frame", nil, view)
    view.overlay:SetAllPoints(view)
    view.markers = CreateFrame("Frame", nil, view)
    view.markers:SetAllPoints(view)
    local player = CreateFrame("Frame", nil, view)
    player:SetSize(27, 27)
    player:Hide()
    view.player = player
    player.arrow = player:CreateTexture(nil, "OVERLAY")
    player.arrow:SetAllPoints()
    player.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    player.dot = player:CreateTexture(nil, "OVERLAY")
    player.dot:SetPoint("CENTER")
    player.dot:SetSize(10, 10)
    player.dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    player.dot:SetVertexColor(.43, .92, 1)
    local status = CreateFrame("Frame", nil, viewport, "BackdropTemplate")
    style.Panel(status, style.background, style.edge)
    status:SetSize(300, 22)
    status:SetPoint("TOP", viewport, "TOP", 0, -5)
    status:Hide()
    status.text = style.Label(status, "", 0, 0, 292, 22, "GameFontHighlightSmall", style.gold, "CENTER")
    status.text:ClearAllPoints()
    status.text:SetPoint("TOPLEFT", status, "TOPLEFT", 4, 0)
    status.text:SetPoint("BOTTOMRIGHT", status, "BOTTOMRIGHT", -4, 0)
    view.roomStatus = status
    local elapsed = 0
    view:SetScript("OnUpdate", function(self, delta)
        if not self.positionEntry then return end
        elapsed = elapsed + delta
        if elapsed < .05 then return end
        elapsed = 0
        updatePlayerMarker(self, true)
    end)
    view:SetScript("OnHide", function() player:Hide() end)
    viewport:SetScript("OnMouseWheel", function(self, delta)
        if delta == 0 or not f.mapSelection then return end
        local index = self.zoomLevel
        local nextIndex = math.max(1, math.min(#mapZoomLevels, index + (delta > 0 and 1 or -1)))
        if nextIndex == index then return end
        stopMapDrag(self)
        local x, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        local w, h = self:GetSize()
        local left, top = self:GetLeft(), self:GetTop()
        x = left and math.max(0, math.min(w, x / scale - left)) or w / 2
        y = top and math.max(0, math.min(h, top - y / scale)) or h / 2
        local ratio = mapZoomLevels[nextIndex] / mapZoomLevels[index]
        self.zoomLevel = nextIndex
        layoutMap(self, view, (self:GetHorizontalScroll() + x) * ratio - x,
            (self:GetVerticalScroll() + y) * ratio - y)
        renderMap(f, f.mapSelection)
    end)
    viewport:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton ~= "LeftButton" or self.zoomLevel == 1 then return end
        local startX, startY = GetCursorPosition()
        local scrollX, scrollY = self:GetHorizontalScroll(), self:GetVerticalScroll()
        self:SetScript("OnUpdate", function()
            if read(IsMouseButtonDown, "LeftButton") == false then stopMapDrag(self); return end
            local x, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            scrollMap(self, view, scrollX + (startX - x) / scale, scrollY + (y - startY) / scale)
        end)
    end)
    viewport:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "LeftButton" then stopMapDrag(self) end
    end)
    viewport:SetScript("OnHide", stopMapDrag)
end

function guide.GetPage(parent)
    if page then return page end
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    f:Hide()
    page = f
    f.title = style.Label(f, "", 16, -9, 530, 27, "GameFontNormalLarge", style.gold)
    f.level = style.Label(f, "", 16, -39, 530, 19, "GameFontHighlightSmall", style.muted)
    f.worldMap = button(f, "Weltkarte", 558, -13, 126, function()
        local entry = current().entry
        guide.OpenWorldMap(entry.entrance and entry.entrance[1] or entry.area)
    end)
    button(f, "Instanz wählen", 691, -13, 140, function(self)
        menu(self, function(root)
            for _, section in ipairs({ { L("Instanzen"), false }, { L("Schlachtzüge"), true } }) do
                local group = root:CreateButton(section[1])
                if group.SetScrollMode then group:SetScrollMode(350) end
                for _, entry in ipairs(guide.entries) do
                    if (entry.raid == true) == section[2] then
                    group:CreateButton(guide.Name(entry), function()
                        guide.Open(entry.key, current().tab == "quests" and "quests" or nil)
                    end)
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
    createMap(f, f)
    f.openBoss = function(stop) showLoot(stop.loot or stop.name) end
    f.viewport:SetSize(mapWidth, mapHeight)
    f.viewport:SetPoint("TOPLEFT", 16, -98)
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
    f.questProgress = style.Label(panel, "", 10, -28, 322, 20, "GameFontHighlightSmall", style.cream)
    f.dropTitle = style.Label(panel, "Dropchance", 200, -33, 64, 18, "GameFontHighlightSmall", style.muted, "RIGHT")
    f.upgradeTitle = style.Label(panel, "Upgrade %", 272, -33, 58, 18, "GameFontHighlightSmall", style.muted, "RIGHT")
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
        row:SetSize(326, 24)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(19, 19)
        row.icon:SetPoint("LEFT", 5, 0)
        row.left = style.Label(row, "", 7, 0, 207, 24, "GameFontHighlightSmall", style.cream)
        row.source = style.Label(row, "", 30, -12, 161, 11, "GameFontDisableSmall", style.muted)
        row.right = style.Label(row, "", 216, 0, 104, 24, "GameFontHighlightSmall", style.muted, "RIGHT")
        row.drop = style.Label(row, "", 192, 0, 64, 24, "GameFontHighlightSmall", style.muted, "RIGHT")
        row.upgrade = style.Label(row, "", 264, 0, 58, 24, "GameFontHighlightSmall", style.muted, "RIGHT")
        row:SetScript("OnEnter", function(self)
            if not self.row or not (self.row.item or self.row.tip) or not GameTooltip or GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.link then GameTooltip:SetHyperlink(self.link)
            elseif self.row.item and GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.row.item)
            elseif self.row.tip then
                GameTooltip:SetText(self.row.tip.title)
                if self.row.tip.text then GameTooltip:AddLine(self.row.tip.text, 1, 1, 1, true) end
            end
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

local function changeWorldFloor(delta)
    local state = worldView
    for index, floor in ipairs(state.selection.entry.floors) do
        if floor == state.selection.floor then
            state.manualFloor = state.selection.entry.floors[index + delta]
            guide.UpdateWorldOverlay(state.owner)
            return
        end
    end
end

local function createWorldOverlay(map)
    local host = map.ScrollContainer
    local panel = CreateFrame("Frame", nil, map, "BackdropTemplate")
    panel:SetAllPoints(host)
    panel:EnableMouse(true)
    style.Panel(panel, style.background)
    local state = { owner = map, host = host, panel = panel }
    createMap(state, panel)
    state.viewport:SetPoint("CENTER", panel, "CENTER", 0, -4)
    state.map.followFloor = function(floor)
        if state.manualFloor or state.manualEntry then return end
        state.positionFloor, state.selection.floor = floor, floor
        renderMap(state, state.selection)
    end
    state.title = style.Label(panel, "", 12, -7, 350, 26, "GameFontNormal", style.gold)
    state.floorName = style.Label(panel, "", 45, 0, 300, 23, "GameFontHighlightSmall", style.cream)
    state.floorName:ClearAllPoints()
    state.floorName:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 46, 8)
    state.mapNote = style.Label(panel, "", 0, 0, 175, 22, "GameFontHighlightSmall", style.muted, "RIGHT")
    state.mapNote:ClearAllPoints()
    state.mapNote:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -45, 8)
    state.prevFloor = button(panel, "<", 0, 0, 25, function() changeWorldFloor(-1) end)
    state.prevFloor:ClearAllPoints()
    state.prevFloor:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 11, 8)
    state.nextFloor = button(panel, ">", 0, 0, 25, function() changeWorldFloor(1) end)
    state.nextFloor:ClearAllPoints()
    state.nextFloor:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 8)
    state.wings = button(panel, "Flügel", 0, 0, 76, function(self)
        menu(self, function(root)
            for _, entry in ipairs(state.candidates) do
                root:CreateButton(guide.Name(entry), function()
                    state.manualEntry, state.manualFloor = entry, nil
                    guide.RememberWing(entry)
                    guide.UpdateWorldOverlay(map)
                end)
            end
        end)
    end)
    state.wings:ClearAllPoints()
    state.wings:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -146, -6)
    state.switch = button(map, "Weltkarte", 0, 0, 126, function()
        state.outdoor = not state.outdoor
        guide.UpdateWorldOverlay(map)
    end)
    state.switch:ClearAllPoints()
    state.switch:SetPoint("TOPRIGHT", host, "TOPRIGHT", -10, -6)
    state.openBoss = function(stop)
        local entry, floor = state.selection.entry, state.selection.floor
        if HideUIPanel then HideUIPanel(map) elseif map.Hide then map:Hide() end
        guide.Open(entry.key, "loot", floor, stop.loot or stop.name)
    end
    return state
end

function guide.ResetWorldOverlay()
    outdoorRequested = nil
    if worldView then
        worldView.outdoor, worldView.manualEntry, worldView.manualFloor = nil, nil, nil
        worldView.positionFloor = nil
    end
end

function guide.UseOutdoorMap()
    if guide.CurrentMap() then
        outdoorRequested = true
        app.worldMap.Refresh()
    end
end

function guide.UpdateWorldOverlay(map)
    local entry, floor, candidates = guide.CurrentMap()
    local enabled = entry and map:IsVisible() and app.comfort.Enabled("mapInterior")
    if not enabled then
        app.worldMap.SetMarkerLayerCovered(map, false)
        if worldView then
            worldView.panel:Hide()
            worldView.switch:Hide()
        end
        return
    end
    worldView = worldView or createWorldOverlay(map)
    local state = worldView
    if outdoorRequested then state.outdoor, outdoorRequested = true, nil end
    if state.detectedEntry ~= entry or state.detectedFloor ~= floor then
        state.detectedEntry, state.detectedFloor = entry, floor
        state.manualEntry, state.manualFloor = nil, nil
        state.positionFloor = nil
    end
    local level = math.max(map:GetFrameLevel(), state.host:GetFrameLevel()) + 100
    state.panel:SetFrameStrata(map:GetFrameStrata())
    state.panel:SetFrameLevel(level)
    state.switch:SetFrameStrata(map:GetFrameStrata())
    state.switch:SetFrameLevel(level + 20)
    state.switch:SetText(L(state.outdoor and "Instanzkarte" or "Weltkarte"))
    state.switch:Show()
    state.panel:SetShown(not state.outdoor)
    app.worldMap.SetMarkerLayerCovered(map, not state.outdoor)
    if state.outdoor then return end
    local width, height = state.host:GetSize()
    local fit = math.min((width - 16) / 3, (height - 72) / 2)
    if fit <= 0 then return end
    state.candidates = candidates
    local selected = state.manualEntry or entry
    local selectedFloor = state.manualFloor or (selected == entry and (state.positionFloor or floor)) or selected.floors[1]
    state.selection = { entry = selected, floor = selectedFloor, tab = "map" }
    state.title:SetWidth(math.max(1, math.min(350, width - 234)))
    state.title:SetText(guide.Name(selected))
    state.viewport:SetFrameLevel(level + 2)
    state.viewport:SetSize(fit * 3, fit * 2)
    state.wings:SetShown(#candidates > 1)
    renderMap(state, state.selection)
end
