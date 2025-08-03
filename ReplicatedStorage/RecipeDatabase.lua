--[[
    RecipeDatabase.lua
    Blueprint-based crafting recipe database for the Roblox inventory system
    Contains all crafting recipes, upgrade paths, and synthesis formulas
]]

local ItemDatabase = require(script.Parent.ItemDatabase)
local RecipeDatabase = {}

-- Recipe Categories
RecipeDatabase.Categories = {
    WEAPON_CRAFTING = "WeaponCrafting",
    ARMOR_CRAFTING = "ArmorCrafting", 
    RING_CRAFTING = "RingCrafting",
    TOOL_CRAFTING = "ToolCrafting",
    UPGRADE_SYNTHESIS = "UpgradeSynthesis",
    MATERIAL_REFINING = "MaterialRefining"
}

-- Crafting Stations/Requirements
RecipeDatabase.CraftingStations = {
    BASIC_WORKBENCH = "BasicWorkbench",
    ADVANCED_FORGE = "AdvancedForge",
    ENHANCEMENT_TABLE = "EnhancementTable",
    SYNTHESIS_CHAMBER = "SynthesisChamber"
}

-- Base Recipe Template
local function createRecipe(id, name, category, station, output, ingredients, level, successRate, time)
    return {
        ID = id,
        Name = name,
        Category = category,
        CraftingStation = station,
        Output = output, -- {itemId = "item_id", quantity = 1}
        Ingredients = ingredients, -- {{itemId = "item_id", quantity = 1}, ...}
        RequiredLevel = level or 1,
        BaseSuccessRate = successRate or 100,
        CraftingTime = time or 5, -- seconds
        UnlockRequirements = {},
        Modifiers = {}
    }
end

-- Weapon Crafting Recipes
RecipeDatabase.WeaponRecipes = {
    ["basic_pistol_recipe"] = createRecipe(
        "basic_pistol_recipe",
        "Basic Pistol Blueprint",
        RecipeDatabase.Categories.WEAPON_CRAFTING,
        RecipeDatabase.CraftingStations.BASIC_WORKBENCH,
        {itemId = "basic_pistol", quantity = 1},
        {
            {itemId = "iron_ingot", quantity = 3},
            {itemId = "steel_ingot", quantity = 1}
        },
        5,
        95,
        10
    ),
    
    ["enhanced_rifle_recipe"] = createRecipe(
        "enhanced_rifle_recipe", 
        "Enhanced Rifle Blueprint",
        RecipeDatabase.Categories.WEAPON_CRAFTING,
        RecipeDatabase.CraftingStations.ADVANCED_FORGE,
        {itemId = "enhanced_rifle", quantity = 1},
        {
            {itemId = "steel_ingot", quantity = 5},
            {itemId = "titanium_ingot", quantity = 2},
            {itemId = "crystal_core", quantity = 1}
        },
        25,
        85,
        25
    ),
    
    ["elite_smg_recipe"] = createRecipe(
        "elite_smg_recipe",
        "Elite SMG Blueprint", 
        RecipeDatabase.Categories.WEAPON_CRAFTING,
        RecipeDatabase.CraftingStations.ADVANCED_FORGE,
        {itemId = "elite_smg", quantity = 1},
        {
            {itemId = "titanium_ingot", quantity = 4},
            {itemId = "mithril_ingot", quantity = 2},
            {itemId = "crystal_core", quantity = 2}
        },
        50,
        75,
        40
    )
}

-- Armor Crafting Recipes
RecipeDatabase.ArmorRecipes = {
    ["kevlar_vest_recipe"] = createRecipe(
        "kevlar_vest_recipe",
        "Kevlar Vest Blueprint",
        RecipeDatabase.Categories.ARMOR_CRAFTING,
        RecipeDatabase.CraftingStations.BASIC_WORKBENCH,
        {itemId = "kevlar_vest", quantity = 1},
        {
            {itemId = "iron_ingot", quantity = 4},
            {itemId = "steel_ingot", quantity = 2}
        },
        10,
        90,
        15
    ),
    
    ["tactical_armor_recipe"] = createRecipe(
        "tactical_armor_recipe",
        "Tactical Armor Blueprint",
        RecipeDatabase.Categories.ARMOR_CRAFTING,
        RecipeDatabase.CraftingStations.ADVANCED_FORGE,
        {itemId = "tactical_armor", quantity = 1},
        {
            {itemId = "steel_ingot", quantity = 6},
            {itemId = "titanium_ingot", quantity = 3},
            {itemId = "crystal_core", quantity = 1}
        },
        30,
        80,
        30
    ),
    
    ["elite_armor_recipe"] = createRecipe(
        "elite_armor_recipe",
        "Elite Armor Blueprint",
        RecipeDatabase.Categories.ARMOR_CRAFTING,
        RecipeDatabase.CraftingStations.ADVANCED_FORGE,
        {itemId = "elite_armor", quantity = 1},
        {
            {itemId = "titanium_ingot", quantity = 8},
            {itemId = "mithril_ingot", quantity = 4},
            {itemId = "adamantium_ingot", quantity = 2},
            {itemId = "crystal_core", quantity = 3}
        },
        60,
        70,
        60
    )
}

