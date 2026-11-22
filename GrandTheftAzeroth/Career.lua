local _, GTA = ...

local RANKS = {
    { 0, "Street Rat" },
    { 50, "Pickpocket" },
    { 150, "Hustler" },
    { 350, "Enforcer" },
    { 700, "Lieutenant" },
    { 1200, "Underboss" },
    { 2000, "Crime Boss" },
    { 3500, "Kingpin of Azeroth" },
    { 6000, "Legend of the Streets" },
}

function GTA:Rank(respect)
    respect = respect or self.db.stats.respect or 0
    local idx = 1
    for i, r in ipairs(RANKS) do
        if respect >= r[1] then idx = i end
    end
    local nextR = RANKS[idx + 1]
    return RANKS[idx][2], idx, nextR and nextR[1] or nil
end

-- Rank line at the bottom of the HUD.
local hud = GTA.hud
hud:SetHeight(118)
local badge = hud:CreateTexture(nil, "ARTWORK")
badge:SetSize(26, 26)
badge:SetTexture(GTA:Tex("respect"))
hud.rank = hud:CreateFontString(nil, "OVERLAY")
hud.rank:SetFont(GTA.FONT_BLOCK, 16, "OUTLINE")
hud.rank:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", 0, 2)
hud.rank:SetTextColor(1, 0.77, 0.16)
badge:SetPoint("RIGHT", hud.rank, "LEFT", -4, 0)

local function drawRank()
    local name, _, nextAt = GTA:Rank()
    local r = GTA.db.stats.respect or 0
    hud.rank:SetText(name:upper() .. "  |cffffffff" .. r .. (nextAt and ("/" .. nextAt) or "") .. " R|r")
end
GTA.DrawRank = drawRank

function GTA:AddRespect(n, why)
    if n <= 0 then return end
    local before = select(2, self:Rank())
    self:Stat("respect", n)
    drawRank()
    local name, after = self:Rank()
    if after > before then
        C_Timer.After(2.8, function()
            GTA:Cutscene("Promotion", "You are now: " .. name, 4)
            GTA:Banner({ text = "RANK UP!", color = { 1, 0.77, 0.16 }, sound = "level_up", sub = name:upper(), hold = 3, priority = true })
            GTA:Confetti(4)
        end)
    end
end

---------------------------------------------------------------- career achievements
local ACHIEVEMENTS = {
    { id = "ride1", stat = "rides", at = 1, name = "Learner's Permit", desc = "Stole your first ride." },
    { id = "ride10", stat = "rides", at = 10, name = "Grand Theft Kodo x10", desc = "Ten rides. Zero receipts." },
    { id = "ride50", stat = "rides", at = 50, name = "Chop Shop Owner", desc = "50 stolen rides." },
    { id = "death1", stat = "deaths", at = 1, name = "Speedrun to the Graveyard", desc = "Died for the first time." },
    { id = "death10", stat = "deaths", at = 10, name = "Frequent Flyer (Spirit Healer)", desc = "10 deaths." },
    { id = "death50", stat = "deaths", at = 50, name = "Died 50 Times. Legend.", desc = "The spirit healer knows your order." },
    { id = "mission10", stat = "missions", at = 10, name = "Errand Boy", desc = "10 missions passed." },
    { id = "mission100", stat = "missions", at = 100, name = "Professional Errand Boy", desc = "100 missions passed." },
    { id = "critter5", stat = "critters", at = 5, name = "PETA's Most Wanted", desc = "5 critter crimes." },
    { id = "wanted5", stat = "maxWanted", at = 5, name = "Five-Star General", desc = "Reached 5 wanted stars." },
    { id = "cheat5", stat = "cheats", at = 5, name = "Cheater Cheater", desc = "Used 5 cheat codes." },
    { id = "stunt3", stat = "stunts", at = 3, name = "Parkour Professional", desc = "3 insane stunts." },
    { id = "kill100", stat = "kills", at = 100, name = "Pest Control", desc = "100 kills." },
    { id = "kill1000", stat = "kills", at = 1000, name = "Azeroth's Problem", desc = "1,000 kills." },
    { id = "contract5", stat = "contracts", at = 5, name = "Hired Muscle", desc = "5 contracts done." },
    { id = "contract25", stat = "contracts", at = 25, name = "On Speed Dial", desc = "25 contracts done." },
    { id = "rampage1", stat = "rampages", at = 1, name = "Rampage!", desc = "First rampage." },
    { id = "rampage10", stat = "rampages", at = 10, name = "Anger Management Dropout", desc = "10 rampages." },
    { id = "money", stat = "earned", at = 1000000, name = "First Million", desc = "Earned $1,000,000 (100 gold)." },
    { id = "taxi10", stat = "taxis", at = 10, name = "Gryphon Loyalty Card", desc = "10 flight paths." },
    { id = "turf25", stat = "discoveries", at = 25, name = "Tourist With a Record", desc = "Discovered 25 areas." },
    { id = "turf100", stat = "discoveries", at = 100, name = "Owns the Map", desc = "Discovered 100 areas." },
    { id = "fits100", stat = "outfits", at = 100, name = "Fashion Criminal", desc = "Collected 100 new appearances." },
    { id = "whips3", stat = "mounts", at = 3, name = "Car Collector", desc = "Added 3 mounts to the garage." },
    { id = "crew5", stat = "pets", at = 5, name = "Small Crew, Big Dreams", desc = "Recruited 5 pets." },
}

GTA.ACHIEVEMENTS = ACHIEVEMENTS

function GTA:CheckAchievements(stat)
    if not self.db then return end
    self.db.achievements = self.db.achievements or {}
    local s = self.db.stats
    for _, a in ipairs(ACHIEVEMENTS) do
        if a.stat == stat and not self.db.achievements[a.id] and (s[a.stat] or 0) >= a.at then
            self.db.achievements[a.id] = date("%Y-%m-%d")
            self:Toast("|cffffc428CAREER ACHIEVEMENT|r\n" .. a.name .. " - " .. a.desc, "cheat_activated", 5)
            self:AddRespect(25)
        end
    end
end

GTA:Command("rank", "your criminal rank", function()
    local name, idx, nextAt = GTA:Rank()
    local r = GTA.db.stats.respect or 0
    GTA:Print("rank " .. idx .. "/" .. #RANKS .. ": |cffffc428" .. name .. "|r (" .. r .. " respect" .. (nextAt and (", next rank at " .. nextAt) or ", maxed out") .. ")")
end)

GTA:Command("achievements", "list career achievements", function()
    local got = GTA.db.achievements or {}
    local n = 0
    for _, a in ipairs(ACHIEVEMENTS) do
        if got[a.id] then n = n + 1 end
    end
    GTA:Print(n .. "/" .. #ACHIEVEMENTS .. " career achievements")
    for _, a in ipairs(ACHIEVEMENTS) do
        print(got[a.id] and ("  |cff5fe05f[x]|r " .. a.name .. " - " .. a.desc) or ("  |cff808080[ ] " .. a.name .. "|r"))
    end
end)

GTA:OnLogin(function()
    -- catch up on anything already earned before achievements existed
    for _, k in ipairs({ "rides", "deaths", "missions", "critters", "maxWanted", "cheats", "stunts", "earned" }) do GTA:CheckAchievements(k) end
    drawRank()
end)
