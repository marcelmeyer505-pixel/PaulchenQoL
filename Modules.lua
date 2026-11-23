local name, app = ...

local function oldModuleIsActive(moduleName)
    local api = C_AddOns
    return api and api.IsAddOnLoaded and api.IsAddOnLoaded(moduleName)
        and (not api.GetAddOnMetadata or api.GetAddOnMetadata(moduleName, "X-Paulchen-Datenbruecke") ~= "1")
end

local legacyTimeline = oldModuleIsActive("Details_CombatTimeline")
local legacyUpgrades = oldModuleIsActive("PaulchenUpgrades")
local legacyAuction = oldModuleIsActive("PaulchenAuktionsscan")

if not legacyTimeline then app.timeline = {} end
if not legacyUpgrades then app.upgrades = {} end
if not legacyAuction then app.auction = {} end

local function import(target, previous)
    if type(target) == "table" then return target end
    if type(previous) ~= "table" then return end
    local function copy(source)
        local result = {}
        for key, value in pairs(source) do result[key] = type(value) == "table" and copy(value) or value end
        return result
    end
    return copy(previous)
end

local function migrate()
    if not legacyTimeline then
        PaulchenQoLTimelineDB = import(PaulchenQoLTimelineDB, DetailsCombatTimelineDB) or { hidden = true }
    end
    if not legacyUpgrades then PaulchenQoLUpgradesDB = import(PaulchenQoLUpgradesDB, PaulchenUpgradesDB) end
    if not legacyAuction then PaulchenQoLAuctionDB = import(PaulchenQoLAuctionDB, PaulchenAuktionsscanDB) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, loaded)
    if type(loaded) ~= "string" or loaded:lower() ~= name:lower() then return end
    self:UnregisterEvent("ADDON_LOADED")
    migrate()
end)

function app.OpenModule(key, command)
    if key == "dtl" and app.timeline and app.timeline.Open then return app.timeline.Open(command) end
    if key == "upgrades" and app.upgrades and app.upgrades.Open then return app.upgrades.Open() end
    if key == "auction" and app.auction and app.auction.Start then return app.auction.Start() end
    if key == "dtl" and SlashCmdList.DETAILSCOMBATTIMELINE then return SlashCmdList.DETAILSCOMBATTIMELINE(command or "") end
    if key == "upgrades" then
        if legacyUpgrades and SlashCmdList.PAULCHENUPGRADES then return SlashCmdList.PAULCHENUPGRADES() end
        return app.OpenDashboard("upgrades")
    elseif key == "auction" and SlashCmdList.PAULCHENAH then
        return SlashCmdList.PAULCHENAH("")
    end
end

function app.UpdateModuleIcons()
    local shown = app.Profile().moduleIcons
    if app.timeline and app.timeline.UpdateMinimap then app.timeline.UpdateMinimap(shown) end
    if app.upgrades and app.upgrades.UpdateMinimap then app.upgrades.UpdateMinimap(shown) end
end

function app.OpenModulesMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return app.ToggleDashboard() end
    MenuUtil.CreateContextMenu(owner, function(_, menu)
        menu:CreateTitle("Paulchen QoL")
        menu:CreateButton(app.L("Übersicht und Reise-Check"), function() app.OpenDashboard("travel") end)
        menu:CreateButton(app.logbookName, function() app.OpenModule("dtl") end)
        menu:CreateButton(app.L("Logbuch · Kompaktansicht"), function() app.OpenModule("dtl", "mini") end)
        menu:CreateButton(app.L("Logbuch · EP und Farmrunden"), function() app.OpenModule("dtl", "farm") end)
        menu:CreateButton(app.L("Paulchen Upgrades"), function() app.OpenModule("upgrades") end)
        menu:CreateButton(app.L("Paulchens Buffwächter"), function() app.OpenDashboard("buffs") end)
        menu:CreateButton(app.L("Auktionshaus scannen"), function() app.OpenModule("auction") end)
        menu:CreateButton(app.L("Einstellungen"), app.OpenConfig)
    end)
end
