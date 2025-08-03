--[[
    CraftingManager.lua
    Server-side crafting system manager
    Handles recipe validation, crafting operations, and batch processing
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local RecipeDatabase = require(ReplicatedStorage.RecipeDatabase)
local InventoryManager = require(script.Parent.InventoryManager)

local CraftingManager = {}

-- Active crafting sessions
local ActiveCrafting = {} -- {userId = {recipeId, quantity, startTime, endTime, successRate}}
local CraftingQueue = {} -- {userId = {{recipeId, quantity}, ...}}

-- Crafting cooldowns
local CraftingCooldowns = {} -- {userId = {recipeId = endTime}}

-- Constants
local CRAFTING_COOLDOWN = 1 -- 1 second between crafts
local MAX_BATCH_SIZE = 10
local MAX_QUEUE_SIZE = 50

-- Initialize player crafting data
function CraftingManager:InitializePlayer(player)
    local userId = tostring(player.UserId)
    CraftingQueue[userId] = {}
    CraftingCooldowns[userId] = {}
    print("Initialized crafting for player:", player.Name)
end

-- Start crafting process
function CraftingManager:StartCrafting(player, recipeId, quantity)
    local userId = tostring(player.UserId)
    quantity = quantity or 1
    
    -- Validate inputs
    if not RecipeDatabase:IsValidRecipe(recipeId) then
        return false, "Invalid recipe"
    end
    
    if quantity <= 0 or quantity > MAX_BATCH_SIZE then
        return false, "Invalid quantity"
    end
    
    -- Check if already crafting
    if ActiveCrafting[userId] then
        return false, "Already crafting"
    end
    
    -- Check cooldown
    if self:IsOnCooldown(userId, recipeId) then
        return false, "Recipe on cooldown"
    end
    
    -- Get recipe data
    local recipe = RecipeDatabase:GetRecipe(recipeId)
    local playerLevel = self:GetPlayerLevel(player)
    
    -- Check requirements
    if not self:CanCraft(player, recipeId, quantity) then
        return false, "Requirements not met"
    end
    
    -- Consume materials
    if not self:ConsumeMaterials(player, recipeId, quantity) then
        return false, "Failed to consume materials"
    end
    
    -- Calculate success rate
    local modifiers = self:GetCraftingModifiers(player)
    local successRate = RecipeDatabase:CalculateSuccessRate(recipeId, modifiers)
    
    -- Start crafting session
    local craftingTime = recipe.CraftingTime * quantity
    ActiveCrafting[userId] = {
        recipeId = recipeId,
        quantity = quantity,
        startTime = tick(),
        endTime = tick() + craftingTime,
        successRate = successRate,
        player = player
    }
    
    print(string.format("Player %s started crafting %dx %s", player.Name, quantity, recipe.Name))
    
    -- Schedule completion
    spawn(function()
        wait(craftingTime)
        self:CompleteCrafting(userId)
    end)
    
    return true, "Crafting started"
end

-- Complete crafting process
function CraftingManager:CompleteCrafting(userId)
    local session = ActiveCrafting[userId]
    if not session then return end
    
    local player = session.player
    local recipe = RecipeDatabase:GetRecipe(session.recipeId)
    local successfulCrafts = 0
    
    -- Process each craft attempt
    for i = 1, session.quantity do
        local success = math.random(1, 100) <= session.successRate
        
        if success then
            successfulCrafts = successfulCrafts + 1
            
            -- Give output item
            local success = InventoryManager:AddItem(
                player, 
                recipe.Output.itemId, 
                recipe.Output.quantity
            )
            
            if not success then
                -- Inventory full, try to give later or drop
                self:HandleInventoryFull(player, recipe.Output.itemId, recipe.Output.quantity)
            end
        end
    end
    
    -- Clear active crafting
    ActiveCrafting[userId] = nil
    
    -- Set cooldown
    CraftingCooldowns[userId][session.recipeId] = tick() + CRAFTING_COOLDOWN
    
    print(string.format("Player %s completed crafting: %d/%d successful", 
        player.Name, successfulCrafts, session.quantity))
    
    -- Process next item in queue
    self:ProcessQueue(userId)
    
    -- Fire completion event (will be handled by events system)
    return {
        recipeId = session.recipeId,
        attempted = session.quantity,
        successful = successfulCrafts,
        successRate = session.successRate
    }
end

-- Add to crafting queue
function CraftingManager:AddToQueue(player, recipeId, quantity)
    local userId = tostring(player.UserId)
    
    if not CraftingQueue[userId] then
        CraftingQueue[userId] = {}
    end
    
    if #CraftingQueue[userId] >= MAX_QUEUE_SIZE then
        return false, "Queue is full"
    end
    
    -- Validate recipe and quantity
    if not RecipeDatabase:IsValidRecipe(recipeId) then
        return false, "Invalid recipe"
    end
    
    if quantity <= 0 or quantity > MAX_BATCH_SIZE then
        return false, "Invalid quantity"
    end
    
    -- Add to queue
    table.insert(CraftingQueue[userId], {
        recipeId = recipeId,
        quantity = quantity
    })
    
    -- Start processing if not already crafting
    if not ActiveCrafting[userId] then
        self:ProcessQueue(userId)
    end
    
    return true, "Added to queue"
end

-- Process crafting queue
function CraftingManager:ProcessQueue(userId)
    local queue = CraftingQueue[userId]
    if not queue or #queue == 0 then return end
    
    local player = Players:GetPlayerByUserId(tonumber(userId))
    if not player then return end
    
    -- Get next item from queue
    local nextCraft = table.remove(queue, 1)
    
    -- Start crafting
    local success, message = self:StartCrafting(player, nextCraft.recipeId, nextCraft.quantity)
    
    if not success then
        -- Re-add to front of queue if failed
        table.insert(queue, 1, nextCraft)
    end
end

-- Check if player can craft recipe
function CraftingManager:CanCraft(player, recipeId, quantity)
    local recipe = RecipeDatabase:GetRecipe(recipeId)
    if not recipe then return false end
    
    -- Check player level
    local playerLevel = self:GetPlayerLevel(player)
    if playerLevel < recipe.RequiredLevel then return false end
    
    -- Check materials
    local requiredMaterials = RecipeDatabase:GetRequiredMaterials(recipeId, quantity)
    
    for itemId, requiredAmount in pairs(requiredMaterials) do
        local playerAmount = InventoryManager:GetItemCount(player, itemId)
        if playerAmount < requiredAmount then
            return false
        end
    end
    
    -- Check crafting station (if implemented)
    -- This would check if player has access to required crafting station
    
    return true
end

-- Consume crafting materials
function CraftingManager:ConsumeMaterials(player, recipeId, quantity)
    local requiredMaterials = RecipeDatabase:GetRequiredMaterials(recipeId, quantity)
    
    -- Verify all materials are available first
    for itemId, requiredAmount in pairs(requiredMaterials) do
        local playerAmount = InventoryManager:GetItemCount(player, itemId)
        if playerAmount < requiredAmount then
            return false
        end
    end
    
    -- Consume materials
    for itemId, requiredAmount in pairs(requiredMaterials) do
        local success = InventoryManager:RemoveItem(player, itemId, requiredAmount)
        if not success then
            -- This shouldn't happen if validation was correct
            warn("Failed to consume material:", itemId, "for player:", player.Name)
            return false
        end
    end
    
    return true
end

-- Get crafting modifiers for player
function CraftingManager:GetCraftingModifiers(player)
    local modifiers = {}
    
    -- Check for lucky charm
    if InventoryManager:GetItemCount(player, "lucky_charm") > 0 then
        modifiers.LUCKY_CHARM = true
    end
    
    -- Check player level (high skill bonus)
    local playerLevel = self:GetPlayerLevel(player)
    if playerLevel >= 50 then
        modifiers.HIGH_SKILL = true
    end
    
    -- Check gang bonuses (would integrate with gang system)
    -- modifiers.GANG_BONUS = self:GetGangCraftingBonus(player)
    
    -- Check VIP status (would integrate with VIP system)
    -- modifiers.VIP_BONUS = self:IsVIP(player)
    
    return modifiers
end

-- Get player level (placeholder - would integrate with experience system)
function CraftingManager:GetPlayerLevel(player)
    -- This would integrate with the actual level system
    return player.leaderstats and player.leaderstats.Level.Value or 1
end

-- Check crafting cooldown
function CraftingManager:IsOnCooldown(userId, recipeId)
    local cooldowns = CraftingCooldowns[userId]
    if not cooldowns or not cooldowns[recipeId] then return false end
    
    return tick() < cooldowns[recipeId]
end

-- Get remaining cooldown time
function CraftingManager:GetCooldownTime(userId, recipeId)
    local cooldowns = CraftingCooldowns[userId]
    if not cooldowns or not cooldowns[recipeId] then return 0 end
    
    local remaining = cooldowns[recipeId] - tick()
    return math.max(0, remaining)
end

-- Handle inventory full situation
function CraftingManager:HandleInventoryFull(player, itemId, quantity)
    -- Could implement drop system or mail system here
    warn("Player inventory full, failed to give item:", itemId, "to player:", player.Name)
end

-- Cancel active crafting
function CraftingManager:CancelCrafting(player)
    local userId = tostring(player.UserId)
    local session = ActiveCrafting[userId]
    
    if not session then
        return false, "No active crafting"
    end
    
    -- Calculate refund percentage based on progress
    local elapsed = tick() - session.startTime
    local totalTime = session.endTime - session.startTime
    local progress = elapsed / totalTime
    
    local refundPercentage = math.max(0.5, 1 - progress) -- Minimum 50% refund
    
    -- Refund materials
    local recipe = RecipeDatabase:GetRecipe(session.recipeId)
    local requiredMaterials = RecipeDatabase:GetRequiredMaterials(session.recipeId, session.quantity)
    
    for itemId, amount in pairs(requiredMaterials) do
        local refundAmount = math.floor(amount * refundPercentage)
        if refundAmount > 0 then
            InventoryManager:AddItem(player, itemId, refundAmount)
        end
    end
    
    -- Clear active crafting
    ActiveCrafting[userId] = nil
    
    return true, string.format("Crafting cancelled, %.0f%% materials refunded", refundPercentage * 100)
end

-- Clear crafting queue
function CraftingManager:ClearQueue(player)
    local userId = tostring(player.UserId)
    CraftingQueue[userId] = {}
    return true, "Queue cleared"
end

-- Get crafting status
function CraftingManager:GetCraftingStatus(player)
    local userId = tostring(player.UserId)
    
    return {
        activeCrafting = ActiveCrafting[userId],
        queueSize = CraftingQueue[userId] and #CraftingQueue[userId] or 0,
        queue = CraftingQueue[userId] or {}
    }
end

-- Get available recipes for player
function CraftingManager:GetAvailableRecipes(player)
    local playerLevel = self:GetPlayerLevel(player)
    local unlockedRecipes = {} -- Would integrate with unlock system
    
    return RecipeDatabase:GetAvailableRecipes(playerLevel, unlockedRecipes)
end

-- Player disconnect handler
function CraftingManager:OnPlayerRemoving(player)
    local userId = tostring(player.UserId)
    
    -- Cancel active crafting and refund materials
    if ActiveCrafting[userId] then
        self:CancelCrafting(player)
    end
    
    -- Clear data
    ActiveCrafting[userId] = nil
    CraftingQueue[userId] = nil
    CraftingCooldowns[userId] = nil
end

-- Auto-cleanup for disconnected players
spawn(function()
    while true do
        wait(60) -- Check every minute
        
        for userId, session in pairs(ActiveCrafting) do
            local player = Players:GetPlayerByUserId(tonumber(userId))
            if not player then
                ActiveCrafting[userId] = nil
            end
        end
        
        for userId, queue in pairs(CraftingQueue) do
            local player = Players:GetPlayerByUserId(tonumber(userId))
            if not player then
                CraftingQueue[userId] = nil
            end
        end
        
        for userId, cooldowns in pairs(CraftingCooldowns) do
            local player = Players:GetPlayerByUserId(tonumber(userId))
            if not player then
                CraftingCooldowns[userId] = nil
            end
        end
    end
end)

-- Initialize event connections
Players.PlayerRemoving:Connect(function(player)
    CraftingManager:OnPlayerRemoving(player)
end)

return CraftingManager