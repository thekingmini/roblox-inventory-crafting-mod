-- DragDropSystem.lua
-- Handles all drag-and-drop mechanics for the crafting system

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)

local DragDropSystem = {}

-- Drag state
DragDropSystem.DragState = {
	isDragging = false,
	dragItem = nil, -- {itemId="", quantity=1, sourceSlot=nil, sourceType=""}
	dragIcon = nil,
	validDropTargets = {},
	lastValidTarget = nil
}

-- Slot types
DragDropSystem.SlotTypes = {
	INVENTORY = "inventory",
	BLUEPRINT = "blueprint", 
	MATERIAL = "material",
	REFINERY = "refinery"
}

-- Drop validation rules
DragDropSystem.DropRules = {
	[DragDropSystem.SlotTypes.BLUEPRINT] = {
		allowedTypes = {ItemDatabase.ItemTypes.BLUEPRINT},
		maxItems = 1
	},
	[DragDropSystem.SlotTypes.MATERIAL] = {
		allowedTypes = {ItemDatabase.ItemTypes.MATERIAL, ItemDatabase.ItemTypes.REFINED},
		maxItems = 99
	},
	[DragDropSystem.SlotTypes.REFINERY] = {
		allowedTypes = {ItemDatabase.ItemTypes.MATERIAL, ItemDatabase.ItemTypes.REFINED, ItemDatabase.ItemTypes.TOOL, ItemDatabase.ItemTypes.WEAPON},
		maxItems = 1
	},
	[DragDropSystem.SlotTypes.INVENTORY] = {
		allowedTypes = nil, -- Allow all types
		maxItems = 99
	}
}

-- Initialize the drag-drop system
function DragDropSystem:Initialize(menuController)
	self.MenuController = menuController
	self:SetupDragHandlers()
	self:SetupInputHandlers()
	
	print("DragDropSystem initialized")
end

-- Setup drag handlers for all slot types
function DragDropSystem:SetupDragHandlers()
	-- Inventory slots
	for i = 1, 100 do
		self:SetupSlotDrag("InventorySlot" .. i, self.SlotTypes.INVENTORY, i)
	end
	
	-- Blueprint slot
	self:SetupSlotDrag("BlueprintSlot", self.SlotTypes.BLUEPRINT, 1)
	
	-- Material slots  
	for i = 1, 6 do
		self:SetupSlotDrag("MaterialSlot" .. i, self.SlotTypes.MATERIAL, i)
	end
	
	-- Refinery slots
	for i = 1, 8 do
		self:SetupSlotDrag("RefinerySlot" .. i, self.SlotTypes.REFINERY, i)
	end
end

-- Setup drag handling for a specific slot
function DragDropSystem:SetupSlotDrag(slotName, slotType, slotIndex)
	local slot = self:FindSlotByName(slotName)
	if not slot then
		warn("Slot not found: " .. slotName)
		return
	end
	
	-- Mouse button down - start drag
	slot.MouseButton1Down:Connect(function()
		self:StartDrag(slot, slotType, slotIndex)
	end)
	
	-- Mouse enter - highlight as potential drop target
	slot.MouseEnter:Connect(function()
		self:OnSlotMouseEnter(slot, slotType, slotIndex)
	end)
	
	-- Mouse leave - remove highlight
	slot.MouseLeave:Connect(function()
		self:OnSlotMouseLeave(slot, slotType, slotIndex)
	end)
end

-- Setup input handlers for drag operations
function DragDropSystem:SetupInputHandlers()
	-- Mouse move - update drag icon position
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and self.DragState.isDragging then
			self:UpdateDragIcon(input.Position)
		end
	end)
	
	-- Mouse button up - end drag
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self.DragState.isDragging then
			self:EndDrag()
		end
	end)
end

