--[[
    InventoryController.lua
    Client-side inventory controller
    Handles inventory UI interactions, local state management, and server communication
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local InventoryController = {}

-- Services and References
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Local State
local InventoryData = {}
local EquipmentData = {}
local CurrentPage = 1
local SelectedSlot = nil
local DraggedItem = nil

-- UI References (will be set by UI system)
local InventoryUI = nil
local InventoryGrid = nil
local EquipmentSlots = nil
local PageButtons = nil

-- Constants
local SLOT_SIZE = 64
local GRID_SIZE = 5
local SLOTS_PER_PAGE = GRID_SIZE * GRID_SIZE
local MAX_PAGES = 4

-- Events (will be connected by events system)
local InventoryEvents = {}

-- Initialize controller
function InventoryController:Initialize()
    self:CreateUI()
    self:SetupEventHandlers()
    self:RequestInventoryData()
    
    print("InventoryController initialized")
end

-- Create inventory UI
function InventoryController:CreateUI()
    -- Main inventory frame
    InventoryUI = Instance.new("Frame")
    InventoryUI.Name = "InventoryUI"
    InventoryUI.Size = UDim2.new(0, 400, 0, 500)
    InventoryUI.Position = UDim2.new(0.5, -200, 0.5, -250)
    InventoryUI.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    InventoryUI.BorderSizePixel = 2
    InventoryUI.BorderColor3 = Color3.fromRGB(100, 100, 100)
    InventoryUI.Visible = false
    InventoryUI.Parent = PlayerGui
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Text = "INVENTORY"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    title.BorderSizePixel = 0
    title.Font = Enum.Font.SourceSansBold
    title.Parent = InventoryUI
    
    -- Page navigation
    self:CreatePageNavigation()
    
    -- Inventory grid
    self:CreateInventoryGrid()
    
    -- Equipment slots
    self:CreateEquipmentSlots()
    
    -- Action buttons
    self:CreateActionButtons()
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.BorderSizePixel = 0
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.Parent = InventoryUI
    
    closeButton.MouseButton1Click:Connect(function()
        self:ToggleInventory()
    end)
end

-- Create page navigation
function InventoryController:CreatePageNavigation()
    local pageFrame = Instance.new("Frame")
    pageFrame.Name = "PageNavigation"
    pageFrame.Size = UDim2.new(1, 0, 0, 30)
    pageFrame.Position = UDim2.new(0, 0, 0, 35)
    pageFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    pageFrame.BorderSizePixel = 0
    pageFrame.Parent = InventoryUI
    
    PageButtons = {}
    
    for i = 1, MAX_PAGES do
        local pageButton = Instance.new("TextButton")
        pageButton.Name = "Page" .. i
        pageButton.Size = UDim2.new(0, 50, 1, 0)
        pageButton.Position = UDim2.new(0, (i-1) * 55 + 10, 0, 0)
        pageButton.Text = tostring(i)
        pageButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        pageButton.TextScaled = true
        pageButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        pageButton.BorderSizePixel = 1
        pageButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
        pageButton.Font = Enum.Font.SourceSans
        pageButton.Parent = pageFrame
        
        PageButtons[i] = pageButton
        
        pageButton.MouseButton1Click:Connect(function()
            self:ChangePage(i)
        end)
    end
    
    self:UpdatePageButtons()
end

-- Create inventory grid
function InventoryController:CreateInventoryGrid()
    InventoryGrid = Instance.new("Frame")
    InventoryGrid.Name = "InventoryGrid"
    InventoryGrid.Size = UDim2.new(0, GRID_SIZE * (SLOT_SIZE + 5) - 5, 0, GRID_SIZE * (SLOT_SIZE + 5) - 5)
    InventoryGrid.Position = UDim2.new(0, 10, 0, 70)
    InventoryGrid.BackgroundTransparency = 1
    InventoryGrid.Parent = InventoryUI
    
    -- Create slot frames
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local slotIndex = (row - 1) * GRID_SIZE + col
            local slot = self:CreateSlot(slotIndex)
            
            slot.Position = UDim2.new(0, (col - 1) * (SLOT_SIZE + 5), 0, (row - 1) * (SLOT_SIZE + 5))
            slot.Parent = InventoryGrid
        end
    end
end

-- Create equipment slots
function InventoryController:CreateEquipmentSlots()
    local equipFrame = Instance.new("Frame")
    equipFrame.Name = "EquipmentFrame"
    equipFrame.Size = UDim2.new(0, 100, 0, 300)
    equipFrame.Position = UDim2.new(1, -110, 0, 70)
    equipFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    equipFrame.BorderSizePixel = 1
    equipFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    equipFrame.Parent = InventoryUI
    
    -- Equipment title
    local equipTitle = Instance.new("TextLabel")
    equipTitle.Name = "Title"
    equipTitle.Size = UDim2.new(1, 0, 0, 25)
    equipTitle.Position = UDim2.new(0, 0, 0, 0)
    equipTitle.Text = "EQUIPMENT"
    equipTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    equipTitle.TextScaled = true
    equipTitle.BackgroundTransparency = 1
    equipTitle.Font = Enum.Font.SourceSansBold
    equipTitle.Parent = equipFrame
    
    EquipmentSlots = {}
    
    -- Create equipment slots
    local equipSlots = {
        {slot = ItemDatabase.EquipmentSlots.WEAPON, name = "Weapon", pos = UDim2.new(0.5, -32, 0, 35)},
        {slot = ItemDatabase.EquipmentSlots.ARMOR, name = "Armor", pos = UDim2.new(0.5, -32, 0, 110)},
        {slot = ItemDatabase.EquipmentSlots.RING_1, name = "Ring 1", pos = UDim2.new(0, 5, 0, 185)},
        {slot = ItemDatabase.EquipmentSlots.RING_2, name = "Ring 2", pos = UDim2.new(1, -69, 0, 185)}
    }
    
    for _, equipData in pairs(equipSlots) do
        local equipSlot = self:CreateEquipmentSlot(equipData.slot, equipData.name)
        equipSlot.Position = equipData.pos
        equipSlot.Parent = equipFrame
        
        EquipmentSlots[equipData.slot] = equipSlot
    end
end

-- Create action buttons
function InventoryController:CreateActionButtons()
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ActionButtons"
    buttonFrame.Size = UDim2.new(1, 0, 0, 40)
    buttonFrame.Position = UDim2.new(0, 0, 1, -45)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = InventoryUI
    
    -- Delete button
    local deleteButton = Instance.new("TextButton")
    deleteButton.Name = "DeleteButton"
    deleteButton.Size = UDim2.new(0, 80, 1, 0)
    deleteButton.Position = UDim2.new(0, 10, 0, 0)
    deleteButton.Text = "DELETE"
    deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    deleteButton.TextScaled = true
    deleteButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    deleteButton.BorderSizePixel = 0
    deleteButton.Font = Enum.Font.SourceSansBold
    deleteButton.Parent = buttonFrame
    
    deleteButton.MouseButton1Click:Connect(function()
        if SelectedSlot then
            self:DeleteItem(SelectedSlot)
        end
    end)
    
    -- Use button
    local useButton = Instance.new("TextButton")
    useButton.Name = "UseButton"
    useButton.Size = UDim2.new(0, 80, 1, 0)
    useButton.Position = UDim2.new(0, 100, 0, 0)
    useButton.Text = "USE"
    useButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    useButton.TextScaled = true
    useButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    useButton.BorderSizePixel = 0
    useButton.Font = Enum.Font.SourceSansBold
    useButton.Parent = buttonFrame
    
    useButton.MouseButton1Click:Connect(function()
        if SelectedSlot then
            self:UseItem(SelectedSlot)
        end
    end)
end

-- Create individual slot
function InventoryController:CreateSlot(slotIndex)
    local slot = Instance.new("Frame")
    slot.Name = "Slot" .. slotIndex
    slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    slot.BorderSizePixel = 2
    slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
    
    -- Item icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, -4, 1, -4)
    icon.Position = UDim2.new(0, 2, 0, 2)
    icon.BackgroundTransparency = 1
    icon.Image = ""
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = slot
    
    -- Quantity label
    local quantity = Instance.new("TextLabel")
    quantity.Name = "Quantity"
    quantity.Size = UDim2.new(0, 20, 0, 15)
    quantity.Position = UDim2.new(1, -22, 1, -17)
    quantity.Text = ""
    quantity.TextColor3 = Color3.fromRGB(255, 255, 255)
    quantity.TextScaled = true
    quantity.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    quantity.BackgroundTransparency = 0.3
    quantity.BorderSizePixel = 0
    quantity.Font = Enum.Font.SourceSansBold
    quantity.Visible = false
    quantity.Parent = slot
    
    -- Rarity border effect
    local rarityBorder = Instance.new("Frame")
    rarityBorder.Name = "RarityBorder"
    rarityBorder.Size = UDim2.new(1, 0, 1, 0)
    rarityBorder.Position = UDim2.new(0, 0, 0, 0)
    rarityBorder.BackgroundTransparency = 1
    rarityBorder.BorderSizePixel = 3
    rarityBorder.BorderColor3 = Color3.fromRGB(100, 100, 100)
    rarityBorder.Visible = false
    rarityBorder.Parent = slot
    
    -- Click detection
    local clickButton = Instance.new("TextButton")
    clickButton.Name = "ClickButton"
    clickButton.Size = UDim2.new(1, 0, 1, 0)
    clickButton.Position = UDim2.new(0, 0, 0, 0)
    clickButton.Text = ""
    clickButton.BackgroundTransparency = 1
    clickButton.Parent = slot
    
    -- Slot interactions
    clickButton.MouseButton1Click:Connect(function()
        self:OnSlotClicked(slotIndex)
    end)
    
    clickButton.MouseButton2Click:Connect(function()
        self:OnSlotRightClicked(slotIndex)
    end)
    
    return slot
end

-- Create equipment slot
function InventoryController:CreateEquipmentSlot(equipSlot, displayName)
    local slot = Instance.new("Frame")
    slot.Name = equipSlot
    slot.Size = UDim2.new(0, 64, 0, 64)
    slot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    slot.BorderSizePixel = 2
    slot.BorderColor3 = Color3.fromRGB(80, 80, 80)
    
    -- Icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, -4, 1, -4)
    icon.Position = UDim2.new(0, 2, 0, 2)
    icon.BackgroundTransparency = 1
    icon.Image = ""
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = slot
    
    -- Label
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 0, 15)
    label.Position = UDim2.new(0, 0, 1, 2)
    label.Text = displayName
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextScaled = true
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSans
    label.Parent = slot
    
    -- Click detection
    local clickButton = Instance.new("TextButton")
    clickButton.Name = "ClickButton"
    clickButton.Size = UDim2.new(1, 0, 1, 0)
    clickButton.Position = UDim2.new(0, 0, 0, 0)
    clickButton.Text = ""
    clickButton.BackgroundTransparency = 1
    clickButton.Parent = slot
    
    clickButton.MouseButton1Click:Connect(function()
        self:OnEquipmentSlotClicked(equipSlot)
    end)
    
    return slot
