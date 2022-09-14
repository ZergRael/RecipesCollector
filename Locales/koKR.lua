local L = _G.LibStub("AceLocale-3.0"):NewLocale("RecipesCollector", "koKR")
if not L then return end

L["Requires ([%w%s]+) %((%d+)%)"] = "([%w%s]+) %((%d+)%) 필요"
