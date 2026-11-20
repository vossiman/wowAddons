local _, GTA = ...
local Safe, Pick = GTA.Safe, GTA.Pick

local lastFired = {}
local function throttle(key, seconds)
    local now = GetTime()
    if lastFired[key] and now - lastFired[key] < seconds then return false end
    lastFired[key] = now
    return true
end

---------------------------------------------------------------- death
local DEATH_SUBS = {
    "Hospital bill: %s",
    "Priest's copay: %s",
    "Spirit healer surcharge: %s",
    "Ambulance (a very tired gryphon): %s",
    "Funeral catered by Goldshire Inn: %s",
}

GTA:RegisterEvent("PLAYER_DEAD", function()
    if not GTA:On("death") then return end
    GTA:Stat("deaths")
    local tex = GTA:Wanted() > 0 and "death_nicked" or Pick({ "death_flattened", "death_deleted", "death_yeeted", "death_respawn_pending" })
    GTA:Overlay("vignette_grey", 0.2, 0.2, 0.2, 0.55, 8)
    GTA:Banner({ texture = tex, sound = "death_sting", hold = 4, priority = true,
        sub = string.format(Pick(DEATH_SUBS), GTA.Commas(math.random(200, 9999))) })
    GTA:SetWanted(0)
end)

local function revived()
    GTA:ClearOverlay()
    if GTA:On("death") and not UnitIsDeadOrGhost("player") and throttle("revive", 5) then
        GTA:Toast(Pick({
            "Discharged from hospital. Doctor says: 'Try not doing that.'",
            "Back on the streets. Your dignity respawns in 5 minutes.",
            "Resurrected. Insurance did NOT cover that.",
        }))
    end
end
GTA:RegisterEvent("PLAYER_ALIVE", revived)
GTA:RegisterEvent("PLAYER_UNGHOST", revived)

---------------------------------------------------------------- missions
local function questTitle(id)
    local ok, t = pcall(C_QuestLog.GetTitleForQuestID, id)
    return ok and Safe(t) or nil
end

GTA:RegisterEvent("QUEST_TURNED_IN", function(questID, xp)
    if not GTA:On("missions") then return end
    local respect = math.max(1, math.floor((tonumber(xp) or 0) / 150)) + math.random(0, 3)
    GTA:Stat("missions")
    GTA:AddRespect(respect)
    GTA:Banner({ texture = "mission_passed", sound = "mission_passed",
        sub = (questTitle(questID) or "Mission") .. "   |cffffc428+" .. respect .. " RESPECT|r" })
    GTA:Confetti(2.5)
end)

GTA:RegisterEvent("QUEST_ACCEPTED", function(a, b)
    if not GTA:On("missions") then return end
    local title = questTitle(b or a) or questTitle(a)
    GTA:Toast("|cffffc428NEW MISSION|r\n" .. (title or "Someone with a ! wants a favour."))
end)

if C_QuestLog and C_QuestLog.AbandonQuest then
    hooksecurefunc(C_QuestLog, "AbandonQuest", function()
        if GTA:On("missions") then GTA:Banner({ texture = "mission_failed", sound = "mission_failed", sub = "You just... gave up? Wow." }) end
    end)
end

GTA:RegisterEvent("PLAYER_LEVEL_UP", function(level)
    if not GTA:On("missions") then return end
    GTA:AddRespect(10)
    GTA:Cutscene("Level " .. tostring(level), "Same face. Bigger ego.", 3.5)
    GTA:Banner({ texture = "level_up", sound = "level_up", sub = "LEVEL " .. tostring(level) .. "   |cffffc428+10 RESPECT|r", priority = true })
    GTA:Confetti(4)
end)

GTA:RegisterEvent("BOSS_KILL", function(_, name)
    if not GTA:On("missions") then return end
    GTA:Banner({ text = "HEIST COMPLETE", color = { 0.24, 0.85, 0.35 }, sound = "airhorn", sub = Safe(name) or "The crew splits the loot. Badly." })
    GTA:Cutscene("The Heist", "Starring: you. Special thanks: the healer.", 4)
    GTA:AddRespect(50)
    GTA:Confetti(4)
end)

