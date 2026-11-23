local _, app = ...
local buttonColor = { 0.20, 0.14, 0.10, 1 }
local activeButtonColor = { 0.31, 0.19, 0.10, 1 }

local style = {
    background = { 0.087, 0.066, 0.054, 0.98 },
    header = { 0.16, 0.096, 0.059 },
    edge = { 0.37, 0.25, 0.16, 1 },
    accent = { 0.71, 0.46, 0.24, 1 },
    cream = { 0.97, 0.90, 0.79 },
    muted = { 0.73, 0.66, 0.58 },
    gold = { 0.98, 0.74, 0.40 },
    green = { 0.66, 0.85, 0.64 },
    orange = { 1, 0.54, 0.40 },
    input = { 0.12, 0.10, 0.08 },
    track = { 0.18, 0.12, 0.08 },
    rowColors = { { 0.105, 0.082, 0.068 }, { 0.132, 0.101, 0.080 } },
}
app.style = style
app.logbookName = app.L("Paulchens Logbuch")
app.logbookLabel = app.L("Logbuch")

function style.Panel(frame, color, edge)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
    frame:SetBackdropBorderColor(unpack(edge or style.edge))
end

function style.Fill(parent, layer, r, g, b, a)
    local art = parent:CreateTexture(nil, layer)
    art:SetAllPoints()
    art:SetColorTexture(r, g, b, a or 1)
    return art
end

function style.Row(frame, index)
    style.Fill(frame, "BACKGROUND", unpack(style.rowColors[index % 2 + 1]))
end

function style.Label(parent, value, x, y, width, height, font, color, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    text:SetPoint("TOPLEFT", x, y)
    text:SetSize(width, height)
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    text:SetTextColor(unpack(color or style.cream))
    text:SetText(app.L(value))
    return text
end

function style.SetButtonState(button, active)
    button:SetBackdropColor(unpack(active and activeButtonColor or buttonColor))
    button:SetBackdropBorderColor(unpack(active and style.accent or style.edge))
end

function style.Button(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    style.Panel(button, buttonColor)
    button:SetHighlightTexture(style.Fill(button, "HIGHLIGHT", 0.90, 0.62, 0.32, 0.20))
    return button
end

function style.TextButton(parent)
    local button = style.Button(parent)
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontNormalSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")
    return button
end

function style.EditBox(parent, font)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    style.Panel(box, style.input)
    box:SetAutoFocus(false)
    box:SetFontObject(font or GameFontHighlightSmall)
    box:SetTextColor(unpack(style.cream))
    box:SetTextInsets(6, 6, 0, 0)
    return box
end

function style.Portrait(parent, size, x, y)
    local art = parent:CreateTexture(nil, "ARTWORK")
    art:SetSize(size, size)
    art:SetPoint("TOPLEFT", x, y)
    art:SetTexture(app.avatar)
    return art
end
