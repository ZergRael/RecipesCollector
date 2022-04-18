local addonName = "RecipesCollector"
local RC = _G.LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceHook-3.0")
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local Recipes = _G.LibStub("LibRecipes-3.0")

-- Addon init
function RC:OnInitialize()
    -- Addon savedvariables database
    self.db = _G.LibStub("AceDB-3.0"):New(addonName, {
        global = {
            compactMode = false,
            hideAlreadyKnown = false,
            hideUnlearnable = true,
        },
        factionrealm = {
            classes = {},
            professions = {},
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

-- Enchanting frame opened
function RC:CRAFT_SHOW()
    -- For some reason, enchanting seems to be the only "Craft" profession as opposed to "TradeSkill" professions
    self.currentTradeSkill = _G.GetCraftDisplaySkillLine()
    self:InitializeDBForPlayerIfNecessary(_G.UnitName("player"), _G.UnitClassBase("player"), self.currentTradeSkill)
end

-- Enchanting frame updated
function RC:CRAFT_UPDATE()
    local playerName = _G.UnitName("player")
    local numRecipes = _G:GetNumCrafts()
    if self:GetNumRecipesPerTradeskill(playerName, self.currentTradeSkill) >= numRecipes then
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

-- Crafting frame opened
function RC:TRADE_SKILL_SHOW()
    self.currentTradeSkill = _G.GetTradeSkillLine()

    self:InitializeDBForPlayerIfNecessary(_G.UnitName("player"), _G.UnitClassBase("player"), self.currentTradeSkill)
end

-- Crafting frame updated
function RC:TRADE_SKILL_UPDATE()
    local playerName = _G.UnitName("player")
    local numRecipes = _G:GetNumTradeSkills()
    if self:GetNumRecipesPerTradeskill(playerName, self.currentTradeSkill) >= numRecipes then
        return
    end

    self.db.factionrealm.numRecipesPerTradeskill[self.currentTradeSkill][playerName] = numRecipes

    for idx = 1, numRecipes, 1 do
        local _, skillType = _G.GetTradeSkillInfo(idx);
        if skillType ~= "header" and skillType ~= nil then
            local tradeSkillLink = _G.GetTradeSkillItemLink(idx)
            local recipeId = tradeSkillLink:match("item:(%d+):")
            if not _G.tContains(self.db.factionrealm.recipes[self.currentTradeSkill][playerName], recipeId) then
                _G.tinsert(self.db.factionrealm.recipes[self.currentTradeSkill][playerName], recipeId)
            end
        end
    end
end

-- Generate initial database structure for a character tradeskill
function RC:InitializeDBForPlayerIfNecessary(playerName, playerClass, tradeSkillName)
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

    self.db.factionrealm.classes[playerName] = playerClass
    self.db.factionrealm.professions[playerName] = self:GetAllSkills()
end

function RC:GetNumRecipesPerTradeskill(playerName, tradeSkillName)
    return self.db.factionrealm.numRecipesPerTradeskill[tradeSkillName][playerName]
end

-- Scan all skills and return professions related ones with skill rank
function RC:GetAllSkills()
    local professionsNames = self.ProfessionNames[_G.GetLocale()]
    local skills = {}
    local numSkills = _G.GetNumSkillLines();
    for idx = 1, numSkills, 1 do
        local skillName, header, _, skillRank = _G.GetSkillLineInfo(idx);
        if not header then
            if _G.tContains(professionsNames, skillName) then
                skills[skillName] = skillRank
            end
        end
    end

    return skills
end

-- Tooltip hook, used to read recipes requirements and append own lines
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
    -- The second seems to be a better option as it will put text on the lower end of the tooltip
    if subclassID ~= _G.LE_ITEM_RECIPE_ENCHANTING and self.debounceRecipe ~= recipeID then
        self.debounceRecipe = recipeID
        return
    end
    self.debounceRecipe = nil

    local profession, skillRank = nil, 1000
    for i = 1, _G.GameTooltip:NumLines() do
        profession, skillRank = _G["GameTooltipTextLeft" .. i]:GetText():match(L["Requires ([%w%s]+) %((%d+)%)"])
        if profession then
            break
        end
    end

    if not profession then
        return
    end

    if not self.db.factionrealm.recipes[profession] then
        return
    end

    local lines = {}
    local compact = self.db.global.compactMode
    for charName, recipes in pairs(self.db.factionrealm.recipes[profession]) do
        local alreadyKnown = _G.tContains(recipes, tostring(itemId or spellId))
        local charSkillRank = self.db.factionrealm.professions[charName] and self.db.factionrealm.professions[charName][profession]

        local line = "|c" .. select(4, _G.GetClassColor(self.db.factionrealm.classes[charName])) .. charName .. "|r"
        if not compact and charSkillRank then
            line = line .. " |cFFAAAAAA(" .. charSkillRank .. ")|r"
        end
        if alreadyKnown then
            line = line .. " |cFF00FF00" .. (compact and _G.YES or _G.ITEM_SPELL_KNOWN) .. "|r"
        else
            if charSkillRank and charSkillRank >= tonumber(skillRank) then
                line = line .. " |cFFDB8139" .. (compact and _G.NO or _G.UNKNOWN) .. "|r"
            else
                line = line .. " |cFFCC0000" .. (compact and "X" or _G.SPELL_FAILED_LOW_CASTLEVEL) .. "|r"
            end
        end

        if (not self.db.global.hideUnlearnable or (charSkillRank and charSkillRank >= tonumber(skillRank))) and not (self.db.global.hideAlreadyKnown and alreadyKnown) then
            _G.tinsert(lines, line)
        end
    end

    if #lines == 0 then
        return
    end

    tooltip:AddLine(" ")
    if compact then
        tooltip:AddLine(_G.strjoin(' - ', _G.unpack(lines)))
    else
        tooltip:AddLine("|cFFAAAAAA" .. addonName .. "|r")
        for _, line in ipairs(lines) do
            tooltip:AddLine(line)
        end
    end
end

-- List database profiles
function RC:ListProfiles()
    local profiles = {}

    for tradeSkillName, chars in pairs(self.db.factionrealm.recipes) do
        for charName, _ in pairs(chars) do
            profiles[charName .. "_" .. tradeSkillName] = charName .. " - " .. tradeSkillName
        end
    end

    return profiles
end

-- Remove specific charname & tradeskill profile from database
function RC:RemoveProfile(profile)
    local charName, tradeSkillName = _G.strsplit("_", profile)
    self.db.factionrealm.recipes[tradeSkillName][charName] = nil
    self.db.factionrealm.numRecipesPerTradeskill[tradeSkillName][charName] = nil
    print(addonName .. ": " .. _G.format(L["Deleted profile %s - %s"], charName, tradeSkillName))
end
