--[[
    AutoRefinery.lua
    Automatic item upgrading and synthesis system
    Handles equipment enhancement through 3x same level → 1x next level synthesis
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local RecipeDatabase = require(ReplicatedStorage.RecipeDatabase)
local InventoryManager = require(game.ServerStorage.InventoryManager)

local AutoRefinery = {}

-- Auto-refinery configurations
local PlayerConfigurations = {} -- {userId = config}
local ActiveRefineries = {} -- {userId = refinery_data}
local RefineryQueue = {} -- {userId = {items_to_refine}}

-- Upgrade paths and modifiers
local UpgradePaths = {
    -- Weapon modifications (6 levels each)
    WEAPON_DAMAGE = {
        maxLevel = 6,
        baseName = "damage_mod",
        synthesisRatio = 3, -- 3:1 ratio
        successRate = {85, 80, 75, 65, 55, 45}, -- Per level
        materials = {
            {itemId = "steel_ingot", quantity = 1},
            {itemId = "crystal_core", quantity = 1}
        }
    },
    WEAPON_ICE_DAMAGE = {
        maxLevel = 6,
        baseName = "ice_damage_mod",
        synthesisRatio = 3,
        successRate = {80, 75, 70, 60, 50, 40},
        materials = {
            {itemId = "titanium_ingot", quantity = 1},
            {itemId = "crystal_core", quantity = 2}
        }
    },
    WEAPON_FIRE_DAMAGE = {
        maxLevel = 6,
        baseName = "fire_damage_mod",
        synthesisRatio = 3,
        successRate = {80, 75, 70, 60, 50, 40},
        materials = {
            {itemId = "titanium_ingot", quantity = 1},
            {itemId = "crystal_core", quantity = 2}
        }
    },
    WEAPON_ACCURACY = {
        maxLevel = 6,
        baseName = "accuracy_mod",
        synthesisRatio = 3,
        successRate = {90, 85, 80, 70, 60, 50},
        materials = {
            {itemId = "steel_ingot", quantity = 2}
        }
    },
    
    -- Armor modifications (6 levels each)
    ARMOR_HEALTH = {
        maxLevel = 6,
        baseName = "health_mod",
        synthesisRatio = 3,
        successRate = {85, 80, 75, 65, 55, 45},
        materials = {
            {itemId = "steel_ingot", quantity = 2},
            {itemId = "crystal_core", quantity = 1}
        }
    },
    ARMOR_ARMOR = {
        maxLevel = 6,
        baseName = "armor_mod",
        synthesisRatio = 3,
        successRate = {85, 80, 75, 65, 55, 45},
        materials = {
            {itemId = "titanium_ingot", quantity = 1},
            {itemId = "crystal_core", quantity = 1}
        }
    },
    ARMOR_SPEED = {
        maxLevel = 6,
        baseName = "speed_mod",
        synthesisRatio = 3,
        successRate = {80, 75, 70, 60, 50, 40},
        materials = {
            {itemId = "steel_ingot", quantity = 1}
        }
    },
    ARMOR_RESISTANCE = {
        maxLevel = 6,
        baseName = "resistance_mod",
        synthesisRatio = 3,
        successRate = {75, 70, 65, 55, 45, 35},
        materials = {
            {itemId = "mithril_ingot", quantity = 1},
            {itemId = "crystal_core", quantity = 2}
        }
    },
    ARMOR_ABSORPTION = {
        maxLevel = 6,
        baseName = "absorption_mod",
        synthesisRatio = 3,
        successRate = {70, 65, 60, 50, 40, 30},
        materials = {
            {itemId = "adamantium_ingot", quantity = 1},
            {itemId = "crystal_core", quantity = 3}
        }
    }
}

-- Auto-refinery configuration structure
local function createRefineryConfig()
    return {
        enabled = false,
        autoSynthesis = {
            enabled = false,
            maxLevel = 3, -- Auto-synthesize up to level 3
            preserveCount = 1 -- Keep at least 1 of each item
        },
        itemFilters = {
            weapons = true,
            armor = true,
            rings = true,
            modifiers = true
        },
        upgradeSettings = {
            autoUpgrade = false,
            preferredPath = nil,
            stopOnFailure = false,
            maxAttempts = 10
        }
    }
end

-- Initialize auto-refinery system
function AutoRefinery:Initialize()
    print("AutoRefinery system initialized")
    
    -- Start processing loop
    spawn(function()
        while true do
            wait(5) -- Process every 5 seconds
            self:ProcessAutoRefineries()
        end
    end)
end

-- Enable auto-refinery for player
function AutoRefinery:EnableAutoRefinery(player, config)
    local userId = tostring(player.UserId)
    
    config = config or createRefineryConfig()
    config.enabled = true
    
    PlayerConfigurations[userId] = config
    
    if not ActiveRefineries[userId] then
        ActiveRefineries[userId] = {
            lastProcessed = tick(),
            synthesisCount = 0,
            upgradeCount = 0,
            failureCount = 0
        }
    end
    
    print("Enabled auto-refinery for player:", player.Name)
    return true
end

-- Disable auto-refinery for player
function AutoRefinery:DisableAutoRefinery(player)
    local userId = tostring(player.UserId)
    
    if PlayerConfigurations[userId] then
        PlayerConfigurations[userId].enabled = false
    end
    
    print("Disabled auto-refinery for player:", player.Name)
end

-- Process all auto-refineries
function AutoRefinery:ProcessAutoRefineries()
    for userId, config in pairs(PlayerConfigurations) do
        if config.enabled then
            local player = Players:GetPlayerByUserId(tonumber(userId))
            if player then
                self:ProcessPlayerRefinery(player, config)
            end
        end
    end
end

-- Process auto-refinery for specific player
function AutoRefinery:ProcessPlayerRefinery(player, config)
    local userId = tostring(player.UserId)
    local refinery = ActiveRefineries[userId]
    
    if not refinery then return end
    
    -- Check if enough time has passed since last processing
    if tick() - refinery.lastProcessed < 5 then return end
    
    refinery.lastProcessed = tick()
    
    -- Process auto-synthesis
    if config.autoSynthesis.enabled then
        self:ProcessAutoSynthesis(player, config.autoSynthesis)
    end
    
    -- Process auto-upgrade
    if config.upgradeSettings.autoUpgrade then
        self:ProcessAutoUpgrade(player, config.upgradeSettings)
    end
end

-- Process automatic synthesis
function AutoRefinery:ProcessAutoSynthesis(player, synthConfig)
    local inventory = InventoryManager:GetInventory(player)
    if not inventory then return end
    
    -- Find items suitable for synthesis
    local synthesisGroups = self:GroupItemsForSynthesis(inventory, synthConfig)
    
    for itemId, items in pairs(synthesisGroups) do
        if #items >= 3 then -- Need at least 3 items for synthesis
            local keepCount = synthConfig.preserveCount or 1
            local availableForSynthesis = #items - keepCount
            
            if availableForSynthesis >= 3 then
                local synthesisCount = math.floor(availableForSynthesis / 3)
                self:PerformSynthesis(player, itemId, synthesisCount, items)
            end
        end
    end
end

-- Group items suitable for synthesis
function AutoRefinery:GroupItemsForSynthesis(inventory, synthConfig)
    local groups = {}
    local maxLevel = synthConfig.maxLevel or 3
    
    for slotIndex, item in pairs(inventory.Items) do
        local itemData = ItemDatabase:GetItem(item.itemId)
        if not itemData then continue end
        
        -- Check if item is eligible for synthesis
        if self:IsItemSynthesizable(itemData, item, maxLevel) then
            local baseId = self:GetBaseItemId(item.itemId)
            
            if not groups[baseId] then
                groups[baseId] = {}
            end
            
            table.insert(groups[baseId], {
                slotIndex = slotIndex,
                item = item,
                level = self:GetItemLevel(item)
            })
        end
    end
    
    return groups
end

-- Check if item is synthesizable
function AutoRefinery:IsItemSynthesizable(itemData, item, maxLevel)
    -- Check item category
    if itemData.Category ~= ItemDatabase.Categories.MATERIAL and
       not itemData.ID:match("_mod_") then
        return false
    end
    
    -- Check current level
    local itemLevel = self:GetItemLevel(item)
    return itemLevel < maxLevel
end

-- Perform synthesis
function AutoRefinery:PerformSynthesis(player, baseItemId, synthesisCount, items)
    local userId = tostring(player.UserId)
    
    for i = 1, synthesisCount do
        -- Take 3 items of the same level
        local sourceItems = {}
        
        for j = 1, 3 do
            if #items > 0 then
                table.insert(sourceItems, table.remove(items, 1))
            end
        end
        
        if #sourceItems == 3 then
            local success = self:AttemptSynthesis(player, sourceItems)
            
            if success then
                ActiveRefineries[userId].synthesisCount = ActiveRefineries[userId].synthesisCount + 1
                print(string.format("Auto-synthesis successful for %s: %s", player.Name, baseItemId))
            else
                ActiveRefineries[userId].failureCount = ActiveRefineries[userId].failureCount + 1
                print(string.format("Auto-synthesis failed for %s: %s", player.Name, baseItemId))
            end
        end
    end
end

-- Attempt synthesis of 3 items
function AutoRefinery:AttemptSynthesis(player, sourceItems)
    if #sourceItems ~= 3 then return false end
    
    local baseItem = sourceItems[1].item
    local currentLevel = self:GetItemLevel(baseItem)
    local upgradePath = self:GetUpgradePath(baseItem.itemId)
    
    if not upgradePath then return false end
    
    -- Check if all items are the same
    for _, sourceItem in pairs(sourceItems) do
        if sourceItem.item.itemId ~= baseItem.itemId then
            return false
        end
    end
    
    -- Calculate success rate
    local successRate = upgradePath.successRate[currentLevel] or 50
    successRate = self:ApplyLuckModifiers(player, successRate)
    
    -- Remove source items
    for _, sourceItem in pairs(sourceItems) do
        InventoryManager:RemoveFromSlot(tostring(player.UserId), sourceItem.slotIndex, 1)
    end
    
    -- Roll for success
    local roll = math.random(1, 100)
    if roll <= successRate then
        -- Success: Create upgraded item
        local nextLevelItemId = self:GetNextLevelItemId(baseItem.itemId)
        if nextLevelItemId then
            InventoryManager:AddItem(player, nextLevelItemId, 1)
            return true
        end
    end
    
    -- Failure: Items are lost
    return false
end

-- Process automatic upgrading
function AutoRefinery:ProcessAutoUpgrade(player, upgradeConfig)
    local inventory = InventoryManager:GetInventory(player)
    if not inventory then return end
    
    -- Find equipment items suitable for upgrading
    local upgradeableItems = self:FindUpgradeableItems(inventory)
    
    for _, itemInfo in pairs(upgradeableItems) do
        if upgradeConfig.maxAttempts > 0 then
            local success = self:AttemptItemUpgrade(player, itemInfo, upgradeConfig)
            
            if success then
                ActiveRefineries[tostring(player.UserId)].upgradeCount = 
                    ActiveRefineries[tostring(player.UserId)].upgradeCount + 1
            else
                ActiveRefineries[tostring(player.UserId)].failureCount = 
                    ActiveRefineries[tostring(player.UserId)].failureCount + 1
                
                if upgradeConfig.stopOnFailure then
                    break
                end
            end
            
            upgradeConfig.maxAttempts = upgradeConfig.maxAttempts - 1
        end
    end
end

-- Find items suitable for upgrading
function AutoRefinery:FindUpgradeableItems(inventory)
    local upgradeableItems = {}
    
    for slotIndex, item in pairs(inventory.Items) do
        local itemData = ItemDatabase:GetItem(item.itemId)
        if not itemData then continue end
        
        -- Check if item can be upgraded
        if itemData.Category == ItemDatabase.Categories.WEAPON or
           itemData.Category == ItemDatabase.Categories.ARMOR then
            
            table.insert(upgradeableItems, {
                slotIndex = slotIndex,
                item = item,
                itemData = itemData
            })
        end
    end
    
    return upgradeableItems
end

-- Attempt to upgrade an item
function AutoRefinery:AttemptItemUpgrade(player, itemInfo, upgradeConfig)
    local preferredPath = upgradeConfig.preferredPath
    local availablePaths = self:GetAvailableUpgradePaths(itemInfo.itemData.Category)
    
    if not preferredPath then
        -- Choose first available path
        preferredPath = availablePaths[1]
    end
    
    if not preferredPath or not UpgradePaths[preferredPath] then
        return false
    end
    
    local upgradePath = UpgradePaths[preferredPath]
    
    -- Check if player has required materials
    if not self:HasUpgradeMaterials(player, upgradePath) then
        return false
    end
    
    -- Consume materials
    for _, material in pairs(upgradePath.materials) do
        InventoryManager:RemoveItem(player, material.itemId, material.quantity)
    end
    
    -- Calculate success rate for level 1 upgrade
    local successRate = upgradePath.successRate[1] or 50
    successRate = self:ApplyLuckModifiers(player, successRate)
    
    -- Roll for success
    local roll = math.random(1, 100)
    if roll <= successRate then
        -- Success: Add modifier to item or create enhanced version
        self:ApplyUpgradeToItem(player, itemInfo, preferredPath, 1)
        return true
    end
    
    -- Failure: Materials consumed but no upgrade
    return false
end

-- Get available upgrade paths for item category
function AutoRefinery:GetAvailableUpgradePaths(category)
    local paths = {}
    
    if category == ItemDatabase.Categories.WEAPON then
        table.insert(paths, "WEAPON_DAMAGE")
        table.insert(paths, "WEAPON_ICE_DAMAGE")
        table.insert(paths, "WEAPON_FIRE_DAMAGE")
        table.insert(paths, "WEAPON_ACCURACY")
    elseif category == ItemDatabase.Categories.ARMOR then
        table.insert(paths, "ARMOR_HEALTH")
        table.insert(paths, "ARMOR_ARMOR")
        table.insert(paths, "ARMOR_SPEED")
        table.insert(paths, "ARMOR_RESISTANCE")
        table.insert(paths, "ARMOR_ABSORPTION")
    end
    
    return paths
end

-- Check if player has upgrade materials
function AutoRefinery:HasUpgradeMaterials(player, upgradePath)
    for _, material in pairs(upgradePath.materials) do
        local playerAmount = InventoryManager:GetItemCount(player, material.itemId)
        if playerAmount < material.quantity then
            return false
        end
    end
    return true
end

-- Apply upgrade to item
function AutoRefinery:ApplyUpgradeToItem(player, itemInfo, upgradePath, level)
    -- This would modify the item's metadata to include the upgrade
    -- For now, we'll add a modifier item to inventory
    local modifierItemId = UpgradePaths[upgradePath].baseName .. "_" .. level
    
    -- Create modifier item if it doesn't exist in database
    if not ItemDatabase:GetItem(modifierItemId) then
        -- Would create dynamic modifier item here
        print("Created modifier item:", modifierItemId)
    end
    
    InventoryManager:AddItem(player, modifierItemId, 1)
    print(string.format("Applied %s level %d to %s", upgradePath, level, itemInfo.itemData.Name))
end

-- Apply luck modifiers to success rate
function AutoRefinery:ApplyLuckModifiers(player, baseRate)
    local finalRate = baseRate
    
    -- Check for lucky charm
    if InventoryManager:GetItemCount(player, "lucky_charm") > 0 then
        finalRate = finalRate + 15
    end
    
    -- Check for VIP status (placeholder)
    -- if self:IsVIP(player) then
    --     finalRate = finalRate + 20
    -- end
    
    return math.min(100, finalRate)
end

-- Utility functions
function AutoRefinery:GetItemLevel(item)
    -- Extract level from item metadata or ID
    if item.metadata and item.metadata.level then
        return item.metadata.level
    end
    
    -- Parse level from item ID (e.g., "damage_mod_3" = level 3)
    local level = item.itemId:match("_(%d+)$")
    return tonumber(level) or 1
end

function AutoRefinery:GetBaseItemId(itemId)
    -- Remove level suffix to get base ID
    return itemId:gsub("_%d+$", "")
end

function AutoRefinery:GetUpgradePath(itemId)
    -- Determine upgrade path from item ID
    for pathName, path in pairs(UpgradePaths) do
        if itemId:match(path.baseName) then
            return path
        end
    end
    return nil
end

function AutoRefinery:GetNextLevelItemId(itemId)
    local baseId = self:GetBaseItemId(itemId)
    local currentLevel = self:GetItemLevel({itemId = itemId})
    local nextLevel = currentLevel + 1
    
    local upgradePath = self:GetUpgradePath(itemId)
    if upgradePath and nextLevel <= upgradePath.maxLevel then
        return baseId .. "_" .. nextLevel
    end
    
    return nil
end

-- Get auto-refinery status
function AutoRefinery:GetRefineryStatus(player)
    local userId = tostring(player.UserId)
    
    return {
        config = PlayerConfigurations[userId],
        stats = ActiveRefineries[userId],
        queueSize = RefineryQueue[userId] and #RefineryQueue[userId] or 0
    }
end

-- Update auto-refinery configuration
function AutoRefinery:UpdateConfiguration(player, newConfig)
    local userId = tostring(player.UserId)
    
    if PlayerConfigurations[userId] then
        -- Merge configurations
        for key, value in pairs(newConfig) do
            PlayerConfigurations[userId][key] = value
        end
        return true
    end
    
    return false
end

-- Manual synthesis interface
function AutoRefinery:ManualSynthesis(player, sourceSlots)
    if #sourceSlots ~= 3 then
        return false, "Need exactly 3 items for synthesis"
    end
    
    local inventory = InventoryManager:GetInventory(player)
    if not inventory then
        return false, "Invalid inventory"
    end
    
    local sourceItems = {}
    for _, slotIndex in pairs(sourceSlots) do
        local item = inventory.Items[slotIndex]
        if not item then
            return false, "Invalid source slot"
        end
        table.insert(sourceItems, {slotIndex = slotIndex, item = item})
    end
    
    return self:AttemptSynthesis(player, sourceItems), "Synthesis attempted"
end

-- Player event handlers
Players.PlayerAdded:Connect(function(player)
    local userId = tostring(player.UserId)
    PlayerConfigurations[userId] = createRefineryConfig()
    ActiveRefineries[userId] = {
        lastProcessed = tick(),
        synthesisCount = 0,
        upgradeCount = 0,
        failureCount = 0
    }
    RefineryQueue[userId] = {}
end)

Players.PlayerRemoving:Connect(function(player)
    local userId = tostring(player.UserId)
    PlayerConfigurations[userId] = nil
    ActiveRefineries[userId] = nil
    RefineryQueue[userId] = nil
end)

-- Initialize system
AutoRefinery:Initialize()

return AutoRefinery