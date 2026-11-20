local _, GTA = ...

-- Letterbox bars that slide in from top and bottom, with a film-style title card.
local cine = CreateFrame("Frame", nil, UIParent)
cine:SetAllPoints(UIParent)
cine:SetFrameStrata("FULLSCREEN")
cine:Hide()

local top = cine:CreateTexture(nil, "BACKGROUND")
top:SetColorTexture(0, 0, 0, 1)
local bottom = cine:CreateTexture(nil, "BACKGROUND")
bottom:SetColorTexture(0, 0, 0, 1)

cine.title = cine:CreateFontString(nil, "OVERLAY")
cine.title:SetFont(GTA.FONT_BLOCK, 34, "")
cine.title:SetTextColor(1, 1, 1)
cine.sub = cine:CreateFontString(nil, "OVERLAY")
cine.sub:SetFont(GTA.FONT_HAND, 18, "")
cine.sub:SetTextColor(1, 0.77, 0.16)

local state, t, hold, barH = "off", 0, 0, 0
local IN, OUT = 0.45, 0.6

local function layout(frac)
    local h = barH * frac
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(math.max(1, h))
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(math.max(1, h))
    cine.title:SetAlpha(frac)
    cine.sub:SetAlpha(frac)
end

cine.title:SetPoint("LEFT", top, "LEFT", 60, 0)
cine.sub:SetPoint("RIGHT", bottom, "RIGHT", -60, 0)

cine:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    if state == "in" then
        layout(math.min(1, t / IN))
        if t >= IN then state, t = "hold", 0 end
    elseif state == "hold" then
        if t >= hold then state, t = "out", 0 end
    elseif state == "out" then
        layout(math.max(0, 1 - t / OUT))
        if t >= OUT then state = "off" self:Hide() end
    end
end)

function GTA:Cutscene(title, sub, seconds)
    if not self:On("cinema") then return end
    barH = UIParent:GetHeight() * 0.11
    cine.title:SetText(title and title:upper() or "")
    cine.sub:SetText(sub or "")
    hold = seconds or 3
    if state == "off" then
        state, t = "in", 0
        layout(0)
    else
        state, t = "hold", 0
    end
    cine:Show()
end
