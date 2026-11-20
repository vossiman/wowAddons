local _, GTA = ...

local function fadeGroup(frame, hold, popScale)
    local ag = frame:CreateAnimationGroup()
    local pop = ag:CreateAnimation("Scale")
    pop:SetOrder(1)
    pop:SetScaleFrom(popScale or 1.8, popScale or 1.8)
    pop:SetScaleTo(1, 1)
    pop:SetDuration(0.22)
    pop:SetSmoothing("OUT")
    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetOrder(1)
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.15)
    local stay = ag:CreateAnimation("Alpha")
    stay:SetOrder(2)
    stay:SetFromAlpha(1)
    stay:SetToAlpha(1)
    stay:SetDuration(hold)
    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetOrder(3)
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.45)
    ag:SetScript("OnFinished", function() frame:Hide() end)
    ag.stay = stay
    return ag
end

-- Big centre banner: one at a time, queued.
local banner = CreateFrame("Frame", nil, UIParent)
banner:SetSize(1024, 256)
banner:SetPoint("CENTER", 0, 150)
banner:SetScale(0.75)
banner:SetFrameStrata("FULLSCREEN_DIALOG")
banner:Hide()
banner.tex = banner:CreateTexture(nil, "ARTWORK")
banner.tex:SetAllPoints()
banner.text = banner:CreateFontString(nil, "OVERLAY")
banner.text:SetFont(GTA.FONT_TITLE, 110, "THICKOUTLINE")
banner.text:SetPoint("CENTER")
banner.text:SetShadowOffset(5, -5)
banner.sub = banner:CreateFontString(nil, "OVERLAY")
banner.sub:SetFont(GTA.FONT_BLOCK, 38, "OUTLINE")
banner.sub:SetPoint("TOP", banner, "BOTTOM", 0, 20)
banner.sub:SetTextColor(1, 1, 1)
banner.anim = fadeGroup(banner, 2.4)

local queue = {}
local function nextBanner()
    if banner:IsShown() or #queue == 0 then return end
    local b = table.remove(queue, 1)
    if b.texture then
        banner.tex:SetTexture(GTA:Tex(b.texture))
        banner.tex:Show()
        banner.text:Hide()
    else
        banner.tex:Hide()
        banner.text:SetText(b.text)
        banner.text:SetTextColor(unpack(b.color or { 1, 0.77, 0.16 }))
        banner.text:Show()
    end
    banner.sub:SetText(b.sub or "")
    banner.anim.stay:SetDuration(b.hold or 2.4)
    banner:SetAlpha(0)
    banner:Show()
    banner.anim:Play()
    if b.sound then GTA:Sound(b.sound) end
end
banner:SetScript("OnHide", function() C_Timer.After(0.1, nextBanner) end)

-- opts: texture=name | text=string, color={r,g,b}, sub=string, sound=name, hold=seconds, priority=bool
function GTA:Banner(opts)
    if #queue > 4 then return end
    if opts.priority then table.insert(queue, 1, opts) else table.insert(queue, opts) end
    nextBanner()
end

-- Top-left help box, the classic "here is what you should do" panel.
local toast = CreateFrame("Frame", nil, UIParent)
toast:SetSize(380, 90)
toast:SetPoint("TOPLEFT", 24, -90)
toast:SetFrameStrata("HIGH")
toast:Hide()
local tbg = toast:CreateTexture(nil, "BACKGROUND")
tbg:SetAllPoints()
tbg:SetTexture(GTA:Tex("panel_dark"))
toast.text = toast:CreateFontString(nil, "OVERLAY")
toast.text:SetFont(GTA.FONT_BLOCK, 17, "")
toast.text:SetPoint("TOPLEFT", 18, -12)
toast.text:SetPoint("BOTTOMRIGHT", -18, 12)
toast.text:SetJustifyH("LEFT")
toast.text:SetJustifyV("MIDDLE")
toast.text:SetTextColor(1, 1, 1)
toast.anim = fadeGroup(toast, 4, 1.05)

local toasts = {}
local function nextToast()
    if toast:IsShown() or #toasts == 0 then return end
    local t = table.remove(toasts, 1)
    toast.text:SetText(t.text)
    toast.anim.stay:SetDuration(t.hold or 4)
    toast:SetAlpha(0)
    toast:Show()
    toast.anim:Play()
    GTA:Sound(t.sound or "text_ping")
end
toast:SetScript("OnHide", function() C_Timer.After(0.2, nextToast) end)

