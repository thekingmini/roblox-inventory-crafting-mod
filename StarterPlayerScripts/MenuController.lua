-- MenuController.lua
-- Manages the unified menu system with tabs and persistent elements

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local MenuController = {}

-- Menu state
MenuController.IsOpen = false
MenuController.CurrentTab = "Character"
MenuController.Menu = nil
MenuController.Tabs = {"Character", "Jobs", "Shop", "Gangs", "CreditShop"}

-- UI References (these would be set up in Roblox Studio)
MenuController.UIReferences = {
	MainFrame = nil,
	TabButtons = {},
	TabContent = {},
	CraftingFrame = nil,
	InventoryFrame = nil,
	RefineryFrame = nil
}

-- Initialize the menu controller
function MenuController:Initialize()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Wait for UI to load (in a real Roblox game, this would be a ScreenGui)
	self:CreateMenuUI(playerGui)
	self:SetupEventConnections()
	
	print("MenuController initialized")
end

-- Create the main menu UI structure
function MenuController:CreateMenuUI(playerGui)
	-- Create main ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CraftingMenuGui"
	screenGui.Parent = playerGui
	screenGui.ResetOnSpawn = false
	
	-- Main menu frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0.8, 0, 0.8, 0)
	mainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	mainFrame.BorderSizePixel = 2
	mainFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	mainFrame.Visible = false
	mainFrame.Parent = screenGui
	
	-- Tab header frame
	local tabFrame = Instance.new("Frame")
	tabFrame.Name = "TabFrame"
	tabFrame.Size = UDim2.new(1, 0, 0.08, 0)
	tabFrame.Position = UDim2.new(0, 0, 0, 0)
	tabFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	tabFrame.BorderSizePixel = 1
	tabFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
	tabFrame.Parent = mainFrame
	
	-- Create tab buttons
	self:CreateTabButtons(tabFrame)
	
	-- Content area frame
	local contentFrame = Instance.new("Frame") 
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, 0, 0.92, 0)
	contentFrame.Position = UDim2.new(0, 0, 0.08, 0)
	contentFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	contentFrame.BorderSizePixel = 0
	contentFrame.Parent = mainFrame
	
	-- Create main layout areas
	self:CreateLayoutAreas(contentFrame)
	
	-- Store reference
	self.Menu = mainFrame
	self.UIReferences.MainFrame = mainFrame
end

-- Create tab buttons
function MenuController:CreateTabButtons(tabFrame)
	local buttonWidth = 1 / #self.Tabs
	
	for i, tabName in pairs(self.Tabs) do
		local button = Instance.new("TextButton")
		button.Name = tabName .. "Button" 
		button.Size = UDim2.new(buttonWidth, -2, 1, -4)
		button.Position = UDim2.new(buttonWidth * (i-1), 2, 0, 2)
		button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		button.BorderSizePixel = 1
		button.BorderColor3 = Color3.fromRGB(100, 100, 100)
		button.Text = tabName
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextScaled = true
		button.Font = Enum.Font.SourceSans
		button.Parent = tabFrame
		
		-- Connect button click
		button.MouseButton1Click:Connect(function()
			self:ShowTab(tabName)
		end)
		
		self.UIReferences.TabButtons[tabName] = button
	end
end

