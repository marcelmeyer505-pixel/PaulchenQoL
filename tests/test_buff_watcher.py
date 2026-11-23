from pathlib import Path
import sys
# A standard Lupa installation provides Lua 5.1; local development may use work/lua_runtime.
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'lua_runtime'))
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
fixture=(root/'tests/buff_watcher_fixture.lua').read_text(encoding='utf-8')
setup=r'''
function GetLocale() return "deDE" end
units={player={name="Chef",class="DRUID",guid="self",level=60,auras={}}}
groupMode="SOLO"; partyCount=0; raidCount=0
knownSpells={[1126]=true}; auraCalls={}; sent={}; reactions={}; reminders={}; canceled={}
diagnostics={}
print=function(...) local values={...};for i,v in ipairs(values) do values[i]=tostring(v) end;diagnostics[#diagnostics+1]=table.concat(values," ") end
function UnitClass(unit) local u=units[unit];return u and u.class,u and u.class end
function UnitName(unit) return units[unit] and units[unit].name end
UnitFullName=UnitName
function UnitGUID(unit) return units[unit] and units[unit].guid end
function UnitLevel(unit) return units[unit] and units[unit].level end
function UnitExists(unit) return units[unit]~=nil end
function UnitIsUnit(a,b) return units[a] and units[b] and units[a].guid==units[b].guid or false end
function UnitIsDeadOrGhost(unit) return units[unit] and units[unit].dead==true or false end
function UnitIsConnected(unit) return units[unit] and not units[unit].offline or false end
function UnitIsVisible(unit) return units[unit] and not units[unit].invisible or false end
function UnitInRange(unit) return units[unit] and not units[unit].far or false,true end
function IsInRaid() return groupMode=="RAID" end
function IsInGroup(category) if category then return instanceGroup==true end;return groupMode~="SOLO" end
function GetNumSubgroupMembers() return partyCount end
function GetNumGroupMembers() return groupMode=="RAID" and raidCount or partyCount+1 end
C_SpellBook={IsSpellKnown=function(id) return knownSpells[id]==true end}
C_Spell={GetSpellName=function(id) if id==9001126 then return "Mal der Wildnis" end end}
C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
 assert(filter=="HELPFUL");auraCalls[unit]=(auraCalls[unit] or 0)+1
 local u=assert(units[unit]);if u.error then error("Aura access denied") end
 return u.auras[index]
end}
restrictedKinds={}
C_RestrictedActions={GetAddOnRestrictionState=function(kind) return restrictedKinds[kind] or 0 end}
C_ChatInfo={AreOutgoingAddonChatMessagesRestricted=function() return chatRestriction==true end,
 SendChatMessage=function(message,channel)
  if chatError then error("Chat denied") end
  if syncBlock then fire("ADDON_ACTION_BLOCKED","PaulchenQoL","SendChatMessage");return end
  assert(#message<=255 and not message:find("|c",1,true) and not message:find("|H",1,true) and not message:find("\n",1,true))
  sent[#sent+1]={text=message,channel=channel,at=GetTime()}
 end}
Enum={PartyCategory={Instance=2},SpellBookSpellBank={Player=0}}
secretValues={}
function issecretvalue(value) return secretValues[value]==true end
function addUnit(token,name,class)
 units[token]={name=name,class=class,guid=token,level=60,auras={}}
end
function aura(unit,...)
 units[unit].auras={}
 for _,id in ipairs({...}) do units[unit].auras[#units[unit].auras+1]={spellId=id} end
end
function resetChat() sent={};app.Settings().buffChat={};app.buffCheck.autoBlocked=nil end
'''
lua=LuaRuntime()
lua.execute(fixture)
lua.execute(setup)
load=lua.eval('function(code,name) assert(loadstring(code,name))("PaulchenQoL",app) end')
for name in ('Localization.lua','Core.lua','Style.lua','Config.lua'):
    load((root/name).read_text(encoding='utf-8'),name)
