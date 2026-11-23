local _, app = ...
local comfort = app.comfort
local read, readable = app.ReadGameValue, app.Readable
local questClass = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
local frequency = Enum and Enum.QuestFrequency
local acceptOptions = {
    [frequency and frequency.Default or 0] = "questRegular",
    [frequency and frequency.Daily or 1] = "questDaily",
    [frequency and frequency.Weekly or 2] = "questWeekly",
}
local pending, questID, acted, selected = nil, nil, {}, {}

local function positiveID(value)
    return type(value) == "number" and value > 0
end

local function mayAcceptAny()
    return comfort.Enabled("questRegular") or comfort.Enabled("questDaily") or comfort.Enabled("questWeekly")
end

local function acceptsFrequency(value)
    if issecretvalue and issecretvalue(value) then return false end
    local option = acceptOptions[value == nil and 0 or value]
    return option ~= nil and comfort.Enabled(option)
end

local function action(label, api, ...)
    if type(api) == "function" then app.SecureCall(app.L(label), api, ...) end
end

local function acceptDetail()
    local daily, dailyKnown = comfort.Read(QuestIsDaily)
    local weekly, weeklyKnown = comfort.Read(QuestIsWeekly)
    if not dailyKnown or not weeklyKnown then return end
    local option = weekly and "questWeekly" or daily and "questDaily" or "questRegular"
    if not comfort.Enabled(option) then return end
    local auto, autoKnown = comfort.Read(QuestGetAutoAccept)
    if not autoKnown or auto then return end
    if acted.accept then return end
    acted.accept = true
    action("Quest-Automatik", AcceptQuest)
end

local function freeTurnIn()
    if read(GetQuestMoneyToGet) ~= 0 or read(GetNumQuestCurrencies) ~= 0 then return false end
    local items = read(GetNumQuestItems)
    if type(items) ~= "number" or items < 0 then return false end
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local marks = app.Settings().marks
    for index = 1, items do
        local link = read(GetQuestItemLink, "required", index)
        if type(link) ~= "string" or type(instant) ~= "function" then return false end
        local ok, id, _, _, _, _, class = pcall(instant, link)
        id = readable(id)
        if not ok or not positiveID(id) or readable(class) ~= questClass
            or marks[app.BagItemKey(id, link)] ~= nil then return false end
    end
    return true
end

local function advanceTurnIn(isReward)
    if not comfort.Enabled("questTurnIn") then return end
    if not freeTurnIn() then
        -- Preserve the decision if the player manually opens the reward page,
        -- where the client's list of requirements can already be empty.
        acted.manualTurnIn = true
        return
    end
    if acted.manualTurnIn then return end
    if isReward then
        local choices = read(GetNumQuestChoices)
        if acted.reward or (choices ~= 0 and choices ~= 1) then return end
        acted.reward = true
        action("Quest-Automatik", GetQuestReward, choices)
    elseif not acted.progress and read(IsQuestCompletable) == true then
        acted.progress = true
        action("Quest-Automatik", CompleteQuest)
    end
end

local function selectOnce(key, api, id)
    if selected[key] or type(api) ~= "function" then return false end
    selected[key] = true
    action("Quest-Automatik", api, id)
    return true
end

local function selectGossip()
    local gossip = C_GossipInfo
    if not gossip or not comfort.Visible(GossipFrame) then return end
    local available, active, options = read(gossip.GetAvailableQuests), read(gossip.GetActiveQuests), read(gossip.GetOptions)
    if type(active) ~= "table" or type(available) ~= "table" or type(options) ~= "table" then return end
    if comfort.Enabled("questTurnIn") then
        for _, row in ipairs(active) do
            local quest = readable(row)
            local id = quest and readable(quest.questID)
            if positiveID(id) and readable(quest.isComplete) == true
                and selectOnce("turn:" .. id, gossip.SelectActiveQuest, id) then return end
        end
    end
    if mayAcceptAny() then
        for _, row in ipairs(available) do
            local quest = readable(row)
            local id = quest and readable(quest.questID)
            if positiveID(id) and readable(quest.isIgnored) ~= true and acceptsFrequency(quest.frequency)
                and selectOnce("accept:" .. id, gossip.SelectAvailableQuest, id) then return end
        end
    end
    if #active ~= 0 or #available ~= 0 or #options ~= 1
        or not comfort.Enabled("gossipAlt") or read(IsAltKeyDown) ~= true then return end
    local option = readable(options[1])
    local id = option and readable(option.gossipOptionID)
    local availableStatus = Enum and Enum.GossipOptionStatus and Enum.GossipOptionStatus.Available or 0
    if positiveID(id) and readable(option.status) == availableStatus then
        -- Let the game's own confirmation handle paid or special interactions.
        selectOnce("gossip:" .. id, gossip.SelectOption, id)
    end
