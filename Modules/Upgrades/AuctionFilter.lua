local _, suite = ...
local app = suite.upgrades
local ah = C_AuctionHouse
if not (app and ah and Menu and Menu.ModifyMenu) then return end

local gear = app.gear
local readable = suite.Readable
local enabled, queued = false, false
local refresh
local emptyMetrics = {}

local function compare(row, level)
    local key = readable(row.itemKey)
    if not key then return end
    local required = ah.GetItemKeyRequiredLevel and readable(ah.GetItemKeyRequiredLevel(key))
    if required and required > level then return end
    local link = gear.AuctionItemLink(key)
    if not link then return end
    local result = gear.CompareToEquipped(link)
    if result and result.usable and (result.minLevel or 0) <= level then return result end
end

local decimal = suite.LocalizeDecimal

PaulchenQoLAuctionValueCellMixin = {}
-- TableBuilder forwards row hover events to every cell, unconditionally.
-- These value-only cells have no hover effect, but must implement both hooks.
-- Define them here so loading before TableBuilderCellMixin is safe as well.
function PaulchenQoLAuctionValueCellMixin:OnLineEnter()
end

function PaulchenQoLAuctionValueCellMixin:OnLineLeave()
end

function PaulchenQoLAuctionValueCellMixin:Init(_, kind, metrics)
    self.kind, self.metrics = kind, metrics
end

function PaulchenQoLAuctionValueCellMixin:Populate(row)
    local metrics = self.metrics(row)
    local value = metrics[self.kind]
    if self.kind == "pct" and value then
        self.Text:SetText(decimal((value == 0 and "%.1f %%" or "%+.1f %%"):format(value)))
        if value > 0 then
            self.Text:SetTextColor(0.48, 0.89, 0.56)
        elseif value < 0 then
            self.Text:SetTextColor(0.95, 0.48, 0.42)
        else
            self.Text:SetTextColor(0.87, 0.85, 0.81)
        end
    elseif value then
        local amount = value < 0.0001 and "<0.0001" or (value < 0.01 and "%.4f" or "%.2f"):format(value)
        self.Text:SetText(decimal(amount))
        self.Text:SetTextColor(1, 0.82, 0.42)
    else
        self.Text:SetText(self.kind == "pct" and metrics.empty and suite.L("Freier Platz") or "—")
        self.Text:SetTextColor(0.68, 0.65, 0.60)
    end
end

local function refreshSoon()
    if not refresh or queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        refresh()
    end)
end