lua.execute('''
app.React=function(key,context) reactions[#reactions+1]={key,context} end
app.CancelReaction=function(key) canceled[key]=(canceled[key] or 0)+1 end
app.SetCompanionReminder=function(key,value) reminders[key]=value end
app.RefreshOverview=function() end
app.OpenDashboard=function(key) openedPage=key end
app.SecureCall=function(label,fn,...) local ok,err=pcall(fn,...);assert(ok,label..": "..tostring(err));return ok end
''')
load((root/'BuffCheck.lua').read_text(encoding='utf-8'),'BuffCheck.lua')
lua.execute(r'''
local b=app.buffCheck
local function own(data) return data.members[1] end
local s=b.Scan()
assert(s.mode=="SOLO" and #s.members==1 and own(s).buffs.wild.state=="MISSING")
assert(reminders.mark=="Mal der Wildnis fehlt." and #sent==0)
assert(not own(s).buffs.fortitude.required and not own(s).buffs.intellect.required)
assert(not b.Say(true) and #sent==0)
aura("player",21850);assert(own(b.Scan()).buffs.wild.state=="PRESENT" and reminders.mark==nil)
groupMode="PARTY";partyCount=1;addUnit("party1","Kevin","WARRIOR")
s=b.Scan();assert(#s.members==2 and s.members[2].buffs.wild.state=="MISSING")
assert(b.Report(s):find("Kevin",1,true))
partyCount=4;addUnit("party2","Rico","PRIEST");addUnit("party3","Tom","MAGE");addUnit("party4","Marcel","ROGUE")
aura("player",1126,21564,23028);aura("party1",1126,21564)
aura("party2",1126,23028);aura("party3",21564);aura("party4",1126)
s=b.Scan();assert(s.missingCount==4 and s.unknownCount==0)
assert(not s.members[2].buffs.intellect.required and not s.members[5].buffs.intellect.required)
assert(s.members[3].buffs.fortitude.state=="MISSING" and s.members[4].buffs.wild.state=="MISSING")
assert(s.members[1].name=="Chef" and s.members[1].class=="DRUID" and s.members[1].groupStatus=="PARTY")
local oldOther=s.members[4].buffs.wild.state
aura("party2",1126,1243,1459)
fire("UNIT_AURA","party2");advance(0.21)
assert(b.Snapshot().members[3].buffs.fortitude.state=="PRESENT" and b.Snapshot().members[4].buffs.wild.state==oldOther)
for token in pairs(units) do aura(token,21849,21562,23028) end
s=b.Scan();assert(s.missingCount==0 and s.unknownCount==0 and b.Report(s):find("Alle Gruppenbuffs vorhanden",1,true))
assert(reactions[#reactions][1]=="buffReady")
auraCalls={}
for i=1,50 do fire("UNIT_AURA","party1") end
advance(0.21)
assert(auraCalls.party1==4 and not auraCalls.player and not auraCalls.party2)
units.party1.dead=true;units.party2.offline=true;units.party3.far=true;units.party4.invisible=true
s=b.Scan();assert(s.missingCount==0 and s.unknownCount>0 and s.unverifiableCount==4)
assert(b.Report(s):find("unvollständig",1,true) and not b.Report(s):find("Alle Gruppenbuffs vorhanden",1,true))
for token,u in pairs(units) do u.dead,u.offline,u.far,u.invisible=nil,nil,nil,nil end
combat=true;s=b.Scan();assert(s.checkedCount==0 and s.missingCount==0 and s.unknownCount>0 and reminders.mark==nil)
combat=false
local hidden=setmetatable({},{__index=function() error("secret field indexed") end})
secretValues[hidden]=true;units.party1.auras={hidden}
s=b.Scan();assert(s.members[2].buffs.wild.state=="UNKNOWN" and #s.members[2].missing==0)
local secretID={};secretValues[secretID]=true
units.party1.auras={{spellId=21564},{spellId=secretID}}
s=b.Scan();assert(s.members[2].buffs.fortitude.state=="PRESENT" and s.members[2].buffs.wild.state=="UNKNOWN")
units.party1.error=true;s=b.Scan();assert(#s.members[2].missing==0);units.party1.error=nil
restrictedKinds[1]=1;s=b.Scan();assert(s.checkedCount==0 and s.missingCount==0);restrictedKinds[1]=nil
for token in pairs(units) do aura(token,21849,21562,23028) end
local settings=b.Settings();assert(not settings.families.spirit and not settings.families.shadow)
-- A chat-only restriction must not hide readable auras or allow sends.
restrictedKinds[5]=2
s=b.Scan();assert(s.checkedCount==5 and s.unknownCount==0 and s.members[1].buffs.wild.state=="PRESENT")
assert(not b.Say(true) and #sent==0)
restrictedKinds[5]=nil
-- A teammate's missing Wild is visible in the table. The persistent
-- reminder is reserved for the druid's own buff as before.
units.player.class="WARRIOR";units.party4.class="DRUID";aura("player",21562)
s=b.Scan();assert(s.members[1].buffs.wild.state=="MISSING" and reminders.mark==nil)
units.player.class="DRUID";units.party4.class="ROGUE";aura("player",21849,21562,23028)
for family in pairs(settings.families) do settings.families[family]=false end
s=b.Scan();assert(b.Report(s):find("Keine Buffanforderungen",1,true))
for _,family in ipairs(b.families) do settings.families[family.key]=not family.optional end
settings.families.spirit=true;s=b.Scan();assert(s.members[1].buffs.spirit.state=="UNKNOWN")
b.SetRequirement("DRUID","spirit","on");s=b.Scan();assert(s.members[1].buffs.spirit.state=="MISSING")
b.SetRequirement("DRUID","spirit","off");s=b.Scan();assert(not s.members[1].buffs.spirit.required)
settings.families.spirit=false
resetChat();aura("party1",21562)
fire("UNIT_SPELLCAST_FAILED","player","cast",1126);advance(2);assert(#sent==0)
fire("UNIT_SPELLCAST_SUCCEEDED","player","cast1",1126);advance(0.5)
fire("UNIT_SPELLCAST_SUCCEEDED","player","cast2",21850);advance(0.7);assert(#sent==0)
aura("party1",1126,21562);advance(0.31)
assert(#sent==1 and sent[1].channel=="PARTY" and sent[1].text:find("Alle Gruppenbuffs vorhanden",1,true))
aura("party2",1126,23028)
fire("UNIT_SPELLCAST_SUCCEEDED","player","cast3",1126);advance(1.1);assert(#sent==1)
advance(61);fire("UNIT_SPELLCAST_SUCCEEDED","player","cast4",1126);advance(1.1)
assert(#sent==2 and sent[2].text:find("Seelenstärke",1,true))
advance(61);fire("UNIT_SPELLCAST_SUCCEEDED","player","cast5",1126);advance(1.1)
assert(#sent==2,"Identical reports must remain deduplicated after cooldown")
settings.autoChat=false;resetChat();fire("UNIT_SPELLCAST_SUCCEEDED","player","cast",1126);advance(2);assert(#sent==0)
settings.autoChat=true
units.party4.class="DRUID";resetChat()
fire("UNIT_SPELLCAST_SUCCEEDED","player","cast",1126)
fire("GROUP_ROSTER_UPDATE");advance(2);assert(#sent==0)
fire("UNIT_SPELLCAST_SUCCEEDED","party4","other",1126);advance(2);assert(#sent==0)
groupMode="RAID";raidCount=40
for i=1,40 do addUnit("raid"..i,"Raid"..i,i==1 and "DRUID" or "WARRIOR");aura("raid"..i,1126) end
units.raid1.guid="self";fire("GROUP_ROSTER_UPDATE");advance(0.21)
fire("UNIT_SPELLCAST_SUCCEEDED","player","raidcast",21850);advance(1.1);assert(#sent==0)
settings.autoRaid=true
fire("UNIT_SPELLCAST_SUCCEEDED","player","raidcast",21850);advance(1.1)
assert(#sent==1 and sent[1].channel=="RAID")
local page=b.GetPage(UIParent);page:Show();assert(#b.Snapshot().members==40 and #page.rows==12 and page.slider:IsShown())
local rosterAPI=GetNumGroupMembers
GetNumGroupMembers=function() error("Count unreadable") end
assert(b.Report(b.Scan()):find("unvollständig",1,true),"Unknown raid size cannot claim a full check")
GetNumGroupMembers=rosterAPI;b.Scan()
page.scripts.OnMouseWheel(page,-20);assert(page.offset==28 and page.rows[12].icons[1].member.unit=="raid40")
page.rows[12].icons[1].scripts.OnEnter(page.rows[12].icons[1]);assert(#GameTooltip.lines>1)
b.OpenConfig();assert(PaulchenBuffConfig:IsShown())
app.CompanionCommand("buffs");assert(openedPage=="buffs")
app.CompanionCommand("buffs check");assert(openedPage=="buffs")
app.CompanionCommand("buffs debug");assert(b.Settings().debug)
assert(#diagnostics>=41,"Debug output must remain local and include the raid")
settings.debug=false
groupMode="PARTY";fire("GROUP_ROSTER_UPDATE");advance(0.21);resetChat()
chatRestriction=true
assert(not b.Say(true) and #sent==0)
assert(not b.Say(false) and PaulchenBuffReport:IsShown() and PaulchenBuffReport.box:GetText():sub(1,3)=="/p ")
chatRestriction=false;syncBlock=true
assert(not b.Say(true) and #sent==0 and b.autoBlocked and app.Settings().buffChat.at==nil)
syncBlock=false;assert(not b.Say(true) and #sent==0)
resetChat();chatError=true;assert(not b.Say(true) and #sent==0);chatError=false
resetChat();assert(b.Say(false) and #sent==1)
assert(not b.Say(false) and #sent==1,"Manual clicks have their own short throttle")
resetChat();units.party2.far=true
fire("UNIT_SPELLCAST_SUCCEEDED","player","unknown",1126);advance(1.1)
assert(#sent==1 and sent[1].text:find("unvollständig",1,true))
units.party2.far=nil
knownSpells={[9001126]=true}
C_SpellBook.GetNumSpellBookSkillLines=function() return 1 end
C_SpellBook.GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=1} end
C_SpellBook.GetSpellBookItemInfo=function() return {spellID=9001126,name="Mal der Wildnis"} end
b.RefreshSpellNames();aura("player",9001126);s=b.Scan()
assert(s.members[1].buffs.wild.state=="PRESENT" and s.providers.wild=="AVAILABLE")
resetChat();fire("UNIT_SPELLCAST_SUCCEEDED","player","customrank",9001126);advance(1.1);assert(#sent==1)
groupMode="SOLO";units.player.class="PALADIN";knownSpells={[19740]=true};aura("player")
settings.blessings.PALADIN="kings";s=b.Scan();assert(not s.members[1].buffs.blessing.required)
knownSpells[20217]=true;s=b.Scan();assert(s.members[1].buffs.blessing.state=="MISSING")
aura("player",25898);s=b.Scan();assert(s.members[1].buffs.blessing.state=="PRESENT")
aura("player",19740);s=b.Scan();assert(s.members[1].buffs.blessing.state=="MISSING")
local api=C_UnitAuras;C_UnitAuras=nil;s=b.Scan();assert(s.missingCount==0 and s.checkedCount==0);C_UnitAuras=api
b.SetOption("cooldown",1);assert(settings.cooldown==60)
b.SetOption("cooldown",900);assert(settings.cooldown==600)
b.SetOption("enabled",false);advance(0.21);assert(reminders.mark==nil and not b.Say(true))
-- Nested class/variant configuration uses real menu callbacks as well as APIs.
local menuCallbacks={}
MenuUtil.CreateContextMenu=function(_,build)
 local node
 node=function(path)
  return {CreateTitle=function() end,CreateButton=function(_,caption) return node(path.."/"..caption) end,
   CreateRadio=function(_,caption,_,change) menuCallbacks[path.."/"..caption]=change end}
 end
 build(nil,node(""))
end
local menuButton
for _,frame in ipairs(frames) do if frame:GetText()=="Anforderungen pro Klasse" then menuButton=frame;break end end
assert(menuButton);menuButton.scripts.OnClick(menuButton)
menuCallbacks["/WARRIOR/Arkane Intelligenz/Pflicht"]()
assert(settings.requirements.WARRIOR.intellect=="on")
menuCallbacks["/ROGUE/Gewünschter Segen/Weisheit"]()
assert(settings.blessings.ROGUE=="wisdom")
''')
print('Buff watcher: solo/party/40-player raids; family/rank equivalence; actual learned spells/custom ranks; class/talent/blessing requirements; targeted/debounced auras; dead/offline/range/secret/combat UNKNOWN; post-cast/coalesced chat; cooldown/dedup; multi-druid and roster cancellation; raid defaults; restrictions/manual fallback; UI/slash/config and disable passed.')

