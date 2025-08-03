-- CraftingSystemMain.lua
-- Main client controller that integrates all crafting system components

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Import all system modules
local MenuController = require(script.Parent.MenuController)
local DragDropSystem = require(script.Parent.DragDropSystem)
local InventoryUIManager = require(script.Parent.InventoryUIManager)
local CraftingUIManager = require(script.Parent.CraftingUIManager)

local CraftingSystemMain = {}

-- System state
CraftingSystemMain.IsInitialized = false
CraftingSystemMain.Systems = {
	MenuController = nil,
	DragDropSystem = nil,
	InventoryUIManager = nil,
	CraftingUIManager = nil
}

-- Initialize the complete crafting system
function CraftingSystemMain:Initialize()
	if self.IsInitialized then
		warn("CraftingSystemMain already initialized")
		return
	end
	
	print("Initializing Complete Drag-and-Drop Crafting System...")
	
	-- Wait for essential services and objects
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Wait for RemoteEvents to be available
	self:WaitForRemoteEvents()
	
	-- Initialize systems in dependency order
	self:InitializeMenuController()
	self:InitializeInventoryUIManager()
	self:InitializeCraftingUIManager()
	self:InitializeDragDropSystem()
	
	-- Setup cross-system integrations
	self:SetupSystemIntegrations()
	
	self.IsInitialized = true
	print("Crafting System initialization complete!")
	
	-- Auto-open menu for demonstration (remove in production)
	wait(2)
	if not self.Systems.MenuController:IsMenuOpen() then
		self.Systems.MenuController:OpenMenu()
	end
end

-- Wait for RemoteEvents to be available
function CraftingSystemMain:WaitForRemoteEvents()
	local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
	if not remoteEventsFolder then
		error("RemoteEvents folder not found in ReplicatedStorage")
	end
	
	-- Wait for essential RemoteEvents
	local requiredRemotes = {"CraftingRemote", "InventoryRemote", "UIUpdateRemote"}
	
	for _, remoteName in pairs(requiredRemotes) do
		local remote = remoteEventsFolder:WaitForChild(remoteName, 10)
		if not remote then
			error("Required RemoteEvent not found: " .. remoteName)
		end
	end
	
	print("All RemoteEvents are available")
end

-- Initialize MenuController
function CraftingSystemMain:InitializeMenuController()
	print("Initializing MenuController...")
	
	MenuController:Initialize()
	self.Systems.MenuController = MenuController
	
	print("MenuController initialized successfully")
end

-- Initialize InventoryUIManager
function CraftingSystemMain:InitializeInventoryUIManager()
	print("Initializing InventoryUIManager...")
	
	InventoryUIManager:Initialize(self.Systems.MenuController)
	self.Systems.InventoryUIManager = InventoryUIManager
	
	print("InventoryUIManager initialized successfully")
end

-- Initialize CraftingUIManager
function CraftingSystemMain:InitializeCraftingUIManager()
	print("Initializing CraftingUIManager...")
	
	CraftingUIManager:Initialize(self.Systems.MenuController)
	self.Systems.CraftingUIManager = CraftingUIManager
	
	print("CraftingUIManager initialized successfully")
end

-- Initialize DragDropSystem
function CraftingSystemMain:InitializeDragDropSystem()
	print("Initializing DragDropSystem...")
	
	DragDropSystem:Initialize(self.Systems.MenuController)
	self.Systems.DragDropSystem = DragDropSystem
	
	print("DragDropSystem initialized successfully")
end

-- Setup integrations between systems
function CraftingSystemMain:SetupSystemIntegrations()
	print("Setting up system integrations...")
	
	-- Connect DragDropSystem to UI managers
	self:ConnectDragDropToManagers()
	
	-- Connect inventory page changes
	self:ConnectInventoryPageHandling()
	
	-- Connect crafting validations
	self:ConnectCraftingValidations()
	
	-- Setup error handling and notifications
	self:SetupErrorHandling()
	
	print("System integrations complete")