GTA:RegisterEvent("ACHIEVEMENT_EARNED", function()
    if GTA:On("missions") then GTA:Toast("|cffffc428HUSTLER UNLOCKED|r\nYour mom would be so proud. Probably.", "cheat_activated") end
end)

---------------------------------------------------------------- money
local lastMoney, merchantOpen
GTA:OnLogin(function() lastMoney = GetMoney() end)

GTA:RegisterEvent("PLAYER_MONEY", function()
    local now = GetMoney()
    local diff = now - (lastMoney or now)
    lastMoney = now
    if not GTA:On("cash") then GTA:SetCash(now, false) return end
    GTA:SetCash(now, true)
    if diff > 0 then
        GTA:Stat("earned", diff)
        if not UnitAffectingCombat("player") and throttle("chaching", 1.5) then GTA:Sound("cha_ching") end
        if diff >= 10000 and throttle("bigscore", 30) then GTA:Sticker("burst_loot", nil, 0.8) end
    elseif diff < 0 and merchantOpen and throttle("spree", 90) then
        GTA:Banner({ texture = "shopping_spree", sound = "cha_ching", hold = 1.6 })
    end
end)

local SHOPS = {
    "|cffffc428ARROWS 'R' US|r\nNo refunds. No questions. No arrows for crossbows.",
    "|cffffc428CRAZY GOBLIN'S DISCOUNT WAREHOUSE|r\nPrices so low they're probably stolen. (They are.)",
    "|cffffc428VENDOR|r\nThis gentleman will buy your grey items and judge you silently.",
    "|cffffc428PAWN SHOP|r\nThat 'Broken Fang'? Priceless. Here's 3 copper.",
}
GTA:RegisterEvent("MERCHANT_SHOW", function()
    merchantOpen = true
    if GTA:On("mishaps") and throttle("shop", 120) then GTA:Toast(Pick(SHOPS)) end
end)
GTA:RegisterEvent("MERCHANT_CLOSED", function() merchantOpen = false end)
GTA:RegisterEvent("AUCTION_HOUSE_SHOW", function()
    if GTA:On("mishaps") and throttle("ah", 120) then GTA:Toast("|cffffc428AUCTION HOUSE|r\nLaundering money... please hold.") end
end)
GTA:RegisterEvent("BANKFRAME_OPENED", function()
    if GTA:On("mishaps") and throttle("bank", 120) then GTA:Toast("|cffffc428BANK JOB PLANNER|r\nVault: open. Guards: asleep. Your plan: deposit linen cloth.") end
end)
GTA:RegisterEvent("MAIL_SHOW", function()
    if GTA:On("mishaps") and throttle("mail", 120) then GTA:Toast("|cffffc428PACKAGE FOR YOU|r\nIt's ticking. Probably a clock. Probably.") end
end)

---------------------------------------------------------------- crime
local CRIMES = {
    "Disturbing the peace", "Loitering with intent", "Jaywalking into a mob",
    "Excessive spellcasting in a residential area", "Unlicensed fireball", "Assault with a deadly weapon (it's a stick)",
    "Resisting a rest", "Grand theft of experience points",
}

local function targetKind()
    if not UnitExists("target") then return nil end
    local name = Safe(UnitName("target"))
    local ctype = Safe(UnitCreatureType("target"))
    if Safe(UnitIsPlayer("target")) then return "player", name end
    if name and name:find("Guard") then return "guard", name end
    if ctype == "Critter" then return "critter", name end
    return "mob", name
end

GTA:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if not GTA:On("wanted") then return end
    local kind, name = targetKind()
    if kind == "guard" then
        GTA:AddWanted(2, "Assaulting an officer" .. (name and (" (" .. name .. ")") or ""))
    elseif kind == "critter" then
        GTA:Stat("critters")
        GTA:AddWanted(1, "Animal cruelty. That " .. (name or "critter") .. " had a family.")
    elseif kind == "player" then
        GTA:AddWanted(1, "Street fight")
    elseif math.random() < 0.15 then
        GTA:AddWanted(1, Pick(CRIMES))
    end
    if GTA:On("mishaps") and math.random() < 0.1 then GTA:Sticker(Pick({ "burst_kapow", "burst_bonk", "burst_crit" })) end
