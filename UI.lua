local _, app = ...

local bird, dashboardOpen, status, detail
local statusUntil, statusTimer
local reminders = {}
local moving, currentArt = false, nil

local function place()
    if not bird then return end
    local settings = app.Profile()
    bird:ClearAllPoints()
    if type(settings.x) == "number" and type(settings.y) == "number" then
        bird:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
    else
        bird:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -45, 178)
    end
end

function app.ResetCompanionPosition()
    local settings = app.Profile()
    settings.x, settings.y = nil, nil
    place()
    app.RenderCompanion()
end

local function stopMoving(self)
    if not moving then return end
    moving = false
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    local x, y = self:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if not (x and y and cx and cy) then return end
    local settings = app.Profile()
    settings.x, settings.y = x - cx, y - cy
    place()
end

local texture = "Interface\\Buttons\\WHITE8X8"

local function makeBubble(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({ bgFile = texture, edgeFile = texture, edgeSize = 1 })
    f:SetBackdropColor(0.102, 0.070, 0.057, 0.97)
    f:SetBackdropBorderColor(0.59, 0.37, 0.23, 1)
    local trim = f:CreateTexture(nil, "ARTWORK")
    trim:SetColorTexture(0.62, 0.15, 0.082, 1)
    trim:SetHeight(2)
    trim:SetPoint("TOPLEFT", 1, -1)
    trim:SetPoint("TOPRIGHT", -1, -1)
    local tail = f:CreateTexture(nil, "BACKGROUND")
    tail:SetSize(10, 10)
    tail:SetColorTexture(0.32, 0.18, 0.12, 1)
    tail:SetRotation(math.pi / 4)
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 12, -10)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text:SetTextColor(0.97, 0.90, 0.79)
    f.text, f.tail = text, tail
    f:Hide()
    return f
end

local function layoutBubble(text)
    local bubble = bird.bubble
    local body = bubble.text
    body:SetText(text)
    local maximum = math.max(130, math.min(290, UIParent:GetWidth() - app.Profile().size - 20))
    local unwrapped = body.GetUnboundedStringWidth and body:GetUnboundedStringWidth() or body:GetStringWidth()
    local width = math.max(105, math.min(maximum, math.ceil(unwrapped or maximum) + 24))
    body:SetWidth(width - 24)
    local height = math.max(36, math.ceil(body:GetStringHeight() or 16) + 20)
    bubble:SetSize(width, height)
    local middle, y = bird:GetCenter()
    local left = middle and (UIParent:GetRight() or UIParent:GetWidth()) - middle - bird:GetWidth() / 2 < width + 10
    local edge, opposite = left and "RIGHT" or "LEFT", left and "LEFT" or "RIGHT"
    local top, bottom = UIParent:GetTop(), UIParent:GetBottom()
    local offset = y and top and bottom and math.max(bottom + height / 2 + 5 - y, math.min(0, top - height / 2 - 5 - y)) or 0
    bubble:ClearAllPoints()
    bubble:SetPoint(edge, bird, opposite, left and -7 or 7, offset)
    bubble.tail:ClearAllPoints()
    bubble.tail:SetPoint(edge, left and 4 or -4, -offset)
    bubble:Show()
end

local function companionStatus()
    if not status then return end
    local now = GetTime()
    if not statusUntil then
        statusUntil = now + app.bubbleDuration
        statusTimer = C_Timer.NewTimer(app.bubbleDuration, function()
            statusTimer = nil
            app.RenderCompanion()
        end)
    end
    if now < statusUntil then return detail and (status .. "\n|cfffabc66" .. detail .. "|r") or status end
end

function app.WithCompanionReminders(text)
    local settings = app.Profile()
    if not settings.comments or not settings.show then return text end
    local reminder = reminders.pouch
    if reminders.mark then
        reminder = reminder and (reminder .. "\n" .. reminders.mark) or reminders.mark
    end
    if not reminder then return text end
    return text and (reminder .. "\n" .. text) or reminder
end

function app.SetCompanionReminder(key, text)
    if reminders[key] == text then return end
    reminders[key] = text
    if text then app.DelayCompanionAmbient(60) end
    app.RenderCompanion()
end

function app.CompanionReminders()
    return reminders.mark, reminders.pouch
end

function app.RenderCompanion()
    if bird then
        local settings = app.Profile()
        local art, comment = app.DialogueView()
        local inCombat = InCombatLockdown and app.ReadGameValue(InCombatLockdown) ~= false
        local shown = settings.show and not dashboardOpen and not (inCombat and settings.hideCombat)
        bird:SetShown(shown)
        if shown then
            if art ~= currentArt then
                currentArt = art
                bird.avatar:SetTexture(app.artPath .. art .. ".tga")
            end
            local text = settings.bubbles and not inCombat and app.WithCompanionReminders(comment or companionStatus())
            if text then layoutBubble(text) else bird.bubble:Hide() end
        end
    end
    if app.RefreshDashboardDialogue then app.RefreshDashboardDialogue() end
end

function app.SetCompanionStatus(text, secondLine)
    if status == text and detail == secondLine then return end
    if status ~= text then
        if statusTimer then statusTimer:Cancel(); statusTimer = nil end
        statusUntil = nil
        if text then app.DelayCompanionAmbient(20) end
    end
    status, detail = text, secondLine
    app.RenderCompanion()
end

function app.SetDashboardOpen(open)
    dashboardOpen = open
    app.RenderCompanion()
end

function app.ApplyProfile()
    if bird then
        local settings = app.Profile()
        bird:SetSize(settings.size, settings.size)
        bird:SetAlpha(settings.opacity)
    end
    app.RenderCompanion()
    if app.RefreshDashboardSettings then app.RefreshDashboardSettings() end
end

function app.BootCompanion()
    if bird then return end
    local frame = CreateFrame("Button", "PaulchenQoLCompanion", UIParent)
    bird = frame
    bird:Hide()
    bird:SetFrameStrata("MEDIUM")
    bird:SetMovable(true)
    bird:SetClampedToScreen(true)
    bird:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bird:RegisterForDrag("LeftButton")
    bird.avatar = bird:CreateTexture(nil, "ARTWORK")
    bird.avatar:SetAllPoints()
    bird.bubble = makeBubble(bird)
    bird:SetScript("OnDragStart", function(self)
        moving = true
        self:StartMoving()
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    bird:SetScript("OnDragStop", function(self)
        stopMoving(self)
        app.RenderCompanion()
    end)
    bird:SetScript("OnHide", function(self)
        stopMoving(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    bird:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Paulchen")
        GameTooltip:AddLine(app.L("Linksklick · Paulchen öffnen"))
        GameTooltip:AddLine(app.L("Rechtsklick · Einstellungen"))
        GameTooltip:Show()
    end)
    bird:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    bird:SetScript("OnClick", function(_, button)
        if button == "RightButton" then app.OpenConfig()
        elseif app.ToggleDashboard then app.ToggleDashboard() end
    end)
    place()
    app.ApplyProfile()
end
