-- EggHatchController (LocalScript)
-- Location: StarterPlayer/StarterPlayerScripts/EggHatchController
--
-- Listens for the server's hatch result and plays the animation. It never asks the server for
-- anything and never decides a result: the RemoteEvent is server -> client only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local hatchFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EggHatch")
local HatchAnimator = require(hatchFolder:WaitForChild("HatchAnimator"))
local HatchConfig = require(hatchFolder:WaitForChild("HatchConfig"))
local KitData = require(hatchFolder:WaitForChild("HatchKitData"))

-- CHANGE THIS to wherever the project keeps its RemoteEvents (reuse an existing hatch remote if there is one).
local EggHatched = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EggHatched")

local MAX_RESULTS = 12 -- sanity cap on what one message can ask us to show

-- The payload comes from our own server, but validate anyway so a bad message can't break the UI.
local function cleanResults(results)
	if type(results) ~= "table" then
		return nil
	end
	local out = {}
	for i, r in ipairs(results) do
		if i > MAX_RESULTS then
			break
		end
		if type(r) == "table" and type(r.PetId) == "string" and HatchConfig.Rarity[r.Rarity] ~= nil then
			table.insert(out, { PetId = r.PetId, Rarity = r.Rarity })
		end
	end
	return #out > 0 and out or nil
end

local function spotCFrame(spot)
	if typeof(spot) ~= "Instance" then
		return nil
	end
	if spot:IsA("Attachment") then
		return spot.WorldCFrame
	elseif spot:IsA("BasePart") then
		return spot.CFrame
	end
	return nil
end

EggHatched.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.EggId) ~= "string" or KitData[payload.EggId] == nil then
		return
	end
	local results = cleanResults(payload.Results)
	if not results then
		return
	end

	local mode = payload.Mode or HatchConfig.DefaultMode
	local base = typeof(payload.BaseCFrame) == "CFrame" and payload.BaseCFrame or spotCFrame(payload.Spot)

	-- "Nest" = the player pressed E on the egg sitting on their nest: the egg cracks open in the
	-- world, and the screen reveal (pet, name, rarity) starts the moment the shell breaks.
	if mode == "Nest" then
		local first = results[1]
		local revealed = false
		local function reveal()
			if not revealed then
				revealed = true
				HatchAnimator.Enqueue(payload.EggId, results, { RevealOnly = true })
			end
		end
		local hideParts = {}
		if typeof(payload.EggPart) == "Instance" and payload.EggPart:IsA("BasePart") then
			hideParts = { payload.EggPart }
			for _, part in ipairs(payload.EggPart:GetDescendants()) do
				if part:IsA("BasePart") then table.insert(hideParts, part) end
			end
		end
		task.spawn(function()
			if base then
				HatchAnimator.PlayWorld(base, payload.EggId, {
					Rarity = first.Rarity,
					PetModel = HatchConfig.GetPetModel(first.PetId),
					HideParts = hideParts,
					OnBreak = reveal,
				})
			end
			-- 3D kit missing or no spot: fall back to the full screen hatch so the player still sees it
			if not revealed then
				revealed = true
				HatchAnimator.Enqueue(payload.EggId, results)
			end
		end)
		return
	end

	if (mode == "World" or mode == "Both") and base then
		local first = results[1]
		local hideParts = {}
		if typeof(payload.EggPart) == "Instance" and payload.EggPart:IsA("BasePart") then
			hideParts = { payload.EggPart }
			for _, part in ipairs(payload.EggPart:GetDescendants()) do
				if part:IsA("BasePart") then table.insert(hideParts, part) end
			end
		end
		task.spawn(HatchAnimator.PlayWorld, base, payload.EggId, {
			Rarity = first.Rarity,
			PetModel = HatchConfig.GetPetModel(first.PetId),
			HideParts = hideParts,
		})
		if mode == "World" then
			return
		end
	end

	HatchAnimator.Enqueue(payload.EggId, results)
end)

-- Load the hatch images in the background so the first hatch doesn't show blank frames.
task.spawn(HatchAnimator.Preload)
