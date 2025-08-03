--[[
    SystemInitializer.lua
    Main initialization script that coordinates all mod systems
    Ensures proper startup order and system integration
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

local SystemInitializer = {}
local LocalPlayer = Players.LocalPlayer

-- Check if running on server or client
local IsServer = RunService:IsServer()

-- System References
local Systems = {}

-- Initialize all systems
function SystemInitializer:Initialize()
    if IsServer then
        self:InitializeServerSystems()
    else
        self:InitializeClientSystems()
    end
    
    print("SystemInitializer completed for", IsServer and "server" or "client")
end

-- Initialize server-side systems
function SystemInitializer:InitializeServerSystems()
    print("Initializing server systems...")
    
    -- Load shared databases first
    Systems.ItemDatabase = require(ReplicatedStorage.ItemDatabase)
    Systems.RecipeDatabase = require(ReplicatedStorage.RecipeDatabase)
    
    -- Load core managers
    Systems.InventoryManager = require(game.ServerStorage.InventoryManager)
    Systems.CraftingManager = require(game.ServerStorage.CraftingManager)
    
    -- Load security systems
    Systems.AntiDuplication = require(game.ServerStorage.AntiDuplication)
    Systems.ExploitDetection = require(game.ServerStorage.ExploitDetection)
    
    -- Load advanced features
    Systems.BatchCrafting = require(game.ServerStorage.BatchCrafting)
    Systems.AutoRefinery = require(game.ServerStorage.AutoRefinery)
    
    -- Load communication systems
    Systems.InventoryEvents = require(ReplicatedStorage.InventoryEvents)
    Systems.CraftingEvents = require(ReplicatedStorage.CraftingEvents)
    
    print("Server systems initialized successfully")
end

-- Initialize client-side systems
function SystemInitializer:InitializeClientSystems()
    print("Initializing client systems...")
    
    -- Wait for shared databases
    local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))
    local RecipeDatabase = require(ReplicatedStorage:WaitForChild("RecipeDatabase"))
    
    -- Load communication systems
    local InventoryEvents = require(ReplicatedStorage:WaitForChild("InventoryEvents"))
    local CraftingEvents = require(ReplicatedStorage:WaitForChild("CraftingEvents"))
    
    -- Load interaction handlers
    local DragDropHandler = require(script.Parent.DragDropHandler)
    local TooltipManager = require(script.Parent.TooltipManager)
    
    -- Load controllers
    local InventoryController = require(script.Parent.InventoryController)
    local CraftingController = require(script.Parent.CraftingController)
    local MainMenuController = require(script.Parent.MainMenuController)
    
    -- Initialize systems in order
    spawn(function()
        -- Initialize interaction handlers first
        DragDropHandler:Initialize()
        TooltipManager:Initialize()
        
        -- Initialize controllers
        InventoryController:Initialize()
        CraftingController:Initialize()
        MainMenuController:Initialize()
        
        -- Connect events
        self:ConnectClientEvents(InventoryController, CraftingController, InventoryEvents, CraftingEvents)
        
        print("Client systems initialized successfully")
    end)
end

-- Connect client-side events
function SystemInitializer:ConnectClientEvents(inventoryController, craftingController, inventoryEvents, craftingEvents)
    -- Connect inventory events
    if inventoryEvents.OnInventoryDataChanged then
        inventoryEvents.OnInventoryDataChanged.Event:Connect(function(inventoryData, equipmentData)
            inventoryController:OnInventoryUpdated(inventoryData)
            if equipmentData then
                inventoryController:OnEquipmentUpdated(equipmentData)
            end
        end)
    end
    
    if inventoryEvents.OnEquipmentChanged then
        inventoryEvents.OnEquipmentChanged.Event:Connect(function(equipmentData)
            inventoryController:OnEquipmentUpdated(equipmentData)
        end)
    end
    
    if inventoryEvents.OnInventoryError then
        inventoryEvents.OnInventoryError.Event:Connect(function(errorMessage)
            warn("Inventory Error:", errorMessage)
            -- Could show error UI here
        end)
    end
    
    -- Connect crafting events
    if craftingEvents.OnAvailableRecipesChanged then
        craftingEvents.OnAvailableRecipesChanged.Event:Connect(function(recipes)
            craftingController:OnRecipesUpdated(recipes)
        end)
    end
    
    if craftingEvents.OnCraftingStatusChanged then
        craftingEvents.OnCraftingStatusChanged.Event:Connect(function(status)
            craftingController:OnCraftingStatusUpdated(status)
        end)
    end
    
    if craftingEvents.OnCraftingError then
        craftingEvents.OnCraftingError.Event:Connect(function(errorMessage)
            warn("Crafting Error:", errorMessage)
            -- Could show error UI here
        end)
    end
    
    -- Override controller request functions to use events
    inventoryController.RequestInventoryData = function()
        inventoryEvents:RequestInventoryData()
    end
    
    inventoryController.RequestUseItem = function(self, slotIndex)
        inventoryEvents:UseItem(slotIndex)
    end
    
    inventoryController.RequestDeleteItem = function(self, slotIndex)
        inventoryEvents:DeleteItem(slotIndex)
    end
    
    inventoryController.RequestEquipItem = function(self, slotIndex, equipSlot)
        inventoryEvents:EquipItem(slotIndex, equipSlot)
    end
    
    inventoryController.RequestUnequipItem = function(self, equipSlot)
        inventoryEvents:UnequipItem(equipSlot)
    end
    
    inventoryController.RequestMoveItem = function(self, fromSlot, toSlot, quantity)
        inventoryEvents:MoveItem(fromSlot, toSlot, quantity)
    end
    
    -- Override crafting controller request functions
    craftingController.RequestCraftingData = function()
        craftingEvents:RequestCraftingData()
    end
    
    craftingController.RequestStartCrafting = function(self, recipeId, quantity)
        craftingEvents:StartCrafting(recipeId, quantity)
    end
    
    craftingController.RequestAddToQueue = function(self, recipeId, quantity)
        craftingEvents:AddToQueue(recipeId, quantity)
    end
    
    craftingController.RequestCancelCrafting = function()
        craftingEvents:CancelCrafting()
    end
    
    craftingController.RequestClearQueue = function()
        craftingEvents:ClearQueue()
    end
    
    print("Client events connected successfully")
end

-- Auto-initialize when script loads
SystemInitializer:Initialize()

return SystemInitializer