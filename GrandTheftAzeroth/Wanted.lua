local _, GTA = ...

local level = 0
local heat = 0          -- seconds of calm needed before the next star drops
local flash = 0
local sirenHandle
local CALM_PER_STAR = 25

function GTA:Wanted() return level end

local function draw()
    for i, s in ipairs(GTA.hud.stars) do
        s:SetTexture(GTA:Tex(i <= level and (level >= 4 and "star_hot" or "star_full") or "star_empty"))
    end
end

function GTA:SetWanted(n, reason)
    if not self:On("wanted") then return end
    n = math.max(0, math.min(5, n))
    if n == level then return end
    local up = n > level
    level = n
    heat = CALM_PER_STAR
    flash = up and 3 or 0
    draw()
    -- Stars only make noise together with something big on screen: the text box carries
    -- the blip (and waits for combat to end), the siren comes with flashing police lights.
    if up then
        for i = 1, level do self.hud.stars[i].pulse:Play() end
        if reason then self:Toast("|cffffc428WANTED LEVEL " .. level .. "|r\n" .. reason, "star_up", 3) end
        if level > (self.db.stats.maxWanted or 0) then
            self.db.stats.maxWanted = level
            if self.CheckAchievements then self:CheckAchievements("maxWanted") end
        end
        if level >= 3 and not sirenHandle then
            sirenHandle = self:Sound("siren")
            self:PoliceLights(3)
            C_Timer.After(3, function() sirenHandle = nil end)
        end
    elseif level == 0 then
        self:Toast("You lost the cops. |cff5fe05fHeat cleared.|r", "star_down", 3)
    end
end

function GTA:AddWanted(n, reason)
    self:SetWanted(level + (n or 1), reason)
end

function GTA:WantedTick(dt)
    if level == 0 then return end
    local stars = self.hud.stars
    if flash > 0 or UnitAffectingCombat("player") then
        flash = math.max(0, flash - dt)
        local a = (math.sin(GetTime() * 12) > 0) and 1 or 0.35
        for i = 1, level do stars[i]:SetAlpha(a) end
    else
        for i = 1, level do stars[i]:SetAlpha(1) end
    end
    if not UnitAffectingCombat("player") then
        heat = heat - dt * (self.calmFactor or 1)
        if heat <= 0 then self:SetWanted(level - 1) end
    end
end

GTA:OnLogin(function()
    level = 0
    draw()
end)
