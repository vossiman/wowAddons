local _, GTA = ...
local Pick, Safe = GTA.Pick, GTA.Safe

local lastFired = {}
local function throttle(key, seconds)
    local now = GetTime()
    if lastFired[key] and now - lastFired[key] < seconds then return false end
    lastFired[key] = now
    return true
end

---------------------------------------------------------------- subzone tag under the cash counter
local SUBZONE_JOKES = {
    { "Goldshire", "You know what you did." },
    { "Inn", "Safehouse. Stew of the day: don't ask." },
    { "Graveyard", "Your second home." },
    { "Cemetery", "Your second home." },
    { "Abbey", "Monks. Suspiciously calm monks." },
    { "Cathedral", "Confession booth is open. Bring snacks." },
    { "Mine", "Unregulated mining operation. Kobold labour." },
    { "Farm", "Organic. Free-range. Haunted?" },
    { "Camp", "Tents. Campfire. Zero building permits." },
    { "Dock", "Shipments arrive at midnight. Don't look in the crates." },
    { "Harbor", "Shipments arrive at midnight. Don't look in the crates." },
    { "Bank", "Casing the joint. Purely hypothetically." },
    { "Barracks", "Cop HQ. Walk casually. CASUALLY." },
    { "Keep", "Gated community. Very old money." },
    { "Tower", "Wizard lives here. Rent is paid in mana." },
    { "Cave", "Bad lighting. Worse tenants." },
    { "Lake", "Body of water. Possibly literal." },
    { "Trade District", "Shopping district. Pickpocket heaven." },
    { "Old Town", "Old town. Older grudges." },
    { "Dwarven District", "Forge noise 24/7. Neighbours furious." },
}
local SUBZONE_GENERIC = {
    "Quiet neighbourhood. Too quiet.",
    "Locals are staring. Keep walking.",
    "Great view. Terrible crime rate.",
    "Somebody's mom lives here.",
    "Nothing to see here. Move along.",
    "Prime real estate (if you like wolves).",
}

-- Subzone card, bottom right above the district card.
local card = CreateFrame("Frame", nil, UIParent)
card:SetSize(640, 110)
card:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -24, 290)
card:SetScale(0.6)
card:SetFrameStrata("HIGH")
card:Hide()
local cardBg = card:CreateTexture(nil, "BACKGROUND")
cardBg:SetAllPoints()
cardBg:SetTexture(GTA:Tex("card_ride"))
card.name = card:CreateFontString(nil, "OVERLAY")
card.name:SetFont(GTA.FONT_TITLE, 54, "OUTLINE")
card.name:SetPoint("TOPRIGHT", -40, -10)
card.name:SetTextColor(1, 1, 1)
card.joke = card:CreateFontString(nil, "OVERLAY")
card.joke:SetFont(GTA.FONT_HAND, 24, "OUTLINE")
card.joke:SetPoint("TOPRIGHT", card.name, "BOTTOMRIGHT", 0, -2)
card.joke:SetTextColor(1, 0.77, 0.16)
GTA:Movable(card, "subzone", function(f) f:Hide() end, function()
    card.name:SetText("Subzone Card")
    card.joke:SetText("Shift-drag me. Click to close.")
    GTA.TempShow(card)
end)

-- Things that happen because of where you just walked in.
local function casing(sub)
    GTA:Toast("Casing the joint... don't hang around too long.")
    C_Timer.After(20, function()
        if (Safe(GetSubZoneText()) or "") == sub and not UnitAffectingCombat("player") then
            GTA:AddWanted(1, "Loitering outside " .. sub .. ". Security has your description.")
        end
    end)
end

local HAPPENINGS = {
    { "Inn", 0.6, function()
        if GTA:Wanted() > 0 then
            GTA:SetWanted(GTA:Wanted() - 1)
            GTA:Toast("|cff5fe05fSAFEHOUSE|r\nThe innkeeper hides you in the back. Heat -1 star.")
        end
    end },
    { "Mine", 0.4, function() GTA:Toast("Labour dispute: the kobolds are unionising. Their only demand is candles.") end },
    { "Farm", 0.4, function()
        GTA:TextSticker("TRESPASSER", "red", true, 0.5)
        GTA:Toast("|cffffc428Farmer:|r GET OFF MY LAND!")
    end },
    { "Graveyard", 0.5, function() GTA:Toast("Spirit healer: 'Your regular table is ready.'") end },
    { "Cemetery", 0.5, function() GTA:Toast("Spirit healer: 'Your regular table is ready.'") end },
    { "Bank", 0.7, casing },
    { "Dock", 0.4, casing },
    { "Harbor", 0.4, casing },
    { "Barracks", 0.5, function() if GTA:Wanted() > 0 then GTA:Patrol() else GTA:Toast("Cop HQ. Walk casually. CASUALLY.") end end },
    { "Cathedral", 0.5, function()
        if GTA:Wanted() > 0 then
            GTA:SetWanted(0)
            GTA:Toast("|cff5fe05fCONFESSION BOOTH|r\nAll sins forgiven. Heat cleared. Donations welcome.")
        end
    end },
    { "Abbey", 0.4, function() GTA:Toast("Monks. Suspiciously calm monks. What are they hiding?") end },
}

