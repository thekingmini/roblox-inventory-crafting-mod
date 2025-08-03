--[[
    InventoryEvents.lua
    Client-server communication for inventory system
    Handles all inventory-related remote events and data synchronization
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InventoryEvents = {}
local LocalPlayer = Players.LocalPlayer

-- Check if running on server or client
local IsServer = RunService:IsServer()

-- Remote Events Container
local RemoteEventsFolder = nil
local RemoteEvents = {}

-- Initialize remote events
function InventoryEvents:Initialize()
    if IsServer then
        self:CreateServerEvents()
        self:SetupServerHandlers()
    else
        self:SetupClientEvents()
        self:SetupClientHandlers()
    end
    
    print("InventoryEvents initialized on", IsServer and "server" or "client")
end

-- Create remote events on server
function InventoryEvents:CreateServerEvents()
    -- Create folder for remote events
    RemoteEventsFolder = Instance.new("Folder")
    RemoteEventsFolder.Name = "InventoryEvents"
    RemoteEventsFolder.Parent = ReplicatedStorage
    
    -- Create individual remote events
    local eventNames = {
        "RequestInventoryData",
        "InventoryDataChanged",
        "MoveItem",
        "UseItem",
        "DeleteItem",
        "EquipItem",
        "UnequipItem",
        "InventoryError",
        "ItemUsed",
        "EquipmentChanged"
    }
    
    for _, eventName in pairs(eventNames) do
        local remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = eventName
        remoteEvent.Parent = RemoteEventsFolder
        RemoteEvents[eventName] = remoteEvent
    end
end

-- Setup client events references
function InventoryEvents:SetupClientEvents()
    -- Wait for events folder
    RemoteEventsFolder = ReplicatedStorage:WaitForChild("InventoryEvents", 10)
    
    if RemoteEventsFolder then
        -- Get references to remote events
        for _, child in pairs(RemoteEventsFolder:GetChildren()) do
            if child:IsA("RemoteEvent") then
                RemoteEvents[child.Name] = child
            end
        end
    else
        warn("Failed to find InventoryEvents folder")
    end
end

-- Server-side event handlers
function InventoryEvents:SetupServerHandlers()
    local InventoryManager = require(game.ServerStorage.InventoryManager)
    
    -- Request inventory data
    RemoteEvents.RequestInventoryData.OnServerEvent:Connect(function(player)
        local inventoryData = InventoryManager:GetInventory(player)
        local equipmentData = InventoryManager:GetEquipment(player)
        
        if inventoryData and equipmentData then
            RemoteEvents.InventoryDataChanged:FireClient(player, inventoryData, equipmentData)
        end
    end)
    
    -- Move item
    RemoteEvents.MoveItem.OnServerEvent:Connect(function(player, fromSlot, toSlot, quantity)
        local success = InventoryManager:MoveItem(player, fromSlot, toSlot, quantity)
        
        if success then
            -- Send updated inventory
            local inventoryData = InventoryManager:GetInventory(player)
            RemoteEvents.InventoryDataChanged:FireClient(player, inventoryData, nil)
        else
            RemoteEvents.InventoryError:FireClient(player, "Failed to move item")
        end
    end)
    
    -- Use item
    RemoteEvents.UseItem.OnServerEvent:Connect(function(player, slotIndex)
        local inventory = InventoryManager:GetInventory(player)
        if not inventory or not inventory.Items[slotIndex] then
            RemoteEvents.InventoryError:FireClient(player, "Invalid item")
            return
        end
        
        local item = inventory.Items[slotIndex]
        local success = self:HandleItemUse(player, item, slotIndex)
        
        if success then
            -- Remove item from inventory
            InventoryManager:RemoveFromSlot(tostring(player.UserId), slotIndex, 1)
            
            -- Send updated inventory
            local inventoryData = InventoryManager:GetInventory(player)
            RemoteEvents.InventoryDataChanged:FireClient(player, inventoryData, nil)
            RemoteEvents.ItemUsed:FireClient(player, item.itemId)
        else
            RemoteEvents.InventoryError:FireClient(player, "Cannot use item")
        end
    end)
    
    -- Delete item
    RemoteEvents.DeleteItem.OnServerEvent:Connect(function(player, slotIndex)
        local success = InventoryManager:RemoveFromSlot(tostring(player.UserId), slotIndex, 1)
        
        if success then
            -- Send updated inventory
            local inventoryData = InventoryManager:GetInventory(player)
            RemoteEvents.InventoryDataChanged:FireClient(player, inventoryData, nil)
        else
            RemoteEvents.InventoryError:FireClient(player, "Failed to delete item")
        end
    end)
    
    -- Equip item
    RemoteEvents.EquipItem.OnServerEvent:Connect(function(player, slotIndex, equipSlot)
        local success = InventoryManager:EquipItem(player, slotIndex, equipSlot)
        
        if success then
            -- Send updated inventory and equipment
            local inventoryData = InventoryManager:GetInventory(player)
            local equipmentData = InventoryManager:GetEquipment(player)
            RemoteEvents.InventoryDataChanged:FireClient(player, inventoryData, equipmentData)
            RemoteEvents.EquipmentChanged:FireClient(player, equipmentData)
        else
            RemoteEvents.InventoryError:FireClient(player, "Failed to equip item")
        end
    end)
    
    -- Unequip item
    RemoteEvents.UnequipItem.OnServerEvent:Connect(function(player, equipSlot)
        local success = InventoryManager:UnequipItem(player, equipSlot)
        
        if success then
            -- Send updated inventory and equipment
            local inventoryData = InventoryManager:GetInventory(player)
            local equipmentData = InventoryManager:GetEquipment(player)
            RemoteEvents.InventoryDataChanged:FireClient(player, inventoryData, equipmentData)
            RemoteEvents.EquipmentChanged:FireClient(player, equipmentData)
        else
            RemoteEvents.InventoryError:FireClient(player, "Failed to unequip item")
        end
    end)
end

-- Client-side event handlers
function InventoryEvents:SetupClientHandlers()
    -- Will be connected by controllers
    self.OnInventoryDataChanged = Instance.new("BindableEvent")
    self.OnEquipmentChanged = Instance.new("BindableEvent")
    self.OnInventoryError = Instance.new("BindableEvent")
    self.OnItemUsed = Instance.new("BindableEvent")
    
    -- Connect remote events to bindable events
    if RemoteEvents.InventoryDataChanged then
        RemoteEvents.InventoryDataChanged.OnClientEvent:Connect(function(inventoryData, equipmentData)
            self.OnInventoryDataChanged:Fire(inventoryData, equipmentData)
        end)
    end
    
    if RemoteEvents.EquipmentChanged then
        RemoteEvents.EquipmentChanged.OnClientEvent:Connect(function(equipmentData)
            self.OnEquipmentChanged:Fire(equipmentData)
        end)
    end
    
    if RemoteEvents.InventoryError then
        RemoteEvents.InventoryError.OnClientEvent:Connect(function(errorMessage)
            self.OnInventoryError:Fire(errorMessage)
        end)
    end
    
    if RemoteEvents.ItemUsed then
        RemoteEvents.ItemUsed.OnClientEvent:Connect(function(itemId)
            self.OnItemUsed:Fire(itemId)
        end)
    end
end

-- Server-side utility functions
function InventoryEvents:HandleItemUse(player, item, slotIndex)
    if not IsServer then return false end
    
    local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
    local itemData = ItemDatabase:GetItem(item.itemId)
    
    if not itemData then return false end
    
    -- Handle different item types
    if itemData.Category == ItemDatabase.Categories.CONSUMABLE then
        return self:UseConsumable(player, item, itemData)
    elseif itemData.Category == ItemDatabase.Categories.BOOST then
        return self:UseBoost(player, item, itemData)
    elseif itemData.Category == ItemDatabase.Categories.TOOL then
        return self:UseTool(player, item, itemData)
    end
    
    return false
end

function InventoryEvents:UseConsumable(player, item, itemData)
    -- Handle consumable items (health potions, etc.)
    if item.itemId == "health_potion" then
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 50)
            return true
        end
    end
    
    return false
end

function InventoryEvents:UseBoost(player, item, itemData)
    -- Handle boost items (temporary effects)
    if item.itemId == "health_boost" then
        -- Apply temporary health boost
        self:ApplyTemporaryEffect(player, "HealthBoost", 300, {maxHealthIncrease = 50})
        return true
    elseif item.itemId == "speed_boost" then
        -- Apply temporary speed boost
        self:ApplyTemporaryEffect(player, "SpeedBoost", 180, {speedMultiplier = 1.5})
        return true
    elseif item.itemId == "armor_boost" then
        -- Apply temporary armor boost
        self:ApplyTemporaryEffect(player, "ArmorBoost", 240, {armorIncrease = 25})
        return true
    end
    
    return false
end

function InventoryEvents:UseTool(player, item, itemData)
    -- Handle tool items
    -- This would integrate with specific tool systems
    return false
end

function InventoryEvents:ApplyTemporaryEffect(player, effectType, duration, effectData)
    -- Apply temporary effect to player
    -- This would integrate with a more comprehensive effect system
    
    local character = player.Character
    if not character then return end
    
    if effectType == "HealthBoost" then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            local originalMaxHealth = humanoid.MaxHealth
            humanoid.MaxHealth = originalMaxHealth + effectData.maxHealthIncrease
            humanoid.Health = humanoid.Health + effectData.maxHealthIncrease
            
            -- Revert after duration
            spawn(function()
                wait(duration)
                if humanoid and humanoid.Parent then
                    humanoid.MaxHealth = originalMaxHealth
                    if humanoid.Health > originalMaxHealth then
                        humanoid.Health = originalMaxHealth
                    end
                end
            end)
        end
    elseif effectType == "SpeedBoost" then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            local originalSpeed = humanoid.WalkSpeed
            humanoid.WalkSpeed = originalSpeed * effectData.speedMultiplier
            
            -- Revert after duration
            spawn(function()
                wait(duration)
                if humanoid and humanoid.Parent then
                    humanoid.WalkSpeed = originalSpeed
                end
            end)
        end
    end
end

-- Client-side request functions
function InventoryEvents:RequestInventoryData()
    if IsServer then return end
    
    if RemoteEvents.RequestInventoryData then
        RemoteEvents.RequestInventoryData:FireServer()
    end
end

function InventoryEvents:MoveItem(fromSlot, toSlot, quantity)
    if IsServer then return end
    
    if RemoteEvents.MoveItem then
        RemoteEvents.MoveItem:FireServer(fromSlot, toSlot, quantity)
    end
end

function InventoryEvents:UseItem(slotIndex)
    if IsServer then return end
    
    if RemoteEvents.UseItem then
        RemoteEvents.UseItem:FireServer(slotIndex)
    end
end

function InventoryEvents:DeleteItem(slotIndex)
    if IsServer then return end
    
    if RemoteEvents.DeleteItem then
        RemoteEvents.DeleteItem:FireServer(slotIndex)
    end
end

function InventoryEvents:EquipItem(slotIndex, equipSlot)
    if IsServer then return end
    
    if RemoteEvents.EquipItem then
        RemoteEvents.EquipItem:FireServer(slotIndex, equipSlot)
    end
end

function InventoryEvents:UnequipItem(equipSlot)
    if IsServer then return end
    
    if RemoteEvents.UnequipItem then
        RemoteEvents.UnequipItem:FireServer(equipSlot)
    end
end

-- Utility functions
function InventoryEvents:GetRemoteEvent(eventName)
    return RemoteEvents[eventName]
end

-- Player initialization
if IsServer then
    Players.PlayerAdded:Connect(function(player)
        -- Initialize player inventory when they join
        local InventoryManager = require(game.ServerStorage.InventoryManager)
        InventoryManager:InitializePlayer(player)
        
        -- Send initial inventory data after a short delay
        spawn(function()
            wait(1) -- Wait for client to be ready
            local inventoryData = InventoryManager:GetInventory(player)
            local equipmentData = InventoryManager:GetEquipment(player)
            
            if inventoryData and equipmentData and RemoteEvents.InventoryDataChanged then
                RemoteEvents.InventoryDataChanged:FireClient(player, inventoryData, equipmentData)
            end
        end)
    end)
end

-- Auto-initialize
InventoryEvents:Initialize()

return InventoryEvents