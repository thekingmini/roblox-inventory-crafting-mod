--[[
    DragDropHandler.lua
    Advanced drag and drop system for inventory interactions
    Handles item dragging, visual feedback, and drop validation
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local InventoryEvents = require(ReplicatedStorage.InventoryEvents)

local DragDropHandler = {}
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Drag state
local DragState = {
    isDragging = false,
    draggedItem = nil,
    sourceSlot = nil,
    sourceType = nil, -- "inventory" or "equipment"
    dragVisual = nil,
    originalPosition = nil,
    validDropTargets = {},
    currentDropTarget = nil
}

-- Visual feedback
local DropIndicators = {}
local DragPreview = nil

-- Constants
local DRAG_THRESHOLD = 10
local DRAG_OPACITY = 0.7
local DROP_HIGHLIGHT_COLOR = Color3.fromRGB(100, 255, 100)
local INVALID_DROP_COLOR = Color3.fromRGB(255, 100, 100)

-- Initialize drag drop system
function DragDropHandler:Initialize()
    self:SetupInputHandling()
    self:CreateDragPreview()
    print("DragDropHandler initialized")
end

-- Setup input handling
function DragDropHandler:SetupInputHandling()
    -- Handle mouse/touch input
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            self:OnInputBegan(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            self:OnInputMoved(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            self:OnInputEnded(input)
        end
    end)
end

-- Create drag preview visual
function DragDropHandler:CreateDragPreview()
    DragPreview = Instance.new("Frame")
    DragPreview.Name = "DragPreview"
    DragPreview.Size = UDim2.new(0, 64, 0, 64)
    DragPreview.BackgroundTransparency = 1
    DragPreview.BorderSizePixel = 0
    DragPreview.ZIndex = 1000
    DragPreview.Visible = false
    DragPreview.Parent = PlayerGui
    
    -- Icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, 0, 1, 0)
    icon.BackgroundTransparency = 1
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ImageTransparency = 1 - DRAG_OPACITY
    icon.Parent = DragPreview
    
    -- Quantity
    local quantity = Instance.new("TextLabel")
    quantity.Name = "Quantity"
    quantity.Size = UDim2.new(0, 20, 0, 15)
    quantity.Position = UDim2.new(1, -22, 1, -17)
    quantity.Text = ""
    quantity.TextColor3 = Color3.fromRGB(255, 255, 255)
    quantity.TextScaled = true
    quantity.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    quantity.BackgroundTransparency = 0.5
    quantity.BorderSizePixel = 0
    quantity.Font = Enum.Font.SourceSansBold
    quantity.ZIndex = 1001
    quantity.Visible = false
    quantity.Parent = DragPreview
    
    -- Rarity border
    local rarityBorder = Instance.new("Frame")
    rarityBorder.Name = "RarityBorder"
    rarityBorder.Size = UDim2.new(1, 0, 1, 0)
    rarityBorder.BackgroundTransparency = 1
    rarityBorder.BorderSizePixel = 3
    rarityBorder.ZIndex = 999
    rarityBorder.Parent = DragPreview
end

-- Input event handlers
function DragDropHandler:OnInputBegan(input)
    local position = input.Position
    local hitSlot, slotData = self:GetSlotAtPosition(position)
    
    if hitSlot and slotData then
        DragState.sourceSlot = hitSlot
        DragState.sourceType = slotData.type
        DragState.draggedItem = slotData.item
        DragState.originalPosition = position
        
        -- Don't start dragging immediately, wait for movement
    end
end

function DragDropHandler:OnInputMoved(input)
    if not DragState.sourceSlot then return end
    
    local currentPosition = input.Position
    
    if not DragState.isDragging then
        -- Check if we've moved enough to start dragging
        local distance = (currentPosition - DragState.originalPosition).Magnitude
        
        if distance > DRAG_THRESHOLD then
            self:StartDrag()
        end
    else
        -- Update drag position
        self:UpdateDragPosition(currentPosition)
        self:UpdateDropTarget(currentPosition)
    end
end

function DragDropHandler:OnInputEnded(input)
    if DragState.isDragging then
        self:EndDrag(input.Position)
    end
    
    self:ResetDragState()
end

-- Drag operations
function DragDropHandler:StartDrag()
    if not DragState.draggedItem then return end
    
    DragState.isDragging = true
    
    -- Setup drag visual
    self:SetupDragVisual()
    
    -- Find valid drop targets
    self:FindValidDropTargets()
    
    -- Show drop indicators
    self:ShowDropIndicators()
    
    print("Started dragging:", DragState.draggedItem.itemId)
end

function DragDropHandler:SetupDragVisual()
    if not DragPreview then return end
    
    local item = DragState.draggedItem
    local itemData = ItemDatabase:GetItem(item.itemId)
    
    if itemData then
        local icon = DragPreview:FindFirstChild("Icon")
        local quantity = DragPreview:FindFirstChild("Quantity")
        local rarityBorder = DragPreview:FindFirstChild("RarityBorder")
        
        if icon then
            icon.Image = itemData.Icon
        end
        
        if quantity then
            if item.quantity > 1 then
                quantity.Text = tostring(item.quantity)
                quantity.Visible = true
            else
                quantity.Visible = false
            end
        end
        
        if rarityBorder then
            rarityBorder.BorderColor3 = itemData.Rarity.Color
        end
    end
    
    DragPreview.Visible = true
end

function DragDropHandler:UpdateDragPosition(position)
    if DragPreview then
        DragPreview.Position = UDim2.new(0, position.X - 32, 0, position.Y - 32)
    end
end

function DragDropHandler:EndDrag(position)
    local dropTarget, dropData = self:GetSlotAtPosition(position)
    
    if dropTarget and self:IsValidDropTarget(dropTarget, dropData) then
        self:PerformDrop(dropTarget, dropData)
    else
        self:CancelDrag()
    end
    
    -- Hide visuals
    self:HideDropIndicators()
    
    if DragPreview then
        DragPreview.Visible = false
    end
end

function DragDropHandler:CancelDrag()
    -- Animate return to original position
    print("Drag cancelled")
end

function DragDropHandler:PerformDrop(targetSlot, targetData)
    local sourceSlot = DragState.sourceSlot
    local sourceType = DragState.sourceType
    local targetType = targetData.type
    
    print("Performing drop from", sourceType, sourceSlot, "to", targetType, targetSlot)
    
    if sourceType == "inventory" and targetType == "inventory" then
        -- Inventory to inventory move
        self:MoveInventoryItem(sourceSlot, targetSlot)
    elseif sourceType == "inventory" and targetType == "equipment" then
        -- Inventory to equipment (equip)
        self:EquipItem(sourceSlot, targetData.equipSlot)
    elseif sourceType == "equipment" and targetType == "inventory" then
        -- Equipment to inventory (unequip)
        self:UnequipItem(targetData.equipSlot)
    elseif sourceType == "equipment" and targetType == "equipment" then
        -- Equipment to equipment (swap)
        self:SwapEquipment(DragState.sourceSlot, targetData.equipSlot)
    end
end

-- Drop target validation
function DragDropHandler:FindValidDropTargets()
    DragState.validDropTargets = {}
    
    local item = DragState.draggedItem
    local itemData = ItemDatabase:GetItem(item.itemId)
    
    if not itemData then return end
    
    -- Always allow inventory slots
    self:AddInventoryTargets()
    
    -- Add equipment slots if item can be equipped
    if itemData.Category == ItemDatabase.Categories.WEAPON then
        self:AddEquipmentTarget(ItemDatabase.EquipmentSlots.WEAPON)
    elseif itemData.Category == ItemDatabase.Categories.ARMOR then
        self:AddEquipmentTarget(ItemDatabase.EquipmentSlots.ARMOR)
    elseif itemData.Category == ItemDatabase.Categories.RING then
        self:AddEquipmentTarget(ItemDatabase.EquipmentSlots.RING_1)
        self:AddEquipmentTarget(ItemDatabase.EquipmentSlots.RING_2)
    end
end

function DragDropHandler:AddInventoryTargets()
    -- Add all inventory slots as valid targets
    -- This would integrate with the inventory UI to get slot references
end

function DragDropHandler:AddEquipmentTarget(equipSlot)
    -- Add specific equipment slot as valid target
    table.insert(DragState.validDropTargets, {
        type = "equipment",
        slot = equipSlot
    })
end

function DragDropHandler:IsValidDropTarget(targetSlot, targetData)
    -- Check if target is in valid drop targets list
    for _, validTarget in pairs(DragState.validDropTargets) do
        if validTarget.type == targetData.type then
            if targetData.type == "inventory" or validTarget.slot == targetData.equipSlot then
                return true
            end
        end
    end
    
    return false
end

-- Drop indicators
function DragDropHandler:ShowDropIndicators()
    -- Highlight valid drop targets
    for _, target in pairs(DragState.validDropTargets) do
        self:HighlightDropTarget(target, true)
    end
end

function DragDropHandler:HideDropIndicators()
    -- Remove all drop target highlights
    for _, indicator in pairs(DropIndicators) do
        if indicator then
            indicator:Destroy()
        end
    end
    DropIndicators = {}
end

function DragDropHandler:HighlightDropTarget(target, isValid)
    -- Create visual highlight for drop target
    -- This would integrate with the UI system to highlight specific slots
end

function DragDropHandler:UpdateDropTarget(position)
    local hitSlot, slotData = self:GetSlotAtPosition(position)
    
    if hitSlot ~= DragState.currentDropTarget then
        -- Update drop target highlighting
        DragState.currentDropTarget = hitSlot
        
        if hitSlot and self:IsValidDropTarget(hitSlot, slotData) then
            -- Valid drop target
            self:SetDropTargetFeedback(hitSlot, true)
        elseif hitSlot then
            -- Invalid drop target
            self:SetDropTargetFeedback(hitSlot, false)
        end
    end
end

function DragDropHandler:SetDropTargetFeedback(slot, isValid)
    -- Update visual feedback for current drop target
    local color = isValid and DROP_HIGHLIGHT_COLOR or INVALID_DROP_COLOR
    -- Apply color to slot border or background
end

-- Slot detection
function DragDropHandler:GetSlotAtPosition(position)
    -- Find which UI slot is at the given screen position
    -- This needs to integrate with the inventory and equipment UI systems
    
    -- For now, return placeholder data
    local inventoryUI = PlayerGui:FindFirstChild("InventoryUI")
    local craftingUI = PlayerGui:FindFirstChild("CraftingUI")
    
    if inventoryUI and inventoryUI.Visible then
        local slot, slotData = self:CheckInventorySlots(inventoryUI, position)
        if slot then return slot, slotData end
        
        local equipSlot, equipData = self:CheckEquipmentSlots(inventoryUI, position)
        if equipSlot then return equipSlot, equipData end
    end
    
    return nil, nil
end

function DragDropHandler:CheckInventorySlots(inventoryUI, position)
    -- Check inventory grid slots
    local inventoryGrid = inventoryUI:FindFirstChild("InventoryGrid")
    if not inventoryGrid then return nil, nil end
    
    for _, child in pairs(inventoryGrid:GetChildren()) do
        if child.Name:match("Slot%d+") then
            if self:IsPositionInFrame(position, child) then
                local slotIndex = tonumber(child.Name:match("%d+"))
                return slotIndex, {
                    type = "inventory",
                    item = nil -- Would get from inventory data
                }
            end
        end
    end
    
    return nil, nil
end

function DragDropHandler:CheckEquipmentSlots(inventoryUI, position)
    -- Check equipment slots
    local equipmentFrame = inventoryUI:FindFirstChild("EquipmentFrame")
    if not equipmentFrame then return nil, nil end
    
    for equipSlot, _ in pairs(ItemDatabase.EquipmentSlots) do
        local slotFrame = equipmentFrame:FindFirstChild(equipSlot)
        if slotFrame and self:IsPositionInFrame(position, slotFrame) then
            return equipSlot, {
                type = "equipment",
                equipSlot = equipSlot,
                item = nil -- Would get from equipment data
            }
        end
    end
    
    return nil, nil
end

function DragDropHandler:IsPositionInFrame(position, frame)
    local framePos = frame.AbsolutePosition
    local frameSize = frame.AbsoluteSize
    
    return position.X >= framePos.X and 
           position.X <= framePos.X + frameSize.X and
           position.Y >= framePos.Y and 
           position.Y <= framePos.Y + frameSize.Y
end

-- Item operations
function DragDropHandler:MoveInventoryItem(fromSlot, toSlot)
    if InventoryEvents then
        InventoryEvents:MoveItem(fromSlot, toSlot, DragState.draggedItem.quantity)
    end
end

function DragDropHandler:EquipItem(fromSlot, equipSlot)
    if InventoryEvents then
        InventoryEvents:EquipItem(fromSlot, equipSlot)
    end
end

function DragDropHandler:UnequipItem(equipSlot)
    if InventoryEvents then
        InventoryEvents:UnequipItem(equipSlot)
    end
end

function DragDropHandler:SwapEquipment(fromEquipSlot, toEquipSlot)
    -- This would require a special swap operation
    -- For now, unequip both and re-equip in swapped positions
    print("Equipment swap not yet implemented")
end

-- State management
function DragDropHandler:ResetDragState()
    DragState.isDragging = false
    DragState.draggedItem = nil
    DragState.sourceSlot = nil
    DragState.sourceType = nil
    DragState.originalPosition = nil
    DragState.validDropTargets = {}
    DragState.currentDropTarget = nil
end

-- Integration functions for UI systems
function DragDropHandler:RegisterSlot(slotFrame, slotType, slotIndex, itemData)
    -- Register a UI slot for drag/drop operations
    slotFrame:SetAttribute("DragDropType", slotType)
    slotFrame:SetAttribute("DragDropIndex", slotIndex)
    
    -- Store item data reference
    if itemData then
        slotFrame:SetAttribute("HasItem", true)
    else
        slotFrame:SetAttribute("HasItem", false)
    end
end

function DragDropHandler:UpdateSlotData(slotFrame, itemData)
    -- Update item data for a registered slot
    if itemData then
        slotFrame:SetAttribute("HasItem", true)
    else
        slotFrame:SetAttribute("HasItem", false)
    end
end

-- Utility functions
function DragDropHandler:GetSlotType(slotFrame)
    return slotFrame:GetAttribute("DragDropType")
end

function DragDropHandler:GetSlotIndex(slotFrame)
    return slotFrame:GetAttribute("DragDropIndex")
end

function DragDropHandler:HasItem(slotFrame)
    return slotFrame:GetAttribute("HasItem") == true
end

-- Visual effects
function DragDropHandler:PlayDropAnimation(targetSlot)
    -- Play a visual effect when an item is dropped
    local dropEffect = Instance.new("Frame")
    dropEffect.Size = UDim2.new(1, 0, 1, 0)
    dropEffect.Position = UDim2.new(0, 0, 0, 0)
    dropEffect.BackgroundColor3 = DROP_HIGHLIGHT_COLOR
    dropEffect.BackgroundTransparency = 0.5
    dropEffect.BorderSizePixel = 0
    dropEffect.ZIndex = 100
    dropEffect.Parent = targetSlot
    
    -- Fade out animation
    local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local fadeTween = TweenService:Create(dropEffect, fadeInfo, {
        BackgroundTransparency = 1
    })
    
    fadeTween:Play()
    fadeTween.Completed:Connect(function()
        dropEffect:Destroy()
    end)
end

return DragDropHandler