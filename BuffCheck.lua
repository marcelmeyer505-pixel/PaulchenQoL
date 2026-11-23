local _, app = ...
local buff = { PRESENT = "PRESENT", MISSING = "MISSING", UNKNOWN = "UNKNOWN" }
app.buffCheck = buff
local style = app.style
local snapshot, page, options, manualWindow
local queued, full, dirty, castTimer, castToken, rosterEpoch = false, true, {}, nil, 0, 0
local lastComment, sending, blockedDuringSend, manualAt
local familyByID, familyByName = {}, {}
local classes = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
local mana = { DRUID=true, HUNTER=true, MAGE=true, PALADIN=true, PRIEST=true, SHAMAN=true, WARLOCK=true }
local defaults = { enabled=true, self=true, group=true, raid=true, autoChat=true, autoRaid=false,
    comments=true, showWindow=true, cooldown=60, debug=false }
buff.families = {
    { key="wild", label="Mal der Wildnis", class="DRUID", minimum=1, icon="Spell_Nature_Regeneration",
        names={"Mal der Wildnis","Gabe der Wildnis","Mark of the Wild","Gift of the Wild"},
        ids={1126,5232,6756,5234,8907,9884,9885,21849,21850} },
    { key="fortitude", label="Seelenstärke", class="PRIEST", minimum=1, icon="Spell_Holy_WordFortitude",
        names={"Machtwort: Seelenstärke","Gebet der Seelenstärke","Power Word: Fortitude","Prayer of Fortitude"},
        ids={1243,1244,1245,2791,10937,10938,21562,21564} },
    { key="intellect", label="Arkane Intelligenz", class="MAGE", minimum=1, mana=true, icon="Spell_Holy_MagicalSentry",
        names={"Arkane Intelligenz","Arkane Brillanz","Arcane Intellect","Arcane Brilliance"},
        ids={1459,1460,1461,10156,10157,23028} },
    { key="spirit", label="Göttlicher Wille", class="PRIEST", minimum=30, mana=true, optional=true, talent=true,
        icon="Spell_Holy_DivineSpirit", names={"Göttlicher Wille","Gebet der Willenskraft","Divine Spirit","Prayer of Spirit"},
        ids={14752,14818,14819,27841,27681} },
    { key="shadow", label="Schattenschutz", class="PRIEST", minimum=30, optional=true, icon="Spell_Shadow_AntiShadow",
        names={"Schattenschutz","Gebet des Schattenschutzes","Shadow Protection","Prayer of Shadow Protection"},
        ids={976,10957,10958,27683} },
    { key="blessing", label="Segen", class="PALADIN", minimum=4, icon="Spell_Holy_FistOfJustice",
        names={}, ids={}, variants={
            {key="might",label="Macht",names={"Segen der Macht","Großer Segen der Macht","Blessing of Might","Greater Blessing of Might"},ids={19740,19834,19835,19836,19837,19838,25291,25782,25916}},
            {key="wisdom",minimum=14,label="Weisheit",names={"Segen der Weisheit","Großer Segen der Weisheit","Blessing of Wisdom","Greater Blessing of Wisdom"},ids={19742,19850,19852,19853,19854,25290,25894,25918}},
            {key="kings",minimum=20,talent=true,label="Könige",names={"Segen der Könige","Großer Segen der Könige","Blessing of Kings","Greater Blessing of Kings"},ids={20217,25898}},
            {key="salvation",minimum=26,label="Rettung",names={"Segen der Rettung","Großer Segen der Rettung","Blessing of Salvation","Greater Blessing of Salvation"},ids={1038,25895}},
            {key="light",minimum=40,label="Licht",names={"Segen des Lichts","Großer Segen des Lichts","Blessing of Light","Greater Blessing of Light"},ids={19977,19978,19979,25890}},
            {key="sanctuary",minimum=30,talent=true,label="Refugium",names={"Segen des Refugiums","Großer Segen des Refugiums","Blessing of Sanctuary","Greater Blessing of Sanctuary"},ids={20911,20912,20913,20914,25899}},
        } },
}
local byKey = {}
for _, family in ipairs(buff.families) do byKey[family.key] = family end

local function secret(value)
    if not issecretvalue then return false end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result == true
end
local function readable(value) if not secret(value) then return value end end
local function call(api, ...)
    if type(api) ~= "function" then return end
    local ok, a, b, c = pcall(api, ...)
    if ok then return readable(a), readable(b), readable(c) end
end
local function field(value, key)
    if secret(value) or type(value) ~= "table" then return end
    local ok, result = pcall(function() return value[key] end)
    if ok then return readable(result) end
end
local function text(value, fallback)
    value = readable(value)
    return type(value) == "string" and value:gsub("[%z\1-\31|]", "") or fallback
end
local function clock() return call(GetTime) or 0 end
local function serverTime() return call(GetServerTime or time) or clock() end
local function combat() return call(InCombatLockdown) == true end

function buff.Settings()
    local profile = app.Profile()
    if type(profile.buffWatcher) ~= "table" then profile.buffWatcher = {} end
    local db = profile.buffWatcher
    for key, value in pairs(defaults) do if type(db[key]) ~= type(value) then db[key] = value end end
    db.cooldown = math.max(60, math.min(600, tonumber(db.cooldown) or 60))
    if db.cooldown ~= db.cooldown then db.cooldown = 60 end
    if type(db.families) ~= "table" then db.families = {} end
    if type(db.requirements) ~= "table" then db.requirements = {} end
    if type(db.blessings) ~= "table" then db.blessings = {} end
    for _, family in ipairs(buff.families) do
        if type(db.families[family.key]) ~= "boolean" then db.families[family.key] = not family.optional end
    end
    return db
