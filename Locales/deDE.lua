local L = _G.LibStub("AceLocale-3.0"):NewLocale("RecipesCollector", "deDE")
if not L then return end

L["Requires ([%w%s]+) %((%d+)%)"] = "Benötigt ([%w%s]+) %((%d+)%)"
