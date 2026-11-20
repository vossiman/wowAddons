local _, GTA = ...

local STATIONS = {
    { name = "GOBLIN FUNK 104.1", file = "radio_goblin_funk", length = 18.46, dj = {
        "You're listening to Goblin Funk! Time is money, friend, and this song costs 3 silver a minute.",
        "That was 'Kaboom In My Heart'. Up next: 'Kaboom In My Heart (Extended Kaboom)'.",
        "Goblin Funk is brought to you by Venture Co. Strip-mining your childhood memories since forever.",
    } },
    { name = "MURLOC WAVE FM", file = "radio_murloc_wave", length = 16.22, dj = {
        "Mrglglglgl! Mrgl mrgl! (Translation: stay hydrated, landwalkers.)",
        "MURLOC WAVE: the only station broadcasting from underwater since nobody asked.",
        "Caller on line one says he's 'a fish, but cooler'. Classic Gurgle.",
    } },
    { name = "ELWYNN LO-FI", file = "radio_elwynn_lofi", length = 24.62, dj = {
        "Lo-fi beats to farm boar livers to. Relax. The quest giver isn't going anywhere.",
        "Somewhere a kobold just yelled 'you no take candle'. Respect his boundaries.",
        "Gentle reminder: the Defias also need self-care.",
    } },
    { name = "TALK AZEROTH AM", file = nil, length = 14, dj = {
        "Today on Talk Azeroth: are gnomes REALLY that short, or just far away?",
        "Caller asks: 'Is it a crime if the NPC respawns?' Our legal expert says: no comment.",
        "Ad break: Feeling slow? Try Swiftness Potion. Side effects include running into walls faster.",
        "Ad break: Goldshire Inn. You won't remember your stay, and neither will we.",
        "Breaking news: local hero kills 10 rats, demands parade. More at eleven.",
        "Weather: Stormwind cloudy, Orgrimmar spiky, Undercity... moist.",
    } },
}

local station = 0
local handle, loopTimer, djTimer

local nowPlaying = CreateFrame("Frame", nil, UIParent)
nowPlaying:SetSize(512, 512)
nowPlaying:SetScale(0.35)
nowPlaying:SetPoint("TOP", UIParent, "TOP", 0, -120)
nowPlaying:SetFrameStrata("HIGH")
nowPlaying:Hide()
local wheel = nowPlaying:CreateTexture(nil, "ARTWORK")
wheel:SetAllPoints()
wheel:SetTexture(GTA:Tex("radio_wheel"))
nowPlaying.label = nowPlaying:CreateFontString(nil, "OVERLAY")
nowPlaying.label:SetFont(GTA.FONT_TITLE, 90, "THICKOUTLINE")
nowPlaying.label:SetPoint("TOP", nowPlaying, "BOTTOM", 0, -10)
nowPlaying.label:SetTextColor(1, 0.77, 0.16)

local function flashWheel(text)
    nowPlaying.label:SetText(text)
    nowPlaying:Show()
    UIFrameFadeIn(nowPlaying, 0.2, 0, 1)
    if nowPlaying.timer then nowPlaying.timer:Cancel() end
    nowPlaying.timer = C_Timer.NewTimer(2.2, function() UIFrameFadeOut(nowPlaying, 0.5, 1, 0) C_Timer.After(0.6, function() nowPlaying:Hide() end) end)
end

local function stopAudio()
    if handle then StopSound(handle, 300) handle = nil end
    if loopTimer then loopTimer:Cancel() loopTimer = nil end
    if djTimer then djTimer:Cancel() djTimer = nil end
end

local function playLoop(s)
    if s.file then
        handle = GTA:Sound(s.file)
        loopTimer = C_Timer.NewTimer(s.length, function() playLoop(s) end)
    end
end

local function startStation(i)
    stopAudio()
    station = i
    if i == 0 then
        flashWheel("RADIO OFF")
        return
    end
    local s = STATIONS[i]
    GTA:Sound("radio_static")
    flashWheel(s.name)
    C_Timer.After(0.6, function()
        if station ~= i then return end
        playLoop(s)
    end)
    djTimer = C_Timer.NewTicker(s.file and 30 or 14, function()
        GTA:Toast("|cffffc428" .. s.name .. "|r\n" .. GTA.Pick(s.dj), "radio_static", 6)
    end)
    C_Timer.After(1.5, function()
        if station == i then GTA:Toast("|cffffc428" .. s.name .. "|r\n" .. GTA.Pick(s.dj), "radio_static", 6) end
    end)
end

function GTA:RadioNext()
    if not self:On("radio") then return end
    startStation((station + 1) % (#STATIONS + 1))
    self.db.lastStation = station
end

function GTA:RadioOnMount(mounted)
    if not self:On("radio") then
        if station ~= 0 then stopAudio() station = 0 end
        return
    end
    if mounted and station == 0 and (self.db.lastStation or 1) > 0 then
        startStation(self.db.lastStation or 1)
    elseif not mounted and station ~= 0 then
        stopAudio()
        station = 0
    end
end

GTA:Command("radio", "next radio station (auto-plays while mounted)", function() GTA:RadioNext() end)