local function attach(search, browse)
    local list = browse and browse.ItemList
    if not (list and list.getEntry and list.getNumEntries and list.SetDataProvider) then return end
    local filter = search.FilterButton
    if not (filter and filter.ClearFiltersButton and type(filter.Reset) == "function"
        and type(search.UpdateClearFiltersButton) == "function" and type(browse.UpdateBrowseResults) == "function"
        and type(browse.UpdateHeaders) == "function" and type(browse.SetSortOrder) == "function") then return end
    local started, getEntry, getCount, complete = list.searchStartedFunc, list.getEntry, list.getNumEntries, list.hasFullResultsFunc
    local rows, scores, source, sourceCount = {}, {}, nil, nil
    local sortKey, reverse
    local headers, extendedLayout = {}, nil

    local function metrics(row)
        row = readable(row)
        if type(row) ~= "table" then return emptyMetrics end
        if scores[row] then return scores[row] end
        local level = gear.PlayerLevel()
        local ok, result = pcall(compare, row, level)
        if not ok then result = nil end
        local pct = result and result.pct or nil
        local price, quantity = readable(row.minPrice), readable(row.totalQuantity)
        local values = {
            upgrade = app.IsUpgrade(result, level),
            pct = pct,
            empty = result and result.empty,
        }
        if values.upgrade and pct and pct > 0 and type(price) == "number" and price > 0
            and type(quantity) == "number" and quantity > 0 then
            values.gold = price / 10000 / pct
        end
        scores[row] = values
        return values
    end

    local function arrangedCount()
        local count = getCount()
        if source ~= browse.browseResults or sourceCount ~= count then
            source, sourceCount = browse.browseResults, count
            rows = {}
            for index = 1, count do
                local row = readable(getEntry(index))
                if type(row) == "table" then
                    local values = metrics(row)
                    if not enabled or values.upgrade then
                        rows[#rows + 1] = { row = row, index = index, value = values[sortKey] }
                    end
                end
            end
            if sortKey then
                table.sort(rows, function(a, b)
                    if a.value == b.value then return a.index < b.index end
                    if a.value == nil then return false end
                    if b.value == nil then return true end
                    if reverse then return a.value > b.value end
                    return a.value < b.value
                end)
            end
        end
        return #rows
    end

    refresh = function()
        scores = {}
        sourceCount = nil
        if list:IsVisible() then list:DirtyScrollFrame() end
    end

    local function updateProvider()
        if enabled or sortKey then
            list:SetDataProvider(started, function(index) return rows[index] and rows[index].row end, arrangedCount, function()
                -- A filtered page can be empty even when the server has more results.
                return (enabled and getCount() > 0) or not complete or complete()
            end)
        else
            list:SetDataProvider(started, getEntry, getCount, complete)
            rows, source = {}, nil
        end
        refresh()
    end

    local sortOwner = {}
    function sortOwner:GetSortOrderState(key)
        if sortKey ~= key then return end
        return reverse and AuctionHouseSortOrderState.PrimaryReversed or AuctionHouseSortOrderState.PrimarySorted
    end

    local function updateHeaders()
        if sortKey then
            for _, header in ipairs(browse.headers or {}) do
                if header.owner == browse then header:SetArrowState(nil) end
            end
        end
        for _, header in pairs(headers) do header:UpdateArrow() end
    end

    function sortOwner:SetSortOrder(key)
        if sortKey == key then
            reverse = not reverse
        else
            sortKey, reverse = key, key == "pct"
        end
        list.ScrollBox:ScrollToBegin()
        updateProvider()
        updateHeaders()
    end

    local function addColumn(builder, key, title, width)
        local column = builder:AddUnsortableFixedWidthColumn(sortOwner, 0, width, 2, 6, title,
            "PaulchenQoLAuctionValueCellTemplate", key, metrics)
        local header = column:GetHeaderFrame()
        -- The stock template can route clicks to a Lua sort owner without an AH query.
        header.sortOrder = key
        header:SetEnabled(true)
        headers[key] = header
    end

    local function extendLayout()
        local nativeLayout = list.tableBuilderLayoutFunction
        if type(nativeLayout) ~= "function" or nativeLayout == extendedLayout then return end
        extendedLayout = function(builder)
            nativeLayout(builder)
            headers = {}
            if type(builder.AddUnsortableFixedWidthColumn) ~= "function" then return end
            addColumn(builder, "pct", "Upgrade %", 82)
            addColumn(builder, "gold", suite.L("Gold pro %"), 87)
            updateHeaders()
        end
        list:SetTableBuilderLayout(extendedLayout)
    end

    local function showClearButton()
        if enabled and filter.ClearFiltersButton then filter.ClearFiltersButton:Show() end
    end

    local function setEnabled(value)
        enabled = value
        updateProvider()
        search:UpdateClearFiltersButton()
    end

    hooksecurefunc(search, "UpdateClearFiltersButton", showClearButton)
    search:HookScript("OnShow", showClearButton)
    hooksecurefunc(filter, "Reset", function()
        if enabled then setEnabled(false) end
    end)
    -- Browse rows may be reused with new prices and the same total count.
    -- Invalidate in the native update hook before its next list repaint.
    hooksecurefunc(browse, "UpdateBrowseResults", refresh)
    hooksecurefunc(browse, "UpdateHeaders", updateHeaders)
    hooksecurefunc(browse, "SetSortOrder", function()
        if not sortKey then return end
        sortKey = nil
        updateProvider()
        browse:UpdateHeaders()
    end)
    if type(browse.SetupTableBuilder) == "function" and type(list.SetTableBuilderLayout) == "function" then
        hooksecurefunc(browse, "SetupTableBuilder", extendLayout)
        extendLayout()
    end
    return function() setEnabled(not enabled) end, function() return sortKey ~= nil end
end

local toggle, isSorted
local function install()
    if toggle then return end
    local auction = AuctionHouseFrame
    if auction and auction.SearchBar then
        toggle, isSorted = attach(auction.SearchBar, auction.BrowseResultsFrame)
    end
end

Menu.ModifyMenu("MENU_AUCTION_HOUSE_SEARCH_FILTER", function(owner, menu)
    local auction = AuctionHouseFrame
    local search = auction and auction.SearchBar
    if not search or owner ~= search.FilterButton then return end
    local browse = auction.BrowseResultsFrame
    install()
    if not toggle then return end
    menu:CreateCheckbox(suite.L("Nur Upgrades"), function() return enabled end, toggle)
    if (enabled or isSorted()) and browse.searchStarted and #browse.browseResults > 0 and not ah.HasFullBrowseResults() then
        menu:CreateButton(suite.L("Weitere Angebote laden"), function()
            if not ah.HasFullBrowseResults() and ah.IsThrottledMessageSystemReady() then ah.RequestMoreBrowseResults() end
        end)
    end
end)

install()
app.RegisterEvent("ADDON_LOADED", function(_, name)
    if readable(name) == "Blizzard_AuctionHouseUI" then install() end
end)
app.RegisterEvent("AUCTION_HOUSE_SHOW", install)
app.On("GEAR_UPDATED", refreshSoon)
app.RegisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED", refreshSoon)
app.RegisterEvent("ITEM_DATA_LOAD_RESULT", refreshSoon)
app.RegisterEvent("GET_ITEM_INFO_RECEIVED", refreshSoon)
