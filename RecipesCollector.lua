local addonName = "RecipesCollector"
local addonTitle = select(2, _G.GetAddOnInfo(addonName))
local addonVersion = _G.GetAddOnMetadata(addonName, "Version")
local RC = _G.LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceHook-3.0")
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local Recipes = _G.LibStub("LibRecipes-3.0")

-- Addon init
function RC:OnInitialize()
    -- Addon savedvariables database
    self.db = _G.LibStub("AceDB-3.0"):New(addonName, {
        -- profile = {
        -- },
        factionrealm = {
            numRecipesPerTradeskill = {},
            recipes = {},
        },
    })

    -- Addon session variables
    self.debounceRecipe = nil
    self.currentTradeSkill = nil

    -- Events register
    self:RegisterEvent("CRAFT_SHOW")
    self:RegisterEvent("CRAFT_UPDATE")
    self:RegisterEvent("TRADE_SKILL_SHOW")
    self:RegisterEvent("TRADE_SKILL_UPDATE")

    -- Hooks
    self:HookScript(_G.GameTooltip, "OnTooltipSetItem", "OnTooltipSetItem")

    -- Options init
    self:RegisterOptionsTable()
end

-- For some reason, enchanting seems to be the only craft profession
function RC:CRAFT_SHOW()
    -- self:Print("CRAFT_SHOW")
    self.currentTradeSkill = self:NormalizeProfessionName(_G.GetCraftDisplaySkillLine())
    -- self:Print(self.currentTradeSkill)

    local playerName = _G.UnitName("player")
    self:InitializeDBForPlayerIfNecessary(playerName, self.currentTradeSkill)
end

function RC:CRAFT_UPDATE()
    -- self:Print("CRAFT_UPDATE")

    local playerName = _G.UnitName("player")
    local numRecipes = _G:GetNumCrafts()
    if self:GetNumRecipesPerTradeskill(playerName, self.currentTradeSkill) >= numRecipes then
        -- self:Print("CRAFT_UPDATE: No changes in recipes, bail out")
        return
    end

    self.db.factionrealm.numRecipesPerTradeskill[self.currentTradeSkill][playerName] = numRecipes

    for idx = 1, numRecipes, 1 do
        local tradeSkillLink = _G.GetCraftItemLink(idx)
        local recipeId = tradeSkillLink:match("enchant:(%d+)|")
        if not _G.tContains(self.db.factionrealm.recipes[self.currentTradeSkill][playerName], recipeId) then
            _G.tinsert(self.db.factionrealm.recipes[self.currentTradeSkill][playerName], recipeId)
        end
    end
end

function RC:TRADE_SKILL_SHOW()
    -- self:Print("TRADE_SKILL_SHOW")
    self.currentTradeSkill = self:NormalizeProfessionName(_G.GetTradeSkillLine())
    -- self:Print(self.currentTradeSkill)

    local playerName = _G.UnitName("player")
    self:InitializeDBForPlayerIfNecessary(playerName, self.currentTradeSkill)
end

function RC:TRADE_SKILL_UPDATE()
    -- self:Print("TRADE_SKILL_UPDATE")
    -- self:Print(_G.GetTradeSkillLine())

    local playerName = _G.UnitName("player")
    local numRecipes = _G:GetNumTradeSkills()
    if self:GetNumRecipesPerTradeskill(playerName, self.currentTradeSkill) >= numRecipes then
        -- self:Print("TRADE_SKILL_UPDATE: No changes in recipes, bail out")
        return
    end

    self.db.factionrealm.numRecipesPerTradeskill[self.currentTradeSkill][playerName] = numRecipes

    for idx = 1, numRecipes, 1 do
        local skillName, skillType = _G.GetTradeSkillInfo(idx);
        if skillType ~= "header" and skillType ~= nil then
            local tradeSkillLink = _G.GetTradeSkillItemLink(idx)
            local recipeId = tradeSkillLink:match("item:(%d+):")
            if not _G.tContains(self.db.factionrealm.recipes[self.currentTradeSkill][playerName], recipeId) then
                _G.tinsert(self.db.factionrealm.recipes[self.currentTradeSkill][playerName], recipeId)
            end
        end
    end
