-- CraftingManager.lua  
-- Server-side crafting management system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local RecipeDatabase = require(ReplicatedStorage.RecipeDatabase)
local InventoryManager = require(script.Parent.InventoryManager)

local CraftingManager = {}

-- Player crafting states
CraftingManager.PlayerCraftingStates = {}

-- Crafting settings
CraftingManager.MAX_CRAFTING_SLOTS = 6 -- Material slots in crafting interface

-- Initialize player crafting state
function CraftingManager:InitializePlayerCrafting(player)
	local playerId = tostring(player.UserId)
	
	if not self.PlayerCraftingStates[playerId] then
		self.PlayerCraftingStates[playerId] = {
			blueprintSlot = nil, -- {itemId="", quantity=1}
			materialSlots = {}, -- [1-6] = {itemId="", quantity=0}
			currentRecipe = nil,
			isCrafting = false,
			craftingStartTime = 0
		}
	end
end

-- Get player crafting state
function CraftingManager:GetPlayerCraftingState(player)
	local playerId = tostring(player.UserId)
	self:InitializePlayerCrafting(player)
	return self.PlayerCraftingStates[playerId]
end

-- Set blueprint in crafting slot
function CraftingManager:SetBlueprint(player, itemId, quantity)
	local playerId = tostring(player.UserId)
	local craftingState = self:GetPlayerCraftingState(player)
	
	-- Validate blueprint
	local itemData = ItemDatabase:GetItem(itemId)
	if not itemData or itemData.type ~= ItemDatabase.ItemTypes.BLUEPRINT then
		return false, "Invalid blueprint item"
	end
	
	-- Clear previous blueprint and materials
	craftingState.blueprintSlot = {
		itemId = itemId,
		quantity = quantity or 1
	}
	craftingState.materialSlots = {}
	craftingState.currentRecipe = RecipeDatabase:GetRecipe(itemId)
	
	return true, "Blueprint set successfully"
end

-- Set material in crafting slot
function CraftingManager:SetMaterial(player, slotIndex, itemId, quantity)
	local playerId = tostring(player.UserId)
	local craftingState = self:GetPlayerCraftingState(player)
	
	-- Validate slot index
	if slotIndex < 1 or slotIndex > self.MAX_CRAFTING_SLOTS then
		return false, "Invalid crafting slot index"
	end
	
	-- Validate item exists
	local itemData = ItemDatabase:GetItem(itemId)
	if not itemData then
		return false, "Invalid item"
	end
	
	-- Set material in slot
	craftingState.materialSlots[slotIndex] = {
		itemId = itemId,
		quantity = quantity or 1
	}
	
	return true, "Material set successfully"
end

-- Clear crafting slot
function CraftingManager:ClearCraftingSlot(player, slotType, slotIndex)
	local playerId = tostring(player.UserId)
	local craftingState = self:GetPlayerCraftingState(player)
	
	if slotType == "blueprint" then
		craftingState.blueprintSlot = nil
		craftingState.materialSlots = {}
		craftingState.currentRecipe = nil
	elseif slotType == "material" and slotIndex then
		craftingState.materialSlots[slotIndex] = nil
	end
	
	return true, "Slot cleared successfully"
end

-- Validate current crafting setup
function CraftingManager:ValidateCraftingSetup(player)
	local craftingState = self:GetPlayerCraftingState(player)
	
	-- Check if blueprint is set
	if not craftingState.blueprintSlot then
		return false, "No blueprint selected"
	end
	
	-- Check if recipe exists
	if not craftingState.currentRecipe then
		return false, "Invalid recipe"
	end
	
	local recipe = craftingState.currentRecipe
	
	-- Check each required ingredient
	for _, ingredient in pairs(recipe.ingredients) do
		local materialSlot = craftingState.materialSlots[ingredient.slot]
		
		if not materialSlot then
			return false, "Missing material in slot " .. ingredient.slot
		end
		
		if materialSlot.itemId ~= ingredient.itemId then
			return false, "Wrong material in slot " .. ingredient.slot .. " (expected " .. ingredient.itemId .. ")"
		end
		
		if materialSlot.quantity < ingredient.quantity then
			return false, "Insufficient quantity in slot " .. ingredient.slot .. " (need " .. ingredient.quantity .. ")"
		end
	end
	
	return true, "Crafting setup is valid"
end

