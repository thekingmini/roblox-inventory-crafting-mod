--[[
    TooltipManager.lua
    Advanced tooltip system for item information display
    Handles hover tooltips, detailed item stats, and comparison data
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local TooltipManager = {}

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Tooltip state
local TooltipState = {
    isVisible = false,
    currentItem = nil,
    hoverSlot = nil,
    tooltip = nil,
    fadeInTween = nil,
    fadeOutTween = nil
}

-- Constants
local TOOLTIP_DELAY = 0.5 -- Delay before showing tooltip
local FADE_DURATION = 0.2
local TOOLTIP_OFFSET = Vector2.new(10, -10)
local MAX_TOOLTIP_WIDTH = 300
local MAX_TOOLTIP_HEIGHT = 400

-- Initialize tooltip system
function TooltipManager:Initialize()
    self:CreateTooltip()
    self:SetupEventHandlers()
    print("TooltipManager initialized")
end

-- Create tooltip UI
function TooltipManager:CreateTooltip()
    TooltipState.tooltip = Instance.new("Frame")
    local tooltip = TooltipState.tooltip
    
    tooltip.Name = "ItemTooltip"
    tooltip.Size = UDim2.new(0, 250, 0, 200)
    tooltip.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    tooltip.BackgroundTransparency = 0.1
    tooltip.BorderSizePixel = 2
    tooltip.BorderColor3 = Color3.fromRGB(100, 100, 100)
    tooltip.ZIndex = 2000
    tooltip.Visible = false
    tooltip.Parent = PlayerGui
    
    -- Shadow effect
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 4, 1, 4)
    shadow.Position = UDim2.new(0, 2, 0, 2)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.7
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 1999
    shadow.Parent = tooltip
    
    -- Content frame
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -10, 1, -10)
    content.Position = UDim2.new(0, 5, 0, 5)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Parent = tooltip
    
    -- Item name
    local itemName = Instance.new("TextLabel")
    itemName.Name = "ItemName"
    itemName.Size = UDim2.new(1, 0, 0, 25)
    itemName.Position = UDim2.new(0, 0, 0, 0)
    itemName.Text = ""
    itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemName.TextScaled = true
    itemName.BackgroundTransparency = 1
    itemName.Font = Enum.Font.SourceSansBold
    itemName.TextXAlignment = Enum.TextXAlignment.Left
    itemName.Parent = content
    
    -- Item category and rarity
    local itemInfo = Instance.new("TextLabel")
    itemInfo.Name = "ItemInfo"
    itemInfo.Size = UDim2.new(1, 0, 0, 20)
    itemInfo.Position = UDim2.new(0, 0, 0, 25)
    itemInfo.Text = ""
    itemInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
    itemInfo.TextScaled = true
    itemInfo.BackgroundTransparency = 1
    itemInfo.Font = Enum.Font.SourceSans
    itemInfo.TextXAlignment = Enum.TextXAlignment.Left
    itemInfo.Parent = content
    
    -- Separator line
    local separator = Instance.new("Frame")
    separator.Name = "Separator"
    separator.Size = UDim2.new(1, 0, 0, 1)
    separator.Position = UDim2.new(0, 0, 0, 50)
    separator.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    separator.BorderSizePixel = 0
    separator.Parent = content
    
    -- Description
    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Size = UDim2.new(1, 0, 0, 40)
    description.Position = UDim2.new(0, 0, 0, 55)
    description.Text = ""
    description.TextColor3 = Color3.fromRGB(220, 220, 220)
    description.TextWrapped = true
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.BackgroundTransparency = 1
    description.Font = Enum.Font.SourceSans
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.Parent = content
    
    -- Stats frame
    local statsFrame = Instance.new("Frame")
    statsFrame.Name = "StatsFrame"
    statsFrame.Size = UDim2.new(1, 0, 1, -100)
    statsFrame.Position = UDim2.new(0, 0, 0, 100)
    statsFrame.BackgroundTransparency = 1
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = content
    
    -- Scrollable stats list
    local statsList = Instance.new("ScrollingFrame")
    statsList.Name = "StatsList"
    statsList.Size = UDim2.new(1, 0, 1, 0)
    statsList.Position = UDim2.new(0, 0, 0, 0)
    statsList.BackgroundTransparency = 1
    statsList.BorderSizePixel = 0
    statsList.ScrollBarThickness = 4
    statsList.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    statsList.CanvasSize = UDim2.new(0, 0, 0, 0)
    statsList.Parent = statsFrame