-- Ring Crafting Recipes
RecipeDatabase.RingRecipes = {
    ["health_ring_recipe"] = createRecipe(
        "health_ring_recipe",
        "Health Ring Blueprint",
        RecipeDatabase.Categories.RING_CRAFTING,
        RecipeDatabase.CraftingStations.ENHANCEMENT_TABLE,
        {itemId = "health_ring", quantity = 1},
        {
            {itemId = "steel_ingot", quantity = 2},
            {itemId = "crystal_core", quantity = 1}
        },
        15,
        85,
        20
    ),
    
    ["damage_ring_recipe"] = createRecipe(
        "damage_ring_recipe",
        "Damage Ring Blueprint", 
        RecipeDatabase.Categories.RING_CRAFTING,
        RecipeDatabase.CraftingStations.ENHANCEMENT_TABLE,
        {itemId = "damage_ring", quantity = 1},
        {
            {itemId = "titanium_ingot", quantity = 2},
            {itemId = "crystal_core", quantity = 1}
        },
        20,
        85,
        20
    ),
    
    ["legendary_ring_recipe"] = createRecipe(
        "legendary_ring_recipe",
        "Legendary Ring Blueprint",
        RecipeDatabase.Categories.RING_CRAFTING,
        RecipeDatabase.CraftingStations.SYNTHESIS_CHAMBER,
        {itemId = "legendary_ring", quantity = 1},
        {
            {itemId = "mithril_ingot", quantity = 5},
            {itemId = "adamantium_ingot", quantity = 3},
            {itemId = "crystal_core", quantity = 5}
        },
        80,
        50,
        120
    )
}

-- Material Refining Recipes  
RecipeDatabase.MaterialRecipes = {
    ["steel_refining"] = createRecipe(
        "steel_refining",
        "Steel Ingot Refining",
        RecipeDatabase.Categories.MATERIAL_REFINING,
        RecipeDatabase.CraftingStations.BASIC_WORKBENCH,
        {itemId = "steel_ingot", quantity = 1},
        {
            {itemId = "iron_ingot", quantity = 3}
        },
        1,
        100,
        5
    ),
    
    ["titanium_refining"] = createRecipe(
        "titanium_refining",
        "Titanium Ingot Refining",
        RecipeDatabase.Categories.MATERIAL_REFINING,
        RecipeDatabase.CraftingStations.ADVANCED_FORGE,
        {itemId = "titanium_ingot", quantity = 1},
        {
            {itemId = "steel_ingot", quantity = 4}
        },
        15,
        95,
        10
    ),
    
    ["mithril_refining"] = createRecipe(
        "mithril_refining", 
        "Mithril Ingot Refining",
        RecipeDatabase.Categories.MATERIAL_REFINING,
        RecipeDatabase.CraftingStations.SYNTHESIS_CHAMBER,
        {itemId = "mithril_ingot", quantity = 1},
        {
            {itemId = "titanium_ingot", quantity = 5},
            {itemId = "crystal_core", quantity = 1}
        },
        40,
        80,
        30
    ),
    
    ["adamantium_refining"] = createRecipe(
        "adamantium_refining",
        "Adamantium Ingot Refining",
        RecipeDatabase.Categories.MATERIAL_REFINING,
        RecipeDatabase.CraftingStations.SYNTHESIS_CHAMBER,
        {itemId = "adamantium_ingot", quantity = 1},
        {
            {itemId = "mithril_ingot", quantity = 3},
            {itemId = "crystal_core", quantity = 2}
        },
        70,
        60,
        60
    )
}

