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
}

local DEFAULTS = {
    enabled = true,
    sound = true,
    gags = {},
    stats = { respect = 0, deaths = 0, rides = 0, missions = 0, maxWanted = 0, earned = 0, cheats = 0, stunts = 0, critters = 0 },
    hudPos = nil,
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
    return s[key]
end

function GTA:Sound(name)
    if not (self.db and self.db.sound) then return end
    local ok, handle = PlaySoundFile(self.PATH .. "sounds\\" .. name .. ".ogg", "Master")
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
        if not ok and GTA.debug then GTA:Print("|cffff0000" .. event .. "|r " .. tostring(err)) end
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
        if not ok and GTA.debug then GTA:Print("login: " .. tostring(err)) end
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
GTA:Command("mute", "toggle all addon sounds", function()
    GTA.db.sound = not GTA.db.sound
    GTA:Print("sounds " .. (GTA.db.sound and "on" or "off"))
end)
GTA:Command("debug", "toggle error output", function() GTA.debug = not GTA.debug GTA:Print("debug " .. tostring(GTA.debug)) end)
GTA:Command("toggle", "toggle one gag: /gta toggle <" .. "death|missions|wanted|cash|rides|districts|phone|radio|mishaps|stunts>", function(key)
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
