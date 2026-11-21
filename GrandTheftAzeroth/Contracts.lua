local _, GTA = ...
local Pick, Safe = GTA.Pick, GTA.Safe

---------------------------------------------------------------- kill detection
-- The combat log is gone, but the XP message still names the victim.
local function buildPattern(fmt)
    if not fmt then return nil end
    local p = fmt:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
    p = p:gsub("%%s", "(.-)", 1):gsub("%%d", "%%d+")
    return "^" .. p
end
local XP_PATTERN = buildPattern(COMBATLOG_XPGAIN_FIRSTPERSON or "%s dies, you gain %d experience.")

local killListeners = {}
function GTA:OnKill(fn) table.insert(killListeners, fn) end

local lastKill = 0
local function registerKill(name)
    lastKill = GetTime()
    GTA:Stat("kills")
    for _, fn in ipairs(killListeners) do
        local ok, err = pcall(fn, name)
        if not ok then GTA:Error("kill", err) end
    end
end

GTA:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
    msg = Safe(msg)
    if not msg or not XP_PATTERN then return end
    local name = msg:match(XP_PATTERN)
    if name then registerKill(name) end
end)

-- At max level there is no XP, so fall back to watching the target die.
local targetName, targetAlive
local function atMaxLevel()
    local max = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    return (UnitLevel("player") or 0) >= max
end
local function readTarget()
    if not UnitExists("target") or Safe(UnitIsPlayer("target")) ~= false then
        targetName, targetAlive = nil, nil
        return
    end
    targetName = Safe(UnitName("target"))
    targetAlive = Safe(UnitIsDead("target")) == false
end
GTA:RegisterEvent("PLAYER_TARGET_CHANGED", readTarget)
GTA:RegisterEvent("UNIT_HEALTH", function(unit)
    if unit ~= "target" or not targetAlive or not targetName then return end
    if Safe(UnitIsDead("target")) == true then
        targetAlive = false
        if atMaxLevel() and Safe(UnitIsTapDenied("target")) == false and GetTime() - lastKill > 0.5 then
            registerKill(targetName)
        end
    end
end)

---------------------------------------------------------------- rampage
local recent, rampage = {}, nil
local RAMPAGE_START, RAMPAGE_WINDOW, RAMPAGE_EXTEND = 4, 30, 10

local rbar = CreateFrame("Frame", nil, UIParent)
rbar:SetSize(420, 70)
rbar:SetPoint("TOP", UIParent, "TOP", 0, -60)
rbar:SetFrameStrata("HIGH")
rbar:Hide()
GTA:Movable(rbar, "rampage", nil, function()
    rbar.title:SetText("RAMPAGE! x0")
    GTA.TempShow(rbar, 20, function() return rampage ~= nil end)
end)
rbar.title = rbar:CreateFontString(nil, "OVERLAY")
rbar.title:SetFont(GTA.FONT_TITLE, 40, "THICKOUTLINE")
rbar.title:SetPoint("TOP")
rbar.title:SetTextColor(1, 0.2, 0.2)
local track = rbar:CreateTexture(nil, "BACKGROUND")
track:SetColorTexture(0, 0, 0, 0.7)
track:SetPoint("BOTTOMLEFT", 40, 6)
track:SetPoint("BOTTOMRIGHT", -40, 6)
track:SetHeight(10)
local fill = rbar:CreateTexture(nil, "ARTWORK")
fill:SetColorTexture(1, 0.2, 0.2, 1)
fill:SetPoint("TOPLEFT", track)
fill:SetPoint("BOTTOMLEFT", track)

local function endRampage()
    local r = rampage
    rampage = nil
    rbar:Hide()
    local respect = r.kills * 5
    GTA:Stat("rampages")
    GTA:AddRespect(respect)
    GTA:Banner({ text = "RAMPAGE OVER", color = { 1, 0.3, 0.3 }, sound = "record_scratch", sub = r.kills .. " KILLS   |cffffc428+" .. respect .. " RESPECT|r", hold = 2.5 })
end

rbar:SetScript("OnUpdate", function(_, dt)
    if not rampage then return end
    rampage.left = rampage.left - dt
    fill:SetWidth(math.max(1, track:GetWidth() * math.min(1, rampage.left / RAMPAGE_WINDOW)))
    if rampage.left <= 0 then endRampage() end
end)

