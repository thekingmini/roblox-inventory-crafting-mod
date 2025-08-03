# 🎯 Complete Drag-and-Drop Crafting System for Roblox

A comprehensive, production-ready crafting system with drag-and-drop UI, secure server-side validation, and seamless inventory management for Roblox games.

## 🚀 Features

### ✨ Core Features
- **Drag-and-Drop Interface**: Intuitive drag-drop mechanics between inventory, crafting, and refinery slots
- **Unified Menu System**: Integrated tabbed interface (Character, Jobs, Shop, Gangs, Credit Shop)
- **Recipe System**: Blueprint-based crafting with material validation
- **4-Page Inventory**: 100 total slots organized across 4 pages (25 slots each)
- **Refinery System**: Item upgrading and enhancement mechanics
- **Real-time Validation**: Visual feedback for valid/invalid crafting combinations

### 🔒 Security & Performance
- **Server-side Validation**: All operations validated on server to prevent exploits
- **Rate Limiting**: Anti-spam protection with configurable limits
- **Efficient UI Updates**: Only updates changed elements for smooth 60 FPS
- **Memory Optimization**: Smart slot management and cleanup

### 🎨 Visual Feedback
- **Item Rarity Colors**: Color-coded borders based on item rarity
- **Quantity Displays**: Clear quantity indicators on stacked items
- **Interactive Tooltips**: Detailed item information on hover
- **Recipe Requirements**: Visual silhouettes showing required materials
- **Validation Indicators**: Green/red borders for valid/invalid drops

## 📁 Project Structure

```
roblox-inventory-crafting-mod/
├── ServerStorage/
│   ├── CraftingManager.lua          # Server-side crafting logic
│   ├── InventoryManager.lua         # Server-side inventory management
│   ├── RemoteEventsHandler.lua      # Server communication handler
│   └── ServerMain.lua               # Server initialization
│
├── ReplicatedStorage/
│   ├── ItemDatabase.lua             # Item definitions and properties
│   ├── RecipeDatabase.lua           # Crafting recipes and requirements
│   └── RemoteEvents/
│       └── RemoteEventsConfig.lua   # RemoteEvent configuration
│
└── StarterPlayerScripts/
    ├── CraftingSystemMain.lua       # Main client controller
    ├── MenuController.lua           # Unified menu management
    ├── DragDropSystem.lua           # Drag-and-drop mechanics
    ├── InventoryUIManager.lua       # Inventory display logic
    └── CraftingUIManager.lua        # Crafting validation logic
```

## 🛠️ Installation

### Prerequisites
- Roblox Studio
- Basic understanding of Roblox scripting

### Setup Instructions

1. **Clone or Download** this repository to your local machine

2. **Open Roblox Studio** and create a new place or open an existing one

3. **Import Server Scripts**:
   - Copy all files from `ServerStorage/` to your game's ServerStorage
   - Copy all files from `ReplicatedStorage/` to your game's ReplicatedStorage
   - Copy all files from `StarterPlayerScripts/` to StarterPlayer → StarterPlayerScripts

4. **Create RemoteEvents**:
   - In ReplicatedStorage, create a Folder named "RemoteEvents"
   - Add three RemoteEvent instances: "CraftingRemote", "InventoryRemote", "UIUpdateRemote"

5. **Initialize the System**:
   - Place `ServerMain.lua` in ServerStorage and it will auto-initialize
   - The client system will auto-start when players join

## 🎮 Usage

### For Players
1. **Press L** to toggle the crafting menu
2. **Switch tabs** using the top navigation (Character, Jobs, Shop, Gangs, Credit Shop)
3. **Navigate inventory** using page buttons (1, 2, 3, 4)
4. **Drag items** from inventory to crafting slots
5. **Drop blueprints** in the blueprint slot to see recipe requirements
6. **Add materials** to the highlighted material slots
7. **Click GO** to craft when all requirements are met
8. **Use refinery** to upgrade items (drag to refinery slots, click GO)

### For Developers

#### Adding New Items
```lua
-- In ReplicatedStorage/ItemDatabase.lua
["new_item_id"] = {
    id = "new_item_id",
    name = "New Item Name",
    type = ItemDatabase.ItemTypes.MATERIAL, -- or BLUEPRINT, TOOL, etc.
    rarity = ItemDatabase.Rarity.COMMON,
    icon = "rbxasset://path/to/icon",
    description = "Item description",
    stackable = true,
    maxStack = 50
}
```

#### Adding New Recipes
```lua
-- In ReplicatedStorage/RecipeDatabase.lua
["blueprint_id"] = {
    id = "blueprint_id",
    name = "Recipe Name",
    resultItem = "result_item_id",
    resultQuantity = 1,
    ingredients = {
        {itemId = "material1_id", quantity = 2, slot = 1},
        {itemId = "material2_id", quantity = 1, slot = 2}
    },
    craftingTime = 5,
    experienceGained = 10,
    requiredLevel = 1
}
```

#### Customizing UI
- Modify `MenuController.lua` to change menu layout and styling
- Adjust slot sizes and positions in the `Create*Slots` functions
- Customize colors and effects in the respective UI managers

## 🔧 Configuration

### Server Settings
```lua
-- In InventoryManager.lua
InventoryManager.MAX_SLOTS = 100        -- Total inventory slots
InventoryManager.SLOTS_PER_PAGE = 25    -- Slots per page
InventoryManager.MAX_PAGES = 4          -- Number of pages

-- In CraftingManager.lua  
CraftingManager.MAX_CRAFTING_SLOTS = 6  -- Material slots in crafting

-- In RemoteEventsHandler.lua
local MAX_REQUESTS_PER_SECOND = 10      -- Rate limiting
```

### Client Settings
```lua
-- In DragDropSystem.lua
-- Modify DropRules to change what items can go in which slots

-- In InventoryUIManager.lua
-- Customize tooltip appearance and behavior

-- In CraftingUIManager.lua
-- Adjust validation rules and visual feedback
```

## 🧪 Testing

### Basic Functionality Test
1. Start the game and press L to open menu
2. Verify inventory loads with starter items
3. Test drag-drop between different slot types
4. Try crafting with a blueprint and materials
5. Test page navigation in inventory
6. Test refinery functionality

### Security Testing
1. Verify server validates all crafting operations
2. Test rate limiting by rapidly sending requests
3. Confirm inventory changes persist across sessions
4. Test with invalid item IDs and quantities

## 🐛 Troubleshooting

### Common Issues

**Menu doesn't open when pressing L**
- Check that CraftingSystemMain.lua is in StarterPlayerScripts
- Verify RemoteEvents exist in ReplicatedStorage/RemoteEvents
- Check console for initialization errors

**Drag-drop not working**
- Ensure inventory has items (starter items are auto-added)
- Check that DragDropSystem initialized properly
- Verify UI elements have correct names and hierarchy

**Server errors**
- Confirm all server modules are in ServerStorage
- Check that RemoteEventsHandler initialized successfully
- Verify ItemDatabase and RecipeDatabase have valid data

**Items not displaying**
- Check item IDs match between database and inventory
- Verify image paths in ItemDatabase are correct
- Ensure UI elements are properly referenced

## 🤝 Contributing

### Adding Features
1. Follow the existing code structure and patterns
2. Add proper error handling and validation
3. Update both client and server components as needed
4. Test thoroughly before submitting

### Code Style
- Use clear, descriptive variable and function names
- Add comments for complex logic
- Follow Roblox scripting best practices
- Maintain consistency with existing code

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for the Roblox development community
- Designed with security and performance in mind
- Implements modern game UI/UX patterns

---

**Ready to craft? Press L and start building!** 🔨✨