end

-- Connect DragDropSystem to UI managers
function CraftingSystemMain:ConnectDragDropToManagers()
	local dragDrop = self.Systems.DragDropSystem
	local inventory = self.Systems.InventoryUIManager
	local crafting = self.Systems.CraftingUIManager
	
	-- Override DragDropSystem's GetSlotItemData to use proper managers
	local originalGetSlotItemData = dragDrop.GetSlotItemData
	dragDrop.GetSlotItemData = function(self, slot, slotType, slotIndex)
		if slotType == dragDrop.SlotTypes.INVENTORY then
			return inventory:GetSlotItem(slotIndex)
		elseif slotType == dragDrop.SlotTypes.BLUEPRINT then
			return crafting:GetCurrentBlueprint()
		elseif slotType == dragDrop.SlotTypes.MATERIAL then
			return crafting:GetMaterialInSlot(slotIndex)
		else
			return originalGetSlotItemData(self, slot, slotType, slotIndex)
		end
	end
	
	-- Override DragDropSystem's ValidateMaterialSlotDrop to use CraftingUIManager
	local originalValidateMaterialSlotDrop = dragDrop.ValidateMaterialSlotDrop
	dragDrop.ValidateMaterialSlotDrop = function(self, materialSlotIndex, dragItem)
		return crafting:ValidateMaterialForSlot(materialSlotIndex, dragItem.itemId, dragItem.quantity)
	end
end

-- Connect inventory page handling
function CraftingSystemMain:ConnectInventoryPageHandling()
	local menuController = self.Systems.MenuController
	local inventory = self.Systems.InventoryUIManager
	
	-- Override MenuController's SwitchInventoryPage to notify InventoryUIManager
	local originalSwitchInventoryPage = menuController.SwitchInventoryPage
	menuController.SwitchInventoryPage = function(self, pageNumber)
		originalSwitchInventoryPage(self, pageNumber)
		inventory:OnPageChanged(pageNumber)
	end
end

-- Connect crafting validations
function CraftingSystemMain:ConnectCraftingValidations()
	local crafting = self.Systems.CraftingUIManager
	local inventory = self.Systems.InventoryUIManager
	
	-- Setup crafting validation with inventory checking
	local originalValidateCraftingSetup = crafting.ValidateCraftingSetup
	crafting.ValidateCraftingSetup = function(self)
		local valid, message = originalValidateCraftingSetup(self)
		
		if valid and self.CurrentRecipe then
			-- Additional check: verify player has materials in inventory
			for _, ingredient in pairs(self.CurrentRecipe.ingredients) do
				local availableQuantity = inventory:GetItemQuantity(ingredient.itemId)
				if availableQuantity < ingredient.quantity then
					self:UpdateGoButtonState(false)
					return false, "Insufficient " .. ingredient.itemId .. " in inventory"
				end
			end
		end
		
		return valid, message
	end
end

-- Setup error handling and notifications
function CraftingSystemMain:SetupErrorHandling()
	-- Global error handler for the crafting system
	local function handleError(errorMessage, system)
		warn("[CraftingSystem] Error in " .. (system or "unknown") .. ": " .. errorMessage)
		
		-- Could be enhanced with proper user notifications
		self:ShowSystemNotification("Error: " .. errorMessage, "error")
	end
	
	-- Wrap critical functions with error handling
	self:WrapSystemFunctions()
end

