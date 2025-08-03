-- RecipeDatabase.lua
-- Manages all crafting recipes and requirements

local RecipeDatabase = {}

-- Recipe definitions
RecipeDatabase.Recipes = {
	["iron_sword_blueprint"] = {
		id = "iron_sword_blueprint",
		name = "Iron Sword",
		resultItem = "iron_sword",
		resultQuantity = 1,
		ingredients = {
			{
				itemId = "iron_ingot",
				quantity = 2,
				slot = 1 -- Blueprint specifies which material slot this goes in
			},
			{
				itemId = "wood", 
				quantity = 1,
				slot = 2
			}
		},
		craftingTime = 5, -- seconds
		experienceGained = 10,
		requiredLevel = 1,
		category = "weapons"
	},
	
	["steel_armor_blueprint"] = {
		id = "steel_armor_blueprint",
		name = "Steel Armor",
		resultItem = "steel_armor",
		resultQuantity = 1,
		ingredients = {
			{
				itemId = "steel_ingot",
				quantity = 4,
				slot = 1
			},
			{
				itemId = "leather",
				quantity = 2, 
				slot = 2
			},
			{
				itemId = "iron_ingot",
				quantity = 1,
				slot = 3
			}
		},
		craftingTime = 10,
		experienceGained = 25,
		requiredLevel = 5,
		category = "armor"
	}
}

-- Refinery recipes (for upgrading items)
RecipeDatabase.RefineryRecipes = {
	["iron_to_steel"] = {
		id = "iron_to_steel",
		name = "Iron to Steel",
		inputItem = "iron_ingot",
		inputQuantity = 5, -- requires 5 iron ingots
		resultItem = "steel_ingot", 
		resultQuantity = 1,
		refineryTime = 8,
		experienceGained = 15,
		requiredLevel = 3
	}
}

-- Get recipe by blueprint ID
function RecipeDatabase:GetRecipe(blueprintId)
	return self.Recipes[blueprintId]
end

-- Check if recipe exists
function RecipeDatabase:RecipeExists(blueprintId)
	return self.Recipes[blueprintId] ~= nil
end

-- Get all recipes
function RecipeDatabase:GetAllRecipes()
	return self.Recipes
end

-- Get recipes by category
function RecipeDatabase:GetRecipesByCategory(category)
	local result = {}
	for id, recipe in pairs(self.Recipes) do
		if recipe.category == category then
			result[id] = recipe
		end
	end
	return result
end

-- Validate if player has required materials for recipe
function RecipeDatabase:ValidateRecipeIngredients(blueprintId, playerInventory)
	local recipe = self:GetRecipe(blueprintId)
	if not recipe then
		return false, "Recipe not found"
	end
	
	-- Check each required ingredient
	for _, ingredient in pairs(recipe.ingredients) do
		local playerQuantity = 0
		
		-- Count how many of this item the player has
		for slot, item in pairs(playerInventory) do
			if item.itemId == ingredient.itemId then
				playerQuantity = playerQuantity + item.quantity
			end
		end
		
		if playerQuantity < ingredient.quantity then
			return false, "Insufficient " .. ingredient.itemId .. " (need " .. ingredient.quantity .. ", have " .. playerQuantity .. ")"
		end
	end
	
	return true, "All ingredients available"
end

-- Get refinery recipe for item
function RecipeDatabase:GetRefineryRecipe(itemId)
	for _, recipe in pairs(self.RefineryRecipes) do
		if recipe.inputItem == itemId then
			return recipe
		end
	end
	return nil
end

-- Check if item can be refined
function RecipeDatabase:CanRefine(itemId)
	return self:GetRefineryRecipe(itemId) ~= nil
end

-- Validate refinery requirements
function RecipeDatabase:ValidateRefineryIngredients(itemId, playerInventory)
	local recipe = self:GetRefineryRecipe(itemId)
	if not recipe then
		return false, "No refinery recipe found for " .. itemId
	end
	
	local playerQuantity = 0
	
	-- Count how many of this item the player has
	for slot, item in pairs(playerInventory) do
		if item.itemId == recipe.inputItem then
			playerQuantity = playerQuantity + item.quantity
		end
	end
	
	if playerQuantity < recipe.inputQuantity then
		return false, "Insufficient " .. recipe.inputItem .. " (need " .. recipe.inputQuantity .. ", have " .. playerQuantity .. ")"
	end
	
	return true, "Sufficient materials for refinery"
end

-- Get required materials for a recipe in a formatted way
function RecipeDatabase:GetRecipeRequirements(blueprintId)
	local recipe = self:GetRecipe(blueprintId)
	if not recipe then
		return nil
	end
	
	local requirements = {}
	for _, ingredient in pairs(recipe.ingredients) do
		table.insert(requirements, {
			itemId = ingredient.itemId,
			quantity = ingredient.quantity,
			slot = ingredient.slot
		})
	end
	
	return requirements
end

return RecipeDatabase