--[[
    MainMenuController.lua
    Main menu system controller with 5 tabs: CHARACTER, JOBS, SHOP, GANGS, CREDIT SHOP
    Handles tab navigation and UI coordination
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MainMenuController = {}
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- UI References
local MainMenuUI = nil
local TabButtons = {}
local TabPanels = {}
local CurrentTab = "CHARACTER"

-- Tab configurations
local TabConfig = {
    CHARACTER = {
        name = "CHARACTER",
        icon = "rbxassetid://0", -- Character icon
        color = Color3.fromRGB(100, 150, 255),
        position = 1
    },
    JOBS = {
        name = "JOBS", 
        icon = "rbxassetid://0", -- Briefcase icon
        color = Color3.fromRGB(255, 200, 100),
        position = 2
    },
    SHOP = {
        name = "SHOP",
        icon = "rbxassetid://0", -- Shopping cart icon
        color = Color3.fromRGB(100, 255, 150),
        position = 3
    },
    GANGS = {
        name = "GANGS",
        icon = "rbxassetid://0", -- Shield icon
        color = Color3.fromRGB(255, 100, 100),
        position = 4
    },
    CREDIT_SHOP = {
        name = "CREDIT SHOP",
        icon = "rbxassetid://0", -- Diamond icon
        color = Color3.fromRGB(255, 215, 0),
        position = 5
    }
}

-- Initialize main menu
function MainMenuController:Initialize()
    self:CreateMainMenuUI()
    self:SetupEventHandlers()
    self:ShowTab("CHARACTER")
    
    print("MainMenuController initialized")
end

-- Create main menu UI
function MainMenuController:CreateMainMenuUI()
    -- Main container
    MainMenuUI = Instance.new("Frame")
    MainMenuUI.Name = "MainMenuUI"
    MainMenuUI.Size = UDim2.new(0, 1000, 0, 700)
    MainMenuUI.Position = UDim2.new(0.5, -500, 0.5, -350)
    MainMenuUI.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainMenuUI.BorderSizePixel = 3
    MainMenuUI.BorderColor3 = Color3.fromRGB(100, 100, 100)
    MainMenuUI.Visible = false
    MainMenuUI.ZIndex = 100
    MainMenuUI.Parent = PlayerGui
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = MainMenuUI
    
    -- Title text
    local titleText = Instance.new("TextLabel")
    titleText.Name = "TitleText"
    titleText.Size = UDim2.new(1, -50, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.Text = "MAIN MENU"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextScaled = true
    titleText.BackgroundTransparency = 1
    titleText.Font = Enum.Font.SourceSansBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 35, 0, 35)
    closeButton.Position = UDim2.new(1, -40, 0, 2.5)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.BorderSizePixel = 0
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.Parent = titleBar
    
    closeButton.MouseButton1Click:Connect(function()
        self:ToggleMainMenu()
    end)
    
    -- Tab navigation bar
    self:CreateTabNavigation()
    
    -- Content area
    self:CreateContentArea()
    
    -- Create individual tab panels
    self:CreateTabPanels()
end

-- Create tab navigation
function MainMenuController:CreateTabNavigation()
    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, 0, 0, 50)
    tabBar.Position = UDim2.new(0, 0, 0, 40)
    tabBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = MainMenuUI
    
    -- Create tab buttons
    local buttonWidth = 1 / #TabConfig
    local buttonIndex = 0
    
    for tabId, config in pairs(TabConfig) do
        local tabButton = self:CreateTabButton(tabId, config, buttonIndex, buttonWidth)
        tabButton.Parent = tabBar
        TabButtons[tabId] = tabButton
        buttonIndex = buttonIndex + 1
    end
end

-- Create individual tab button
function MainMenuController:CreateTabButton(tabId, config, index, width)
    local button = Instance.new("TextButton")
    button.Name = "Tab_" .. tabId
    button.Size = UDim2.new(width, -2, 1, -4)
    button.Position = UDim2.new(width * index, 2, 0, 2)
    button.Text = ""
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 1
    button.BorderColor3 = Color3.fromRGB(80, 80, 80)
    
    -- Tab icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 24, 0, 24)
    icon.Position = UDim2.new(0, 10, 0.5, -12)
    icon.BackgroundTransparency = 1
    icon.Image = config.icon
    icon.ImageColor3 = Color3.fromRGB(200, 200, 200)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = button
    
    -- Tab text
    local text = Instance.new("TextLabel")
    text.Name = "Text"
    text.Size = UDim2.new(1, -45, 1, 0)
    text.Position = UDim2.new(0, 40, 0, 0)
    text.Text = config.name
    text.TextColor3 = Color3.fromRGB(200, 200, 200)
    text.TextScaled = true
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.SourceSansBold
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = button
    
    -- Click handler
    button.MouseButton1Click:Connect(function()
        self:ShowTab(tabId)
    end)
    
    return button
