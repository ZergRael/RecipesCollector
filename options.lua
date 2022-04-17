local addonName = "RecipesCollector"
local _, addonTitle, addonNotes = _G.GetAddOnInfo(addonName)
local RC = _G.LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceConfig = _G.LibStub("AceConfig-3.0")
local AceConfigDialog = _G.LibStub("AceConfigDialog-3.0")

function RC:RegisterOptionsTable()
    AceConfig:RegisterOptionsTable(addonName, {
        name = addonName,
        descStyle = "inline",
        handler = RC,
        type = "group",
        args = {
            General = {
                order = 10,
                type = "group",
                name = L["Options"],
                args = {
                    intro = {
                        order = 0,
                        type = "description",
                        name = addonNotes,
                    },
                    general = {
                        order = 10,
                        type = "group",
                        name = L["General Settings"],
                        inline = true,
                        args = {
                            compactMode = {
                                order = 10,
                                type = "toggle",
                                name = L["Compact mode"],
                                get = function() return self.db.global.compactMode end,
                                set = function(_, val) self.db.global.compactMode = val end,
                            }
                        },
                    },
                    db = {
                        order = 20,
                        type = "group",
                        name = L["Database Settings"],
                        inline = true,
                        args = {
                            purgeTradeSkill = {
                                order = 80,
                                type = "select",
                                name = L["Delete a tradeskill profile"],
                                values = "ListProfiles",
                                set = function(_, val)
                                    RC:RemoveProfile(val)
                                    val = nil
                                end,
                            },
                        },
                    }
                },
            },
        }
    }, { "RC" })
    AceConfigDialog:AddToBlizOptions(addonName, nil, nil, "General")
end
