-- Simulated WoW UI/runtime used by the BuffCheck regression suite.

app, timers, frames = {}, {}, {}
levelSounds, mutedSounds = {}, {}
function PlaySoundFile(path, channel)
    assert(path == "Interface\\AddOns\\PaulchenQoL\\Sounds\\level-up.mp3" and channel == "SFX")
    if soundFails then return false end
    levelSounds[#levelSounds + 1] = path
    return true, #levelSounds
end
function MuteSoundFile(id) assert(id == 569593); mutedSounds[id] = true end
function UnmuteSoundFile(id) assert(id == 569593); mutedSounds[id] = nil end
C_AddOns = { IsAddOnLoaded=function() return true end, GetAddOnMetadata=function() return "1" end }
UISpecialFrames, SlashCmdList = {}, {}
local function updateVisibility(widget, visible)
    if widget.visible == visible then return end
    widget.visible = visible
    local callback = widget.scripts[visible and "OnShow" or "OnHide"]
    if callback then callback(widget) end
    for _, child in ipairs(widget.children) do updateVisibility(child, visible and child.shown) end
end
local methods = {
    SetScript = function(self, event, callback) self.scripts[event] = callback end,
    GetScript = function(self, event) return self.scripts[event] end,
    HookScript = function(self, event, callback)
        local original = self.scripts[event]
        self.scripts[event] = function(...)
            if original then original(...) end
            callback(...)
        end
    end,
    RegisterEvent = function(self, event)
        if event == "UNIT_FLAGS" then error("Unavailable in test client") end
        self.events[event] = true
    end,
    UnregisterEvent = function(self, event) self.events[event] = nil end,
    SetShown = function(self, shown)
        if self.shown == shown then return end
        self.shown = shown
        updateVisibility(self, shown and (not self.parent or self.parent.visible))
    end,
    Show = function(self) self:SetShown(true) end,
    Hide = function(self) self:SetShown(false) end,
    IsShown = function(self) return self.shown end,
    IsVisible = function(self) return self.visible end,
    GetName = function(self) return self.name end,
    SetSize = function(self, w, h) self.width, self.height = w, h end,
    SetWidth = function(self, w) self.width = w end,
    SetHeight = function(self, h) self.height = h end,
    GetWidth = function(self) return self.width or 1024 end,
    GetHeight = function(self) return self.height or 800 end,
    SetScale = function(self, scale) self.scale = scale end,
    GetScale = function(self) return self.scale or 1 end,
    GetCenter = function() return 0, 0 end,
    GetTop = function() return 800 end,
    GetBottom = function() return 0 end,
    GetRight = function() return 1024 end,
    GetStringWidth = function(self) return #self:GetText() * 6 end,
    GetStringHeight = function() return 24 end,
    SetTexture = function(self, path) self.texturePath = path end,
    SetPoint = function(self, ...) self.point = {...} end,
    ClearAllPoints = function(self) self.point = nil end,
    GetFrameLevel = function() return 1 end,
    GetFrameStrata = function() return "HIGH" end,
    SetBackdrop = function(self, backdrop) self.backdrop = backdrop end,
    SetBackdropColor = function(self, ...) self.background = {...} end,
    SetEnabled = function(self, enabled) self.enabled = enabled end,
    IsEnabled = function(self) return rawget(self, "enabled") ~= false end,
    GetEffectiveScale = function() return 1 end,
    SetText = function(self, text)
        self.textValue = text
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end,
    GetText = function(self) return self.textValue or "" end,
    SetOwner = function(self, target) self.owner, self.lines = target, {} end,
    AddLine = function(self, text) self.lines[#self.lines + 1] = text end,
    IsOwned = function(self, target) return self.owner == target end,
    IsForbidden = function() return false end,
    SetChecked = function(self, checked) self.checked = checked end,
    GetChecked = function(self) return self.checked end,
}
function CreateFrame(kind, name, parent)
    local widget = { kind=kind, name=name, parent=parent, shown=true, visible=not parent or parent.visible,
        scripts={}, events={}, children={} }
    if parent then table.insert(parent.children, widget) end
    if name then _G[name] = widget end
    table.insert(frames, widget)
    return setmetatable(widget, { __index=function(_, key)
        if key == "item" or key == "textValue" or key == "parent" or key == "width" or key == "height"
            or key == "page" or key == "scale" then return nil end
        return methods[key] or function() end
    end })
end
methods.CreateTexture = function(self) return CreateFrame("Texture", nil, self) end
methods.CreateFontString = function(self) return CreateFrame("FontString", nil, self) end
UIParent, Minimap, GameTooltip = CreateFrame("Frame"), CreateFrame("Frame"), CreateFrame("Tooltip")
MenuUtil = { CreateContextMenu=function(_, setup)
    choices = {}
    setup(nil, {
        CreateTitle=function() end,
        CreateRadio=function(_, text, _, change) choices[text] = change end,
        CreateButton=function(_, text, action) choices[text] = action end,
    })
end }
C_Timer = { After=function(delay, callback) timers[#timers + 1] = {delay, callback, at=now+delay} end }
function C_Timer.NewTimer(delay, callback)
    local canceled = false
    C_Timer.After(delay, function() if not canceled then callback() end end)
    return {Cancel=function() canceled = true end}
end
function fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
    end
end
function runUpdates()
    local queued = timers
    timers = {}
    for _, timer in ipairs(queued) do
        if timer[1] < 1 then timer[2]() else timers[#timers + 1] = timer end
    end
end
now = 102
function GetTime() return now end
function advance(seconds)
    local finish = now + seconds
    while true do
        local best
        for n, timer in ipairs(timers) do
            if timer.at <= finish and (not best or timer.at < timers[best].at) then best = n end
        end
        if not best then break end
        local timer = table.remove(timers, best)
        now = math.max(now, timer.at)
        timer[2]()
    end
    now = finish
end
zone, level, dead, afk = "Teufelswald", 52, false, false
function GetRealZoneText() return zone end
function UnitLevel() return level end
function UnitIsDeadOrGhost() return dead end
function UnitIsAFK() return afk end
function GetUnitSpeed() return 0 end
function GetServerTime() return 100000 + math.floor(now) end
airborne = false
function UnitOnTaxi(unit) return unit == "player" and airborne end
function TakeTaxiNode() end
function hooksecurefunc(object, name, fn)
    if type(object) == "string" then object, name, fn = _G, object, name end
    local original = object[name]
    object[name] = function(...)
        local results = {original(...)}
        fn(...)
        return unpack(results)
    end
end
combat = false
function InCombatLockdown() return combat end
function GetCursorPosition() return 6, 6 end
function GetBindLocation() return "Orgrimmar" end
local current, maximum = { 50, 25 }, { 100, 100 }
function GetInventoryItemDurability(slot) return current[slot], maximum[slot] end
local function item(id, link, count, noValue)
    return { itemID=id, hyperlink=link, stackCount=count, quality=2, iconFileID=134400, hasNoValue=noValue, isLocked=false }
end
stackLink = "|cff1eff00|Hitem:100::::::::::|h[Ätherkraut]|h|r"
local bear = "|cff1eff00|Hitem:200::::::1196::::|h[Mantel des Bären]|h|r"
local cat = "|cff1eff00|Hitem:200::::::1197::::|h[Mantel der Katze]|h|r"
local quest = "|cffffffff|Hitem:300::::::::::|h[Auftragsgegenstand]|h|r"
local bags = { [0]={item(100, stackLink, 2, false), item(200, bear, 1, false), item(200, cat, 1, false)},
    [1]={item(100, stackLink, 3, false), item(300, quest, 1, true)} }
local free = { [0]=2, [1]=1, [2]=8 }
local slots = { [0]=5, [1]=3, [2]=8 }
C_Container = {
    GetContainerNumFreeSlots=function(bag) return free[bag] or 0, bag == 2 and 32 or nil end,
    GetContainerNumSlots=function(bag) return slots[bag] or 0 end,
    GetContainerItemInfo=function(bag, slot) return bags[bag] and bags[bag][slot] end,
    GetContainerItemQuestInfo=function(bag, slot)
        if bag == 1 and slot == 2 then return {isQuestItem=true} end
    end,
}
local duration = 1800
C_Item = {
    GetItemCount=function(id, includeBank)
        assert(not includeBank)
        if id == 6948 then return 1 end
        return evergreenItems and evergreenItems[id] or 0
    end,
    GetItemCooldown=function(id)
        if id == 11020 then return pouchStart or 0, pouchDuration or 0, true end
        assert(id == 6948)
        return 100, duration, true
    end,
    GetItemInfo=function(link)
        local id = tonumber(link:match("item:(%d+)"))
        local price = id == 100 and 125 or 250
        return "Item " .. id, link, 2, 50, 45, "Trade goods", "Other", 20, nil, 134400, price
    end,
}
function startShortCooldown() duration = 1.5 end
function fillBags() free[0], free[1], current[2] = 0, 0, 100 end
function clearBags() free[0], free[1], current[2] = 5, 3, 100 end