end

-- Create content area
function MainMenuController:CreateContentArea()
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, 0, 1, -90)
    contentArea.Position = UDim2.new(0, 0, 0, 90)
    contentArea.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    contentArea.BorderSizePixel = 0
    contentArea.Parent = MainMenuUI
end

-- Create tab panels
function MainMenuController:CreateTabPanels()
    local contentArea = MainMenuUI:FindFirstChild("ContentArea")
    
    -- CHARACTER Tab
    TabPanels.CHARACTER = self:CreateCharacterPanel(contentArea)
    
    -- JOBS Tab
    TabPanels.JOBS = self:CreateJobsPanel(contentArea)
    
    -- SHOP Tab
    TabPanels.SHOP = self:CreateShopPanel(contentArea)
    
    -- GANGS Tab
    TabPanels.GANGS = self:CreateGangsPanel(contentArea)
    
    -- CREDIT SHOP Tab
    TabPanels.CREDIT_SHOP = self:CreateCreditShopPanel(contentArea)
end

-- Create CHARACTER panel
function MainMenuController:CreateCharacterPanel(parent)
    local panel = Instance.new("Frame")
    panel.Name = "CharacterPanel"
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.Position = UDim2.new(0, 0, 0, 0)
    panel.BackgroundTransparency = 1
    panel.Visible = false
    panel.Parent = parent
    
    -- 3D Character display (left side)
    local characterFrame = Instance.new("Frame")
    characterFrame.Name = "CharacterFrame"
    characterFrame.Size = UDim2.new(0, 400, 1, -20)
    characterFrame.Position = UDim2.new(0, 10, 0, 10)
    characterFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    characterFrame.BorderSizePixel = 1
    characterFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    characterFrame.Parent = panel
    
    -- Character viewport
    local characterViewport = Instance.new("ViewportFrame")
    characterViewport.Name = "CharacterViewport"
    characterViewport.Size = UDim2.new(1, -20, 0.7, 0)
    characterViewport.Position = UDim2.new(0, 10, 0, 10)
    characterViewport.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    characterViewport.BorderSizePixel = 0
    characterViewport.Parent = characterFrame
    
    -- Equipment slots (right side)
    local equipmentFrame = Instance.new("Frame")
    equipmentFrame.Name = "EquipmentFrame"
    equipmentFrame.Size = UDim2.new(0, 250, 1, -20)
    equipmentFrame.Position = UDim2.new(0, 420, 0, 10)
    equipmentFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    equipmentFrame.BorderSizePixel = 1
    equipmentFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    equipmentFrame.Parent = panel
    
    -- Stats panel (far right)
    local statsFrame = Instance.new("Frame")
    statsFrame.Name = "StatsFrame"
    statsFrame.Size = UDim2.new(0, 300, 1, -20)
    statsFrame.Position = UDim2.new(0, 680, 0, 10)
    statsFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    statsFrame.BorderSizePixel = 1
    statsFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    statsFrame.Parent = panel
    
    return panel
end

-- Create JOBS panel
function MainMenuController:CreateJobsPanel(parent)
    local panel = Instance.new("Frame")
    panel.Name = "JobsPanel"
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.Position = UDim2.new(0, 0, 0, 0)
    panel.BackgroundTransparency = 1
    panel.Visible = false
    panel.Parent = parent
    
    -- Job list (left side)
    local jobListFrame = Instance.new("Frame")
    jobListFrame.Name = "JobListFrame"
    jobListFrame.Size = UDim2.new(0, 300, 1, -20)
    jobListFrame.Position = UDim2.new(0, 10, 0, 10)
    jobListFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    jobListFrame.BorderSizePixel = 1
    jobListFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    jobListFrame.Parent = panel
    
    -- Job details (right side)
    local jobDetailsFrame = Instance.new("Frame")
    jobDetailsFrame.Name = "JobDetailsFrame"
    jobDetailsFrame.Size = UDim2.new(1, -320, 1, -20)
    jobDetailsFrame.Position = UDim2.new(0, 320, 0, 10)
    jobDetailsFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    jobDetailsFrame.BorderSizePixel = 1
    jobDetailsFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    jobDetailsFrame.Parent = panel
    
    return panel