# Fresh Lua VM: settings and the successful-send cooldown survive reload.
serialize=lua.eval('''function(value)
 local encode
 encode=function(v)
  if type(v)=="table" then
   local parts={};for k,item in pairs(v) do parts[#parts+1]="["..encode(k).."]="..encode(item) end
   return "{"..table.concat(parts,",").."}"
  elseif type(v)=="string" then return string.format("%q",v)
  else return tostring(v) end
 end
 return encode(value)
end''')
settings_saved=serialize(lua.globals().PaulchenQoLSettings)
character_saved=serialize(lua.globals().PaulchenQoLDB)
reload_lua=LuaRuntime()
reload_lua.execute(fixture)
reload_lua.execute(setup)
reload_lua.execute('PaulchenQoLSettings='+settings_saved+';PaulchenQoLDB='+character_saved+';now='+str(lua.globals().now))
reload_load=reload_lua.eval('function(code,name) assert(loadstring(code,name))("PaulchenQoL",app) end')
for name in ('Localization.lua','Core.lua','Style.lua','Config.lua'):
    reload_load((root/name).read_text(encoding='utf-8'),name)
reload_lua.execute('''
app.React=function() end;app.CancelReaction=function() end
app.SetCompanionReminder=function() end;app.RefreshOverview=function() end
''')
reload_load((root/'BuffCheck.lua').read_text(encoding='utf-8'),'BuffCheck.lua')
reload_lua.execute('''
local b=app.buffCheck
assert(not b.Settings().enabled and b.Settings().autoRaid and b.Settings().cooldown==600)
assert(b.Settings().requirements.DRUID.spirit=="off" and b.Settings().blessings.PALADIN=="kings")
assert(type(app.Settings().buffChat.at)=="number" and type(app.Settings().buffChat.signature)=="string")
b.SetOption("enabled",true)
groupMode="PARTY";partyCount=1;addUnit("party1","Reload","WARRIOR")
assert(not b.Say(true) and #sent==0,"A reload must not reset the automatic chat cooldown")
''')
print('Reload: fresh Lua runtime retains options, per-class requirements, blessing choice and successful-chat history/cooldown.')
