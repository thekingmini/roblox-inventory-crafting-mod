-- InventoryUIManager.lua
-- Manages inventory display and UI synchronization with server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ItemDatabase = require(ReplicatedStorage.ItemDatabase)

local InventoryUIManager = {}

-- State management
InventoryUIManager.CurrentPage = 1
InventoryUIManager.ClientInventory = {} -- [1-100] = {itemId="", quantity=1, metadata={}}
InventoryUIManager.LastServerSync = 0
InventoryUIManager.MenuController = nil

-- UI settings
InventoryUIManager.SLOTS_PER_PAGE = 25
InventoryUIManager.MAX_PAGES = 4
InventoryUIManager.MAX_SLOTS = 100

-- Initialize the inventory UI manager
function InventoryUIManager:Initialize(menuController)
	self.MenuController = menuController
	self:SetupRemoteEventHandlers()
	self:RequestInventoryData()
	
	print("InventoryUIManager initialized")
end

-- Setup RemoteEvent handlers
function InventoryUIManager:SetupRemoteEventHandlers()
	-- Listen for inventory updates from server
	local UIUpdateRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("UIUpdateRemote")
	if UIUpdateRemote then
		UIUpdateRemote.OnClientEvent:Connect(function(updateData)
			self:HandleServerUpdate(updateData)
		end)
	end
	
	-- Listen for inventory responses
	local InventoryRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("InventoryRemote")
	if InventoryRemote then
		InventoryRemote.OnClientEvent:Connect(function(responseData)
			self:HandleInventoryResponse(responseData)
		end)
	end
end

-- Request initial inventory data from server
function InventoryUIManager:RequestInventoryData()
	local InventoryRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("InventoryRemote")
	if InventoryRemote then
		InventoryRemote:FireServer({
			action = "get_inventory"
		})
	end
end

-- Handle server updates
function InventoryUIManager:HandleServerUpdate(updateData)
	if updateData.type == "inventory_update" then
		self:UpdateInventoryFromServer(updateData.inventory, updateData.timestamp)
	elseif updateData.type == "error" then
		self:ShowError(updateData.message)
	elseif updateData.type == "success" then
		self:ShowSuccess(updateData.message)
	end
end

-- Handle inventory response from server
function InventoryUIManager:HandleInventoryResponse(responseData)
	if responseData.success then
		if responseData.action == "get_inventory" and responseData.data.inventory then
			self:UpdateInventoryFromServer(responseData.data.inventory.slots, responseData.data.inventory.lastUpdated)
		end
	else
		self:ShowError(responseData.message or "Inventory operation failed")
	end
end

-- Update inventory from server data
function InventoryUIManager:UpdateInventoryFromServer(serverInventory, timestamp)
	-- Only update if server data is newer
	if timestamp and timestamp <= self.LastServerSync then
		return
	end
	
	self.ClientInventory = serverInventory or {}
	self.LastServerSync = timestamp or tick()
	
	-- Update UI display
	self:RefreshInventoryDisplay()
end

-- Refresh the inventory display
function InventoryUIManager:RefreshInventoryDisplay()
	-- Update all visible slots for current page
	local startSlot = (self.CurrentPage - 1) * self.SLOTS_PER_PAGE + 1
	local endSlot = math.min(startSlot + self.SLOTS_PER_PAGE - 1, self.MAX_SLOTS)
	
	for slotIndex = startSlot, endSlot do
		self:UpdateSlotDisplay(slotIndex)
	end
	
	-- Update page indicators
	self:UpdatePageIndicators()
end

