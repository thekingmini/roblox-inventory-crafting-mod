# Roblox Inventory & Crafting Mod System

A comprehensive, production-ready inventory and crafting system for Roblox games featuring advanced UI, security systems, and extensive customization options.

## 🎮 Features Overview

### Core Systems
- **5x5 Grid Inventory** with 4 pages (100 total slots)
- **Equipment System** with weapon, armor, and 2 ring slots
- **Blueprint-Based Crafting** with 6 ingot types and synthesis recipes
- **Auto-Refinery System** for automatic item upgrading (3:1 synthesis ratio)
- **Batch Crafting** supporting up to 100 items per batch
- **6-Tier Rarity System** with visual indicators

### Security Features
- **Anti-Duplication System** with checksum validation
- **Exploit Detection** with behavior pattern analysis
- **Transaction Monitoring** with rate limiting
- **Audit Logging** for all operations
- **Automatic Restrictions** for suspicious activity

### User Interface
- **Main Menu** with 5 tabs (CHARACTER, JOBS, SHOP, GANGS, CREDIT SHOP)
- **Advanced Drag & Drop** with visual feedback
- **Comprehensive Tooltips** showing detailed item stats
- **Real-time Progress Tracking** for crafting operations
- **Responsive Design** with smooth animations

### Advanced Features
- **Experience System** (Levels 1-100)
- **Multiple Currency Support**
- **Faction/Gang Integration**
- **Equipment Enhancement** with 6 modification levels
- **Premium Store** with credit-based purchases

## 📁 File Structure

```
ServerStorage/
├── InventoryManager.lua        # Core inventory management
├── CraftingManager.lua         # Crafting system logic
├── AntiDuplication.lua         # Anti-duplication security
├── ExploitDetection.lua        # Exploit detection system
├── BatchCrafting.lua           # Bulk crafting operations
└── AutoRefinery.lua            # Automatic upgrade synthesis

ReplicatedStorage/
├── ItemDatabase.lua            # Item definitions and properties
├── RecipeDatabase.lua          # Crafting recipes and formulas
├── InventoryEvents.lua         # Inventory communication
└── CraftingEvents.lua          # Crafting communication

StarterPlayer/StarterPlayerScripts/
├── SystemInitializer.lua       # Main system coordinator
├── InventoryController.lua     # Client inventory UI
├── CraftingController.lua      # Client crafting UI
├── MainMenuController.lua      # Main menu system
├── DragDropHandler.lua         # Drag & drop interactions
└── TooltipManager.lua          # Tooltip system
```

## 🚀 Installation

1. **Download** all files to your Roblox Studio project
2. **Place files** in their respective folders according to the file structure
3. **Configure** item database and recipes as needed
4. **Test** in Studio before publishing

## ⚙️ Configuration

### Item Database
Located in `ReplicatedStorage/ItemDatabase.lua`
```lua
-- Add new items
ItemDatabase.Weapons["new_weapon"] = createBaseItem(
    "new_weapon",
    "New Weapon",
    ItemDatabase.Categories.WEAPON,
    ItemDatabase.RarityTiers.Rare,
    "Description here"
)
```

### Recipe Database
Located in `ReplicatedStorage/RecipeDatabase.lua`
```lua
-- Add new recipes
RecipeDatabase.WeaponRecipes["new_recipe"] = createRecipe(
    "new_recipe",
    "Recipe Name",
    RecipeDatabase.Categories.WEAPON_CRAFTING,
    RecipeDatabase.CraftingStations.BASIC_WORKBENCH,
    {itemId = "output_item", quantity = 1},
    {
        {itemId = "material1", quantity = 2},
        {itemId = "material2", quantity = 1}
    },
    10, -- Required level
    85, -- Success rate
    15  -- Crafting time
)
```

## 🎯 Usage

### Basic Operations

#### Opening Inventory
- Press `I` key (default) or call `InventoryController:ToggleInventory()`

#### Opening Main Menu
- Press `M` key (default) or call `MainMenuController:ToggleMainMenu()`