end

-- Event handlers
function InventoryController:SetupEventHandlers()
    -- Will be connected by events system
    -- InventoryEvents.InventoryUpdated:Connect(function(inventoryData) ... end)
    -- InventoryEvents.EquipmentUpdated:Connect(function(equipmentData) ... end)
end

-- UI Control Functions
function InventoryController:ToggleInventory()
    InventoryUI.Visible = not InventoryUI.Visible
    
    if InventoryUI.Visible then
        self:RefreshUI()
    end
end

function InventoryController:ChangePage(pageNum)
    if pageNum < 1 or pageNum > MAX_PAGES then return end
    
    CurrentPage = pageNum
    self:UpdatePageButtons()
    self:RefreshInventoryGrid()
end

function InventoryController:UpdatePageButtons()
    for i, button in pairs(PageButtons) do
        if i == CurrentPage then
            button.BackgroundColor3 = Color3.fromRGB(100, 150, 200)
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            button.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
end

-- Slot interaction handlers
function InventoryController:OnSlotClicked(slotIndex)
    SelectedSlot = slotIndex
    self:UpdateSlotSelection()
    
    -- Handle drag and drop logic here
    local realSlotIndex = self:GetRealSlotIndex(slotIndex)
    local item = InventoryData.Items and InventoryData.Items[realSlotIndex]
    
    if item then
        print("Selected item:", item.itemId, "quantity:", item.quantity)
    end