-- Update a specific slot's display
function InventoryUIManager:UpdateSlotDisplay(slotIndex)
	local slot = self:GetInventorySlot(slotIndex)
	if not slot then
		return
	end
	
	local itemData = self.ClientInventory[slotIndex]
	
	if itemData and itemData.itemId then
		-- Set item icon
		local item = ItemDatabase:GetItem(itemData.itemId)
		if item then
			slot.Image = item.icon
			
			-- Update quantity display
			self:UpdateSlotQuantity(slot, itemData.quantity)
			
			-- Update tooltip/hover info
			self:SetupSlotTooltip(slot, item, itemData)
			
			-- Set rarity border color
			self:SetSlotRarityBorder(slot, item.rarity)
		end
	else
		-- Clear empty slot
		slot.Image = ""
		self:ClearSlotQuantity(slot)
		self:ClearSlotTooltip(slot)
		self:ClearSlotRarityBorder(slot)
	end
end

-- Update slot quantity display
function InventoryUIManager:UpdateSlotQuantity(slot, quantity)
	local quantityLabel = slot:FindFirstChild("QuantityLabel")
	
	if quantity > 1 then
		if not quantityLabel then
			quantityLabel = Instance.new("TextLabel")
			quantityLabel.Name = "QuantityLabel"
			quantityLabel.Size = UDim2.new(0.4, 0, 0.3, 0)
			quantityLabel.Position = UDim2.new(0.6, 0, 0.7, 0)
			quantityLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			quantityLabel.BackgroundTransparency = 0.2
			quantityLabel.BorderSizePixel = 0
			quantityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			quantityLabel.TextScaled = true
			quantityLabel.Font = Enum.Font.SourceSansBold
			quantityLabel.ZIndex = slot.ZIndex + 1
			quantityLabel.Parent = slot
		end
		quantityLabel.Text = tostring(quantity)
	elseif quantityLabel then
		quantityLabel:Destroy()
	end
end

-- Clear slot quantity display
function InventoryUIManager:ClearSlotQuantity(slot)
	local quantityLabel = slot:FindFirstChild("QuantityLabel")
	if quantityLabel then
		quantityLabel:Destroy()
	end
end

-- Setup slot tooltip on hover
function InventoryUIManager:SetupSlotTooltip(slot, itemData, slotData)
	-- Remove existing tooltip connections
	self:ClearSlotTooltip(slot)
	
	-- Mouse enter - show tooltip
	local enterConnection = slot.MouseEnter:Connect(function()
		self:ShowItemTooltip(slot, itemData, slotData)
	end)
	
	-- Mouse leave - hide tooltip
	local leaveConnection = slot.MouseLeave:Connect(function()
		self:HideItemTooltip()
	end)
	
	-- Store connections for cleanup
	slot:SetAttribute("TooltipEnterConnection", enterConnection)
	slot:SetAttribute("TooltipLeaveConnection", leaveConnection)
end

-- Clear slot tooltip
function InventoryUIManager:ClearSlotTooltip(slot)
	local enterConnection = slot:GetAttribute("TooltipEnterConnection")
	local leaveConnection = slot:GetAttribute("TooltipLeaveConnection")
	
	if enterConnection then
		enterConnection:Disconnect()
		slot:SetAttribute("TooltipEnterConnection", nil)
	end
	
	if leaveConnection then
		leaveConnection:Disconnect()
		slot:SetAttribute("TooltipLeaveConnection", nil)
	end
end

