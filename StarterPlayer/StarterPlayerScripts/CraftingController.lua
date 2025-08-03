--[[
    CraftingController.lua
    Client-side crafting system controller
    Handles crafting UI, recipe browsing, and batch crafting operations
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local RecipeDatabase = require(ReplicatedStorage.RecipeDatabase)
local CraftingController = {}

-- Services and References
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Local State
local AvailableRecipes = {}
local CraftingStatus = {}
local SelectedRecipe = nil
local CraftingQueue = {}

-- UI References
local CraftingUI = nil
local RecipeList = nil
local RecipeDetails = nil
local CraftingProgress = nil
local QueueDisplay = nil

-- Constants
local RECIPE_BUTTON_HEIGHT = 60
local MAX_VISIBLE_RECIPES = 8

-- Events (will be connected by events system)
local CraftingEvents = {}

-- Initialize controller
function CraftingController:Initialize()
    self:CreateUI()
    self:SetupEventHandlers()
    self:RequestCraftingData()
    
    print("CraftingController initialized")
end

-- Create crafting UI
function CraftingController:CreateUI()
    -- Main crafting frame
    CraftingUI = Instance.new("Frame")
    CraftingUI.Name = "CraftingUI"
    CraftingUI.Size = UDim2.new(0, 700, 0, 500)
    CraftingUI.Position = UDim2.new(0.5, -350, 0.5, -250)
    CraftingUI.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    CraftingUI.BorderSizePixel = 2
    CraftingUI.BorderColor3 = Color3.fromRGB(100, 100, 100)
    CraftingUI.Visible = false
    CraftingUI.Parent = PlayerGui
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Text = "CRAFTING SYSTEM"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    title.BorderSizePixel = 0
    title.Font = Enum.Font.SourceSansBold
    title.Parent = CraftingUI
    
    -- Create sections
    self:CreateRecipeList()
    self:CreateRecipeDetails()
    self:CreateCraftingProgress()
    self:CreateQueueDisplay()
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
    closeButton.Parent = CraftingUI
    
    closeButton.MouseButton1Click:Connect(function()
        self:ToggleCrafting()
    end)
end

-- Create recipe list
function CraftingController:CreateRecipeList()
    local listFrame = Instance.new("Frame")
    listFrame.Name = "RecipeListFrame"
    listFrame.Size = UDim2.new(0, 200, 1, -100)
    listFrame.Position = UDim2.new(0, 10, 0, 40)
    listFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    listFrame.BorderSizePixel = 1
    listFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    listFrame.Parent = CraftingUI
    
    -- List title
    local listTitle = Instance.new("TextLabel")
    listTitle.Name = "ListTitle"
    listTitle.Size = UDim2.new(1, 0, 0, 25)
    listTitle.Position = UDim2.new(0, 0, 0, 0)
    listTitle.Text = "RECIPES"
    listTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    listTitle.TextScaled = true
    listTitle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    listTitle.BorderSizePixel = 0
    listTitle.Font = Enum.Font.SourceSansBold
    listTitle.Parent = listFrame
    
    -- Scrollable recipe list
    RecipeList = Instance.new("ScrollingFrame")
    RecipeList.Name = "RecipeList"
    RecipeList.Size = UDim2.new(1, -10, 1, -30)
    RecipeList.Position = UDim2.new(0, 5, 0, 25)
    RecipeList.BackgroundTransparency = 1
    RecipeList.BorderSizePixel = 0
    RecipeList.ScrollBarThickness = 8
    RecipeList.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    RecipeList.CanvasSize = UDim2.new(0, 0, 0, 0)
    RecipeList.Parent = listFrame
end

-- Create recipe details panel
function CraftingController:CreateRecipeDetails()
    local detailsFrame = Instance.new("Frame")
    detailsFrame.Name = "RecipeDetailsFrame"
    detailsFrame.Size = UDim2.new(0, 280, 1, -100)
    detailsFrame.Position = UDim2.new(0, 220, 0, 40)
    detailsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    detailsFrame.BorderSizePixel = 1
    detailsFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    detailsFrame.Parent = CraftingUI
    
    RecipeDetails = detailsFrame
    
    -- Details content (will be populated dynamically)
    self:CreateDetailsContent()
end

-- Create details content
function CraftingController:CreateDetailsContent()
    -- Recipe name
    local recipeName = Instance.new("TextLabel")
    recipeName.Name = "RecipeName"
    recipeName.Size = UDim2.new(1, -10, 0, 30)
    recipeName.Position = UDim2.new(0, 5, 0, 5)
    recipeName.Text = "Select a Recipe"
    recipeName.TextColor3 = Color3.fromRGB(255, 255, 255)
    recipeName.TextScaled = true
    recipeName.BackgroundTransparency = 1
    recipeName.Font = Enum.Font.SourceSansBold
    recipeName.TextXAlignment = Enum.TextXAlignment.Left
    recipeName.Parent = RecipeDetails
    
    -- Output item
    local outputFrame = Instance.new("Frame")
    outputFrame.Name = "OutputFrame"
    outputFrame.Size = UDim2.new(1, -10, 0, 80)
    outputFrame.Position = UDim2.new(0, 5, 0, 40)
    outputFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    outputFrame.BorderSizePixel = 1
    outputFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    outputFrame.Parent = RecipeDetails
    
    local outputLabel = Instance.new("TextLabel")
    outputLabel.Name = "OutputLabel"
    outputLabel.Size = UDim2.new(1, 0, 0, 20)
    outputLabel.Position = UDim2.new(0, 0, 0, 0)
    outputLabel.Text = "CRAFTS:"
    outputLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    outputLabel.TextScaled = true
    outputLabel.BackgroundTransparency = 1
    outputLabel.Font = Enum.Font.SourceSans
    outputLabel.Parent = outputFrame
    
    -- Output item icon and name
    local outputIcon = Instance.new("ImageLabel")
    outputIcon.Name = "OutputIcon"
    outputIcon.Size = UDim2.new(0, 50, 0, 50)
    outputIcon.Position = UDim2.new(0, 5, 0, 25)
    outputIcon.BackgroundTransparency = 1
    outputIcon.Image = ""
    outputIcon.ScaleType = Enum.ScaleType.Fit
    outputIcon.Parent = outputFrame
    
    local outputName = Instance.new("TextLabel")
    outputName.Name = "OutputName"
    outputName.Size = UDim2.new(1, -65, 0, 25)
    outputName.Position = UDim2.new(0, 60, 0, 25)
    outputName.Text = ""
    outputName.TextColor3 = Color3.fromRGB(255, 255, 255)
    outputName.TextScaled = true
    outputName.BackgroundTransparency = 1
    outputName.Font = Enum.Font.SourceSans
    outputName.TextXAlignment = Enum.TextXAlignment.Left
    outputName.Parent = outputFrame
    
    local outputQuantity = Instance.new("TextLabel")
    outputQuantity.Name = "OutputQuantity"
    outputQuantity.Size = UDim2.new(1, -65, 0, 20)
    outputQuantity.Position = UDim2.new(0, 60, 0, 50)
    outputQuantity.Text = ""
    outputQuantity.TextColor3 = Color3.fromRGB(200, 200, 200)
    outputQuantity.TextScaled = true
    outputQuantity.BackgroundTransparency = 1
    outputQuantity.Font = Enum.Font.SourceSans
    outputQuantity.TextXAlignment = Enum.TextXAlignment.Left
    outputQuantity.Parent = outputFrame
    
    -- Requirements section
    local requirementsFrame = Instance.new("Frame")
    requirementsFrame.Name = "RequirementsFrame"
    requirementsFrame.Size = UDim2.new(1, -10, 0, 180)
    requirementsFrame.Position = UDim2.new(0, 5, 0, 130)
    requirementsFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    requirementsFrame.BorderSizePixel = 1
    requirementsFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    requirementsFrame.Parent = RecipeDetails
    
    local reqLabel = Instance.new("TextLabel")
    reqLabel.Name = "RequirementsLabel"
    reqLabel.Size = UDim2.new(1, 0, 0, 20)
    reqLabel.Position = UDim2.new(0, 0, 0, 0)
    reqLabel.Text = "REQUIREMENTS:"
    reqLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    reqLabel.TextScaled = true
    reqLabel.BackgroundTransparency = 1
    reqLabel.Font = Enum.Font.SourceSans
    reqLabel.Parent = requirementsFrame
    
    -- Scrollable requirements list
    local reqList = Instance.new("ScrollingFrame")
    reqList.Name = "RequirementsList"
    reqList.Size = UDim2.new(1, -5, 1, -25)
    reqList.Position = UDim2.new(0, 0, 0, 25)
    reqList.BackgroundTransparency = 1
    reqList.BorderSizePixel = 0
    reqList.ScrollBarThickness = 6
    reqList.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    reqList.CanvasSize = UDim2.new(0, 0, 0, 0)
    reqList.Parent = requirementsFrame
    
    -- Recipe info
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Size = UDim2.new(1, -10, 0, 80)
    infoFrame.Position = UDim2.new(0, 5, 0, 320)
    infoFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    infoFrame.BorderSizePixel = 1
    infoFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    infoFrame.Parent = RecipeDetails
    
    local levelReq = Instance.new("TextLabel")
    levelReq.Name = "LevelRequirement"
    levelReq.Size = UDim2.new(1, 0, 0, 20)
    levelReq.Position = UDim2.new(0, 5, 0, 5)
    levelReq.Text = "Level Required: 0"
    levelReq.TextColor3 = Color3.fromRGB(200, 200, 200)
    levelReq.TextScaled = true
    levelReq.BackgroundTransparency = 1
    levelReq.Font = Enum.Font.SourceSans
    levelReq.TextXAlignment = Enum.TextXAlignment.Left
    levelReq.Parent = infoFrame
    
    local successRate = Instance.new("TextLabel")
    successRate.Name = "SuccessRate"
    successRate.Size = UDim2.new(1, 0, 0, 20)
    successRate.Position = UDim2.new(0, 5, 0, 25)
    successRate.Text = "Success Rate: 0%"
    successRate.TextColor3 = Color3.fromRGB(200, 200, 200)
    successRate.TextScaled = true
    successRate.BackgroundTransparency = 1
    successRate.Font = Enum.Font.SourceSans
    successRate.TextXAlignment = Enum.TextXAlignment.Left
    successRate.Parent = infoFrame
    
    local craftTime = Instance.new("TextLabel")
    craftTime.Name = "CraftTime"
    craftTime.Size = UDim2.new(1, 0, 0, 20)
    craftTime.Position = UDim2.new(0, 5, 0, 45)
    craftTime.Text = "Craft Time: 0s"
    craftTime.TextColor3 = Color3.fromRGB(200, 200, 200)
    craftTime.TextScaled = true
    craftTime.BackgroundTransparency = 1
    craftTime.Font = Enum.Font.SourceSans
    craftTime.TextXAlignment = Enum.TextXAlignment.Left
    craftTime.Parent = infoFrame
end

-- Create crafting progress display
function CraftingController:CreateCraftingProgress()
    local progressFrame = Instance.new("Frame")
    progressFrame.Name = "CraftingProgressFrame"
    progressFrame.Size = UDim2.new(0, 190, 0, 150)
    progressFrame.Position = UDim2.new(0, 510, 0, 40)
    progressFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    progressFrame.BorderSizePixel = 1
    progressFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    progressFrame.Parent = CraftingUI
    
    CraftingProgress = progressFrame
    
    -- Progress title
    local progressTitle = Instance.new("TextLabel")
    progressTitle.Name = "ProgressTitle"
    progressTitle.Size = UDim2.new(1, 0, 0, 25)
    progressTitle.Position = UDim2.new(0, 0, 0, 0)
    progressTitle.Text = "PROGRESS"
    progressTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    progressTitle.TextScaled = true
    progressTitle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    progressTitle.BorderSizePixel = 0
    progressTitle.Font = Enum.Font.SourceSansBold
    progressTitle.Parent = progressFrame
    
    -- Current craft info
    local currentCraft = Instance.new("TextLabel")
    currentCraft.Name = "CurrentCraft"
    currentCraft.Size = UDim2.new(1, -10, 0, 20)
    currentCraft.Position = UDim2.new(0, 5, 0, 30)
    currentCraft.Text = "No active crafting"
    currentCraft.TextColor3 = Color3.fromRGB(200, 200, 200)
    currentCraft.TextScaled = true
    currentCraft.BackgroundTransparency = 1
    currentCraft.Font = Enum.Font.SourceSans
    currentCraft.TextXAlignment = Enum.TextXAlignment.Left
    currentCraft.Parent = progressFrame
    
    -- Progress bar
    local progressBG = Instance.new("Frame")
    progressBG.Name = "ProgressBackground"
    progressBG.Size = UDim2.new(1, -10, 0, 20)
    progressBG.Position = UDim2.new(0, 5, 0, 55)
    progressBG.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    progressBG.BorderSizePixel = 1
    progressBG.BorderColor3 = Color3.fromRGB(80, 80, 80)
    progressBG.Parent = progressFrame
    
    local progressBar = Instance.new("Frame")
    progressBar.Name = "ProgressBar"
    progressBar.Size = UDim2.new(0, 0, 1, 0)
    progressBar.Position = UDim2.new(0, 0, 0, 0)
    progressBar.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    progressBar.BorderSizePixel = 0
    progressBar.Parent = progressBG
    
    -- Time remaining
    local timeRemaining = Instance.new("TextLabel")
    timeRemaining.Name = "TimeRemaining"
    timeRemaining.Size = UDim2.new(1, -10, 0, 20)
    timeRemaining.Position = UDim2.new(0, 5, 0, 80)
    timeRemaining.Text = ""
    timeRemaining.TextColor3 = Color3.fromRGB(200, 200, 200)
    timeRemaining.TextScaled = true
    timeRemaining.BackgroundTransparency = 1
    timeRemaining.Font = Enum.Font.SourceSans
    timeRemaining.TextXAlignment = Enum.TextXAlignment.Left
    timeRemaining.Parent = progressFrame
    
    -- Cancel button
    local cancelButton = Instance.new("TextButton")
    cancelButton.Name = "CancelButton"
    cancelButton.Size = UDim2.new(1, -10, 0, 25)
    cancelButton.Position = UDim2.new(0, 5, 0, 105)
    cancelButton.Text = "CANCEL"
    cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelButton.TextScaled = true
    cancelButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    cancelButton.BorderSizePixel = 0
    cancelButton.Font = Enum.Font.SourceSansBold
    cancelButton.Parent = progressFrame
    
    cancelButton.MouseButton1Click:Connect(function()
        self:CancelCrafting()
    end)
end

-- Create queue display
function CraftingController:CreateQueueDisplay()
    local queueFrame = Instance.new("Frame")
    queueFrame.Name = "QueueFrame"
    queueFrame.Size = UDim2.new(0, 190, 0, 150)
    queueFrame.Position = UDim2.new(0, 510, 0, 200)
    queueFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    queueFrame.BorderSizePixel = 1
    queueFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    queueFrame.Parent = CraftingUI
    
    QueueDisplay = queueFrame
    
    -- Queue title
    local queueTitle = Instance.new("TextLabel")
    queueTitle.Name = "QueueTitle"
    queueTitle.Size = UDim2.new(1, 0, 0, 25)
    queueTitle.Position = UDim2.new(0, 0, 0, 0)
    queueTitle.Text = "QUEUE"
    queueTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    queueTitle.TextScaled = true
    queueTitle.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    queueTitle.BorderSizePixel = 0
    queueTitle.Font = Enum.Font.SourceSansBold
    queueTitle.Parent = queueFrame
    
    -- Queue list
    local queueList = Instance.new("ScrollingFrame")
    queueList.Name = "QueueList"
    queueList.Size = UDim2.new(1, -5, 1, -55)
    queueList.Position = UDim2.new(0, 0, 0, 25)
    queueList.BackgroundTransparency = 1
    queueList.BorderSizePixel = 0
    queueList.ScrollBarThickness = 6
    queueList.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    queueList.CanvasSize = UDim2.new(0, 0, 0, 0)
    queueList.Parent = queueFrame
    
    -- Clear queue button
    local clearButton = Instance.new("TextButton")
    clearButton.Name = "ClearQueueButton"
    clearButton.Size = UDim2.new(1, -10, 0, 25)
    clearButton.Position = UDim2.new(0, 5, 1, -30)
    clearButton.Text = "CLEAR QUEUE"
    clearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearButton.TextScaled = true
    clearButton.BackgroundColor3 = Color3.fromRGB(150, 100, 50)
    clearButton.BorderSizePixel = 0
    clearButton.Font = Enum.Font.SourceSansBold
    clearButton.Parent = queueFrame
    
    clearButton.MouseButton1Click:Connect(function()
        self:ClearQueue()
    end)
end

-- Create action buttons
function CraftingController:CreateActionButtons()
    local actionFrame = Instance.new("Frame")
    actionFrame.Name = "ActionFrame"
    actionFrame.Size = UDim2.new(0, 280, 0, 40)
    actionFrame.Position = UDim2.new(0, 220, 1, -50)
    actionFrame.BackgroundTransparency = 1
    actionFrame.Parent = CraftingUI
    
    -- Quantity input
    local quantityLabel = Instance.new("TextLabel")
    quantityLabel.Name = "QuantityLabel"
    quantityLabel.Size = UDim2.new(0, 60, 1, 0)
    quantityLabel.Position = UDim2.new(0, 0, 0, 0)
    quantityLabel.Text = "Quantity:"
    quantityLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    quantityLabel.TextScaled = true
    quantityLabel.BackgroundTransparency = 1
    quantityLabel.Font = Enum.Font.SourceSans
    quantityLabel.Parent = actionFrame
    
    local quantityInput = Instance.new("TextBox")
    quantityInput.Name = "QuantityInput"
    quantityInput.Size = UDim2.new(0, 50, 1, 0)
    quantityInput.Position = UDim2.new(0, 65, 0, 0)
    quantityInput.Text = "1"
    quantityInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    quantityInput.TextScaled = true
    quantityInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    quantityInput.BorderSizePixel = 1
    quantityInput.BorderColor3 = Color3.fromRGB(100, 100, 100)
    quantityInput.Font = Enum.Font.SourceSans
    quantityInput.Parent = actionFrame
    
    -- Craft button
    local craftButton = Instance.new("TextButton")
    craftButton.Name = "CraftButton"
    craftButton.Size = UDim2.new(0, 80, 1, 0)
    craftButton.Position = UDim2.new(0, 125, 0, 0)
    craftButton.Text = "CRAFT"
    craftButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    craftButton.TextScaled = true
    craftButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    craftButton.BorderSizePixel = 0
    craftButton.Font = Enum.Font.SourceSansBold
    craftButton.Parent = actionFrame
    
    craftButton.MouseButton1Click:Connect(function()
        self:StartCrafting()
    end)
    
    -- Queue button
    local queueButton = Instance.new("TextButton")
    queueButton.Name = "QueueButton"
    queueButton.Size = UDim2.new(0, 80, 1, 0)
    queueButton.Position = UDim2.new(0, 210, 0, 0)
    queueButton.Text = "QUEUE"
    queueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    queueButton.TextScaled = true
    queueButton.BackgroundColor3 = Color3.fromRGB(100, 100, 150)
    queueButton.BorderSizePixel = 0
    queueButton.Font = Enum.Font.SourceSansBold
    queueButton.Parent = actionFrame
    
    queueButton.MouseButton1Click:Connect(function()
        self:AddToQueue()
    end)
end

-- Event handlers
function CraftingController:SetupEventHandlers()
    -- Will be connected by events system
    -- CraftingEvents.RecipesUpdated:Connect(function(recipes) ... end)
    -- CraftingEvents.CraftingStatusUpdated:Connect(function(status) ... end)
end

-- UI Control Functions
function CraftingController:ToggleCrafting()
    CraftingUI.Visible = not CraftingUI.Visible
    
    if CraftingUI.Visible then
        self:RefreshUI()
    end
end

function CraftingController:RefreshUI()
    self:RefreshRecipeList()
    self:RefreshCraftingProgress()
    self:RefreshQueueDisplay()
    
    if SelectedRecipe then
        self:ShowRecipeDetails(SelectedRecipe)
    end
end

function CraftingController:RefreshRecipeList()
    -- Clear existing buttons
    for _, child in pairs(RecipeList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local yPos = 0
    for recipeId, recipe in pairs(AvailableRecipes) do
        local recipeButton = self:CreateRecipeButton(recipeId, recipe)
        recipeButton.Position = UDim2.new(0, 0, 0, yPos)
        recipeButton.Parent = RecipeList
        
        yPos = yPos + RECIPE_BUTTON_HEIGHT + 5
    end
    
    -- Update canvas size
    RecipeList.CanvasSize = UDim2.new(0, 0, 0, yPos)
end

function CraftingController:CreateRecipeButton(recipeId, recipe)
    local button = Instance.new("Frame")
    button.Name = recipeId
    button.Size = UDim2.new(1, -10, 0, RECIPE_BUTTON_HEIGHT)
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 1
    button.BorderColor3 = Color3.fromRGB(100, 100, 100)
    
    -- Recipe icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 50, 0, 50)
    icon.Position = UDim2.new(0, 5, 0, 5)
    icon.BackgroundTransparency = 1
    icon.Image = "" -- Would use output item icon
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = button
    
    -- Recipe name
    local name = Instance.new("TextLabel")
    name.Name = "RecipeName"
    name.Size = UDim2.new(1, -65, 0, 25)
    name.Position = UDim2.new(0, 60, 0, 5)
    name.Text = recipe.Name
    name.TextColor3 = Color3.fromRGB(255, 255, 255)
    name.TextScaled = true
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.SourceSansBold
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Parent = button
    
    -- Level requirement
    local level = Instance.new("TextLabel")
    level.Name = "LevelReq"
    level.Size = UDim2.new(1, -65, 0, 15)
    level.Position = UDim2.new(0, 60, 0, 30)
    level.Text = "Level " .. recipe.RequiredLevel
    level.TextColor3 = Color3.fromRGB(200, 200, 200)
    level.TextScaled = true
    level.BackgroundTransparency = 1
    level.Font = Enum.Font.SourceSans
    level.TextXAlignment = Enum.TextXAlignment.Left
    level.Parent = button
    
    -- Category
    local category = Instance.new("TextLabel")
    category.Name = "Category"
    category.Size = UDim2.new(1, -65, 0, 15)
    category.Position = UDim2.new(0, 60, 0, 45)
    category.Text = recipe.Category
    category.TextColor3 = Color3.fromRGB(150, 150, 150)
    category.TextScaled = true
    category.BackgroundTransparency = 1
    category.Font = Enum.Font.SourceSans
    category.TextXAlignment = Enum.TextXAlignment.Left
    category.Parent = button
    
    -- Click detection
    local clickButton = Instance.new("TextButton")
    clickButton.Name = "ClickButton"
    clickButton.Size = UDim2.new(1, 0, 1, 0)
    clickButton.Position = UDim2.new(0, 0, 0, 0)
    clickButton.Text = ""
    clickButton.BackgroundTransparency = 1
    clickButton.Parent = button
    
    clickButton.MouseButton1Click:Connect(function()
        self:SelectRecipe(recipeId)
    end)
    
    return button
end

function CraftingController:SelectRecipe(recipeId)
    SelectedRecipe = recipeId
    self:ShowRecipeDetails(recipeId)
    self:UpdateRecipeSelection()
end

function CraftingController:ShowRecipeDetails(recipeId)
    local recipe = AvailableRecipes[recipeId]
    if not recipe then return end
    
    -- Update recipe name
    local recipeName = RecipeDetails:FindFirstChild("RecipeName")
    if recipeName then
        recipeName.Text = recipe.Name
    end
    
    -- Update output item
    local outputFrame = RecipeDetails:FindFirstChild("OutputFrame")
    if outputFrame then
        local outputIcon = outputFrame:FindFirstChild("OutputIcon")
        local outputName = outputFrame:FindFirstChild("OutputName")
        local outputQuantity = outputFrame:FindFirstChild("OutputQuantity")
        
        local outputItem = ItemDatabase:GetItem(recipe.Output.itemId)
        if outputItem then
            if outputIcon then outputIcon.Image = outputItem.Icon end
            if outputName then outputName.Text = outputItem.Name end
            if outputQuantity then outputQuantity.Text = "x" .. recipe.Output.quantity end
        end
    end
    
    -- Update requirements
    self:UpdateRequirements(recipe)
    
    -- Update info
    local infoFrame = RecipeDetails:FindFirstChild("InfoFrame")
    if infoFrame then
        local levelReq = infoFrame:FindFirstChild("LevelRequirement")
        local successRate = infoFrame:FindFirstChild("SuccessRate")
        local craftTime = infoFrame:FindFirstChild("CraftTime")
        
        if levelReq then levelReq.Text = "Level Required: " .. recipe.RequiredLevel end
        if successRate then successRate.Text = "Success Rate: " .. recipe.BaseSuccessRate .. "%" end
        if craftTime then craftTime.Text = "Craft Time: " .. recipe.CraftingTime .. "s" end
    end
end

function CraftingController:UpdateRequirements(recipe)
    local reqFrame = RecipeDetails:FindFirstChild("RequirementsFrame")
    if not reqFrame then return end
    
    local reqList = reqFrame:FindFirstChild("RequirementsList")
    if not reqList then return end
    
    -- Clear existing requirements
    for _, child in pairs(reqList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local yPos = 0
    for _, ingredient in pairs(recipe.Ingredients) do
        local reqItem = self:CreateRequirementItem(ingredient)
        reqItem.Position = UDim2.new(0, 0, 0, yPos)
        reqItem.Parent = reqList
        
        yPos = yPos + 35
    end
    
    reqList.CanvasSize = UDim2.new(0, 0, 0, yPos)
end

function CraftingController:CreateRequirementItem(ingredient)
    local item = Instance.new("Frame")
    item.Name = ingredient.itemId
    item.Size = UDim2.new(1, -10, 0, 30)
    item.BackgroundTransparency = 1
    
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 25, 0, 25)
    icon.Position = UDim2.new(0, 0, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Image = ""
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = item
    
    local name = Instance.new("TextLabel")
    name.Name = "ItemName"
    name.Size = UDim2.new(1, -30, 0, 25)
    name.Position = UDim2.new(0, 30, 0, 0)
    name.Text = ""
    name.TextColor3 = Color3.fromRGB(255, 255, 255)
    name.TextScaled = true
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.SourceSans
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Parent = item
    
    -- Get item data
    local itemData = ItemDatabase:GetItem(ingredient.itemId)
    if itemData then
        icon.Image = itemData.Icon
        name.Text = itemData.Name .. " x" .. ingredient.quantity
    else
        name.Text = ingredient.itemId .. " x" .. ingredient.quantity
    end
    
    return item
end

function CraftingController:UpdateRecipeSelection()
    -- Update visual selection in recipe list
    for _, child in pairs(RecipeList:GetChildren()) do
        if child:IsA("Frame") then
            if child.Name == SelectedRecipe then
                child.BorderColor3 = Color3.fromRGB(100, 200, 255)
                child.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
            else
                child.BorderColor3 = Color3.fromRGB(100, 100, 100)
                child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end
        end
    end
end

-- Crafting actions
function CraftingController:StartCrafting()
    if not SelectedRecipe then return end
    
    local quantityInput = CraftingUI:FindFirstChild("ActionFrame"):FindFirstChild("QuantityInput")
    local quantity = tonumber(quantityInput.Text) or 1
    quantity = math.max(1, math.min(10, quantity)) -- Clamp between 1-10
    
    self:RequestStartCrafting(SelectedRecipe, quantity)
end

function CraftingController:AddToQueue()
    if not SelectedRecipe then return end
    
    local quantityInput = CraftingUI:FindFirstChild("ActionFrame"):FindFirstChild("QuantityInput")
    local quantity = tonumber(quantityInput.Text) or 1
    quantity = math.max(1, math.min(10, quantity))
    
    self:RequestAddToQueue(SelectedRecipe, quantity)
end

function CraftingController:CancelCrafting()
    self:RequestCancelCrafting()
end

function CraftingController:ClearQueue()
    self:RequestClearQueue()
end

-- Server requests (will be handled by events system)
function CraftingController:RequestCraftingData()
    -- Request available recipes and current status
    -- CraftingEvents:RequestCraftingData()
end

function CraftingController:RequestStartCrafting(recipeId, quantity)
    -- CraftingEvents:StartCrafting(recipeId, quantity)
end

function CraftingController:RequestAddToQueue(recipeId, quantity)
    -- CraftingEvents:AddToQueue(recipeId, quantity)
end

function CraftingController:RequestCancelCrafting()
    -- CraftingEvents:CancelCrafting()
end

function CraftingController:RequestClearQueue()
    -- CraftingEvents:ClearQueue()
end

-- Progress display updates
function CraftingController:RefreshCraftingProgress()
    local progressFrame = CraftingProgress
    local currentCraft = progressFrame:FindFirstChild("CurrentCraft")
    local progressBar = progressFrame:FindFirstChild("ProgressBackground"):FindFirstChild("ProgressBar")
    local timeRemaining = progressFrame:FindFirstChild("TimeRemaining")
    
    if CraftingStatus.activeCrafting then
        local session = CraftingStatus.activeCrafting
        local recipe = RecipeDatabase:GetRecipe(session.recipeId)
        
        if currentCraft then
            currentCraft.Text = "Crafting: " .. (recipe and recipe.Name or session.recipeId)
        end
        
        -- Calculate progress
        local elapsed = tick() - session.startTime
        local total = session.endTime - session.startTime
        local progress = math.min(1, elapsed / total)
        
        progressBar.Size = UDim2.new(progress, 0, 1, 0)
        
        local remaining = math.max(0, session.endTime - tick())
        if timeRemaining then
            timeRemaining.Text = string.format("Time: %.1fs", remaining)
        end
    else
        if currentCraft then currentCraft.Text = "No active crafting" end
        progressBar.Size = UDim2.new(0, 0, 1, 0)
        if timeRemaining then timeRemaining.Text = "" end
    end
end

function CraftingController:RefreshQueueDisplay()
    local queueFrame = QueueDisplay:FindFirstChild("QueueList")
    if not queueFrame then return end
    
    -- Clear existing queue items
    for _, child in pairs(queueFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local yPos = 0
    for i, queueItem in pairs(CraftingQueue) do
        local itemFrame = self:CreateQueueItem(queueItem, i)
        itemFrame.Position = UDim2.new(0, 0, 0, yPos)
        itemFrame.Parent = queueFrame
        
        yPos = yPos + 25
    end
    
    queueFrame.CanvasSize = UDim2.new(0, 0, 0, yPos)
end

function CraftingController:CreateQueueItem(queueItem, index)
    local item = Instance.new("Frame")
    item.Name = "QueueItem" .. index
    item.Size = UDim2.new(1, -5, 0, 20)
    item.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    item.BorderSizePixel = 1
    item.BorderColor3 = Color3.fromRGB(100, 100, 100)
    
    local text = Instance.new("TextLabel")
    text.Name = "Text"
    text.Size = UDim2.new(1, -5, 1, 0)
    text.Position = UDim2.new(0, 5, 0, 0)
    text.BackgroundTransparency = 1
    text.TextScaled = true
    text.Font = Enum.Font.SourceSans
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.Parent = item
    
    local recipe = RecipeDatabase:GetRecipe(queueItem.recipeId)
    if recipe then
        text.Text = string.format("%d. %s x%d", index, recipe.Name, queueItem.quantity)
    else
        text.Text = string.format("%d. %s x%d", index, queueItem.recipeId, queueItem.quantity)
    end
    
    return item
end

-- Data update handlers (called by events system)
function CraftingController:OnRecipesUpdated(recipes)
    AvailableRecipes = recipes
    self:RefreshRecipeList()
end

function CraftingController:OnCraftingStatusUpdated(status)
    CraftingStatus = status
    CraftingQueue = status.queue or {}
    self:RefreshCraftingProgress()
    self:RefreshQueueDisplay()
end

-- Update loop for progress animation
spawn(function()
    while true do
        wait(0.1)
        if CraftingUI.Visible and CraftingStatus.activeCrafting then
            self:RefreshCraftingProgress()
        end
    end
end)

return CraftingController