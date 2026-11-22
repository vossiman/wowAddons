local _, GTA = ...
local Pick, Safe = GTA.Pick, GTA.Safe

local lastFired = {}
local function throttle(key, seconds)
    local now = GetTime()
    if lastFired[key] and now - lastFired[key] < seconds then return false end
    lastFired[key] = now
    return true
end

local function on() return GTA:On("collect") end

local function spellName(id)
    local ok, name = pcall(C_Spell and C_Spell.GetSpellName or GetSpellInfo, id)
    return ok and Safe(name) or nil
end

-- Collects several hits that arrive together (trainers, first logins) into one message.
local function batcher(delay, flush)
    local items, timer = {}, nil
    return function(item)
        table.insert(items, item)
        if timer then return end
        timer = C_Timer.NewTimer(delay, function()
            timer = nil
            local list = items
            items = {}
            flush(list)
        end)
    end
end

---------------------------------------------------------------- new areas
local function pattern(fmt)
    if not fmt then return nil end
    local p = fmt:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%s", "(.-)", 1):gsub("%%d", "%%d+")
    return "^" .. p
end
local AREA_PATTERNS = { pattern(ERR_ZONE_EXPLORED_XP), pattern(ERR_ZONE_EXPLORED) }

local TAGS = {
    "Tag it before the Defias do.",
    "Nobody owns this block yet. Now you do.",
    "Spray-painted your name on the nearest rock.",
    "Real estate agents are already calling.",
    "The locals didn't invite you. You came anyway.",
}

GTA:RegisterEvent("UI_INFO_MESSAGE", function(_, msg)
    msg = Safe(msg)
    if not msg or not on() then return end
    for _, p in ipairs(AREA_PATTERNS) do
        local area = p and msg:match(p)
        if area then
            local n = GTA:Stat("discoveries")
            GTA:AddRespect(2)
            GTA:Banner({ text = "TURF DISCOVERED", color = { 1, 0.27, 0.67 }, sub = area:upper() .. "   " .. Pick(TAGS) .. "   (" .. n .. " found)", hold = 2.2 })
            return
        end
    end
end)

---------------------------------------------------------------- flight paths
GTA:RegisterEvent("CHAT_MSG_SYSTEM", function(msg)
    msg = Safe(msg)
    if msg and ERR_NEW_TAXIPATH and msg == ERR_NEW_TAXIPATH and on() then
        local n = GTA:Stat("flightpaths")
        GTA:AddRespect(3)
        GTA:Banner({ text = "EXPANDING OPERATIONS", color = { 0.16, 0.86, 1 }, sub = "New flight path. Safehouse network: " .. n .. " locations.", hold = 2 })
    end
end)

