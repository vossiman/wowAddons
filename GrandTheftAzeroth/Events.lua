local _, GTA = ...
local Pick, Safe = GTA.Pick, GTA.Safe

local lastFired = {}
local function throttle(key, seconds)
    local now = GetTime()
    if lastFired[key] and now - lastFired[key] < seconds then return false end
    lastFired[key] = now
    return true
end

local function calm()
    return not UnitAffectingCombat("player") and not UnitIsDeadOrGhost("player")
end

---------------------------------------------------------------- combat hits (UNIT_COMBAT; values may be hidden in combat, then nothing shows)
-- "you" if you're in this fight, "group" if the target is fighting someone in your group, nil otherwise.
function GTA:TargetFight()
    if not UnitAffectingCombat("player") or not UnitExists("target") then return nil end
    if Safe(UnitIsUnit("targettarget", "player")) == true or Safe(UnitIsUnit("targettarget", "pet")) == true then return "you" end
    local threat = Safe(UnitThreatSituation("player", "target"))
    if threat ~= nil then return "you" end
    if IsInGroup() and UnitExists("targettarget") then
        local inGroup = Safe(UnitInParty("targettarget")) or Safe(UnitInRaid("targettarget"))
        if inGroup then return "group" end
    end
    return nil
end

local YOU_AVOIDED = { DODGE = "NOPE", PARRY = "DENIED", BLOCK = "NOT TODAY" }
local THEY_AVOIDED = { DODGE = "DODGED", PARRY = "PARRIED", BLOCK = "BLOCKED" }

GTA:RegisterEvent("UNIT_COMBAT", function(unit, action, flag)
    if not GTA:On("combat") then return end
    unit, action, flag = Safe(unit), Safe(action), Safe(flag)
    if not (unit and action) then return end
    if unit == "player" then
        if action == "WOUND" and flag == "CRITICAL" and throttle("crittaken", 4) then
            GTA:TextSticker("OOF", "cyan", true, 0.5)
        elseif YOU_AVOIDED[action] and throttle("avoid", 5) then
            GTA:TextSticker(YOU_AVOIDED[action], "green", true, 0.45)
        elseif action == "MISS" and throttle("missedyou", 6) then
            GTA:TextSticker("TOO SLOW", "green", true, 0.4)
        end
    elseif unit == "target" then
        -- Hits on your target come from anyone. Only count them when it's your fight.
        local who = GTA:TargetFight()
        if who == "you" then
            if action == "WOUND" and flag == "CRITICAL" and throttle("critdealt", 3) then
                GTA:TextSticker("CRIT!", "red", true, 0.5)
            elseif THEY_AVOIDED[action] and throttle("denied", 5) then
                GTA:TextSticker(THEY_AVOIDED[action], "white", true, 0.45)
            elseif action == "MISS" and throttle("youmissed", 6) then
                GTA:TextSticker("WHIFF", "white", true, 0.4)
            end
        elseif who == "group" and action == "WOUND" and flag == "CRITICAL" and throttle("critgroup", 6) then
            GTA:TextSticker("CREW CRIT", "white", "side", 0.32)
        end
    end
end)

---------------------------------------------------------------- fights
local fightStart
GTA:RegisterEvent("PLAYER_REGEN_DISABLED", function() fightStart = GetTime() end)
GTA:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    local dur = fightStart and GetTime() - fightStart or 0
    fightStart = nil
    C_Timer.After(0.3, function()
        if UnitIsDeadOrGhost("player") or not GTA:On("mishaps") then return end
        local hp, max = Safe(UnitHealth("player")), Safe(UnitHealthMax("player"))
        if hp and max and max > 0 and hp / max < 0.15 and throttle("walkedoff", 120) then
            GTA:Banner({ text = "WALKED IT OFF", color = { 1, 0.3, 0.3 }, sub = string.format("%d%% health. Totally fine. Not a scratch.", math.floor(hp / max * 100)), hold = 2 })
        elseif dur > 60 and throttle("longfight", 300) then
            GTA:Toast(string.format("That fight took %d seconds. The cops got bored and went home.", dur))
            if GTA:Wanted() > 0 then GTA:SetWanted(GTA:Wanted() - 1) end
        end
    end)
