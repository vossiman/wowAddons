local _, GTA = ...

local CONTACTS = {
    { "Cousin Grizzlik", {
        "Hey cousin! Let's go bowling!",
        "Cousin! You want to go bowling? Or maybe just... bowling?",
        "Why you not answer? Bowling. Tonight. Bring ogre.",
    } },
    { "Mom", {
        "Did you eat? Real food. Not 'Conjured Muffin'.",
        "Your father says stop standing on the mailbox.",
        "I saw you on a WANTED poster. Your hair looked nice.",
    } },
    { "Lawyer (Goblin)", {
        "Technically 'looting' is a lifestyle, not a crime. 400g please.",
        "Plead not guilty. Also plead not murloc.",
        "Good news: charges dropped. Bad news: so was your loot.",
    } },
    { "Unknown Number", {
        "We've been trying to reach you about your mount's extended warranty.",
        "Congratulations! You won a free hearthstone cooldown reset! Click here.",
        "Hot singles in your zone! (They are Defias. Do not respond.)",
    } },
    { "Big Hoggen", {
        "Got a job for you. Bring 10 boar livers. Don't ask.",
        "The kodo is hot. Paint it. Sell it in Thousand Needles.",
        "Meet me behind the inn. Come alone. Bring snacks.",
    } },
    { "Quest Giver", {
        "Hey, it's me with the ! over my head. Got 5 minutes? It's about rats.",
        "You still have my quest. Just checking. No pressure. (Pressure.)",
        "New mission: kill 12 wolves. They have done nothing. Do it anyway.",
    } },
    { "Ex (Night Elf)", {
        "Saw you dancing on the mailbox. We're done. Again.",
        "Can I have my hoodie back? And my 10,000 years?",
    } },
    { "Taxi Dispatch", {
        "Gryphon #12 says you didn't tip. He knows where you live.",
        "Your wind rider is on strike. Union stuff.",
    } },
    { "Bank of Azeroth", {
        "Your account is overdrawn by 3 copper. Penalty: 4 copper.",
        "Suspicious activity detected: you bought 200 linen cloth. Explain.",
    } },
}

local phone = CreateFrame("Frame", nil, UIParent)
phone:SetSize(256, 512)
phone:SetScale(0.6)
phone:SetPoint("BOTTOMRIGHT", -60, 120)
phone:SetFrameStrata("HIGH")
phone:Hide()
local bg = phone:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture(GTA:Tex("phone"))
phone.from = phone:CreateFontString(nil, "OVERLAY")
phone.from:SetFont(GTA.FONT_BLOCK, 26, "OUTLINE")
phone.from:SetPoint("TOP", 0, -60)
phone.from:SetWidth(200)
phone.msg = phone:CreateFontString(nil, "OVERLAY")
phone.msg:SetFont(GTA.FONT_HAND, 22, "")
phone.msg:SetPoint("TOP", phone.from, "BOTTOM", 0, -24)
phone.msg:SetWidth(196)
phone.msg:SetJustifyH("LEFT")
phone.msg:SetTextColor(0.05, 0.05, 0.1)
phone.bubble = phone:CreateTexture(nil, "ARTWORK")
phone.bubble:SetColorTexture(1, 1, 1, 0.92)
phone.bubble:SetPoint("TOPLEFT", phone.msg, "TOPLEFT", -10, 10)
phone.bubble:SetPoint("BOTTOMRIGHT", phone.msg, "BOTTOMRIGHT", 10, -10)

phone:EnableMouse(true)
phone:SetScript("OnMouseDown", function(self) self:Hide() end)

function GTA:PhoneText(from, msg)
    if not self:On("phone") then return end
    local c = self.Pick(CONTACTS)
    from = from or c[1]
    msg = msg or self.Pick(c[2])
    phone.from:SetText(from)
    phone.msg:SetText(msg)
    phone:Show()
    UIFrameFadeIn(phone, 0.25, 0, 1)
    self:Sound("phone_ring")
    if phone.timer then phone.timer:Cancel() end
    phone.timer = C_Timer.NewTimer(9, function() UIFrameFadeOut(phone, 0.5, 1, 0) C_Timer.After(0.6, function() phone:Hide() end) end)
end

local function schedule()
    C_Timer.After(math.random(600, 1200), function()
        if GTA:On("phone") and not UnitAffectingCombat("player") and not IsInInstance() then GTA:PhoneText() end
        schedule()
    end)
end

GTA:OnLogin(function() C_Timer.After(math.random(90, 180), function()
    if GTA:On("phone") and not UnitAffectingCombat("player") then GTA:PhoneText() end
    schedule()
end) end)

GTA:Command("phone", "get a text right now", function() GTA:PhoneText() end)