end

-- Setup event handlers
function TooltipManager:SetupEventHandlers()
    -- Mouse movement for positioning
    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            self:UpdateTooltipPosition(input.Position)
        end
    end)
end

-- Show tooltip for item
function TooltipManager:ShowTooltip(itemData, itemInstance, slotFrame)
    if not itemData then return end
    
    TooltipState.currentItem = itemData
    TooltipState.hoverSlot = slotFrame
    
    self:PopulateTooltip(itemData, itemInstance)
    self:PositionTooltip()
    
    -- Cancel any existing fade tweens
    if TooltipState.fadeInTween then
        TooltipState.fadeInTween:Cancel()
    end
    if TooltipState.fadeOutTween then
        TooltipState.fadeOutTween:Cancel()
    end
    
    -- Show tooltip with fade in
    TooltipState.tooltip.Visible = true
    TooltipState.isVisible = true
    
    local fadeInfo = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TooltipState.fadeInTween = TweenService:Create(TooltipState.tooltip, fadeInfo, {
        BackgroundTransparency = 0.1
    })
    
    TooltipState.fadeInTween:Play()
end

-- Hide tooltip
function TooltipManager:HideTooltip()
    if not TooltipState.isVisible then return end
    
    TooltipState.isVisible = false
    TooltipState.currentItem = nil
    TooltipState.hoverSlot = nil
    
    -- Cancel fade in if running
    if TooltipState.fadeInTween then
        TooltipState.fadeInTween:Cancel()
    end
    
    -- Fade out
    local fadeInfo = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TooltipState.fadeOutTween = TweenService:Create(TooltipState.tooltip, fadeInfo, {
        BackgroundTransparency = 1
    })
    
    TooltipState.fadeOutTween:Play()
    TooltipState.fadeOutTween.Completed:Connect(function()
        TooltipState.tooltip.Visible = false
    end)
end

-- Populate tooltip with item data
function TooltipManager:PopulateTooltip(itemData, itemInstance)
    local tooltip = TooltipState.tooltip
    local content = tooltip:FindFirstChild("Content")
    
    if not content then return end
    
    -- Set item name with rarity color
    local itemName = content:FindFirstChild("ItemName")
    if itemName then
        itemName.Text = itemData.Name
        itemName.TextColor3 = itemData.Rarity.Color
    end
    
    -- Set item info
    local itemInfo = content:FindFirstChild("ItemInfo")
    if itemInfo then
        local levelText = itemInstance and itemInstance.Level and " (Level " .. itemInstance.Level .. ")" or ""
        itemInfo.Text = itemData.Category .. " - " .. itemData.Rarity.Name .. levelText
    end
    
    -- Set description
    local description = content:FindFirstChild("Description")
    if description then
        description.Text = itemData.Description or "No description available."
        
        -- Adjust description height based on text
        local textBounds = self:GetTextBounds(description.Text, description.TextSize, description.Font, MAX_TOOLTIP_WIDTH - 10)
        description.Size = UDim2.new(1, 0, 0, math.max(20, textBounds.Y))
    end
    
    -- Populate stats
    self:PopulateStats(itemData, itemInstance)
    
    -- Adjust tooltip size
    self:AdjustTooltipSize()
end