end)

GTA:OnKill(function(name)
    if not GTA:On("mishaps") or not UnitExists("target") then return end
    if Safe(UnitName("target")) ~= name or Safe(UnitIsDead("target")) ~= true then return end
    local theirs, mine = Safe(UnitLevel("target")), UnitLevel("player") or 0
    if theirs and (theirs == -1 or theirs >= mine + 3) and throttle("upset", 60) then
        GTA:Banner({ text = "UPSET OF THE YEAR", color = { 1, 0.77, 0.16 }, sub = name .. (theirs == -1 and " (level ??)" or (" (level " .. theirs .. ")")) .. " went down. Nobody had money on you.", hold = 2.2 })
        GTA:AddRespect(15)
    end
end)

GTA:RegisterEvent("PLAYER_DEAD", function()
    if not IsInGroup() then return end
    C_Timer.After(1.5, function()
        local raid = IsInRaid()
        local n = GetNumGroupMembers()
        for i = 1, raid and n or (n - 1) do
            local u = raid and ("raid" .. i) or ("party" .. i)
            if UnitExists(u) and Safe(UnitIsDeadOrGhost(u)) ~= true then return end
        end
        if throttle("wipe", 300) then
            GTA:News("ENTIRE CREW FLATTENED. THE HEIST WENT SIDEWAYS. WITNESSES DESCRIBE IT AS 'A PULL'.")
            GTA:EventText("wipe", 0.7)
        end
    end)
end)

GTA:RegisterEvent("UNIT_HEALTH", function(unit)
    if unit ~= "pet" or not GTA:On("mishaps") then return end
    if Safe(UnitIsDead("pet")) == true and throttle("petdead", 60) then
        GTA:Toast("|cffff4040YOUR ASSOCIATE GOT WHACKED|r\nFeed them, revive them, and never speak of this.", nil, 5, true)
    end
end)

---------------------------------------------------------------- money and loot
local merchantOpen, sales, interpol = false, 0, false
local lastMoney
GTA:OnLogin(function() lastMoney = GetMoney() end)
GTA:RegisterEvent("MERCHANT_SHOW", function() merchantOpen = true end)
GTA:RegisterEvent("MERCHANT_CLOSED", function() merchantOpen = false end)
GTA:RegisterEvent("PLAYER_MONEY", function()
    local now = GetMoney()
    local gain = now - (lastMoney or now)
    lastMoney = now
    if gain <= 0 or not merchantOpen or not GTA:On("mishaps") then return end
    sales = sales + 1
    if throttle("fence", 120) then GTA:TextSticker("FENCED", "green", true, 0.5) end
    if sales >= 10 and not interpol then
        interpol = true
        GTA:News("INTERPOL INTERESTED IN LOCAL ADVENTURER WHO SOLD " .. sales .. " 'TOTALLY FOUND' ITEMS TO ONE VENDOR")
    end
end)

GTA:RegisterEvent("CHAT_MSG_MONEY", function()
    if GTA:On("mishaps") and math.random() < 0.15 and throttle("pickpocket", 300) then
        GTA:Toast("Pickpocketing the deceased. Classy.")
    end
end)

-- What you were doing right before a loot window decides what it means.
local lastCast, lastCastAt = nil, 0
local GATHER = { ["Herb Gathering"] = true, ["Mining"] = true, ["Herbalism"] = true }
GTA:RegisterEvent("LOOT_OPENED", function()
    if not GTA:On("mishaps") then return end
    local recent = GetTime() - lastCastAt < 8 and lastCast or nil
    if recent and GATHER[recent] then
        if throttle("gather", 90) then GTA:TextSticker("PRODUCT ACQUIRED", "green", true, 0.5) end
        return
    end
    if recent == "Fishing" then
        if throttle("fish", 120) then GTA:Toast("Sleeping with the fishes. Except this one. This one's dinner.") end
        return
    end
    local ok, guid = pcall(GetLootSourceInfo, 1)
    guid = ok and Safe(guid) or nil
    if guid and (guid:find("^GameObject") or guid:find("^Item")) and throttle("safe", 20) then
        GTA:TextSticker("SAFE CRACKED", "gold", true, 0.6)
    end
end)

