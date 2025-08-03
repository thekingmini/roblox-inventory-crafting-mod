-- CraftingUIManager.lua
-- Manages crafting UI and validation logic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local RecipeDatabase = require(ReplicatedStorage.RecipeDatabase)

local CraftingUIManager = {}

-- State management
CraftingUIManager.CurrentBlueprint = nil -- {itemId="", quantity=1}
CraftingUIManager.MaterialSlots = {} -- [1-6] = {itemId="", quantity=1}
CraftingUIManager.CurrentRecipe = nil
CraftingUIManager.MenuController = nil
CraftingUIManager.IsCrafting = false

-- UI References
CraftingUIManager.BlueprintSlot = nil
CraftingUIManager.MaterialSlots = {}
CraftingUIManager.GoButton = nil

-- Initialize the crafting UI manager
function CraftingUIManager:Initialize(menuController)
	self.MenuController = menuController
	self:SetupUIReferences()
	self:SetupRemoteEventHandlers()
	self:SetupButtonHandlers()
	
	print("CraftingUIManager initialized")
end

-- Setup UI element references
function CraftingUIManager:SetupUIReferences()
	if not self.MenuController or not self.MenuController.UIReferences.CraftingFrame then
		warn("MenuController or CraftingFrame not available")
		return
	end
	
	local craftingFrame = self.MenuController.UIReferences.CraftingFrame
	
	-- Blueprint slot
	self.BlueprintSlot = craftingFrame:FindFirstChild("BlueprintSlot")
	
	-- Material slots
	for i = 1, 6 do
		local slot = craftingFrame:FindFirstChild("MaterialSlot" .. i)
		if slot then
			self.MaterialSlots[i] = slot
		end
	end
	
	-- GO button
	self.GoButton = craftingFrame:FindFirstChild("CraftingMenuGoButton")
end

-- Setup RemoteEvent handlers
function CraftingUIManager:SetupRemoteEventHandlers()
	-- Listen for crafting responses
	local CraftingRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("CraftingRemote")
	if CraftingRemote then
		CraftingRemote.OnClientEvent:Connect(function(responseData)
			self:HandleCraftingResponse(responseData)
		end)
	end
	
	-- Listen for UI updates
	local UIUpdateRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("UIUpdateRemote")
	if UIUpdateRemote then
		UIUpdateRemote.OnClientEvent:Connect(function(updateData)
			self:HandleServerUpdate(updateData)
		end)
	end
end

-- Setup button handlers
function CraftingUIManager:SetupButtonHandlers()
	-- GO button click
	if self.GoButton then
		self.GoButton.MouseButton1Click:Connect(function()
			self:ExecuteCraft()
		end)
	end
end

-- Handle crafting response from server
function CraftingUIManager:HandleCraftingResponse(responseData)
	if responseData.action == "set_blueprint" then
		if responseData.success then
			self:OnBlueprintSet(responseData.data.requirements)
		else
			self:ShowError(responseData.message)
		end
	elseif responseData.action == "set_material" then
		if responseData.success then
			self:ValidateCraftingSetup()
		else
			self:ShowError(responseData.message)
		end
	elseif responseData.action == "craft" then
		self:OnCraftCompleted(responseData.success, responseData.message)
	elseif responseData.action == "validate_setup" then
		self:OnValidationResult(responseData.success, responseData.message)
	end
end

-- Handle server updates
function CraftingUIManager:HandleServerUpdate(updateData)
	if updateData.type == "crafting_update" then
		self:UpdateCraftingFromServer(updateData.crafting)
	elseif updateData.type == "error" then
		self:ShowError(updateData.message)
	elseif updateData.type == "success" then
		self:ShowSuccess(updateData.message)
	end
end

-- Set blueprint in crafting slot
function CraftingUIManager:SetBlueprint(itemId, quantity)
	-- Validate blueprint
	local itemData = ItemDatabase:GetItem(itemId)
	if not itemData or itemData.type ~= ItemDatabase.ItemTypes.BLUEPRINT then
		self:ShowError("Invalid blueprint item")
		return false
	end
	
	-- Clear previous setup
	self:ClearCraftingSetup()
	
	-- Set blueprint locally
	self.CurrentBlueprint = {
		itemId = itemId,
		quantity = quantity or 1
	}
	
	-- Update blueprint slot UI
	self:UpdateBlueprintSlotDisplay()
	
	-- Get recipe
	local recipe = RecipeDatabase:GetRecipe(itemId)
	if recipe then
		self.CurrentRecipe = recipe
		self:ShowRecipeRequirements()
	else
		self:ShowError("No recipe found for blueprint")
		return false
	end
	
	return true