-- Start dragging from a slot
function DragDropSystem:StartDrag(slot, slotType, slotIndex)
	-- Get item data from slot
	local itemData = self:GetSlotItemData(slot, slotType, slotIndex)
	if not itemData or not itemData.itemId then
		return -- No item to drag
	end
	
	-- Set drag state
	self.DragState.isDragging = true
	self.DragState.dragItem = {
		itemId = itemData.itemId,
		quantity = itemData.quantity,
		sourceSlot = slotIndex,
		sourceType = slotType,
		sourceSlotRef = slot
	}
	
	-- Create drag icon
	self:CreateDragIcon(itemData.itemId, itemData.quantity)
	
	-- Highlight valid drop targets
	self:HighlightValidDropTargets()
	
	-- Visual feedback on source slot
	self:SetSlotHighlight(slot, Color3.fromRGB(255, 200, 100), 3)
end

-- Update drag icon position
function DragDropSystem:UpdateDragIcon(mousePosition)
	if self.DragState.dragIcon then
		self.DragState.dragIcon.Position = UDim2.new(0, mousePosition.X - 32, 0, mousePosition.Y - 32)
	end
end

-- End drag operation
function DragDropSystem:EndDrag()
	if not self.DragState.isDragging then
		return
	end
	
	-- Find drop target under mouse
	local dropTarget = self:GetDropTargetUnderMouse()
	
	if dropTarget then
		self:ProcessDrop(dropTarget.slot, dropTarget.slotType, dropTarget.slotIndex)
	end
	
	-- Clean up drag state
	self:CleanupDrag()
end

-- Process item drop onto target slot
function DragDropSystem:ProcessDrop(targetSlot, targetSlotType, targetSlotIndex)
	local dragItem = self.DragState.dragItem
	
	-- Validate drop
	local valid, reason = self:ValidateDrop(dragItem, targetSlotType, targetSlotIndex)
	if not valid then
		self:ShowDropError(reason)
		return
	end
	
	-- Different handling based on target type
	if targetSlotType == self.SlotTypes.INVENTORY then
		self:ProcessInventoryDrop(targetSlotIndex, dragItem)
	elseif targetSlotType == self.SlotTypes.BLUEPRINT then
		self:ProcessBlueprintDrop(dragItem)
	elseif targetSlotType == self.SlotTypes.MATERIAL then
		self:ProcessMaterialDrop(targetSlotIndex, dragItem)
	elseif targetSlotType == self.SlotTypes.REFINERY then
		self:ProcessRefineryDrop(targetSlotIndex, dragItem)
	end
end

-- Validate if drop is allowed
function DragDropSystem:ValidateDrop(dragItem, targetSlotType, targetSlotIndex)
	-- Can't drop on same slot
	if dragItem.sourceType == targetSlotType and dragItem.sourceSlot == targetSlotIndex then
		return false, "Cannot drop item on itself"
	end
	
	-- Get item data
	local itemData = ItemDatabase:GetItem(dragItem.itemId)
	if not itemData then
		return false, "Invalid item"
	end
	
	-- Check drop rules for target slot type
	local dropRule = self.DropRules[targetSlotType]
	if dropRule then
		-- Check allowed item types
		if dropRule.allowedTypes then
			if not table.find(dropRule.allowedTypes, itemData.type) then
				return false, "Item type not allowed in this slot"
			end
		end
		
		-- Check quantity limits
		if dragItem.quantity > dropRule.maxItems then
			return false, "Too many items for this slot type"
		end
	end
	
	-- Special validation for material slots
	if targetSlotType == self.SlotTypes.MATERIAL then
		local valid, reason = self:ValidateMaterialSlotDrop(targetSlotIndex, dragItem)
		if not valid then
			return false, reason
		end
	end
	
	-- Special validation for blueprint slots
	if targetSlotType == self.SlotTypes.BLUEPRINT then
		if itemData.type ~= ItemDatabase.ItemTypes.BLUEPRINT then
			return false, "Only blueprints allowed in blueprint slot"
		end
	end
	
	return true, "Drop allowed"
end