if C_AuctionHouse then
    for _, fn in ipairs({ "PlaceBid", "ConfirmCommoditiesPurchase" }) do
        if C_AuctionHouse[fn] then
            hooksecurefunc(C_AuctionHouse, fn, function()
                if GTA:On("mishaps") and throttle("blackmarket", 60) then GTA:Toast("|cffffc428BLACK MARKET|r\nPurchase complete. No receipts, no questions.") end
            end)
        end
    end
end

if type(RepairAllItems) == "function" then
    hooksecurefunc("RepairAllItems", function()
        if GTA:On("mishaps") and throttle("repair", 60) then GTA:Toast("Car's fixed. The mechanic charged double and kept your sunglasses.") end
    end)
end

---------------------------------------------------------------- your own spells: eating, hearthstone, gathering
local FOOD = { Food = true, Drink = true, Refreshment = true, ["Food & Drink"] = true }
GTA:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" then return end
    spellID = Safe(spellID)
    if not spellID then return end
    local ok, name = pcall(C_Spell and C_Spell.GetSpellName or GetSpellInfo, spellID)
    name = ok and Safe(name) or nil
    if not name then return end
    lastCast, lastCastAt = name, GetTime()
    if FOOD[name] and GTA:On("mishaps") and throttle("lunch", 300) then
        GTA:Toast("Lunch break. Crime can wait. Crime always waits.")
    elseif name:find("Hearthstone") and C_Spell and C_Spell.GetSpellCooldown then
        C_Timer.After(2, function()
            local okc, cd = pcall(C_Spell.GetSpellCooldown, spellID)
            if not okc or type(cd) ~= "table" then return end
            local start, duration = Safe(cd.startTime), Safe(cd.duration)
            if start and duration and duration > 60 then
                C_Timer.After(start + duration - GetTime() + 1, function()
                    if GTA:On("turf") then GTA:Toast("Your getaway rock is ready again. Hearthstone off cooldown.") end
                end)
            end
        end)
    end
end)

---------------------------------------------------------------- movement: falls, swims, joyrides, loitering
local fallStart, swimStart, mountStart, joyrideDone, idleStart = nil, nil, nil, false, nil
local idleBird, idleCops, idleAch = false, false, false
local wasMountedSwim = false

