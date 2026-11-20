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