end)

GTA:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    if not GTA:On("wanted") or UnitAffectingCombat("player") then return end
    local kind = targetKind()
    if kind == "guard" and throttle("guardtarget", 60) then
        GTA:Toast("Officer, I can explain.")
    elseif kind == "critter" and throttle("crittertarget", 90) then
        GTA:Toast("Don't even think about it. That's a protected species.")
    end
end)

GTA:RegisterEvent("PLAYER_PVP_KILLS_CHANGED", function()
    GTA:AddWanted(2, "Homicide. Allegedly.")
end)

GTA:RegisterEvent("PLAYER_UPDATE_RESTING", function()
    if not IsResting() then return end
    if GTA:Wanted() > 0 then
        GTA:SetWanted(0)
        GTA:Toast("|cff5fe05fSAFEHOUSE|r\nThe cops never check inns. Heat cleared.")
    elseif GTA:On("mishaps") and throttle("rest", 300) then
        GTA:Toast("|cff5fe05fSAFEHOUSE|r\nLie low. Order the stew. Don't ask what's in it.")
    end
end)

---------------------------------------------------------------- social
local ASSAULT = { "slap", "spit", "rude", "poke", "chicken", "flex", "threat", "punch", "kick", "bonk", "taunt" }
local LOVE = { "kiss", "hug", "love", "flirt", "cuddle", "wink" }

GTA:RegisterEvent("CHAT_MSG_TEXT_EMOTE", function(msg, sender)
    msg, sender = Safe(msg), Safe(sender)
    if not (msg and sender) or not GTA:On("mishaps") then return end
    local me = UnitName("player")
    if sender == me or sender:match("^" .. me .. "%-") then return end
    local low = msg:lower()
    if not low:find(" you") then return end
    for _, v in ipairs(ASSAULT) do
        if low:find(v) then
            GTA:Sticker("burst_bonk", "bonk", 0.7)
            GTA:AddWanted(1, "Got assaulted by " .. sender .. ". You're somehow the one getting charged.")
            return
        end
    end
    for _, v in ipairs(LOVE) do
        if low:find(v) then
            GTA:AddWanted(1, "Public indecency with " .. sender .. ".")
            return
        end
    end
    if low:find("danc") then GTA:Toast(sender .. " challenged you to a dance-off. Society demands an answer.") end
end)

GTA:RegisterEvent("MIRROR_TIMER_START", function(timer)
    if not GTA:On("mishaps") then return end
    if timer == "BREATH" and throttle("breath", 60) then
        GTA:Sticker("burst_splash", "sploosh", 0.8)
        GTA:Toast("Sleeping with the fishes already? The boss said 'later'.")
    elseif timer == "EXHAUSTION" and throttle("fatigue", 60) then
        GTA:Toast("You're in the deep end, pal. Literally.")
    end
end)

GTA:RegisterEvent("DUEL_REQUESTED", function(name)
    if GTA:On("mishaps") then GTA:Toast((Safe(name) or "Someone") .. " wants to take this outside.", "record_scratch") end
end)
GTA:RegisterEvent("DUEL_FINISHED", function()
    if GTA:On("mishaps") then GTA:Banner({ text = "STREET FIGHT OVER", color = { 1, 1, 1 }, sound = "bonk", hold = 1.6 }) end
end)
GTA:RegisterEvent("GROUP_JOINED", function()
    if GTA:On("mishaps") and throttle("group", 60) then GTA:Toast("|cffffc428CREW ASSEMBLED|r\nNobody say 'heist' on comms.") end
end)
GTA:RegisterEvent("CHAT_MSG_SKILL", function()
    if GTA:On("mishaps") and throttle("skill", 300) then GTA:Toast("Skill increased. Your cardio, however, did not.") end
end)
GTA:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE", function()
    if GTA:On("mishaps") and throttle("rep", 300) then GTA:Toast("Gang rep up. The streets are talking. Mostly about your outfit.") end
