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

local tag = CreateFrame("Frame", nil, GTA.hud)
tag:SetSize(320, 44)
tag:SetPoint("TOPRIGHT", GTA.hud, "BOTTOMRIGHT", 0, -14)
tag:Hide()
tag.name = tag:CreateFontString(nil, "OVERLAY")
tag.name:SetFont(GTA.FONT_TITLE, 26, "OUTLINE")
tag.name:SetPoint("TOPRIGHT")
tag.name:SetTextColor(1, 1, 1)
tag.joke = tag:CreateFontString(nil, "OVERLAY")
tag.joke:SetFont(GTA.FONT_HAND, 14, "OUTLINE")
tag.joke:SetPoint("TOPRIGHT", tag.name, "BOTTOMRIGHT", 0, -2)
tag.joke:SetTextColor(1, 0.77, 0.16)

local lastSub
local function showSubzone()
    if not GTA:On("turf") then return end
    local sub = Safe(GetSubZoneText()) or ""
    if sub == "" or sub == lastSub then return end
    lastSub = sub
    local joke
    for _, j in ipairs(SUBZONE_JOKES) do
        if sub:find(j[1], 1, true) then joke = j[2] break end
    end
    tag.name:SetText(sub)
    tag.joke:SetText(joke or Pick(SUBZONE_GENERIC))
    tag:Show()
    UIFrameFadeIn(tag, 0.3, 0, 1)
    if tag.timer then tag.timer:Cancel() end
    tag.timer = C_Timer.NewTimer(6, function() UIFrameFadeOut(tag, 0.8, 1, 0) C_Timer.After(0.9, function() tag:Hide() end) end)
end
GTA:RegisterEvent("ZONE_CHANGED", showSubzone)

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
