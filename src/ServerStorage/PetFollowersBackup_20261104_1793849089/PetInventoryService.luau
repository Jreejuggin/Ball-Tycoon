-- Server-owned pet state. DataSaveScript is the only DataStore writer.
local HttpService = game:GetService("HttpService")
local EggConfig = require(game.ReplicatedStorage.EggConfig)

local Service = {}
local states = setmetatable({}, { __mode = "k" })
local saveCallback
local petRarities = {}
for _, egg in pairs(EggConfig.Eggs) do
	for _, pet in ipairs(egg.Pets) do petRarities[pet.PetId] = pet.Rarity end
end

local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = clone(child) end
	return result
end

local function canChange(player)
	return states[player] ~= nil and player.Parent ~= nil
		and player:GetAttribute("DataLoaded") == true
		and not player:GetAttribute("DataClosing")
		and not player:GetAttribute("DataLoadFailed")
		and not player:GetAttribute("DataSessionLost")
end

function Service.Resolve(player, savedData)
	local data = type(savedData) == "table" and savedData.PetInventory
	local state = { SchemaVersion = 1, Pets = {}, NestEgg = nil }
	if data ~= nil then
		assert(type(data) == "table" and data.SchemaVersion == 1, "Unsupported pet save; refusing to replace it")
		assert(type(data.Pets) == "table", "Invalid pet inventory")
		for id, count in pairs(data.Pets) do
			assert(petRarities[id] and type(count) == "number" and count == count
				and count >= 0 and count < 1e9 and count % 1 == 0, "Invalid saved pet count")
			state.Pets[id] = count
		end
		if data.NestEgg ~= nil then
			local egg = data.NestEgg
			assert(type(egg) == "table" and type(egg.Id) == "string" and EggConfig.Eggs[egg.EggId], "Invalid saved nest egg")
			state.NestEgg = { Id = egg.Id, EggId = egg.EggId }
		end
	end
	states[player] = state
end

function Service.Serialize(player)
	assert(states[player], "Pet state missing; refusing partial save")
	return clone(states[player])
end

function Service.Get(player)
	return states[player] and clone(states[player]) or nil
end

function Service.SetSaveCallback(callback)
	saveCallback = callback
end

-- Mutations below never yield. Egg removal and pet grant form one state update.
-- A failed DataStore response never rolls back a grant that may already be saved.
function Service.RequestSave(player)
	if saveCallback then
		task.spawn(function()
			local ok, saved = pcall(saveCallback, player)
			if not ok or not saved then
				warn("[PetInventoryService] Save pending for " .. player.Name .. "; existing autosave/departure writer will retry")
			end
		end)
	end
end

function Service.GrantEgg(player, eggId)
	if not canChange(player) or not EggConfig.Eggs[eggId] then return false, "Data is unavailable" end
	local state = states[player]
	if state.NestEgg then return false, "Open the egg on your nest first" end
	state.NestEgg = { Id = HttpService:GenerateGUID(false), EggId = eggId }
	Service.RequestSave(player)
	return true, clone(state.NestEgg)
end

function Service.PurchaseEgg(player, eggId)
	if not canChange(player) or type(eggId) ~= "string" then return false, "Data is unavailable" end
	local egg = EggConfig.Eggs[eggId]
	local state = states[player]
	if not egg then return false, "Unknown egg" end
	if state.NestEgg then return false, "Open the egg on your nest first" end
	local folder = player:FindFirstChild(egg.Currency == "Gems" and "GemData" or "leaderstats")
	local balance = folder and folder:FindFirstChild(egg.Currency)
	if not balance or balance.Value < egg.Price then return false, "Not enough " .. egg.Currency end
	-- Validate everything before deducting. No yield between charge and ownership.
	local record = { Id = HttpService:GenerateGUID(false), EggId = eggId }
	balance.Value -= egg.Price
	state.NestEgg = record
	Service.RequestSave(player)
	return true, clone(record)
end

function Service.OpenEgg(player, recordId, eggId, rng)
	if not canChange(player) then return false end
	local state = states[player]
	local egg = state.NestEgg
	if not egg or egg.Id ~= recordId or egg.EggId ~= eggId then return false end
	local petId, rarity = EggConfig.Roll(eggId, rng)
	state.Pets[petId] = (state.Pets[petId] or 0) + 1
	state.NestEgg = nil
	Service.RequestSave(player)
	return true, petId, rarity
end

function Service.GetRarity(petId)
	return petRarities[petId]
end

return Service