#### Drag & Drop
- Click and drag items between inventory slots
- Drag to equipment slots to equip items
- Visual feedback shows valid drop zones

#### Crafting
1. Open crafting interface
2. Select recipe from list
3. Set quantity (1-10)
4. Click "CRAFT" or "QUEUE" for batch processing

### Advanced Features

#### Auto-Refinery
```lua
-- Enable auto-refinery
AutoRefinery:EnableAutoRefinery(player, {
    enabled = true,
    autoSynthesis = {
        enabled = true,
        maxLevel = 3,
        preserveCount = 1
    }
})
```

#### Batch Crafting
```lua
-- Start batch crafting
BatchCrafting:StartBatch(player, "recipe_id", 50, options)
```

## 🔧 API Reference

### InventoryManager
```lua
InventoryManager:AddItem(player, itemId, quantity, metadata)
InventoryManager:RemoveItem(player, itemId, quantity, fromSlot)
InventoryManager:MoveItem(player, fromSlot, toSlot, quantity)
InventoryManager:EquipItem(player, slotIndex, equipSlot)
InventoryManager:GetInventory(player)
```

### CraftingManager
```lua
CraftingManager:StartCrafting(player, recipeId, quantity)
CraftingManager:AddToQueue(player, recipeId, quantity)
CraftingManager:CancelCrafting(player)
CraftingManager:GetAvailableRecipes(player)
```

### AntiDuplication
```lua
AntiDuplication:ValidateInventoryOperation(player, operation, data)
AntiDuplication:UpdateItemChecksum(userId, slotIndex, itemData)
AntiDuplication:IsPlayerRestricted(player)
```

## 🛡️ Security Features

### Anti-Duplication
- **Checksum Validation**: Every item has a unique checksum
- **Transaction Logging**: All operations are logged and monitored
- **Rate Limiting**: Prevents excessive operations per minute
- **Suspicious Activity Detection**: Automatic flagging of unusual patterns

### Exploit Detection
- **Behavior Analysis**: Monitors player action patterns
- **Speed Detection**: Flags impossible action speeds
- **Pattern Recognition**: Detects repetitive exploit attempts
- **Automatic Response**: Progressive restrictions and admin notifications

## 📊 Performance

### Optimizations
- **Efficient Data Structures**: Optimized for large inventories
- **Lazy Loading**: UI elements loaded as needed
- **Batch Processing**: Multiple operations processed together
- **Memory Management**: Automatic cleanup of old data

### Monitoring
- **Performance Metrics**: Built-in performance tracking
- **Error Handling**: Comprehensive error management
- **Debug Tools**: Development and testing utilities

## 🎨 Customization

### UI Themes
Modify colors and styling in controller files:
```lua
-- Example: Change inventory background color
InventoryUI.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
```

### Item Rarities
Add new rarity tiers in `ItemDatabase.lua`:
```lua
ItemDatabase.RarityTiers.Mythic = {
    Name = "Mythic",
    Color = Color3.fromRGB(255, 0, 255),
    Value = 7
}
```

### Sound Effects
Add sound integration in event handlers:
```lua
-- Example: Play sound on item craft
local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://YOUR_SOUND_ID"
sound:Play()
```

## 🐛 Troubleshooting

### Common Issues

**Items not appearing in inventory:**
- Check ItemDatabase for item definition
- Verify item ID spelling
- Ensure inventory has space

**Crafting not working:**
- Verify recipe exists in RecipeDatabase
- Check player level requirements
- Ensure sufficient materials

**Drag & drop not responding:**
- Check DragDropHandler initialization
- Verify UI element z-index ordering
- Test with different input devices

### Debug Mode
Enable debug output:
```lua
-- Add to SystemInitializer
_G.DEBUG_MODE = true
```

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues and questions:
- Create GitHub issues for bugs
- Check documentation for common solutions
- Join our Discord community (if applicable)

## 🔄 Updates

### Version 1.0.0
- Initial release with complete system
- All core features implemented
- Security systems active
- UI fully functional

---

**Note**: This system is designed for production use but should be thoroughly tested in your specific game environment before deployment.
