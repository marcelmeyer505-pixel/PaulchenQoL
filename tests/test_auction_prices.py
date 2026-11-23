"""Exercise bag/bank price sources with deterministic Lua 5.1 clocks."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lua_runtime"))
from lupa.lua51 import LuaRuntime

source = (Path(__file__).resolve().parents[1] / "Modules/Auction/Prices.lua").read_text(encoding="utf-8")
lua = LuaRuntime()
lua.execute(r'''
profile, scans, tsPrices, calls, minPrices, minCalls = {}, {}, {}, {}, {}, {}
clock, installed, loaded = 0, true, true
function GetLocale() return "deDE" end
function GetTime() return clock end
function GetServerTime() return 1000 + clock end
C_AddOns = {
    IsAddOnLoaded = function() return loaded end,
    GetAddOnInfo = function() return installed and "TradeSkillMaster" or nil end,
}
function CreateFrame()
    return { SetScript = function(_, _, handler) event = handler end }
end
function newApp()
    app = {
        Readable = function(value) return value end,
        Profile = function() return profile end,
        RegisterSupported = function() end,
        auction = {
            GetSnapshot = function() return full, scans end,
            OnUpdated = function(callback) scanUpdated = callback end,
        },
    }
    return app
end
function freshAPI()
    TSM_API = {
        ToItemString = function(link)
            queried = link
            local suffix = link:match("^item:%d+:0:0:0:0:0:([%-]?%d+):")
            return "i:" .. link:match("^item:(%d+)") .. (suffix and suffix ~= "0" and ":" .. suffix or "")
        end,
        GetCustomPriceValue = function(key, item)
            assert(key == "DBMarket" or key == "DBMinBuyout")
            local values, counts = tsPrices, calls
            if key == "DBMinBuyout" then values, counts = minPrices, minCalls end
            counts[item] = (counts[item] or 0) + 1
            if values[item] == "ERROR" then error("TSM is still initializing") end
            return values[item]
        end,
    }
end
function assertPrice(link, id, expected, expectedSource, at)
    local price, src, info = app.GetAuctionPrice(link, id)
    assert(price == expected and src == expectedSource, tostring(price) .. " / " .. src)
    assert((info and info.at) == at)
end
base, suffix, bonus = "item:42", "item:42:0:0:0:0:0:-7:11:60", "item:42:0:0:0:0:0:0:11:60:0:0:0:1:809"
full = { at = 980, items = { [42] = {
    [base] = {price = 300, link = base},
    [suffix] = {price = 600, link = suffix},
    [bonus] = {price = 850, link = bonus},
} } }
tsPrices["i:42"], tsPrices["i:42:-7"] = 1100, 1750
freshAPI()
''')
localization = (Path(__file__).resolve().parents[1] / "Localization.lua").read_text(encoding="utf-8")
load = lua.eval('''function(code, locale)
    local addon = newApp()
    assert(loadstring(locale))("PaulchenQoL", addon)
    assert(loadstring(code))("PaulchenQoL", addon)
end''')
load(source, localization)
lua.execute(r'''
event(nil, "PLAYER_LOGIN")
assert(app.GetAuctionPriceMode() == "auto")
assertPrice(base, 42, 1100, "TSM_DBMarket")
assertPrice(suffix, 42, 1750, "TSM_DBMarket")
assert(queried == suffix)
assertPrice("item:42:0:0:0:0:0:-7:99:50", 42, 1750, "TSM_DBMarket")
assert(calls["i:42:-7"] == 1)
assertPrice(bonus, 42, 850, "PAULCHEN_SCAN", 980)
assertPrice(nil, 42, 1100, "TSM_DBMarket")
assertPrice(nil, 999, nil, "NONE")
minPrices["i:42"], minPrices["i:42:-7"] = 650, 1000
assert(app.GetTSMMinBuyout(base, 42) == 650 and app.GetTSMMinBuyout(suffix, 42) == 1000)
assert(app.GetTSMMinBuyout("item:42:0:0:0:0:0:-7:99:50", 42) == 1000 and minCalls["i:42:-7"] == 1)
assert(app.GetTSMMinBuyout(bonus, 42) == nil and minCalls["i:42"] == 1)
assertPrice(base, 42, 1100, "TSM_DBMarket")
local tsm, scanner = app.GetAuctionPriceStatus()
assert(tsm:find("TSM aktiv", 1, true) and scanner == "Paulchens Scanner aktiv")
tsPrices["i:42"] = 1200
minPrices["i:42"] = 800
clock = 59
assertPrice(base, 42, 1100, "TSM_DBMarket")
assert(app.GetTSMMinBuyout(base, 42) == 650)
clock = 60
assertPrice(base, 42, 1200, "TSM_DBMarket")
assert(app.GetTSMMinBuyout(base, 42) == 800 and minCalls["i:42"] == 2)

for _, invalid in ipairs({false, "ERROR", "123", -1, 0, math.huge, 0 / 0}) do
    tsPrices["i:42"] = invalid
    minPrices["i:42"] = invalid
    app.RefreshAuctionPrices()
    assertPrice(base, 42, 300, "PAULCHEN_SCAN", 980)
    assert(app.GetTSMMinBuyout(base, 42) == nil)
end
tsPrices["i:42"] = nil
app.RefreshAuctionPrices()
assertPrice(base, 42, 300, "PAULCHEN_SCAN", 980)

app.SetAuctionPriceMode("tsm")
assert(app.GetAuctionPriceMode() == "tsm")
tsPrices["i:42"] = 1200
app.SetAuctionPriceMode("scanner")
assert(app.GetTSMMinBuyout(suffix, 42) == nil)
assertPrice(base, 42, 300, "PAULCHEN_SCAN", 980)
assertPrice(suffix, 42, 600, "PAULCHEN_SCAN", 980)
assertPrice("item:42:0:0:0:0:0:-8:11:60", 42, nil, "NONE")
assertPrice("item:42:0:0:0:0:0:0:11:60:0:0:0:1:810", 42, nil, "NONE")
assertPrice("item:42", 43, nil, "NONE")
assertPrice("item:bogus", 42, nil, "NONE")
app.SetAuctionPriceMode("auto")

loaded = false
event(nil, "PLAYER_LOGIN")
assertPrice(base, 42, 300, "PAULCHEN_SCAN", 980)
installed, TSM_API = false, nil
assertPrice(base, 42, 300, "PAULCHEN_SCAN", 980)
assert(app.GetAuctionPriceStatus() == "TSM nicht installiert")
assert(app.GetTSMMinBuyout(suffix, 42) == nil)
installed, loaded, TSM_API = true, true, {}
event(nil, "ADDON_LOADED", "TradeSkillMaster")
assertPrice(base, 42, 300, "PAULCHEN_SCAN", 980)
local lateAPI = TSM_API
freshAPI()
lateAPI.ToItemString, lateAPI.GetCustomPriceValue = TSM_API.ToItemString, TSM_API.GetCustomPriceValue
TSM_API = lateAPI
assertPrice(base, 42, 1200, "TSM_DBMarket")

local original = TSM_API.ToItemString
TSM_API.ToItemString = function() error("unavailable") end
app.RefreshAuctionPrices()
assertPrice(base, 42, 300, "PAULCHEN_SCAN", 980)
TSM_API.ToItemString = original
tsPrices["i:42"] = nil
app.RefreshAuctionPrices()
assertPrice(base, 42, 300, "PAULCHEN_SCAN", 980)
assertPrice(suffix, 42, 1750, "TSM_DBMarket")
local baseCalls, suffixCalls = calls["i:42"], calls["i:42:-7"]
scans["42:0:0"] = { id = 42, at = 1050, complete = true, offers = {
    [base] = {price = 400, link = base, timeLeft = 15},
} }
scanUpdated()
assertPrice(base, 42, 400, "PAULCHEN_SCAN", 1050)
assertPrice(suffix, 42, 1750, "TSM_DBMarket")
assert(calls["i:42"] == baseCalls and calls["i:42:-7"] == suffixCalls)
clock = 65
assertPrice(base, 42, nil, "NONE")
app.SetAuctionPriceMode("scanner")
''')
load(source, localization)
lua.execute(r'''
event(nil, "PLAYER_LOGIN")
assert(app.GetAuctionPriceMode() == "scanner")
assertPrice(suffix, 42, nil, "NONE")
app.SetAuctionPriceMode("auto")
assertPrice(suffix, 42, 1750, "TSM_DBMarket")
installed, loaded, TSM_API = false, false, nil
''')
load(source, localization)
lua.execute(r'''
event(nil, "PLAYER_LOGIN")
assertPrice(suffix, 42, nil, "NONE")
app.auction.GetSnapshot = function() error("scanner unavailable") end
app.RefreshAuctionPrices()
assertPrice(base, 42, nil, "NONE")
''')

lua.execute(r'''
freshAPI()
installed, loaded = true, true
minPrices["i:42"], minPrices["i:42:-7"] = 800, 1000
app.upgrades = {
    content = { ItemAllowed = function(scan) return not scan.locked end },
    VariantKey = function(link) return link == suffix and "suffix" or nil end,
}
''')
load_sources = lua.eval('function(code) assert(loadstring(code))("PaulchenQoL", app) end')
load_sources((Path(__file__).resolve().parents[1] / "Modules/Upgrades/Sources.lua").read_text(encoding="utf-8"))
lua.execute(r'''
local scan = { activeRewards = {}, atlas = { items = {} }, journal = { items = {} },
    crafting = {}, auctions = {}, browseItems = {}, presentItems = {} }
local item = { link = suffix, boe = true, quality = 3 }
local getSources = app.upgrades.GetSources
local function auctionSource()
    for _, source in ipairs(getSources(scan, 42, item)) do
        if source.kind == "auction" then return source end
    end
end
assert(auctionSource().isEstimate and auctionSource().price == 1000)
assert(not next(scan.presentItems), "Price estimates must never mark an item available")
scan.locked = true
assert(not auctionSource(), "An estimate must not bypass locked content")
scan.locked, item.boe = false, false
assert(not auctionSource(), "An estimate alone is useful only on known tradeable items")
item.boe = true
scan.auctions[42] = { suffix = {price = 1100, at = 1051} }
local actual = auctionSource()
assert(not actual.isEstimate and actual.price == 1100 and actual.tsmPrice == 1000 and actual.at == 1051)
scan.auctions[42] = { [42] = {price = 600, at = 1051} }
assert(auctionSource().isEstimate and auctionSource().price == 1000, "Base offers must not replace variant estimates")
scan.browseItems.suffix = {price = 1150}
assert(not auctionSource().isEstimate and auctionSource().price == 1150 and auctionSource().tsmPrice == 1000)
scan.browseItems.suffix = {}
assert(auctionSource().isEstimate and auctionSource().price == 1000)
scan.browseItems.suffix.price = 1150
app.SetAuctionPriceMode("scanner")
assert(auctionSource().price == 1150 and not auctionSource().tsmPrice)
scan.browseItems.suffix = nil
assert(not auctionSource())
scan.auctions[42].suffix = {price = 1100, at = 1051}
assert(auctionSource().price == 1100 and not auctionSource().tsmPrice)
''')
print("Auction prices: sources, cache, variants, scanner fallback, reload and upgrade availability OK")
