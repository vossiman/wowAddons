local _, GTA = ...
local Pick, Safe = GTA.Pick, GTA.Safe

-- Lying low: the Cozy Sleeping Bag or the /sleep emote.
local DREAMS = {
    "You dream of a world without quest timers. You wake up sweating.",
    "You dream you're a goblin CEO. You fund both sides of a war. You feel nothing.",
    "You dream the guards actually caught you. Then you remember they never do.",
    "You dream of a vendor who pays more than 3 copper. A fantasy, clearly.",
    "You dream the murlocs are unionising. The dream is real. Wake up.",
    "You dream about your mount. It's being driven by someone else. Classic.",
    "You dream of a quiet life. Farming. No killing. You laugh in your sleep.",
    "You dream of Mom's voice: 'Did you eat?' You did not.",
    "You dream your lawyer billed you for this dream. He did.",
    "You dream of a world where loot is shared fairly. The nightmare ends there.",
}

local sleeping            -- { start = t, bag = bool }
local savedCalm, nextDream, xpTicks = 1, 0, 0

local zzz = CreateFrame("Frame", nil, UIParent)
zzz:SetSize(200, 120)
zzz:SetPoint("CENTER", UIParent, "CENTER", 60, 120)
zzz:SetFrameStrata("HIGH")
zzz:Hide()
zzz.text = zzz:CreateFontString(nil, "OVERLAY")
zzz.text:SetFont(GTA.FONT_TITLE, 46, "THICKOUTLINE")
zzz.text:SetPoint("CENTER")
zzz.text:SetTextColor(0.75, 0.85, 1)
zzz.text:SetText("Z z z")

local nap = CreateFrame("Frame", nil, UIParent)
nap:SetSize(300, 60)
nap:SetPoint("TOP", UIParent, "TOP", 0, -200)
nap:SetFrameStrata("HIGH")
nap:Hide()
local napBg = nap:CreateTexture(nil, "BACKGROUND")
napBg:SetAllPoints()
napBg:SetTexture(GTA:Tex("panel_dark"))
nap.title = nap:CreateFontString(nil, "OVERLAY")
nap.title:SetFont(GTA.FONT_BLOCK, 16, "")
nap.title:SetPoint("TOP", 0, -10)
nap.title:SetTextColor(0.75, 0.85, 1)
nap.body = nap:CreateFontString(nil, "OVERLAY")
nap.body:SetFont(GTA.FONT_BLOCK, 13, "")
nap.body:SetPoint("TOP", nap.title, "BOTTOM", 0, -4)
nap.body:SetTextColor(1, 1, 1)
GTA:Movable(nap, "nap", nil, function()
    nap.title:SetText("LYING LOW  0:00")
    nap.body:SetText("Shift-drag me into place")
    GTA.TempShow(nap, 20, function() return sleeping ~= nil end)
end)

local function minsec(t) return string.format("%d:%02d", t / 60, t % 60) end

local function wake()
    if not sleeping then return end
    local dur = GetTime() - sleeping.start
    local bag = sleeping.bag
    sleeping = nil
    GTA.calmFactor = savedCalm
    zzz:Hide()
    nap:Hide()
    GTA:ClearOverlay()
    if dur < 8 then return end
    local sub = "You slept " .. minsec(dur) .. ". "
    if dur >= 120 and GTA:Wanted() > 0 then
        GTA:SetWanted(0)
        sub = sub .. "Slept it off: heat cleared."
    else
        sub = sub .. Pick({ "Your mount was not stolen. Probably.", "Nobody robbed you. Suspicious.", "The world did not wait for you.", "Back to crime." })
    end
    GTA:Banner({ text = "GOOD MORNING, " .. (UnitName("player") or "YOU"):upper(), color = { 0.75, 0.85, 1 }, sub = sub, hold = 2.5 })
    if dur >= 90 and math.random() < 0.5 then
        C_Timer.After(3, function()
            GTA:PhoneText(Pick({ "Cousin Grizzlik", "Mom", "Big Hoggen" }), math.random(2, 7) .. " missed calls while you slept. " .. Pick({ "Bowling?", "Call me back.", "Where's my money?", "Did you eat?" }))
        end)
    end
    if bag then GTA:Stat("naps") end
end

local function fallAsleep(bag)
    if sleeping or not GTA:On("mishaps") then return end
    sleeping = { start = GetTime(), bag = bag }
    savedCalm = GTA.calmFactor or 1
    GTA.calmFactor = savedCalm * 3
    nextDream, xpTicks = GetTime() + 20, 0
    GTA:Overlay("vignette_grey", 0, 0, 0.06, 0.35)
    GTA:Cutscene("Lying Low", bag and "Cozy sleeping bag. The safehouse of champions." or "Right here. On the ground. Like a professional.", 3)
    zzz:Show()
    nap:Show()

    -- Capitals set calmFactor away from 1 (see Turf.lua); inns show in the subzone name.
    local sub = Safe(GetSubZoneText()) or ""
    if sub:find("Inn", 1, true) then
        C_Timer.After(4, function() if sleeping then GTA:Toast("Paid for a room. Slept on the floor anyway. Respect.") end end)
    elseif not bag and savedCalm ~= 1 then
        C_Timer.After(4, function() if sleeping then GTA:AddWanted(1, "Sleeping rough downtown. The cops wrote you a ticket.") end end)
    end
end

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, dt)
    if not sleeping then return end
    acc = acc + dt
    zzz.text:SetPoint("CENTER", 0, math.sin(GetTime() * 1.5) * 12)
    zzz.text:SetAlpha(0.6 + 0.4 * math.sin(GetTime() * 2))
    if acc < 0.5 then return end
    acc = 0
    local ok, speed = pcall(GetUnitSpeed, "player")
    speed = ok and Safe(speed) or 0
    if speed > 0 or IsFalling() or IsMounted() or UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") then
        return wake()
    end
    local now = GetTime()
    local dur = now - sleeping.start
    nap.title:SetText("LYING LOW  " .. minsec(dur))
    nap.body:SetText(GTA:Wanted() > 0 and ("Heat cooling 3x faster (" .. GTA:Wanted() .. " stars)") or "No heat. Just vibes.")
    if now >= nextDream then
        nextDream = now + 25
        GTA:Toast("|cffbfd9ffDREAMING|r\n" .. Pick(DREAMS))
    end
    if sleeping.bag and xpTicks < 3 and dur >= (xpTicks + 1) * 60 then
        xpTicks = xpTicks + 1
        GTA:TextSticker("+" .. xpTicks .. "% XP", "gold", true, 0.45)
    end
end)

if type(DoEmote) == "function" then
    hooksecurefunc("DoEmote", function(token)
        if type(token) == "string" and token:upper() == "SLEEP" then C_Timer.After(0.3, function() fallAsleep(false) end) end
    end)
end

GTA:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" then return end
    local ok, name = pcall(C_Spell and C_Spell.GetSpellName or GetSpellInfo, Safe(spellID))
    name = ok and Safe(name) or nil
    if name and (name:find("Sleeping Bag") or name:find("Cozy")) then C_Timer.After(1, function() fallAsleep(true) end) end
end)
