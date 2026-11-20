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
        GTA:Sticker("burst_kapow", "airhorn", 0.9)
    end
end)

---------------------------------------------------------------- contracts
local CLIENTS = { "Big Hoggen", "Cousin Grizzlik", "Lawyer (Goblin)", "Mysterious Hooded Figure", "The Quartermaster", "Your Mom" }
local REASONS = {
    "They know what they did.",
    "They've been looking at me funny.",
    "Business reasons. Don't ask.",
    "One of them owes me 3 silver.",
    "They're bad for property values.",
    "Honestly? Vibes.",
}

local contract
local seen = {}   -- recent victim keywords and counts

local function keyword(name)
    return (name:match("(%a+)$") or name)
end

local cbox = CreateFrame("Frame", nil, UIParent)
cbox:SetSize(300, 70)
cbox:SetPoint("LEFT", UIParent, "LEFT", 20, 120)
cbox:SetFrameStrata("MEDIUM")
cbox:Hide()
local cbg = cbox:CreateTexture(nil, "BACKGROUND")
cbg:SetAllPoints()
cbg:SetTexture(GTA:Tex("panel_dark"))
cbox.title = cbox:CreateFontString(nil, "OVERLAY")
cbox.title:SetFont(GTA.FONT_BLOCK, 15, "")
cbox.title:SetPoint("TOPLEFT", 14, -10)
cbox.title:SetTextColor(1, 0.77, 0.16)
cbox.body = cbox:CreateFontString(nil, "OVERLAY")
cbox.body:SetFont(GTA.FONT_BLOCK, 20, "")
cbox.body:SetPoint("TOPLEFT", cbox.title, "BOTTOMLEFT", 0, -4)
cbox.body:SetTextColor(1, 1, 1)

local function drawContract()
    if not contract then cbox:Hide() return end
    cbox.title:SetText("CONTRACT FOR " .. contract.client:upper())
    local mins = math.max(0, math.ceil((contract.expires - GetTime()) / 60))
    cbox.body:SetText(string.format("Whack %s: %d/%d   |cff999999%dm left|r", contract.target, contract.done, contract.need, mins))
    cbox:Show()
end

local function offer(target, quiet)
    local need = math.random(4, 8)
    contract = {
        target = target, need = need, done = 0,
        client = Pick(CLIENTS),
        reward = need * math.random(8, 14),
        expires = GetTime() + 20 * 60,
    }
    local text = string.format("Got a job. %d %s need to disappear. %s Pays %d respect.", need, target, Pick(REASONS), contract.reward)
    if GTA:On("phone") and not quiet then
        GTA:PhoneText(contract.client, text)
    else
        GTA:Toast("|cffffc428NEW CONTRACT|r\n" .. text, "phone_ring", 6)
    end
    drawContract()
end

local function complete()
    local c = contract
    contract = nil
    drawContract()
    GTA:Stat("contracts")
    GTA:Cutscene("Contract Complete", c.client .. " is pleased. Mostly.", 3.5)
    GTA:Banner({ texture = "mission_passed", sound = "mission_passed", sub = "Contract: " .. c.need .. " " .. c.target .. "   |cffffc428+" .. c.reward .. " RESPECT|r", priority = true })
    GTA:AddRespect(c.reward)
    GTA:Confetti(3)
end

GTA:OnKill(function(name)
    if not GTA:On("contracts") then return end
    local key = keyword(name)
    seen[key] = (seen[key] or 0) + 1
    if contract then
        if name:find(contract.target, 1, true) then
            contract.done = contract.done + 1
            if contract.done >= contract.need then complete() else drawContract() end
        end
        return
    end
    if seen[key] >= 3 and math.random() < 0.35 then
        wipe(seen)
        C_Timer.After(2, function() if not contract then offer(key) end end)
    end
end)

C_Timer.NewTicker(15, function()
    if not contract then return end
    if GetTime() > contract.expires then
        local c = contract
        contract = nil
        drawContract()
        GTA:Banner({ texture = "mission_failed", sound = "mission_failed", sub = c.client .. " found someone else. Ouch." })
    else
        drawContract()
    end
end)

GTA:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() wipe(seen) end)

GTA:Command("contract", "ask for a contract based on what you've been killing", function()
    if contract then return GTA:Print("you already have a contract: " .. contract.target .. " " .. contract.done .. "/" .. contract.need) end
    local best, n = nil, 0
    for k, v in pairs(seen) do if v > n then best, n = k, v end end
    if not best then return GTA:Print("kill a few things first so the boss knows what you're good at.") end
    offer(best, true)
end)
GTA:Command("dropcontract", "abandon your current contract", function()
    if not contract then return end
    contract = nil
    drawContract()
    GTA:Banner({ texture = "mission_failed", sound = "mission_failed", sub = "Quitter." })
end)