end

-- Set material in crafting slot
function CraftingUIManager:SetMaterial(slotIndex, itemId, quantity)
	if slotIndex < 1 or slotIndex > 6 then
		self:ShowError("Invalid material slot index")
		return false
	end
	
	-- Validate against current recipe
	if not self.CurrentRecipe then
		self:ShowError("No blueprint selected")
		return false
	end
	
	local valid, reason = self:ValidateMaterialForSlot(slotIndex, itemId, quantity)
	if not valid then
		self:ShowError(reason)
		return false
	end
	
	-- Set material locally
	self.MaterialSlots[slotIndex] = {
		itemId = itemId,
		quantity = quantity or 1
	}
	
	-- Update material slot UI
	self:UpdateMaterialSlotDisplay(slotIndex)
	
	-- Re-validate crafting setup
	self:ValidateCraftingSetup()
	
	return true
end

-- Clear crafting setup
function CraftingUIManager:ClearCraftingSetup()
	self.CurrentBlueprint = nil
	self.CurrentRecipe = nil
	self.MaterialSlots = {}
	self.IsCrafting = false
	
	-- Clear UI
	self:ClearBlueprintSlotDisplay()
	self:ClearMaterialSlotsDisplay()
	self:UpdateGoButtonState(false)
	self:ClearRecipeRequirements()
end

-- Clear specific material slot
function CraftingUIManager:ClearMaterialSlot(slotIndex)
	if slotIndex >= 1 and slotIndex <= 6 then
		self.MaterialSlots[slotIndex] = nil
		self:ClearMaterialSlotDisplay(slotIndex)
		self:ValidateCraftingSetup()
	end
end

-- Validate material for specific slot
function CraftingUIManager:ValidateMaterialForSlot(slotIndex, itemId, quantity)
	if not self.CurrentRecipe then
		return false, "No recipe selected"
	end
	
	-- Find required ingredient for this slot
	local requiredIngredient = nil
	for _, ingredient in pairs(self.CurrentRecipe.ingredients) do
		if ingredient.slot == slotIndex then
			requiredIngredient = ingredient
			break
		end
	end
	
	if not requiredIngredient then
		return false, "No ingredient required for slot " .. slotIndex
	end
	
	-- Check item type
	if itemId ~= requiredIngredient.itemId then
		return false, "Wrong material (expected " .. requiredIngredient.itemId .. ")"
	end
	
	-- Check quantity
	if quantity < requiredIngredient.quantity then
		return false, "Insufficient quantity (need " .. requiredIngredient.quantity .. ")"
	end
	
	return true, "Material valid"
end

-- Validate complete crafting setup
function CraftingUIManager:ValidateCraftingSetup()
	if not self.CurrentRecipe then
		self:UpdateGoButtonState(false)
		return false, "No recipe selected"
	end
	
	-- Check all required ingredients
	for _, ingredient in pairs(self.CurrentRecipe.ingredients) do
		local materialSlot = self.MaterialSlots[ingredient.slot]
		
		if not materialSlot then
			self:UpdateGoButtonState(false)
			return false, "Missing material in slot " .. ingredient.slot
		end
		
		if materialSlot.itemId ~= ingredient.itemId then
			self:UpdateGoButtonState(false)
			return false, "Wrong material in slot " .. ingredient.slot
		end
		
		if materialSlot.quantity < ingredient.quantity then
			self:UpdateGoButtonState(false)
			return false, "Insufficient quantity in slot " .. ingredient.slot
		end
	end
	
	self:UpdateGoButtonState(true)
	return true, "Crafting setup valid"
end

-- Execute crafting
function CraftingUIManager:ExecuteCraft()
	if self.IsCrafting then
		self:ShowError("Already crafting")
		return
	end
	
	if not self.CurrentBlueprint then
		self:ShowError("No blueprint selected")
		return
	end
	
	-- Final validation
	local valid, message = self:ValidateCraftingSetup()
	if not valid then
		self:ShowError(message)
		return
	end
	
	-- Prepare materials data
	local materials = {}
	for slotIndex, material in pairs(self.MaterialSlots) do
		table.insert(materials, {
			itemId = material.itemId,
			quantity = material.quantity,
			slotIndex = slotIndex
		})
	end
	
	-- Send craft request to server
	local CraftingRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("CraftingRemote")
	if CraftingRemote then
		self.IsCrafting = true
		self:UpdateGoButtonState(false, "CRAFTING...")
		
		CraftingRemote:FireServer({
			action = "craft",
			recipeId = self.CurrentBlueprint.itemId,
			materials = materials
		})
	end