-- Show item tooltip
function InventoryUIManager:ShowItemTooltip(slot, itemData, slotData)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create tooltip frame
	local tooltip = Instance.new("Frame")
	tooltip.Name = "ItemTooltip"
	tooltip.Size = UDim2.new(0, 200, 0, 100)
	tooltip.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	tooltip.BorderSizePixel = 2
	tooltip.BorderColor3 = self:GetRarityColor(itemData.rarity)
	tooltip.ZIndex = 1000
	tooltip.Parent = playerGui
	
	-- Position tooltip near mouse
	local mousePos = Players.LocalPlayer:GetMouse()
	tooltip.Position = UDim2.new(0, mousePos.X + 10, 0, mousePos.Y - 50)
	
	-- Item name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -10, 0, 20)
	nameLabel.Position = UDim2.new(0, 5, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.name
	nameLabel.TextColor3 = self:GetRarityColor(itemData.rarity)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.Parent = tooltip
	
	-- Item type
	local typeLabel = Instance.new("TextLabel")
	typeLabel.Size = UDim2.new(1, -10, 0, 15)
	typeLabel.Position = UDim2.new(0, 5, 0, 25)
	typeLabel.BackgroundTransparency = 1
	typeLabel.Text = itemData.type:upper()
	typeLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	typeLabel.TextXAlignment = Enum.TextXAlignment.Left
	typeLabel.TextScaled = true
	typeLabel.Font = Enum.Font.SourceSans
	typeLabel.Parent = tooltip
	
	-- Quantity
	if slotData.quantity > 1 then
		local quantityLabel = Instance.new("TextLabel")
		quantityLabel.Size = UDim2.new(1, -10, 0, 15)
		quantityLabel.Position = UDim2.new(0, 5, 0, 40)
		quantityLabel.BackgroundTransparency = 1
		quantityLabel.Text = "Quantity: " .. slotData.quantity
		quantityLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		quantityLabel.TextXAlignment = Enum.TextXAlignment.Left
		quantityLabel.TextScaled = true
		quantityLabel.Font = Enum.Font.SourceSans
		quantityLabel.Parent = tooltip
	end
	
	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -10, 0, 30)
	descLabel.Position = UDim2.new(0, 5, 0, 60)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = itemData.description or ""
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.TextScaled = false
	descLabel.TextSize = 12
	descLabel.Font = Enum.Font.SourceSans
	descLabel.Parent = tooltip
	
	-- Store reference for hiding
	self.CurrentTooltip = tooltip
end

-- Hide item tooltip
function InventoryUIManager:HideItemTooltip()
	if self.CurrentTooltip then
		self.CurrentTooltip:Destroy()
		self.CurrentTooltip = nil
	end
end

-- Set slot rarity border
function InventoryUIManager:SetSlotRarityBorder(slot, rarity)
	local color = self:GetRarityColor(rarity)
	slot.BorderColor3 = color
end

-- Clear slot rarity border
function InventoryUIManager:ClearSlotRarityBorder(slot)
	slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
end

-- Get rarity color
function InventoryUIManager:GetRarityColor(rarity)
	local colors = {
		[ItemDatabase.Rarity.COMMON] = Color3.fromRGB(150, 150, 150),
		[ItemDatabase.Rarity.UNCOMMON] = Color3.fromRGB(100, 255, 100),
		[ItemDatabase.Rarity.RARE] = Color3.fromRGB(100, 100, 255),
		[ItemDatabase.Rarity.EPIC] = Color3.fromRGB(200, 100, 255),
		[ItemDatabase.Rarity.LEGENDARY] = Color3.fromRGB(255, 200, 100)
	}
	
	return colors[rarity] or colors[ItemDatabase.Rarity.COMMON]
end

-- Get inventory slot UI element
function InventoryUIManager:GetInventorySlot(slotIndex)
	if not self.MenuController or not self.MenuController.UIReferences.InventoryFrame then
		return nil
	end
	
	return self.MenuController.UIReferences.InventoryFrame:FindFirstChild("InventorySlot" .. slotIndex)
end

-- Switch to a specific page
function InventoryUIManager:SwitchToPage(pageNumber)
	if pageNumber < 1 or pageNumber > self.MAX_PAGES then
		warn("Invalid page number: " .. pageNumber)
		return
	end
	
	local oldPage = self.CurrentPage
	self.CurrentPage = pageNumber
	
	-- Hide old page slots
	local oldStartSlot = (oldPage - 1) * self.SLOTS_PER_PAGE + 1
	local oldEndSlot = math.min(oldStartSlot + self.SLOTS_PER_PAGE - 1, self.MAX_SLOTS)
	
	for slotIndex = oldStartSlot, oldEndSlot do
		local slot = self:GetInventorySlot(slotIndex)
		if slot then
			slot.Visible = false
		end
	end
	
	-- Show new page slots
	local newStartSlot = (pageNumber - 1) * self.SLOTS_PER_PAGE + 1
	local newEndSlot = math.min(newStartSlot + self.SLOTS_PER_PAGE - 1, self.MAX_SLOTS)
	
	for slotIndex = newStartSlot, newEndSlot do
		local slot = self:GetInventorySlot(slotIndex)
		if slot then
			slot.Visible = true
			self:UpdateSlotDisplay(slotIndex)
		end
	end
	
	self:UpdatePageIndicators()