end

local function register(family, entry, variant)
    local function name(value)
        value = text(value)
        if value and value ~= "" then familyByName[value] = {family=family,variant=variant} end
    end
    for _, value in ipairs(entry.names) do name(value) end
    for _, id in ipairs(entry.ids) do
        familyByID[id] = {family=family,variant=variant}
        name(call(C_Spell and C_Spell.GetSpellName or GetSpellInfo, id))
    end
end
function buff.RefreshSpellNames()
    familyByID = {}
    familyByName = {}
    for _, family in ipairs(buff.families) do
        register(family, family)
        for _, variant in ipairs(family.variants or {}) do register(family, variant, variant.key) end
    end
    -- Forever-specific ranks can be learned by the same localized spell name.
    local book=C_SpellBook
    local total=book and call(book.GetNumSpellBookSkillLines)
    if type(total)=="number" and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo then
        local inspected=0
        for line=1,math.min(40,total) do
            local info=call(book.GetSpellBookSkillLineInfo,line)
            local offset,count=field(info,"itemIndexOffset"),field(info,"numSpellBookItems")
            if type(offset)=="number" and type(count)=="number" then
                for index=offset+1,offset+math.min(400,count) do
                    inspected=inspected+1
                    if inspected>4096 then return end
                    local slot=call(book.GetSpellBookItemInfo,index,Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0)
                    local id=field(slot,"spellID")
                    if type(id)=="number" then
                        local name=text(field(slot,"name")) or text(call(C_Spell and C_Spell.GetSpellName or GetSpellInfo,id))
                        if name and familyByName[name] then familyByID[id]=familyByName[name] end
                    end
                end
            end
        end
    end
end
local function known(family,variant)
    local api = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell or IsSpellKnown
    if not api then return end
    local unknown = false
    for id, entry in pairs(familyByID) do
        if entry.family == family and (not variant or entry.variant==variant) then
            local value = call(api, id)
            if value == true then return true end
            if value == nil then unknown = true end
        end
    end
    if not unknown then return false end
end
local function restricted(lastKind)
    if combat() then return true end
    if C_RestrictedActions then
        for kind = 0, lastKind do
            if C_RestrictedActions.GetAddOnRestrictionState then
                local state = call(C_RestrictedActions.GetAddOnRestrictionState, kind)
                if state == nil or state ~= 0 then return true end
            elseif C_RestrictedActions.IsAddOnRestrictionActive
                and call(C_RestrictedActions.IsAddOnRestrictionActive, kind) ~= false then return true end
        end
    end
    return false
end
local function mode()
    if call(IsInRaid) == true then return "RAID" end
    if call(IsInGroup) == true or (call(GetNumSubgroupMembers) or 0) > 0 then return "PARTY" end
    return "SOLO"
end
local function identity(unit, groupStatus)
    local name, realm = call(UnitFullName or UnitName, unit)
    name, realm = text(name, unit), text(realm)
    if realm and realm ~= "" then name = name .. "-" .. realm end
    local _, class = call(UnitClass, unit)
    class = text(class, "UNKNOWN")
    return {unit=unit, name=name, class=class, guid=text(call(UnitGUID, unit), unit), groupStatus=groupStatus,
        isSelf=unit == "player" or call(UnitIsUnit, unit, "player") == true,
        level=call(UnitLevel, unit), buffs={}, present={}, missing={}, unknown={} }
