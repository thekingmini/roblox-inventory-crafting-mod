--[[
    ItemDatabase.lua
    Comprehensive item database for the Roblox inventory and crafting system
    Contains all items, their properties, rarity tiers, and metadata
]]

local ItemDatabase = {}

-- Asset Rarity System
ItemDatabase.RarityTiers = {
    Standard = {
        Name = "Standard",
        Color = Color3.fromRGB(128, 128, 128), -- Grey
        Value = 1
    },
    Rare = {
        Name = "Rare", 
        Color = Color3.fromRGB(0, 100, 255), -- Blue
        Value = 2
    },
    Unique = {
        Name = "Unique",
        Color = Color3.fromRGB(128, 0, 255), -- Purple
        Value = 3
    },
    Elite = {
        Name = "Elite",
        Color = Color3.fromRGB(255, 165, 0), -- Orange
        Value = 4
    },
    Epic = {
        Name = "Epic",
        Color = Color3.fromRGB(255, 215, 0), -- Gold
        Value = 5
    },
    Legendary = {
        Name = "Legendary",
        Color = Color3.fromRGB(255, 0, 0), -- Red
        Value = 6
    }
}

-- Item Categories
ItemDatabase.Categories = {
    WEAPON = "Weapon",
    ARMOR = "Armor", 
    RING = "Ring",
    CONSUMABLE = "Consumable",
    MATERIAL = "Material",
    TOOL = "Tool",
    CURRENCY = "Currency",
    BOOST = "Boost",
    JOB_ITEM = "JobItem",
    AMMO = "Ammo"
}

-- Equipment Slots
ItemDatabase.EquipmentSlots = {
    WEAPON = "Weapon",
    ARMOR = "Armor",
    RING_1 = "Ring1",
    RING_2 = "Ring2"
}

-- Base Item Template
local function createBaseItem(id, name, category, rarity, description, stackable, maxStack)
    return {
        ID = id,
        Name = name,
        Category = category,
        Rarity = rarity,
        Description = description or "",
        Stackable = stackable or false,
        MaxStack = maxStack or 1,
        Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png", -- Default icon
        Value = 0,
        Level = 1,
        Stats = {},
        Requirements = {},
        Effects = {},
        Metadata = {}
    }
end

-- Weapons Database
ItemDatabase.Weapons = {
    ["basic_pistol"] = createBaseItem(
        "basic_pistol",
        "Basic Pistol",
        ItemDatabase.Categories.WEAPON,
        ItemDatabase.RarityTiers.Standard,
        "A standard issue pistol for law enforcement."
    ),
    ["enhanced_rifle"] = createBaseItem(
        "enhanced_rifle", 
        "Enhanced Rifle",
        ItemDatabase.Categories.WEAPON,
        ItemDatabase.RarityTiers.Rare,
        "Military-grade rifle with enhanced accuracy."
    ),
    ["elite_smg"] = createBaseItem(
        "elite_smg",
        "Elite SMG", 
        ItemDatabase.Categories.WEAPON,
        ItemDatabase.RarityTiers.Elite,
        "High-rate submachine gun for close combat."
    )
}

-- Armor Database
ItemDatabase.Armor = {
    ["kevlar_vest"] = createBaseItem(
        "kevlar_vest",
        "Kevlar Vest",
        ItemDatabase.Categories.ARMOR,
        ItemDatabase.RarityTiers.Standard,
        "Standard protection vest."
    ),
    ["tactical_armor"] = createBaseItem(
        "tactical_armor",
        "Tactical Armor",
        ItemDatabase.Categories.ARMOR, 
        ItemDatabase.RarityTiers.Rare,
        "Advanced tactical protection gear."
    ),
    ["elite_armor"] = createBaseItem(
        "elite_armor",
        "Elite Armor",
        ItemDatabase.Categories.ARMOR,
        ItemDatabase.RarityTiers.Elite,
        "Top-tier protection for elite operatives."
    )
}

-- Rings Database  
ItemDatabase.Rings = {
    ["health_ring"] = createBaseItem(
        "health_ring",
        "Health Ring",
        ItemDatabase.Categories.RING,
        ItemDatabase.RarityTiers.Rare,
        "Increases maximum health."
    ),
    ["damage_ring"] = createBaseItem(
        "damage_ring", 
        "Damage Ring",
        ItemDatabase.Categories.RING,
        ItemDatabase.RarityTiers.Rare,
        "Increases weapon damage output."
    ),
    ["legendary_ring"] = createBaseItem(
        "legendary_ring",
        "Legendary Ring",
        ItemDatabase.Categories.RING,
        ItemDatabase.RarityTiers.Legendary,
        "Provides massive stat bonuses."
    )
}

