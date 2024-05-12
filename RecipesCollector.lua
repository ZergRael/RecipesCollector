local addonName = "RecipesCollector"
---@class RC : AceAddon, AceEvent-3.0, AceHook-3.0
local RC = _G.LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceHook-3.0")
---@class L : AceLocale-3.0
local L = _G.LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local Recipes = _G.LibStub("LibRecipes-3.0")

RC.IsEra = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_CLASSIC
RC.IsClassic = _G.WOW_PROJECT_ID == _G.WOW_PROJECT_CATACLYSM_CLASSIC

-- Addon init
function RC:OnInitialize()
    -- Addon savedvariables database
    self.db = _G.LibStub("AceDB-3.0"):New(addonName, {
        global = {
            compactMode = false,
            hideAlreadyKnown = false,
            hideUnlearnable = true,
            showOnCraftingSpells = true,
            showLastUpdate = false,
            hideHeader = false,
            firstRun = true,
        },
        factionrealm = {
            classes = {},
            professions = {},
            lastUpdate = {},
            numRecipesPerTradeskill = {},
            recipes = {},
        },
    })

    -- Addon session variables
    self.debounceRecipe = nil

    -- Events register
    ---@diagnostic disable-next-line: param-type-mismatch -- this event has been removed in retail
    self:RegisterEvent("TRADE_SKILL_UPDATE")

    -- Hooks
    ---@diagnostic disable-next-line: param-type-mismatch -- GameTooltip hookscript is not supported properly by luals
    self:HookScript(_G.GameTooltip, "OnTooltipSetItem", "OnTooltipSetItem")
    ---@diagnostic disable-next-line: param-type-mismatch -- GameTooltip hookscript is not supported properly by luals
    self:HookScript(_G.GameTooltip, "OnTooltipSetSpell", "OnTooltipSetSpell")

    -- Options init
    self:RegisterOptionsTable()

    if self.db.global.firstRun then
        self.db.global.firstRun = false
        print(addonName .. ": " .. L["firstrun.info"])
    end
end

-- Tradeskill frame updated
function RC:TRADE_SKILL_UPDATE()
    local playerName = _G.UnitName("player")
    -- Event might have fired too early
    if not playerName then
        return
    end

    ---@diagnostic disable-next-line: undefined-field -- this method has been removed in retail
    local numRecipes = _G:GetNumTradeSkills()
    ---@diagnostic disable-next-line: undefined-field -- this method has been removed in retail
    local currentTradeSkill = _G.GetTradeSkillLine()
    self:InitializeDBForPlayerIfNecessary(playerName, _G.UnitClassBase("player"), currentTradeSkill)

    if self:GetNumRecipesPerTradeskill(playerName, currentTradeSkill) >= numRecipes then
        return
    end

    self.db.factionrealm.numRecipesPerTradeskill[currentTradeSkill][playerName] = numRecipes

    for idx = 1, numRecipes, 1 do
        ---@diagnostic disable-next-line: undefined-field -- this method has been removed in retail
        local _, skillType = _G.GetTradeSkillInfo(idx);
        if skillType ~= "header" and skillType ~= nil then
            ---@diagnostic disable-next-line: undefined-field -- this method has been removed in retail
            local tradeSkillLink = _G.GetTradeSkillItemLink(idx)
            ---@diagnostic disable-next-line: undefined-field -- this method has been removed in retail
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
---@param playerName string
---@param playerClass string Locale independant player class
---@param tradeSkillName string
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
    if self.db.factionrealm.lastUpdate[playerName] == nil then
        self.db.factionrealm.lastUpdate[playerName] = {}
    end

    self.db.factionrealm.lastUpdate[playerName][tradeSkillName] = time()
    self.db.factionrealm.classes[playerName] = playerClass
    self.db.factionrealm.professions[playerName] = self:GetProfessionRanks()
end

-- Retrieve currently known recipes count
---@param playerName string
---@param tradeSkillName string
---@return integer
function RC:GetNumRecipesPerTradeskill(playerName, tradeSkillName)
    return self.db.factionrealm.numRecipesPerTradeskill[tradeSkillName][playerName]
end

-- Scan all skills and return professions related ones with skill rank
---@return table<string,integer>
function RC:GetProfessionRanks()
    local professionsNames = self.ProfessionNames[_G.GetLocale()]
    local skills = {}

    if self.IsEra then
        ---@diagnostic disable-next-line: undefined-field -- this method has been removed in retail
        local numSkills = _G.GetNumSkillLines();
        for idx = 1, numSkills, 1 do
            ---@diagnostic disable-next-line: undefined-field -- this method has been removed in retail
            local skillName, header, _, skillRank = _G.GetSkillLineInfo(idx);
            if not header then
                if _G.tContains(professionsNames, skillName) then
                    skills[skillName] = skillRank
                end
            end
        end
    elseif self.IsClassic then
        local professionsIndexes = { _G.GetProfessions() }
        for idx = 1, #professionsIndexes, 1 do
            if professionsIndexes[idx] ~= nil then
                local name, _, skillRank = _G.GetProfessionInfo(professionsIndexes[idx])
                skills[name] = skillRank
            end
        end
    end

    return skills
end

-- Tooltip hook, used to read recipes requirements or craft spell info
---@param tooltip GameTooltip
function RC:OnTooltipSetItem(tooltip)
    local _, itemLink = tooltip:GetItem()
    if itemLink then
        self:HandleItemTooltip(tooltip, itemLink)
    end
end

