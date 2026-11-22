local ADDON, GTA = ...
_G.GrandTheftAzeroth = GTA

GTA.PATH = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
GTA.FONT_TITLE = GTA.PATH .. "fonts\\Bangers-Regular.ttf"
GTA.FONT_BLOCK = GTA.PATH .. "fonts\\Anton-Regular.ttf"
GTA.FONT_HAND = GTA.PATH .. "fonts\\PermanentMarker-Regular.ttf"

GTA.GAGS = {
    { key = "death", label = "Death screen", desc = "Big slanted death titles and a dramatic sting when you die." },
    { key = "missions", label = "Mission banners", desc = "Mission passed / new mission / level up / heist complete banners." },
    { key = "wanted", label = "Wanted stars", desc = "Wanted level that rises with crimes and fades out of combat." },
    { key = "cash", label = "Cash counter", desc = "Your gold as a rolling dollar counter with cha-ching." },
    { key = "rides", label = "Stolen rides", desc = "Vehicle card when you mount, speedometer while riding." },
    { key = "districts", label = "District cards", desc = "Zone names with a crime-city tagline." },
    { key = "phone", label = "Fake phone", desc = "Silly texts from shady contacts every so often." },
    { key = "radio", label = "Radio", desc = "Made-up radio stations while mounted (toggle with /gta radio)." },
    { key = "mishaps", label = "Mishaps & social", desc = "Slaps, swimming, AFK, vendors, loot, duels, taxis and other reactions." },
    { key = "stunts", label = "Stunt jumps", desc = "Insane stunt bonus for jumping a lot." },
    { key = "turf", label = "Turf & travel", desc = "Subzone tags, enemy turf, heist briefings, hearthstone rides, broken gear, full bags, night shift." },
    { key = "contracts", label = "Contracts & rampages", desc = "Hit contracts from shady contacts and RAMPAGE streaks when you kill fast." },
    { key = "cinema", label = "Cutscene bars", desc = "Movie letterbox bars for level-ups, heists, contracts and promotions." },
    { key = "collect", label = "Collections & discovery", desc = "New areas, flight paths, recipes, pets, mounts, toys, titles, skills and transmog appearances." },
    { key = "combat", label = "Combat stickers", desc = "CRIT!, OOF, DENIED, WHIFF and friends when hits land, miss or get blocked." },
    { key = "chaos", label = "Street life & news", desc = "Breaking news on a timer, plus speed cameras, tax audits, insults, patrols and birds caused by what you do." },
}

local DEFAULTS = {
    enabled = true,
    sound = true,
    gags = {},
    stats = { respect = 0, deaths = 0, rides = 0, missions = 0, maxWanted = 0, earned = 0, cheats = 0, stunts = 0, critters = 0 },
    hudPos = nil,
    chaos = 2,
    volume = "med",
    allSounds = false,
    errors = {},
}

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = type(dst[k]) == "table" and dst[k] or {}
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function GTA:On(gag)
    return self.db and self.db.enabled and self.db.gags[gag] ~= false
end

function GTA:Stat(key, delta)
    local s = self.db.stats
    s[key] = (s[key] or 0) + (delta or 1)
    if self.CheckAchievements then self:CheckAchievements(key) end
    return s[key]
end

-- By default only big moments make noise; everything else is visual. "All sounds" turns every gag's sound back on.
local SPECIAL = { death_sting = true, mission_passed = true, mission_failed = true, level_up = true }

function GTA:UserSounds(seconds)
    self.forceUntil = GetTime() + (seconds or 1)
end

function GTA:Sound(name, channel, force)
    if not (self.db and self.db.sound) then return end
    local allowed = force or channel == "Music" or SPECIAL[name] or self.db.allSounds
        or (self.forceUntil and GetTime() < self.forceUntil)
    if not allowed then return end
    self.soundLog = self.soundLog or {}
    table.insert(self.soundLog, date("%H:%M:%S") .. "  " .. name .. "  <- " .. (debugstack(2, 1, 0):match("([%w_]+%.lua:%d+)") or "?"))
    if #self.soundLog > 20 then table.remove(self.soundLog, 1) end
    local ok, handle = PlaySoundFile(self.PATH .. "sounds\\" .. (self.db.volume or "med") .. "\\" .. name .. ".ogg", channel or "SFX")
    return ok and handle or nil
