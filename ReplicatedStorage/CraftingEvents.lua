--[[
    CraftingEvents.lua
    Client-server communication for crafting system
    Handles all crafting-related remote events and data synchronization
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CraftingEvents = {}
local LocalPlayer = Players.LocalPlayer

-- Check if running on server or client
local IsServer = RunService:IsServer()

-- Remote Events Container
local RemoteEventsFolder = nil
local RemoteEvents = {}

-- Initialize remote events
function CraftingEvents:Initialize()
    if IsServer then
        self:CreateServerEvents()
        self:SetupServerHandlers()
    else
        self:SetupClientEvents()
        self:SetupClientHandlers()
    end
    
    print("CraftingEvents initialized on", IsServer and "server" or "client")
end

-- Create remote events on server
function CraftingEvents:CreateServerEvents()
    -- Create folder for remote events
    RemoteEventsFolder = Instance.new("Folder")
    RemoteEventsFolder.Name = "CraftingEvents"
    RemoteEventsFolder.Parent = ReplicatedStorage
    
    -- Create individual remote events
    local eventNames = {
        "RequestCraftingData",
        "CraftingDataChanged",
        "AvailableRecipesChanged",
        "StartCrafting",
        "AddToQueue",
        "CancelCrafting",
        "ClearQueue",
        "CraftingCompleted",
        "CraftingError",
        "CraftingStatusChanged"
    }
    
    for _, eventName in pairs(eventNames) do
        local remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = eventName
        remoteEvent.Parent = RemoteEventsFolder
        RemoteEvents[eventName] = remoteEvent
    end
end

-- Setup client events references
function CraftingEvents:SetupClientEvents()
    -- Wait for events folder
    RemoteEventsFolder = ReplicatedStorage:WaitForChild("CraftingEvents", 10)
    
    if RemoteEventsFolder then
        -- Get references to remote events
        for _, child in pairs(RemoteEventsFolder:GetChildren()) do
            if child:IsA("RemoteEvent") then
                RemoteEvents[child.Name] = child
            end
        end
    else
        warn("Failed to find CraftingEvents folder")
    end
end

-- Server-side event handlers
function CraftingEvents:SetupServerHandlers()
    local CraftingManager = require(game.ServerStorage.CraftingManager)
    local RecipeDatabase = require(ReplicatedStorage.RecipeDatabase)
    
    -- Request crafting data
    RemoteEvents.RequestCraftingData.OnServerEvent:Connect(function(player)
        local availableRecipes = CraftingManager:GetAvailableRecipes(player)
        local craftingStatus = CraftingManager:GetCraftingStatus(player)
        
        RemoteEvents.AvailableRecipesChanged:FireClient(player, availableRecipes)
        RemoteEvents.CraftingStatusChanged:FireClient(player, craftingStatus)
    end)
    
    -- Start crafting
    RemoteEvents.StartCrafting.OnServerEvent:Connect(function(player, recipeId, quantity)
        local success, message = CraftingManager:StartCrafting(player, recipeId, quantity)
        
        if success then
            -- Send updated status
            local craftingStatus = CraftingManager:GetCraftingStatus(player)
            RemoteEvents.CraftingStatusChanged:FireClient(player, craftingStatus)
        else
            RemoteEvents.CraftingError:FireClient(player, message)
        end
    end)
    
    -- Add to queue
    RemoteEvents.AddToQueue.OnServerEvent:Connect(function(player, recipeId, quantity)
        local success, message = CraftingManager:AddToQueue(player, recipeId, quantity)
        
        if success then
            -- Send updated status
            local craftingStatus = CraftingManager:GetCraftingStatus(player)
            RemoteEvents.CraftingStatusChanged:FireClient(player, craftingStatus)
        else
            RemoteEvents.CraftingError:FireClient(player, message)
        end
    end)
    
    -- Cancel crafting
    RemoteEvents.CancelCrafting.OnServerEvent:Connect(function(player)
        local success, message = CraftingManager:CancelCrafting(player)
        
        if success then
            -- Send updated status
            local craftingStatus = CraftingManager:GetCraftingStatus(player)
            RemoteEvents.CraftingStatusChanged:FireClient(player, craftingStatus)
        else
            RemoteEvents.CraftingError:FireClient(player, message)
        end
    end)
    
    -- Clear queue
    RemoteEvents.ClearQueue.OnServerEvent:Connect(function(player)
        local success, message = CraftingManager:ClearQueue(player)
        
        if success then
            -- Send updated status
            local craftingStatus = CraftingManager:GetCraftingStatus(player)
            RemoteEvents.CraftingStatusChanged:FireClient(player, craftingStatus)
        else
            RemoteEvents.CraftingError:FireClient(player, message)
        end
    end)
end

-- Client-side event handlers
function CraftingEvents:SetupClientHandlers()
    -- Create bindable events for controllers to connect to
    self.OnAvailableRecipesChanged = Instance.new("BindableEvent")
    self.OnCraftingStatusChanged = Instance.new("BindableEvent")
    self.OnCraftingCompleted = Instance.new("BindableEvent")
    self.OnCraftingError = Instance.new("BindableEvent")
    
    -- Connect remote events to bindable events
    if RemoteEvents.AvailableRecipesChanged then
        RemoteEvents.AvailableRecipesChanged.OnClientEvent:Connect(function(recipes)
            self.OnAvailableRecipesChanged:Fire(recipes)
        end)
    end
    
    if RemoteEvents.CraftingStatusChanged then
        RemoteEvents.CraftingStatusChanged.OnClientEvent:Connect(function(status)
            self.OnCraftingStatusChanged:Fire(status)
        end)
    end
    
    if RemoteEvents.CraftingCompleted then
        RemoteEvents.CraftingCompleted.OnClientEvent:Connect(function(result)
            self.OnCraftingCompleted:Fire(result)
        end)
    end
    
    if RemoteEvents.CraftingError then
        RemoteEvents.CraftingError.OnClientEvent:Connect(function(errorMessage)
            self.OnCraftingError:Fire(errorMessage)
        end)
    end
end

-- Client-side request functions
function CraftingEvents:RequestCraftingData()
    if IsServer then return end
    
    if RemoteEvents.RequestCraftingData then
        RemoteEvents.RequestCraftingData:FireServer()
    end
end

function CraftingEvents:StartCrafting(recipeId, quantity)
    if IsServer then return end
    
    if RemoteEvents.StartCrafting then
        RemoteEvents.StartCrafting:FireServer(recipeId, quantity)
    end
end

function CraftingEvents:AddToQueue(recipeId, quantity)
    if IsServer then return end
    
    if RemoteEvents.AddToQueue then
        RemoteEvents.AddToQueue:FireServer(recipeId, quantity)
    end
end

function CraftingEvents:CancelCrafting()
    if IsServer then return end
    
    if RemoteEvents.CancelCrafting then
        RemoteEvents.CancelCrafting:FireServer()
    end
end

function CraftingEvents:ClearQueue()
    if IsServer then return end
    
    if RemoteEvents.ClearQueue then
        RemoteEvents.ClearQueue:FireServer()
    end
end

-- Server-side crafting completion handler
if IsServer then
    -- Monitor crafting completions
    spawn(function()
        local CraftingManager = require(game.ServerStorage.CraftingManager)
        
        while true do
            wait(1) -- Check every second
            
            -- This would integrate with the CraftingManager's completion system
            -- For now, we'll add a hook for when crafting completes
        end
    end)
    
    -- Player initialization
    Players.PlayerAdded:Connect(function(player)
        -- Initialize player crafting when they join
        local CraftingManager = require(game.ServerStorage.CraftingManager)
        CraftingManager:InitializePlayer(player)
        
        -- Send initial crafting data after a short delay
        spawn(function()
            wait(2) -- Wait for client to be ready
            local availableRecipes = CraftingManager:GetAvailableRecipes(player)
            local craftingStatus = CraftingManager:GetCraftingStatus(player)
            
            if RemoteEvents.AvailableRecipesChanged then
                RemoteEvents.AvailableRecipesChanged:FireClient(player, availableRecipes)
            end
            
            if RemoteEvents.CraftingStatusChanged then
                RemoteEvents.CraftingStatusChanged:FireClient(player, craftingStatus)
            end
        end)
    end)
end

-- Utility functions
function CraftingEvents:GetRemoteEvent(eventName)
    return RemoteEvents[eventName]
end

-- Crafting completion notification system
function CraftingEvents:NotifyCraftingCompleted(player, result)
    if not IsServer then return end
    
    if RemoteEvents.CraftingCompleted then
        RemoteEvents.CraftingCompleted:FireClient(player, result)
    end
    
    -- Also update crafting status
    local CraftingManager = require(game.ServerStorage.CraftingManager)
    local craftingStatus = CraftingManager:GetCraftingStatus(player)
    
    if RemoteEvents.CraftingStatusChanged then
        RemoteEvents.CraftingStatusChanged:FireClient(player, craftingStatus)
    end
end

-- Recipe unlock system
function CraftingEvents:NotifyRecipeUnlocked(player, recipeId)
    if not IsServer then return end
    
    -- Send updated available recipes
    local CraftingManager = require(game.ServerStorage.CraftingManager)
    local availableRecipes = CraftingManager:GetAvailableRecipes(player)
    
    if RemoteEvents.AvailableRecipesChanged then
        RemoteEvents.AvailableRecipesChanged:FireClient(player, availableRecipes)
    end
end

-- Level up integration
function CraftingEvents:OnPlayerLevelUp(player, newLevel)
    if not IsServer then return end
    
    -- Check for newly available recipes
    local CraftingManager = require(game.ServerStorage.CraftingManager)
    local availableRecipes = CraftingManager:GetAvailableRecipes(player)
    
    if RemoteEvents.AvailableRecipesChanged then
        RemoteEvents.AvailableRecipesChanged:FireClient(player, availableRecipes)
    end
end

-- Auto-initialize
CraftingEvents:Initialize()

return CraftingEvents