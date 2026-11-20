local _, GTA = ...

---------------------------------------------------------------- taxi meter
local meter = CreateFrame("Frame", nil, UIParent)
meter:SetSize(260, 80)
meter:SetPoint("TOP", UIParent, "TOP", 0, -140)
meter:SetFrameStrata("HIGH")
meter:Hide()
local mbg = meter:CreateTexture(nil, "BACKGROUND")
mbg:SetAllPoints()
mbg:SetTexture(GTA:Tex("panel_dark"))
meter.label = meter:CreateFontString(nil, "OVERLAY")
meter.label:SetFont(GTA.FONT_BLOCK, 14, "")
meter.label:SetPoint("TOP", 0, -10)
meter.label:SetTextColor(1, 0.77, 0.16)
meter.label:SetText("GRYPHON CAB CO.  -  FARE")
meter.fare = meter:CreateFontString(nil, "OVERLAY")
meter.fare:SetFont(GTA.FONT_BLOCK, 34, "OUTLINE")
meter.fare:SetPoint("BOTTOM", 0, 8)
meter.fare:SetTextColor(1, 0.3, 0.3)

local fare, rate, started = 0, 0, 0
meter:SetScript("OnUpdate", function(self, dt)
    fare = fare + rate * dt
    self.fare:SetText(GTA.Commas(fare))
    if not UnitOnTaxi("player") and GetTime() - started > 2 then
        self:Hide()
        local secs = math.floor(GetTime() - started)
        GTA:Stat("taxis")
        GTA:Toast(string.format("|cffffc428RECEIPT|r  %dm %02ds  -  %s\nTip: 0%%. Driver rating of you: %s", secs / 60, secs % 60, GTA.Commas(fare),
            GTA.Pick({ "1 star (rude)", "2 stars (smelled like murloc)", "1 star (yelled 'faster' 40 times)", "3 stars (fine I guess)" })), "cha_ching", 6)
    end
end)

GTA:RegisterEvent("PLAYER_CONTROL_LOST", function()
    C_Timer.After(0.6, function()
        if GTA:On("rides") and UnitOnTaxi("player") and not meter:IsShown() then
            fare, rate, started = math.random(5, 12), math.random(3, 9) + math.random(), GetTime()
            meter:Show()
        end
    end)
end)

---------------------------------------------------------------- minimap police ring
local ring = CreateFrame("Frame", nil, UIParent)
ring:SetFrameStrata("LOW")
ring:Hide()
local red = ring:CreateTexture(nil, "ARTWORK")
red:SetTexture(GTA:Tex("siren_red"))
red:SetBlendMode("ADD")
red:SetPoint("CENTER", ring, "CENTER", -30, 20)
local blue = ring:CreateTexture(nil, "ARTWORK")
blue:SetTexture(GTA:Tex("siren_blue"))
blue:SetBlendMode("ADD")
blue:SetPoint("CENTER", ring, "CENTER", 30, 20)

ring:SetScript("OnUpdate", function(self)
    if not GTA:On("wanted") or GTA:Wanted() == 0 or not Minimap:IsVisible() then self:Hide() return end
    local on = math.sin(GetTime() * 8) > 0
    local strength = 0.25 + 0.12 * GTA:Wanted()
    red:SetAlpha(on and strength or 0.05)
    blue:SetAlpha(on and 0.05 or strength)
end)

local function showRing()
    if not (Minimap and GTA:On("wanted")) then return end
    local size = Minimap:GetWidth() * 1.25
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", Minimap, "CENTER")
    ring:SetSize(size, size)
    red:SetSize(size, size)
    blue:SetSize(size, size)
    ring:Show()
end

local orig = GTA.SetWanted
function GTA:SetWanted(n, reason)
    orig(self, n, reason)
    if self:Wanted() > 0 then showRing() end
end
