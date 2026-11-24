local _, suite = ...
local app = suite.upgrades
local data = app and app.setBonusData
if not data then return end
local sets, byItem, requiredSkills = {}, {}, {}
app.setBonuses = sets

for setID, definition in pairs(data) do
    for _, id in ipairs(definition.items) do byItem[id] = setID end
    if definition.skill then requiredSkills[definition.skill] = true end
end

function sets.ItemSet(id, clientSet)
    return type(clientSet) == "number" and clientSet > 0 and clientSet or byItem[id]
end

function sets.SkillKey(rankFor)
    local fields = {}
    for id in pairs(requiredSkills) do
        fields[#fields + 1] = id .. ":" .. tostring(rankFor(id) or "?")
    end
    table.sort(fields)
    return table.concat(fields, ",")
end

function sets.Equipped(slots, rankFor)
    local pieces, ranks = {}, {}
    for _, entry in pairs(slots) do
        local info = entry.info
        if info.setID then
            local group = pieces[info.setID]
            if not group then
                group = { count = 0, items = {} }
                pieces[info.setID] = group
            end
            local count = group.items[info.id] or 0
            if count == 0 then group.count = group.count + 1 end
            group.items[info.id] = count + 1
        end
    end
    for id in pairs(requiredSkills) do ranks[id] = rankFor(id) end
    return { pieces = pieces, ranks = ranks }
end

local function track(changes, info, amount)
    if not info or not info.setID then return end
    local group = changes[info.setID]
    if not group then group = {}; changes[info.setID] = group end
    group[info.id] = (group[info.id] or 0) + amount
end

function sets.Compare(equipped, weights, candidate, removed, otherRemoved, partner)
    if not (candidate.setID or removed and removed.setID or otherRemoved and otherRemoved.setID
        or partner and partner.setID) then return 0, 0 end
    local changes = {}
    track(changes, removed, -1)
    track(changes, otherRemoved, -1)
    track(changes, candidate, 1)
    track(changes, partner, 1)
    local oldPoints, newPoints, effects, unknownLoss = 0, 0, nil, false
    local function record(setID, threshold, gaining, points, unknown)
        effects = effects or {}
        effects[#effects + 1] = { setID = setID, threshold = threshold, gaining = gaining,
            points = points, unknown = unknown or nil }
        if gaining then newPoints = newPoints + points
        else oldPoints = oldPoints + points; unknownLoss = unknownLoss or unknown end
    end
    for setID, itemChanges in pairs(changes) do
        local group = equipped.pieces[setID]
        local before = group and group.count or 0
        local after = before
        for id, amount in pairs(itemChanges) do
            local worn = group and group.items[id] or 0
            if worn == 0 and amount > 0 then after = after + 1
            elseif worn > 0 and worn + amount <= 0 then after = after - 1 end
        end
        if before ~= after then
            local definition = data[setID]
            local rank = definition and definition.skill and equipped.ranks[definition.skill]
            if not definition or not next(definition.bonuses) then
                record(setID, 0, after > before, 0, true)
            elseif not definition.skill or not rank or rank >= definition.rank then
                for threshold, bonus in pairs(definition.bonuses) do
                    if (before >= threshold) ~= (after >= threshold) then
                        local points = 0
                        local hasSkill = not definition.skill or rank ~= nil
                        if hasSkill and bonus.stats then
                            for stat, value in pairs(bonus.stats) do points = points + value * (weights[stat] or 0) end
                        end
                        record(setID, threshold, after >= threshold, points, bonus.unknown or not hasSkill)
                    end
                end
            end
        end
    end
    if effects then
        table.sort(effects, function(a, b)
            if a.setID == b.setID then return a.threshold < b.threshold end
            return a.setID < b.setID
        end)
    end
    return oldPoints, newPoints, effects, unknownLoss
end

function sets.AddTooltipLines(tooltip, result)
    for _, effect in ipairs(result.setEffects or {}) do
        local name = suite.ReadGameValue(C_Item and C_Item.GetItemSetInfo, effect.setID) or suite.LF("Set %d", effect.setID)
        if effect.threshold > 0 then name = name .. " (" .. effect.threshold .. ")" end
        local label = suite.LF(effect.gaining and "Setbonus dazu · %s" or "Setbonus entfällt · %s", name)
        local points = effect.gaining and effect.points or -effect.points
        local value = points ~= 0 and suite.LocalizeDecimal(suite.LF("%+.2f Punkte", points)) or ""
        if effect.unknown then
            value = value ~= "" and value .. " · " .. suite.L("Effekt offen") or suite.L("Effekt offen")
        end
        tooltip:AddDoubleLine(label, value, 0.95, 0.76, 0.43, 0.95, 0.76, 0.43)
    end
end