---------------------------------------------------------------- recipes
local recipes = batcher(2, function(list)
    GTA:Stat("recipes", #list)
    GTA:AddRespect(#list)
    if #list == 1 then
        GTA:Toast("|cffffc428NEW PRODUCT LINE|r\n" .. (list[1] or "Something cookable") .. ". The cook just got better.")
    else
        GTA:Toast("|cffffc428" .. #list .. " NEW PRODUCT LINES|r\nThe lab is expanding. The neighbours are concerned.")
    end
end)
GTA:RegisterEvent("NEW_RECIPE_LEARNED", function(recipeID)
    if on() then recipes(spellName(Safe(recipeID))) end
end)

---------------------------------------------------------------- pets, mounts, toys
local function petName(guid)
    if not (C_PetJournal and C_PetJournal.GetPetInfoByPetID) then return nil end
    local ok, _, customName, _, _, _, _, _, name = pcall(C_PetJournal.GetPetInfoByPetID, guid)
    return ok and (Safe(customName) or Safe(name)) or nil
end

local function newPet(name)
    if not on() or not throttle("pet", 2) then return end
    GTA:Stat("pets")
    GTA:AddRespect(10)
    GTA:Banner({ text = "NEW ASSOCIATE RECRUITED", color = { 0.24, 0.85, 0.35 }, sub = (name and name:upper() .. "   " or "") .. "Small, loyal, asks no questions.", hold = 2.2 })
end
GTA:RegisterEvent("NEW_PET_ADDED", function(guid) newPet(petName(Safe(guid))) end)
GTA:RegisterEvent("COMPANION_LEARNED", function() C_Timer.After(0.5, function() newPet(nil) end) end)

GTA:RegisterEvent("NEW_MOUNT_ADDED", function(mountID)
    if not on() then return end
    local name
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        local ok, n = pcall(C_MountJournal.GetMountInfoByID, Safe(mountID))
        name = ok and Safe(n) or nil
    end
    local n = GTA:Stat("mounts")
    GTA:AddRespect(25)
    GTA:Cutscene("New Whip", "Garage: " .. n .. " vehicles. Insured: none.", 3)
    GTA:Banner({ text = "NEW WHIP IN THE GARAGE", color = { 1, 0.77, 0.16 }, sub = (name or "SOMETHING FAST"):upper() .. "   No plates. No paperwork.", hold = 2.5, priority = true })
    GTA:Confetti(4)
end)

GTA:RegisterEvent("NEW_TOY_ADDED", function(itemID)
    if not on() then return end
    itemID = Safe(itemID)
    local name
    if itemID then
        local ok, n = pcall(C_Item and C_Item.GetItemNameByID or GetItemInfo, itemID)
        name = ok and Safe(n) or nil
    end
    GTA:Stat("toys")
    GTA:AddRespect(5)
    GTA:Toast("|cffffc428CONTRABAND ACQUIRED|r\n" .. (name or "A suspicious toy") .. ". Keep it in the trunk.")
end)

---------------------------------------------------------------- transmog: one sticker a minute, a running tally, milestones per day
local outfitsToday, outfitDay = 0, nil
GTA:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_ADDED", function()
    if not on() then return end
    local today = date("%Y-%m-%d")
    if outfitDay ~= today then outfitDay, outfitsToday = today, 0 end
    outfitsToday = outfitsToday + 1
    GTA:Stat("outfits")
    if outfitsToday == 10 or outfitsToday == 25 or outfitsToday == 50 or outfitsToday % 100 == 0 then
        GTA:Toast(string.format("|cffffc428WARDROBE|r\n%d new outfits stolen today. Wardrobe now worth %s.", outfitsToday, GTA.Commas((GTA.db.stats.outfits or 0) * 250)))
    elseif throttle("outfit", 60) then
        GTA:TextSticker("NEW FIT", "pink", true, 0.5)
    end
end)

---------------------------------------------------------------- titles and new skills (compare against what we saw before)
local function knownTitles()
    if not (GetNumTitles and IsTitleKnown) then return nil end
    local n = 0
    for i = 1, GetNumTitles() do
        local ok, known = pcall(IsTitleKnown, i)
        if ok and known then n = n + 1 end
    end
    return n
end

local titleCount
GTA:RegisterEvent("KNOWN_TITLES_UPDATE", function()
    local n = knownTitles()
    if not n then return end
    if titleCount and n > titleCount and on() then
        GTA:Stat("titles")
        GTA:AddRespect(15)
        GTA:Banner({ text = "STREET NAME EARNED", color = { 1, 0.77, 0.16 }, sub = "New title unlocked. Pick one that scares people.", hold = 2.2 })
    end
    titleCount = n
end)

local function skillNames()
    if not (GetNumSkillLines and GetSkillLineInfo) then return nil end
    local set = {}
    for i = 1, GetNumSkillLines() do
        local ok, name, isHeader = pcall(GetSkillLineInfo, i)
        if ok and name and not isHeader then set[name] = true end
    end
    return set
end

local skills
GTA:RegisterEvent("SKILL_LINES_CHANGED", function()
    local now = skillNames()
    if not now then return end
    if skills and on() then
        for name in pairs(now) do
            if not skills[name] and throttle("newskill:" .. name, 60) then
                GTA:Toast("|cffffc428NEW SKILL SET|r\n" .. name .. ". Resume updated.")
            end
        end
    end
    skills = now
end)

GTA:OnLogin(function()
    C_Timer.After(5, function()
        titleCount = knownTitles()
        skills = skillNames()
    end)
end)

---------------------------------------------------------------- what the phone's Collection app shows
local function liveCount(fn)
    local ok, a, b = pcall(fn)
    if not ok then return nil end
    return Safe(b) or Safe(a)
end

function GTA:CollectionLines()
    local s = self.db.stats
    local y = "|cffffc428"
    local mounts = C_MountJournal and C_MountJournal.GetNumMounts and liveCount(function()
        local n = 0
        for _, id in ipairs(C_MountJournal.GetMountIDs()) do
            local _, _, _, _, _, _, _, _, _, _, collected = C_MountJournal.GetMountInfoByID(id)
            if collected then n = n + 1 end
        end
        return n
    end)
    local pets = C_PetJournal and C_PetJournal.GetNumPets and liveCount(C_PetJournal.GetNumPets)
    local toys = C_ToyBox and C_ToyBox.GetNumLearnedDisplayedToys and liveCount(C_ToyBox.GetNumLearnedDisplayedToys)
    return {
        y .. "GARAGE|r  " .. (mounts or s.mounts or 0) .. " whips, worth " .. GTA.Commas((mounts or s.mounts or 0) * 85000),
        y .. "ASSOCIATES|r  " .. (pets or s.pets or 0) .. " pets on the payroll",
        y .. "CONTRABAND|r  " .. (toys or s.toys or 0) .. " toys",
        y .. "WARDROBE|r  " .. (s.outfits or 0) .. " new fits, worth " .. GTA.Commas((s.outfits or 0) * 250),
        "",
        y .. "TURF|r  " .. (s.discoveries or 0) .. " areas discovered",
        y .. "SAFEHOUSES|r  " .. (s.flightpaths or 0) .. " flight paths",
        y .. "PRODUCT LINES|r  " .. (s.recipes or 0) .. " recipes",
        y .. "STREET NAMES|r  " .. (s.titles or 0) .. " titles",
        "",
        "|cff999999Counts since you installed the addon; garage,\nassociates and contraband use your real collection.|r",
    }
end