local NEIGHBOURHOOD = {
    function() GTA:Toast("|cffffc428Street vendor:|r Hot dogs! Well, hot boar. Close enough.") end,
    function()
        GTA:TextSticker("MUGGED?", "cyan", true, 0.5)
        GTA:Toast("A mugger tried you. He saw your gear and apologised.")
    end,
    function() GTA:Toast("Fresh graffiti on the wall: '" .. (UnitName("player") or "YOU") .. " WAS HERE'. Wasn't you. Probably.") end,
    function() GTA:Sponsor() end,
}

local lastSub, lastHappening = nil, 0
local happened = {}
local function showSubzone()
    if not GTA:On("turf") then return end
    local sub = Safe(GetSubZoneText()) or ""
    if sub == "" or sub == lastSub then return end
    lastSub = sub
    local joke
    for _, j in ipairs(SUBZONE_JOKES) do
        if sub:find(j[1], 1, true) then joke = j[2] break end
    end
    card.name:SetText(sub)
    card.joke:SetText(joke or Pick(SUBZONE_GENERIC))
    card:Show()
    UIFrameFadeIn(card, 0.3, 0, 1)
    if card.timer then card.timer:Cancel() end
    card.timer = C_Timer.NewTimer(5, function() UIFrameFadeOut(card, 0.8, 1, 0) C_Timer.After(0.9, function() card:Hide() end) end)

    local now = GetTime()
    if UnitAffectingCombat("player") or now - lastHappening < 45 or (happened[sub] and now - happened[sub] < 600) then return end
    if GTA:Wanted() > 0 and math.random() < 0.3 then
        lastHappening, happened[sub] = now, now
        return C_Timer.After(2, function() GTA:Patrol() end)
    end
    for _, h in ipairs(HAPPENINGS) do
        if sub:find(h[1], 1, true) then
            if math.random() < h[2] then
                lastHappening, happened[sub] = now, now
                C_Timer.After(2, function() h[3](sub) end)
            end
            return
        end
    end
    if math.random() < 0.12 then
        lastHappening, happened[sub] = now, now
        C_Timer.After(2, Pick(NEIGHBOURHOOD))
    end
end
GTA:RegisterEvent("ZONE_CHANGED", showSubzone)

---------------------------------------------------------------- capitals, flight paths, outgrown zones
local CAPITALS = {
    ["Stormwind City"] = "Alliance", ["Ironforge"] = "Alliance", ["Darnassus"] = "Alliance",
    ["Orgrimmar"] = "Horde", ["Thunder Bluff"] = "Horde", ["Undercity"] = "Horde",
}
local wasCapital
GTA:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
    C_Timer.After(2.5, function()
        local zone = Safe(GetZoneText()) or ""
        local owner = CAPITALS[zone]
        GTA.calmFactor = 1
        if owner then
            local mine = UnitFactionGroup("player")
            if owner == mine then
                GTA.calmFactor = 2
                if GTA:On("turf") and wasCapital ~= zone then
                    GTA:Banner({ text = "DOWNTOWN", color = { 1, 1, 1 }, sub = zone:upper() .. "   Big city. Cops are busy. Heat fades faster.", hold = 2.5 })
                    GTA:EventText("city", 0.3)
                end
            else
                GTA.calmFactor = 0.5
                if GTA:On("turf") and wasCapital ~= zone then
                    GTA:Banner({ text = "ENEMY DOWNTOWN", color = { 1, 0.25, 0.25 }, sub = zone:upper() .. "   You are very much not from around here.", hold = 2.5 })
                    GTA:AddWanted(2, "Strolling through enemy downtown")
                end
            end
        end
        wasCapital = owner and zone or nil

        if GTA:On("turf") and C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapLevels then
            local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
            if ok and mapID then
                local ok2, _, playerMax = pcall(C_Map.GetMapLevels, mapID)
                local lvl = UnitLevel("player") or 0
                if ok2 and type(playerMax) == "number" and playerMax > 0 and lvl >= playerMax + 5 and throttle("outgrown:" .. zone, 3600) then
                    GTA:Toast("|cffffc428" .. zone .. "|r\nThis neighbourhood is beneath you now. The locals can tell.")
                end
            end
        end
    end)