-- Tooltip hook, used to read recipes requirements or craft spell info
---@param tooltip GameTooltip
function RC:OnTooltipSetSpell(tooltip)
    if not self.db.global.showOnCraftingSpells then
        return
    end

    local _, spellId = tooltip:GetSpell()
    if spellId then
        self:HandleSpellTooltip(tooltip, spellId)
    end
end

-- Read recipe tooltip and append own lines
---@param tooltip GameTooltip
---@param itemLink string
function RC:HandleItemTooltip(tooltip, itemLink)
    local recipeId, _, _, _, _, classID, subclassID = _G.C_Item.GetItemInfoInstant(itemLink)
    if classID ~= _G.Enum.ItemClass.Recipe then
        return
    end

    ---@diagnostic disable-next-line: undefined-field -- this library is not known by luals
    local spellId, itemId = Recipes:GetRecipeInfo(recipeId)
    if not spellId then
        return
    end

    -- Recipes tooltip are called twice except for enchanting
    -- The second seems to be a better option as it will put text on the lower end of the tooltip
    if subclassID ~= _G.Enum.ItemRecipeSubclass.Enchanting and self.debounceRecipe ~= recipeId then
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
            line = line .. " |cFF00FF00" .. (compact and YES or ITEM_SPELL_KNOWN) .. "|r"
        else
            if charSkillRank and charSkillRank >= tonumber(skillRank) then
                line = line .. " |cFFDB8139" .. (compact and NO or UNKNOWN) .. "|r"
            else
                line = line .. " |cFFCC0000" .. (compact and "X" or SPELL_FAILED_LOW_CASTLEVEL) .. "|r"
            end
        end

        if not compact and self.db.global.showLastUpdate then
            local lastUpdate = self.db.factionrealm.lastUpdate[charName] and
                self.db.factionrealm.lastUpdate[charName][profession]
            local lastUpdateDaysAgo = lastUpdate and format(INT_GENERAL_DURATION_DAYS,
                floor(difftime(time(), self.db.factionrealm.lastUpdate[charName][profession]) / (24 * 60 * 60)))
            line = line .. " |cFF999999(" .. (lastUpdateDaysAgo or UNKNOWN) .. ")|r"
        end

        if (not self.db.global.hideUnlearnable or (charSkillRank and charSkillRank >= tonumber(skillRank))) and
            not (self.db.global.hideAlreadyKnown and alreadyKnown) then
            _G.tinsert(lines, line)
        end
    end

    self:AppendToTooltip(tooltip, lines)
end

-- Read craft spell tooltip and append own lines
---@param tooltip GameTooltip
---@param spellId integer
function RC:HandleSpellTooltip(tooltip, spellId)
    if not spellId then
        return
    end

    ---@diagnostic disable-next-line: undefined-field -- this library is not known by luals
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
            line = line .. " |cFF00FF00" .. (compact and YES or ITEM_SPELL_KNOWN) .. "|r"
        else
            line = line .. " |cFFDB8139" .. (compact and NO or UNKNOWN) .. "|r"
        end

        if not compact and self.db.global.showLastUpdate then
            local lastUpdate = self.db.factionrealm.lastUpdate[charName] and
                self.db.factionrealm.lastUpdate[charName][profession]
            local lastUpdateDaysAgo = lastUpdate and format(INT_GENERAL_DURATION_DAYS,
                floor(difftime(time(), self.db.factionrealm.lastUpdate[charName][profession]) / (24 * 60 * 60)))
            line = line .. " |cFF999999(" .. (lastUpdateDaysAgo or UNKNOWN) .. ")|r"
        end

        _G.tinsert(lines, line)
    end

    self:AppendToTooltip(tooltip, lines)
end

-- Append text to tooltip
---@param tooltip GameTooltip
---@param lines table<integer,string>
function RC:AppendToTooltip(tooltip, lines)
    if #lines == 0 then
        return
    end

    tooltip:AddLine(" ")
    if self.db.global.compactMode then
        tooltip:AddLine(_G.strjoin(' - ', _G.unpack(lines)))
    else
        if not self.db.global.hideHeader then
            tooltip:AddLine("|cFFAAAAAA" .. addonName .. "|r")
        end
        for _, line in ipairs(lines) do
            tooltip:AddLine(line)
        end
    end
end

-- List database profiles
---@return table<string,string>
function RC:ListProfiles()
    local profiles = {}

    for tradeSkillName, chars in pairs(self.db.factionrealm.recipes) do
        for charName, _ in pairs(chars) do
            local lastUpdate = self.db.factionrealm.lastUpdate[charName] and
                self.db.factionrealm.lastUpdate[charName][tradeSkillName]
            local lastUpdateDaysAgo = lastUpdate and format(INT_GENERAL_DURATION_DAYS,
                floor(difftime(time(), self.db.factionrealm.lastUpdate[charName][tradeSkillName]) / (24 * 60 * 60)))
            profiles[charName .. "_" .. tradeSkillName] = charName .. " - " .. tradeSkillName ..
                (lastUpdateDaysAgo and (" (" .. lastUpdateDaysAgo .. ")") or "")
        end
    end

    return profiles
end

-- Remove specific charname & tradeskill profile from database
---@param profile string Profile key from database
function RC:RemoveProfile(profile)
    local charName, tradeSkillName = _G.strsplit("_", profile)
    self.db.factionrealm.recipes[tradeSkillName][charName] = nil
    self.db.factionrealm.numRecipesPerTradeskill[tradeSkillName][charName] = nil
    print(addonName .. ": " .. _G.format(L["Deleted profile %s - %s"], charName, tradeSkillName))
end
