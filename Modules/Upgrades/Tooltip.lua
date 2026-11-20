local _, suite = ...
local app = suite.upgrades
if not app then return end
local gear, readable = app.gear, suite.Readable
local added = setmetatable({}, { __mode = "k" })

local function itemLink(tooltip, data)
    local link
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, value = TooltipUtil.GetDisplayedItem(tooltip)
        link = readable(value)
    end
    if not gear.ItemID(link) and tooltip.GetItem then
        local _, value = tooltip:GetItem()
        link = readable(value)
    end
    if gear.ItemID(link) then return link end
    local id = data and readable(data.id)
    if type(id) == "number" and id > 0 then return "item:" .. id end
end

local function addComparison(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    if app.showingUpgradeRow and tooltip == GameTooltip then return end
    if tooltip.IsForbidden and readable(tooltip:IsForbidden()) ~= false then return end
    local link = itemLink(tooltip, data)
    if not gear.ItemID(link) then return end
    app.ObserveVariant(link)
    local db = PaulchenQoLUpgradesDB
    if db and db.statTooltip == false then return end
    local lines = tooltip.NumLines and readable(tooltip:NumLines())
    local previous = added[tooltip]
    if previous and previous.link == link and (not lines or not previous.lines or lines >= previous.lines) then return end
    local result = gear.CompareToEquipped(link)
    if not result then return end

    local status = "Nicht tragbar"
    local r, g, b = 0.79, 0.71, 0.64
    if result.usable then
        if result.minLevel > gear.PlayerLevel() then
            status = ("Ab Stufe %d"):format(result.minLevel)
        elseif result.equipped then
            status = "Angelegt"
        else
            status = result.pct and ("%+.1f %%"):format(result.pct) or ("%+.2f Punkte"):format(result.delta)
            status = status:gsub("%.", ",")
            if result.empty then status = status .. " · Freier Platz" end
            if result.delta > 0 then r, g, b = 0.54, 0.88, 0.60
            elseif result.delta < 0 then r, g, b = 0.94, 0.50, 0.45 end
        end
    end
    tooltip:AddDoubleLine("Paulchen · " .. app.ProfileName(), status, 0.98, 0.76, 0.42, r, g, b)
    added[tooltip] = { link = link, lines = tooltip.NumLines and readable(tooltip:NumLines()) }
end

local processor, types = TooltipDataProcessor, Enum and Enum.TooltipDataType
local modern = processor and processor.AddTooltipPostCall and types and types.Item
local function safeAdd(tooltip, data)
    pcall(addComparison, tooltip, data)
end
for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
    local tooltip = _G[name]
    if tooltip and tooltip.HookScript then
        pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", function(self) added[self] = nil end)
        if not modern then pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", safeAdd) end
    end
end
if modern then processor.AddTooltipPostCall(types.Item, safeAdd) end
