local _, suite = ...
local addon = suite.timeline
if not addon then return end

local function literal(text)
    return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function compile(template, anchored)
    if type(template) ~= "string" then return end
    local parts, order, cursor = {}, {}, 1
    while true do
        local left, right, position, kind = template:find("%%(%d*)%$?([sd])", cursor)
        if not left then break end
        parts[#parts + 1] = literal(template:sub(cursor, left - 1))
        parts[#parts + 1] = kind == "d" and "(%d+)" or "(.+)"
        order[#order + 1] = tonumber(position) or #order + 1
        cursor = right + 1
    end
    if #order == 0 then return end
    parts[#parts + 1] = literal(template:sub(cursor))
    local pattern = table.concat(parts)
    return { pattern = anchored and ("^" .. pattern .. "$") or pattern, order = order }
end

local function match(message, format)
    local result = {}
    for index, value in ipairs({ message:match(format.pattern) }) do
        result[format.order[index]] = value
    end
    return result[1], result[2]
end

local function patterns(names)
    local result = {}
    for _, name in ipairs(names) do
        local format = compile(_G[name], true)
        if format then result[#result + 1] = format end
    end
    return result
end

local function moneyAmount(message, formats, coins)
    for _, format in ipairs(formats) do
        local money = match(message, format)
        if money then
            local copper = 0
            for _, coin in ipairs(coins) do
                local amount = coin[2] and tonumber(match(money, coin[2]))
                amount = amount or tonumber(money:match("(%d+)%s*|T[^|]*UI%-" .. coin[3] .. "Icon[^|]*|t"))
                copper = copper + (amount or 0) * coin[1]
            end
            return copper
        end
    end
end

function addon.ListenFarmLoot(activeRound, refresh)
    local moneyFormats = patterns({ "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT", "YOU_LOOT_MONEY_GUILD", "LOOT_MONEY_SPLIT_GUILD" })
    local itemFormats = patterns({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF" })
    local coins = {
        { 10000, compile(GOLD_AMOUNT), "Gold" },
        { 100, compile(SILVER_AMOUNT), "Silver" },
        { 1, compile(COPPER_AMOUNT), "Copper" },
    }
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_MONEY")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:SetScript("OnEvent", function(_, event, message)
        local run = activeRound()
        if not run or issecretvalue(message) or type(message) ~= "string" then return end
        if event == "CHAT_MSG_MONEY" then
            local amount = moneyAmount(message, moneyFormats, coins)
            if amount and amount > 0 then
                run.copper = (run.copper or 0) + amount
                refresh()
            end
        elseif run.item then
            for _, format in ipairs(itemFormats) do
                local link, quantity = match(message, format)
                local id, name
                if link then id, name = link:match("|Hitem:(%d+)[^|]*|h%[(.-)%]|h") end
                if id then
                    local targetID = run.item:match("^%d+$") or run.item:match("|Hitem:(%d+)")
                    if (targetID and tonumber(targetID) == tonumber(id)) or (not targetID and name:lower() == run.item:lower()) then
                        run.itemLabel = name
                        run.itemCount = (run.itemCount or 0) + (tonumber(quantity) or 1)
                        refresh()
                    end
                    return
                end
            end
        end
    end)
end