end

local function selectGreeting()
    if not comfort.Visible(QuestFrame) or not comfort.Visible(QuestFrameGreetingPanel) then return end
    local active, available = read(GetNumActiveQuests), read(GetNumAvailableQuests)
    if type(active) ~= "number" or type(available) ~= "number" then return end
    if comfort.Enabled("questTurnIn") then
        for index = 1, active do
            local title, complete = read(GetActiveTitle, index)
            if type(title) == "string" and complete == true
                and selectOnce("greeting:turn:" .. title, SelectActiveQuest, index) then return end
        end
    end
    if mayAcceptAny() and type(GetAvailableQuestInfo) == "function" then
        for index = 1, available do
            local ok, _, value, _, _, id = pcall(GetAvailableQuestInfo, index)
            id = readable(id)
            if ok and positiveID(id) and acceptsFrequency(value)
                and selectOnce("greeting:accept:" .. id, SelectAvailableQuest, index) then return end
        end
    end
end

local function handle(dialog)
    local event, id = dialog.event, dialog.id
    if not dialog.allowed or not comfort.CanInteract() or comfort.HasDialog() then return end
    if read(UnitExists, "questnpc") ~= true and read(UnitExists, "npc") ~= true then return end
    if event == "GOSSIP_SHOW" then return selectGossip() end
    if event == "QUEST_GREETING" then return selectGreeting() end
    if not positiveID(id) or id ~= read(GetQuestID) or not comfort.Visible(QuestFrame) then return end
    if event == "QUEST_DETAIL" and comfort.Visible(QuestFrameDetailPanel) then
        acceptDetail()
    elseif event == "QUEST_PROGRESS" and comfort.Visible(QuestFrameProgressPanel) then
        advanceTurnIn(false)
    elseif event == "QUEST_COMPLETE" and comfort.Visible(QuestFrameRewardPanel) then
        advanceTurnIn(true)
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL",
    "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_TURNED_IN", "PLAYER_ENTERING_WORLD" }) do
    app.RegisterSupported(events, event)
end
events:SetScript("OnEvent", function(_, event, continuing)
    if event == "GOSSIP_CLOSED" then
        if readable(continuing) ~= true then selected = {} end
        if pending and pending.event == "GOSSIP_SHOW" then pending = nil end
    elseif event == "QUEST_FINISHED" or event == "QUEST_TURNED_IN" or event == "PLAYER_ENTERING_WORLD" then
        pending, questID, acted = nil, nil, {}
        if event == "PLAYER_ENTERING_WORLD" then
            selected = {}
        elseif event == "QUEST_FINISHED" then
            for key in pairs(selected) do
                if key:sub(1, 9) == "greeting:" then selected[key] = nil end
            end
        end
    elseif C_Timer and C_Timer.After and (mayAcceptAny() or comfort.Enabled("questTurnIn") or comfort.Enabled("gossipAlt")) then
        local menu = event == "GOSSIP_SHOW" or event == "QUEST_GREETING"
        local id = not menu and read(GetQuestID) or nil
        local allowed = comfort.CanInteract()
        if positiveID(id) and id ~= questID then questID, acted = id, {} end
        if event == "QUEST_PROGRESS" and positiveID(id) and (not allowed or not freeTurnIn()) then
            -- A manually opened reward page may no longer expose the original requirements.
            acted.manualTurnIn = true
        end
        local dialog = { event = event, id = id, allowed = allowed }
        pending = dialog
        C_Timer.After(0, function()
            if pending ~= dialog then return end
            pending = nil
            app.SecureCall(app.L("Quest-Automatik"), handle, dialog)
        end)
    end
end)