-- Process crafting operation
function CraftingManager:ProcessCraft(player, recipeId, materials)
	local playerId = tostring(player.UserId)
	local craftingState = self:GetPlayerCraftingState(player)
	
	-- Prevent multiple simultaneous crafting
	if craftingState.isCrafting then
		return false, "Already crafting"
	end
	
	-- Validate recipe
	local recipe = RecipeDatabase:GetRecipe(recipeId)
	if not recipe then
		return false, "Recipe not found"
	end
	
	-- Validate player has blueprint in inventory  
	if not InventoryManager:HasItem(player, recipeId, 1) then
		return false, "Blueprint not found in inventory"
	end
	
	-- Validate materials in inventory
	local valid, message = RecipeDatabase:ValidateRecipeIngredients(recipeId, InventoryManager:GetPlayerInventory(player).slots)
	if not valid then
		return false, message
	end
	
	-- Check inventory space for result
	local emptySlot = InventoryManager:FindEmptySlot(player)
	if not emptySlot then
		return false, "Inventory full"
	end
	
	-- Start crafting process
	craftingState.isCrafting = true
	craftingState.craftingStartTime = tick()
	
	-- Remove materials from inventory
	for _, ingredient in pairs(recipe.ingredients) do
		local success, removeMessage = InventoryManager:RemoveItem(player, ingredient.itemId, ingredient.quantity)
		if not success then
			-- Rollback if any material removal fails
			craftingState.isCrafting = false
			return false, "Failed to remove materials: " .. removeMessage
		end
	end
	
	-- Simulate crafting time (in a real game, this might be async)
	wait(recipe.craftingTime or 1)
	
	-- Add result item to inventory
	local success, addMessage = InventoryManager:AddItem(player, recipe.resultItem, recipe.resultQuantity)
	if not success then
		craftingState.isCrafting = false
		return false, "Failed to add result item: " .. addMessage
	end
	
	-- Clear crafting state
	craftingState.isCrafting = false
	craftingState.blueprintSlot = nil
	craftingState.materialSlots = {}
	craftingState.currentRecipe = nil
	
	return true, "Crafting completed successfully"
end

-- Process refinery operation
function CraftingManager:ProcessRefinery(player, itemId, quantity)
	local playerId = tostring(player.UserId)
	
	-- Get refinery recipe
	local recipe = RecipeDatabase:GetRefineryRecipe(itemId)
	if not recipe then
		return false, "No refinery recipe for " .. itemId
	end
	
	-- Validate player has enough items
	if not InventoryManager:HasItem(player, recipe.inputItem, recipe.inputQuantity) then
		return false, "Insufficient materials for refinery"
	end
	
	-- Check inventory space for result
	local emptySlot = InventoryManager:FindEmptySlot(player)
	if not emptySlot then
		return false, "Inventory full"
	end
	
	-- Remove input materials
	local success, removeMessage = InventoryManager:RemoveItem(player, recipe.inputItem, recipe.inputQuantity)
	if not success then
		return false, "Failed to remove input materials: " .. removeMessage
	end
	
	-- Simulate refinery time
	wait(recipe.refineryTime or 5)
	
	-- Add result item
	local addSuccess, addMessage = InventoryManager:AddItem(player, recipe.resultItem, recipe.resultQuantity)
	if not addSuccess then
		return false, "Failed to add refined item: " .. addMessage
	end
	
	return true, "Refinery completed successfully"
end

-- Get crafting requirements for a blueprint
function CraftingManager:GetCraftingRequirements(blueprintId)
	local recipe = RecipeDatabase:GetRecipe(blueprintId)
	if not recipe then
		return nil, "Recipe not found"
	end
	
	return recipe.ingredients, "Requirements found"
end

-- Check if player can craft a recipe
function CraftingManager:CanCraft(player, recipeId)
	local recipe = RecipeDatabase:GetRecipe(recipeId)
	if not recipe then
		return false, "Recipe not found"
	end
	
	-- Check if player has blueprint
	if not InventoryManager:HasItem(player, recipeId, 1) then
		return false, "Blueprint not found"
	end
	
	-- Check materials
	local playerInventory = InventoryManager:GetPlayerInventory(player).slots
	local valid, message = RecipeDatabase:ValidateRecipeIngredients(recipeId, playerInventory)
	
	return valid, message
end

-- Get current crafting status
function CraftingManager:GetCraftingStatus(player)
	local craftingState = self:GetPlayerCraftingState(player)
	
	return {
		isCrafting = craftingState.isCrafting,
		blueprint = craftingState.blueprintSlot,
		materials = craftingState.materialSlots,
		recipe = craftingState.currentRecipe,
		craftingStartTime = craftingState.craftingStartTime
	}
end

return CraftingManager