-- Populate item stats
function TooltipManager:PopulateStats(itemData, itemInstance)
    local statsFrame = TooltipState.tooltip.Content:FindFirstChild("StatsFrame")
    if not statsFrame then return end
    
    local statsList = statsFrame:FindFirstChild("StatsList")
    if not statsList then return end
    
    -- Clear existing stats
    for _, child in pairs(statsList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local yPos = 0
    
    -- Basic item stats
    self:AddStatLine(statsList, "Value", tostring(itemData.Value), yPos)
    yPos = yPos + 20
    
    if itemData.Stackable then
        local quantity = itemInstance and itemInstance.quantity or 1
        self:AddStatLine(statsList, "Quantity", quantity .. "/" .. itemData.MaxStack, yPos)
        yPos = yPos + 20
    end
    
    -- Equipment stats
    if itemData.Category == ItemDatabase.Categories.WEAPON then
        self:AddWeaponStats(statsList, itemData, itemInstance, yPos)
        yPos = yPos + self:GetWeaponStatsHeight(itemData, itemInstance)
    elseif itemData.Category == ItemDatabase.Categories.ARMOR then
        self:AddArmorStats(statsList, itemData, itemInstance, yPos)
        yPos = yPos + self:GetArmorStatsHeight(itemData, itemInstance)
    elseif itemData.Category == ItemDatabase.Categories.RING then
        self:AddRingStats(statsList, itemData, itemInstance, yPos)
        yPos = yPos + self:GetRingStatsHeight(itemData, itemInstance)
    end
    
    -- Special effects
    if itemData.Effects and #itemData.Effects > 0 then
        self:AddSeparator(statsList, yPos)
        yPos = yPos + 25
        
        self:AddEffects(statsList, itemData.Effects, yPos)
        yPos = yPos + (#itemData.Effects * 20)
    end
    
    -- Requirements
    if itemData.Requirements and next(itemData.Requirements) then
        self:AddSeparator(statsList, yPos)
        yPos = yPos + 25
        
        self:AddRequirements(statsList, itemData.Requirements, yPos)
        yPos = yPos + (self:CountRequirements(itemData.Requirements) * 20)
    end
    
    -- Update canvas size
    statsList.CanvasSize = UDim2.new(0, 0, 0, yPos)
end

-- Add stat line
function TooltipManager:AddStatLine(parent, statName, statValue, yPos, color)
    local statLine = Instance.new("Frame")
    statLine.Name = "StatLine"
    statLine.Size = UDim2.new(1, 0, 0, 18)
    statLine.Position = UDim2.new(0, 0, 0, yPos)
    statLine.BackgroundTransparency = 1
    statLine.Parent = parent
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "StatName"
    nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.Text = statName .. ":"
    nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameLabel.TextScaled = true
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.SourceSans
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = statLine
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "StatValue"
    valueLabel.Size = UDim2.new(0.4, 0, 1, 0)
    valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
    valueLabel.Text = tostring(statValue)
    valueLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    valueLabel.TextScaled = true
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = Enum.Font.SourceSans
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = statLine
end

-- Add separator
function TooltipManager:AddSeparator(parent, yPos)
    local separator = Instance.new("Frame")
    separator.Name = "Separator"
    separator.Size = UDim2.new(1, 0, 0, 1)
    separator.Position = UDim2.new(0, 0, 0, yPos + 10)
    separator.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    separator.BorderSizePixel = 0
    separator.Parent = parent
end

-- Add weapon stats
function TooltipManager:AddWeaponStats(parent, itemData, itemInstance, yPos)
    local startY = yPos
    
    -- Base damage
    self:AddStatLine(parent, "Damage", "50-75", yPos)
    yPos = yPos + 20
    
    -- Attack speed
    self:AddStatLine(parent, "Attack Speed", "1.2", yPos)
    yPos = yPos + 20
    
    -- Accuracy
    self:AddStatLine(parent, "Accuracy", "85%", yPos)
    yPos = yPos + 20
    
    -- Range
    self:AddStatLine(parent, "Range", "Medium", yPos)
    yPos = yPos + 20
    
    return yPos - startY
end

function TooltipManager:GetWeaponStatsHeight(itemData, itemInstance)
    return 80 -- 4 stats * 20 pixels
end

-- Add armor stats
function TooltipManager:AddArmorStats(parent, itemData, itemInstance, yPos)
    local startY = yPos
    
    -- Armor rating
    self:AddStatLine(parent, "Armor", "25", yPos)
    yPos = yPos + 20
    
    -- Health bonus
    self:AddStatLine(parent, "Health", "+50", yPos, Color3.fromRGB(100, 255, 100))
    yPos = yPos + 20
    
    -- Speed penalty
    self:AddStatLine(parent, "Speed", "-5%", yPos, Color3.fromRGB(255, 100, 100))
    yPos = yPos + 20
    
    return yPos - startY
end

function TooltipManager:GetArmorStatsHeight(itemData, itemInstance)
    return 60 -- 3 stats * 20 pixels
end

-- Add ring stats
function TooltipManager:AddRingStats(parent, itemData, itemInstance, yPos)
    local startY = yPos
    
    if itemData.ID == "health_ring" then
        self:AddStatLine(parent, "Health", "+25", yPos, Color3.fromRGB(100, 255, 100))
        yPos = yPos + 20
    elseif itemData.ID == "damage_ring" then
        self:AddStatLine(parent, "Damage", "+15%", yPos, Color3.fromRGB(255, 200, 100))
        yPos = yPos + 20
    elseif itemData.ID == "legendary_ring" then
        self:AddStatLine(parent, "All Stats", "+10", yPos, Color3.fromRGB(255, 215, 0))
        yPos = yPos + 20
        self:AddStatLine(parent, "Crit Chance", "+5%", yPos, Color3.fromRGB(255, 100, 100))
        yPos = yPos + 20
    end
    
    return yPos - startY
end

function TooltipManager:GetRingStatsHeight(itemData, itemInstance)
    if itemData.ID == "legendary_ring" then
        return 40 -- 2 stats
    else
        return 20 -- 1 stat
    end
end

-- Add effects
function TooltipManager:AddEffects(parent, effects, yPos)
    for i, effect in pairs(effects) do
        local effectText = effect.Description or effect.Name or "Unknown Effect"
        self:AddStatLine(parent, "Effect", effectText, yPos + (i-1) * 20, Color3.fromRGB(150, 150, 255))
    end
end

-- Add requirements
function TooltipManager:AddRequirements(parent, requirements, yPos)
    local index = 0
    
    if requirements.Level then
        self:AddStatLine(parent, "Required Level", requirements.Level, yPos + index * 20, Color3.fromRGB(255, 255, 100))
        index = index + 1
    end
    
    if requirements.Class then
        self:AddStatLine(parent, "Required Class", requirements.Class, yPos + index * 20, Color3.fromRGB(255, 255, 100))
        index = index + 1
    end
    
    if requirements.Faction then
        self:AddStatLine(parent, "Required Faction", requirements.Faction, yPos + index * 20, Color3.fromRGB(255, 255, 100))
        index = index + 1
    end
end

function TooltipManager:CountRequirements(requirements)
    local count = 0
    if requirements.Level then count = count + 1 end
    if requirements.Class then count = count + 1 end
    if requirements.Faction then count = count + 1 end
    return count
end

-- Position tooltip
function TooltipManager:PositionTooltip()
    local tooltip = TooltipState.tooltip
    local mousePos = UserInputService:GetMouseLocation()
    
    self:UpdateTooltipPosition(mousePos)
end

function TooltipManager:UpdateTooltipPosition(mousePos)
    if not TooltipState.isVisible then return end
    
    local tooltip = TooltipState.tooltip
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local tooltipSize = tooltip.AbsoluteSize
    
    local x = mousePos.X + TOOLTIP_OFFSET.X
    local y = mousePos.Y + TOOLTIP_OFFSET.Y
    
    -- Keep tooltip on screen
    if x + tooltipSize.X > viewportSize.X then
        x = mousePos.X - tooltipSize.X - TOOLTIP_OFFSET.X
    end
    
    if y + tooltipSize.Y > viewportSize.Y then
        y = mousePos.Y - tooltipSize.Y - TOOLTIP_OFFSET.Y
    end
    
    -- Clamp to screen bounds
    x = math.max(0, math.min(x, viewportSize.X - tooltipSize.X))
    y = math.max(0, math.min(y, viewportSize.Y - tooltipSize.Y))
    
    tooltip.Position = UDim2.new(0, x, 0, y)
end

-- Adjust tooltip size based on content
function TooltipManager:AdjustTooltipSize()
    local tooltip = TooltipState.tooltip
    local content = tooltip:FindFirstChild("Content")
    
    if not content then return end
    
    local description = content:FindFirstChild("Description")
    local statsFrame = content:FindFirstChild("StatsFrame")
    local statsList = statsFrame and statsFrame:FindFirstChild("StatsList")
    
    local totalHeight = 110 -- Base height for name, info, description
    
    if description then
        totalHeight = totalHeight + description.AbsoluteSize.Y
    end
    
    if statsList then
        totalHeight = totalHeight + math.min(statsList.CanvasSize.Y.Offset, 200) -- Max stats height
    end
    
    -- Clamp tooltip size
    local width = math.min(MAX_TOOLTIP_WIDTH, 250)
    local height = math.min(MAX_TOOLTIP_HEIGHT, totalHeight)
    
    tooltip.Size = UDim2.new(0, width, 0, height)
    
    -- Update shadow size
    local shadow = tooltip:FindFirstChild("Shadow")
    if shadow then
        shadow.Size = UDim2.new(1, 4, 1, 4)
    end
end

-- Utility functions
function TooltipManager:GetTextBounds(text, textSize, font, maxWidth)
    local textService = game:GetService("TextService")
    return textService:GetTextSize(text, textSize, font, Vector2.new(maxWidth, math.huge))
end

-- Integration functions for UI systems
function TooltipManager:RegisterSlotForTooltip(slotFrame, getItemDataCallback)
    -- Register a slot to show tooltips on hover
    local connections = {}
    
    connections.mouseEnter = slotFrame.MouseEnter:Connect(function()
        spawn(function()
            wait(TOOLTIP_DELAY)
            
            -- Check if still hovering
            if slotFrame:FindFirstChild("ClickButton") and 
               slotFrame.ClickButton.AbsolutePosition.X <= UserInputService:GetMouseLocation().X and
               slotFrame.ClickButton.AbsolutePosition.X + slotFrame.ClickButton.AbsoluteSize.X >= UserInputService:GetMouseLocation().X and
               slotFrame.ClickButton.AbsolutePosition.Y <= UserInputService:GetMouseLocation().Y and
               slotFrame.ClickButton.AbsolutePosition.Y + slotFrame.ClickButton.AbsoluteSize.Y >= UserInputService:GetMouseLocation().Y then
                
                local itemData, itemInstance = getItemDataCallback()
                if itemData then
                    self:ShowTooltip(itemData, itemInstance, slotFrame)
                end
            end
        end)
    end)
    
    connections.mouseLeave = slotFrame.MouseLeave:Connect(function()
        self:HideTooltip()
    end)
    
    -- Store connections for cleanup
    slotFrame:SetAttribute("TooltipConnections", connections)
end

function TooltipManager:UnregisterSlotTooltip(slotFrame)
    -- Cleanup tooltip connections
    local connections = slotFrame:GetAttribute("TooltipConnections")
    if connections then
        for _, connection in pairs(connections) do
            if connection then
                connection:Disconnect()
            end
        end
    end
end

-- Comparison tooltips (for showing stat differences)
function TooltipManager:ShowComparisonTooltip(newItemData, equippedItemData, slotFrame)
    -- Enhanced tooltip showing stat comparisons
    -- This would extend the base tooltip with comparison data
end

return TooltipManager