-- Create main layout areas
function MenuController:CreateLayoutAreas(contentFrame)
	-- Left side - Crafting Menu
	local craftingFrame = Instance.new("Frame")
	craftingFrame.Name = "CraftingFrame"
	craftingFrame.Size = UDim2.new(0.25, -5, 0.7, -5)
	craftingFrame.Position = UDim2.new(0, 5, 0, 5)
	craftingFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	craftingFrame.BorderSizePixel = 2
	craftingFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
	craftingFrame.Parent = contentFrame
	
	-- Create crafting slots
	self:CreateCraftingSlots(craftingFrame)
	
	-- Center - Tab Content Area
	local tabContentFrame = Instance.new("Frame")
	tabContentFrame.Name = "TabContentFrame"
	tabContentFrame.Size = UDim2.new(0.5, -10, 0.7, -5)
	tabContentFrame.Position = UDim2.new(0.25, 5, 0, 5)
	tabContentFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	tabContentFrame.BorderSizePixel = 2
	tabContentFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
	tabContentFrame.Parent = contentFrame
	
	-- Create tab content areas
	self:CreateTabContent(tabContentFrame)
	
	-- Right side - Inventory
	local inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "InventoryFrame"
	inventoryFrame.Size = UDim2.new(0.25, -5, 0.7, -5)
	inventoryFrame.Position = UDim2.new(0.75, 0, 0, 5)
	inventoryFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	inventoryFrame.BorderSizePixel = 2
	inventoryFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
	inventoryFrame.Parent = contentFrame
	
	-- Create inventory slots and page controls
	self:CreateInventorySlots(inventoryFrame)
	
	-- Bottom - Refinery
	local refineryFrame = Instance.new("Frame")
	refineryFrame.Name = "RefineryFrame"
	refineryFrame.Size = UDim2.new(1, -10, 0.3, -10)
	refineryFrame.Position = UDim2.new(0, 5, 0.7, 5)
	refineryFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	refineryFrame.BorderSizePixel = 2
	refineryFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
	refineryFrame.Parent = contentFrame
	
	-- Create refinery slots
	self:CreateRefinerySlots(refineryFrame)
	
	-- Store references
	self.UIReferences.CraftingFrame = craftingFrame
	self.UIReferences.InventoryFrame = inventoryFrame
	self.UIReferences.RefineryFrame = refineryFrame
end

