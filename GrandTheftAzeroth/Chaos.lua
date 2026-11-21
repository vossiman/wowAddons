local _, GTA = ...
local Pick, Safe = GTA.Pick, GTA.Safe

local TIPS = {
    "TIP: Murlocs cannot be reasoned with. Believe us, we tried.",
    "TIP: Hold down the jump key to look cool. It does nothing else.",
    "TIP: Vendors buy everything. Even your dignity. Especially your dignity.",
    "TIP: The guards can't arrest you if you never make eye contact.",
    "TIP: A hearthstone is just a getaway car with a 30 minute cooldown.",
    "TIP: If you can't find the quest item, it's in the last place you look. Obviously.",
    "TIP: Respect can't be bought. But it can be looted.",
}

local SPONSORS = {
    "GOBLIN ENERGY DRINK. NOW WITH 40% MORE KABOOM.",
    "THE GOLDSHIRE INN. NO REFUNDS. NO MEMORIES.",
    "HONEST GRIZZLIK'S USED KODOS. LOW MILEAGE*. (*IT WALKED)",
    "SHELL-B-GONE TURTLE WAX. FOR YOUR TURTLE MOUNT.",
    "BIG HOGGEN'S BAIL BONDS. WE'LL GET YOU OUT. EVENTUALLY.",
    "MURLOC SUSHI. ETHICALLY QUESTIONABLE. DELICIOUS.",
}

local ACHIEVEMENTS = {
    "Stood still for 3 seconds. Inspiring.",
    "Looked at the map. Did not read it.",
    "Walked past a quest giver without helping. Cold.",
    "Thought about vendoring that grey item. Did not.",
    "Existed in a zone. Legend.",
}

local INSULTS = {
    "Hey! I'm walkin' here!",
    "Watch it, buddy!",
    "Nice outfit. Did you loot it off a skeleton?",
    "You again? I'm calling the guards.",
    "Is that a mount or a cry for help?",
}

local function speedNow()
    local ok, speed = pcall(GetUnitSpeed, "player")
    return ok and Safe(speed) or 0
end

local lastFired = {}
local function throttle(key, seconds)
    local now = GetTime()
    if lastFired[key] and now - lastFired[key] < seconds then return false end
    lastFired[key] = now
    return true
end

local function calm()
    return GTA:On("chaos") and not UnitAffectingCombat("player") and not UnitIsDeadOrGhost("player")
end

---------------------------------------------------------------- street life, each one caused by something you did
function GTA:Patrol()
    self:PoliceLights(4)
    if self:Wanted() > 0 then
        self:AddWanted(1, "A patrol spotted you. Running was a bad idea.")
    else
        self:Toast("A patrol drives by. Act natural. NATURAL.")
    end
end

function GTA:Bird()
    self:Sticker("splat", nil, 0.9)
    self:Toast("A gryphon has relieved itself on you. |cffff4040-1 DIGNITY|r")
end

function GTA:Sponsor()
    self:Banner({ text = "THIS ZONE IS SPONSORED BY", color = { 1, 1, 1 }, sub = Pick(SPONSORS), hold = 3.5 })
end

function GTA:FakeAchievement(text)
    self:Toast("|cffffc428ACHIEVEMENT UNLOCKED|r\n" .. (text or Pick(ACHIEVEMENTS)))
end

-- Speed camera: 8 seconds flat out on a mount.
local fastFor = 0
C_Timer.NewTicker(1, function()
    if not IsMounted() or UnitOnTaxi("player") then fastFor = 0 return end
    local mph = speedNow() * 10
    fastFor = mph >= 110 and fastFor + 1 or 0
    if fastFor >= 8 and calm() and throttle("camera", 600) then
        fastFor = 0
        GTA:Flash()
        GTA:Toast(string.format("|cffffc428SPEED CAMERA|r\n%d murlocs/h in a 30 zone. Fine: %s.", mph, GTA.Commas(mph * 7)))
    end
end)

