local L = _G.LibStub("AceLocale-3.0"):NewLocale("RecipesCollector", "zhTW")
if not L then return end

L["Requires ([%w%s]+) %((%d+)%)"] = "需要 ([%w%s]+) %((%d+)%)"
