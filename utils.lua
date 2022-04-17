local addonName = "RecipesCollector"
local RC = _G.LibStub("AceAddon-3.0"):GetAddon(addonName)

function RC:PrintArray(arr)
    for i, value in ipairs(arr) do
        self:Print(i, "=", value)
    end
end
