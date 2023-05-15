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
            showOnCraftingSpells = true,
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

    -- Events register
    self:RegisterEvent("TRADE_SKILL_UPDATE")

    -- Hooks
    self:HookScript(_G.GameTooltip, "OnTooltipSetItem", "OnTooltipSetItem")

    -- Options init
    self:RegisterOptionsTable()
end

-- Tradeskill frame updated
function RC:TRADE_SKILL_UPDATE()
    local playerName = _G.UnitName("player")
    -- Event might have fired too early
    if not playerName then
        return
    end

    local numRecipes = _G:GetNumTradeSkills()
    local currentTradeSkill = _G.GetTradeSkillLine()
    self:InitializeDBForPlayerIfNecessary(playerName, _G.UnitClassBase("player"), currentTradeSkill)

    if self:GetNumRecipesPerTradeskill(playerName, currentTradeSkill) >= numRecipes then
        return
    end

    self.db.factionrealm.numRecipesPerTradeskill[currentTradeSkill][playerName] = numRecipes

    for idx = 1, numRecipes, 1 do
        local _, skillType = _G.GetTradeSkillInfo(idx);
        if skillType ~= "header" and skillType ~= nil then
            local tradeSkillLink = _G.GetTradeSkillItemLink(idx)
            local enchantLink = _G.GetTradeSkillRecipeLink(idx)
            local recipeId = tradeSkillLink and tradeSkillLink:match("item:(%d+):") or
                enchantLink:match("enchant:(%d+)|")

            if not _G.tContains(self.db.factionrealm.recipes[currentTradeSkill][playerName], recipeId) then
                _G.tinsert(self.db.factionrealm.recipes[currentTradeSkill][playerName], recipeId)
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

-- Tooltip hook, used to read recipes requirements or craft spell info
function RC:OnTooltipSetItem(tooltip)
    local _, itemLink = tooltip:GetItem()
    if itemLink then
        self:HandleItemTooltip(tooltip, itemLink)
        return
    end

    if not self.db.global.showOnCraftingSpells then
        return
    end

    local _, spellLink = tooltip:GetSpell()
    if spellLink then
        self:HandleSpellTooltip(tooltip, spellLink)
    end
end

-- Read recipe tooltip and append own lines
function RC:HandleItemTooltip(tooltip, itemLink)
    local recipeId, _, _, _, _, classID, subclassID = _G.GetItemInfoInstant(itemLink)
    if classID ~= _G.LE_ITEM_CLASS_RECIPE then
        return
    end

    local spellId, itemId = Recipes:GetRecipeInfo(recipeId)
    if not spellId then
        return
    end

    -- Recipes tooltip are called twice except for enchanting
    -- The second seems to be a better option as it will put text on the lower end of the tooltip
    if subclassID ~= _G.LE_ITEM_RECIPE_ENCHANTING and self.debounceRecipe ~= recipeId then
        self.debounceRecipe = recipeId
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
        local charSkillRank = self.db.factionrealm.professions[charName] and
            self.db.factionrealm.professions[charName][profession]

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

        if (not self.db.global.hideUnlearnable or (charSkillRank and charSkillRank >= tonumber(skillRank))) and
            not (self.db.global.hideAlreadyKnown and alreadyKnown) then
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

-- Read craft spell tooltip and append own lines
function RC:HandleSpellTooltip(tooltip, spellLink)
    local spellId = select(7, _G.GetSpellInfo(spellLink))
    if not spellId then
        return
    end

    local recipeId, itemId = Recipes:GetSpellInfo(spellId)
    if not recipeId then
        return
    end

    local profession = _G["GameTooltipTextLeft1"]:GetText():match("([%w%s]+)%s?:")
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
        local charSkillRank = self.db.factionrealm.professions[charName] and
            self.db.factionrealm.professions[charName][profession]

        local line = "|c" .. select(4, _G.GetClassColor(self.db.factionrealm.classes[charName])) .. charName .. "|r"
        if not compact and charSkillRank then
            line = line .. " |cFFAAAAAA(" .. charSkillRank .. ")|r"
        end
        if alreadyKnown then
            line = line .. " |cFF00FF00" .. (compact and _G.YES or _G.ITEM_SPELL_KNOWN) .. "|r"
        else
            line = line .. " |cFFDB8139" .. (compact and _G.NO or _G.UNKNOWN) .. "|r"
        end

        _G.tinsert(lines, line)
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
