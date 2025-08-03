--[[
    AntiDuplication.lua
    Comprehensive anti-duplication system for item security
    Prevents item duplication exploits through multiple validation layers
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local AntiDuplication = {}

-- Data Store for checksums and audit logs
local ChecksumDataStore = DataStoreService:GetDataStore("ItemChecksums")
local AuditLogDataStore = DataStoreService:GetDataStore("DuplicationAuditLog")

-- Player data tracking
local PlayerItemChecksums = {} -- {userId = {slotIndex = checksum}}
local PlayerTransactionLog = {} -- {userId = {transactions}}
local PlayerSuspiciousActivity = {} -- {userId = suspiciousCount}

-- Constants
local MAX_TRANSACTIONS_PER_MINUTE = 30
local SUSPICIOUS_ACTIVITY_THRESHOLD = 5
local CHECKSUM_UPDATE_INTERVAL = 10 -- seconds
local TRANSACTION_LOG_SIZE = 100

-- Initialize anti-duplication system
function AntiDuplication:Initialize()
    print("AntiDuplication system initialized")
    
    -- Start periodic checksum verification
    spawn(function()
        while true do
            wait(CHECKSUM_UPDATE_INTERVAL)
            self:PerformPeriodicChecks()
        end
    end)
    
    -- Cleanup old transaction logs
    spawn(function()
        while true do
            wait(300) -- 5 minutes
            self:CleanupOldTransactions()
        end
    end)
end

-- Generate item checksum
function AntiDuplication:GenerateItemChecksum(itemData, slotIndex, timestamp)
    local checksumData = {
        itemId = itemData.itemId,
        quantity = itemData.quantity,
        metadata = itemData.metadata or {},
        slotIndex = slotIndex,
        timestamp = timestamp or tick()
    }
    
    local jsonString = HttpService:JSONEncode(checksumData)
    return HttpService:GenerateGUID(false), jsonString
end

-- Validate item checksum
function AntiDuplication:ValidateItemChecksum(userId, slotIndex, itemData)
    local userChecksums = PlayerItemChecksums[userId]
    if not userChecksums then return false end
    
    local storedChecksum = userChecksums[slotIndex]
    if not storedChecksum then return false end
    
    local currentChecksum, _ = self:GenerateItemChecksum(itemData, slotIndex)
    return storedChecksum.hash == currentChecksum
end

-- Update item checksum
function AntiDuplication:UpdateItemChecksum(userId, slotIndex, itemData)
    if not PlayerItemChecksums[userId] then
        PlayerItemChecksums[userId] = {}
    end
    
    local checksum, jsonData = self:GenerateItemChecksum(itemData, slotIndex)
    
    PlayerItemChecksums[userId][slotIndex] = {
        hash = checksum,
        data = jsonData,
        timestamp = tick()
    }
    
    -- Save to persistent storage periodically
    self:SaveChecksumsAsync(userId)
end

-- Remove item checksum
function AntiDuplication:RemoveItemChecksum(userId, slotIndex)
    if PlayerItemChecksums[userId] then
        PlayerItemChecksums[userId][slotIndex] = nil
    end
end

-- Validate inventory operation
function AntiDuplication:ValidateInventoryOperation(player, operation, data)
    local userId = tostring(player.UserId)
    
    -- Check transaction rate limiting
    if not self:CheckTransactionRateLimit(userId) then
        self:LogSuspiciousActivity(userId, "ExcessiveTransactionRate", {
            operation = operation,
            timestamp = tick()
        })
        return false, "Transaction rate limit exceeded"
    end
    
    -- Log transaction
    self:LogTransaction(userId, operation, data)
    
    -- Validate specific operations
    if operation == "MoveItem" then
        return self:ValidateMoveItem(player, data)
    elseif operation == "SplitStack" then
        return self:ValidateSplitStack(player, data)
    elseif operation == "MergeStack" then
        return self:ValidateMergeStack(player, data)
    elseif operation == "DeleteItem" then
        return self:ValidateDeleteItem(player, data)
    end
    
    return true, "Operation validated"
end

-- Validate move item operation
function AntiDuplication:ValidateMoveItem(player, data)
    local userId = tostring(player.UserId)
    local fromSlot = data.fromSlot
    local toSlot = data.toSlot
    local quantity = data.quantity
    
    -- Get current inventory state
    local InventoryManager = require(game.ServerStorage.InventoryManager)
    local inventory = InventoryManager:GetInventory(player)
    
    if not inventory then
        return false, "Invalid inventory"
    end
    
    local fromItem = inventory.Items[fromSlot]
    if not fromItem then
        return false, "Source slot is empty"
    end
    
    -- Validate checksum
    if not self:ValidateItemChecksum(userId, fromSlot, fromItem) then
        self:LogSuspiciousActivity(userId, "InvalidChecksum", {
            operation = "MoveItem",
            fromSlot = fromSlot,
            itemId = fromItem.itemId,
            timestamp = tick()
        })
        return false, "Item checksum validation failed"
    end
    
    -- Validate quantity
    if quantity > fromItem.quantity then
        return false, "Invalid quantity"
    end
    
    -- Check if this is a suspicious move pattern
    if self:IsSuspiciousMovePattern(userId, fromSlot, toSlot) then
        self:LogSuspiciousActivity(userId, "SuspiciousMovePattern", {
            fromSlot = fromSlot,
            toSlot = toSlot,
            timestamp = tick()
        })
        return false, "Suspicious move pattern detected"
    end
    
    return true, "Move operation validated"
end

-- Validate stack splitting
function AntiDuplication:ValidateSplitStack(player, data)
    local userId = tostring(player.UserId)
    local sourceSlot = data.sourceSlot
    local targetSlot = data.targetSlot
    local splitQuantity = data.quantity
    
    local InventoryManager = require(game.ServerStorage.InventoryManager)
    local inventory = InventoryManager:GetInventory(player)
    
    local sourceItem = inventory.Items[sourceSlot]
    if not sourceItem then
        return false, "Source slot is empty"
    end
    
    -- Validate source checksum
    if not self:ValidateItemChecksum(userId, sourceSlot, sourceItem) then
        return false, "Source item checksum validation failed"
    end
    
    -- Validate split quantity
    if splitQuantity >= sourceItem.quantity or splitQuantity <= 0 then
        return false, "Invalid split quantity"
    end
    
    -- Check if item is stackable
    local itemData = ItemDatabase:GetItem(sourceItem.itemId)
    if not itemData or not itemData.Stackable then
        return false, "Item is not stackable"
    end
    
    -- Target slot must be empty
    if inventory.Items[targetSlot] then
        return false, "Target slot is not empty"
    end
    
    return true, "Split operation validated"
end

-- Validate stack merging
function AntiDuplication:ValidateMergeStack(player, data)
    local userId = tostring(player.UserId)
    local sourceSlot = data.sourceSlot
    local targetSlot = data.targetSlot
    
    local InventoryManager = require(game.ServerStorage.InventoryManager)
    local inventory = InventoryManager:GetInventory(player)
    
    local sourceItem = inventory.Items[sourceSlot]
    local targetItem = inventory.Items[targetSlot]
    
    if not sourceItem or not targetItem then
        return false, "Invalid source or target item"
    end
    
    -- Validate checksums
    if not self:ValidateItemChecksum(userId, sourceSlot, sourceItem) or
       not self:ValidateItemChecksum(userId, targetSlot, targetItem) then
        return false, "Item checksum validation failed"
    end
    
    -- Items must be the same type
    if sourceItem.itemId ~= targetItem.itemId then
        return false, "Cannot merge different items"
    end
    
    -- Check if stackable
    local itemData = ItemDatabase:GetItem(sourceItem.itemId)
    if not itemData or not itemData.Stackable then
        return false, "Item is not stackable"
    end
    
    -- Check stack limit
    local totalQuantity = sourceItem.quantity + targetItem.quantity
    if totalQuantity > itemData.MaxStack then
        return false, "Would exceed stack limit"
    end
    
    return true, "Merge operation validated"
end

-- Validate item deletion
function AntiDuplication:ValidateDeleteItem(player, data)
    local userId = tostring(player.UserId)
    local slotIndex = data.slotIndex
    
    local InventoryManager = require(game.ServerStorage.InventoryManager)
    local inventory = InventoryManager:GetInventory(player)
    
    local item = inventory.Items[slotIndex]
    if not item then
        return false, "Slot is empty"
    end
    
    -- Validate checksum
    if not self:ValidateItemChecksum(userId, slotIndex, item) then
        return false, "Item checksum validation failed"
    end
    
    -- Log deletion for audit
    self:LogItemDeletion(userId, item, slotIndex)
    
    return true, "Delete operation validated"
end

-- Transaction rate limiting
function AntiDuplication:CheckTransactionRateLimit(userId)
    if not PlayerTransactionLog[userId] then
        PlayerTransactionLog[userId] = {}
    end
    
    local currentTime = tick()
    local transactions = PlayerTransactionLog[userId]
    local recentTransactions = 0
    
    -- Count transactions in the last minute
    for i = #transactions, 1, -1 do
        if currentTime - transactions[i].timestamp <= 60 then
            recentTransactions = recentTransactions + 1
        else
            break
        end
    end
    
    return recentTransactions < MAX_TRANSACTIONS_PER_MINUTE
end

-- Log transaction
function AntiDuplication:LogTransaction(userId, operation, data)
    if not PlayerTransactionLog[userId] then
        PlayerTransactionLog[userId] = {}
    end
    
    local transaction = {
        operation = operation,
        data = data,
        timestamp = tick()
    }
    
    table.insert(PlayerTransactionLog[userId], transaction)
    
    -- Keep only recent transactions
    local transactions = PlayerTransactionLog[userId]
    if #transactions > TRANSACTION_LOG_SIZE then
        table.remove(transactions, 1)
    end
end

-- Detect suspicious move patterns
function AntiDuplication:IsSuspiciousMovePattern(userId, fromSlot, toSlot)
    local transactions = PlayerTransactionLog[userId]
    if not transactions then return false end
    
    local currentTime = tick()
    local recentMoves = {}
    
    -- Collect recent move operations
    for i = #transactions, 1, -1 do
        local transaction = transactions[i]
        if currentTime - transaction.timestamp <= 30 and transaction.operation == "MoveItem" then
            table.insert(recentMoves, {
                from = transaction.data.fromSlot,
                to = transaction.data.toSlot,
                timestamp = transaction.timestamp
            })
        else
            break
        end
    end
    
    -- Check for rapid back-and-forth movements (duplication attempt)
    if #recentMoves >= 4 then
        local pattern1 = {from = fromSlot, to = toSlot}
        local pattern2 = {from = toSlot, to = fromSlot}
        
        local patternCount = 0
        for _, move in pairs(recentMoves) do
            if (move.from == pattern1.from and move.to == pattern1.to) or
               (move.from == pattern2.from and move.to == pattern2.to) then
                patternCount = patternCount + 1
            end
        end
        
        if patternCount >= 3 then
            return true
        end
    end
    
    return false
end

-- Log suspicious activity
function AntiDuplication:LogSuspiciousActivity(userId, activityType, details)
    if not PlayerSuspiciousActivity[userId] then
        PlayerSuspiciousActivity[userId] = 0
    end
    
    PlayerSuspiciousActivity[userId] = PlayerSuspiciousActivity[userId] + 1
    
    local logEntry = {
        userId = userId,
        activityType = activityType,
        details = details,
        timestamp = tick(),
        suspiciousCount = PlayerSuspiciousActivity[userId]
    }
    
    -- Log to console
    warn("Suspicious activity detected:", userId, activityType, HttpService:JSONEncode(details))
    
    -- Save to audit log
    spawn(function()
        pcall(function()
            local key = userId .. "_" .. tostring(tick())
            AuditLogDataStore:SetAsync(key, logEntry)
        end)
    end)
    
    -- Take action if threshold exceeded
    if PlayerSuspiciousActivity[userId] >= SUSPICIOUS_ACTIVITY_THRESHOLD then
        self:HandleSuspiciousPlayer(userId)
    end
end

-- Handle suspicious player
function AntiDuplication:HandleSuspiciousPlayer(userId)
    local player = Players:GetPlayerByUserId(tonumber(userId))
    if not player then return end
    
    warn("Player flagged for suspicious activity:", player.Name, "(" .. userId .. ")")
    
    -- Temporary restrictions
    self:ApplyTemporaryRestrictions(player)
    
    -- Notify administrators
    self:NotifyAdministrators(player, PlayerSuspiciousActivity[userId])
end

-- Apply temporary restrictions
function AntiDuplication:ApplyTemporaryRestrictions(player)
    -- Flag player for restrictions
    player:SetAttribute("InventoryRestricted", true)
    player:SetAttribute("RestrictionTime", tick())
    
    -- Restrictions last for 10 minutes
    spawn(function()
        wait(600)
        if player.Parent then
            player:SetAttribute("InventoryRestricted", nil)
            player:SetAttribute("RestrictionTime", nil)
        end
    end)
end

-- Check if player is restricted
function AntiDuplication:IsPlayerRestricted(player)
    return player:GetAttribute("InventoryRestricted") == true
end

-- Notify administrators
function AntiDuplication:NotifyAdministrators(player, suspiciousCount)
    -- Send notification to administrators
    for _, adminPlayer in pairs(Players:GetPlayers()) do
        if adminPlayer:GetRankInGroup(0) >= 100 then -- Adjust group/rank as needed
            local message = string.format("Player %s (%s) flagged for suspicious activity (%d violations)",
                player.Name, player.UserId, suspiciousCount)
            -- Send admin notification (would integrate with admin system)
        end
    end
end

-- Log item deletion for audit
function AntiDuplication:LogItemDeletion(userId, item, slotIndex)
    local deletionLog = {
        userId = userId,
        itemId = item.itemId,
        quantity = item.quantity,
        slotIndex = slotIndex,
        timestamp = tick()
    }
    
    spawn(function()
        pcall(function()
            local key = "deletion_" .. userId .. "_" .. tostring(tick())
            AuditLogDataStore:SetAsync(key, deletionLog)
        end)
    end)
end

-- Perform periodic checks
function AntiDuplication:PerformPeriodicChecks()
    for _, player in pairs(Players:GetPlayers()) do
        spawn(function()
            self:ValidatePlayerInventory(player)
        end)
    end
end

-- Validate entire player inventory
function AntiDuplication:ValidatePlayerInventory(player)
    local userId = tostring(player.UserId)
    local InventoryManager = require(game.ServerStorage.InventoryManager)
    local inventory = InventoryManager:GetInventory(player)
    
    if not inventory then return end
    
    local checksumErrors = 0
    
    for slotIndex, item in pairs(inventory.Items) do
        if not self:ValidateItemChecksum(userId, slotIndex, item) then
            checksumErrors = checksumErrors + 1
            
            -- Update checksum (might be legitimate change)
            self:UpdateItemChecksum(userId, slotIndex, item)
        end
    end
    
    -- Too many checksum errors might indicate tampering
    if checksumErrors > 5 then
        self:LogSuspiciousActivity(userId, "MultipleChecksumErrors", {
            errorCount = checksumErrors,
            timestamp = tick()
        })
    end
end

-- Save checksums to persistent storage
function AntiDuplication:SaveChecksumsAsync(userId)
    spawn(function()
        pcall(function()
            local checksums = PlayerItemChecksums[userId]
            if checksums then
                ChecksumDataStore:SetAsync(userId, checksums)
            end
        end)
    end)
end

-- Load checksums from persistent storage
function AntiDuplication:LoadChecksumsAsync(userId)
    spawn(function()
        local success, checksums = pcall(function()
            return ChecksumDataStore:GetAsync(userId)
        end)
        
        if success and checksums then
            PlayerItemChecksums[userId] = checksums
        else
            PlayerItemChecksums[userId] = {}
        end
    end)
end

-- Cleanup old transactions
function AntiDuplication:CleanupOldTransactions()
    local currentTime = tick()
    
    for userId, transactions in pairs(PlayerTransactionLog) do
        for i = #transactions, 1, -1 do
            if currentTime - transactions[i].timestamp > 3600 then -- 1 hour
                table.remove(transactions, i)
            end
        end
    end
end

-- Player event handlers
Players.PlayerAdded:Connect(function(player)
    local userId = tostring(player.UserId)
    PlayerTransactionLog[userId] = {}
    PlayerSuspiciousActivity[userId] = 0
    
    -- Load checksums
    AntiDuplication:LoadChecksumsAsync(userId)
end)

Players.PlayerRemoving:Connect(function(player)
    local userId = tostring(player.UserId)
    
    -- Save checksums before player leaves
    AntiDuplication:SaveChecksumsAsync(userId)
    
    -- Cleanup
    PlayerTransactionLog[userId] = nil
    PlayerSuspiciousActivity[userId] = nil
    PlayerItemChecksums[userId] = nil
end)

-- Initialize system
AntiDuplication:Initialize()

return AntiDuplication