-- Text boxes wait until combat ends so they are not missed mid-fight; urgent=true skips the wait.
local deferred, history = {}, {}
GTA.history = history

function GTA:Toast(text, sound, hold, urgent)
    local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " - ")
    table.insert(history, date("%H:%M") .. "  " .. plain)
    while #history > 40 do table.remove(history, 1) end
    if not urgent and UnitAffectingCombat("player") then
        if #deferred < 4 then table.insert(deferred, { text = text, sound = sound, hold = hold }) end
        return
    end
    if #toasts > 5 then return end
    table.insert(toasts, { text = text, sound = sound, hold = hold })
    nextToast()
end

GTA:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    C_Timer.After(1.5, function()
        if UnitAffectingCombat("player") then return end
        for _, t in ipairs(deferred) do table.insert(toasts, t) end
        wipe(deferred)
        nextToast()
    end)
end)

GTA:Command("log", "re-read the last pop-up messages", function()
    GTA:Print("recent messages:")
    for i = math.max(1, #history - 14), #history do print("  " .. history[i]) end
end)

-- Breaking-news ticker scrolling along the bottom of the screen.
local ticker = CreateFrame("Frame", nil, UIParent)
ticker:SetPoint("BOTTOMLEFT", 0, 0)
ticker:SetPoint("BOTTOMRIGHT", 0, 0)
ticker:SetHeight(34)
ticker:SetFrameStrata("HIGH")
ticker:SetClipsChildren(true)
ticker:Hide()
local tkbg = ticker:CreateTexture(nil, "BACKGROUND")
tkbg:SetAllPoints()
tkbg:SetColorTexture(0.55, 0, 0, 0.85)
local tklabel = ticker:CreateFontString(nil, "OVERLAY")
tklabel:SetFont(GTA.FONT_BLOCK, 20, "")
tklabel:SetPoint("LEFT", 0, 0)
tklabel:SetText("  BREAKING  ")
local tklbg = ticker:CreateTexture(nil, "ARTWORK")
tklbg:SetColorTexture(1, 1, 1, 1)
tklbg:SetPoint("TOPLEFT")
tklbg:SetPoint("BOTTOMRIGHT", tklabel, "BOTTOMRIGHT", 0, -7)
tklabel:SetTextColor(0.6, 0, 0)
tklabel:SetDrawLayer("OVERLAY", 7)
ticker.text = ticker:CreateFontString(nil, "OVERLAY")
ticker.text:SetFont(GTA.FONT_BLOCK, 20, "")
ticker.text:SetTextColor(1, 1, 1)
ticker:SetScript("OnUpdate", function(self, dt)
    self.x = self.x - dt * 140
    self.text:SetPoint("LEFT", self, "LEFT", self.x, 0)
    if self.x < -self.text:GetStringWidth() then self:Hide() end
end)

function GTA:News(text)
    ticker.text:SetText(text .. "        ///        " .. text)
    ticker.x = UIParent:GetWidth()
    ticker:Show()
    self:Sound("text_ping")
end

-- Camera flash.
local flash = CreateFrame("Frame", nil, UIParent)
flash:SetAllPoints(UIParent)
flash:SetFrameStrata("FULLSCREEN_DIALOG")
flash:Hide()
local ftex = flash:CreateTexture(nil, "OVERLAY")
ftex:SetAllPoints()
ftex:SetColorTexture(1, 1, 1, 1)

function GTA:Flash()
    UIFrameFadeOut(flash, 0.6, 0.9, 0)
    flash:Show()
    C_Timer.After(0.65, function() flash:Hide() end)
end

-- Police lights pulsing in the screen corners.
local lights = CreateFrame("Frame", nil, UIParent)
lights:SetAllPoints(UIParent)
lights:SetFrameStrata("BACKGROUND")
lights:Hide()
local red = lights:CreateTexture(nil, "ARTWORK")
red:SetTexture(GTA:Tex("siren_red"))
red:SetSize(900, 900)
red:SetPoint("CENTER", lights, "TOPLEFT", 0, 0)
red:SetBlendMode("ADD")
local blue = lights:CreateTexture(nil, "ARTWORK")
blue:SetTexture(GTA:Tex("siren_blue"))
blue:SetSize(900, 900)
blue:SetPoint("CENTER", lights, "TOPRIGHT", 0, 0)
blue:SetBlendMode("ADD")
lights:SetScript("OnUpdate", function(self, dt)
    self.left = self.left - dt
    local on = math.sin(GetTime() * 9) > 0
    red:SetAlpha(on and 0.55 or 0.05)
    blue:SetAlpha(on and 0.05 or 0.55)
    if self.left <= 0 then self:Hide() end
end)

function GTA:PoliceLights(seconds)
    lights.left = seconds or 4
    lights:Show()
end

-- Comic burst stickers that pop up somewhere near the middle.
local stickers = {}
local function getSticker()
    for _, s in ipairs(stickers) do
        if not s:IsShown() then return s end
    end
    local s = CreateFrame("Frame", nil, UIParent)
    s:SetSize(256, 256)
    s:SetFrameStrata("FULLSCREEN")
    s.tex = s:CreateTexture(nil, "ARTWORK")
    s.tex:SetAllPoints()
    s.anim = fadeGroup(s, 0.7, 2.6)
    table.insert(stickers, s)
    return s
end

function GTA:Sticker(name, sound, scale)
    local s = getSticker()
    s.tex:SetTexture(self:Tex(name))
    s.tex:SetRotation(math.rad(math.random(-25, 25)))
    s:SetScale(scale or (0.5 + math.random() * 0.3))
    s:ClearAllPoints()
    s:SetPoint("CENTER", UIParent, "CENTER", math.random(-500, 500), math.random(-250, 300))
    s:SetAlpha(0)
    s:Show()
    s.anim:Play()
    if sound then self:Sound(sound) end
end

-- Full-screen tint with a vignette.
local overlay = CreateFrame("Frame", nil, UIParent)
overlay:SetAllPoints(UIParent)
overlay:SetFrameStrata("BACKGROUND")
overlay:Hide()
overlay.solid = overlay:CreateTexture(nil, "BACKGROUND")
overlay.solid:SetAllPoints()
overlay.vig = overlay:CreateTexture(nil, "BORDER")
overlay.vig:SetAllPoints()
overlay.fadeIn = overlay:CreateAnimationGroup()
local oi = overlay.fadeIn:CreateAnimation("Alpha")
oi:SetFromAlpha(0)
oi:SetToAlpha(1)
oi:SetDuration(0.8)
overlay.fadeIn:SetToFinalAlpha(true)

function GTA:Overlay(vignette, r, g, b, a, seconds)
    overlay.vig:SetTexture(self:Tex(vignette))
    overlay.solid:SetColorTexture(r, g, b, a)
    overlay:SetAlpha(0)
    overlay:Show()
    overlay.fadeIn:Play()
    if overlay.timer then overlay.timer:Cancel() end
    if seconds then
        overlay.timer = C_Timer.NewTimer(seconds, function() overlay:Hide() end)
    end
end

function GTA:ClearOverlay()
    if overlay.timer then overlay.timer:Cancel() end
    overlay:Hide()
end

-- Confetti: coloured bits falling from the top.
local confetti = CreateFrame("Frame", nil, UIParent)
confetti:SetAllPoints(UIParent)
confetti:SetFrameStrata("FULLSCREEN")
confetti:Hide()
confetti.bits = {}
local COLORS = { { 1, .2, .2 }, { 1, .77, .16 }, { .24, .8, .35 }, { .16, .86, 1 }, { 1, .27, .67 }, { .63, .35, 1 } }
for i = 1, 70 do
    local t = confetti:CreateTexture(nil, "OVERLAY")
    t:SetSize(math.random(6, 12), math.random(10, 18))
    confetti.bits[i] = t
end
confetti:SetScript("OnUpdate", function(self, dt)
    self.left = self.left - dt
    local h = UIParent:GetHeight()
    for _, t in ipairs(self.bits) do
        t.y = t.y - t.vy * dt
        t.x = t.x + math.sin(GetTime() * t.wob) * 40 * dt
        t.rot = t.rot + t.spin * dt
        t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", t.x, t.y)
        t:SetRotation(t.rot)
        if t.y < -20 then t.y = h + 20 end
    end
    if self.left <= 0 then self:Hide() end
end)

function GTA:Confetti(seconds)
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    for _, t in ipairs(confetti.bits) do
        t:SetColorTexture(unpack(COLORS[math.random(#COLORS)]))
        t.x, t.y = math.random(0, math.floor(w)), h + math.random(0, math.floor(h))
        t.vy = math.random(120, 300)
        t.wob = math.random(2, 6)
        t.rot, t.spin = 0, (math.random() - 0.5) * 10
    end
    confetti.left = seconds or 3
    confetti:Show()
end
