-- InventoryManager.lua
-- Server-side inventory management system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)

local InventoryManager = {}

-- Player inventories storage (server-side)
InventoryManager.PlayerInventories = {}

-- Inventory settings
InventoryManager.MAX_SLOTS = 100
InventoryManager.SLOTS_PER_PAGE = 25
InventoryManager.MAX_PAGES = 4

-- Initialize player inventory
function InventoryManager:InitializePlayerInventory(player)
	local playerId = tostring(player.UserId)
	
	if not self.PlayerInventories[playerId] then
		self.PlayerInventories[playerId] = {
			slots = {}, -- [1-100] = {itemId="", quantity=0, metadata={}}
			lastUpdated = tick()
		}
		
		-- Give player some starting items for testing
		self:AddItem(player, "iron_sword_blueprint", 1)
		self:AddItem(player, "iron_ingot", 10)
		self:AddItem(player, "wood", 5)
		self:AddItem(player, "leather", 3)
		self:AddItem(player, "steel_armor_blueprint", 1)
	end
end

-- Get player inventory
function InventoryManager:GetPlayerInventory(player)
	local playerId = tostring(player.UserId)
	self:InitializePlayerInventory(player)
	return self.PlayerInventories[playerId]
end

-- Add item to player inventory
function InventoryManager:AddItem(player, itemId, quantity, metadata)
	local playerId = tostring(player.UserId)
	local inventory = self:GetPlayerInventory(player)
	
	-- Validate item exists
	local itemData = ItemDatabase:GetItem(itemId)
	if not itemData then
		warn("Attempted to add non-existent item: " .. itemId)
		return false, "Item does not exist"
	end
	
	local quantityToAdd = quantity or 1
	metadata = metadata or {}
	
	-- If item is stackable, try to stack with existing items first
	if itemData.stackable then
		for slotIndex = 1, self.MAX_SLOTS do
			local slot = inventory.slots[slotIndex]
			if slot and slot.itemId == itemId then
				local spaceAvailable = itemData.maxStack - slot.quantity
				local amountToAdd = math.min(quantityToAdd, spaceAvailable)
				
				if amountToAdd > 0 then
					slot.quantity = slot.quantity + amountToAdd
					quantityToAdd = quantityToAdd - amountToAdd
					
					if quantityToAdd <= 0 then
						inventory.lastUpdated = tick()
						return true, "Item added successfully"
					end
				end
			end
		end
	end
	
	-- Find empty slots for remaining quantity
	while quantityToAdd > 0 do
		local emptySlot = self:FindEmptySlot(player)
		if not emptySlot then
			return false, "Inventory full"
		end
		
		local amountToAdd = itemData.stackable and math.min(quantityToAdd, itemData.maxStack) or 1
		
		inventory.slots[emptySlot] = {
			itemId = itemId,
			quantity = amountToAdd,
			metadata = metadata
		}
		
		quantityToAdd = quantityToAdd - amountToAdd
	end
	
	inventory.lastUpdated = tick()
	return true, "Item added successfully"
end

-- Remove item from player inventory
function InventoryManager:RemoveItem(player, itemId, quantity, specificSlot)
	local playerId = tostring(player.UserId)
	local inventory = self:GetPlayerInventory(player)
	
	local quantityToRemove = quantity or 1
	
	-- If specific slot is provided, remove from that slot only
	if specificSlot then
		local slot = inventory.slots[specificSlot]
		if slot and slot.itemId == itemId and slot.quantity >= quantityToRemove then
			slot.quantity = slot.quantity - quantityToRemove
			if slot.quantity <= 0 then
				inventory.slots[specificSlot] = nil
			end
			inventory.lastUpdated = tick()
			return true, "Item removed successfully"
		else
			return false, "Insufficient quantity in specified slot"
		end
	end
	
	-- Remove from any available slots
	for slotIndex = 1, self.MAX_SLOTS do
		local slot = inventory.slots[slotIndex]
		if slot and slot.itemId == itemId then
			local amountToRemove = math.min(quantityToRemove, slot.quantity)
			slot.quantity = slot.quantity - amountToRemove
			quantityToRemove = quantityToRemove - amountToRemove
			
			if slot.quantity <= 0 then
				inventory.slots[slotIndex] = nil
			end
			
			if quantityToRemove <= 0 then
				inventory.lastUpdated = tick()
				return true, "Item removed successfully"
			end
		end
	end
	
	return false, "Insufficient quantity in inventory"