-- Wrap system functions with error handling
function CraftingSystemMain:WrapSystemFunctions()
	local systems = {
		{name = "DragDropSystem", system = self.Systems.DragDropSystem},
		{name = "InventoryUIManager", system = self.Systems.InventoryUIManager},
		{name = "CraftingUIManager", system = self.Systems.CraftingUIManager}
	}
	
	for _, systemInfo in pairs(systems) do
		if systemInfo.system then
			-- Wrap key functions that might fail
			local keyFunctions = {"ProcessDrop", "ExecuteCraft", "UpdateSlotDisplay", "HandleServerUpdate"}
			
			for _, funcName in pairs(keyFunctions) do
				local originalFunc = systemInfo.system[funcName]
				if originalFunc then
					systemInfo.system[funcName] = function(...)
						local success, result = pcall(originalFunc, ...)
						if not success then
							warn("[CraftingSystem] Error in " .. systemInfo.name .. "." .. funcName .. ": " .. tostring(result))
						end
						return result
					end
				end
			end
		end
	end
end

-- Handle menu opened event
function CraftingSystemMain:OnMenuOpened()
	if not self.IsInitialized then
		return
	end
	
	-- Refresh all displays when menu opens
	if self.Systems.InventoryUIManager then
		self.Systems.InventoryUIManager:RefreshInventoryDisplay()
	end
	
	if self.Systems.CraftingUIManager then
		self.Systems.CraftingUIManager:ValidateCraftingSetup()
	end
	
	print("Menu opened - systems refreshed")
end

-- Handle menu closed event
function CraftingSystemMain:OnMenuClosed()
	if not self.IsInitialized then
		return
	end
	
	-- Cancel any ongoing drag operations
	if self.Systems.DragDropSystem and self.Systems.DragDropSystem.DragState.isDragging then
		self.Systems.DragDropSystem:CleanupDrag()
	end
	
	-- Hide any tooltips
	if self.Systems.InventoryUIManager then
		self.Systems.InventoryUIManager:HideItemTooltip()
	end
	
	print("Menu closed - drag operations cleaned up")
end

-- Show system notification
function CraftingSystemMain:ShowSystemNotification(message, notificationType)
	-- Placeholder for notification system
	-- In a full implementation, this would show UI notifications
	local messageType = notificationType or "info"
	
	if messageType == "error" then
		warn("[CraftingSystem] " .. message)
	else
		print("[CraftingSystem] " .. message)
	end
end

-- Get system reference
function CraftingSystemMain:GetSystem(systemName)
	return self.Systems[systemName]
end

-- Check if system is ready
function CraftingSystemMain:IsSystemReady()
	return self.IsInitialized and 
		   self.Systems.MenuController and
		   self.Systems.DragDropSystem and
		   self.Systems.InventoryUIManager and
		   self.Systems.CraftingUIManager
end

-- Cleanup and shutdown
function CraftingSystemMain:Shutdown()
	if not self.IsInitialized then
		return
	end
	
	print("Shutting down CraftingSystem...")
	
	-- Close menu if open
	if self.Systems.MenuController and self.Systems.MenuController:IsMenuOpen() then
		self.Systems.MenuController:CloseMenu()
	end
	
	-- Clean up drag operations
	if self.Systems.DragDropSystem then
		self.Systems.DragDropSystem:CleanupDrag()
	end
	
	-- Hide tooltips
	if self.Systems.InventoryUIManager then
		self.Systems.InventoryUIManager:HideItemTooltip()
	end
	
	-- Clear references
	for systemName, _ in pairs(self.Systems) do
		self.Systems[systemName] = nil
	end
	
	self.IsInitialized = false
	print("CraftingSystem shutdown complete")
end

-- Debug function to get system status
function CraftingSystemMain:GetSystemStatus()
	local status = {
		IsInitialized = self.IsInitialized,
		Systems = {}
	}
	
	for systemName, system in pairs(self.Systems) do
		status.Systems[systemName] = {
			Available = system ~= nil,
			Type = type(system)
		}
	end
	
	return status
end

-- Auto-initialize when script loads
spawn(function()
	-- Wait a bit for other systems to load
	wait(1)
	CraftingSystemMain:Initialize()
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	if player == Players.LocalPlayer then
		CraftingSystemMain:Shutdown()
	end
end)

return CraftingSystemMain