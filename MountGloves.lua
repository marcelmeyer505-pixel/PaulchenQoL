local _, app = ...

local ridingGloves = 287010 -- Handschuhe der Vorhut
local hands = INVSLOT_HAND or 10
local readable = app.Readable
local initialized, queued, mountedBefore
local pending, skipRide, restoreFailed, missingReported
local automaticLink

local function wornGloves()
    local id = GetInventoryItemID("player", hands)
    if issecretvalue and issecretvalue(id) then return nil, false end
    return id, true
end

local function mounted()
    return IsMounted and readable(IsMounted())
end

local function canChangeGear()
    return initialized and C_Item and C_Item.EquipItemByName and GetInventoryItemID and GetInventoryItemLink
        and not (InCombatLockdown and InCombatLockdown())
        and not (UnitOnTaxi and readable(UnitOnTaxi("player")))
        and not (UnitInVehicle and readable(UnitInVehicle("player")))
        and not (GetCursorInfo and readable(GetCursorInfo()))
end

local function wornGUID()
    if ItemLocation and ItemLocation.CreateFromEquipmentSlot and C_Item.GetItemGUID then
        return readable(C_Item.GetItemGUID(ItemLocation:CreateFromEquipmentSlot(hands)))
    end
end

local function restoreLink(saved)
    if saved.guid and C_Item.GetItemLocation and C_Item.GetItemLink then
        local location = readable(C_Item.GetItemLocation(saved.guid))
        if location then
            if not location:IsBagAndSlot() then return end
            local link = readable(C_Item.GetItemLink(location))
            return link and app.BagItemCount(link) > 0 and link or nil
        end
    end
    return app.BagItemCount(saved.link) > 0 and saved.link or nil
end

local function tell(text)
    print("Paulchen QoL · " .. text)
end

function app.UpgradeGloveLink()
    if not (GetInventoryItemID and GetInventoryItemLink) then return end
    local saved = app.Settings().mountGloveReturn
    if type(saved) ~= "table" or type(saved.link) ~= "string" then return end
    local id, known = wornGloves()
    if known and (id == ridingGloves or pending and not id) then return saved.link end
end

function app.IsRidingGloveItem(id)
    return readable(id) == ridingGloves
end

function app.IsAutomaticMountGloveChange(slot)
    if readable(slot) ~= hands or not (GetInventoryItemID and GetInventoryItemLink) then return false end
    local id, known = wornGloves()
    if not known then return false end
    local link = readable(GetInventoryItemLink("player", hands))
    if pending and (not id or pending.riding and id == ridingGloves or not pending.riding and link == pending.item) then
        if link then automaticLink = link end
        return true
    end
    -- Duplicate notifications may arrive after the asynchronous request is
    -- confirmed. A different link immediately restores normal gear handling.
    if automaticLink and link == automaticLink then return true end
    automaticLink = nil
    return false
end

local function equip(item, riding)
    local request = { item = item, riding = riding, before = readable(GetInventoryItemLink("player", hands)) }
    pending = request
    app.SecureCall("Reithandschuhe anlegen", C_Item.EquipItemByName, item, hands)
    C_Timer.After(1.5, function()
        if pending ~= request then return end
        pending = nil
        local id, known = wornGloves()
        if known and not id and request.before then
            local gear = app.upgrades and app.upgrades.gear
            if gear and gear.Invalidate then gear.Invalidate("equipment") end
        end
        if riding then
            if mounted() and canChangeGear() and wornGloves() ~= ridingGloves then
                tell("Die Handschuhe der Vorhut konnten nicht angelegt werden.")
            end
        elseif canChangeGear() and wornGloves() == ridingGloves then
            restoreFailed = true
            tell("Deine bisherigen Handschuhe konnten nicht angelegt werden. Lege " .. item .. " aus der Tasche an.")
        end
        app.RefreshMountGloves()
    end)
end

local function update()
    if not canChangeGear() then return end
    local onMount = mounted()
    if type(onMount) ~= "boolean" then return end
    if onMount ~= mountedBefore then
        mountedBefore = onMount
        skipRide, restoreFailed, missingReported = false, false, false
    end

    local worn, known = wornGloves()
    if not known then return end
    local restored
    if pending then
        local ridingIsWorn = worn == ridingGloves
        if pending.riding ~= ridingIsWorn then return end
        restored = not pending.riding and readable(GetInventoryItemLink("player", hands)) == pending.item
        pending = nil
    end

    local settings = app.Settings()
    local saved = settings.mountGloveReturn
    if type(saved) ~= "table" or type(saved.link) ~= "string" then saved = nil end
    local enabled = app.Profile().mountGloves
    if saved then
        if worn ~= ridingGloves then
            -- Leave any later manual change equipped.
            settings.mountGloveReturn = nil
            if not restored then
                if onMount then skipRide = true end
                return
            end
        else
            if not (onMount and enabled) and not restoreFailed then
                local original = restoreLink(saved)
                if original then
                    equip(original, false)
                elseif not missingReported then
                    missingReported = true
                    tell("Die bisherigen Handschuhe fehlen in deinen Taschen.")
                end
            end
            return
        end
    end

    if not (onMount and enabled and not skipRide and worn and worn ~= ridingGloves) then return end
    if app.BagItemCount(ridingGloves) < 1 then return end
    local link = readable(GetInventoryItemLink("player", hands))
    if type(link) == "string" then
        skipRide = true
        settings.mountGloveReturn = { link = link, guid = wornGUID() }
        equip(ridingGloves, true)
    end
end

function app.RefreshMountGloves()
    if queued or not initialized then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        app.SecureCall("Reithandschuhe", update)
    end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_REGEN_ENABLED",
    "PLAYER_EQUIPMENT_CHANGED", "PLAYER_CONTROL_GAINED", "BAG_UPDATE_DELAYED", "CURSOR_UPDATE" }) do
    app.RegisterSupported(events, event)
end
events:SetScript("OnEvent", function(_, event, slot)
    if event == "PLAYER_ENTERING_WORLD" then initialized, restoreFailed = true, false end
    if event == "PLAYER_REGEN_ENABLED" then restoreFailed = false end
    if event ~= "PLAYER_EQUIPMENT_CHANGED" or readable(slot) == hands then app.RefreshMountGloves() end
end)