end

function RC:InitializeDBForPlayerIfNecessary(playerName, tradeSkillName)
    if self.db.factionrealm.numRecipesPerTradeskill[tradeSkillName] == nil then
        self.db.factionrealm.numRecipesPerTradeskill[tradeSkillName] = {}
    end
    if self.db.factionrealm.numRecipesPerTradeskill[tradeSkillName][playerName] == nil then
        self.db.factionrealm.numRecipesPerTradeskill[tradeSkillName][playerName] = 0
    end
    if self.db.factionrealm.recipes[tradeSkillName] == nil then
        self.db.factionrealm.recipes[tradeSkillName] = {}
    end
    if self.db.factionrealm.recipes[tradeSkillName][playerName] == nil then
        self.db.factionrealm.recipes[tradeSkillName][playerName] = {}
    end
end

function RC:GetNumRecipesPerTradeskill(playerName, tradeSkillName)
    return self.db.factionrealm.numRecipesPerTradeskill[tradeSkillName][playerName]
end

function RC:OnTooltipSetItem(tooltip)
    local _, itemLink = tooltip:GetItem()
    if not itemLink then
        return
    end

    local recipeID, _, _, _, _, classID, subclassID = _G.GetItemInfoInstant(itemLink)
    if classID ~= _G.LE_ITEM_CLASS_RECIPE then
        return
    end

    local spellId, itemId = Recipes:GetRecipeInfo(recipeID)
    if not spellId then
        return
    end

    -- Recipes tooltip are called twice except for enchanting
    if subclassID ~= _G.LE_ITEM_RECIPE_ENCHANTING and self.debounceRecipe ~= recipeID then
        self.debounceRecipe = recipeID
        return
    end
    self.debounceRecipe = nil
    -- self:Print(itemLink, recipeId, spellId, itemId)

    local profession = nil
    for i = 1, _G.GameTooltip:NumLines() do
        profession = _G["GameTooltipTextLeft" .. i]:GetText():match(L["Requires ([%w%s]+) %((%d+)%)"])
        if profession then
            break
        end
    end

    if not profession then
        -- self:Print("Probably not a recipe")
        return
    end

    local normalizedProfession = self:NormalizeProfessionName(profession)
    if not self.db.factionrealm.recipes[normalizedProfession] then
        -- self:Print("Missing profession in DB")
        return
    end

    local lines = {}
    for charName, recipes in pairs(self.db.factionrealm.recipes[normalizedProfession]) do
        local check = _G.tContains(recipes, tostring(itemId or spellId)) and " |cFF00FF00Y|r" or " |cFFFF0000N|r"
        _G.tinsert(lines, charName .. check)
    end

    if #lines == 0 then
        return
    end

    tooltip:AddLine(" ")
    for _, line in ipairs(lines) do
        tooltip:AddLine(line)
    end
end

function RC:NormalizeProfessionName(str)
    -- TODO: Check if necessary to manipulate professions names
    -- maybe to remove specs ?
    return str
end

function RC:ListProfiles()
    local profiles = {}

    for tradeSkillName, chars in pairs(self.db.factionrealm.recipes) do
        for charName, _ in pairs(chars) do
            profiles[charName .. "_" .. tradeSkillName] = charName .. " - " .. tradeSkillName
        end
    end

    return profiles
end

function RC:RemoveProfile(profile)
    local charName, tradeSkillName = _G.strsplit("_", profile)
    self.db.factionrealm.recipes[tradeSkillName][charName] = nil
    self.db.factionrealm.numRecipesPerTradeskill[tradeSkillName][charName] = nil
    self:Print(_G.format(L["Deleted profile %s - %s"], charName, tradeSkillName))
end
