-- Server-owned pet state. DataSaveScript is the only DataStore writer.
local HttpService = game:GetService("HttpService")
local EggConfig = require(game.ReplicatedStorage.EggConfig)
local FollowConfig = require(game.ReplicatedStorage.PetFollowConfig)
local HatchTiming = require(game.ReplicatedStorage.Shared.EggHatch.HatchConfig).Timing

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

local function equippedCount(state, petId)
	local count = 0
	for _, id in ipairs(state.Equipped) do if id == petId then count += 1 end end
	return count
end

local function publishEquipped(player, state)
	-- The server publishes only the small equipped list. Clients animate these cosmetics.
	player:SetAttribute("EquippedPetIds", HttpService:JSONEncode(state.Equipped))
end

function Service.Resolve(player, savedData)
	-- A successful first load has no saved record; keep the pet section nil.
	local data = if type(savedData) == "table" then savedData.PetInventory else nil
	local state = { SchemaVersion = 1, Pets = {}, NestEgg = nil, Equipped = {} }
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
	-- Older saves have no Equipped field: choose up to four owned copies once.
	-- An explicitly saved empty list remains empty after rejoining.
	if data and data.Equipped == nil then
		local ids = {}
		for id, count in pairs(state.Pets) do if count > 0 then table.insert(ids, id) end end
		table.sort(ids)
		for _, id in ipairs(ids) do
			for _ = 1, math.min(state.Pets[id], FollowConfig.MaxEquippedPets - #state.Equipped) do
				table.insert(state.Equipped, id)
			end
			if #state.Equipped == FollowConfig.MaxEquippedPets then break end
		end
	elseif data and type(data.Equipped) == "table" then
		for _, id in ipairs(data.Equipped) do
			if type(id) == "string" and (state.Pets[id] or 0) > equippedCount(state, id) then
				table.insert(state.Equipped, id)
				if #state.Equipped == FollowConfig.MaxEquippedPets then break end
			end
		end
	end
	states[player] = state
	player:SetAttribute("PetFollowerRevealAt", nil)
	publishEquipped(player, state)
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
	if #state.Equipped < FollowConfig.MaxEquippedPets then
		-- Let the egg crack before its new follower reveals the result.
		local delay = HatchTiming.ShakeRounds * (HatchTiming.SwingsPerRound * HatchTiming.SwingTime * 2 + HatchTiming.PauseBetweenRounds)
			+ HatchTiming.RevealPop
		player:SetAttribute("PetFollowerRevealAt", workspace:GetServerTimeNow() + delay)
		table.insert(state.Equipped, petId)
	end
	publishEquipped(player, state)
	Service.RequestSave(player)
	return true, petId, rarity
end

function Service.EquipPet(player, petId)
	if not canChange(player) then return false, "Your data is unavailable" end
	if type(petId) ~= "string" or not petRarities[petId] then return false, "Unknown pet" end
	local state = states[player]
	if #state.Equipped >= FollowConfig.MaxEquippedPets then return false, "Four pets are already equipped. Unequip one first." end
	if (state.Pets[petId] or 0) <= equippedCount(state, petId) then return false, "You have no unequipped copies of this pet" end
	table.insert(state.Equipped, petId)
	player:SetAttribute("PetFollowerRevealAt", nil)
	publishEquipped(player, state)
	Service.RequestSave(player)
	return true, "Pet equipped"
end

function Service.UnequipPet(player, petId)
	if not canChange(player) then return false, "Your data is unavailable" end
	if type(petId) ~= "string" then return false, "Unknown pet" end
	local state = states[player]
	for index = #state.Equipped, 1, -1 do
		if state.Equipped[index] == petId then
			table.remove(state.Equipped, index)
			player:SetAttribute("PetFollowerRevealAt", nil)
			publishEquipped(player, state)
			Service.RequestSave(player)
			return true, "Pet unequipped"
		end
	end
	return false, "That pet is not equipped"
end

function Service.GetRarity(petId)
	return petRarities[petId]
end

return Service
