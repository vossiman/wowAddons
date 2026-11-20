local _, GTA = ...

-- The "Murloc Mobile" phone: every command as a tappable app.
local phone = CreateFrame("Frame", "GrandTheftAzerothPhone", UIParent)
phone:SetSize(256, 512)
phone:SetScale(1.1)
phone:SetPoint("RIGHT", UIParent, "RIGHT", -120, 0)
phone:SetFrameStrata("DIALOG")
phone:SetMovable(true)
phone:EnableMouse(true)
phone:RegisterForDrag("LeftButton")
phone:SetClampedToScreen(true)
phone:SetScript("OnDragStart", phone.StartMoving)
phone:SetScript("OnDragStop", phone.StopMovingOrSizing)
phone:Hide()
table.insert(UISpecialFrames, "GrandTheftAzerothPhone")

local bg = phone:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture(GTA:Tex("phone"))

local header = phone:CreateFontString(nil, "OVERLAY")
header:SetFont(GTA.FONT_BLOCK, 15, "OUTLINE")
header:SetPoint("TOP", 0, -46)
header:SetTextColor(1, 1, 1)

local clock = phone:CreateFontString(nil, "OVERLAY")
clock:SetFont(GTA.FONT_BLOCK, 11, "")
clock:SetPoint("TOPRIGHT", -30, -46)

local close = CreateFrame("Button", nil, phone)
close:SetSize(40, 34)
close:SetPoint("BOTTOM", 0, 10)
close:SetScript("OnClick", function() phone:Hide() end)

local pages = {}
local function page(name)
    local f = CreateFrame("Frame", nil, phone)
    f:SetPoint("TOPLEFT", 26, -66)
    f:SetPoint("BOTTOMRIGHT", -26, 56)
    f:Hide()
    pages[name] = f
    return f
end

local current
local function show(name, title)
    for _, f in pairs(pages) do f:Hide() end
    current = name
    header:SetText(title or "MURLOC MOBILE")
    pages[name]:Show()
    if pages[name].refresh then pages[name]:refresh() end
end