end

-- Handle craft completion
function CraftingUIManager:OnCraftCompleted(success, message)
	self.IsCrafting = false
	
	if success then
		self:ShowSuccess(message or "Crafting completed successfully!")
		self:ClearCraftingSetup()
	else
		self:ShowError(message or "Crafting failed")
		self:UpdateGoButtonState(true)
	end
end

-- Handle blueprint set response
function CraftingUIManager:OnBlueprintSet(requirements)
	self:ShowRecipeRequirements()
end

-- Handle validation result
function CraftingUIManager:OnValidationResult(success, message)
	self:UpdateGoButtonState(success)
	
	if not success then
		self:ShowError(message)
	end
end

-- Update blueprint slot display
function CraftingUIManager:UpdateBlueprintSlotDisplay()
	if not self.BlueprintSlot or not self.CurrentBlueprint then
		return
	end
	
	local itemData = ItemDatabase:GetItem(self.CurrentBlueprint.itemId)
	if itemData then
		self.BlueprintSlot.Image = itemData.icon
		
		-- Add blueprint glow effect
		self.BlueprintSlot.BorderColor3 = Color3.fromRGB(100, 200, 255)
		self.BlueprintSlot.BorderSizePixel = 3
	end
end

-- Clear blueprint slot display
function CraftingUIManager:ClearBlueprintSlotDisplay()
	if self.BlueprintSlot then
		self.BlueprintSlot.Image = ""
		self.BlueprintSlot.BorderColor3 = Color3.fromRGB(100, 100, 100)
		self.BlueprintSlot.BorderSizePixel = 2
	end
end

-- Update material slot display
function CraftingUIManager:UpdateMaterialSlotDisplay(slotIndex)
	local slot = self.MaterialSlots[slotIndex]
	local uiSlot = self.MaterialSlots[slotIndex]
	
	if not uiSlot or not slot then
		return
	end
	
	local itemData = ItemDatabase:GetItem(slot.itemId)
	if itemData then
		uiSlot.Image = itemData.icon
		
		-- Add quantity label if needed
		self:UpdateSlotQuantity(uiSlot, slot.quantity)
		
		-- Validation border color
		local valid = self:ValidateMaterialForSlot(slotIndex, slot.itemId, slot.quantity)
		if valid then
			uiSlot.BorderColor3 = Color3.fromRGB(100, 255, 100) -- Green for valid
		else
			uiSlot.BorderColor3 = Color3.fromRGB(255, 100, 100) -- Red for invalid
		end
	end
end

-- Clear material slot display
function CraftingUIManager:ClearMaterialSlotDisplay(slotIndex)
	local uiSlot = self.MaterialSlots[slotIndex]
	if uiSlot then
		uiSlot.Image = ""
		uiSlot.BorderColor3 = Color3.fromRGB(100, 100, 100)
		
		-- Remove quantity label
		local quantityLabel = uiSlot:FindFirstChild("QuantityLabel")
		if quantityLabel then
			quantityLabel:Destroy()
		end
	end
end

-- Clear all material slots display
function CraftingUIManager:ClearMaterialSlotsDisplay()
	for i = 1, 6 do
		self:ClearMaterialSlotDisplay(i)
	end
end

-- Update slot quantity display
function CraftingUIManager:UpdateSlotQuantity(slot, quantity)
	local quantityLabel = slot:FindFirstChild("QuantityLabel")
	
	if quantity > 1 then
		if not quantityLabel then
			quantityLabel = Instance.new("TextLabel")
			quantityLabel.Name = "QuantityLabel"
			quantityLabel.Size = UDim2.new(0.4, 0, 0.3, 0)
			quantityLabel.Position = UDim2.new(0.6, 0, 0.7, 0)
			quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			quantityLabel.BackgroundTransparency = 0.2
			quantityLabel.BorderSizePixel = 0
			quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			quantityLabel.TextScaled = true
			quantityLabel.Font = Enum.Font.SourceSansBold
			quantityLabel.ZIndex = slot.ZIndex + 1
			quantityLabel.Parent = slot
		end
		quantityLabel.Text = tostring(quantity)
	elseif quantityLabel then
		quantityLabel:Destroy()
	end