local mover = CreateFrame("Frame")
local acc = 0
mover:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.2 then return end
    acc = 0
    if not GTA.db or not GTA.db.enabled or UnitIsDeadOrGhost("player") then return end
    local now = GetTime()

    -- Falls (no fall-damage event exists, so time the drop).
    if IsFalling() and not IsFlying() then
        fallStart = fallStart or now
    elseif fallStart then
        local drop = now - fallStart
        fallStart = nil
        if drop >= 1.6 and GTA:On("mishaps") and throttle("fall", 30) then
            if IsSwimming() then
                GTA:Sticker("burst_splash", nil, 0.7)
            else
                GTA:TextSticker("SPLAT", "red", true, 0.6)
                GTA:Toast("That's gonna leave a mark.", nil, 3, true)
            end
        end
    end

    -- Swimming and driving into lakes.
    local swimming = IsSwimming()
    if swimming then
        swimStart = swimStart or now
        if now - swimStart > 60 and GTA:On("mishaps") and throttle("coastguard", 600) then
            GTA:Toast("You've been in the water a full minute. The Coast Guard has been called.")
        end
    else
        swimStart = nil
    end
    local mountedSwim = swimming and IsMounted()
    if mountedSwim and not wasMountedSwim and GTA:On("rides") and throttle("lake", 300) then
        GTA:Sticker("burst_splash", nil, 0.8)
        GTA:Toast("You drove into the lake. Classic.")
    end
    wasMountedSwim = mountedSwim

    -- Joyrides.
    if IsMounted() and not UnitOnTaxi("player") then
        mountStart = mountStart or now
        if not joyrideDone and now - mountStart > 180 and GTA:On("rides") then
            joyrideDone = true
            GTA:Toast("|cffffc428JOYRIDE BONUS|r\nThree minutes behind the wheel. +5 respect.")
            GTA:AddRespect(5)
        end
    else
        mountStart, joyrideDone = nil, false
    end

    -- Standing around.
    local ok, speed = pcall(GetUnitSpeed, "player")
    speed = ok and Safe(speed) or 1
    if speed == 0 and calm() and not UnitIsAFK("player") then
        idleStart = idleStart or now
        local idle = now - idleStart
        if not idleBird and idle > 90 and not IsIndoors() and not IsResting() and GTA:On("mishaps") then
            idleBird = true
            if math.random() < 0.4 and throttle("bird", 900) then GTA:Bird() end
        end
        if not idleCops and idle > 120 and IsResting() and GTA.calmFactor and GTA.calmFactor ~= 1 and GTA:On("wanted") then
            idleCops = true
            if throttle("loiter", 600) then GTA:AddWanted(1, "Loitering downtown. The cops have noticed you standing there.") end
        end
        if not idleAch and idle > 180 and GTA:On("mishaps") then
            idleAch = true
            if throttle("idleach", 1800) then GTA:FakeAchievement("Stood still for 3 minutes. Inspiring.") end
        end
    else
        idleStart, idleBird, idleCops, idleAch = nil, false, false, false
    end
end)

---------------------------------------------------------------- social
GTA:RegisterEvent("INSPECT_READY", function()
    if GTA:On("mishaps") and throttle("inspect", 300) then GTA:Toast("Checking out the competition. Their gear is better. Sorry.") end
end)
GTA:RegisterEvent("TRADE_SHOW", function()
    if GTA:On("mishaps") and throttle("trade", 120) then GTA:Toast("Shady handoff in progress. Don't count it in public.") end
end)
GTA:RegisterEvent("GUILD_INVITE_REQUEST", function(inviter, guild)
    if GTA:On("mishaps") then GTA:Toast("|cffffc428THE FAMILY WANTS YOU|r\n" .. (Safe(guild) or "A guild") .. " is making you an offer you can't refuse.", nil, 6, true) end
end)
GTA:RegisterEvent("PARTY_INVITE_REQUEST", function(name)
    if GTA:On("mishaps") then GTA:Toast("|cffffc428JOB OFFER|r\n" .. (Safe(name) or "Someone") .. " wants you on the crew.", nil, 5, true) end
end)
GTA:RegisterEvent("CHAT_MSG_WHISPER", function(_, sender)
    sender = Safe(sender)
    if not sender or IsInInstance() or not GTA:On("phone") or not throttle("whisper", 120) then return end
    GTA:PhoneText("Burner phone", "New message from " .. sender:gsub("%-.*", "") .. ". Read it in chat. Then delete it.")
end)

if type(DoEmote) == "function" then
    hooksecurefunc("DoEmote", function(token)
        if type(token) ~= "string" or token:upper() ~= "DANCE" or not GTA:On("mishaps") or not throttle("dance", 60) then return end
        if GTA.RadioStation and GTA:RadioStation() ~= "OFF" then
            GTA:Toast("|cffffc428" .. GTA:RadioStation() .. "|r\nThis one goes out to the person dancing like that. In public.")
        else
            GTA:TextSticker("DANCE-OFF!", "pink", true, 0.5)
        end
    end)
end

