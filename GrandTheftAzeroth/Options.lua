local _, GTA = ...

function GTA:RegisterOptions()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local category = Settings.RegisterVerticalLayoutCategory("Grand Theft Azeroth")

    local function checkbox(variable, key, tbl, label, tooltip)
        local setting = Settings.RegisterAddOnSetting(category, variable, key, tbl, Settings.VarType.Boolean, label, Settings.Default.True)
        setting:SetValueChangedCallback(function() GTA:RefreshHud() end)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    checkbox("GTA_ENABLED", "enabled", self.db, "Enable Grand Theft Azeroth", "Master switch for every gag.")
    checkbox("GTA_SOUND", "sound", self.db, "Play sounds", "All addon sounds, including the radio.")
    local noisy = Settings.RegisterAddOnSetting(category, "GTA_ALL_SOUNDS", "allSounds", self.db, Settings.VarType.Boolean,
        "Sounds for every gag (noisy)", Settings.Default.False)
    Settings.CreateCheckbox(category, noisy, "Off: only deaths, missions, level-ups, heists, rampages and gang wars make noise. On: every pop-up, star and coin does too.")
    for _, g in ipairs(self.GAGS) do
        if self.db.gags[g.key] == nil then self.db.gags[g.key] = true end
        checkbox("GTA_GAG_" .. g.key:upper(), g.key, self.db.gags, g.label, g.desc)
    end

    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category
end

GTA:Command("options", "open the settings panel", function()
    if GTA.settingsCategory and Settings.OpenToCategory then
        Settings.OpenToCategory(GTA.settingsCategory:GetID())
    end
end)