end

-- Show recipe requirements
function CraftingUIManager:ShowRecipeRequirements()
	if not self.CurrentRecipe then
		return
	end
	
	-- Highlight required material slots and show silhouettes
	for _, ingredient in pairs(self.CurrentRecipe.ingredients) do
		local slotIndex = ingredient.slot
		local uiSlot = self.MaterialSlots[slotIndex]
		
		if uiSlot then
			-- Show silhouette of required item
			local itemData = ItemDatabase:GetItem(ingredient.itemId)
			if itemData then
				uiSlot.Image = itemData.icon
				uiSlot.ImageTransparency = 0.7 -- Silhouette effect
				uiSlot.BorderColor3 = Color3.fromRGB(255, 255, 100) -- Yellow highlight
				uiSlot.BorderSizePixel = 3
				
				-- Add requirement label
				local reqLabel = Instance.new("TextLabel")
				reqLabel.Name = "RequirementLabel"
				reqLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
				reqLabel.Position = UDim2.new(0.2, 0, 0, 0)
				reqLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 100)
				reqLabel.BackgroundTransparency = 0.1
				reqLabel.BorderSizePixel = 0
				reqLabel.Text = tostring(ingredient.quantity)
				reqLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
				reqLabel.TextScaled = true
				reqLabel.Font = Enum.Font.SourceSansBold
				reqLabel.ZIndex = uiSlot.ZIndex + 1
				reqLabel.Parent = uiSlot
			end
		end
	end
end

-- Clear recipe requirements display
function CraftingUIManager:ClearRecipeRequirements()
	for i = 1, 6 do
		local uiSlot = self.MaterialSlots[i]
		if uiSlot then
			-- Remove requirement labels
			local reqLabel = uiSlot:FindFirstChild("RequirementLabel")
			if reqLabel then
				reqLabel:Destroy()
			end
			
			-- Reset slot appearance
			uiSlot.Image = ""
			uiSlot.ImageTransparency = 0
			uiSlot.BorderColor3 = Color3.fromRGB(100, 100, 100)
			uiSlot.BorderSizePixel = 2
		end
	end
end

-- Update GO button state
function CraftingUIManager:UpdateGoButtonState(enabled, text)
	if not self.GoButton then
		return
	end
	
	self.GoButton.Text = text or "GO"
	
	if enabled then
		self.GoButton.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
		self.GoButton.BorderColor3 = Color3.fromRGB(100, 200, 100)
		self.GoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		self.GoButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		self.GoButton.BorderColor3 = Color3.fromRGB(120, 120, 120)
		self.GoButton.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end

-- Update from server crafting state
function CraftingUIManager:UpdateCraftingFromServer(craftingData)
	if craftingData.blueprint then
		self.CurrentBlueprint = craftingData.blueprint
		self:UpdateBlueprintSlotDisplay()
	end
	
	if craftingData.materials then
		self.MaterialSlots = craftingData.materials
		for i = 1, 6 do
			self:UpdateMaterialSlotDisplay(i)
		end
	end
	
	if craftingData.recipe then
		self.CurrentRecipe = craftingData.recipe
		self:ShowRecipeRequirements()
	end
	
	self.IsCrafting = craftingData.isCrafting or false
	self:ValidateCraftingSetup()
end

-- Get current recipe
function CraftingUIManager:GetCurrentRecipe()
	return self.CurrentRecipe
end

-- Get current blueprint
function CraftingUIManager:GetCurrentBlueprint()
	return self.CurrentBlueprint
end

-- Get material in slot
function CraftingUIManager:GetMaterialInSlot(slotIndex)
	return self.MaterialSlots[slotIndex]
end

-- Check if crafting is possible
function CraftingUIManager:CanCraft()
	local valid, _ = self:ValidateCraftingSetup()
	return valid and not self.IsCrafting
end

-- Show error message
function CraftingUIManager:ShowError(message)
	-- Could be enhanced with proper UI notifications
	warn("Crafting Error: " .. message)
end

-- Show success message
function CraftingUIManager:ShowSuccess(message)
	-- Could be enhanced with proper UI notifications
	print("Crafting Success: " .. message)
end

return CraftingUIManager