local addonName = "RecipesCollector"
local addonNotes = select(3, C_AddOns.GetAddOnInfo(addonName))
---@class RC : AceAddon
local RC = _G.LibStub("AceAddon-3.0"):GetAddon(addonName)
---@class L : AceLocale-3.0
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceConfig = _G.LibStub("AceConfig-3.0")
local AceConfigDialog = _G.LibStub("AceConfigDialog-3.0")

-- Generate options and include them in client Addons Options
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
                        args = {},
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
                                args = {},
                            },
                            hideAlreadyKnown = {
                                order = 20,
                                type = "toggle",
                                name = L["Hide if already known"],
                                get = function() return self.db.global.hideAlreadyKnown end,
                                set = function(_, val) self.db.global.hideAlreadyKnown = val end,
                                args = {},
                            },
                            hideUnlearnable = {
                                order = 30,
                                type = "toggle",
                                name = L["Hide if skill not high enough"],
                                get = function() return self.db.global.hideUnlearnable end,
                                set = function(_, val) self.db.global.hideUnlearnable = val end,
                                args = {},
                            },
                            showOnCraftingSpells = {
                                order = 40,
                                type = "toggle",
                                name = L["Add to linked tradeskill"],
                                get = function() return self.db.global.showOnCraftingSpells end,
                                set = function(_, val) self.db.global.showOnCraftingSpells = val end,
                                args = {},
                            },
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
                                args = {},
                            },
                        },
                    }
                },
            },
        }
    }, { "RC" })
    AceConfigDialog:AddToBlizOptions(addonName, nil, nil, "General")
end