-- Ingots and Materials
ItemDatabase.Materials = {
    ["iron_ingot"] = createBaseItem(
        "iron_ingot",
        "Iron Ingot",
        ItemDatabase.Categories.MATERIAL,
        ItemDatabase.RarityTiers.Standard,
        "Basic crafting material.",
        true,
        64
    ),
    ["steel_ingot"] = createBaseItem(
        "steel_ingot", 
        "Steel Ingot",
        ItemDatabase.Categories.MATERIAL,
        ItemDatabase.RarityTiers.Rare,
        "Refined metal for advanced crafting.",
        true,
        64
    ),
    ["titanium_ingot"] = createBaseItem(
        "titanium_ingot",
        "Titanium Ingot", 
        ItemDatabase.Categories.MATERIAL,
        ItemDatabase.RarityTiers.Unique,
        "High-grade material for elite equipment.",
        true,
        64
    ),
    ["mithril_ingot"] = createBaseItem(
        "mithril_ingot",
        "Mithril Ingot",
        ItemDatabase.Categories.MATERIAL,
        ItemDatabase.RarityTiers.Epic,
        "Rare magical metal.",
        true,
        64
    ),
    ["adamantium_ingot"] = createBaseItem(
        "adamantium_ingot",
        "Adamantium Ingot",
        ItemDatabase.Categories.MATERIAL,
        ItemDatabase.RarityTiers.Legendary,
        "The strongest known material.",
        true,
        64
    ),
    ["crystal_core"] = createBaseItem(
        "crystal_core",
        "Crystal Core",
        ItemDatabase.Categories.MATERIAL,
        ItemDatabase.RarityTiers.Epic,
        "Crystallized energy core.",
        true,
        32
    )
}

-- Job Items
ItemDatabase.JobItems = {
    ["lockpick"] = createBaseItem(
        "lockpick",
        "Lockpick",
        ItemDatabase.Categories.JOB_ITEM,
        ItemDatabase.RarityTiers.Standard,
        "Tool for bypassing locks.",
        true,
        10
    ),
    ["hacking_device"] = createBaseItem(
        "hacking_device",
        "Hacking Device", 
        ItemDatabase.Categories.JOB_ITEM,
        ItemDatabase.RarityTiers.Rare,
        "Advanced electronic infiltration tool."
    ),
    ["money_printer"] = createBaseItem(
        "money_printer",
        "Money Printer",
        ItemDatabase.Categories.JOB_ITEM,
        ItemDatabase.RarityTiers.Unique,
        "Generates passive income."
    )
}

-- Ammo Types
ItemDatabase.Ammo = {
    ["pistol_ammo"] = createBaseItem(
        "pistol_ammo",
        "Pistol Ammo",
        ItemDatabase.Categories.AMMO,
        ItemDatabase.RarityTiers.Standard,
        "Standard pistol ammunition.",
        true,
        100
    ),
    ["rifle_ammo"] = createBaseItem(
        "rifle_ammo",
        "Rifle Ammo", 
        ItemDatabase.Categories.AMMO,
        ItemDatabase.RarityTiers.Standard,
        "High-velocity rifle rounds.",
        true,
        100
    ),
    ["smg_ammo"] = createBaseItem(
        "smg_ammo",
        "SMG Ammo",
        ItemDatabase.Categories.AMMO,
        ItemDatabase.RarityTiers.Standard,
        "Compact submachine gun rounds.",
        true,
        100
    ),
    ["shotgun_ammo"] = createBaseItem(
        "shotgun_ammo",
        "Shotgun Ammo",
        ItemDatabase.Categories.AMMO,
        ItemDatabase.RarityTiers.Standard,
        "Spreading shotgun shells.",
        true,
        50
    )
}

-- Boosts and Consumables
ItemDatabase.Boosts = {
    ["health_boost"] = createBaseItem(
        "health_boost",
        "Health Boost",
        ItemDatabase.Categories.BOOST,
        ItemDatabase.RarityTiers.Rare,
        "Temporarily increases maximum health.",
        true,
        5
    ),
    ["armor_boost"] = createBaseItem(
        "armor_boost",
        "Armor Boost",
        ItemDatabase.Categories.BOOST,
        ItemDatabase.RarityTiers.Rare,
        "Temporarily increases armor rating.",
        true,
        5
    ),
    ["speed_boost"] = createBaseItem(
        "speed_boost",
        "Speed Boost",
        ItemDatabase.Categories.BOOST,
        ItemDatabase.RarityTiers.Rare,
        "Temporarily increases movement speed.",
        true,
        5
    ),
    ["xp_talisman"] = createBaseItem(
        "xp_talisman",
        "XP Talisman",
        ItemDatabase.Categories.BOOST,
        ItemDatabase.RarityTiers.Epic,
        "Increases experience gain rate."
    ),
    ["lucky_charm"] = createBaseItem(
        "lucky_charm",
        "Lucky Charm",
        ItemDatabase.Categories.BOOST,
        ItemDatabase.RarityTiers.Epic,
        "Increases success rates and rare drops."
    )
}

-- Combine all items into master database
ItemDatabase.Items = {}
for category, items in pairs({
    ItemDatabase.Weapons,
    ItemDatabase.Armor, 
    ItemDatabase.Rings,
    ItemDatabase.Materials,
    ItemDatabase.JobItems,
    ItemDatabase.Ammo,
    ItemDatabase.Boosts
}) do
    for id, item in pairs(items) do
        ItemDatabase.Items[id] = item
    end
end

-- Utility Functions
function ItemDatabase:GetItem(itemId)
    return self.Items[itemId]
end

function ItemDatabase:GetItemsByCategory(category)
    local items = {}
    for id, item in pairs(self.Items) do
        if item.Category == category then
            items[id] = item
        end
    end
    return items
end

function ItemDatabase:GetItemsByRarity(rarity)
    local items = {}
    for id, item in pairs(self.Items) do
        if item.Rarity == rarity then
            items[id] = item
        end
    end
    return items
end

function ItemDatabase:IsValidItem(itemId)
    return self.Items[itemId] ~= nil
end

function ItemDatabase:CanStack(itemId)
    local item = self:GetItem(itemId)
    return item and item.Stackable
end

function ItemDatabase:GetMaxStack(itemId)
    local item = self:GetItem(itemId)
    return item and item.MaxStack or 1
end

return ItemDatabase