-- Validate material slot drop against current recipe
function DragDropSystem:ValidateMaterialSlotDrop(materialSlotIndex, dragItem)
	-- Get current blueprint/recipe from CraftingUIManager
	local CraftingUIManager = require(script.Parent.CraftingUIManager)
	local currentRecipe = CraftingUIManager:GetCurrentRecipe()
	
	if not currentRecipe then
		return false, "No blueprint selected"
	end
	
	-- Find required ingredient for this slot
	local requiredIngredient = nil
	for _, ingredient in pairs(currentRecipe.ingredients) do
		if ingredient.slot == materialSlotIndex then
			requiredIngredient = ingredient
			break
		end
	end
	
	if not requiredIngredient then
		return false, "No ingredient required for this slot"
	end
	
	-- Check if item matches required ingredient
	if dragItem.itemId ~= requiredIngredient.itemId then
		return false, "Wrong material type (expected " .. requiredIngredient.itemId .. ")"
	end
	
	-- Check quantity
	if dragItem.quantity < requiredIngredient.quantity then
		return false, "Insufficient quantity (need " .. requiredIngredient.quantity .. ")"
	end
	
	return true, "Material valid for slot"
end

-- Process drop into inventory slot
function DragDropSystem:ProcessInventoryDrop(targetSlotIndex, dragItem)
	-- Send inventory move request to server
	local InventoryRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("InventoryRemote")
	if InventoryRemote then
		local requestData = {
			action = "move_item",
			fromSlot = self:GetSourceInventorySlot(dragItem),
			toSlot = targetSlotIndex,
			itemId = dragItem.itemId,
			quantity = dragItem.quantity
		}
		
		InventoryRemote:FireServer(requestData)
	end
end

-- Process drop into blueprint slot
function DragDropSystem:ProcessBlueprintDrop(dragItem)
	-- Send crafting request to server
	local CraftingRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("CraftingRemote")
	if CraftingRemote then
		local requestData = {
			action = "set_blueprint",
			itemId = dragItem.itemId,
			quantity = dragItem.quantity
		}
		
		CraftingRemote:FireServer(requestData)
	end
	
	-- Also remove from source inventory if it was from inventory
	if dragItem.sourceType == self.SlotTypes.INVENTORY then
		self:RemoveFromSourceSlot(dragItem)
	end
end

-- Process drop into material slot
function DragDropSystem:ProcessMaterialDrop(materialSlotIndex, dragItem)
	-- Send crafting request to server
	local CraftingRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("CraftingRemote")
	if CraftingRemote then
		local requestData = {
			action = "set_material",
			slotIndex = materialSlotIndex,
			itemId = dragItem.itemId,
			quantity = dragItem.quantity
		}
		
		CraftingRemote:FireServer(requestData)
	end
	
	-- Remove from source if from inventory
	if dragItem.sourceType == self.SlotTypes.INVENTORY then
		self:RemoveFromSourceSlot(dragItem)
	end
end

-- Process drop into refinery slot
function DragDropSystem:ProcessRefineryDrop(refinerySlotIndex, dragItem)
	-- For now, just move item to refinery slot locally
	-- In a full implementation, this would communicate with server
	local targetSlot = self:FindSlotByName("RefinerySlot" .. refinerySlotIndex)
	if targetSlot then
		self:SetSlotItem(targetSlot, dragItem.itemId, dragItem.quantity)
	end
	
	-- Remove from source if from inventory
	if dragItem.sourceType == self.SlotTypes.INVENTORY then
		self:RemoveFromSourceSlot(dragItem)
	end
end

-- Create visual drag icon
function DragDropSystem:CreateDragIcon(itemId, quantity)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create drag icon
	local dragIcon = Instance.new("ImageLabel")
	dragIcon.Name = "DragIcon"
	dragIcon.Size = UDim2.new(0, 64, 0, 64)
	dragIcon.BackgroundTransparency = 0.3
	dragIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dragIcon.BorderSizePixel = 2
	dragIcon.BorderColor3 = Color3.fromRGB(255, 255, 100)
	dragIcon.ZIndex = 1000
	
	-- Set item icon
	local itemData = ItemDatabase:GetItem(itemId)
	if itemData then
		dragIcon.Image = itemData.icon
	end
	
	-- Add quantity label if > 1
	if quantity > 1 then
		local quantityLabel = Instance.new("TextLabel")
		quantityLabel.Size = UDim2.new(0.4, 0, 0.4, 0)
		quantityLabel.Position = UDim2.new(0.6, 0, 0.6, 0)
		quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		quantityLabel.BackgroundTransparency = 0.3
		quantityLabel.BorderSizePixel = 0
		quantityLabel.Text = tostring(quantity)
		quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		quantityLabel.TextScaled = true
		quantityLabel.Font = Enum.Font.SourceSansBold
		quantityLabel.Parent = dragIcon
	end
	
	dragIcon.Parent = playerGui
	self.DragState.dragIcon = dragIcon
