-- ItemDatabase.lua
-- Manages all item definitions and properties for the crafting system

local ItemDatabase = {}

-- Item type definitions
ItemDatabase.ItemTypes = {
	BLUEPRINT = "blueprint",
	MATERIAL = "material", 
	TOOL = "tool",
	WEAPON = "weapon",
	CONSUMABLE = "consumable",
	REFINED = "refined"
}

-- Item rarity definitions
ItemDatabase.Rarity = {
	COMMON = 1,
	UNCOMMON = 2, 
	RARE = 3,
	EPIC = 4,
	LEGENDARY = 5
}

-- Database of all items
ItemDatabase.Items = {
	-- Blueprints
	["iron_sword_blueprint"] = {
		id = "iron_sword_blueprint",
		name = "Iron Sword Blueprint",
		type = ItemDatabase.ItemTypes.BLUEPRINT,
		rarity = ItemDatabase.Rarity.COMMON,
		icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		description = "Blueprint for crafting an iron sword",
		stackable = true,
		maxStack = 10,
		craftsItem = "iron_sword"
	},
	
	["steel_armor_blueprint"] = {
		id = "steel_armor_blueprint", 
		name = "Steel Armor Blueprint",
		type = ItemDatabase.ItemTypes.BLUEPRINT,
		rarity = ItemDatabase.Rarity.UNCOMMON,
		icon = "rbxasset://textures/ui/GuiImagePlaceholder.png", 
		description = "Blueprint for crafting steel armor",
		stackable = true,
		maxStack = 10,
		craftsItem = "steel_armor"
	},
	
	-- Materials
	["iron_ingot"] = {
		id = "iron_ingot",
		name = "Iron Ingot", 
		type = ItemDatabase.ItemTypes.MATERIAL,
		rarity = ItemDatabase.Rarity.COMMON,
		icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		description = "Basic iron ingot for crafting",
		stackable = true,
		maxStack = 100,
		refinable = true,
		refinesTo = "steel_ingot"
	},
	
	["wood"] = {
		id = "wood",
		name = "Wood",
		type = ItemDatabase.ItemTypes.MATERIAL,
		rarity = ItemDatabase.Rarity.COMMON, 
		icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		description = "Basic wood for crafting",
		stackable = true,
		maxStack = 100
	},
	
	["leather"] = {
		id = "leather",
		name = "Leather",
		type = ItemDatabase.ItemTypes.MATERIAL,
		rarity = ItemDatabase.Rarity.COMMON,
		icon = "rbxasset://textures/ui/GuiImagePlaceholder.png", 
		description = "Leather for armor crafting",
		stackable = true,
		maxStack = 50
	},
	
	["steel_ingot"] = {
		id = "steel_ingot",
		name = "Steel Ingot",
		type = ItemDatabase.ItemTypes.REFINED,
		rarity = ItemDatabase.Rarity.UNCOMMON,
		icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		description = "Refined steel ingot",
		stackable = true,
		maxStack = 50
	},
	
	-- Crafted Items
	["iron_sword"] = {
		id = "iron_sword",
		name = "Iron Sword",
		type = ItemDatabase.ItemTypes.WEAPON,
		rarity = ItemDatabase.Rarity.COMMON,
		icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		description = "A basic iron sword",
		stackable = false,
		maxStack = 1,
		durability = 100,
		damage = 25
	},
	
	["steel_armor"] = {
		id = "steel_armor",
		name = "Steel Armor",
		type = ItemDatabase.ItemTypes.TOOL,
		rarity = ItemDatabase.Rarity.UNCOMMON,
		icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		description = "Protective steel armor",
		stackable = false,
		maxStack = 1, 
		durability = 200,
		defense = 50
	}
}

-- Get item by ID
function ItemDatabase:GetItem(itemId)
	return self.Items[itemId]
end

-- Check if item exists
function ItemDatabase:ItemExists(itemId)
	return self.Items[itemId] ~= nil
end

-- Get all items of a specific type
function ItemDatabase:GetItemsByType(itemType)
	local result = {}
	for id, item in pairs(self.Items) do
		if item.type == itemType then
			result[id] = item
		end
	end
	return result
end

-- Get all blueprint items
function ItemDatabase:GetBlueprints()
	return self:GetItemsByType(self.ItemTypes.BLUEPRINT)
end

-- Get all material items
function ItemDatabase:GetMaterials()
	return self:GetItemsByType(self.ItemTypes.MATERIAL)
end

-- Check if item can be stacked
function ItemDatabase:IsStackable(itemId)
	local item = self:GetItem(itemId)
	return item and item.stackable or false
end

-- Get max stack size for item
function ItemDatabase:GetMaxStack(itemId)
	local item = self:GetItem(itemId)
	return item and item.maxStack or 1
end

-- Check if item can be refined
function ItemDatabase:IsRefinable(itemId)
	local item = self:GetItem(itemId)
	return item and item.refinable or false
end

-- Get what item refines to
function ItemDatabase:GetRefinedItem(itemId)
	local item = self:GetItem(itemId)
	return item and item.refinesTo
end

return ItemDatabase