end

function InventoryController:OnSlotRightClicked(slotIndex)
    -- Quick use/equip item
    local realSlotIndex = self:GetRealSlotIndex(slotIndex)
    local item = InventoryData.Items and InventoryData.Items[realSlotIndex]
    
    if item then
        self:QuickAction(realSlotIndex)
    end
end

function InventoryController:OnEquipmentSlotClicked(equipSlot)
    -- Unequip item
    if EquipmentData[equipSlot] then
        self:UnequipItem(equipSlot)
    end
end

-- Item actions
function InventoryController:UseItem(slotIndex)
    local realSlotIndex = self:GetRealSlotIndex(slotIndex)
    local item = InventoryData.Items and InventoryData.Items[realSlotIndex]
    
    if not item then return end
    
    local itemData = ItemDatabase:GetItem(item.itemId)
    if not itemData then return end
    
    -- Handle different item types
    if itemData.Category == ItemDatabase.Categories.CONSUMABLE or 
       itemData.Category == ItemDatabase.Categories.BOOST then
        -- Use consumable
        self:RequestUseItem(realSlotIndex)
    elseif itemData.Category == ItemDatabase.Categories.WEAPON or
           itemData.Category == ItemDatabase.Categories.ARMOR or
           itemData.Category == ItemDatabase.Categories.RING then
        -- Equip item
        self:EquipItem(realSlotIndex)
    end