GTA:OnKill(function()
    if not GTA:On("contracts") then return end
    local now = GetTime()
    if rampage then
        rampage.kills = rampage.kills + 1
        rampage.left = math.min(RAMPAGE_WINDOW, rampage.left + RAMPAGE_EXTEND)
        rbar.title:SetText("RAMPAGE! x" .. rampage.kills)
        if rampage.kills % 5 == 0 then GTA:Sticker(Pick({ "burst_kapow", "burst_crit" }), "airhorn", 0.7) end
        return
    end
    table.insert(recent, now)
    while recent[1] and now - recent[1] > RAMPAGE_WINDOW do table.remove(recent, 1) end
    if #recent >= RAMPAGE_START then
        rampage = { kills = #recent, left = RAMPAGE_WINDOW }
        wipe(recent)
        rbar.title:SetText("RAMPAGE! x" .. rampage.kills)
        rbar:Show()
        GTA:Sticker("burst_kapow", nil, 0.9)
        GTA:Sound("airhorn", nil, true)
    end
end)

---------------------------------------------------------------- kills per minute drive the wanted level
local killTimes = {}
local KPM_STARS = { { 16, 5 }, { 12, 4 }, { 8, 3 }, { 5, 2 }, { 3, 1 } }

function GTA:KillsPerMinute()
    local now = GetTime()
    while killTimes[1] and now - killTimes[1] > 60 do table.remove(killTimes, 1) end
    return #killTimes
end

GTA:OnKill(function()
    table.insert(killTimes, GetTime())
    local kpm = GTA:KillsPerMinute()
    for _, t in ipairs(KPM_STARS) do
        if kpm >= t[1] then
            if t[2] > GTA:Wanted() then GTA:SetWanted(t[2], "Kill rate: " .. kpm .. " per minute. The neighbours have noticed.") end
            break
        end
    end
end)

local kpmText = GTA.hud:CreateFontString(nil, "OVERLAY")
kpmText:SetFont(GTA.FONT_BLOCK, 13, "OUTLINE")
kpmText:SetPoint("RIGHT", GTA.hud.stars[1], "LEFT", -6, 0)
kpmText:SetTextColor(1, 0.4, 0.4)
C_Timer.NewTicker(1, function()
    local kpm = GTA:KillsPerMinute()
    kpmText:SetText(kpm > 0 and (kpm .. " KILLS/MIN") or "")
    kpmText:SetShown(GTA:On("wanted"))
end)

---------------------------------------------------------------- contracts are your real quests
local cbox = CreateFrame("Frame", nil, UIParent)
cbox:SetSize(320, 96)
cbox:SetPoint("LEFT", UIParent, "LEFT", 20, 120)
cbox:SetFrameStrata("MEDIUM")
cbox:Hide()
local cbg = cbox:CreateTexture(nil, "BACKGROUND")
cbg:SetAllPoints()
cbg:SetTexture(GTA:Tex("panel_dark"))
cbox.title = cbox:CreateFontString(nil, "OVERLAY")
cbox.title:SetFont(GTA.FONT_BLOCK, 14, "")
cbox.title:SetPoint("TOPLEFT", 14, -10)
cbox.title:SetPoint("RIGHT", -14, 0)
cbox.title:SetJustifyH("LEFT")
cbox.title:SetWordWrap(false)
cbox.title:SetTextColor(1, 0.77, 0.16)
cbox.body = cbox:CreateFontString(nil, "OVERLAY")
cbox.body:SetFont(GTA.FONT_BLOCK, 15, "")
cbox.body:SetPoint("TOPLEFT", cbox.title, "BOTTOMLEFT", 0, -4)
cbox.body:SetPoint("RIGHT", -14, 0)
cbox.body:SetJustifyH("LEFT")
cbox.body:SetSpacing(2)
cbox.body:SetTextColor(1, 1, 1)

local jobs = {}        -- questID -> { title, objectives = { {text, type, have, need, done} } }
local progress = {}    -- "questID:index" -> numFulfilled last seen
local pinned           -- questID the player picked with the Contract app
local scanned = false

local function jobKind(job)
    for _, o in ipairs(job.objectives) do if o.type == "monster" then return "HIT CONTRACT" end end
    return "PICKUP JOB"
end

local function scan()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return end
    local fresh = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local ok, rows = pcall(C_QuestLog.GetQuestObjectives, info.questID)
            local objs = {}
            if ok and type(rows) == "table" then
                for _, r in ipairs(rows) do
                    if (r.type == "monster" or r.type == "item") and r.numRequired and r.numRequired > 0 then
                        table.insert(objs, { text = r.text or "?", type = r.type, have = r.numFulfilled or 0, need = r.numRequired, done = r.finished })
                    end
                end
            end
            if #objs > 0 then fresh[info.questID] = { title = info.title or "Job", objectives = objs } end
        end
    end
    return fresh
end

local function currentJob()
    if pinned and jobs[pinned] then return pinned, jobs[pinned] end
    local super = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
    if super and jobs[super] then return super, jobs[super] end
    local best, bestFrac, bestID
    for id, job in pairs(jobs) do
        local have, need = 0, 0
        for _, o in ipairs(job.objectives) do have, need = have + math.min(o.have, o.need), need + o.need end
        local frac = need > 0 and have / need or 0
        if frac < 1 and (not best or frac > bestFrac) then best, bestFrac, bestID = job, frac, id end
    end
    return bestID, best
end

local function draw()
    local id, job = currentJob()
    if not job or not GTA:On("contracts") then cbox:Hide() return end
    cbox.title:SetText(jobKind(job) .. ": " .. job.title:upper())
    local lines = {}
    for i, o in ipairs(job.objectives) do
        if i > 3 then break end
        table.insert(lines, (o.done and "|cff5fe05f" or "") .. o.text .. (o.done and "|r" or ""))
    end
    cbox.body:SetText(table.concat(lines, "\n"))
    cbox:SetHeight(40 + #lines * 18)
    cbox:Show()
end

local function update()
    local fresh = scan()
    if not fresh then return end
    for id, job in pairs(fresh) do
        for i, o in ipairs(job.objectives) do
            local key = id .. ":" .. i
            local before = progress[key]
            if scanned and before and o.have > before and GTA:On("contracts") then
                if o.done or o.have >= o.need then
                    GTA:Banner({ text = o.type == "monster" and "TARGET ELIMINATED" or "PACKAGE SECURED", color = { 0.24, 0.85, 0.35 }, sub = o.text, hold = 1.6 })
                else
                    GTA:TextSticker("+" .. (o.have - before), o.type == "monster" and "red" or "green", true, 0.4)
                end
            end
            progress[key] = o.have
        end
        local old = jobs[id]
        local allDone = true
        for _, o in ipairs(job.objectives) do if not (o.done or o.have >= o.need) then allDone = false end end
        if scanned and old and allDone and GTA:On("contracts") then
            local wasDone = true
            for _, o in ipairs(old.objectives) do if not (o.done or o.have >= o.need) then wasDone = false end end
            if not wasDone then
                GTA:Stat("contracts")
                GTA:Cutscene("Contract Complete", job.title .. ". Go get paid.", 3)
            end
        end
    end
    jobs = fresh
    scanned = true
    if pinned and not jobs[pinned] then pinned = nil end
    draw()
end

local pending
local function queueUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function() pending = false update() end)
end
GTA:RegisterEvent("QUEST_LOG_UPDATE", queueUpdate)
GTA:RegisterEvent("QUEST_WATCH_UPDATE", queueUpdate)
GTA:RegisterEvent("UNIT_QUEST_LOG_CHANGED", function(unit) if unit == "player" then queueUpdate() end end)
GTA:RegisterEvent("SUPER_TRACKING_CHANGED", queueUpdate)
GTA:OnLogin(function() C_Timer.After(3, update) end)

GTA:Movable(cbox, "contract", function()
    if GTA.NextContract then GTA:NextContract() end
end, function()
    if cbox:IsShown() then return end
    cbox.title:SetText("CONTRACT TRACKER")
    cbox.body:SetText("Your kill and loot quests show up here.\nShift-drag me. Click to switch quest.")
    GTA.TempShow(cbox, 20, function() return currentJob() ~= nil end)
end)

function GTA:NextContract()
    local ids = {}
    for id in pairs(jobs) do table.insert(ids, id) end
    table.sort(ids)
    if #ids == 0 then return self:Print("no kill or loot quests in your log right now.") end
    local cur = currentJob()
    local nextID = ids[1]
    for i, id in ipairs(ids) do if id == cur then nextID = ids[i % #ids + 1] end end
    pinned = nextID
    draw()
end

GTA:Command("contract", "switch which quest the contract tracker shows", function() GTA:NextContract() end)
