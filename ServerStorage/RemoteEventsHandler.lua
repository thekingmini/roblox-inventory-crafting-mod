-- RemoteEventsHandler.lua
-- Server-side handler for all RemoteEvent communications

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local InventoryManager = require(script.Parent.InventoryManager)
local CraftingManager = require(script.Parent.CraftingManager)
local ItemDatabase = require(ReplicatedStorage.ItemDatabase)
local RecipeDatabase = require(ReplicatedStorage.RecipeDatabase)

local RemoteEventsHandler = {}

-- RemoteEvent references (these would be created in Roblox Studio)
local CraftingRemote = ReplicatedStorage.RemoteEvents:WaitForChild("CraftingRemote")
local InventoryRemote = ReplicatedStorage.RemoteEvents:WaitForChild("InventoryRemote")
local UIUpdateRemote = ReplicatedStorage.RemoteEvents:WaitForChild("UIUpdateRemote")

-- Initialize the handler
function RemoteEventsHandler:Initialize()
	-- Connect to RemoteEvent handlers
	CraftingRemote.OnServerEvent:Connect(function(...) self:HandleCraftingRequest(...) end)
	InventoryRemote.OnServerEvent:Connect(function(...) self:HandleInventoryRequest(...) end)
	
	-- Handle player joining
	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerJoined(player)
	end)
	
	-- Handle existing players
	for _, player in pairs(Players:GetPlayers()) do
		self:OnPlayerJoined(player)
	end
	
	print("RemoteEventsHandler initialized")
end

-- Handle player joined
function RemoteEventsHandler:OnPlayerJoined(player)
	-- Initialize player systems
	InventoryManager:InitializePlayerInventory(player)
	CraftingManager:InitializePlayerCrafting(player)
	
	-- Send initial inventory data to client
	wait(1) -- Give client time to load
	self:SendInventoryUpdate(player)
end

-- Handle crafting requests
function RemoteEventsHandler:HandleCraftingRequest(player, requestData)
	if not player or not requestData then
		warn("Invalid crafting request")
		return
	end
	
	local action = requestData.action
	local success = false
	local message = ""
	local responseData = {}
	
	if action == "craft" then
		success, message = CraftingManager:ProcessCraft(player, requestData.recipeId, requestData.materials)
		
		if success then
			-- Send updated inventory after successful craft
			self:SendInventoryUpdate(player)
		end
		
	elseif action == "set_blueprint" then
		success, message = CraftingManager:SetBlueprint(player, requestData.itemId, requestData.quantity)
		responseData.requirements = nil
		
		if success then
			local requirements = CraftingManager:GetCraftingRequirements(requestData.itemId)
			responseData.requirements = requirements
		end
		
	elseif action == "set_material" then
		success, message = CraftingManager:SetMaterial(player, requestData.slotIndex, requestData.itemId, requestData.quantity)
		
	elseif action == "clear_slot" then
		success, message = CraftingManager:ClearCraftingSlot(player, requestData.slotType, requestData.slotIndex)
		
	elseif action == "validate_setup" then
		success, message = CraftingManager:ValidateCraftingSetup(player)
		
	elseif action == "get_status" then
		responseData = CraftingManager:GetCraftingStatus(player)
		success = true
		message = "Status retrieved"
		
	elseif action == "refinery" then
		success, message = CraftingManager:ProcessRefinery(player, requestData.itemId, requestData.quantity)
		
		if success then
			self:SendInventoryUpdate(player)
		end
		
	else
		message = "Unknown crafting action: " .. tostring(action)
	end
	
	-- Send response back to client
	CraftingRemote:FireClient(player, {
		success = success,
		message = message,
		action = action,
		data = responseData
	})
end