end

function InventoryController:DeleteItem(slotIndex)
    local realSlotIndex = self:GetRealSlotIndex(slotIndex)
    local item = InventoryData.Items and InventoryData.Items[realSlotIndex]
    
    if not item then return end
    
    -- Confirmation dialog would go here
    self:RequestDeleteItem(realSlotIndex)
end

function InventoryController:EquipItem(slotIndex)
    local item = InventoryData.Items and InventoryData.Items[slotIndex]
    if not item then return end
    
    local itemData = ItemDatabase:GetItem(item.itemId)
    if not itemData then return end
    
    local equipSlot = nil
    
    if itemData.Category == ItemDatabase.Categories.WEAPON then
        equipSlot = ItemDatabase.EquipmentSlots.WEAPON
    elseif itemData.Category == ItemDatabase.Categories.ARMOR then
        equipSlot = ItemDatabase.EquipmentSlots.ARMOR
    elseif itemData.Category == ItemDatabase.Categories.RING then
        -- Find available ring slot
        if not EquipmentData[ItemDatabase.EquipmentSlots.RING_1] then
            equipSlot = ItemDatabase.EquipmentSlots.RING_1
        elseif not EquipmentData[ItemDatabase.EquipmentSlots.RING_2] then
            equipSlot = ItemDatabase.EquipmentSlots.RING_2
        else
            equipSlot = ItemDatabase.EquipmentSlots.RING_1 -- Replace first ring
        end
    end
    
    if equipSlot then
        self:RequestEquipItem(slotIndex, equipSlot)
    end
end

function InventoryController:UnequipItem(equipSlot)
    self:RequestUnequipItem(equipSlot)
end

function InventoryController:QuickAction(slotIndex)
    local item = InventoryData.Items and InventoryData.Items[slotIndex]
    if not item then return end
    
    local itemData = ItemDatabase:GetItem(item.itemId)
    if not itemData then return end
    
    -- Auto-determine action based on item type
    if itemData.Category == ItemDatabase.Categories.WEAPON or
       itemData.Category == ItemDatabase.Categories.ARMOR or
       itemData.Category == ItemDatabase.Categories.RING then
        self:EquipItem(slotIndex)
    else
        self:UseItem(slotIndex)
    end
