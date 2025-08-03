-- This file creates the RemoteEvent instances that will be used for client-server communication
-- In Roblox, RemoteEvents are typically created as Instance objects, but this file serves as documentation
-- The actual RemoteEvent instances would be created in Roblox Studio or through a script

--[[
RemoteEvents to be created in ReplicatedStorage/RemoteEvents/:

1. CraftingRemote (RemoteEvent)
   - Used for crafting operations
   - Client -> Server: craft requests, material validation
   - Server -> Client: craft results, errors

2. InventoryRemote (RemoteEvent) 
   - Used for inventory operations
   - Client -> Server: move items, inventory requests
   - Server -> Client: inventory updates, item changes

3. UIUpdateRemote (RemoteEvent)
   - Used for UI synchronization
   - Server -> Client: inventory updates, status changes
   - Ensures UI stays in sync with server state

These would be created as:
local CraftingRemote = Instance.new("RemoteEvent")
CraftingRemote.Name = "CraftingRemote"
CraftingRemote.Parent = game.ReplicatedStorage.RemoteEvents

local InventoryRemote = Instance.new("RemoteEvent")
InventoryRemote.Name = "InventoryRemote" 
InventoryRemote.Parent = game.ReplicatedStorage.RemoteEvents

local UIUpdateRemote = Instance.new("RemoteEvent")
UIUpdateRemote.Name = "UIUpdateRemote"
UIUpdateRemote.Parent = game.ReplicatedStorage.RemoteEvents
--]]

return {
	CraftingRemote = "CraftingRemote",
	InventoryRemote = "InventoryRemote", 
	UIUpdateRemote = "UIUpdateRemote"
}