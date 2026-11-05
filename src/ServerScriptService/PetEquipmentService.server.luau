-- Accept only equip/unequip intent; the inventory owns validation and persistence.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inventory = require(script.Parent.PetInventoryService)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = remotes:WaitForChild("PetEquipment")
local lastRequest = {}

remote.OnServerEvent:Connect(function(player, action, petId)
	if (action ~= "Equip" and action ~= "Unequip") or type(petId) ~= "string" or #petId > 64 then return end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < 0.15 then return end
	lastRequest[player] = now
	local ok, message
	if action == "Equip" then ok, message = Inventory.EquipPet(player, petId)
	else ok, message = Inventory.UnequipPet(player, petId) end
	local state = Inventory.Get(player)
	if state then remotes.EggInventory:FireClient(player, { State = state, Message = message }) end
end)

Players.PlayerRemoving:Connect(function(player) lastRequest[player] = nil end)