end)
GTA:RegisterEvent("MAP_EXPLORATION_UPDATED", function()
    if GTA:On("mishaps") and throttle("explore", 30) then GTA:Toast("|cffffc428NEW TURF|r\nTag it before the Defias do.") end
end)

local LOOT_PREFIX = LOOT_ITEM_SELF and LOOT_ITEM_SELF:match("^(.-)%%s")
GTA:RegisterEvent("CHAT_MSG_LOOT", function(msg)
    msg = Safe(msg)
    if not msg or not GTA:On("mishaps") or not LOOT_PREFIX or msg:sub(1, #LOOT_PREFIX) ~= LOOT_PREFIX then return end
    if msg:find("|cffa335ee") or msg:find("|cffff8000") then
        GTA:Sticker("burst_loot", "airhorn", 0.9)
        GTA:Banner({ text = "SCORE!", color = { 0.64, 0.21, 0.93 }, sound = "cha_ching", hold = 1.5 })
        GTA:Confetti(3)
    elseif msg:find("|cff0070dd") and throttle("rare", 20) then
        GTA:Sticker("burst_loot", "cha_ching", 0.6)
    end
end)

-- AFK: wanted poster with your face on it.
local poster = CreateFrame("Frame", nil, UIParent)
poster:SetSize(256, 512)
poster:SetPoint("CENTER", 0, 40)
poster:SetScale(0.9)
poster:SetFrameStrata("DIALOG")
poster:Hide()
poster.face = poster:CreateTexture(nil, "BACKGROUND")
poster.face:SetPoint("TOPLEFT", 40, -120)
poster.face:SetSize(176, 176)
poster.frame = poster:CreateTexture(nil, "ARTWORK")
poster.frame:SetAllPoints()
poster.frame:SetTexture(GTA:Tex("poster_wanted"))
poster.name = poster:CreateFontString(nil, "OVERLAY")
poster.name:SetFont(GTA.FONT_BLOCK, 26, "")
poster.name:SetTextColor(0.35, 0.12, 0.08)
poster.name:SetPoint("TOP", 0, -298)
GTA:Movable(poster, "poster", function(f) f:Hide() end, function()
    SetPortraitTexture(poster.face, "player")
    poster.name:SetText("SHIFT-DRAG ME")
    GTA.TempShow(poster, 20, function() return UnitIsAFK("player") end)
end)

GTA:RegisterEvent("PLAYER_FLAGS_CHANGED", function(unit)
    if unit ~= "player" then return end
    if GTA:On("mishaps") and UnitIsAFK("player") then
        SetPortraitTexture(poster.face, "player")
        poster.name:SetText((UnitName("player") or "YOU"):upper())
        poster:Show()
        GTA:Toast("Napping in a getaway car. Zzz.")
    else
        poster:Hide()
    end
end)

---------------------------------------------------------------- travel
GTA:RegisterEvent("TAXIMAP_OPENED", function()
    if GTA:On("rides") and throttle("taxi", 60) then GTA:Toast("|cffffc428TAXI!|r\nNo, you can't drive. You know why.") end
end)
GTA:RegisterEvent("PLAYER_CONTROL_LOST", function()
    C_Timer.After(0.5, function()
        if GTA:On("rides") and UnitOnTaxi("player") then
            GTA:Banner({ text = "HIJACKED FLIGHT", color = { 0.16, 0.86, 1 }, sound = "vroom", sub = "The gryphon has not consented to this." })
        end
    end)
end)

local function activeMountName()
    if not (C_MountJournal and C_MountJournal.GetMountIDs) then return nil end
    for _, id in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, isActive = C_MountJournal.GetMountInfoByID(id)
        if isActive then return Safe(name) end
    end
end

local RIDE_FALLBACK = { "Rusty Kodo", "Questionable Horse", "Borrowed Wolf", "Mechanostrider (Stolen)", "Some Guy's Raptor" }
local RIDE_SUBS = { "Stolen. Obviously.", "Insured? Absolutely not.", "Previous owner: 'HEY!'", "Plates: L0OT3R", "Hot-wired in 3 seconds flat" }

local mounted
local function mountCheck()
    local now = IsMounted() and not UnitOnTaxi("player")
    if now == mounted then return end
    mounted = now
    GTA:ShowSpeedo(now)
    GTA:RadioOnMount(now)
    if now and GTA:On("rides") then
        local ok, name = pcall(activeMountName)
        name = (ok and name) or Pick(RIDE_FALLBACK)
        local last = name:match("(%S+)$") or name
        GTA:Stat("rides")
        GTA:RideCard(name:upper(), Pick({ "GRAND THEFT " .. last:upper(), Pick(RIDE_SUBS) }))
        GTA:Sound("vroom")
    end
end
GTA:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", mountCheck)
GTA:RegisterEvent("COMPANION_UPDATE", mountCheck)
GTA:OnLogin(function() mounted = IsMounted() GTA:ShowSpeedo(mounted) end)

---------------------------------------------------------------- districts
local TAGLINES = {
    ["Elwynn Forest"] = "Nice neighbourhood. Kobolds pay no rent.",
    ["Westfall"] = "Low rent. High murlocs. Bring your own scarecrow.",
    ["Redridge Mountains"] = "Gnolls run the docks. Don't ask about the docks.",
    ["Duskwood"] = "Property values: dead. So are the neighbours.",
    ["Stormwind City"] = "The big city. Pickpockets, nobles, same thing.",
    ["Goldshire"] = "What happens here stays in the server logs.",
    ["Dun Morogh"] = "Cold, armed and very short-tempered. Also short.",
    ["Ironforge"] = "Underground economy. Literally.",
    ["Loch Modan"] = "Dam good real estate.",
    ["Wetlands"] = "Bring boots. Bring two pairs.",
    ["Teldrassil"] = "Gated community. Very tall gate.",
    ["Darkshore"] = "Moody waterfront. Great for brooding.",
    ["Durotar"] = "Hot, dusty and full of very honest scorpions.",
    ["Orgrimmar"] = "Spiky architecture. Spikier residents.",
    ["The Barrens"] = "Ask about Mankrik's wife. Everyone else does.",
    ["Mulgore"] = "Free-range kodo. No questions asked.",
    ["Thunder Bluff"] = "Lifts are the only thing that works on time.",
    ["Tirisfal Glades"] = "Gated, dead and still complaining about HOA fees.",
    ["Undercity"] = "Sewer living with extra steps.",
    ["Silverpine Forest"] = "Werewolves, but make it a fixer-upper.",
    ["Hillsbrad Foothills"] = "Farmland. Murder farmland.",
    ["Stranglethorn Vale"] = "Tourist hotspot. Tiger hotspot. Hotspot.",
    ["Booty Bay"] = "Neutral territory. The sharks are not.",
    ["Ashenvale"] = "Lumber disputes, but with swords.",
    ["Stonetalon Mountains"] = "Venture Co. is 'renovating'.",
    ["Tanaris"] = "Sand. Pirates. More sand.",
    ["Gadgetzan"] = "Goblin capital of 'technically legal'.",
    ["Mount Hyjal"] = "Upscale. Very upscale. Mostly up.",
    ["Zephras Isle"] = "Island getaway. Getaway from what? Don't ask.",
    ["The Riverglades"] = "Waterfront with a view and a body count.",
    ["Shen'dralas"] = "Ancient, exclusive, and definitely judging your gear.",
}
local GENERIC = {
    "Where dreams go to get mugged.",
    "Fresh territory. Same old crimes.",
    "The locals look friendly. Suspicious.",
    "Rent is cheap. Find out why.",
    "Population: you and a lot of angry wildlife.",
}

local district = CreateFrame("Frame", nil, UIParent)
district:SetSize(1024, 256)
district:SetPoint("BOTTOMRIGHT", -20, 140)
district:SetScale(0.55)
district:SetFrameStrata("HIGH")
district:Hide()
local dbg = district:CreateTexture(nil, "BACKGROUND")
dbg:SetAllPoints()
dbg:SetTexture(GTA:Tex("card_district"))
district.name = district:CreateFontString(nil, "OVERLAY")
district.name:SetFont(GTA.FONT_TITLE, 110, "THICKOUTLINE")
district.name:SetPoint("RIGHT", -30, 20)
district.name:SetTextColor(1, 1, 1)
district.tag = district:CreateFontString(nil, "OVERLAY")
district.tag:SetFont(GTA.FONT_HAND, 34, "OUTLINE")
district.tag:SetPoint("TOPRIGHT", district.name, "BOTTOMRIGHT", 0, -6)
district.tag:SetTextColor(1, 0.77, 0.16)

local lastZone
GTA:Movable(district, "district", function(f) f:Hide() end, function()
    district.name:SetText(Safe(GetZoneText()) or "District")
    district.tag:SetText("Shift-drag me. Click to close.")
    GTA.TempShow(district)
end)

local function showDistrict(force)
    if not GTA:On("districts") then return end
    local zone = Safe(GetZoneText()) or ""
    if zone == "" or (zone == lastZone and not force) then return end
    lastZone = zone
    district.name:SetText(zone)
    district.tag:SetText(TAGLINES[zone] or Pick(GENERIC))
    district:Show()
    UIFrameFadeIn(district, 0.4, 0, 1)
    if district.timer then district.timer:Cancel() end
    district.timer = C_Timer.NewTimer(5, function() UIFrameFadeOut(district, 0.8, 1, 0) C_Timer.After(0.9, function() district:Hide() end) end)
end
GTA:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(1, showDistrict) end)
GTA:OnLogin(function() C_Timer.After(4, showDistrict) end)
GTA.ShowDistrict = showDistrict

