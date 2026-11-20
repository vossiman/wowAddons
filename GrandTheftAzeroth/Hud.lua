local _, GTA = ...

local hud = CreateFrame("Frame", "GrandTheftAzerothHud", UIParent)
GTA.hud = hud
hud:SetSize(260, 90)
hud:SetFrameStrata("MEDIUM")
hud:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -230)
GTA:Movable(hud, "hud", function() if GTA.TogglePhone then GTA:TogglePhone() end end)
hud:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Grand Theft Azeroth")
    GameTooltip:AddLine("Click: open phone. Shift-drag: move.", 1, 1, 1)
    GameTooltip:Show()
end)
hud:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Wanted stars, right-aligned.
hud.stars = {}
for i = 1, 5 do
    local s = hud:CreateTexture(nil, "ARTWORK")
    s:SetSize(34, 34)
    s:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -(5 - i) * 36, 0)
    s.pulse = s:CreateAnimationGroup()
    local grow = s.pulse:CreateAnimation("Scale")
    grow:SetScaleFrom(2.2, 2.2)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(0.35)
    grow:SetSmoothing("OUT")
    hud.stars[i] = s
end

-- Cash.
hud.cash = hud:CreateFontString(nil, "OVERLAY")
hud.cash:SetFont(GTA.FONT_BLOCK, 30, "OUTLINE")
hud.cash:SetPoint("TOPRIGHT", hud, "TOPRIGHT", 0, -40)
hud.cash:SetTextColor(0.45, 0.85, 0.4)
hud.cash:SetShadowOffset(2, -2)
hud.delta = hud:CreateFontString(nil, "OVERLAY")
hud.delta:SetFont(GTA.FONT_BLOCK, 20, "OUTLINE")
hud.delta:SetPoint("TOPRIGHT", hud.cash, "BOTTOMRIGHT", 0, -2)

local function commas(n)
    local s = tostring(math.floor(math.abs(n)))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (n < 0 and "-$" or "$") .. out
end
GTA.Commas = commas

local shown, target, deltaLeft = 0, 0, 0
hud:SetScript("OnUpdate", function(self, dt)
    if shown ~= target then
        local diff = target - shown
        local stepv = math.max(1, math.abs(diff) * dt * 4)
        if math.abs(diff) <= stepv then shown = target else shown = shown + (diff > 0 and stepv or -stepv) end
        self.cash:SetText(commas(shown))
    end
    if deltaLeft > 0 then
        deltaLeft = deltaLeft - dt
        self.delta:SetAlpha(math.min(1, deltaLeft))
    end
    if GTA.WantedTick then GTA:WantedTick(dt) end
end)

function GTA:SetCash(copper, animate)
    local old = target
    target = copper
    if not animate then
        shown = copper
        hud.cash:SetText(commas(copper))
        return
    end
    local d = copper - old
    if d ~= 0 then
        hud.delta:SetText((d > 0 and "|cff5fe05f+" or "|cffff4040-") .. commas(d):gsub("^%-", "") .. "|r")
        deltaLeft = 2.5
    end
end

function GTA:RefreshHud()
    local on = self.db.enabled
    hud:SetShown(on and (self:On("cash") or self:On("wanted")))
    hud.cash:SetShown(self:On("cash"))
    hud.delta:SetShown(self:On("cash"))
    for _, s in ipairs(hud.stars) do s:SetShown(self:On("wanted")) end
end

-- Ride card and speedometer, bottom right.
local ride = CreateFrame("Frame", nil, UIParent)
ride:SetSize(512, 128)
ride:SetPoint("BOTTOMRIGHT", -40, 220)
ride:SetScale(0.7)
ride:Hide()
local rbg = ride:CreateTexture(nil, "BACKGROUND")
rbg:SetAllPoints()
rbg:SetTexture(GTA:Tex("card_ride"))
ride.name = ride:CreateFontString(nil, "OVERLAY")
ride.name:SetFont(GTA.FONT_TITLE, 52, "OUTLINE")
ride.name:SetPoint("CENTER", 10, 14)
ride.name:SetTextColor(1, 1, 1)
ride.sub = ride:CreateFontString(nil, "OVERLAY")
ride.sub:SetFont(GTA.FONT_BLOCK, 24, "")
ride.sub:SetPoint("TOP", ride.name, "BOTTOM", 0, -4)
ride.sub:SetTextColor(1, 0.77, 0.16)

GTA:Movable(ride, "ride", function(f) f:Hide() end, function()
    ride.name:SetText("STOLEN RIDE CARD")
    ride.sub:SetText("shift-drag me")
    GTA.TempShow(ride)
end)

function GTA:RideCard(name, sub)
    ride.name:SetText(name)
    ride.sub:SetText(sub or "")
    ride:Show()
    UIFrameFadeIn(ride, 0.3, 0, 1)
    if ride.timer then ride.timer:Cancel() end
    ride.timer = C_Timer.NewTimer(4, function() UIFrameFadeOut(ride, 0.6, 1, 0) C_Timer.After(0.7, function() ride:Hide() end) end)
end

local speedo = CreateFrame("Frame", nil, UIParent)
speedo:SetSize(256, 256)
speedo:SetPoint("BOTTOMRIGHT", -30, 260)
speedo:SetScale(0.55)
speedo:Hide()
local sbg = speedo:CreateTexture(nil, "BACKGROUND")
sbg:SetAllPoints()
sbg:SetTexture(GTA:Tex("speedo"))
local needle = speedo:CreateTexture(nil, "ARTWORK")
needle:SetAllPoints()
needle:SetTexture(GTA:Tex("speedo_needle"))
speedo.value = speedo:CreateFontString(nil, "OVERLAY")
speedo.value:SetFont(GTA.FONT_BLOCK, 40, "OUTLINE")
speedo.value:SetPoint("CENTER", 0, -50)

local hasSpeed = type(GetUnitSpeed) == "function"
local smooth = 0
speedo:SetScript("OnUpdate", function(_, dt)
    local ok, speed = pcall(GetUnitSpeed, "player")
    speed = ok and GTA.Safe(speed) or 0
    smooth = smooth + (speed - smooth) * math.min(1, dt * 5)
    local mph = smooth * 10
    speedo.value:SetText(string.format("%d", mph))
    -- needle sweeps 240 degrees: 0 mph at 7 o'clock, 300 at 5 o'clock
    local frac = math.min(1, mph / 300)
    needle:SetRotation(math.rad(120 - frac * 240))
end)

GTA:Movable(speedo, "speedo", nil, function() GTA.TempShow(speedo, 20, function() return IsMounted() end) end)

function GTA:ShowSpeedo(show)
    speedo:SetShown(show and hasSpeed and self:On("rides"))
end

GTA:OnLogin(function()
    GTA:SetCash(GetMoney(), false)
    GTA:RefreshHud()
end)
