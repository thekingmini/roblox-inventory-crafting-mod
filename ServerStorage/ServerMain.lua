-- ServerMain.lua  
-- Main server script to initialize the crafting system server-side components

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvents if they don't exist
local function createRemoteEvents()
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEventsFolder then
		remoteEventsFolder = Instance.new("Folder")
		remoteEventsFolder.Name = "RemoteEvents"
		remoteEventsFolder.Parent = ReplicatedStorage
	end
	
	local remoteEventNames = {"CraftingRemote", "InventoryRemote", "UIUpdateRemote"}
	
	for _, remoteName in pairs(remoteEventNames) do
		if not remoteEventsFolder:FindFirstChild(remoteName) then
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = remoteName
			remoteEvent.Parent = remoteEventsFolder
			print("Created RemoteEvent: " .. remoteName)
		end
	end
end

-- Initialize the server systems
local function initializeServer()
	print("Initializing Crafting System Server...")
	
	-- Create RemoteEvents
	createRemoteEvents()
	
	-- Initialize RemoteEventsHandler
	local RemoteEventsHandler = require(ServerStorage.RemoteEventsHandler)
	RemoteEventsHandler:Initialize()
	
	print("Crafting System Server initialization complete!")
end

-- Start server initialization
initializeServer()