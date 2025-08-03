--[[
    BatchCrafting.lua
    Advanced batch crafting system for bulk item production
    Handles large-scale crafting operations with optimization and queue management
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local RecipeDatabase = require(ReplicatedStorage.RecipeDatabase)
local CraftingManager = require(game.ServerStorage.CraftingManager)
local InventoryManager = require(game.ServerStorage.InventoryManager)

local BatchCrafting = {}

-- Batch processing data
local ActiveBatches = {} -- {userId = {batchId = batch_data}}
local BatchQueue = {} -- {userId = {batches}}
local BatchResults = {} -- {userId = {batchId = results}}

-- Constants
local MAX_BATCH_SIZE = 100
local MAX_CONCURRENT_BATCHES = 3
local BATCH_PROCESSING_INTERVAL = 0.5 -- seconds
local MAX_BATCH_DURATION = 3600 -- 1 hour max

-- Batch data structure
local function createBatch(batchId, recipeId, quantity, playerLevel, modifiers)
    return {
        id = batchId,
        recipeId = recipeId,
        totalQuantity = quantity,
        remainingQuantity = quantity,
        processedQuantity = 0,
        successfulQuantity = 0,
        startTime = tick(),
        estimatedEndTime = 0,
        playerLevel = playerLevel,
        modifiers = modifiers or {},
        status = "Queued", -- Queued, Processing, Completed, Cancelled
        results = {
            attempts = 0,
            successes = 0,
            failures = 0,
            outputItems = {}
        }
    }
end

-- Initialize batch crafting system
function BatchCrafting:Initialize()
    print("BatchCrafting system initialized")
    
    -- Start batch processing loop
    spawn(function()
        while true do
            wait(BATCH_PROCESSING_INTERVAL)
            self:ProcessBatches()
        end
    end)
    
    -- Cleanup completed batches
    spawn(function()
        while true do
            wait(300) -- 5 minutes
            self:CleanupCompletedBatches()
        end
    end)
end

-- Start batch crafting
function BatchCrafting:StartBatch(player, recipeId, quantity, options)
    local userId = tostring(player.UserId)
    options = options or {}
    
    -- Validate input
    if not RecipeDatabase:IsValidRecipe(recipeId) then
        return false, "Invalid recipe"
    end
    
    if quantity <= 0 or quantity > MAX_BATCH_SIZE then
        return false, "Invalid quantity (max " .. MAX_BATCH_SIZE .. ")"
    end
    
    -- Check concurrent batch limit
    local activeBatches = self:GetActiveBatchCount(userId)
    if activeBatches >= MAX_CONCURRENT_BATCHES then
        return false, "Maximum concurrent batches reached"
    end
    
    -- Check if player can craft this recipe
    local canCraft, reason = self:ValidateBatchCrafting(player, recipeId, quantity)
    if not canCraft then
        return false, reason
    end
    
    -- Calculate required materials
    local requiredMaterials = RecipeDatabase:GetRequiredMaterials(recipeId, quantity)
    
    -- Verify and consume materials
    if not self:ConsumeAllMaterials(player, requiredMaterials) then
        return false, "Insufficient materials"
    end
    
    -- Create batch
    local batchId = self:GenerateBatchId()
    local playerLevel = self:GetPlayerLevel(player)
    local modifiers = self:GetCraftingModifiers(player)
    
    local batch = createBatch(batchId, recipeId, quantity, playerLevel, modifiers)
    
    -- Calculate estimated completion time
    local recipe = RecipeDatabase:GetRecipe(recipeId)
    local baseTime = recipe.CraftingTime * quantity
    local timeReduction = self:CalculateTimeReduction(modifiers)
    batch.estimatedEndTime = tick() + (baseTime * (1 - timeReduction))
    
    -- Add to queue
    if not BatchQueue[userId] then
        BatchQueue[userId] = {}
    end
    table.insert(BatchQueue[userId], batch)
    
    print(string.format("Started batch crafting for %s: %dx %s (Batch ID: %s)",
        player.Name, quantity, recipe.Name, batchId))
    
    return true, batchId
end

-- Validate batch crafting
function BatchCrafting:ValidateBatchCrafting(player, recipeId, quantity)
    local recipe = RecipeDatabase:GetRecipe(recipeId)
    if not recipe then
        return false, "Recipe not found"
    end
    
    -- Check player level
    local playerLevel = self:GetPlayerLevel(player)
    if playerLevel < recipe.RequiredLevel then
        return false, "Insufficient level"
    end
    
    -- Check materials
    local requiredMaterials = RecipeDatabase:GetRequiredMaterials(recipeId, quantity)
    for itemId, requiredAmount in pairs(requiredMaterials) do
        local playerAmount = InventoryManager:GetItemCount(player, itemId)
        if playerAmount < requiredAmount then
            return false, "Insufficient " .. itemId
        end
    end
    
    -- Check inventory space for output
    local outputItem = recipe.Output
    if not InventoryManager:HasSpace(player, outputItem.itemId, outputItem.quantity * quantity) then
        return false, "Insufficient inventory space"
    end
    
    return true, "Validation passed"
end

-- Consume all materials for batch
function BatchCrafting:ConsumeAllMaterials(player, requiredMaterials)
    -- First, verify all materials are available
    for itemId, requiredAmount in pairs(requiredMaterials) do
        local playerAmount = InventoryManager:GetItemCount(player, itemId)
        if playerAmount < requiredAmount then
            return false
        end
    end
    
    -- Then consume all materials
    for itemId, requiredAmount in pairs(requiredMaterials) do
        local success = InventoryManager:RemoveItem(player, itemId, requiredAmount)
        if not success then
            -- This shouldn't happen if validation was correct
            warn("Failed to consume material during batch crafting:", itemId)
            return false
        end
    end
    
    return true
end

-- Process all active batches
function BatchCrafting:ProcessBatches()
    for userId, batches in pairs(BatchQueue) do
        self:ProcessPlayerBatches(userId, batches)
    end
    
    for userId, activeBatches in pairs(ActiveBatches) do
        for batchId, batch in pairs(activeBatches) do
            self:ProcessBatch(userId, batchId, batch)
        end
    end
end

-- Process batches for a specific player
function BatchCrafting:ProcessPlayerBatches(userId, batches)
    -- Move batches from queue to active if possible
    local activeBatches = ActiveBatches[userId] or {}
    local activeCount = 0
    
    for _ in pairs(activeBatches) do
        activeCount = activeCount + 1
    end
    
    while activeCount < MAX_CONCURRENT_BATCHES and #batches > 0 do
        local batch = table.remove(batches, 1)
        batch.status = "Processing"
        
        if not ActiveBatches[userId] then
            ActiveBatches[userId] = {}
        end
        ActiveBatches[userId][batch.id] = batch
        
        activeCount = activeCount + 1
        
        print("Started processing batch:", batch.id)
    end
end

-- Process individual batch
function BatchCrafting:ProcessBatch(userId, batchId, batch)
    if batch.status ~= "Processing" then return end
    
    -- Check for timeout
    if tick() - batch.startTime > MAX_BATCH_DURATION then
        self:CancelBatch(userId, batchId, "Timeout")
        return
    end
    
    -- Process items in chunks to avoid lag
    local itemsPerCycle = math.min(5, batch.remainingQuantity)
    
    for i = 1, itemsPerCycle do
        if batch.remainingQuantity <= 0 then break end
        
        -- Simulate individual craft attempt
        local success = self:ProcessSingleCraftAttempt(batch)
        
        batch.results.attempts = batch.results.attempts + 1
        batch.remainingQuantity = batch.remainingQuantity - 1
        batch.processedQuantity = batch.processedQuantity + 1
        
        if success then
            batch.results.successes = batch.results.successes + 1
            batch.successfulQuantity = batch.successfulQuantity + 1
            
            -- Add output item to results
            local recipe = RecipeDatabase:GetRecipe(batch.recipeId)
            if recipe then
                local outputId = recipe.Output.itemId
                local outputQuantity = recipe.Output.quantity
                
                if not batch.results.outputItems[outputId] then
                    batch.results.outputItems[outputId] = 0
                end
                batch.results.outputItems[outputId] = batch.results.outputItems[outputId] + outputQuantity
            end
        else
            batch.results.failures = batch.results.failures + 1
        end
    end
    
    -- Check if batch is complete
    if batch.remainingQuantity <= 0 then
        self:CompleteBatch(userId, batchId, batch)
    end
end

-- Process single craft attempt
function BatchCrafting:ProcessSingleCraftAttempt(batch)
    local recipe = RecipeDatabase:GetRecipe(batch.recipeId)
    if not recipe then return false end
    
    -- Calculate success rate with modifiers
    local baseSuccessRate = recipe.BaseSuccessRate
    local finalSuccessRate = self:ApplySuccessRateModifiers(baseSuccessRate, batch.modifiers)
    
    -- Roll for success
    local roll = math.random(1, 100)
    return roll <= finalSuccessRate
end

-- Apply success rate modifiers
function BatchCrafting:ApplySuccessRateModifiers(baseRate, modifiers)
    local finalRate = baseRate
    
    -- Apply each modifier
    for modifierType, value in pairs(modifiers) do
        if RecipeDatabase.LuckModifiers[modifierType] then
            finalRate = finalRate + RecipeDatabase.LuckModifiers[modifierType]
        end
    end
    
    -- Batch crafting bonus (5% bonus for large batches)
    if modifiers.batchSize and modifiers.batchSize >= 50 then
        finalRate = finalRate + 5
    end
    
    return math.min(100, finalRate)
end

-- Complete batch
function BatchCrafting:CompleteBatch(userId, batchId, batch)
    batch.status = "Completed"
    batch.endTime = tick()
    
    -- Give output items to player
    local player = Players:GetPlayerByUserId(tonumber(userId))
    if player then
        self:GiveOutputItems(player, batch)
    end
    
    -- Store results
    if not BatchResults[userId] then
        BatchResults[userId] = {}
    end
    BatchResults[userId][batchId] = batch.results
    
    -- Remove from active batches
    if ActiveBatches[userId] then
        ActiveBatches[userId][batchId] = nil
    end
    
    print(string.format("Completed batch %s: %d/%d successful",
        batchId, batch.results.successes, batch.results.attempts))
    
    -- Notify player (would integrate with events system)
    self:NotifyBatchCompletion(player, batch)
end

-- Give output items to player
function BatchCrafting:GiveOutputItems(player, batch)
    for itemId, quantity in pairs(batch.results.outputItems) do
        local success = InventoryManager:AddItem(player, itemId, quantity)
        if not success then
            -- Handle inventory full situation
            warn("Failed to give batch output items to player:", player.Name)
            -- Could implement a mail system or temporary storage here
        end
    end
end

-- Cancel batch
function BatchCrafting:CancelBatch(userId, batchId, reason)
    reason = reason or "Player request"
    
    local batch = ActiveBatches[userId] and ActiveBatches[userId][batchId]
    if not batch then return false, "Batch not found" end
    
    if batch.status == "Completed" then
        return false, "Batch already completed"
    end
    
    batch.status = "Cancelled"
    batch.endTime = tick()
    
    -- Calculate refund based on progress
    local progressPercent = batch.processedQuantity / batch.totalQuantity
    local refundPercent = math.max(0.5, 1 - progressPercent) -- Minimum 50% refund
    
    -- Refund materials
    local player = Players:GetPlayerByUserId(tonumber(userId))
    if player then
        self:RefundMaterials(player, batch, refundPercent)
        
        -- Give partial output items if any were crafted
        if batch.results.successes > 0 then
            self:GiveOutputItems(player, batch)
        end
    end
    
    -- Remove from active batches
    if ActiveBatches[userId] then
        ActiveBatches[userId][batchId] = nil
    end
    
    print(string.format("Cancelled batch %s (Reason: %s, Refund: %.0f%%)",
        batchId, reason, refundPercent * 100))
    
    return true, "Batch cancelled"
end

-- Refund materials
function BatchCrafting:RefundMaterials(player, batch, refundPercent)
    local recipe = RecipeDatabase:GetRecipe(batch.recipeId)
    if not recipe then return end
    
    local requiredMaterials = RecipeDatabase:GetRequiredMaterials(batch.recipeId, batch.totalQuantity)
    
    for itemId, amount in pairs(requiredMaterials) do
        local refundAmount = math.floor(amount * refundPercent)
        if refundAmount > 0 then
            InventoryManager:AddItem(player, itemId, refundAmount)
        end
    end
end

-- Get active batch count for player
function BatchCrafting:GetActiveBatchCount(userId)
    local count = 0
    
    if ActiveBatches[userId] then
        for _ in pairs(ActiveBatches[userId]) do
            count = count + 1
        end
    end
    
    return count
end

-- Get batch status
function BatchCrafting:GetBatchStatus(userId, batchId)
    -- Check active batches
    if ActiveBatches[userId] and ActiveBatches[userId][batchId] then
        return ActiveBatches[userId][batchId]
    end
    
    -- Check queue
    if BatchQueue[userId] then
        for _, batch in pairs(BatchQueue[userId]) do
            if batch.id == batchId then
                return batch
            end
        end
    end
    
    -- Check results
    if BatchResults[userId] and BatchResults[userId][batchId] then
        return {
            id = batchId,
            status = "Completed",
            results = BatchResults[userId][batchId]
        }
    end
    
    return nil
end

-- Get all batches for player
function BatchCrafting:GetPlayerBatches(userId)
    local batches = {
        active = ActiveBatches[userId] or {},
        queued = BatchQueue[userId] or {},
        completed = BatchResults[userId] or {}
    }
    
    return batches
end

-- Calculate time reduction from modifiers
function BatchCrafting:CalculateTimeReduction(modifiers)
    local reduction = 0
    
    -- VIP bonus (20% time reduction)
    if modifiers.VIP_BONUS then
        reduction = reduction + 0.2
    end
    
    -- Gang bonus (10% time reduction)
    if modifiers.GANG_BONUS then
        reduction = reduction + 0.1
    end
    
    -- High skill bonus (15% time reduction)
    if modifiers.HIGH_SKILL then
        reduction = reduction + 0.15
    end
    
    return math.min(0.5, reduction) -- Max 50% reduction
end

-- Generate unique batch ID
function BatchCrafting:GenerateBatchId()
    return "batch_" .. tostring(tick()) .. "_" .. tostring(math.random(1000, 9999))
end

-- Get player level (placeholder)
function BatchCrafting:GetPlayerLevel(player)
    return player.leaderstats and player.leaderstats.Level.Value or 1
end

-- Get crafting modifiers (placeholder)
function BatchCrafting:GetCraftingModifiers(player)
    local modifiers = {}
    
    -- Check for lucky charm
    if InventoryManager:GetItemCount(player, "lucky_charm") > 0 then
        modifiers.LUCKY_CHARM = true
    end
    
    -- Check player level
    local playerLevel = self:GetPlayerLevel(player)
    if playerLevel >= 50 then
        modifiers.HIGH_SKILL = true
    end
    
    return modifiers
end

-- Notify batch completion
function BatchCrafting:NotifyBatchCompletion(player, batch)
    -- This would integrate with the events system to notify the client
    local recipe = RecipeDatabase:GetRecipe(batch.recipeId)
    local message = string.format("Batch crafting completed: %d/%d %s crafted successfully",
        batch.results.successes, batch.results.attempts, recipe and recipe.Name or "items")
    
    print("Notification for", player.Name, ":", message)
end

-- Cleanup completed batches
function BatchCrafting:CleanupCompletedBatches()
    local currentTime = tick()
    
    for userId, results in pairs(BatchResults) do
        for batchId, result in pairs(results) do
            -- Remove results older than 24 hours
            if result.endTime and currentTime - result.endTime > 86400 then
                results[batchId] = nil
            end
        end
    end
end

-- Player disconnect handler
Players.PlayerRemoving:Connect(function(player)
    local userId = tostring(player.UserId)
    
    -- Cancel active batches and refund materials
    if ActiveBatches[userId] then
        for batchId, batch in pairs(ActiveBatches[userId]) do
            BatchCrafting:CancelBatch(userId, batchId, "Player disconnected")
        end
    end
    
    -- Clear data
    ActiveBatches[userId] = nil
    BatchQueue[userId] = nil
    BatchResults[userId] = nil
end)

-- Initialize system
BatchCrafting:Initialize()

return BatchCrafting