end)

GTA:RegisterEvent("CHAT_MSG_SYSTEM", function(msg)
    msg = Safe(msg)
    if msg and ERR_NEW_TAXIPATH and msg == ERR_NEW_TAXIPATH and GTA:On("turf") then
        GTA:Banner({ text = "EXPANDING OPERATIONS", color = { 0.16, 0.86, 1 }, sub = "New flight path. The gryphons know your name now.", hold = 2 })
    end
end)

---------------------------------------------------------------- indoors
local wasIndoors
GTA:RegisterEvent("ZONE_CHANGED_INDOORS", function()
    local indoors = IsIndoors()
    if indoors == wasIndoors then return end
    wasIndoors = indoors
    showSubzone()
    if not GTA:On("turf") or not indoors or UnitAffectingCombat("player") then return end
    if IsResting() then
        if throttle("indoorsrest", 300) then GTA:Toast("Inside the safehouse. Wipe your feet. The cops can't see you here.") end
    elseif math.random() < 0.25 and throttle("indoors", 180) then
        if math.random() < 0.5 then
            GTA:AddWanted(1, "Breaking and entering. You didn't even knock.")
        else
            GTA:Toast(Pick({
                "Entering private property. Touch nothing. Loot everything.",
                "Hiding indoors? Classic. The cops will never think of that.",
                "You walked in like you own the place. You do not.",
            }))
        end
    end
end)

---------------------------------------------------------------- enemy turf (pvp zone type)
local function zonePvpType()
    local fn = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
    if not fn then return nil end
    local ok, kind = pcall(fn)
    return ok and Safe(kind) or nil
end

GTA:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
    C_Timer.After(2, function()
        if not GTA:On("turf") then return end
        lastSub = nil
        local zone = Safe(GetZoneText()) or "?"
        local kind = zonePvpType()
        if not kind or not throttle("pvp:" .. zone, 600) then return end
        if kind == "hostile" then
            GTA:PoliceLights(3)
            GTA:AddWanted(1, "Trespassing on enemy turf. They have very pointy welcome committees.")
        elseif kind == "sanctuary" then
            GTA:Toast("|cff5fe05fNEUTRAL GROUND|r\nNo shooting. No stabbing. Aggressive emoting is still allowed.")
        elseif kind == "contested" then
            GTA:Toast("|cffffc428CONTESTED TURF|r\nBoth gangs claim this block. Watch your back.")
        elseif kind == "combat" then
            GTA:Toast("|cffff4040WAR ZONE|r\nEveryone here is having a very bad day.")
        end
    end)
end)

---------------------------------------------------------------- instances: heists and gang wars
local CREWS = { "you, a tank who reads nothing, a healer with trust issues, two DPS 'just here for loot'" }
local PLANS = {
    "Walk in. Take everything. Walk out. (There is no step 4.)",
    "Tank goes first. If tank dies, blame the healer.",
    "Pull everything at once and pray. Classic.",
    "Stealth in. Hunter's pet pulls the whole room. Improvise.",
}
local lastInstance
GTA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(3, function()
        if not GTA:On("turf") then return end
        local inInstance, kind = IsInInstance()
        local name = Safe(GetInstanceInfo())
        if not inInstance then lastInstance = nil return end
        if name == lastInstance then return end
        lastInstance = name
        if kind == "pvp" or kind == "arena" then
            GTA:Banner({ text = "GANG WAR", color = { 1, 0.25, 0.25 }, sound = "siren", force = true, sub = name or "Turf war", priority = true })
            GTA:PoliceLights(4)
        elseif kind == "party" or kind == "raid" then
            GTA:Banner({ text = "HEIST BRIEFING", color = { 0.16, 0.86, 1 }, sound = "police_chirp", sub = "Target: " .. (name or "somewhere with loot"), priority = true })
            GTA:Toast("|cffffc428CREW|r " .. Pick(CREWS) .. "\n|cffffc428PLAN|r " .. Pick(PLANS), nil, 8)
            GTA:Cutscene(name or "The Job", "A Grand Theft Azeroth production", 4)
        end
    end)