end

-- Update page indicator buttons
function InventoryUIManager:UpdatePageIndicators()
	if not self.MenuController or not self.MenuController.UIReferences.InventoryFrame then
		return
	end
	
	local pageFrame = self.MenuController.UIReferences.InventoryFrame:FindFirstChild("PageFrame")
	if not pageFrame then
		return
	end
	
	for i = 1, self.MAX_PAGES do
		local pageButton = pageFrame:FindFirstChild("Page" .. i .. "Button")
		if pageButton then
			if i == self.CurrentPage then
				pageButton.BackgroundColor3 = Color3.fromRGB(80, 120, 80)
				pageButton.BorderColor3 = Color3.fromRGB(100, 150, 100)
			else
				pageButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
				pageButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
			end
		end
	end
end

-- Get item from inventory slot
function InventoryUIManager:GetSlotItem(slotIndex)
	return self.ClientInventory[slotIndex]
end

-- Check if slot has item
function InventoryUIManager:HasItemInSlot(slotIndex)
	local item = self:GetSlotItem(slotIndex)
	return item and item.itemId ~= nil
end

-- Get total quantity of specific item in inventory
function InventoryUIManager:GetItemQuantity(itemId)
	local total = 0
	
	for slotIndex = 1, self.MAX_SLOTS do
		local item = self:GetSlotItem(slotIndex)
		if item and item.itemId == itemId then
			total = total + (item.quantity or 0)
		end
	end
	
	return total
end

-- Find first slot containing specific item
function InventoryUIManager:FindItemSlot(itemId)
	for slotIndex = 1, self.MAX_SLOTS do
		local item = self:GetSlotItem(slotIndex)
		if item and item.itemId == itemId then
			return slotIndex
		end
	end
	
	return nil
end

-- Find first empty slot
function InventoryUIManager:FindEmptySlot()
	for slotIndex = 1, self.MAX_SLOTS do
		if not self:HasItemInSlot(slotIndex) then
			return slotIndex
		end
	end
	
	return nil
end

-- Show error message
function InventoryUIManager:ShowError(message)
	-- This could be enhanced with a proper notification system
	warn("Inventory Error: " .. message)
end

-- Show success message
function InventoryUIManager:ShowSuccess(message)
	-- This could be enhanced with a proper notification system
	print("Inventory Success: " .. message)
end

-- Handle page change from MenuController
function InventoryUIManager:OnPageChanged(pageNumber)
	self:SwitchToPage(pageNumber)
end

-- Get current page
function InventoryUIManager:GetCurrentPage()
	return self.CurrentPage
end

-- Get total pages
function InventoryUIManager:GetTotalPages()
	return self.MAX_PAGES
end

-- Refresh specific slot
function InventoryUIManager:RefreshSlot(slotIndex)
	self:UpdateSlotDisplay(slotIndex)
end

-- Get all items on current page
function InventoryUIManager:GetCurrentPageItems()
	local items = {}
	local startSlot = (self.CurrentPage - 1) * self.SLOTS_PER_PAGE + 1
	local endSlot = math.min(startSlot + self.SLOTS_PER_PAGE - 1, self.MAX_SLOTS)
	
	for slotIndex = startSlot, endSlot do
		local item = self:GetSlotItem(slotIndex)
		if item then
			items[slotIndex] = item
		end
	end
	
	return items
end

return InventoryUIManager