end

-- Highlight valid drop targets
function DragDropSystem:HighlightValidDropTargets()
	local dragItem = self.DragState.dragItem
	self.DragState.validDropTargets = {}
	
	-- Check all possible drop targets
	local allSlots = self:GetAllSlots()
	
	for _, slotInfo in pairs(allSlots) do
		local valid, _ = self:ValidateDrop(dragItem, slotInfo.slotType, slotInfo.slotIndex)
		if valid then
			self:SetSlotHighlight(slotInfo.slot, Color3.fromRGB(100, 255, 100), 2)
			table.insert(self.DragState.validDropTargets, slotInfo)
		end
	end
end

-- Set slot highlight effect
function DragDropSystem:SetSlotHighlight(slot, color, borderSize)
	slot.BorderColor3 = color
	slot.BorderSizePixel = borderSize or 2
end

-- Remove slot highlight
function DragDropSystem:RemoveSlotHighlight(slot)
	slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
	slot.BorderSizePixel = 1
end

-- Clean up after drag operation
function DragDropSystem:CleanupDrag()
	-- Remove drag icon
	if self.DragState.dragIcon then
		self.DragState.dragIcon:Destroy()
		self.DragState.dragIcon = nil
	end
	
	-- Remove highlights from all slots
	local allSlots = self:GetAllSlots()
	for _, slotInfo in pairs(allSlots) do
		self:RemoveSlotHighlight(slotInfo.slot)
	end
	
	-- Reset drag state
	self.DragState.isDragging = false
	self.DragState.dragItem = nil
	self.DragState.validDropTargets = {}
	self.DragState.lastValidTarget = nil
end

-- Find slot by name
function DragDropSystem:FindSlotByName(slotName)
	local mainFrame = self.MenuController.UIReferences.MainFrame
	if not mainFrame then return nil end
	
	-- Search in different frame areas
	local searchAreas = {
		mainFrame:FindFirstChild("ContentFrame"):FindFirstChild("CraftingFrame"),
		mainFrame:FindFirstChild("ContentFrame"):FindFirstChild("InventoryFrame"), 
		mainFrame:FindFirstChild("ContentFrame"):FindFirstChild("RefineryFrame")
	}
	
	for _, area in pairs(searchAreas) do
		if area then
			local slot = area:FindFirstChild(slotName)
			if slot then
				return slot
			end
		end
	end
	
	return nil
end

-- Get all slots for highlighting
function DragDropSystem:GetAllSlots()
	local slots = {}
	
	-- Inventory slots
	for i = 1, 100 do
		local slot = self:FindSlotByName("InventorySlot" .. i)
		if slot then
			table.insert(slots, {
				slot = slot,
				slotType = self.SlotTypes.INVENTORY,
				slotIndex = i
			})
		end
	end
	
	-- Blueprint slot
	local blueprintSlot = self:FindSlotByName("BlueprintSlot")
	if blueprintSlot then
		table.insert(slots, {
			slot = blueprintSlot,
			slotType = self.SlotTypes.BLUEPRINT,
			slotIndex = 1
		})
	end
	
	-- Material slots
	for i = 1, 6 do
		local slot = self:FindSlotByName("MaterialSlot" .. i)
		if slot then
			table.insert(slots, {
				slot = slot,
				slotType = self.SlotTypes.MATERIAL,
				slotIndex = i
			})
		end
	end
	
	-- Refinery slots
	for i = 1, 8 do
		local slot = self:FindSlotByName("RefinerySlot" .. i)
		if slot then
			table.insert(slots, {
				slot = slot,
				slotType = self.SlotTypes.REFINERY,
				slotIndex = i
			})
		end
	end
	
	return slots
