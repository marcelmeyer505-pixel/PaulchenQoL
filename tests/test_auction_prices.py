"""Exercise bag/bank price sources with deterministic Lua 5.1 clocks."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lua_runtime"))
from lupa.lua51 import LuaRuntime

source = (Path(__file__).resolve().parents[1] / "Modules/Auction/Prices.lua").read_text(encoding="utf-8")
lua = LuaRuntime()
lua.execute(r'''
profile, scans, tsPrices, calls = {}, {}, {}, {}
clock, installed, loaded = 0, true, true
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
            assert(key == "DBMarket")
            calls[item] = (calls[item] or 0) + 1
            if tsPrices[item] == "ERROR" then error("TSM is still initializing") end
            return tsPrices[item]
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
load = lua.eval('function(code) assert(loadstring(code))("PaulchenQoL", newApp()) end')
load(source)
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
local tsm, scanner = app.GetAuctionPriceStatus()
assert(tsm:find("TSM aktiv", 1, true) and scanner == "Paulchens Scanner aktiv")
tsPrices["i:42"] = 1200
clock = 59
assertPrice(base, 42, 1100, "TSM_DBMarket")
clock = 60
assertPrice(base, 42, 1200, "TSM_DBMarket")

for _, invalid in ipairs({false, "ERROR", "123", -1, 0, math.huge, 0 / 0}) do
    tsPrices["i:42"] = invalid
    app.RefreshAuctionPrices()
    assertPrice(base, 42, 300, "PAULCHEN_SCAN", 980)
end
tsPrices["i:42"] = nil
app.RefreshAuctionPrices()
assertPrice(base, 42, 300, "PAULCHEN_SCAN", 980)

app.SetAuctionPriceMode("tsm")
assert(app.GetAuctionPriceMode() == "tsm")
tsPrices["i:42"] = 1200
app.SetAuctionPriceMode("scanner")
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
load(source)
lua.execute(r'''
event(nil, "PLAYER_LOGIN")
assert(app.GetAuctionPriceMode() == "scanner")
assertPrice(suffix, 42, nil, "NONE")
app.SetAuctionPriceMode("auto")
assertPrice(suffix, 42, 1750, "TSM_DBMarket")
installed, loaded, TSM_API = false, false, nil
''')
load(source)
lua.execute(r'''
event(nil, "PLAYER_LOGIN")
assertPrice(suffix, 42, nil, "NONE")
app.auction.GetSnapshot = function() error("scanner unavailable") end
app.RefreshAuctionPrices()
assertPrice(base, 42, nil, "NONE")
''')
print("Auction prices: priorities, invalid values, late TSM, variants, scan expiry and reload OK")
