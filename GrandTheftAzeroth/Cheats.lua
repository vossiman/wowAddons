local _, GTA = ...

local function stamp(text)
    GTA:Sticker("stamp_cheat", "cheat_activated", 0.6)
    GTA:Stat("cheats")
    if text then GTA:Toast("|cffff4040CHEAT ACTIVATED|r\n" .. text, "cheat_activated") end
end

local CHEATS = {
    moremurlocs = function()
        stamp("Murloc density increased by 0%. They were already everywhere.")
        for i = 1, 6 do C_Timer.After(i * 0.25, function() GTA:Sticker("burst_splash", "sploosh") end) end
    end,
    moneyplz = function()
        stamp("Infinite money granted. (Visual only. The IRS of Stormwind is watching.)")
        GTA:SetCash(999999999, true)
        C_Timer.After(5, function() GTA:SetCash(GetMoney(), true) GTA:Sound("record_scratch") end)
    end,
    panic = function()
        stamp("You asked for this.")
        GTA:SetWanted(5, "Typing PANIC into a cheat box")
        GTA:Sound("siren")
    end,
    lawabiding = function()
        stamp("Records wiped. Your lawyer sends his regards.")
        GTA:SetWanted(0)
    end,
    godmode = function()
        GTA:Sound("record_scratch")
        GTA:Toast("|cffff4040ACCESS DENIED|r\nNice try. A Game Master is now reading this. Wave hello.")
    end,
    noclip = function()
        GTA:Sound("bonk")
        GTA:Toast("You walked into a wall. Confidently.")
    end,
    bigheadmode = function()
        stamp("Head size set to 1.0x. Turns out it was already big.")
    end,
    airhorn = function()
        GTA:Sound("airhorn")
        GTA:Sticker("burst_kapow")
    end,
    confetti = function()
        stamp()
        GTA:Confetti(6)
    end,
    partytime = function()
        stamp("Party time!")
        GTA:Confetti(6)
        GTA:Sound("airhorn")
        C_Timer.After(1, function() GTA:Sound("airhorn") end)
        for i = 1, 5 do C_Timer.After(i * 0.4, function() GTA:Sticker(GTA.Pick({ "burst_kapow", "burst_bonk", "burst_oof", "burst_crit", "burst_loot" })) end) end
    end,
    leeroy = function()
        stamp("Plan abandoned. Chicken acquired.")
        GTA:Banner({ text = "AT LEAST I HAVE CHICKEN", color = { 1, 0.6, 0.2 }, sound = "airhorn" })
    end,
}

GTA.CHEAT_NAMES = {}
for k in pairs(CHEATS) do table.insert(GTA.CHEAT_NAMES, k) end
table.sort(GTA.CHEAT_NAMES)

function GTA:TryCheat(code)
    local fn = CHEATS[code:lower()]
    if not fn then return false end
    GTA:UserSounds(7)
    fn()
    return true
end

GTA:Command("cheats", "list cheat codes (spoilers!)", function()
    local names = {}
    for k in pairs(CHEATS) do table.insert(names, k:upper()) end
    table.sort(names)
    GTA:Print("cheat codes: " .. table.concat(names, ", ") .. "   (use /gta CODE)")
end)
