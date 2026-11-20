"""Check the TableBuilder cell interface without WoW widget fallbacks."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'lua_runtime'))
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
lua.execute('''
suite={upgrades={gear={}},Readable=function(v) return v end}
C_AuctionHouse={}
Menu={ModifyMenu=function() end}
suite.upgrades.RegisterEvent=function() end
suite.upgrades.On=function() end
function GetLocale() return "deDE" end
-- No TableBuilderCellMixin / CreateFromMixins: addon may load before them.
''')
load=lua.eval('function(s) assert(loadstring(s))("PaulchenQoL",suite) end')
load((root/'Modules/Upgrades/AuctionFilter.lua').read_text(encoding='utf-8'))
lua.execute('''
local mixin=assert(PaulchenQoLAuctionValueCellMixin)
assert(type(mixin.OnLineEnter)=="function" and type(mixin.OnLineLeave)=="function")
function testCell(kind)
 local label={SetText=function(self,value) self.value=value end,
              SetTextColor=function(self,...) self.color={...} end}
 -- No metatable returns made-up widget functions: missing callbacks must fail.
 local cell=setmetatable({Text=label},{__index=mixin})
 cell:Init({},kind,function(row) return row end)
 return cell
end
cells={testCell("pct"),testCell("gold")}
local nativeCalls={enter=0,leave=0}
local row={cells={}}
for i=1,4 do row.cells[i]={OnLineEnter=function() nativeCalls.enter=nativeCalls.enter+1 end,
 OnLineLeave=function() nativeCalls.leave=nativeCalls.leave+1 end} end
row.cells[5],row.cells[6]=cells[1],cells[2]
-- The row's public contract dispatches both hooks to all six cells.
for n=1,1000 do
 for _,cell in ipairs(row.cells) do cell:OnLineEnter() end
 for _,cell in ipairs(row.cells) do cell:OnLineLeave() end
end
assert(nativeCalls.enter==4000 and nativeCalls.leave==4000)
cells[1]:Populate({pct=12.5});assert(cells[1].Text.value=="+12,5 %" and cells[1].Text.color[2]==0.89)
cells[1]:Populate({pct=-2});assert(cells[1].Text.value=="-2,0 %" and cells[1].Text.color[1]==0.95)
cells[1]:Populate({pct=0});assert(cells[1].Text.value=="0,0 %")
cells[2]:Populate({gold=4.25});assert(cells[2].Text.value=="4,25")
cells[2]:Populate({gold=0.00001});assert(cells[2].Text.value=="<0,0001")
cells[1]:Populate({empty=true});assert(cells[1].Text.value=="Freier Platz")
cells[2]:Populate({});assert(cells[2].Text.value=="—")
-- Pooled cells can be reused across values and still accept both callbacks.
cells[1]:Init({},"gold",function(row) return {gold=row.price} end)
cells[1]:Populate({price=8.5});assert(cells[1].Text.value=="8,50")
cells[1]:OnLineEnter();cells[1]:OnLineLeave()
''')
print('Auction cells: mandatory hover callbacks before TableBuilder load, 1000 six-cell enter/leave cycles, both columns, value/color rendering and pooled reuse passed.')

lua.execute(r'''
local function noop() end
suite.auction = {}
SlashCmdList = {}
local key = {itemID=84, itemLevel=0, itemSuffix=0}
local good = {itemLink="item:84",buyoutAmount=15000,quantity=1}
local protected = setmetatable({}, {__index=function() error("Protected row was accessed") end})
function issecretvalue(value) return value == protected end
function GetServerTime() return 10 end
function GetRealmName() return "Test" end
function UnitFactionGroup() return "Horde" end
C_Item = {GetItemInfoInstant=function() return nil,nil,nil,"INVTYPE_CHEST" end}
C_AuctionHouse.GetNumItemSearchResults = function() return #searchRows end
C_AuctionHouse.GetItemSearchResultInfo = function(_,index)
    local row = searchRows[index]
    if row == false then error("Short-lived query failure") end
    return row
end
C_AuctionHouse.HasFullItemSearchResults = function() return true end
function CreateFrame()
    return {RegisterEvent=noop,SetScript=function(_,_,handler) scannerEvent=handler end}
end
function scanSearch(...)
    searchRows = {...}
    scannerEvent(nil, "ITEM_SEARCH_RESULTS_UPDATED", key)
    local _, searches = suite.auction.GetSnapshot()
    return searches["84:0:0"]
end
auctionGood,auctionProtected=good,protected
''')
load((root/'Modules/Auction/Scanner.lua').read_text(encoding='utf-8'))
lua.execute('''
scannerEvent(nil,"AUCTION_HOUSE_SHOW")
local prior=scanSearch(auctionGood)
assert(prior.complete and prior.offers["item:84"].price==15000)
assert(scanSearch(false)==prior)
assert(scanSearch(auctionProtected)==prior)
assert(scanSearch({buyoutAmount=17000})==prior)
assert(scanSearch({containsAccountItem=auctionProtected,buyoutAmount=17000,itemLink="item:84"})==prior)
local cleared=scanSearch({buyoutAmount=0})
assert(cleared~=prior and cleared.complete and not next(cleared.offers))
''')
print('Auction scanner: unreadable, protected and incomplete rows preserve the previous search. A readable empty buyout result still clears old offers.')