---------------------------------------------------------------- character: drinking, rest, talents, spells, gear
local DRUNK = {}
for i = 2, 4 do if _G["DRUNK_MESSAGE_SELF" .. i] then DRUNK[_G["DRUNK_MESSAGE_SELF" .. i]] = true end end
GTA:RegisterEvent("CHAT_MSG_SYSTEM", function(msg)
    msg = Safe(msg)
    if not msg or not DRUNK[msg] or not GTA:On("wanted") or not throttle("drunk", 120) then return end
    if IsMounted() then
        GTA:AddWanted(2, "DUI. Riding a mount while that drunk. Classy.")
    else
        GTA:AddWanted(1, "Public intoxication.")
    end
end)

local function checkRested()
    local rest, max = Safe(GetXPExhaustion()), Safe(UnitXPMax("player"))
    if not (rest and max and max > 0) or rest < max * 1.5 then return end
    local today = date("%Y-%m-%d")
    if GTA.db.restedDay == today or not GTA:On("mishaps") then return end
    GTA.db.restedDay = today
    GTA:Toast("|cff5fe05fFULLY RESTED|r\nBatteries charged. Ready for a crime spree.")
end
GTA:RegisterEvent("UPDATE_EXHAUSTION", checkRested)
GTA:RegisterEvent("PLAYER_UPDATE_RESTING", checkRested)

GTA:RegisterEvent("CHARACTER_POINTS_CHANGED", function()
    local ok, pts = pcall(UnitCharacterPoints, "player")
    pts = ok and Safe(pts) or nil
    if pts and pts > 0 and GTA:On("missions") and throttle("talent", 30) then
        GTA:Toast("|cffffc428NEW TALENT POINT|r\nInvest in crime. It always pays.", nil, 4, true)
    end
end)

local loginAt = 0
GTA:OnLogin(function() loginAt = GetTime() end)
GTA:RegisterEvent("LEARNED_SPELL_IN_TAB", function(spellID)
    if GetTime() - loginAt < 10 or not GTA:On("missions") or not throttle("newspell", 5) then return end
    local ok, name = pcall(C_Spell and C_Spell.GetSpellName or GetSpellInfo, Safe(spellID))
    GTA:Toast("|cffffc428NEW WEAPON UNLOCKED|r\n" .. (ok and Safe(name) or "Something dangerous"))
end)
GTA:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
    if GetTime() - loginAt < 15 or UnitAffectingCombat("player") or not GTA:On("mishaps") then return end
    if throttle("threads", 60) then GTA:TextSticker("FRESH THREADS", "white", true, 0.5) end
end)

---------------------------------------------------------------- "previously on": a recap after a long break
-- A /reload (or a quick relog) keeps the same session; a real break starts a new one.
local RECAP = { "missions", "kills", "deaths", "rides", "respect" }
GTA:OnLogin(function()
    local last = GTA.db.lastSession
    if last and last.at and time() - last.at < 3600 and GTA.db.sessionBase then return end
    GTA.db.sessionBase = {}
    for _, k in ipairs(RECAP) do GTA.db.sessionBase[k] = GTA.db.stats[k] or 0 end
    if not last or not last.at then return end
    local bits = {}
    local function add(n, word) if n and n > 0 then table.insert(bits, n .. " " .. word) end end
    add(last.missions, "missions")
    add(last.kills, "kills")
    add(last.deaths, "deaths")
    add(last.rides, "stolen rides")
    add(last.respect, "respect")
    if #bits == 0 then return end
    C_Timer.After(8, function()
        GTA:Cutscene("Previously on Grand Theft Azeroth", table.concat(bits, "   "), 4)
    end)
end)
GTA:RegisterEvent("PLAYER_LOGOUT", function()
    local s, base, d = GTA.db.stats, GTA.db.sessionBase or {}, { at = time() }
    for _, k in ipairs(RECAP) do d[k] = (s[k] or 0) - (base[k] or 0) end
    GTA.db.lastSession = d
end)
