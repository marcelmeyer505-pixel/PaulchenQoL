local _, app = ...
local world, L = app.worldMap, app.L
local read, plain = app.ReadGameValue, app.Readable

local function providers()
    local journal, routes = _G.ForeverDungeonJournal_NS, _G.ForeverDungeonRoutes
    if not (journal and type(journal.DB) == "table") then journal = nil end
    if not (routes and type(routes.Dungeons) == "table") then routes = nil end
    return journal, routes
end

local function normalized(name)
    if type(name) ~= "string" then return end
    return name:lower():gsub("^the%s+", ""):gsub("[%s%p]", ""):gsub("’", "")
end

local function catalog(journal, routes)
    local entries, byName, byInstance = {}, {}, {}
    local function alias(entry, name)
        local key = normalized(name)
        if key and key ~= "" then
            local previous = byName[key]
            byName[key] = (previous == nil or previous == entry) and entry or false
        end
    end
    local function add(entry)
        entries[#entries + 1] = entry
        return entry
    end
    local guide = app.instances
    if guide then
        for _, dungeon in ipairs(guide.entries) do
            local at = dungeon.entrance
            local entry = add({
                guideKey = dungeon.key, instance = dungeon.id, name = guide.Name(dungeon),
                routeEntrance = at and { map = at[1], x = at[2], y = at[3] },
            })
            alias(entry, dungeon.name)
            alias(entry, dungeon.de)
            alias(entry, dungeon.key)
        end
        for _, entry in ipairs(entries) do
            if entry.instance then
                local previous = byInstance[entry.instance]
                byInstance[entry.instance] = previous == nil and entry or false
            end
        end
        return entries, byName, byInstance
    end
    if journal then
        local ids = {}
        for id, key in pairs(journal.INSTANCE_ID_TO_DUNGEON or {}) do ids[key] = id end
        for _, key in ipairs(journal.ORDER or {}) do
            local record = journal.DB[key]
            if record and (record.entrance or journal.DUNGEON_MAPS and journal.DUNGEON_MAPS[key]) then
                local entry = add({
                    journal = key, instance = ids[key], name = read(journal.LocalizeDungeonName, key) or key,
                    journalEntrance = record.entrance,
                })
                alias(entry, key)
                alias(entry, entry.name)
            end
        end
    end
    if routes then
        local count = {}
        for _, route in ipairs(routes.Dungeons) do
            if route.instanceID then count[route.instanceID] = (count[route.instanceID] or 0) + 1 end
        end
        for _, route in ipairs(routes.Dungeons) do
            local display = read(routes.GetKeyName, routes, route.key) or route.name or route.key
            local entry = byName[normalized(route.name)] or byName[normalized(display)]
            if not entry and route.instanceID and count[route.instanceID] == 1 then
                for _, candidate in ipairs(entries) do
                    if candidate.journal and candidate.instance == route.instanceID then
                        if entry then entry = nil; break end
                        entry = candidate
                    end
                end
            end
            -- Routes has one Stratholme route key. Journal has two dungeon pages and two entrances.
            local paired
            if route.key == "stratholme" then
                for wing, floor in pairs({ ["Stratholme: Living"] = 317, ["Stratholme: Undead"] = 318 }) do
                    local candidate = byName[normalized(wing)]
                    if candidate then
                        candidate.route, candidate.floor = route.key, floor
                        paired = true
                    end
                end
            end
            if not paired then
                entry = entry or add({ name = display })
                entry.route, entry.instance = route.key, route.instanceID or entry.instance
                entry.routeEntrance = read(routes.GetEntrance, routes, route.key)
                local wings = routes.WingPortals and routes.WingPortals[route.instanceID]
                for _, door in ipairs(wings or {}) do
                    if door.key == route.key then
                        entry.routeEntrance = { map = wings.map, x = door.x, y = door.y }
                        break
                    end
                end
                alias(entry, route.key)
                alias(entry, route.name)
                alias(entry, display)
            end
        end
    end
    for _, entry in ipairs(entries) do
        local id = entry.instance
        if id then
            local previous = byInstance[id]
            byInstance[id] = previous == nil and entry or false
        end
    end
    return entries, byName, byInstance
end

local function nativeIdentity(id)
    if type(id) ~= "number" or id <= 0 or type(EJ_GetInstanceInfo) ~= "function" then return end
    local name, _, _, _, _, _, _, _, _, instanceID = EJ_GetInstanceInfo(id)
    return plain(name), plain(instanceID)
end

function world.CollectDungeons(mapID, sources, points)
    local journal, routes = providers()
    local entries, byName, byInstance = catalog(journal, routes)
    local seen = {}
    local function add(source, x, y, name, entry, note, atlas)
        if not app.ValidMapPoint(x, y) then return end
        local sourceX, sourceY = x, y
        x, y = app.ProjectMapPoint(source, mapID, x, y)
        if not x then return end
        if entry and seen[entry] then return end
        for _, point in ipairs(points) do
            if point.kind == "dungeon" and (point.name == name and point.dungeon == entry or not entry and not point.dungeon)
                and math.abs(point.x - x) < .012 and math.abs(point.y - y) < .012 then return end
        end
        if entry then
            seen[entry] = true
            entry.waypoint = { source, sourceX, sourceY }
        end
        points[#points + 1] = {
            kind = "dungeon", x = x, y = y, name = name, dungeon = entry, note = note, atlas = atlas,
        }
    end
    local included = {}
    for _, source in ipairs(sources) do
        included[source] = true
        local records = read(C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap, source)
        for _, value in ipairs(type(records) == "table" and records or {}) do
            local native = plain(value)
            if native then
                local name = plain(native.name)
                local title, instance = read(nativeIdentity, plain(native.journalInstanceID))
                local entry = byName[normalized(title)] or byName[normalized(name)] or byInstance[instance] or nil
                local x, y = world.Vector(plain(native.position))
                add(source, x, y, entry and entry.name or name, entry, plain(native.description), plain(native.atlasName))
            end
        end
    end
    for _, entry in ipairs(entries) do
        local entrance = entry.routeEntrance or entry.journalEntrance
        local source = entrance and (entrance.map or entrance.mapID)
        if source and included[source] then
            local note = entry.journalEntrance and entry.journalEntrance.detail
            if journal and entry.journal then
                note = read(journal.LocalizeDungeonField, entry.journal, "entranceDetail", note) or note
            end
            add(source, entrance.x, entrance.y, entry.name, entry, note)
        end
    end
    for _, source in ipairs(sources) do
        for _, landmark in ipairs(app.mapDungeonLandmarks[source] or {}) do
            local entry = byName[normalized(landmark[4])] or nil
            if not entry then
                -- An installed Routes provider may know this entrance without a Journal key.
                entry = byName[normalized(L(landmark[3]))] or byName[normalized(landmark[3])] or nil
            end
            add(source, landmark[1], landmark[2], entry and entry.name or L(landmark[3]), entry)
        end
    end
end

local function closeMaximizedMap()
    local map = WorldMapFrame
    if map and read(map.IsShown, map) and read(map.IsMaximized, map) and HideUIPanel then HideUIPanel(map) end
end

local function actions(entry)
    local choices = {}
    local journal, routes = providers()
    local key = entry and entry.journal
    local record = journal and key and journal.DB[key]
    local frame = _G.ForeverDungeonJournalFrame
    local function journalAction(fn, ...)
        if not (frame and frame.Show and frame.IsShown and fn) then return end
        closeMaximizedMap()
        if not frame:IsShown() then frame:Show() end
        if frame.Raise then frame:Raise() end
        fn(key, ...)
    end
    local function add(label, action, mapAction)
        choices[#choices + 1] = { L(label), action, mapAction }
    end
    local guide = app.instances
    local dungeon = guide and entry and guide.byKey[entry.guideKey]
    if dungeon then
        local function open(tab)
            closeMaximizedMap()
            guide.Open(dungeon.key, tab)
        end
        if #dungeon.floors > 0 then add("Innenkarte öffnen", function() open("map") end, true) end
        if #dungeon.paths > 0 then add("Route öffnen", function() open("route") end) end
        if #dungeon.quests > 0 then add("Instanzquests öffnen", function() open("quests") end) end
        if #dungeon.loot > 0 then add("Bosse und Beute öffnen", function() open("loot") end) end
    elseif record and frame then
        if type(journal.OpenDungeonMap) == "function" and journal.DUNGEON_MAPS and journal.DUNGEON_MAPS[key]
            and read(journal.IsDungeonMapLocked, key) ~= true and read(journal.IsDungeonLocked, key) ~= true then
            add("Innenkarte öffnen", function() journalAction(journal.OpenDungeonMap) end, true)
        end
        if type(journal.OpenQuestPage) == "function" and type(record.quests) == "table" and #record.quests > 0 then
            add("Instanzquests öffnen", function() journalAction(journal.OpenQuestPage) end)
        end
        if type(journal.OpenBossPage) == "function" and type(record.bosses) == "table" and #record.bosses > 0 then
            add("Bosse und Beute öffnen", function() journalAction(journal.OpenBossPage, 1) end)
        end
    end
    if not dungeon and routes and entry and entry.route and routes.Window and type(routes.Window.Open) == "function" then
        add("In Forever DungeonRoutes öffnen", function()
            closeMaximizedMap()
            routes.Window:Open(entry.route, entry.floor)
        end, true)
    end
    local waypoint = entry and entry.waypoint
    if waypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates and C_Map and C_Map.SetUserWaypoint
        and read(C_Map.CanSetUserWaypointOnMap, waypoint[1]) == true then
        add("Wegpunkt zum Eingang setzen", function()
            if read(C_Map.CanSetUserWaypointOnMap, waypoint[1]) ~= true then return end
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(unpack(waypoint)))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end)
    end
    return choices
end

function world.DungeonClick(pin, entries, button)
    local combat, known = app.comfort.Read(InCombatLockdown)
    if not known or combat then return end
    if #entries == 1 and button == "LeftButton" then
        local choices = actions(entries[1])
        local first = choices[1]
        for _, choice in ipairs(choices) do
            if choice[3] then first = choice; break end
        end
        if first then app.SecureCall(first[1], first[2]) end
        return
    end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(pin, function(_, root)
        for _, entry in ipairs(entries) do
            local choices = actions(entry)
            if #choices > 0 then
                local menu = root
                if #entries > 1 then menu = root:CreateButton(entry.name)
                else menu:CreateTitle(entry.name) end
                for _, choice in ipairs(choices) do
                    local label, action = choice[1], choice[2]
                    menu:CreateButton(label, function()
                        local locked, readable = app.comfort.Read(InCombatLockdown)
                        if readable and not locked then app.SecureCall(label, action) end
                    end)
                end
            end
        end
    end)
end