---------------------------------------------------------------- stunts
local jumps = {}
if type(JumpOrAscendStart) == "function" then
    hooksecurefunc("JumpOrAscendStart", function()
        if not GTA:On("stunts") then return end
        local now = GetTime()
        table.insert(jumps, now)
        while jumps[1] and now - jumps[1] > 4 do table.remove(jumps, 1) end
        if #jumps >= 7 and throttle("stunt", 45) then
            wipe(jumps)
            GTA:Stat("stunts")
            GTA:Banner({ text = "INSANE STUNT BONUS!", color = { 1, 0.27, 0.67 }, sound = "airhorn", sub = "+$0. Nobody saw it." })
        end
    end)
end

---------------------------------------------------------------- stats + demo
GTA:Command("stats", "your criminal record", function()
    local s = GTA.db.stats
    GTA:Print("criminal record")
    print(string.format("  Respect: |cffffc428%d|r   Missions passed: %d   Times flattened: %d", s.respect, s.missions, s.deaths))
    print(string.format("  Grand theft rides: %d   Highest wanted level: %d   Critter crimes: %d", s.rides, s.maxWanted, s.critters))
    print(string.format("  Money earned: %s   Stunts: %d   Cheats used: %d", GTA.Commas(s.earned), s.stunts, s.cheats))
end)

