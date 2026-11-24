local _, app = ...
-- Paulchen's standalone dungeon quest planner.
-- Independent MIT-licensed quest reference pack, no Polestar dependency.
-- Unknown prerequisites or unreadable player progress are never guessed.
local planner = {}
app.dungeonQuests = planner

local style, readable = app.style, app.Readable
local frame, copyFrame, selectedDungeon, selectedQuest
local dungeonOffset, questOffset, chainOffset = 0, 0, 0
local dungeonFilter, questFilter = "", ""
local showCompleted = true
local snapshot, planned, updateQueued

local function L(de, en)
    return app.GetLanguage and app.GetLanguage() == "enUS" and en or de
end

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then
        if readable then return readable(result) end
        return result
    end
end

local function dataSource()
    local d = app.DungeonQuestData
    if type(d) ~= "table" or type(d.List) ~= "function"
        or type(d.Quests) ~= "function" or type(d.Quest) ~= "function" then return nil, "missing" end
    if type(d.Load) == "function" then
        local ok, result, reason = pcall(d.Load)
        if not ok then return nil, "error" end
        if result == false then return nil, reason or "nodata" end
    end
    return d
end

local function side()
    local faction = safe(UnitFactionGroup, "player")
    return faction == "Horde" and "H" or faction == "Alliance" and "A" or nil
end

local function questDone(id)
    if type(id) ~= "number" then return nil end
    local c = C_QuestLog
    local done = safe(c and c.IsQuestFlaggedCompleted, id)
    if type(done) == "boolean" then return done end
    return nil -- Never guess completion from an empty or protected client API.
end

local function questInLog(id)
    if type(id) ~= "number" then return nil end
    local c = C_QuestLog
    local result = safe(c and c.IsOnQuest, id)
    if type(result) == "boolean" then return result end
    if c and c.GetNumQuestLogEntries and c.GetInfo then
        local n = safe(c.GetNumQuestLogEntries)
        if type(n) ~= "number" then return nil end
        for i = 1, n do
            local info = safe(c.GetInfo, i)
            if type(info) == "table" and not readable(info.isHeader)
                and readable(info.questID) == id then return true end
        end
        return false
    end
    return nil
end

local function eachID(value, callback)
    if type(value) == "number" then callback(value)
    elseif type(value) == "table" then
        for _, id in ipairs(value) do if type(id) == "number" then callback(id) end end
    end
end

local function prerequisiteState(id)
    local provider = app.DungeonQuestData
    local record = safe(provider and provider.Prerequisites, id)
    if type(record) ~= "table" then return nil end
    local incomplete, unknown = 0, false
    -- The Codex uses pre/preAll for required predecessor quests and preAny
    -- for alternative predecessors. Never interpret breadcrumb order as a hard gate.
    local seen = {}
    local function required(pre)
        eachID(pre, function(parent)
            if seen[parent] then return end
            seen[parent] = true
            local value = questDone(parent)
            if value == false then incomplete = incomplete + 1
            elseif value == nil then unknown = true end
        end)
    end
    required(record)
    if incomplete > 0 then return "LOCKED" end
    if unknown then return "UNKNOWN" end
    return "CLEAR"
end

local function status(id, entry, dungeons)
    local completed = questDone(id)
    if completed == true then return "DONE" end
    local inLog = questInLog(id)
    if inLog == true then
        if safe(C_QuestLog and C_QuestLog.ReadyForTurnIn, id) == true then return "READY" end
        return "ACTIVE"
    end
    if completed == nil or inLog == nil then return "UNKNOWN" end
    if type(entry) == "table" then
        if entry.faction and side() and entry.faction ~= side() then return "OTHER" end
        if dungeons and dungeons.QuestFor then
            local _, why
            local ok, a, b = pcall(dungeons.QuestFor, entry)
            if ok then _, why = a, b end
            if why == "class" or why == "race" then return "OTHER" end
        end
        local closed = false
        eachID(entry.closedBy, function(other)
            if questDone(other) == true or questInLog(other) == true then closed = true end
        end)
        if closed then return "CLOSED" end
        local level = safe(UnitLevel, "player")
        if type(level) == "number" and type(entry.minLevel) == "number" and level < entry.minLevel then
            return "LEVEL"
        end
    end
    local prereqs = prerequisiteState(id)
    if prereqs == "LOCKED" then return "LOCKED" end
    if prereqs == "UNKNOWN" then return "UNKNOWN" end
    -- Being not in the quest log does not prove the NPC currently offers it.
    return "NOT_STARTED"
