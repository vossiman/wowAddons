local _, GTA = ...
local Pick, Safe = GTA.Pick, GTA.Safe

local HEADLINES = {
    "LOCAL PALADIN BUBBLES, HEARTHSTONES; POLICE BAFFLED",
    "MURLOC ELECTED MAYOR OF WESTFALL. CAMPAIGN SLOGAN: 'MRGLGLGL'",
    "STUDY: 9 OUT OF 10 KOBOLDS PREFER CANDLES. 10TH KOBOLD 'JUST WANTS TO TALK'",
    "GOLDSHIRE INN FAILS HEALTH INSPECTION FOR 4,000TH YEAR RUNNING",
    "MAN WHO SAID 'IT'S JUST ONE MORE QUEST' REPORTED MISSING SINCE TUESDAY",
    "GNOMES DEMAND TALLER COUNTERS AT AUCTION HOUSE. AUCTIONEER: 'WHO SAID THAT?'",
    "HUNTER'S PET CAUGHT DOING ALL THE WORK, AGAIN",
    "ROGUE WANTED FOR QUESTIONING. NOBODY CAN SEE HIM",
    "BOAR POPULATION STABLE DESPITE 2 MILLION ADVENTURERS NEEDING LIVERS",
    "EXPERTS WARN: STANDING IN FIRE STILL BAD",
    "WARLOCK SUMMONS GROUP, GROUP DOES NOT CLICK PORTAL. HUMANITY DOOMED",
    "STORMWIND GUARDS CONFIRM: 'WE SAW NOTHING'. ALSO 'WE NEVER SEE ANYTHING'",
    "LOCAL SHAMAN FORGETS TOTEM, WALKS BACK 400 YARDS IN SHAME",
    "ECONOMISTS STUMPED AS LINEN CLOTH PRICES OUTPERFORM GOLD",
    "BREAKING: SOMEONE IN TRADE CHAT WAS RIGHT ABOUT SOMETHING. INVESTIGATION ONGOING",
    "DRUID TURNS INTO BEAR TO AVOID TAXES. IRS: 'WE'LL ALLOW IT'",
    "MAILBOX DANCERS UNIONIZE. DEMANDS INCLUDE BIGGER MAILBOXES",
    "FLIGHT MASTER DENIES ALL KNOWLEDGE OF 'THE SCENIC ROUTE'",
    "QUESTIONABLE MAN IN DUSKWOOD STILL SELLING 'TOTALLY NORMAL' MEAT",
    "WEATHER: CHANCE OF RAIN 40%. CHANCE OF GANK 90%",
}

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

local PEDESTRIANS = { "Some Guy", "Angry Peasant", "A Gnome (Probably)", "Lady With Groceries", "Retired Footman" }
local INSULTS = {
    "Hey! I'm walkin' here!",
    "Watch it, buddy!",
    "Nice outfit. Did you loot it off a skeleton?",
    "You again? I'm calling the guards.",
    "Is that a mount or a cry for help?",
}

local function moving()
    local ok, speed = pcall(GetUnitSpeed, "player")
    speed = ok and Safe(speed) or 0
    return speed > 0, speed
end