GTA:Command("demo", "show off every gag once", function()
    local steps = {
        function() GTA:Banner({ texture = "logo_wordmark", sound = "airhorn", sub = "a parody. please don't sue." }) end,
        function() GTA:AddWanted(1, "Being in a demo") end,
        function() GTA:Banner({ texture = "mission_passed", sound = "mission_passed", sub = "Demo Mission   |cffffc428+5 RESPECT|r" }) GTA:Confetti(2) end,
        function() GTA:SetCash(GetMoney() + 123456, true) GTA:Sound("cha_ching") end,
        function() GTA:SetCash(GetMoney(), true) GTA:RideCard("QUESTIONABLE HORSE", "GRAND THEFT HORSE") GTA:Sound("vroom") end,
        function() showDistrict(true) end,
        function() GTA:PhoneText() end,
        function() GTA:Sticker("burst_kapow", "bonk") GTA:Sticker("burst_crit") end,
        function() GTA:AddWanted(2, "Jaywalking, but aggressively") end,
        function() GTA:Overlay("vignette_grey", 0.2, 0.2, 0.2, 0.55, 5) GTA:Banner({ texture = "death_flattened", sound = "death_sting", hold = 3 }) end,
        function() GTA:SetWanted(0) end,
    }
    for i, fn in ipairs(steps) do C_Timer.After((i - 1) * 3.2, fn) end
end)