end
local function roster()
    local currentMode, units, unknown = mode(), {}, false
    if currentMode == "RAID" then
        local total = call(GetNumGroupMembers)
        unknown=type(total)~="number" or total~=total or total<1 or total>40
        if unknown then total=0 end
        for index=1,math.min(40, type(total) == "number" and math.max(0,total) or 0) do
            units[#units+1] = identity("raid" .. index, currentMode)
        end
        if #units == 0 then units[1] = identity("player", currentMode) end
    else
        units[1] = identity("player", currentMode)
        if currentMode == "PARTY" then
            local total = call(GetNumSubgroupMembers)
            if type(total) ~= "number" then
                local count=call(GetNumGroupMembers)
                if type(count)=="number" then total=count-1 else total=0;unknown=true end
            end
            if total~=total or total<1 or total>4 then unknown=true;total=math.max(0,math.min(4,total==total and total or 0)) end
            for index=1,math.min(4,math.max(0,total)) do units[#units+1] = identity("party" .. index,currentMode) end
        end
    end
    return units, currentMode, unknown
end
local function providerStates(members)
    local result = {}
    for _, family in ipairs(buff.families) do
        local function availability(variant)
            local available, unknown = false, false
            for _, member in ipairs(members) do
                if member.class == family.class then
                    if member.isSelf then
                        local value = known(family,variant and variant.key)
                        available, unknown = available or value == true, unknown or value == nil
                    elseif type(member.level) ~= "number" then
                        unknown = true
                    elseif member.level >= (variant and variant.minimum or family.minimum) then
                        if family.talent or variant and variant.talent or call(UnitIsConnected,member.unit) ~= true then unknown = true
                        else available = true end
                    end
                elseif member.class == "UNKNOWN" then unknown = true end
            end
            return available and "AVAILABLE" or unknown and "UNKNOWN" or "UNAVAILABLE"
            end
        result[family.key]=availability()
        for _,variant in ipairs(family.variants or {}) do result[family.key .. ":" .. variant.key]=availability(variant) end
    end
    return result
end
local function checkable(member)
    if restricted(4) then return false, app.L("Aura-Daten im Kampf oder durch den Client geschützt") end
    local exists=call(UnitExists,member.unit)
    if exists==false or type(UnitExists)=="function" and exists~=true then return false, app.L("Nicht erreichbar / Existenz unbekannt") end
    if call(UnitIsDeadOrGhost,member.unit) ~= false then return false, app.L("Tot, Geist oder Lebensstatus unbekannt") end
    if not member.isSelf then
        if call(UnitIsConnected,member.unit) ~= true then return false, app.L("Offline oder Verbindung unbekannt") end
        if call(UnitIsVisible,member.unit) ~= true then return false, app.L("Nicht sichtbar / außerhalb der überprüfbaren Reichweite") end
        local inRange, checked = call(UnitInRange,member.unit)
        if inRange ~= true or checked == false then return false, app.L("Außerhalb der überprüfbaren Reichweite") end
    end
    return true
end
local function readAuras(member)
    local found, ok, reason = {}, checkable(member)
    if not ok then return found, false, reason end
    local api = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not api then return found, false, app.L("Aura-API nicht verfügbar") end
    local complete = true
    for index=1,255 do
        local success, aura = pcall(api,member.unit,index,"HELPFUL")
        if not success or secret(aura) then return found, false, app.L("Aura-Daten geschützt oder nicht lesbar") end
        if aura == nil then
            if complete then return found,true end
            return found,false,app.L("Einzelne Aura-Daten nicht lesbar")
        end
        local id, name = field(aura,"spellId"), field(aura,"name")
        local entry = type(id) == "number" and familyByID[id] or type(name) == "string" and familyByName[name]
        if entry then
            local values = found[entry.family.key] or {}
            values[entry.variant or "any"] = {spellID=type(id)=="number" and id or nil, name=text(name,entry.family.label)}
            found[entry.family.key] = values
        end
        -- An unidentifiable aura could be any missing family: fail closed.
        if type(id) ~= "number" then complete = false end
    end
    return found, false, app.L("Aura-Liste nicht vollständig lesbar")
end
local function requirement(member, family, providers)
    local settings = buff.Settings()
    if not settings.families[family.key] then return false, app.L("Bufffamilie deaktiviert") end
    local custom = settings.requirements[member.class]
    local value = type(custom)=="table" and custom[family.key] or "auto"
    if value == "off" then return false, app.L("Für diese Klasse deaktiviert") end
    if value == "on" then return true end
    if family.mana and member.class=="UNKNOWN" then return true,app.L("Klasseninformation nicht lesbar") end
    if family.mana and not mana[member.class] then return false, app.L("Für diese Klasse nicht erforderlich") end
    local provider = providers[family.key]
    if family.key=="blessing" then
        local variant=settings.blessings[member.class]
        if variant and variant~="any" then provider=providers["blessing:" .. variant] end
    end
    if provider == "UNAVAILABLE" then return false, app.L("Kein verfügbarer Buffgeber / Zauber nicht erlernt") end
    if provider ~= "AVAILABLE" then return true, app.L("Fähigkeit des Buffgebers nicht überprüfbar") end
    return true
end
local function inspect(member, providers)
    member.present, member.missing, member.unknown, member.buffs = {}, {}, {}, {}
    local settings = buff.Settings()
    member.checked = settings.enabled and (member.isSelf and settings.self or not member.isSelf and settings.group)
        and (member.groupStatus ~= "RAID" or settings.raid)
    local found, complete, reason
    if member.checked then found,complete,reason = readAuras(member)
    else found,complete,reason = {},false,app.L("Prüfung ausgeschaltet") end
    member.reason,member.verifiable = reason,member.checked and complete
    for _, family in ipairs(buff.families) do
        local required, why = requirement(member,family,providers)
        local variant = family.key=="blessing" and settings.blessings[member.class] or "any"
        if not variant or variant == "" then variant = "any" end
        local auras = found[family.key]
        local present = auras and (variant=="any" and next(auras)~=nil or auras[variant]~=nil)
        local state = present and buff.PRESENT or required and member.checked and not why and complete and buff.MISSING or buff.UNKNOWN
        local entry = {state=state,required=required,reason=not member.checked and reason or why or not complete and reason or nil,
            variant=variant,auras=auras}
        member.buffs[family.key] = entry
        if required and member.checked then
            local list = state==buff.PRESENT and member.present or state==buff.MISSING and member.missing or member.unknown
            list[#list+1] = family.key
        end
    end
    return member
end
local function fingerprint(data)
    local result,group = {},{}
    for _, member in ipairs(data.members) do
        local row={member.guid,member.name,tostring(member.checked),tostring(member.verifiable)}
        group[#group+1]=member.guid
        for _, family in ipairs(buff.families) do
            local entry = member.buffs[family.key]
            if entry.required then row[#row+1] = family.key .. ":" .. entry.state .. ":" .. entry.variant end
        end
        result[#result+1]=table.concat(row,":")
    end
    table.sort(result);table.sort(group)
    data.groupSignature=data.mode .. ":" .. table.concat(group,",")
    return data.mode .. ";" .. tostring(data.rosterUnknown) .. ";" .. table.concat(result,";")
end
local function publish(data)
    data.missingCount, data.unknownCount, data.checkedCount, data.unverifiableCount = 0,0,0,0
    data.excluded = data.rosterUnknown == true
    data.requiredCount = 0
    for _, member in ipairs(data.members) do
        data.missingCount = data.missingCount + #member.missing
        data.unknownCount = data.unknownCount + #member.unknown
        data.requiredCount = data.requiredCount + #member.present + #member.missing + #member.unknown
        if member.checked then
            if member.verifiable then data.checkedCount=data.checkedCount+1 else data.unverifiableCount=data.unverifiableCount+1 end
        else data.excluded = true end
    end
    data.signature, data.at = fingerprint(data), clock()
    snapshot = data
    local own
    for _, member in ipairs(data.members) do if member.isSelf then own=member;break end end
    local wild = own and own.class == "DRUID" and own.checked and own.buffs.wild
    app.SetCompanionReminder("mark",wild and wild.required and wild.state==buff.MISSING and app.L("Mal der Wildnis fehlt.") or nil)
    if buff.Render then buff.Render() end
    if data.signature ~= lastComment then
        lastComment = data.signature
        app.CancelReaction("buffMissing"); app.CancelReaction("buffReady")
        if buff.Settings().enabled and buff.Settings().comments then
            local first
            for _, member in ipairs(data.members) do
                if #member.missing>0 and not (member.isSelf and #member.missing==1 and member.missing[1]=="wild") then first=member;break end
            end
            if first then app.React("buffMissing",{name=first.name,buff=byKey[first.missing[1]].label})
            elseif data.mode~="SOLO" and data.requiredCount>0 and data.missingCount==0 and data.unknownCount==0 and data.unverifiableCount==0 and not data.excluded then
                app.React("buffReady")
            end
        end
    end
    return data
end
function buff.Scan()
    local members,currentMode,unknown = roster()
    local providers = providerStates(members)
    for _, member in ipairs(members) do inspect(member,providers) end
    return publish({members=members,mode=currentMode,providers=providers,rosterUnknown=unknown})
end
function buff.Snapshot() return snapshot or buff.Scan() end
function app.GetGroupBuffStatus() return buff.Scan() end
function buff.Request(unit, all)
    full = full or all
    if type(unit)=="string" then dirty[unit]=true end
    if queued then return end
    queued = true
    C_Timer.After(0.2,function()
        queued = false
        local units,all = dirty,full
        dirty,full = {},false
        if all or not snapshot then buff.Scan();return end
        local changed = false
        for _, member in ipairs(snapshot.members) do
            if units[member.unit] or member.isSelf and units.player then inspect(member,snapshot.providers);changed=true end
        end
        if changed then publish(snapshot) end
    end)
end

local function utf8limit(value, maximum)
    if #value<=maximum then return value end
    local stop=maximum
    while stop>0 and value:byte(stop+1) and value:byte(stop+1)>=128 and value:byte(stop+1)<192 do stop=stop-1 end
    return value:sub(1,stop)
end
function buff.Report(data)
    data = data or buff.Snapshot()
    if data.checkedCount==0 then return app.L("[Paulchen] Buffcheck unvollständig: Keine Spieler vollständig überprüfbar.") end
    local incomplete=data.unknownCount>0 or data.unverifiableCount>0 or data.excluded
    local prefix = "[Paulchen] Buffcheck" .. (incomplete and app.L(" unvollständig") or "") .. ": "
    local parts = {}
    for _, family in ipairs(buff.families) do
        local names = {}
        for _, member in ipairs(data.members) do
            if member.checked and member.buffs[family.key].required and member.buffs[family.key].state==buff.MISSING then names[#names+1]=member.name end
        end
        if #names>0 then
            local who = #names<=2 and table.concat(names,", ") or names[1] .. app.L(" und ") .. (#names-1) .. app.L(" weitere")
            parts[#parts+1] = family.label .. app.L(" fehlt ") .. who
        end
    end
    if #parts==0 then
        parts[1] = (data.unknownCount>0 or data.unverifiableCount>0) and app.L("Keine sicher fehlenden Buffs; Status teilweise unbekannt.")
            or data.excluded and app.L("Geprüfte Buffs vorhanden; Prüfung nicht vollständig.")
            or data.requiredCount==0 and app.L("Keine Buffanforderungen für diese Gruppe.")
            or app.L("Alle Gruppenbuffs vorhanden! So gefällt mir das!")
    end
    if data.unknownCount>0 and data.missingCount>0 then parts[#parts+1]=data.unknownCount .. app.L(" Buffstatus unbekannt") end
    local result = prefix .. table.concat(parts," | ")
    if #result>250 then result=prefix .. data.missingCount .. app.L(" Buffs fehlen; ") .. data.unknownCount .. app.L(" Status unbekannt. Details in Paulchens Buffwächter.") end
    return utf8limit(result,250)
end
local function chatChannel(currentMode)
    if currentMode=="SOLO" then return end
    local instanceCategory=Enum and Enum.PartyCategory and Enum.PartyCategory.Instance
    if instanceCategory and call(IsInGroup,instanceCategory)==true then return "INSTANCE_CHAT" end
    return currentMode=="RAID" and "RAID" or "PARTY"
end
local function chatRestricted()
    if restricted(5) then return true end
    if C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
        and call(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)~=false then return true end
    return false
end
local function history()
    local db=app.Settings()
    if type(db.buffChat)~="table" then db.buffChat={} end
    return db.buffChat
end
function buff.Say(automatic)
    local settings=buff.Settings()
    if not settings.enabled then buff.notice=app.L("Buffwächter ausgeschaltet.");return false end
    local data=buff.Scan()
    local channel=chatChannel(data.mode)
    if not channel then buff.notice=app.L("Solospiel: kein Gruppenchatbericht.");return false end
    if automatic and (data.requiredCount == 0 or not settings.autoChat or not settings.group
        or data.mode=="RAID" and (not settings.raid or not settings.autoRaid)) then return false end
    local previous,now=history(),serverTime()
    if automatic and (previous.signature==data.signature or type(previous.at)=="number" and now-previous.at<settings.cooldown) then return false end
    if not automatic and manualAt and clock()-manualAt<5 then buff.notice=app.L("Bitte kurz warten.");return false end
    local message=buff.Report(data)
    if automatic and previous.message==message and previous.group==data.groupSignature then return false end
    local api=C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if buff.autoBlocked or chatRestricted() or not api then
        buff.notice=app.L("Chat eingeschränkt. Bericht über 'Bericht übernehmen' manuell ausgeben.")
        if not automatic then buff.ManualReport(message,channel) end
        if buff.Render then buff.Render() end
        return false
    end
    sending,blockedDuringSend=true,false
    local ok,result=pcall(api,message,channel)
    sending=false
    if not ok or secret(result) or result==false or blockedDuringSend then
        buff.autoBlocked=true
        buff.notice=app.L("Chatversand vom Client abgelehnt; manueller Bericht verfügbar.")
        if not automatic then buff.ManualReport(message,channel) end
        if buff.Render then buff.Render() end
        return false
    end
    previous.at,previous.signature,previous.message,previous.group=now,data.signature,message,data.groupSignature
    if not automatic then manualAt=clock() end
    buff.notice=app.L("Buffbericht gesendet · ") .. channel
    if buff.Render then buff.Render() end
    return true
end
local function cancelCast()
    castToken=castToken+1
    if castTimer then castTimer:Cancel();castTimer=nil end
end
function buff.CastSucceeded(unit, spellID)
    unit,spellID=readable(unit),readable(spellID)
    if unit~="player" or type(spellID)~="number" then return end
    local entry=familyByID[spellID]
    if not entry then
        local name=call(C_Spell and C_Spell.GetSpellName or GetSpellInfo,spellID)
        if type(name)=="string" then entry=familyByName[name] end
    end
    if not entry or entry.family.key~="wild" then return end
    local _,class=call(UnitClass,"player")
    local settings=buff.Settings()
    if class~="DRUID" or not settings.enabled or not settings.autoChat or mode()=="SOLO" then return end
    cancelCast()
    local token,epoch=castToken,rosterEpoch
    castTimer=C_Timer.NewTimer(1,function()
        castTimer=nil
        if token~=castToken or epoch~=rosterEpoch then return end
        buff.Say(true)
    end)
end

function buff.SetOption(key,value)
    local db=buff.Settings()
    if key=="cooldown" then value=math.max(60,math.min(600,tonumber(value) or 60)) end
    if defaults[key]==nil or type(value)~=type(defaults[key]) then return end
    db[key]=value
    cancelCast()
    if not db.comments or not db.enabled then app.CancelReaction("buffMissing");app.CancelReaction("buffReady") end
    buff.Request(nil,true)
    if app.RefreshBuffTab then app.RefreshBuffTab() end
end
function buff.SetRequirement(class,key,value)
    if not byKey[key] or (value~="auto" and value~="on" and value~="off") then return end
    local db=buff.Settings()
    db.requirements[class]=type(db.requirements[class])=="table" and db.requirements[class] or {}
    db.requirements[class][key]=value
    buff.Request(nil,true)
end

local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","UNIT_AURA",
    "UNIT_SPELLCAST_SUCCEEDED","SPELLS_CHANGED","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED",
    "PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_DEAD","UNIT_CONNECTION","UNIT_FLAGS","UNIT_PHASE",
    "UNIT_IN_RANGE_UPDATE","ZONE_CHANGED_NEW_AREA","ADDON_RESTRICTION_STATE_CHANGED",
    "ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do app.RegisterSupported(events,event) end
events:SetScript("OnEvent",function(_,event,unit,_,spellID)
    app.SecureCall(app.L("Buffwächter"),function()
        if event=="ADDON_ACTION_BLOCKED" or event=="ADDON_ACTION_FORBIDDEN" then
            if sending then blockedDuringSend=true end
        elseif event=="UNIT_SPELLCAST_SUCCEEDED" then buff.CastSucceeded(unit,spellID)
        elseif event=="UNIT_CONNECTION" then buff.Request(nil,true)
        elseif event=="UNIT_AURA" or event=="UNIT_FLAGS" or event=="UNIT_PHASE" or event=="UNIT_IN_RANGE_UPDATE" then
            unit=readable(unit)
            if type(unit)=="string" and (unit=="player" or unit:match("^party%d+$") or unit:match("^raid%d+$")) then buff.Request(unit) end
        else
            if event=="GROUP_ROSTER_UPDATE" or event=="PLAYER_ENTERING_WORLD" then rosterEpoch=rosterEpoch+1;cancelCast() end
            if event=="SPELLS_CHANGED" or event=="PLAYER_LOGIN" then buff.RefreshSpellNames() end
            buff.Request(nil,true)
        end
    end)
end)
buff.RefreshSpellNames()

local stateColors = { PRESENT={0.35,0.90,0.45}, MISSING={1,0.33,0.28}, UNKNOWN={0.62,0.64,0.67} }
local stateLabels = { PRESENT=app.L("Vorhanden"), MISSING=app.L("Fehlt"), UNKNOWN=app.L("Unbekannt") }
local function label(parent,value,x,y,w,h,color,font)
    return style.Label(parent,value,x,y,w,h,font or "GameFontHighlightSmall",color or style.cream)
end
local function button(parent,value,x,y,w,action)
    local control=style.TextButton(parent)
    control:SetPoint("TOPLEFT",x,y);control:SetSize(w,27);control:SetText(value)
    control:SetScript("OnClick",action)
    return control
end
local function className(class)
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
end
local function tooltip(icon)
    local member,family=icon.member,icon.family
    if not member then return end
    local entry=member.buffs[family.key]
    GameTooltip:SetOwner(icon,"ANCHOR_RIGHT")
    GameTooltip:AddLine(family.label,unpack(style.gold))
    GameTooltip:AddLine(member.name .. " · " .. stateLabels[entry.state],unpack(stateColors[entry.state]))
    if not entry.required then GameTooltip:AddLine(app.L("Nicht angefordert"),unpack(style.muted)) end
    if entry.variant~="any" then
        for _, variant in ipairs(family.variants or {}) do
            if variant.key==entry.variant then GameTooltip:AddLine("Gewünschter Segen: " .. variant.label,unpack(style.cream)) end
        end
    end
    if entry.reason then GameTooltip:AddLine(entry.reason,0.72,0.72,0.72,true) end
    if entry.auras then
        for _, aura in pairs(entry.auras) do GameTooltip:AddLine(aura.name,0.5,0.9,0.6) end
    end
    GameTooltip:Show()
end
function buff.Render()
    if not page or not page:IsVisible() or not snapshot then return end
    local data=snapshot
    local maximum=math.max(0,#data.members-12)
    page.offset=math.max(0,math.min(maximum,page.offset or 0))
    page.slider:SetMinMaxValues(0,maximum);page.slider:SetValue(page.offset);page.slider:SetShown(maximum>0)
    page.summary:SetText(("%s · %d Spieler · %d geprüft · %d Buffs fehlen · %d unbekannt")
        :format(data.mode=="RAID" and app.L("Raid") or data.mode=="PARTY" and app.L("Gruppe") or "Solo",#data.members,data.checkedCount,data.missingCount,data.unknownCount)
        .. ((data.excluded or data.unverifiableCount>0) and " · unvollständig" or ""))
    page.notice:SetText(not buff.Settings().enabled and app.L("Buffwächter ausgeschaltet.") or buff.notice or app.L("Nur sicher lesbare Daten werden als fehlend bewertet."))
    for index,row in ipairs(page.rows) do
        local member=data.members[index+page.offset]
        row:SetShown(member~=nil)
        if member then
            row.name:SetText(member.name)
            local classColor=RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.class]
            row.name:SetTextColor(classColor and classColor.r or 0.9,classColor and classColor.g or 0.86,classColor and classColor.b or 0.75)
            local missing={}
            for _,key in ipairs(member.missing) do missing[#missing+1]=byKey[key].label end
            local status=#missing>0 and table.concat(missing,", ") or not member.checked and app.L("Prüfung ausgeschaltet")
                or (#member.unknown>0 or not member.verifiable) and (member.reason or app.L("Buffstatus teilweise unbekannt"))
                or #member.present>0 and app.L("Alles vorhanden") or app.L("Keine Buffanforderungen")
            if #missing>0 and #member.unknown>0 then status=status .. " · weitere unbekannt" end
            row.status:SetText(status)
            local state=#missing>0 and buff.MISSING or (#member.unknown>0 or not member.checked or not member.verifiable) and buff.UNKNOWN or buff.PRESENT
            row.status:SetTextColor(unpack(stateColors[state]))
            for _,icon in ipairs(row.icons) do
                icon.member=member
                icon:SetBackdropBorderColor(unpack(stateColors[member.buffs[icon.family.key].state]))
                icon.art:SetDesaturated(member.buffs[icon.family.key].state==buff.UNKNOWN)
            end
        else
            for _,icon in ipairs(row.icons) do icon.member=nil end
        end
    end
end
function buff.GetPage(parent)
    if page then return page end
    local f=CreateFrame("Frame",nil,parent)
    page=f;f:Hide();f:SetSize(860,610);f.offset=0;f.rows={}
    label(f,app.L("Paulchens Buffwächter"),18,-12,640,28,style.gold,"GameFontNormalLarge")
    label(f,app.L("Wildnis · Seelenstärke · Intelligenz · Wille · Schattenschutz · Segen"),18,-44,820,21,style.muted)
    button(f,app.L("Aktualisieren"),18,-76,130,function() buff.Scan() end)
    button(f,app.L("Im Gruppenchat"),156,-76,160,function() buff.Say(false) end)
    button(f,app.L("Bericht übernehmen"),324,-76,180,function() buff.ManualReport(buff.Report(buff.Scan()),chatChannel(mode())) end)
    button(f,app.L("Einstellungen"),674,-76,168,function() buff.OpenConfig() end)
    f.summary=label(f,"",18,-112,824,24,style.gold)
    label(f,app.L("Spieler"),18,-145,170,24,style.muted)
    label(f,app.L("Buffstatus"),195,-145,210,24,style.muted)
    label(f,app.L("Fehlende Buffs / Prüfbarkeit"),420,-145,390,24,style.muted)
    for index=1,12 do
        local row=CreateFrame("Frame",nil,f)
        row:SetPoint("TOPLEFT",18,-173-(index-1)*30);row:SetSize(806,29);style.Row(row,index)
        row.name=label(row,"",5,0,164,29)
        row.status=label(row,"",402,0,394,29)
        row.icons={}
        for n,family in ipairs(buff.families) do
            local icon=CreateFrame("Frame",nil,row,"BackdropTemplate")
            icon:SetSize(26,26);icon:SetPoint("TOPLEFT",177+(n-1)*34,-1);icon:EnableMouse(true)
            style.Panel(icon,style.track)
            icon.family=family
            icon.art=icon:CreateTexture(nil,"ARTWORK");icon.art:SetPoint("TOPLEFT",2,-2);icon.art:SetPoint("BOTTOMRIGHT",-2,2)
            local texture=call(C_Spell and C_Spell.GetSpellTexture or GetSpellTexture,family.ids[1] or 19740)
            icon.art:SetTexture(texture or "Interface\\Icons\\" .. family.icon)
            icon:SetScript("OnEnter",tooltip)
            icon:SetScript("OnLeave",function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
            row.icons[#row.icons+1]=icon
        end
        f.rows[index]=row
    end
    local slider=CreateFrame("Slider",nil,f)
    slider:SetPoint("TOPRIGHT",-12,-173);slider:SetSize(14,360);slider:SetOrientation("VERTICAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob");slider:SetValueStep(1);slider:SetObeyStepOnDrag(true)
    slider:SetScript("OnValueChanged",function(_,value)
        value=math.floor(value+0.5)
        if value~=f.offset then f.offset=value;buff.Render() end
    end)
    f.slider=slider
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel",function(_,delta) f.offset=f.offset-delta*3;buff.Render() end)
    label(f,"|cff59e673Vorhanden|r · |cffff5447Fehlt|r · |cff9ea3abUnbekannt / nicht angefordert|r",18,-545,824,22)
    f.notice=label(f,"",18,-572,824,32,style.muted);f.notice:SetWordWrap(true)
    f:SetScript("OnShow",function() buff.Scan() end)
    local elapsed=0
    f:SetScript("OnUpdate",function(_,delta)
        elapsed=elapsed+delta
        if elapsed<2 or not snapshot then return end
        elapsed=0
        -- Range events differ between clients. While visible, retry only
        -- unknown members or members whose accessibility has changed.
        for _,member in ipairs(snapshot.members) do
            if member.checked and (not member.verifiable or checkable(member)~=member.verifiable) then buff.Request(member.unit) end
        end
    end)
    return f
end
function buff.ManualReport(message,channel)
    if not manualWindow then
        local f=CreateFrame("Frame","PaulchenBuffReport",UIParent,"BackdropTemplate")
        manualWindow=f;f:SetSize(700,190);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");style.Panel(f,style.background)
        label(f,app.L("Buffbericht · Strg+C zum Kopieren"),18,-12,630,26,style.gold,"GameFontNormalLarge")
        label(f,app.L("Manuell in den Gruppenchat einfügen und mit Enter senden."),18,-45,664,24,style.muted)
        f.box=style.EditBox(f);f.box:SetPoint("TOPLEFT",18,-78);f.box:SetSize(664,60);f.box:SetMultiLine(true)
        f.box:SetMaxLetters(300);f.box:SetScript("OnEscapePressed",function() f:Hide() end)
        local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT");close:SetScript("OnClick",function() f:Hide() end)
        f:SetScript("OnHide",function() f.box:ClearFocus() end)
        UISpecialFrames[#UISpecialFrames+1]=f:GetName()
    end
    local prefix=channel=="RAID" and "/raid " or channel=="INSTANCE_CHAT" and "/i " or channel=="PARTY" and "/p " or ""
    manualWindow.box:SetText(prefix .. message);manualWindow:Show();manualWindow.box:SetFocus();manualWindow.box:HighlightText()
end
local function refreshOptions()
    if options and options:IsShown() then for _,sync in ipairs(options.controls) do sync() end end
end
local function requirementMenu(owner)
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end
    MenuUtil.CreateContextMenu(owner,function(_,root)
        root:CreateTitle(app.L("Anforderungen pro Zielklasse"))
        for _,class in ipairs(classes) do
            local branch=root:CreateButton(className(class))
            for _,family in ipairs(buff.families) do
                local choices=branch:CreateButton(family.label)
                for _,choice in ipairs({{"auto",app.L("Automatisch")},{"on",app.L("Pflicht")},{"off",app.L("Aus")}}) do
                    local key,value=family.key,choice[1]
                    choices:CreateRadio(choice[2],function()
                        local custom=buff.Settings().requirements[class]
                        return (type(custom)=="table" and custom[key] or "auto")==value
                    end,function() buff.SetRequirement(class,key,value) end)
                end
            end
            local blessings=branch:CreateButton(app.L("Gewünschter Segen"))
            local choices={{key="any",label=app.L("Beliebiger Segen")}}
            for _,variant in ipairs(byKey.blessing.variants) do choices[#choices+1]=variant end
            for _,variant in ipairs(choices) do
                local key=variant.key
                blessings:CreateRadio(variant.label,function() return (buff.Settings().blessings[class] or "any")==key end,function()
                    buff.Settings().blessings[class]=key;buff.Request(nil,true)
                end)
            end
        end
    end)
end
function buff.OpenConfig()
    if not options then
        local f=CreateFrame("Frame","PaulchenBuffConfig",UIParent,"BackdropTemplate")
        options=f;f:Hide();f:SetSize(720,530);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");style.Panel(f,style.background)
        f:SetScale(math.min(1,(UIParent:GetWidth()-20)/720,(UIParent:GetHeight()-20)/530))
        label(f,"Paulchen · Buffwächter",18,-12,650,28,style.gold,"GameFontNormalLarge")
        local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT");close:SetScript("OnClick",function() f:Hide() end)
        f.controls={}
        local function check(caption,x,y,get,set)
            local control=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
            control:SetSize(24,24);control:SetPoint("TOPLEFT",x,y)
            label(control,caption,28,0,306,24)
            control:SetScript("OnClick",function(self) set(not not self:GetChecked());refreshOptions() end)
            f.controls[#f.controls+1]=function() control:SetChecked(get()) end
        end
        local flags={{"enabled","Buffwächter aktivieren"},{"self","Eigene Buffs überprüfen"},{"group","Gruppenbuffs überprüfen"},
            {"autoChat","Chatbericht nach Wildnisbuff"},{"raid","Raidgruppen berücksichtigen"},{"autoRaid","Automatische Raidchatmeldung"},
            {"comments","Paulchen-Kommentare"},{"showWindow","Reiter im Hauptfenster anzeigen"}}
        for index,definition in ipairs(flags) do
            local key=definition[1]
            check(definition[2],18,-61-(index-1)*31,function() return buff.Settings()[key] end,function(value) buff.SetOption(key,value) end)
        end
        label(f,"Bufffamilien",378,-48,310,24,style.gold)
        for index,family in ipairs(buff.families) do
            local key=family.key
            check(family.label .. (family.optional and " (optional)" or ""),378,-79-(index-1)*31,
                function() return buff.Settings().families[key] end,function(value)
                    buff.Settings().families[key]=value;buff.Request(nil,true)
                end)
        end
        button(f,"Anforderungen pro Klasse",378,-281,306,function(self) requirementMenu(self) end)
        label(f,"Automatisch: nur mit passendem Buffgeber.\nIntelligenz/Wille nur für Manaklassen.\nPflicht/Aus und gewünschter Segen sind je Klasse wählbar.",378,-318,306,68,style.muted):SetWordWrap(true)
        label(f,"Chat-Abstand (60–600 Sekunden)",18,-328,320,24,style.gold)
        local cooldown=style.EditBox(f);cooldown:SetSize(90,28);cooldown:SetPoint("TOPLEFT",18,-358);cooldown:SetNumeric(true)
        cooldown:SetMaxLetters(3)
        cooldown:SetScript("OnEnterPressed",function(self) buff.SetOption("cooldown",self:GetText());self:ClearFocus();refreshOptions() end)
        cooldown:SetScript("OnEscapePressed",function(self) self:ClearFocus();refreshOptions() end)
        f.controls[#f.controls+1]=function() if not cooldown:HasFocus() then cooldown:SetText(tostring(buff.Settings().cooldown)) end end
        label(f,"Mit Enter übernehmen. Mindestens 60 Sekunden; identische automatische Berichte werden unterdrückt.",18,-394,666,38,style.muted):SetWordWrap(true)
        label(f,"Nicht lesbare, entfernte, tote oder ausgeloggte Spieler bleiben unbekannt. Schattenschutz und Wille starten ausgeschaltet; fremde Talente werden nicht geraten.",18,-448,666,52,style.muted):SetWordWrap(true)
        f:SetScript("OnShow",refreshOptions)
        UISpecialFrames[#UISpecialFrames+1]=f:GetName()
    end
    options:Show();refreshOptions()
end
function buff.Command(command)
    command=(command or ""):lower()
    if command=="say" then buff.Say(false)
    elseif command=="check" then
        buff.Scan();print("Paulchen QoL · " .. buff.Report())
        buff.SetOption("showWindow",true);app.OpenDashboard("buffs")
    elseif command=="debug" then
        local db=buff.Settings();db.debug=not db.debug
        local data=buff.Scan()
        print("Paulchen Buffwächter · Diagnose " .. (db.debug and "an" or "aus") .. " · " .. data.mode)
        print("Aura-API: " .. tostring(C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex)=="function" or false)
            .. " · Chat-API: " .. tostring(type(C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage)=="function")
            .. " · Chat eingeschränkt: " .. tostring(chatRestricted()) .. " · Versand abgelehnt: " .. tostring(buff.autoBlocked==true))
        for _,member in ipairs(data.members) do
            print(member.name .. " · " .. member.class .. " · fehlt " .. #member.missing .. " · unbekannt " .. #member.unknown .. " · " .. (member.reason or "lesbar"))
        end
    else
        buff.SetOption("showWindow",true);app.OpenDashboard("buffs")
    end
end