end)

---------------------------------------------------------------- hearthstone, portals, bind
local function spellName(id)
    id = Safe(id)
    if not id then return nil end
    local ok, name = pcall(C_Spell and C_Spell.GetSpellName or GetSpellInfo, id)
    return ok and Safe(name) or nil
end

GTA:RegisterEvent("UNIT_SPELLCAST_START", function(unit, _, spellID)
    if unit ~= "player" or not GTA:On("turf") then return end
    local name = spellName(spellID)
    if not name then return end
    if name:find("Hearthstone") then
        GTA:Toast("|cffffc428RIDE REQUESTED|r\nYour driver (a magic rock) is 10 seconds away. 4.2 stars.", "phone_ring")
    elseif name:find("Teleport") or name:find("Portal") then
        GTA:Toast("Opening a getaway portal. No questions, no luggage limit.")
    end
end)

GTA:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or not GTA:On("turf") then return end
    local name = spellName(spellID)
    if name and name:find("Hearthstone") then
        C_Timer.After(6, function()
            GTA:Toast("Ride complete. Please rate your rock: " .. string.rep("|cffffc428*|r", math.random(1, 5)), "text_ping")
        end)
        if GTA:Wanted() > 0 then C_Timer.After(5, function() GTA:SetWanted(0) end) end
    end
end)

GTA:RegisterEvent("HEARTHSTONE_BOUND", function()
    if GTA:On("turf") then GTA:Toast("|cff5fe05fNEW SAFEHOUSE REGISTERED|r\nThe innkeeper swears he won't talk. He will.") end
end)

---------------------------------------------------------------- gear damage
local lastDura
local function durabilityState()
    local worst = 1
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        cur, max = Safe(cur), Safe(max)
        if cur and max and max > 0 then worst = math.min(worst, cur / max) end
    end
    if worst == 0 then return "broken" elseif worst < 0.25 then return "low" end
    return "ok"
end

GTA:RegisterEvent("UPDATE_INVENTORY_DURABILITY", function()
    local state = durabilityState()
    if state == lastDura then return end
    local prev = lastDura
    lastDura = state
    if not GTA:On("turf") or prev == nil then return end
    if state == "broken" then
        GTA:Sticker("burst_oof", "record_scratch", 0.8)
        GTA:Toast("|cffff4040YOUR RIDE IS TOTALED|r\nSomething you're wearing just broke. Find a mechanic (blacksmith).", nil, 6, true)
    elseif state == "low" then
        GTA:Toast("Check engine light is on. Your gear is held together with tape and hope.")
    end
end)

---------------------------------------------------------------- error messages
GTA:RegisterEvent("UI_ERROR_MESSAGE", function(_, msg)
    msg = Safe(msg)
    if not msg or not GTA:On("turf") then return end
    if (msg == ERR_INV_FULL or msg == ERR_BAG_FULL) and throttle("bagfull", 60) then
        GTA:Sticker("burst_oof", "bonk", 0.6)
        GTA:Toast("|cffffc428TRUNK'S FULL!|r\nYou can't fit another stolen boar tusk in there.", nil, 4, true)
    elseif msg == ERR_NOT_ENOUGH_MONEY and throttle("broke", 60) then
        GTA:Sound("record_scratch")
        GTA:Toast("|cffff4040CARD DECLINED|r\nTry another card. Or a life of crime.", nil, 4, true)
    end
end)

---------------------------------------------------------------- night shift
function GTA:IsNight()
    local h = GetGameTime()
    h = Safe(h) or 12
    return h >= 21 or h < 5
end

local wasNight
local function checkNight(announce)
    local night = GTA:IsNight()
    if night == wasNight then return end
    wasNight = night
    if not announce or not GTA:On("turf") then return end
    if night then
        GTA:Banner({ text = "NIGHT SHIFT", color = { 0.6, 0.45, 1 }, sound = "police_chirp", sub = "Crime rate +50%. Visibility -50%. Vibes +100%." })
    else
        GTA:Toast("|cffffc428SUNRISE|r\nThe night shift clocks out. Act normal.")
    end
end
GTA:OnLogin(function()
    checkNight(false)
    C_Timer.NewTicker(60, function() checkNight(true) end)
end)

GTA:Command("turf", "show your current subzone tag again", function() lastSub = nil showSubzone() end)