end

-- Get drop target under mouse
function DragDropSystem:GetDropTargetUnderMouse()
	for _, targetInfo in pairs(self.DragState.validDropTargets) do
		local slot = targetInfo.slot
		local absolutePos = slot.AbsolutePosition
		local absoluteSize = slot.AbsoluteSize
		local mousePos = UserInputService:GetMouseLocation()
		
		if mousePos.X >= absolutePos.X and mousePos.X <= absolutePos.X + absoluteSize.X and
		   mousePos.Y >= absolutePos.Y and mousePos.Y <= absolutePos.Y + absoluteSize.Y then
			return targetInfo
		end
	end
	
	return nil
end

-- Get item data from slot (this would connect to inventory/crafting managers)
function DragDropSystem:GetSlotItemData(slot, slotType, slotIndex)
	-- This is a placeholder - in a real implementation, this would query
	-- the appropriate manager (InventoryUIManager, CraftingUIManager) for slot data
	
	if slot.Image and slot.Image ~= "" then
		-- For demo purposes, assume slots with images have items
		return {
			itemId = "iron_ingot", -- Placeholder
			quantity = 1
		}
	end
	
	return nil
end

-- Set slot item visually
function DragDropSystem:SetSlotItem(slot, itemId, quantity)
	local itemData = ItemDatabase:GetItem(itemId)
	if itemData then
		slot.Image = itemData.icon
		
		-- Add/update quantity label
		local quantityLabel = slot:FindFirstChild("QuantityLabel")
		if quantity > 1 then
			if not quantityLabel then
				quantityLabel = Instance.new("TextLabel")
				quantityLabel.Name = "QuantityLabel"
				quantityLabel.Size = UDim2.new(0.4, 0, 0.4, 0)
				quantityLabel.Position = UDim2.new(0.6, 0, 0.6, 0)
				quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				quantityLabel.BackgroundTransparency = 0.3
				quantityLabel.BorderSizePixel = 0
				quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				quantityLabel.TextScaled = true
				quantityLabel.Font = Enum.Font.SourceSansBold
				quantityLabel.Parent = slot
			end
			quantityLabel.Text = tostring(quantity)
		elseif quantityLabel then
			quantityLabel:Destroy()
		end
	end
end

-- Remove item from source slot
function DragDropSystem:RemoveFromSourceSlot(dragItem)
	if dragItem.sourceType == self.SlotTypes.INVENTORY then
		-- Send remove request to server
		local InventoryRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("InventoryRemote")
		if InventoryRemote then
			local requestData = {
				action = "remove_item",
				itemId = dragItem.itemId,
				quantity = dragItem.quantity,
				specificSlot = dragItem.sourceSlot
			}
			
			InventoryRemote:FireServer(requestData)
		end
	end
end

-- Get source inventory slot for drag item
function DragDropSystem:GetSourceInventorySlot(dragItem)
	if dragItem.sourceType == self.SlotTypes.INVENTORY then
		return dragItem.sourceSlot
	end
	return nil
end

-- Show drop error message
function DragDropSystem:ShowDropError(reason)
	-- This could be enhanced with a proper UI notification system
	warn("Drop failed: " .. reason)
end

-- Handle slot mouse enter
function DragDropSystem:OnSlotMouseEnter(slot, slotType, slotIndex)
	if self.DragState.isDragging then
		-- Highlight if valid drop target
		for _, target in pairs(self.DragState.validDropTargets) do
			if target.slot == slot then
				self:SetSlotHighlight(slot, Color3.fromRGB(150, 255, 150), 3)
				self.DragState.lastValidTarget = target
				break
			end
		end
	end
end

-- Handle slot mouse leave
function DragDropSystem:OnSlotMouseLeave(slot, slotType, slotIndex)
	if self.DragState.isDragging then
		-- Restore normal highlight for valid targets
		for _, target in pairs(self.DragState.validDropTargets) do
			if target.slot == slot then
				self:SetSlotHighlight(slot, Color3.fromRGB(100, 255, 100), 2)
				break
			end
		end
	end
end

return DragDropSystem