-- Targeting people out of combat.
GTA:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    if not calm() or not UnitExists("target") then return end
    local isPlayer = Safe(UnitIsPlayer("target"))
    local name = Safe(UnitName("target"))
    if isPlayer == true then
        local theirs, mine = Safe(UnitLevel("target")) or 0, UnitLevel("player") or 0
        if theirs >= mine + 15 and throttle("celebrity", 600) then
            GTA:Toast("Celebrity sighting! " .. (name or "Someone") .. " (level " .. theirs .. ") is right there. You pretend not to care.")
        end
        return
    end
    if not name then return end
    if name:find("Guard") and GTA:Wanted() == 0 and GTA:On("wanted") and math.random() < 0.25 and throttle("wrongguy", 600) then
        GTA:SetWanted(2, "Matches description of suspect: 'has arms, legs, a face'.")
        C_Timer.After(5, function()
            GTA:SetWanted(0)
            GTA:Toast("Oh. Wrong person. Carry on, citizen.")
        end)
    elseif Safe(UnitIsFriend("player", "target")) and Safe(UnitCreatureType("target")) == "Humanoid"
        and math.random() < 0.12 and throttle("insult", 180) then
        GTA:Toast("|cffffc428" .. name .. ":|r " .. Pick(INSULTS))
    end
end)

-- Big paydays get audited.
local lastMoney
GTA:OnLogin(function() lastMoney = GetMoney() end)
GTA:RegisterEvent("PLAYER_MONEY", function()
    local now = GetMoney()
    local gain = now - (lastMoney or now)
    lastMoney = now
    if gain >= 10000 and calm() and math.random() < 0.3 and throttle("audit", 1800) then
        C_Timer.After(2, function()
            GTA:SetCash(0, true)
            GTA:Toast("|cffff4040TAX AUDIT|r\nThat payday got noticed. The Stormwind Revenue Service is reviewing your 'loot'.")
            C_Timer.After(5, function()
                GTA:SetCash(GetMoney(), true)
                GTA:Toast("Audit complete. You're clean. For now.")
            end)
        end)
    end
end)

-- Loading screens get a tip.
GTA:RegisterEvent("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
    if isLogin or isReload then return end
    C_Timer.After(4, function() if calm() and math.random() < 0.5 then GTA:Toast(Pick(TIPS)) end end)
end)

-- Opening the map.
if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", function()
        if calm() and math.random() < 0.15 and throttle("map", 1800) then GTA:FakeAchievement("Looked at the map. Did not read it.") end
    end)
end

-- Three missions in five minutes.
local turnins = {}
GTA:RegisterEvent("QUEST_TURNED_IN", function()
    local now = GetTime()
    table.insert(turnins, now)
    while turnins[1] and now - turnins[1] > 300 do table.remove(turnins, 1) end
    if #turnins >= 3 and throttle("legend", 600) then
        wipe(turnins)
        C_Timer.After(4, function()
            GTA:Banner({ text = "WHAT A LEGEND", color = { 1, 0.77, 0.16 }, sub = "Three missions in five minutes. Nobody asked you to." })
        end)
    end
end)

---------------------------------------------------------------- breaking news: the one thing still on a timer
local RANGES = { { 600, 1200 }, { 240, 480 }, { 90, 180 } }

local function schedule()
    local r = RANGES[GTA.db.chaos or 2] or RANGES[2]
    local wait = math.random(r[1], r[2])
    if GTA.IsNight and GTA:IsNight() then wait = wait * 0.6 end
    C_Timer.After(wait, function()
        if (GTA.db.chaos or 2) > 0 and calm() then GTA:BreakingNews() end
        schedule()
    end)
end
GTA:OnLogin(schedule)

function GTA:Headline(text) if text then self:News(text) else self:BreakingNews() end end

GTA:Command("random", "breaking news right now", function() GTA:BreakingNews() end)
GTA:Command("chaos", "how often breaking news runs, 0-3 (0 = never)", function(arg)
    local n = tonumber(arg)
    if n and n >= 0 and n <= 3 then
        GTA.db.chaos = math.floor(n)
        GTA:Print("news level " .. GTA.db.chaos .. ({ [0] = " (no news)", " (rare)", " (default)", " (24-hour news)" })[GTA.db.chaos])
    else
        GTA:Print("news level is " .. (GTA.db.chaos or 2) .. ". Use /gta chaos 0-3.")
    end
end)