end

-- Create SHOP panel
function MainMenuController:CreateShopPanel(parent)
    local panel = Instance.new("Frame")
    panel.Name = "ShopPanel"
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.Position = UDim2.new(0, 0, 0, 0)
    panel.BackgroundTransparency = 1
    panel.Visible = false
    panel.Parent = parent
    
    -- Category tabs
    local categoryFrame = Instance.new("Frame")
    categoryFrame.Name = "CategoryFrame"
    categoryFrame.Size = UDim2.new(1, -20, 0, 40)
    categoryFrame.Position = UDim2.new(0, 10, 0, 10)
    categoryFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    categoryFrame.BorderSizePixel = 0
    categoryFrame.Parent = panel
    
    -- Shop items grid
    local itemsFrame = Instance.new("Frame")
    itemsFrame.Name = "ItemsFrame"
    itemsFrame.Size = UDim2.new(1, -20, 1, -70)
    itemsFrame.Position = UDim2.new(0, 10, 0, 60)
    itemsFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    itemsFrame.BorderSizePixel = 1
    itemsFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    itemsFrame.Parent = panel
    
    return panel
end

-- Create GANGS panel
function MainMenuController:CreateGangsPanel(parent)
    local panel = Instance.new("Frame")
    panel.Name = "GangsPanel"
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.Position = UDim2.new(0, 0, 0, 0)
    panel.BackgroundTransparency = 1
    panel.Visible = false
    panel.Parent = parent
    
    -- Gang info (top)
    local gangInfoFrame = Instance.new("Frame")
    gangInfoFrame.Name = "GangInfoFrame"
    gangInfoFrame.Size = UDim2.new(1, -20, 0, 200)
    gangInfoFrame.Position = UDim2.new(0, 10, 0, 10)
    gangInfoFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    gangInfoFrame.BorderSizePixel = 1
    gangInfoFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    gangInfoFrame.Parent = panel
    
    -- Gang members/upgrades (bottom)
    local gangContentFrame = Instance.new("Frame")
    gangContentFrame.Name = "GangContentFrame"
    gangContentFrame.Size = UDim2.new(1, -20, 1, -230)
    gangContentFrame.Position = UDim2.new(0, 10, 0, 220)
    gangContentFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    gangContentFrame.BorderSizePixel = 1
    gangContentFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    gangContentFrame.Parent = panel
    
    return panel
end

-- Create CREDIT SHOP panel
function MainMenuController:CreateCreditShopPanel(parent)
    local panel = Instance.new("Frame")
    panel.Name = "CreditShopPanel"
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.Position = UDim2.new(0, 0, 0, 0)
    panel.BackgroundTransparency = 1
    panel.Visible = false
    panel.Parent = parent
    
    -- Credits display (top)
    local creditsFrame = Instance.new("Frame")
    creditsFrame.Name = "CreditsFrame"
    creditsFrame.Size = UDim2.new(1, -20, 0, 60)
    creditsFrame.Position = UDim2.new(0, 10, 0, 10)
    creditsFrame.BackgroundColor3 = Color3.fromRGB(60, 40, 0)
    creditsFrame.BorderSizePixel = 1
    creditsFrame.BorderColor3 = Color3.fromRGB(255, 215, 0)
    creditsFrame.Parent = panel
    
    -- Premium items grid
    local premiumItemsFrame = Instance.new("Frame")
    premiumItemsFrame.Name = "PremiumItemsFrame"
    premiumItemsFrame.Size = UDim2.new(1, -20, 1, -90)
    premiumItemsFrame.Position = UDim2.new(0, 10, 0, 80)
    premiumItemsFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    premiumItemsFrame.BorderSizePixel = 1
    premiumItemsFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    premiumItemsFrame.Parent = panel
    
    return panel
end

-- Setup event handlers
function MainMenuController:SetupEventHandlers()
    -- Keybind to toggle menu (M key)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.M then
            self:ToggleMainMenu()
        end
    end)
end

-- Show specific tab
function MainMenuController:ShowTab(tabId)
    if not TabPanels[tabId] then return end
    
    -- Hide all panels
    for _, panel in pairs(TabPanels) do
        panel.Visible = false
    end
    
    -- Show selected panel
    TabPanels[tabId].Visible = true
    CurrentTab = tabId
    
    -- Update tab button states
    self:UpdateTabButtons()
    
    -- Load tab content
    self:LoadTabContent(tabId)
    
    print("Switched to tab:", tabId)