end

function GTA:Tex(name)
    return self.PATH .. "textures\\" .. name .. ".png"
end

function GTA.Pick(list)
    return list[math.random(#list)]
end

function GTA.Safe(v)
    if v ~= nil and issecretvalue and issecretvalue(v) then return nil end
    return v
end

function GTA:Print(msg)
    print("|cffff3030Grand Theft|r |cffffc428Azeroth|r: " .. msg)
end

function GTA:Error(where, err)
    local line = date("%H:%M:%S") .. " " .. where .. ": " .. tostring(err)
    if self.db then
        self.db.errors = self.db.errors or {}
        table.insert(self.db.errors, line)
        while #self.db.errors > 30 do table.remove(self.db.errors, 1) end
    end
    if self.debug then self:Print("|cffff0000" .. line .. "|r") end
end

local events = CreateFrame("Frame")
local handlers = {}

function GTA:RegisterEvent(event, fn)
    if not handlers[event] then
        local ok = pcall(events.RegisterEvent, events, event)
        if not ok then return false end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
    return true
end

events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do
        local ok, err = pcall(fn, ...)
        if not ok then GTA:Error(event, err) end
    end
end)

GTA.loginHooks = {}
function GTA:OnLogin(fn) table.insert(self.loginHooks, fn) end

GTA:RegisterEvent("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    GrandTheftAzerothDB = GrandTheftAzerothDB or {}
    copyDefaults(DEFAULTS, GrandTheftAzerothDB)
    GTA.db = GrandTheftAzerothDB
    if GTA.RegisterOptions then GTA:RegisterOptions() end
end)

GTA:RegisterEvent("PLAYER_LOGIN", function()
    for _, fn in ipairs(GTA.loginHooks) do
        local ok, err = pcall(fn)
        if not ok then GTA:Error("login", err) end
    end
end)

GTA.commands = {}
function GTA:Command(name, help, fn) self.commands[name] = { help = help, fn = fn } end

SLASH_GRANDTHEFTAZEROTH1 = "/gta"
SlashCmdList.GRANDTHEFTAZEROTH = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    local c = GTA.commands[cmd]
    if c then return c.fn(rest) end
    if cmd ~= "" and GTA.TryCheat and GTA:TryCheat(cmd) then return end
    GTA:Print("commands:")
    local names = {}
    for k in pairs(GTA.commands) do table.insert(names, k) end
    table.sort(names)
    for _, k in ipairs(names) do print("  /gta " .. k .. " - " .. GTA.commands[k].help) end
    print("  /gta <CHEATCODE> - you know what you did")
end

GTA:Command("on", "switch the whole addon on", function() GTA.db.enabled = true GTA:Print("on. Welcome back to the streets.") end)
GTA:Command("off", "switch the whole addon off", function() GTA.db.enabled = false GTA:Print("off. Going straight. For now.") end)
GTA.VOLUME_STEPS = { "off", "low", "med", "high" }
function GTA:VolumeLabel()
    return self.db.sound and self.db.volume or "off"
end
function GTA:SetVolume(v)
    if v == "off" then
        self.db.sound = false
    else
        self.db.sound = true
        self.db.volume = v
    end
end
GTA:Command("mute", "toggle all addon sounds", function()
    GTA.db.sound = not GTA.db.sound
    GTA:Print("sounds " .. (GTA.db.sound and "on" or "off"))
end)
GTA:Command("allsounds", "sounds for every gag (noisy) instead of only big moments", function()
    GTA.db.allSounds = not GTA.db.allSounds
    GTA:Print(GTA.db.allSounds and "every gag makes noise now. You asked for it." or "only big moments make noise.")
end)
GTA:Command("volume", "addon volume: off, low, med or high", function(arg)
    arg = (arg or ""):lower()
    if arg == "off" or arg == "low" or arg == "med" or arg == "high" then
        GTA:SetVolume(arg)
        GTA:Sound("text_ping", nil, true)
    end
    GTA:Print("volume: " .. GTA:VolumeLabel() .. "  (/gta volume off|low|med|high)")
end)
GTA:Command("debug", "toggle error output", function() GTA.debug = not GTA.debug GTA:Print("debug " .. tostring(GTA.debug)) end)
GTA:Command("toggle", "toggle one gag: /gta toggle <" .. "death|missions|wanted|cash|rides|districts|phone|radio|mishaps|stunts|chaos|turf|contracts|cinema|combat|collect>", function(key)
    key = (key or ""):lower()
    for _, g in ipairs(GTA.GAGS) do
        if g.key == key then
            GTA.db.gags[key] = GTA.db.gags[key] == false
            GTA:Print(g.label .. " " .. (GTA.db.gags[key] and "on" or "off"))
            if GTA.RefreshHud then GTA:RefreshHud() end
            return
        end
    end
    GTA:Print("unknown gag '" .. key .. "'")
end)

GTA:Command("errors", "show recent addon errors (send these to the dev)", function()
    local e = GTA.db.errors or {}
    if #e == 0 then return GTA:Print("no errors recorded. Suspiciously clean.") end
    GTA:Print(#e .. " recent errors:")
    for _, line in ipairs(e) do print("  " .. line) end
end)
GTA:Command("clearerrors", "forget recorded errors", function() wipe(GTA.db.errors) GTA:Print("errors cleared") end)

GTA:Command("sounds", "what just made that noise? (last 10 sounds and where they came from)", function()
    local log = GTA.soundLog or {}
    GTA:Print("last sounds:")
    for i = math.max(1, #log - 9), #log do print("  " .. log[i]) end
end)

---------------------------------------------------------------- movable frames
-- Shift-drag moves any addon frame (position saved per frame); a plain click runs onClick (usually: dismiss).
GTA.movables = {}

local function savePos(frame, key)
    local point, _, rel, x, y = frame:GetPoint(1)
    GTA.db.positions = GTA.db.positions or {}
    GTA.db.positions[key] = { point, rel, x, y }
end

local function applyPos(m)
    local p = GTA.db.positions and GTA.db.positions[m.key]
    m.frame:ClearAllPoints()
    if p then
        m.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        for _, pt in ipairs(m.defaults) do m.frame:SetPoint(unpack(pt)) end
    end
end

function GTA:Movable(frame, key, onClick, preview)
    local m = { frame = frame, key = key, preview = preview, defaults = {} }
    for i = 1, frame:GetNumPoints() do
        local point, rel, relPoint, x, y = frame:GetPoint(i)
        m.defaults[i] = { point, rel or UIParent, relPoint, x, y }
    end
    self.movables[key] = m
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f)
        if IsShiftKeyDown() then
            f.gtaMoving = true
            f:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        if f.gtaMoving then savePos(f, key) end
    end)
    frame:SetScript("OnMouseUp", function(f, button)
        if f.gtaMoving then f.gtaMoving = false return end
        if not IsShiftKeyDown() and onClick then onClick(f, button) end
    end)
    if self.db then applyPos(m) end
end

GTA:OnLogin(function()
    if GTA.db.hudPos and not (GTA.db.positions and GTA.db.positions.hud) then
        GTA.db.positions = GTA.db.positions or {}
        GTA.db.positions.hud = GTA.db.hudPos
    end
    GTA.db.hudPos = nil
    for _, m in pairs(GTA.movables) do applyPos(m) end
end)

function GTA.TempShow(frame, seconds, keep)
    frame:Show()
    frame:SetAlpha(1)
    C_Timer.After(seconds or 20, function()
        if not (keep and keep()) then frame:Hide() end
    end)
end

function GTA:ShowLayout()
    self:Print("layout mode: shift-drag anything into place. Frames hide again in 20 seconds.")
    for _, m in pairs(self.movables) do
        if m.preview then
            local ok, err = pcall(m.preview)
            if not ok then self:Error("layout " .. m.key, err) end
        end
    end
end

function GTA:ResetLayout()
    if self.db.positions then wipe(self.db.positions) end
    for _, m in pairs(self.movables) do applyPos(m) end
    self:Print("all frames back to their default spots.")
end

GTA:Command("layout", "show every frame so you can shift-drag them into place", function() GTA:ShowLayout() end)
GTA:Command("resetlayout", "put every frame back where it started", function() GTA:ResetLayout() end)