end

-- Move item from one slot to another
function InventoryManager:MoveItem(player, fromSlot, toSlot, quantity)
	local playerId = tostring(player.UserId)
	local inventory = self:GetPlayerInventory(player)
	
	-- Validate slot indices
	if fromSlot < 1 or fromSlot > self.MAX_SLOTS or toSlot < 1 or toSlot > self.MAX_SLOTS then
		return false, "Invalid slot index"
	end
	
	local sourceSlot = inventory.slots[fromSlot]
	if not sourceSlot then
		return false, "Source slot is empty"
	end
	
	local quantityToMove = quantity or sourceSlot.quantity
	if quantityToMove > sourceSlot.quantity then
		return false, "Insufficient quantity in source slot"
	end
	
	local targetSlot = inventory.slots[toSlot]
	local itemData = ItemDatabase:GetItem(sourceSlot.itemId)
	
	-- If target slot is empty, move items there
	if not targetSlot then
		inventory.slots[toSlot] = {
			itemId = sourceSlot.itemId,
			quantity = quantityToMove,
			metadata = sourceSlot.metadata
		}
		
		sourceSlot.quantity = sourceSlot.quantity - quantityToMove
		if sourceSlot.quantity <= 0 then
			inventory.slots[fromSlot] = nil
		end
		
		inventory.lastUpdated = tick()
		return true, "Item moved successfully"
	end
	
	-- If target slot has same item and is stackable, try to stack
	if targetSlot.itemId == sourceSlot.itemId and itemData.stackable then
		local spaceAvailable = itemData.maxStack - targetSlot.quantity
		local amountToMove = math.min(quantityToMove, spaceAvailable)
		
		if amountToMove > 0 then
			targetSlot.quantity = targetSlot.quantity + amountToMove
			sourceSlot.quantity = sourceSlot.quantity - amountToMove
			
			if sourceSlot.quantity <= 0 then
				inventory.slots[fromSlot] = nil
			end
			
			inventory.lastUpdated = tick()
			return true, "Item stacked successfully"
		else
			return false, "Target slot is full"
		end
	end
	
	-- Otherwise, swap items
	inventory.slots[fromSlot] = targetSlot
	inventory.slots[toSlot] = {
		itemId = sourceSlot.itemId,
		quantity = quantityToMove,
		metadata = sourceSlot.metadata
	}
	
	if sourceSlot.quantity > quantityToMove then
		-- Partial move, keep remainder in source
		sourceSlot.quantity = sourceSlot.quantity - quantityToMove
		inventory.slots[fromSlot] = sourceSlot
	end
	
	inventory.lastUpdated = tick()
	return true, "Items swapped successfully"
end

-- Find first empty slot
function InventoryManager:FindEmptySlot(player)
	local inventory = self:GetPlayerInventory(player)
	
	for slotIndex = 1, self.MAX_SLOTS do
		if not inventory.slots[slotIndex] then
			return slotIndex
		end
	end
	
	return nil
end

-- Get item count in inventory
function InventoryManager:GetItemCount(player, itemId)
	local inventory = self:GetPlayerInventory(player)
	local count = 0
	
	for slotIndex = 1, self.MAX_SLOTS do
		local slot = inventory.slots[slotIndex]
		if slot and slot.itemId == itemId then
			count = count + slot.quantity
		end
	end
	
	return count
end

-- Check if player has enough of an item
function InventoryManager:HasItem(player, itemId, quantity)
	local currentCount = self:GetItemCount(player, itemId)
	return currentCount >= (quantity or 1)
end

-- Get slot data by index
function InventoryManager:GetSlot(player, slotIndex)
	local inventory = self:GetPlayerInventory(player)
	return inventory.slots[slotIndex]
end

-- Set slot data
function InventoryManager:SetSlot(player, slotIndex, itemId, quantity, metadata)
	local inventory = self:GetPlayerInventory(player)
	
	if itemId and quantity and quantity > 0 then
		inventory.slots[slotIndex] = {
			itemId = itemId,
			quantity = quantity,
			metadata = metadata or {}
		}
	else
		inventory.slots[slotIndex] = nil
	end
	
	inventory.lastUpdated = tick()
end

-- Clear inventory slot
function InventoryManager:ClearSlot(player, slotIndex)
	local inventory = self:GetPlayerInventory(player)
	inventory.slots[slotIndex] = nil
	inventory.lastUpdated = tick()
end

return InventoryManager