end

-- Server requests (will be handled by events system)
function InventoryController:RequestInventoryData()
    -- Request current inventory from server
    -- InventoryEvents:RequestInventory()
end

function InventoryController:RequestUseItem(slotIndex)
    -- InventoryEvents:UseItem(slotIndex)
end

function InventoryController:RequestDeleteItem(slotIndex)
    -- InventoryEvents:DeleteItem(slotIndex)
end

function InventoryController:RequestEquipItem(slotIndex, equipSlot)
    -- InventoryEvents:EquipItem(slotIndex, equipSlot)
end

function InventoryController:RequestUnequipItem(equipSlot)
    -- InventoryEvents:UnequipItem(equipSlot)
end

function InventoryController:RequestMoveItem(fromSlot, toSlot, quantity)
    -- InventoryEvents:MoveItem(fromSlot, toSlot, quantity)
end

-- UI Update Functions
function InventoryController:RefreshUI()
    self:RefreshInventoryGrid()
    self:RefreshEquipment()
end

function InventoryController:RefreshInventoryGrid()
    for slotIndex = 1, SLOTS_PER_PAGE do
        local slot = InventoryGrid:FindFirstChild("Slot" .. slotIndex)
        if slot then
            self:UpdateSlot(slot, slotIndex)
        end
    end
end

function InventoryController:RefreshEquipment()
    for equipSlot, slotFrame in pairs(EquipmentSlots) do
        self:UpdateEquipmentSlot(slotFrame, equipSlot)
    end
end

function InventoryController:UpdateSlot(slotFrame, slotIndex)
    local realSlotIndex = self:GetRealSlotIndex(slotIndex)
    local item = InventoryData.Items and InventoryData.Items[realSlotIndex]
    
    local icon = slotFrame:FindFirstChild("Icon")
    local quantity = slotFrame:FindFirstChild("Quantity") 
    local rarityBorder = slotFrame:FindFirstChild("RarityBorder")
    
    if item then
        local itemData = ItemDatabase:GetItem(item.itemId)
        
        if itemData then
            -- Set icon
            icon.Image = itemData.Icon
            
            -- Set quantity
            if item.quantity > 1 then
                quantity.Text = tostring(item.quantity)
                quantity.Visible = true
            else
                quantity.Visible = false
            end
            
            -- Set rarity border
            rarityBorder.BorderColor3 = itemData.Rarity.Color
            rarityBorder.Visible = true
        else
            -- Invalid item
            icon.Image = ""
            quantity.Visible = false
            rarityBorder.Visible = false
        end
    else
        -- Empty slot
        icon.Image = ""
        quantity.Visible = false
        rarityBorder.Visible = false
    end
    
    -- Selection highlight
    if SelectedSlot == slotIndex then
        slotFrame.BorderColor3 = Color3.fromRGB(255, 255, 0)
    else
        slotFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    end
end

function InventoryController:UpdateEquipmentSlot(slotFrame, equipSlot)
    local item = EquipmentData[equipSlot]
    local icon = slotFrame:FindFirstChild("Icon")
    
    if item then
        local itemData = ItemDatabase:GetItem(item.itemId)
        if itemData then
            icon.Image = itemData.Icon
            slotFrame.BorderColor3 = itemData.Rarity.Color
        else
            icon.Image = ""
            slotFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
        end
    else
        icon.Image = ""
        slotFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
    end
end

function InventoryController:UpdateSlotSelection()
    -- Will be called to update visual selection
    self:RefreshInventoryGrid()
end

-- Utility Functions
function InventoryController:GetRealSlotIndex(gridSlotIndex)
    return (CurrentPage - 1) * SLOTS_PER_PAGE + gridSlotIndex
end

-- Data update handlers (called by events system)
function InventoryController:OnInventoryUpdated(inventoryData)
    InventoryData = inventoryData
    self:RefreshInventoryGrid()
end

function InventoryController:OnEquipmentUpdated(equipmentData)
    EquipmentData = equipmentData
    self:RefreshEquipment()
end

return InventoryController