-- Each event: fn, and optional ok() condition. Weights decide how often it shows up.
local EVENTS = {
    { w = 4, fn = function() GTA:News(Pick(HEADLINES)) end },
    { w = 3, fn = function()
        GTA:PoliceLights(4)
        GTA:Sound("police_chirp")
        if GTA:Wanted() > 0 then
            GTA:AddWanted(1, "A patrol spotted you. Running was a bad idea.")
        else
            GTA:Toast("A patrol drives by. Act natural. NATURAL.")
        end
    end },
    { w = 3, fn = function()
        GTA:Sound("slide_whistle")
        C_Timer.After(0.9, function()
            GTA:Sticker("splat", "sploosh", 0.9)
            GTA:Toast("A gryphon has relieved itself on you. |cffff4040-1 DIGNITY|r")
        end)
    end },
    { w = 2, fn = function()
        GTA:SetCash(0, true)
        GTA:Sound("record_scratch")
        GTA:Toast("|cffff4040TAX AUDIT|r\nThe Stormwind Revenue Service is reviewing your 'loot'.")
        C_Timer.After(5, function()
            GTA:SetCash(GetMoney(), true)
            GTA:Toast("Audit complete. You're clean. For now.", "cha_ching")
        end)
    end },
    { w = 3, ok = function() return moving() end, fn = function()
        local _, speed = moving()
        local mph = math.floor(speed * 10)
        GTA:Sound("shutter")
        GTA:Flash()
        GTA:Toast(string.format("|cffffc428SPEED CAMERA|r\n%d murlocs/h in a 30 zone. Fine: %s.", mph, GTA.Commas(mph * 7)))
    end },
    { w = 3, fn = function()
        GTA:Sound("honk")
        local who = Safe(UnitExists("target") and not UnitIsPlayer("target") and UnitName("target")) or Pick(PEDESTRIANS)
        GTA:Toast("|cffffc428" .. tostring(who) .. ":|r " .. Pick(INSULTS))
    end },
    { w = 2, fn = function()
        GTA:Banner({ text = "THIS ZONE IS SPONSORED BY", color = { 1, 1, 1 }, sub = Pick(SPONSORS), hold = 3.5, sound = "text_ping" })
    end },
    { w = 2, fn = function() GTA:Toast(Pick(TIPS)) end },
    { w = 2, ok = function() return GTA:On("wanted") end, fn = function()
        local before = GTA:Wanted()
        GTA:SetWanted(math.min(5, before + 2), "Matches description of suspect: 'has arms, legs, a face'.")
        C_Timer.After(5, function()
            GTA:SetWanted(before)
            GTA:Toast("Oh. Wrong person. Carry on, citizen.", "star_down")
        end)
    end },
    { w = 2, fn = function() GTA:Toast("|cffffc428ACHIEVEMENT UNLOCKED|r\n" .. Pick(ACHIEVEMENTS), "cheat_activated") end },
    { w = 2, ok = function() return GTA:On("phone") end, fn = function() GTA:PhoneText() end },
    { w = 1, fn = function()
        GTA:Sound("airhorn")
        for i = 1, 4 do C_Timer.After(i * 0.3, function() GTA:Sticker(Pick({ "burst_kapow", "burst_bonk", "burst_oof", "burst_crit" })) end) end
        GTA:Confetti(3)
    end },
    { w = 1, fn = function()
        GTA:Sound("record_scratch")
        GTA:Banner({ text = "WHAT A LEGEND", color = { 1, 0.77, 0.16 }, sub = "Nobody knows why. Least of all you." })
    end },
    { w = 1, fn = function()
        GTA:Toast("Celebrity sighting! A level 60 in full epics just walked past. You pretend not to care.")
    end },
}

local function fire(force)
    if not GTA:On("chaos") and not force then return end
    if not force and (UnitAffectingCombat("player") or UnitIsDeadOrGhost("player")) then return end
    local pool, total = {}, 0
    for _, e in ipairs(EVENTS) do
        if not e.ok or e.ok() then
            table.insert(pool, e)
            total = total + e.w
        end
    end
    local r = math.random() * total
    for _, e in ipairs(pool) do
        r = r - e.w
        if r <= 0 then return e.fn() end
    end
end

local RANGES = { { 300, 600 }, { 100, 240 }, { 35, 90 } }

local function schedule()
    local level = GTA.db.chaos or 2
    local r = RANGES[level] or RANGES[2]
    local wait = math.random(r[1], r[2])
    if GTA.IsNight and GTA:IsNight() then wait = wait * 0.6 end
    C_Timer.After(wait, function()
        if (GTA.db.chaos or 2) > 0 then fire() end
        schedule()
    end)
end
GTA:OnLogin(schedule)

-- Small in-combat chaos: comic stickers only, never text.
GTA:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if GTA:On("chaos") and (GTA.db.chaos or 2) >= 2 and math.random() < 0.2 then
        C_Timer.After(math.random() * 3, function()
            GTA:Sticker(Pick({ "burst_kapow", "burst_bonk", "burst_oof", "burst_crit" }), Pick({ "bonk", "boing", "honk" }))
        end)
    end
end)

GTA:Command("random", "make something random happen right now", function() fire(true) end)
GTA:Command("chaos", "chaos level 0-3 (0 = off, 3 = unhinged)", function(arg)
    local n = tonumber(arg)
    if n and n >= 0 and n <= 3 then
        GTA.db.chaos = math.floor(n)
        GTA:Print("chaos level " .. GTA.db.chaos .. ({ [0] = " (boring)", " (chill)", " (default)", " (unhinged)" })[GTA.db.chaos])
    else
        GTA:Print("chaos level is " .. (GTA.db.chaos or 2) .. ". Use /gta chaos 0-3.")
    end
end)