end

-- Update tab button visual states
function MainMenuController:UpdateTabButtons()
    for tabId, button in pairs(TabButtons) do
        local isActive = (tabId == CurrentTab)
        local config = TabConfig[tabId]
        
        if isActive then
            button.BackgroundColor3 = config.color
            button.BorderColor3 = Color3.fromRGB(255, 255, 255)
            
            local icon = button:FindFirstChild("Icon")
            local text = button:FindFirstChild("Text")
            
            if icon then icon.ImageColor3 = Color3.fromRGB(255, 255, 255) end
            if text then text.TextColor3 = Color3.fromRGB(255, 255, 255) end
        else
            button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            button.BorderColor3 = Color3.fromRGB(80, 80, 80)
            
            local icon = button:FindFirstChild("Icon")
            local text = button:FindFirstChild("Text")
            
            if icon then icon.ImageColor3 = Color3.fromRGB(200, 200, 200) end
            if text then text.TextColor3 = Color3.fromRGB(200, 200, 200) end
        end
    end
end

-- Load content for specific tab
function MainMenuController:LoadTabContent(tabId)
    if tabId == "CHARACTER" then
        self:LoadCharacterContent()
    elseif tabId == "JOBS" then
        self:LoadJobsContent()
    elseif tabId == "SHOP" then
        self:LoadShopContent()
    elseif tabId == "GANGS" then
        self:LoadGangsContent()
    elseif tabId == "CREDIT_SHOP" then
        self:LoadCreditShopContent()
    end
end

-- Load CHARACTER tab content
function MainMenuController:LoadCharacterContent()
    local panel = TabPanels.CHARACTER
    
    -- Load 3D character model
    self:Load3DCharacter(panel)
    
    -- Load equipment display
    self:LoadEquipmentDisplay(panel)
    
    -- Load stats display
    self:LoadStatsDisplay(panel)
end

-- Load 3D character model
function MainMenuController:Load3DCharacter(panel)
    local characterFrame = panel:FindFirstChild("CharacterFrame")
    if not characterFrame then return end
    
    local viewport = characterFrame:FindFirstChild("CharacterViewport")
    if not viewport then return end
    
    -- Create or update character model in viewport
    local character = LocalPlayer.Character
    if character then
        -- Clone character for display
        -- Implementation would go here
        print("Loading 3D character model")
    end
end

-- Load equipment display
function MainMenuController:LoadEquipmentDisplay(panel)
    local equipmentFrame = panel:FindFirstChild("EquipmentFrame")
    if not equipmentFrame then return end
    
    -- This would integrate with the InventoryController
    print("Loading equipment display")
end

-- Load stats display
function MainMenuController:LoadStatsDisplay(panel)
    local statsFrame = panel:FindFirstChild("StatsFrame")
    if not statsFrame then return end
    
    -- Display combined stats from equipment, gang, and base stats
    print("Loading stats display")
end

-- Load JOBS tab content
function MainMenuController:LoadJobsContent()
    print("Loading jobs content")
    -- Would integrate with job system
end

-- Load SHOP tab content
function MainMenuController:LoadShopContent()
    print("Loading shop content")
    -- Would integrate with shop system
end

-- Load GANGS tab content
function MainMenuController:LoadGangsContent()
    print("Loading gangs content")
    -- Would integrate with gang system
end

-- Load CREDIT SHOP tab content
function MainMenuController:LoadCreditShopContent()
    print("Loading credit shop content")
    -- Would integrate with premium shop system
end

-- Toggle main menu visibility
function MainMenuController:ToggleMainMenu()
    if MainMenuUI then
        MainMenuUI.Visible = not MainMenuUI.Visible
        
        if MainMenuUI.Visible then
            self:ShowTab(CurrentTab)
        end
    end
end

-- Show main menu
function MainMenuController:ShowMainMenu()
    if MainMenuUI then
        MainMenuUI.Visible = true
        self:ShowTab(CurrentTab)
    end
end

-- Hide main menu
function MainMenuController:HideMainMenu()
    if MainMenuUI then
        MainMenuUI.Visible = false
    end
end

-- Get current tab
function MainMenuController:GetCurrentTab()
    return CurrentTab
end

-- Check if menu is visible
function MainMenuController:IsVisible()
    return MainMenuUI and MainMenuUI.Visible
end

return MainMenuController