local function textButton(parent, w, h, label, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    local t = b:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(0, 0, 0, 0.45)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(GTA.FONT_BLOCK, 13, "OUTLINE")
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function backButton(parent)
    local b = textButton(parent, 70, 22, "< BACK", function() show("home") end)
    b:SetPoint("BOTTOMLEFT", 0, 0)
    return b
end

local function cmd(name, arg)
    return function()
        local c = GTA.commands[name]
        if c then c.fn(arg or "") end
    end
end

---------------------------------------------------------------- home screen
local home = page("home")
local APPS = {
    { icon = "radio_wheel", label = function() return "Radio\n" .. (GTA.RadioStation and GTA:RadioStation() or "") end, run = function() GTA:RadioNext() end },
    { icon = "burst_kapow", label = function() return "Chaos!" end, run = cmd("random") },
    { icon = "siren_red", label = function() return "Chaos lvl\n" .. (GTA.db.chaos or 2) .. "/3" end, run = function()
        cmd("chaos", tostring(((GTA.db.chaos or 2) + 1) % 4))()
    end },
    { icon = "poster_wanted", label = function() return "Contract" end, run = cmd("contract") },
    { icon = "stamp_cheat", label = function() return "Cheats" end, run = function() show("cheats", "CHEATS") end },
    { icon = "respect", label = function() return "Record" end, run = function() show("record", "CRIMINAL RECORD") end },
    { icon = "panel_dark", label = function() return "Messages" end, run = function() show("log", "MESSAGES") end },
    { icon = "confetti", label = function() return "Demo" end, run = function() phone:Hide() cmd("demo")() end },
    { icon = "burst_oof", label = function() return "Prank text" end, run = function() GTA:PhoneText() end },
    { icon = "cash", label = function() return "Volume\n" .. GTA:VolumeLabel() end, run = function()
        local steps, cur = GTA.VOLUME_STEPS, GTA:VolumeLabel()
        for i, v in ipairs(steps) do
            if v == cur then GTA:SetVolume(steps[i % #steps + 1]) break end
        end
    end },
    { icon = "speedo", label = function() return "Settings" end, run = function() phone:Hide() cmd("options")() end },
    { icon = "star_full", label = function() return "Addon\n" .. (GTA.db.enabled and "on" or "off") end, run = function()
        cmd(GTA.db.enabled and "off" or "on")()
        GTA:RefreshHud()
    end },
}

local appButtons = {}
for i, app in ipairs(APPS) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local b = CreateFrame("Button", nil, home)
    b:SetSize(62, 82)
    b:SetPoint("TOPLEFT", 4 + col * 66, -4 - row * 92)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(46, 46)
    b.icon:SetPoint("TOP", 0, -2)
    b.icon:SetTexture(GTA:Tex(app.icon))
    local plate = b:CreateTexture(nil, "BACKGROUND")
    plate:SetSize(54, 54)
    plate:SetPoint("CENTER", b.icon)
    plate:SetColorTexture(0, 0, 0, 0.35)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:GetHighlightTexture():SetAllPoints(plate)
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetFont(GTA.FONT_BLOCK, 11, "OUTLINE")
    b.label:SetPoint("TOP", b.icon, "BOTTOM", 0, -4)
    b.label:SetWidth(66)
    b:SetScript("OnClick", function()
        app.run()
        GTA:Sound("text_ping")
        C_Timer.After(0.1, function() if current == "home" then home:refresh() end end)
    end)
    b.app = app
    appButtons[i] = b
end

function home:refresh()
    for _, b in ipairs(appButtons) do b.label:SetText(b.app.label()) end
end

---------------------------------------------------------------- cheats
local cheats = page("cheats")
backButton(cheats)
local cheatButtons = {}
function cheats:refresh()
    if #cheatButtons > 0 then return end
    for i, code in ipairs(GTA.CHEAT_NAMES or {}) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local b = textButton(cheats, 98, 26, code:upper(), function() GTA:TryCheat(code) end)
        b:SetPoint("TOPLEFT", col * 102, -row * 30)
        cheatButtons[i] = b
    end
end

---------------------------------------------------------------- criminal record
local record = page("record")
backButton(record)
record.text = record:CreateFontString(nil, "OVERLAY")
record.text:SetFont(GTA.FONT_BLOCK, 13, "")
record.text:SetPoint("TOPLEFT", 2, -2)
record.text:SetWidth(200)
record.text:SetJustifyH("LEFT")
record.text:SetSpacing(3)
local achBtn = textButton(record, 120, 22, "ACHIEVEMENTS", function() show("ach", "ACHIEVEMENTS") end)
achBtn:SetPoint("BOTTOMRIGHT", 0, 0)

function record:refresh()
    local s = GTA.db.stats
    local rank, idx, nextAt = GTA:Rank()
    local got = 0
    for _ in pairs(GTA.db.achievements or {}) do got = got + 1 end
    local y = "|cffffc428"
    self.text:SetText(table.concat({
        y .. "RANK|r  " .. rank:upper(),
        y .. "RESPECT|r  " .. (s.respect or 0) .. (nextAt and (" / " .. nextAt) or ""),
        y .. "WANTED|r  " .. GTA:Wanted() .. " stars (record " .. (s.maxWanted or 0) .. ")",
        "",
        "Missions passed: " .. (s.missions or 0),
        "Contracts done: " .. (s.contracts or 0),
        "Kills: " .. (s.kills or 0) .. "   Rampages: " .. (s.rampages or 0),
        "Times flattened: " .. (s.deaths or 0),
        "Stolen rides: " .. (s.rides or 0) .. "   Taxis: " .. (s.taxis or 0),
        "Critter crimes: " .. (s.critters or 0),
        "Stunts: " .. (s.stunts or 0) .. "   Cheats: " .. (s.cheats or 0),
        "Money earned: " .. GTA.Commas(s.earned or 0),
        "",
        y .. "ACHIEVEMENTS|r  " .. got,
        #(GTA.db.errors or {}) > 0 and ("|cffff4040Errors logged: " .. #GTA.db.errors .. " (/gta errors)|r") or "",
    }, "\n"))
end

---------------------------------------------------------------- achievements
local ach = page("ach")
local achBack = textButton(ach, 70, 22, "< BACK", function() show("record", "CRIMINAL RECORD") end)
achBack:SetPoint("BOTTOMLEFT", 0, 0)
ach.text = ach:CreateFontString(nil, "OVERLAY")
ach.text:SetFont(GTA.FONT_BLOCK, 11, "")
ach.text:SetPoint("TOPLEFT", 2, -2)
ach.text:SetWidth(200)
ach.text:SetJustifyH("LEFT")
function ach:refresh()
    local got = GTA.db.achievements or {}
    local lines = {}
    for _, a in ipairs(GTA.ACHIEVEMENTS or {}) do
        table.insert(lines, got[a.id] and ("|cff5fe05f+|r " .. a.name) or ("|cff707070- " .. a.name .. "|r"))
    end
    self.text:SetText(table.concat(lines, "\n"))
end

---------------------------------------------------------------- message log
local log = page("log")
backButton(log)
log.text = log:CreateFontString(nil, "OVERLAY")
log.text:SetFont(GTA.FONT_BLOCK, 11, "")
log.text:SetPoint("TOPLEFT", 2, -2)
log.text:SetWidth(200)
log.text:SetJustifyH("LEFT")
log.text:SetSpacing(4)
function log:refresh()
    local h, lines = GTA.history or {}, {}
    for i = #h, math.max(1, #h - 9), -1 do table.insert(lines, h[i]) end
    self.text:SetText(#lines > 0 and table.concat(lines, "\n") or "No messages yet. Go commit a crime.")
end

---------------------------------------------------------------- open / close
phone:SetScript("OnUpdate", function(self, dt)
    self.t = (self.t or 0) + dt
    if self.t < 1 then return end
    self.t = 0
    local h, m = GetGameTime()
    clock:SetText(string.format("%02d:%02d", GTA.Safe(h) or 0, GTA.Safe(m) or 0))
end)

function GTA:TogglePhone()
    if phone:IsShown() then
        phone:Hide()
    else
        show("home")
        phone:Show()
        self:Sound("text_ping")
    end
end
GrandTheftAzeroth_TogglePhone = function() GTA:TogglePhone() end
BINDING_HEADER_GRANDTHEFTAZEROTH = "Grand Theft Azeroth"
BINDING_NAME_GTA_PHONE = "Open the phone menu"

GTA:Command("phone", "open the phone menu", function() GTA:TogglePhone() end)
GTA:Command("text", "get a random text right now", function() GTA:PhoneText() end)

---------------------------------------------------------------- minimap button
local mm = CreateFrame("Button", "GrandTheftAzerothMinimapButton", Minimap)
mm:SetSize(32, 32)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton")
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetSize(24, 24)
mmIcon:SetPoint("CENTER")
mmIcon:SetTexture(GTA:Tex("respect"))
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetSize(54, 54)
mmBorder:SetPoint("TOPLEFT")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local function placeButton()
    local angle = math.rad(GTA.db.minimapAngle or 200)
    local r = Minimap:GetWidth() / 2 + 6
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        GTA.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
        placeButton()
    end)
end)
mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
mm:SetScript("OnClick", function(_, button)
    if button == "RightButton" then cmd("random")() else GTA:TogglePhone() end
end)
mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cffff3030Grand Theft|r |cffffc428Azeroth|r")
    GameTooltip:AddLine("Left-click: open phone", 1, 1, 1)
    GameTooltip:AddLine("Right-click: random chaos", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

GTA:OnLogin(function()
    placeButton()
    mm:SetShown(GTA.db.minimapButton ~= false)
end)

GTA:Command("minimap", "show or hide the minimap button", function()
    GTA.db.minimapButton = GTA.db.minimapButton == false
    mm:SetShown(GTA.db.minimapButton)
end)

-- Clicking the cash / stars display (without shift) opens the phone too.
GTA.hud:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and not IsShiftKeyDown() then GTA:TogglePhone() end
end)