-- Create crafting slots
function MenuController:CreateCraftingSlots(parent)
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "CraftingTitle"
	title.Size = UDim2.new(1, 0, 0.15, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "CRAFTING"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.SourceSansBold
	title.Parent = parent
	
	-- Blueprint slot
	local blueprintSlot = Instance.new("ImageButton")
	blueprintSlot.Name = "BlueprintSlot"
	blueprintSlot.Size = UDim2.new(0, 64, 0, 64)
	blueprintSlot.Position = UDim2.new(0.5, -32, 0.2, 0)
	blueprintSlot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	blueprintSlot.BorderSizePixel = 2
	blueprintSlot.BorderColor3 = Color3.fromRGB(100, 100, 100)
	blueprintSlot.Image = ""
	blueprintSlot.Parent = parent
	
	-- Blueprint label
	local blueprintLabel = Instance.new("TextLabel")
	blueprintLabel.Name = "BlueprintLabel"
	blueprintLabel.Size = UDim2.new(1, 0, 0.08, 0)
	blueprintLabel.Position = UDim2.new(0, 0, 0.37, 0)
	blueprintLabel.BackgroundTransparency = 1
	blueprintLabel.Text = "Insert a Blueprint"
	blueprintLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	blueprintLabel.TextScaled = true
	blueprintLabel.Font = Enum.Font.SourceSans
	blueprintLabel.Parent = parent
	
	-- Material slots (2x3 grid)
	local slotSize = 48
	local spacing = 10
	local startX = (parent.AbsoluteSize.X - (3 * slotSize + 2 * spacing)) / 2
	local startY = 0.5
	
	for row = 1, 2 do
		for col = 1, 3 do
			local slotIndex = (row - 1) * 3 + col
			local slot = Instance.new("ImageButton")
			slot.Name = "MaterialSlot" .. slotIndex
			slot.Size = UDim2.new(0, slotSize, 0, slotSize)
			slot.Position = UDim2.new(0, startX + (col - 1) * (slotSize + spacing), startY + (row - 1) * 0.15, 0)
			slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			slot.BorderSizePixel = 2
			slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
			slot.Image = ""
			slot.Parent = parent
		end
	end
	
	-- GO button
	local goButton = Instance.new("TextButton")
	goButton.Name = "CraftingMenuGoButton"
	goButton.Size = UDim2.new(0.6, 0, 0.12, 0)
	goButton.Position = UDim2.new(0.2, 0, 0.85, 0)
	goButton.BackgroundColor3 = Color3.fromRGB(80, 120, 80)
	goButton.BorderSizePixel = 2
	goButton.BorderColor3 = Color3.fromRGB(100, 150, 100)
	goButton.Text = "GO"
	goButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	goButton.TextScaled = true
	goButton.Font = Enum.Font.SourceSansBold
	goButton.Parent = parent
end

-- Create inventory slots 
function MenuController:CreateInventorySlots(parent)
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "InventoryTitle"
	title.Size = UDim2.new(1, 0, 0.1, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "INVENTORY"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.SourceSansBold
	title.Parent = parent
	
	-- Page buttons
	local pageFrame = Instance.new("Frame")
	pageFrame.Name = "PageFrame"
	pageFrame.Size = UDim2.new(1, 0, 0.08, 0)
	pageFrame.Position = UDim2.new(0, 0, 0.88, 0)
	pageFrame.BackgroundTransparency = 1
	pageFrame.Parent = parent
	
	for i = 1, 4 do
		local pageButton = Instance.new("TextButton")
		pageButton.Name = "Page" .. i .. "Button"
		pageButton.Size = UDim2.new(0.2, -2, 1, 0)
		pageButton.Position = UDim2.new(0.2 * (i-1) + 0.1, 2, 0, 0)
		pageButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		pageButton.BorderSizePixel = 1
		pageButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
		pageButton.Text = tostring(i)
		pageButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		pageButton.TextScaled = true
		pageButton.Font = Enum.Font.SourceSans
		pageButton.Parent = pageFrame
	end
	
	-- Inventory grid (5x5 = 25 slots per page)
	local slotSize = 36
	local spacing = 4
	local gridWidth = 5 * slotSize + 4 * spacing
	local startX = (parent.AbsoluteSize.X - gridWidth) / 2
	local startY = 0.15
	
	for i = 1, 100 do -- 100 total slots across 4 pages
		local row = math.floor((i - 1) / 5) % 5 + 1
		local col = (i - 1) % 5 + 1
		local page = math.floor((i - 1) / 25) + 1
		
		local slot = Instance.new("ImageButton")
		slot.Name = "InventorySlot" .. i
		slot.Size = UDim2.new(0, slotSize, 0, slotSize)
		slot.Position = UDim2.new(0, startX + (col - 1) * (slotSize + spacing), startY + (row - 1) * (slotSize + spacing) / parent.AbsoluteSize.Y, 0)
		slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		slot.BorderSizePixel = 1
		slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
		slot.Image = ""
		slot.Visible = (page == 1) -- Only show page 1 initially
		slot.Parent = parent
	end
end

-- Create refinery slots
function MenuController:CreateRefinerySlots(parent)
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "RefineryTitle"
	title.Size = UDim2.new(0.2, 0, 0.4, 0)
	title.Position = UDim2.new(0, 5, 0, 5)
	title.BackgroundTransparency = 1
	title.Text = "REFINERY"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.SourceSansBold
	title.Parent = parent
	
	-- Refinery slots (horizontal row)
	local slotSize = 48
	local spacing = 8
	local startX = 20
	local startY = 0.5
	
	for i = 1, 8 do
		local slot = Instance.new("ImageButton")
		slot.Name = "RefinerySlot" .. i
		slot.Size = UDim2.new(0, slotSize, 0, slotSize)
		slot.Position = UDim2.new(0, startX + (i - 1) * (slotSize + spacing), startY, 0)
		slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		slot.BorderSizePixel = 2
		slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
		slot.Image = ""
		slot.Parent = parent
	end
	
	-- Refinery GO button
	local goButton = Instance.new("TextButton")
	goButton.Name = "RefineryGoButton"
	goButton.Size = UDim2.new(0.15, 0, 0.6, 0)
	goButton.Position = UDim2.new(0.8, 0, 0.2, 0)
	goButton.BackgroundColor3 = Color3.fromRGB(120, 80, 80)
	goButton.BorderSizePixel = 2
	goButton.BorderColor3 = Color3.fromRGB(150, 100, 100)
	goButton.Text = "GO"
	goButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	goButton.TextScaled = true
	goButton.Font = Enum.Font.SourceSansBold
	goButton.Parent = parent
end

-- Create tab content areas
function MenuController:CreateTabContent(parent)
	for _, tabName in pairs(self.Tabs) do
		local contentFrame = Instance.new("Frame")
		contentFrame.Name = tabName .. "Content"
		contentFrame.Size = UDim2.new(1, 0, 1, 0)
		contentFrame.Position = UDim2.new(0, 0, 0, 0)
		contentFrame.BackgroundTransparency = 1
		contentFrame.Visible = (tabName == "Character")
		contentFrame.Parent = parent
		
		-- Add placeholder content
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Position = UDim2.new(0, 0, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = tabName .. " Content"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.SourceSans
		label.Parent = contentFrame
		
		self.UIReferences.TabContent[tabName] = contentFrame
	end
end

-- Setup event connections
function MenuController:SetupEventConnections()
	-- L key to toggle menu
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.L then
			self:ToggleMenu()
		end
	end)
	
	-- Page button connections for inventory
	local inventoryFrame = self.UIReferences.InventoryFrame
	if inventoryFrame then
		for i = 1, 4 do
			local pageButton = inventoryFrame:FindFirstChild("PageFrame"):FindFirstChild("Page" .. i .. "Button")
			if pageButton then
				pageButton.MouseButton1Click:Connect(function()
					self:SwitchInventoryPage(i)
				end)
			end
		end
	end
end

-- Toggle menu visibility
function MenuController:ToggleMenu()
	if self.IsOpen then
		self:CloseMenu()
	else
		self:OpenMenu()
	end
end

-- Open menu
function MenuController:OpenMenu()
	if self.Menu then
		self.Menu.Visible = true
		self.IsOpen = true
		self:ShowTab(self.CurrentTab)
		
		-- Notify crafting system
		local CraftingSystem = require(script.Parent.CraftingSystemMain)
		CraftingSystem.OnMenuOpened()
	end
end

-- Close menu
function MenuController:CloseMenu()
	if self.Menu then
		-- Notify crafting system before closing
		local CraftingSystem = require(script.Parent.CraftingSystemMain)
		CraftingSystem.OnMenuClosed()
		
		self.Menu.Visible = false
		self.IsOpen = false
	end
end

-- Show specific tab
function MenuController:ShowTab(tabName)
	if not table.find(self.Tabs, tabName) then
		warn("Invalid tab name: " .. tabName)
		return
	end
	
	self.CurrentTab = tabName
	
	-- Update tab button appearances
	for name, button in pairs(self.UIReferences.TabButtons) do
		if name == tabName then
			button.BackgroundColor3 = Color3.fromRGB(80, 120, 80)
		else
			button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		end
	end
	
	-- Update tab content visibility
	for name, content in pairs(self.UIReferences.TabContent) do
		content.Visible = (name == tabName)
	end
end

-- Switch inventory page
function MenuController:SwitchInventoryPage(pageNumber)
	if pageNumber < 1 or pageNumber > 4 then
		warn("Invalid page number: " .. pageNumber)
		return
	end
	
	local inventoryFrame = self.UIReferences.InventoryFrame
	if not inventoryFrame then return end
	
	-- Update page button appearances
	for i = 1, 4 do
		local pageButton = inventoryFrame:FindFirstChild("PageFrame"):FindFirstChild("Page" .. i .. "Button")
		if pageButton then
			if i == pageNumber then
				pageButton.BackgroundColor3 = Color3.fromRGB(80, 120, 80)
			else
				pageButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			end
		end
	end
	
	-- Update slot visibility
	for slotIndex = 1, 100 do
		local slot = inventoryFrame:FindFirstChild("InventorySlot" .. slotIndex)
		if slot then
			local slotPage = math.floor((slotIndex - 1) / 25) + 1
			slot.Visible = (slotPage == pageNumber)
		end
	end
	
	-- Notify inventory manager of page change
	local InventoryUIManager = require(script.Parent.InventoryUIManager)
	InventoryUIManager.OnPageChanged(pageNumber)
end

-- Get UI element references
function MenuController:GetUIElement(elementPath)
	local parts = string.split(elementPath, ".")
	local current = self.UIReferences.MainFrame
	
	for _, part in pairs(parts) do
		if current then
			current = current:FindFirstChild(part)
		else
			break
		end
	end
	
	return current
end

-- Check if menu is open
function MenuController:IsMenuOpen()
	return self.IsOpen
end

-- Get current tab
function MenuController:GetCurrentTab()
	return self.CurrentTab
end

return MenuController