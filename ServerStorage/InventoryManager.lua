--[[
    InventoryManager.lua
    Server-side inventory management system
    Handles all inventory operations, validation, and persistence
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local InventoryManager = {}

-- Data Store
local InventoryDataStore = DataStoreService:GetDataStore("PlayerInventories")

-- Player Data Cache
local PlayerInventories = {}
local PlayerEquipment = {}

-- Constants
local INVENTORY_SIZE = 25 -- 5x5 grid per page
local MAX_PAGES = 4
local TOTAL_SLOTS = INVENTORY_SIZE * MAX_PAGES

-- Default inventory structure
local function createDefaultInventory()
    return {
        Pages = MAX_PAGES,
        CurrentPage = 1,
        Items = {}, -- {slotIndex = {itemId = "item_id", quantity = 1, metadata = {}}}
        Equipment = {
            [ItemDatabase.EquipmentSlots.WEAPON] = nil,
            [ItemDatabase.EquipmentSlots.ARMOR] = nil,
            [ItemDatabase.EquipmentSlots.RING_1] = nil,
            [ItemDatabase.EquipmentSlots.RING_2] = nil
        },
        LastSaved = os.time()
    }
end

-- Initialize player inventory
function InventoryManager:InitializePlayer(player)
    local userId = tostring(player.UserId)
    
    -- Try to load existing data
    local success, inventoryData = pcall(function()
        return InventoryDataStore:GetAsync(userId)
    end)
    
    if success and inventoryData then
        PlayerInventories[userId] = inventoryData
        PlayerEquipment[userId] = inventoryData.Equipment or {}
        print("Loaded inventory for player:", player.Name)
    else
        -- Create new inventory
        PlayerInventories[userId] = createDefaultInventory()
        PlayerEquipment[userId] = {}
        print("Created new inventory for player:", player.Name)
        
        -- Give starter items
        self:GiveStarterItems(player)
    end
    
    -- Validate inventory integrity
    self:ValidateInventory(userId)
end

-- Save player inventory
function InventoryManager:SaveInventory(player)
    local userId = tostring(player.UserId)
    local inventoryData = PlayerInventories[userId]
    
    if not inventoryData then return false end
    
    inventoryData.LastSaved = os.time()
    
    local success, error = pcall(function()
        InventoryDataStore:SetAsync(userId, inventoryData)
    end)
    
    if success then
        print("Saved inventory for player:", player.Name)
        return true
    else
        warn("Failed to save inventory for player:", player.Name, error)
        return false
    end
end

-- Give starter items to new players
function InventoryManager:GiveStarterItems(player)
    local starterItems = {
        {itemId = "basic_pistol", quantity = 1},
        {itemId = "kevlar_vest", quantity = 1},
        {itemId = "iron_ingot", quantity = 10},
        {itemId = "pistol_ammo", quantity = 50}
    }
    
    for _, item in pairs(starterItems) do
        self:AddItem(player, item.itemId, item.quantity)
    end
end

-- Add item to inventory
function InventoryManager:AddItem(player, itemId, quantity, metadata)
    local userId = tostring(player.UserId)
    local inventory = PlayerInventories[userId]
    
    if not inventory then return false end
    if not ItemDatabase:IsValidItem(itemId) then return false end
    
    quantity = quantity or 1
    metadata = metadata or {}
    
    local item = ItemDatabase:GetItem(itemId)
    
    -- Handle stackable items
    if item.Stackable then
        return self:AddStackableItem(userId, itemId, quantity, metadata)
    else
        return self:AddNonStackableItem(userId, itemId, quantity, metadata)
    end
end

-- Add stackable item
function InventoryManager:AddStackableItem(userId, itemId, quantity, metadata)
    local inventory = PlayerInventories[userId]
    local item = ItemDatabase:GetItem(itemId)
    local maxStack = item.MaxStack
    
    -- Try to stack with existing items first
    for slotIndex = 1, TOTAL_SLOTS do
        local slot = inventory.Items[slotIndex]
        if slot and slot.itemId == itemId then
            local canAdd = maxStack - slot.quantity
            if canAdd > 0 then
                local addAmount = math.min(canAdd, quantity)
                slot.quantity = slot.quantity + addAmount
                quantity = quantity - addAmount
                
                if quantity <= 0 then
                    return true
                end
            end
        end
    end
    
    -- Add remaining quantity to new slots
    while quantity > 0 do
        local emptySlot = self:FindEmptySlot(userId)
        if not emptySlot then
            return false -- Inventory full
        end
        
        local addAmount = math.min(maxStack, quantity)
        inventory.Items[emptySlot] = {
            itemId = itemId,
            quantity = addAmount,
            metadata = metadata
        }
        quantity = quantity - addAmount
    end
    
    return true
end

-- Add non-stackable item
function InventoryManager:AddNonStackableItem(userId, itemId, quantity, metadata)
    local inventory = PlayerInventories[userId]
    
    for i = 1, quantity do
        local emptySlot = self:FindEmptySlot(userId)
        if not emptySlot then
            return false -- Inventory full
        end
        
        inventory.Items[emptySlot] = {
            itemId = itemId,
            quantity = 1,
            metadata = metadata
        }
    end
    
    return true
end

-- Remove item from inventory
function InventoryManager:RemoveItem(player, itemId, quantity, fromSlot)
    local userId = tostring(player.UserId)
    local inventory = PlayerInventories[userId]
    
    if not inventory then return false end
    
    quantity = quantity or 1
    
    if fromSlot then
        -- Remove from specific slot
        return self:RemoveFromSlot(userId, fromSlot, quantity)
    else
        -- Remove from any available slots
        return self:RemoveFromInventory(userId, itemId, quantity)
    end
end

-- Remove from specific slot
function InventoryManager:RemoveFromSlot(userId, slotIndex, quantity)
    local inventory = PlayerInventories[userId]
    local slot = inventory.Items[slotIndex]
    
    if not slot then return false end
    if slot.quantity < quantity then return false end
    
    slot.quantity = slot.quantity - quantity
    
    if slot.quantity <= 0 then
        inventory.Items[slotIndex] = nil
    end
    
    return true
end

-- Remove from inventory by item ID
function InventoryManager:RemoveFromInventory(userId, itemId, quantity)
    local inventory = PlayerInventories[userId]
    local remaining = quantity
    
    for slotIndex = 1, TOTAL_SLOTS do
        if remaining <= 0 then break end
        
        local slot = inventory.Items[slotIndex]
        if slot and slot.itemId == itemId then
            local removeAmount = math.min(slot.quantity, remaining)
            slot.quantity = slot.quantity - removeAmount
            remaining = remaining - removeAmount
            
            if slot.quantity <= 0 then
                inventory.Items[slotIndex] = nil
            end
        end
    end
    
    return remaining == 0
end

-- Move item between slots
function InventoryManager:MoveItem(player, fromSlot, toSlot, quantity)
    local userId = tostring(player.UserId)
    local inventory = PlayerInventories[userId]
    
    if not inventory then return false end
    if fromSlot == toSlot then return true end
    
    local fromItem = inventory.Items[fromSlot]
    if not fromItem then return false end
    
    quantity = quantity or fromItem.quantity
    if quantity > fromItem.quantity then return false end
    
    local toItem = inventory.Items[toSlot]
    
    if not toItem then
        -- Move to empty slot
        inventory.Items[toSlot] = {
            itemId = fromItem.itemId,
            quantity = quantity,
            metadata = fromItem.metadata
        }
        
        fromItem.quantity = fromItem.quantity - quantity
        if fromItem.quantity <= 0 then
            inventory.Items[fromSlot] = nil
        end
        
        return true
    else
        -- Try to stack or swap
        if toItem.itemId == fromItem.itemId and ItemDatabase:CanStack(fromItem.itemId) then
            local item = ItemDatabase:GetItem(fromItem.itemId)
            local canAdd = item.MaxStack - toItem.quantity
            local addAmount = math.min(canAdd, quantity)
            
            if addAmount > 0 then
                toItem.quantity = toItem.quantity + addAmount
                fromItem.quantity = fromItem.quantity - addAmount
                
                if fromItem.quantity <= 0 then
                    inventory.Items[fromSlot] = nil
                end
                
                return true
            end
        else
            -- Swap items
            inventory.Items[fromSlot] = toItem
            inventory.Items[toSlot] = fromItem
            return true
        end
    end
    
    return false
end

-- Equip item
function InventoryManager:EquipItem(player, slotIndex, equipSlot)
    local userId = tostring(player.UserId)
    local inventory = PlayerInventories[userId]
    local equipment = PlayerEquipment[userId]
    
    if not inventory or not equipment then return false end
    
    local item = inventory.Items[slotIndex]
    if not item then return false end
    
    local itemData = ItemDatabase:GetItem(item.itemId)
    if not itemData then return false end
    
    -- Validate equipment slot
    local validSlot = false
    if itemData.Category == ItemDatabase.Categories.WEAPON and equipSlot == ItemDatabase.EquipmentSlots.WEAPON then
        validSlot = true
    elseif itemData.Category == ItemDatabase.Categories.ARMOR and equipSlot == ItemDatabase.EquipmentSlots.ARMOR then
        validSlot = true
    elseif itemData.Category == ItemDatabase.Categories.RING and (equipSlot == ItemDatabase.EquipmentSlots.RING_1 or equipSlot == ItemDatabase.EquipmentSlots.RING_2) then
        validSlot = true
    end
    
    if not validSlot then return false end
    
    -- Unequip current item if exists
    if equipment[equipSlot] then
        self:UnequipItem(player, equipSlot)
    end
    
    -- Equip new item
    equipment[equipSlot] = {
        itemId = item.itemId,
        quantity = 1,
        metadata = item.metadata
    }
    
    -- Remove from inventory (only 1 quantity for equipment)
    item.quantity = item.quantity - 1
    if item.quantity <= 0 then
        inventory.Items[slotIndex] = nil
    end
    
    return true
end

-- Unequip item
function InventoryManager:UnequipItem(player, equipSlot)
    local userId = tostring(player.UserId)
    local equipment = PlayerEquipment[userId]
    
    if not equipment or not equipment[equipSlot] then return false end
    
    local equippedItem = equipment[equipSlot]
    equipment[equipSlot] = nil
    
    -- Add back to inventory
    return self:AddItem(player, equippedItem.itemId, equippedItem.quantity, equippedItem.metadata)
end

-- Find empty slot
function InventoryManager:FindEmptySlot(userId)
    local inventory = PlayerInventories[userId]
    
    for slotIndex = 1, TOTAL_SLOTS do
        if not inventory.Items[slotIndex] then
            return slotIndex
        end
    end
    
    return nil
end

-- Get inventory data
function InventoryManager:GetInventory(player)
    local userId = tostring(player.UserId)
    return PlayerInventories[userId]
end

-- Get equipment data
function InventoryManager:GetEquipment(player)
    local userId = tostring(player.UserId)
    return PlayerEquipment[userId]
end

-- Validate inventory integrity
function InventoryManager:ValidateInventory(userId)
    local inventory = PlayerInventories[userId]
    if not inventory then return false end
    
    -- Check for invalid items
    for slotIndex, slot in pairs(inventory.Items) do
        if not ItemDatabase:IsValidItem(slot.itemId) then
            inventory.Items[slotIndex] = nil
        end
    end
    
    -- Check equipment
    local equipment = PlayerEquipment[userId]
    for equipSlot, item in pairs(equipment) do
        if not ItemDatabase:IsValidItem(item.itemId) then
            equipment[equipSlot] = nil
        end
    end
    
    return true
end

-- Check if inventory has space
function InventoryManager:HasSpace(player, itemId, quantity)
    local userId = tostring(player.UserId)
    local inventory = PlayerInventories[userId]
    
    if not inventory then return false end
    
    local item = ItemDatabase:GetItem(itemId)
    if not item then return false end
    
    if item.Stackable then
        local remaining = quantity
        
        -- Check existing stacks
        for slotIndex = 1, TOTAL_SLOTS do
            local slot = inventory.Items[slotIndex]
            if slot and slot.itemId == itemId then
                local canAdd = item.MaxStack - slot.quantity
                remaining = remaining - canAdd
                if remaining <= 0 then return true end
            end
        end
        
        -- Check empty slots
        local emptySlots = 0
        for slotIndex = 1, TOTAL_SLOTS do
            if not inventory.Items[slotIndex] then
                emptySlots = emptySlots + 1
            end
        end
        
        local slotsNeeded = math.ceil(remaining / item.MaxStack)
        return emptySlots >= slotsNeeded
    else
        -- Non-stackable items need individual slots
        local emptySlots = 0
        for slotIndex = 1, TOTAL_SLOTS do
            if not inventory.Items[slotIndex] then
                emptySlots = emptySlots + 1
            end
        end
        
        return emptySlots >= quantity
    end
end

-- Get item count in inventory
function InventoryManager:GetItemCount(player, itemId)
    local userId = tostring(player.UserId)
    local inventory = PlayerInventories[userId]
    
    if not inventory then return 0 end
    
    local count = 0
    for slotIndex = 1, TOTAL_SLOTS do
        local slot = inventory.Items[slotIndex]
        if slot and slot.itemId == itemId then
            count = count + slot.quantity
        end
    end
    
    return count
end

-- Player disconnect handler
function InventoryManager:OnPlayerRemoving(player)
    self:SaveInventory(player)
    
    local userId = tostring(player.UserId)
    PlayerInventories[userId] = nil
    PlayerEquipment[userId] = nil
end

-- Initialize event connections
Players.PlayerRemoving:Connect(function(player)
    InventoryManager:OnPlayerRemoving(player)
end)

-- Auto-save every 5 minutes
spawn(function()
    while true do
        wait(300) -- 5 minutes
        for _, player in pairs(Players:GetPlayers()) do
            InventoryManager:SaveInventory(player)
        end
    end
end)

return InventoryManager