-- Synthesis/Upgrade Recipes (3x same level → 1x next level)
RecipeDatabase.SynthesisRecipes = {
    -- Weapon Enhancement Synthesis
    ["weapon_damage_synthesis"] = createRecipe(
        "weapon_damage_synthesis",
        "Weapon Damage Enhancement",
        RecipeDatabase.Categories.UPGRADE_SYNTHESIS,
        RecipeDatabase.CraftingStations.ENHANCEMENT_TABLE,
        {itemId = "damage_enhancement", quantity = 1},
        {
            {itemId = "basic_damage_mod", quantity = 3}
        },
        25,
        80,
        15
    ),
    
    ["weapon_ice_synthesis"] = createRecipe(
        "weapon_ice_synthesis",
        "Ice Damage Enhancement",
        RecipeDatabase.Categories.UPGRADE_SYNTHESIS,
        RecipeDatabase.CraftingStations.ENHANCEMENT_TABLE,
        {itemId = "ice_enhancement", quantity = 1},
        {
            {itemId = "basic_ice_mod", quantity = 3}
        },
        30,
        75,
        20
    ),
    
    ["weapon_fire_synthesis"] = createRecipe(
        "weapon_fire_synthesis",
        "Fire Damage Enhancement",
        RecipeDatabase.Categories.UPGRADE_SYNTHESIS,
        RecipeDatabase.CraftingStations.ENHANCEMENT_TABLE,
        {itemId = "fire_enhancement", quantity = 1},
        {
            {itemId = "basic_fire_mod", quantity = 3}
        },
        30,
        75,
        20
    ),
    
    -- Armor Enhancement Synthesis
    ["armor_health_synthesis"] = createRecipe(
        "armor_health_synthesis",
        "Health Enhancement",
        RecipeDatabase.Categories.UPGRADE_SYNTHESIS,
        RecipeDatabase.CraftingStations.ENHANCEMENT_TABLE,
        {itemId = "health_enhancement", quantity = 1},
        {
            {itemId = "basic_health_mod", quantity = 3}
        },
        20,
        85,
        15
    ),
    
    ["armor_speed_synthesis"] = createRecipe(
        "armor_speed_synthesis",
        "Speed Enhancement",
        RecipeDatabase.Categories.UPGRADE_SYNTHESIS,
        RecipeDatabase.CraftingStations.ENHANCEMENT_TABLE,
        {itemId = "speed_enhancement", quantity = 1},
        {
            {itemId = "basic_speed_mod", quantity = 3}
        },
        35,
        80,
        20
    )
}

-- Combine all recipes
RecipeDatabase.Recipes = {}
for category, recipes in pairs({
    RecipeDatabase.WeaponRecipes,
    RecipeDatabase.ArmorRecipes,
    RecipeDatabase.RingRecipes,
    RecipeDatabase.MaterialRecipes,
    RecipeDatabase.SynthesisRecipes
}) do
    for id, recipe in pairs(recipes) do
        RecipeDatabase.Recipes[id] = recipe
    end
end

-- Success Rate Modifiers
RecipeDatabase.LuckModifiers = {
    LUCKY_CHARM = 15, -- +15% success rate
    HIGH_SKILL = 10,  -- +10% for high crafting skill
    GANG_BONUS = 5,   -- +5% gang crafting bonus
    VIP_BONUS = 20    -- +20% VIP crafting bonus
}

-- Utility Functions
function RecipeDatabase:GetRecipe(recipeId)
    return self.Recipes[recipeId]
end

function RecipeDatabase:GetRecipesByCategory(category)
    local recipes = {}
    for id, recipe in pairs(self.Recipes) do
        if recipe.Category == category then
            recipes[id] = recipe
        end
    end
    return recipes
end

function RecipeDatabase:GetAvailableRecipes(playerLevel, unlockedRecipes)
    local available = {}
    for id, recipe in pairs(self.Recipes) do
        if playerLevel >= recipe.RequiredLevel then
            if not recipe.UnlockRequirements or #recipe.UnlockRequirements == 0 then
                available[id] = recipe
            elseif unlockedRecipes and unlockedRecipes[id] then
                available[id] = recipe
            end
        end
    end
    return available
end

function RecipeDatabase:CanCraft(recipeId, playerInventory, playerLevel)
    local recipe = self:GetRecipe(recipeId)
    if not recipe then return false end
    
    -- Check level requirement
    if playerLevel < recipe.RequiredLevel then return false end
    
    -- Check ingredients
    for _, ingredient in pairs(recipe.Ingredients) do
        local itemCount = playerInventory[ingredient.itemId] or 0
        if itemCount < ingredient.quantity then
            return false
        end
    end
    
    return true
end

function RecipeDatabase:CalculateSuccessRate(recipeId, modifiers)
    local recipe = self:GetRecipe(recipeId)
    if not recipe then return 0 end
    
    local successRate = recipe.BaseSuccessRate
    modifiers = modifiers or {}
    
    -- Apply luck modifiers
    for modifier, value in pairs(modifiers) do
        if self.LuckModifiers[modifier] then
            successRate = successRate + self.LuckModifiers[modifier]
        end
    end
    
    -- Cap at 100%
    return math.min(successRate, 100)
end

function RecipeDatabase:GetRequiredMaterials(recipeId, quantity)
    local recipe = self:GetRecipe(recipeId)
    if not recipe then return {} end
    
    local materials = {}
    for _, ingredient in pairs(recipe.Ingredients) do
        materials[ingredient.itemId] = (materials[ingredient.itemId] or 0) + (ingredient.quantity * quantity)
    end
    
    return materials
end

function RecipeDatabase:IsValidRecipe(recipeId)
    return self.Recipes[recipeId] ~= nil
end

return RecipeDatabase