-- Handle inventory requests  
function RemoteEventsHandler:HandleInventoryRequest(player, requestData)
	if not player or not requestData then
		warn("Invalid inventory request")
		return
	end
	
	local action = requestData.action
	local success = false
	local message = ""
	local responseData = {}
	
	if action == "move_item" then
		success, message = InventoryManager:MoveItem(player, requestData.fromSlot, requestData.toSlot, requestData.quantity)
		
		if success then
			self:SendInventoryUpdate(player)
		end
		
	elseif action == "add_item" then
		success, message = InventoryManager:AddItem(player, requestData.itemId, requestData.quantity, requestData.metadata)
		
		if success then
			self:SendInventoryUpdate(player)
		end
		
	elseif action == "remove_item" then
		success, message = InventoryManager:RemoveItem(player, requestData.itemId, requestData.quantity, requestData.specificSlot)
		
		if success then
			self:SendInventoryUpdate(player)
		end
		
	elseif action == "get_inventory" then
		responseData.inventory = InventoryManager:GetPlayerInventory(player)
		success = true
		message = "Inventory retrieved"
		
	elseif action == "get_slot" then
		responseData.slot = InventoryManager:GetSlot(player, requestData.slotIndex)
		success = true
		message = "Slot data retrieved"
		
	elseif action == "set_slot" then
		InventoryManager:SetSlot(player, requestData.slotIndex, requestData.itemId, requestData.quantity, requestData.metadata)
		success = true
		message = "Slot updated"
		
		self:SendInventoryUpdate(player)
		
	elseif action == "clear_slot" then
		InventoryManager:ClearSlot(player, requestData.slotIndex)
		success = true
		message = "Slot cleared"
		
		self:SendInventoryUpdate(player)
		
	else
		message = "Unknown inventory action: " .. tostring(action)
	end
	
	-- Send response back to client
	InventoryRemote:FireClient(player, {
		success = success,
		message = message,
		action = action,
		data = responseData
	})
end

-- Send inventory update to client
function RemoteEventsHandler:SendInventoryUpdate(player)
	local inventory = InventoryManager:GetPlayerInventory(player)
	
	UIUpdateRemote:FireClient(player, {
		type = "inventory_update",
		inventory = inventory.slots,
		timestamp = inventory.lastUpdated
	})
end

-- Send crafting update to client
function RemoteEventsHandler:SendCraftingUpdate(player)
	local craftingStatus = CraftingManager:GetCraftingStatus(player)
	
	UIUpdateRemote:FireClient(player, {
		type = "crafting_update",
		crafting = craftingStatus,
		timestamp = tick()
	})
end

-- Send error message to client
function RemoteEventsHandler:SendError(player, errorMessage, errorType)
	UIUpdateRemote:FireClient(player, {
		type = "error",
		message = errorMessage,
		errorType = errorType or "general",
		timestamp = tick()
	})
end

-- Send success message to client
function RemoteEventsHandler:SendSuccess(player, successMessage, successType)
	UIUpdateRemote:FireClient(player, {
		type = "success",
		message = successMessage,
		successType = successType or "general", 
		timestamp = tick()
	})
end

-- Validate request data
function RemoteEventsHandler:ValidateRequest(requestData, requiredFields)
	if not requestData then
		return false, "No request data provided"
	end
	
	for _, field in pairs(requiredFields) do
		if requestData[field] == nil then
			return false, "Missing required field: " .. field
		end
	end
	
	return true, "Request data valid"
end

-- Security: Rate limiting per player
local PlayerRateLimits = {}
local MAX_REQUESTS_PER_SECOND = 10

function RemoteEventsHandler:CheckRateLimit(player)
	local playerId = tostring(player.UserId)
	local currentTime = tick()
	
	if not PlayerRateLimits[playerId] then
		PlayerRateLimits[playerId] = {
			requests = {},
			lastCleanup = currentTime
		}
	end
	
	local playerData = PlayerRateLimits[playerId]
	
	-- Clean up old requests (older than 1 second)
	if currentTime - playerData.lastCleanup > 1 then
		local newRequests = {}
		for _, requestTime in pairs(playerData.requests) do
			if currentTime - requestTime < 1 then
				table.insert(newRequests, requestTime)
			end
		end
		playerData.requests = newRequests
		playerData.lastCleanup = currentTime
	end
	
	-- Check if player has exceeded rate limit
	if #playerData.requests >= MAX_REQUESTS_PER_SECOND then
		return false, "Rate limit exceeded"
	end
	
	-- Add current request
	table.insert(playerData.requests, currentTime)
	return true, "Request allowed"
end

-- Apply rate limiting to handlers
local originalHandleCrafting = RemoteEventsHandler.HandleCraftingRequest
function RemoteEventsHandler:HandleCraftingRequest(player, requestData)
	local allowed, message = self:CheckRateLimit(player)
	if not allowed then
		self:SendError(player, message, "rate_limit")
		return
	end
	
	originalHandleCrafting(self, player, requestData)
end

local originalHandleInventory = RemoteEventsHandler.HandleInventoryRequest  
function RemoteEventsHandler:HandleInventoryRequest(player, requestData)
	local allowed, message = self:CheckRateLimit(player)
	if not allowed then
		self:SendError(player, message, "rate_limit")
		return
	end
	
	originalHandleInventory(self, player, requestData)
end

return RemoteEventsHandler