end

local states = {
    DONE = { "Abgeschlossen", "Completed", { 0.45, 0.83, 0.48 } },
    READY = { "Abgabebereit", "Ready to turn in", { 0.85, 0.77, 0.35 } },
    ACTIVE = { "Im Questlog", "In quest log", { 0.39, 0.68, 1 } },
    LOCKED = { "Vorquests fehlen", "Prerequisites missing", { 1, 0.52, 0.39 } },
    LEVEL = { "Stufe zu niedrig", "Level too low", { 1, 0.52, 0.39 } },
    OTHER = { "Andere Klasse/Fraktion", "Wrong class/faction", { 0.62, 0.62, 0.62 } },
    CLOSED = { "Nicht mehr erhältlich", "No longer obtainable", { 0.62, 0.62, 0.62 } },
    NOT_STARTED = { "Nicht angenommen", "Not accepted", { 0.92, 0.83, 0.65 } },
    UNKNOWN = { "Status unbekannt", "Status unknown", { 0.64, 0.64, 0.67 } },
}
local function stateText(code)
    local row = states[code] or states.UNKNOWN
    return L(row[1], row[2])
end
local function stateColor(code)
    local row = states[code] or states.UNKNOWN
    return unpack(row[3])
end

local function addUnique(target, seen, value)
    if type(value) == "number" and value > 0 and not seen[value] then
        seen[value] = true
        target[#target + 1] = value
        return true
    end
    return false
end

local function makeChain(d, key, target, main)
    local ids, seen = {}, {}
    local function append(entry)
        if type(entry) ~= "table" then return end
        for _, id in ipairs(entry.chain or {}) do addUnique(ids, seen, id) end
        addUnique(ids, seen, entry.id)
    end
    append(target)
    -- Follow-ups are other dungeon quests whose chain shares an earlier step.
    -- Their prerequisites are not necessarily all strict requirements.
    for _ = 1, 3 do
        local expanded = false
        for _, entry in ipairs(main) do
            local connected = seen[entry.id]
            for _, id in ipairs(entry.chain or {}) do
                if seen[id] then connected = true; break end
            end
            if connected then
                local old = #ids
                append(entry)
                if #ids > old then expanded = true end
            end
        end
        if not expanded then break end
    end
    -- Keep Polestar's oldest-first chain order; never sort by quest ID.
    for _, entry in ipairs(main) do
        if seen[entry.id] and entry.id ~= target.id then
            for _, id in ipairs(entry.chain or {}) do
                if seen[id] then
                    local pos, prior
                    for i, value in ipairs(ids) do
                        if value == id then prior = i end
                        if value == entry.id then pos = i end
                    end
                    if prior and pos and prior > pos then
                        table.remove(ids, pos)
                        table.insert(ids, prior, entry.id)
                    end
                end
            end
        end
    end
    local rows, complete = {}, 0
    for _, id in ipairs(ids) do
        local entry = safe(d.Quest, key, id)
        local code = status(id, entry, d)
        if code == "DONE" then complete = complete + 1 end
        rows[#rows + 1] = { id = id, entry = entry, title = entry and entry.title or ("Quest #" .. id), status = code }
    end
    return rows, complete
end

function planner.ListDungeons()
    local d, reason = dataSource()
    if not d then return nil, reason end
    local list = safe(d.List)
    if type(list) ~= "table" then return nil, "nodata" end
    return list
end

function planner.Build(key)
    local d, reason = dataSource()
    if not d then return nil, reason end
    local list = safe(d.List)
    if type(list) ~= "table" then return nil, "nodata" end
    local dungeon
    for _, entry in ipairs(list) do if entry.key == key then dungeon = entry; break end end
    if not dungeon then return nil, "notfound" end
    local source = safe(d.Quests, key, side())
    if type(source) ~= "table" then return nil, "nodata" end
    local rows, done, active, unknown = {}, 0, 0, 0
    for _, entry in ipairs(source) do
        if type(entry) == "table" and type(entry.id) == "number" then
            local code = status(entry.id, entry, d)
            if code == "DONE" then done = done + 1 end
            if code == "ACTIVE" or code == "READY" then active = active + 1 end
            if code == "UNKNOWN" then unknown = unknown + 1 end
            rows[#rows + 1] = {
                id = entry.id, entry = entry, title = entry.title or ("Quest #" .. entry.id),
                giver = entry.start, ender = entry.finish,
                status = code, chainSize = #(entry.chain or {}),
            }
        end
    end
    return { dungeon = dungeon, quests = rows, done = done, active = active,
        unknown = unknown, provider = d, total = #rows, key = key }, nil
end

function planner.Chain(id, data)
    data = data or snapshot
    if not data then return {}, 0 end
    local q
    for _, row in ipairs(data.quests) do if row.id == id then q = row.entry; break end end
    if not q then q = safe(data.provider.Quest, data.key, id) end
    if not q then return {}, 0 end
    local source = {}
    for _, row in ipairs(data.quests) do source[#source + 1] = row.entry end
    return makeChain(data.provider, data.key, q, source)
end

local mapNames = {}
local function mapName(map)
    if type(map) ~= "number" then return nil end
    if mapNames[map] then return mapNames[map] end
    local info = safe(C_Map and C_Map.GetMapInfo, map)
    local name = info and app.Readable(info.name)
    if type(name) == "string" and name ~= "" then mapNames[map] = name end
    return name
end

local function pointText(point)
    if type(point) ~= "table" or point.kind == "unknown" then
        return L("Queststart / Abgabe nicht erfasst", "Quest start / turn-in not recorded")
    end
    local prefix = point.kind == "npc" and L("NPC", "NPC")
        or point.kind == "object" and L("Objekt", "Object")
        or point.kind == "item" and L("Gegenstand", "Item")
        or L("Queststart", "Quest start")
    local name = point.name or (point.id and ("#" .. point.id)) or L("Unbekannt", "Unknown")
    local result = prefix .. ": " .. name
    if type(point.x) == "number" and type(point.y) == "number"
        and type(point.map) == "number" then
        local x, y = point.x, point.y
        if x <= 1 and y <= 1 then x, y = x * 100, y * 100 end
        result = result .. (" · %s (%.1f, %.1f)"):format(mapName(point.map) or
            ("Map #" .. point.map), x, y)
        if point.observed then
            result = result .. L(" · bei NPC-Kontakt erfasst", " · observed during NPC interaction")
        end
    elseif point.inside then
        result = result .. L(" · in der Instanz, genaue Position unbekannt",
            " · inside dungeon, exact position unknown")
    elseif point.kind == "item" or point.kind == "object" then
        result = result .. L(" · Fundort nicht erfasst", " · source location not recorded")
    else
        result = result .. L(" · Standort nicht erfasst", " · location not recorded")
    end
    return result
end

local function multiplePointText(points, fallback)
    if type(points) ~= "table" or #points == 0 then return pointText(fallback) end
    local out = {}
    for _, point in ipairs(points) do out[#out+1] = pointText(point) end
    return table.concat(out, "; ")
end

local function exportText(data)
    local out = { data.dungeon.name .. " – " .. L("Instanzquests", "Dungeon Quests") }
    out[#out+1] = ("%d/%d %s"):format(data.done, data.total, L("abgeschlossen", "completed"))
    for _, row in ipairs(data.quests) do
        out[#out+1] = ("[%s] %s (#%d)"):format(stateText(row.status), row.title, row.id)
        out[#out+1] = "  " .. L("Questgeber", "Quest giver") .. ": " .. multiplePointText(row.entry and row.entry.givers, row.giver)
        out[#out+1] = "  " .. L("Abgabe", "Turn-in") .. ": " .. multiplePointText(row.entry and row.entry.enders, row.ender)
        local chain = planner.Chain(row.id, data)
        if #chain > 1 then
            local steps = {}
            for _, step in ipairs(chain) do
                steps[#steps+1] = step.title .. " [" .. stateText(step.status) .. "]"
                    .. " {" .. pointText(step.entry and step.entry.start) .. "}"
            end
            out[#out+1] = "  " .. L("Questreihe", "Quest chain") .. ": " .. table.concat(steps, " > ")
        end
    end
    return table.concat(out, "\n")
end

local function styledButton(parent, caption, x, y, width, callback)
    local button = style.TextButton(parent)
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width, 24)
    button:SetText(caption)
    if callback then button:SetScript("OnClick", callback) end
    return button
end

local function label(parent, value, x, y, width, height, color, font)
    return style.Label(parent, value, x, y, width, height,
        font or "GameFontHighlightSmall", color or style.cream)
end

local function showExport()
    if not snapshot then return end
    if not copyFrame then
        local f = CreateFrame("Frame", "PaulchenDungeonQuestExport", UIParent, "BackdropTemplate")
        f:SetSize(780, 570)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        style.Panel(f, style.background)
        f:Hide()
        label(f, L("Questliste kopieren (Strg+C)", "Copy Quest List (Ctrl+C)"),
            15, -12, 720, 25, style.gold, "GameFontNormalLarge")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT")
        close:SetScript("OnClick", function() f:Hide() end)
        local scroll = CreateFrame("ScrollFrame", "PaulchenDungeonQuestExportScroll", f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -50)
        scroll:SetPoint("BOTTOMRIGHT", -36, 15)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject("GameFontHighlightSmall")
        edit:SetAutoFocus(false)
        edit:SetWidth(720)
        edit:SetHeight(500)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        edit:SetScript("OnTextChanged", function(self)
            self:SetHeight(math.max(500, self:GetStringHeight()+20))
        end)
        scroll:SetScrollChild(edit)
        f.edit = edit
        f:SetScript("OnHide", function() edit:ClearFocus() end)
        UISpecialFrames[#UISpecialFrames+1] = f:GetName()
        copyFrame = f
    end
    copyFrame.edit:SetText(exportText(snapshot))
    copyFrame:Show()
    copyFrame.edit:SetFocus()
    copyFrame.edit:HighlightText()
end

local function openRoute(point, labelText)
    if type(point) ~= "table" or not point.map or point.x == nil or point.y == nil then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local d = snapshot and snapshot.provider
    if d and type(d.GuideToPoint) == "function" then
        safe(d.GuideToPoint, point, labelText or point.name)
    end
end

local function questMatches(row)
    if not showCompleted and row.status == "DONE" then return false end
    local q = questFilter:lower()
    return q == "" or row.title:lower():find(q, 1, true) ~= nil
        or tostring(row.id):find(q, 1, true) ~= nil
        or (row.giver and row.giver.name and row.giver.name:lower():find(q, 1, true) ~= nil)
end

local function render()
    if not frame or not frame:IsShown() then return end
    local available, reason = planner.ListDungeons()
    if not available then
        frame.note:SetText(L("Instanzdaten fehlen. Die integrierte Questdatenbank konnte nicht geladen werden.",
            "Dungeon data unavailable. The bundled quest data could not be loaded.")
            .. (reason and (" [" .. tostring(reason) .. "]") or ""))
        frame.summary:SetText("")
        for _, row in ipairs(frame.dungeonRows) do row:Hide() end
        for _, row in ipairs(frame.questRows) do row:Hide() end
        for _, row in ipairs(frame.chainRows) do row:Hide() end
        return
    end
    local matches = {}
    for _, dungeon in ipairs(available) do
        if dungeon.name and (dungeonFilter == "" or dungeon.name:lower():find(dungeonFilter:lower(), 1, true)) then
            matches[#matches+1] = dungeon
        end
    end
    if not selectedDungeon and matches[1] then selectedDungeon = matches[1].key end
    dungeonOffset = math.max(0, math.min(dungeonOffset, math.max(0, #matches - #frame.dungeonRows)))
    for index, row in ipairs(frame.dungeonRows) do
        local d = matches[index + dungeonOffset]
        row.dungeon = d
        row:SetShown(d ~= nil)
        if d then
            row:SetText((d.key == selectedDungeon and "• " or "") .. d.name)
        end
    end
    snapshot = nil
    if selectedDungeon then snapshot, reason = planner.Build(selectedDungeon) end
    if not snapshot then
        frame.note:SetText(L("Keine Questdaten für die ausgewählte Instanz.",
            "No quest data for the selected dungeon."))
        frame.summary:SetText("")
        for _, row in ipairs(frame.questRows) do row:Hide() end
        for _, row in ipairs(frame.chainRows) do row:Hide() end
        return
    end
    frame.title:SetText(snapshot.dungeon.name .. " – " .. L("Quests", "Quests"))
    frame.summary:SetText(("%d %s · %d %s · %d %s · %d %s"):format(snapshot.total,
        L("Quests", "quests"), snapshot.done, L("abgeschlossen", "completed"),
        snapshot.active, L("aktiv", "active"), snapshot.unknown, L("unbekannt", "unknown")))
    frame.note:SetText(snapshot.dungeon.incomplete
        and L("Für diese Instanz fehlen noch erfasste Quests (Datenstand Oktober 2026).",
            "No quests catalogued yet for this dungeon (October 2026 dataset).")
        or L("Eigenständige Questdatenbank (MIT, Stand 2026-10). Neuere Forever-Quests können fehlen.",
            "Built-in quest data (MIT, Oct 2026). Newer Forever quests may be missing."))
    local filtered = {}
    for _, row in ipairs(snapshot.quests) do if questMatches(row) then filtered[#filtered+1] = row end end
    questOffset = math.max(0, math.min(questOffset, math.max(0, #filtered - #frame.questRows)))
    if selectedQuest then
        local exists = false
        for _, row in ipairs(snapshot.quests) do
            if row.id == selectedQuest then exists = true; break end
            for _, prior in ipairs(row.entry.chain or {}) do
                if prior == selectedQuest then exists = true; break end
            end
            if exists then break end
        end
        if not exists then selectedQuest = nil end
    end
    if not selectedQuest and snapshot.quests[1] then selectedQuest = snapshot.quests[1].id end
    for index, row in ipairs(frame.questRows) do
        local item = filtered[index + questOffset]
        row.data = item
        row:SetShown(item ~= nil)
        if item then
            row.title:SetText((item.id == selectedQuest and "› " or "") .. item.title)
            row.state:SetText(stateText(item.status))
            row.state:SetTextColor(stateColor(item.status))
            local giver = item.giver
            if giver and giver.map and giver.x ~= nil then
                row.giver:SetText(giver.name or L("Koordinaten bekannt", "Coordinates known"))
            elseif giver and giver.inside then
                row.giver:SetText(L("In der Instanz", "Inside dungeon"))
            elseif giver and giver.kind == "unknown" then
                row.giver:SetText(L("Questgeber unbekannt", "Unknown quest giver"))
            else
                row.giver:SetText(giver and giver.name or L("Questgeber unbekannt", "Unknown quest giver"))
            end
        end
    end
    local selected
    for _, row in ipairs(snapshot.quests) do
        if row.id == selectedQuest then selected = row; break end
    end
    if not selected and selectedQuest then
        local entry = safe(snapshot.provider.Quest, snapshot.key, selectedQuest)
        if entry then
            selected = { id = selectedQuest, title = entry.title or ("Quest #" .. selectedQuest),
                giver = entry.start, ender = entry.finish, entry = entry,
                status = status(selectedQuest, entry, snapshot.provider) }
        end
    end
    local chain, completed = {}, 0
    if selected then chain, completed = planner.Chain(selectedQuest, snapshot) end
    frame.selected:SetText(selected and (selected.title .. " (#" .. selected.id .. ")") or "")
    frame.questgiver:SetText(selected and (L("Questgeber: ", "Quest giver: ") .. multiplePointText(selected.entry and selected.entry.givers, selected.giver)) or "")
    frame.ender:SetText(selected and (L("Abgabe bei: ", "Turn in to: ") .. multiplePointText(selected.entry and selected.entry.enders, selected.ender)) or "")
    frame.gotoGiver:SetEnabled(not not (selected and selected.giver and selected.giver.map
        and selected.giver.x ~= nil and selected.giver.y ~= nil))
    frame.gotoEnder:SetEnabled(not not (selected and selected.ender and selected.ender.map
        and selected.ender.x ~= nil and selected.ender.y ~= nil))
    frame.chainSummary:SetText(#chain > 0 and (L("Questreihe", "Quest chain") .. ": " .. completed .. "/" .. #chain ..
        " " .. L("abgeschlossen", "completed") .. " · " .. L("Reihenfolge laut Quelldaten, nicht immer Pflicht-Vorquests.",
        "Source order; not every preceding step is mandatory.")) or "")
    chainOffset = math.max(0, math.min(chainOffset, math.max(0, #chain - #frame.chainRows)))
    for index, row in ipairs(frame.chainRows) do
        local step = chain[index + chainOffset]
        row.step = step
        row:SetShown(step ~= nil)
        if step then
            row:SetText(("%d. [%s] %s"):format(index + chainOffset, stateText(step.status), step.title))
            local text = row.GetFontString and row:GetFontString()
            if text then text:SetTextColor(stateColor(step.status)) end
        end
    end
end

local function refresh()
    if frame and frame:IsShown() then render() end
end

function planner.Refresh()
    if updateQueued or not frame or not frame:IsShown() then return end
    updateQueued = true
    local function run()
        updateQueued = false
        if frame and frame:IsShown() then app.SecureCall("Instanzquests", refresh) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.3, run) else run() end
end

function planner.Open(key)
    if key ~= nil then selectedDungeon = key; selectedQuest = nil; questOffset = 0; chainOffset = 0 end
    if not frame then
        local f = CreateFrame("Frame", "PaulchenDungeonQuestPlanner", UIParent, "BackdropTemplate")
        frame = f
        f:Hide()
        f:SetSize(975, 715)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true)
        f:SetScale(math.min(1, (UIParent:GetWidth() - 20) / 975, (UIParent:GetHeight() - 20) / 715))
        style.Panel(f, style.background)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        label(f, L("Paulchens Instanz-Questplaner", "Paulchen's Dungeon Quest Planner"),
            18, -12, 860, 29, style.gold, "GameFontNormalLarge")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() f:Hide() end)
        label(f, L("Instanz", "Dungeon"), 17, -54, 205, 20, style.gold)
        label(f, L("Instanz suchen", "Search dungeon"), 17, -75, 205, 18, style.muted)
        local findDungeon = style.EditBox(f)
        findDungeon:SetPoint("TOPLEFT", 17, -96)
        findDungeon:SetSize(200, 24)
        findDungeon:SetScript("OnTextChanged", function(self)
            dungeonFilter = self:GetText() or ""
            dungeonOffset = 0
            render()
        end)
        f.dungeonRows = {}
        for i = 1, 17 do
            local row = styledButton(f, "", 17, -129 - (i-1)*29, 200, function(self)
                if self.dungeon then selectedDungeon = self.dungeon.key; selectedQuest = nil
                    questOffset, chainOffset = 0, 0; render() end
            end)
            f.dungeonRows[#f.dungeonRows+1] = row
        end
        styledButton(f, "▲", 17, -630, 96, function()
            dungeonOffset = math.max(0, dungeonOffset-10); render()
        end)
        styledButton(f, "▼", 121, -630, 96, function()
            dungeonOffset = dungeonOffset+10; render()
        end)
        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel", function(_, delta)
            dungeonOffset = math.max(0, dungeonOffset-delta*3); render()
        end)

        f.title = label(f, "", 237, -51, 714, 24, style.gold, "GameFontNormalLarge")
        f.summary = label(f, "", 237, -78, 714, 22, style.cream)
        f.note = label(f, "", 237, -106, 714, 20, style.muted)
        local search = style.EditBox(f)
        search:SetPoint("TOPLEFT", 237, -133)
        search:SetSize(320, 24)
        search:SetScript("OnTextChanged", function(self)
            questFilter = self:GetText() or ""
            questOffset = 0
            render()
        end)
        f.filter = styledButton(f, L("Erledigte ausblenden", "Hide completed"), 565, -133, 180, function(self)
            showCompleted = not showCompleted
            self:SetText(showCompleted and L("Erledigte ausblenden", "Hide completed")
                or L("Erledigte anzeigen", "Show completed"))
            questOffset = 0; render()
        end)
        styledButton(f, L("Liste kopieren", "Copy list"), 758, -133, 194, showExport)
        label(f, L("Quest", "Quest"), 240, -166, 350, 19, style.gold)
        label(f, L("Status", "Status"), 605, -166, 165, 19, style.gold)
        label(f, L("Questgeber", "Quest giver"), 776, -166, 171, 19, style.gold)
        f.questRows = {}
        for i = 1, 10 do
            local row = CreateFrame("Button", nil, f)
            row:SetPoint("TOPLEFT", 237, -188-(i-1)*29)
            row:SetSize(716, 28)
            style.Row(row, i)
            row.title = label(row, "", 6, -3, 350, 24, style.cream)
            row.state = label(row, "", 366, -3, 161, 24)
            row.giver = label(row, "", 538, -3, 172, 24, style.muted)
            row:SetScript("OnClick", function(self)
                if self.data then selectedQuest = self.data.id; chainOffset = 0; render() end
            end)
            row:SetScript("OnEnter", function(self)
                if not self.data then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.data.title, unpack(style.gold))
                GameTooltip:AddLine(stateText(self.data.status), stateColor(self.data.status))
                GameTooltip:AddLine(L("Questgeber: ", "Quest giver: ") .. multiplePointText(self.data.entry and self.data.entry.givers, self.data.giver), 1, 1, 1, true)
                GameTooltip:AddLine(L("Abgabe bei: ", "Turn in to: ") .. multiplePointText(self.data.entry and self.data.entry.enders, self.data.ender), 1, 1, 1, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.questRows[#f.questRows+1] = row
        end
        styledButton(f, "▲", 237, -484, 52, function()
            questOffset = math.max(0, questOffset-6); render()
        end)
        styledButton(f, "▼", 294, -484, 52, function()
            questOffset = questOffset+6; render()
        end)
        f.selected = label(f, "", 237, -519, 710, 22, style.gold)
        f.questgiver = label(f, "", 237, -543, 610, 20, style.cream)
        f.ender = label(f, "", 237, -564, 610, 20, style.cream)
        f.gotoGiver = styledButton(f, L("Zum Questgeber", "Go to quest giver"), 827, -542, 124, function()
            local entry = snapshot and safe(snapshot.provider.Quest, snapshot.key, selectedQuest)
            if entry then openRoute(entry.start, entry.title) end
        end)
        f.gotoEnder = styledButton(f, L("Zur Abgabe", "Go to turn-in"), 827, -569, 124, function()
            local entry = snapshot and safe(snapshot.provider.Quest, snapshot.key, selectedQuest)
            if entry then openRoute(entry.finish, entry.title) end
        end)
        f.chainSummary = label(f, "", 237, -596, 710, 21, style.muted)
        f.chainRows = {}
        for i = 1, 3 do
            local row = styledButton(f, "", 237, -621-(i-1)*25, 635, function(self)
                if self.step then selectedQuest = self.step.id; chainOffset = 0; render() end
            end)
            row:SetScript("OnEnter", function(self)
                local step = self.step
                if not step then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(step.title, unpack(style.gold))
                GameTooltip:AddLine(stateText(step.status), stateColor(step.status))
                GameTooltip:AddLine(L("Questgeber: ", "Quest giver: ")
                    .. multiplePointText(step.entry and step.entry.givers, step.entry and step.entry.start), 1, 1, 1, true)
                GameTooltip:AddLine(L("Abgabe bei: ", "Turn in to: ")
                    .. multiplePointText(step.entry and step.entry.enders, step.entry and step.entry.finish), 1, 1, 1, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.chainRows[#f.chainRows+1] = row
        end
        styledButton(f, "▲", 880, -621, 70, function()
            chainOffset = math.max(0, chainOffset-3); render()
        end)
        styledButton(f, "▼", 880, -652, 70, function()
            chainOffset = chainOffset+3; render()
        end)
        UISpecialFrames[#UISpecialFrames+1] = f:GetName()
        f:SetScript("OnShow", render)
    end
    frame:Show()
    render()
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_ACCEPTED",
    "QUEST_REMOVED", "PLAYER_LEVEL_UP", "QUEST_DATA_LOAD_RESULT", "ADDON_LOADED" }) do
    if app.RegisterSupported then app.RegisterSupported(eventFrame, event) end
end
eventFrame:SetScript("OnEvent", function() planner.Refresh() end)
