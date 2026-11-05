-- P1 prototype: all prices, rolls, ownership and inventory changes run here on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PolicyService = game:GetService("PolicyService")
local Config = require(ReplicatedStorage.Shared.EggHatch.HatchConfig)
local Kit = require(ReplicatedStorage.Shared.EggHatch.HatchKitData)
local Eggs = require(ReplicatedStorage.EggConfig)
local Inventory = require(script.Parent.PetInventoryService)
local Remotes = ReplicatedStorage.Remotes
local Service = {}
local rng = Random.new()
local liveEggs = {}
local busy = {}
local policy = setmetatable({}, { __mode = "k" })
local lastPurchase = setmetatable({}, { __mode = "k" })
local initialized = false

local function findPlot(player)
	local plot = workspace:FindFirstChild(player:GetAttribute("AssignedPlotName") or "")
	if plot and plot.Name == "P1" and plot:GetAttribute("Owner") == player.UserId then return plot end
	return nil
end

local function findSpot(plot)
	local slots = plot and plot:FindFirstChild("CentreSlots")
	local centre = slots and slots:FindFirstChild("Centre05_Pet")
	local residence = centre and centre:FindFirstChild("PetResidence")
	local base = residence and residence:FindFirstChild("Base")
	local spot = base and base:FindFirstChild("PetSpot")
	return spot and spot:IsA("Attachment") and spot or nil
end

local function isNear(player, spot)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local centre = spot and spot:FindFirstAncestor("Centre05_Pet")
	local activated = centre and centre:FindFirstChild("Activated")
	return activated and activated.Value and root and humanoid and humanoid.Health > 0 and spot
		and (root.Position - spot.WorldPosition).Magnitude <= Config.OpenPrompt.MaxActivationDistance + 2
end

local function prepare(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

function Service.SendState(player, message, openShop)
	local state = Inventory.Get(player)
	if state and player.Parent then
		Remotes.EggInventory:FireClient(player, { State = state, Message = message, OpenShop = openShop })
	end
end

function Service.AttachPrompt(eggPart, eggId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = Config.OpenPrompt.ActionText
	prompt.ObjectText = Eggs.Eggs[eggId].DisplayName
	prompt.KeyboardKeyCode = Config.OpenPrompt.KeyboardKey
	prompt.GamepadKeyCode = Config.OpenPrompt.GamepadKey
	prompt.HoldDuration = Config.OpenPrompt.HoldDuration
	prompt.MaxActivationDistance = Config.OpenPrompt.MaxActivationDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ServerEnabled", true)
	prompt.Parent = eggPart
	CollectionService:AddTag(prompt, Config.OpenPrompt.Tag)
	return prompt
end

local function openEgg(player, plot, spot, model, carrier, record, prompt, holds)
	local heldAt = holds[player]
	holds[player] = nil
	if busy[plot] or not prompt.Enabled or carrier:GetAttribute("Opening")
		or findPlot(player) ~= plot or findSpot(plot) ~= spot or not isNear(player, spot)
		or liveEggs[plot] ~= model or not heldAt
		or os.clock() - heldAt < Config.OpenPrompt.HoldDuration - 0.05 then return end
	busy[plot] = model
	carrier:SetAttribute("Opening", true)
	prompt:SetAttribute("ServerEnabled", false)
	prompt.Enabled = false
	local ok, granted, petId, rarity = pcall(Inventory.OpenEgg, player, record.Id, record.EggId, rng)
	if not ok or not granted then
		carrier:SetAttribute("Opening", false)
		prompt:SetAttribute("ServerEnabled", true)
		prompt.Enabled = true
		busy[plot] = nil
		if not ok then warn("[EggOpenService] " .. tostring(granted)) end
		return
	end
	-- Inventory has committed and the existing writer has been scheduled.
	-- Send a CFrame as well as Instances so streaming/destruction cannot lose the location.
	Remotes.EggHatched:FireClient(player, {
		EggId = record.EggId, Results = { { PetId = petId, Rarity = rarity } },
		Mode = "Nest", Spot = spot, BaseCFrame = spot.WorldCFrame, EggPart = carrier,
	})
	Service.SendState(player)
	print(("[EggOpenService] %s opened %s -> %s (%s)"):format(player.Name, record.EggId, petId, rarity))
	local timing = Config.Timing
	local breakDelay = timing.ShakeRounds * (timing.SwingsPerRound * timing.SwingTime * 2 + timing.PauseBetweenRounds)
	task.delay(breakDelay, function()
		if model.Parent then model:Destroy() end
		if liveEggs[plot] == model then liveEggs[plot] = nil end
	end)
	-- Keep the next egg from overlapping this reveal. This never gates persistence.
	task.delay(breakDelay + timing.SplitTime * 1.4 + timing.RevealPop * 1.4
		+ timing.Hold + Config.Rarity[rarity].ExtraHold + timing.FadeOut, function()
		busy[plot] = nil
		if findPlot(player) == plot then Service.Refresh(player) end
	end)
end

function Service.Refresh(player)
	local plot = findPlot(player)
	local spot = findSpot(plot)
	if not spot or busy[plot] then return end
	local state = Inventory.Get(player)
	if not state then return end
	if liveEggs[plot] then liveEggs[plot]:Destroy(); liveEggs[plot] = nil end
	local anchor = spot.Parent:FindFirstChild("EggShopAnchor")
	if anchor then anchor:Destroy() end
	local activated = plot.CentreSlots.Centre05_Pet:FindFirstChild("Activated")
	if not activated or not activated.Value then return end
	local record = state.NestEgg
	if not record then
		anchor = Instance.new("Part")
		anchor.Name = "EggShopAnchor"
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Transparency = 1
		anchor.CFrame = spot.WorldCFrame * CFrame.new(0, 1, 0)
		prepare(anchor)
		anchor.Parent = spot.Parent
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EggShopPrompt"
		prompt.ActionText = "Choose Egg"
		prompt.ObjectText = "Your Nest"
		prompt.MaxActivationDistance = Config.OpenPrompt.MaxActivationDistance
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("ServerEnabled", true)
		prompt.Parent = anchor
		CollectionService:AddTag(prompt, "EggShopPrompt")
		prompt.Triggered:Connect(function(who)
			if who == player and findPlot(who) == plot and isNear(who, spot) then Service.SendState(who, nil, true) end
		end)
		return
	end
	local kit = Kit[record.EggId]
	local template = ReplicatedStorage.Assets.EggHatch:FindFirstChild(record.EggId .. "_Hatch")
	if not kit or not template then warn("[EggOpenService] Missing hatch template"); return end
	local model = Instance.new("Model")
	model.Name = "NestEgg"
	local carrier = Instance.new("Part")
	carrier.Name = "EggPart"
	carrier.Size = kit.Whole.Size
	carrier.Transparency = 1
	carrier.CFrame = spot.WorldCFrame * CFrame.new(0, carrier.Size.Y / 2, 0)
	prepare(carrier)
	carrier:SetAttribute("EggId", record.EggId)
	carrier:SetAttribute("EggRecordId", record.Id)
	carrier:SetAttribute("Opening", false)
	carrier.Parent = model
	for _, name in ipairs({ "ShellTop", "ShellBottom" }) do
		local part = template[name]:Clone()
		prepare(part)
		part.CFrame = spot.WorldCFrame * CFrame.new(kit[name].Centre)
		part.Parent = carrier
	end
	local prompt = Service.AttachPrompt(carrier, record.EggId)
	model.Parent = spot.Parent.Parent
	liveEggs[plot] = model
	local holds = setmetatable({}, { __mode = "k" })
	prompt.PromptButtonHoldBegan:Connect(function(who)
		if not busy[plot] and prompt.Enabled and findPlot(who) == plot and isNear(who, spot) then holds[who] = os.clock() end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(who)
		-- Roblox can emit HoldEnded just before Triggered on a completed hold.
		-- Cancel short holds immediately; retain completed holds for that event only.
		local started = holds[who]
		if not started then return end
		if os.clock() - started < Config.OpenPrompt.HoldDuration - 0.05 then
			holds[who] = nil
		else
			task.delay(0.2, function() if holds[who] == started then holds[who] = nil end end)
		end
	end)
	prompt.Triggered:Connect(function(who) openEgg(who, plot, spot, model, carrier, record, prompt, holds) end)
end

function Service.Init()
	if initialized then return end
	initialized = true
	local plot = workspace:FindFirstChild("P1")
	assert(findSpot(plot), "P1 PetSpot is missing")
	plot.CentreSlots.Centre05_Pet.Activated.Changed:Connect(function()
		local owner = plot:GetAttribute("Owner")
		local player = owner and Players:GetPlayerByUserId(owner)
		if player then Service.Refresh(player) end
	end)
	plot:GetAttributeChangedSignal("Owner"):Connect(function()
		if liveEggs[plot] then liveEggs[plot]:Destroy(); liveEggs[plot] = nil end
		busy[plot] = nil
		local spot = findSpot(plot)
		local anchor = spot and spot.Parent:FindFirstChild("EggShopAnchor")
		if anchor then anchor:Destroy() end
		local owner = plot:GetAttribute("Owner")
		local player = owner and Players:GetPlayerByUserId(owner)
		if player then Service.Refresh(player); Service.SendState(player) end
	end)
	local function connectPlayer(player)
		-- Policies are fetched once, outside the non-yielding purchase transaction.
		task.spawn(function()
			local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
			policy[player] = ok and info or nil
		end)
		player:GetAttributeChangedSignal("AssignedPlotName"):Connect(function()
			Service.Refresh(player)
		end)
		if player:GetAttribute("DataLoaded") then Service.Refresh(player) end
	end
	Players.PlayerAdded:Connect(connectPlayer)
	for _, player in ipairs(Players:GetPlayers()) do connectPlayer(player) end
	Remotes.BuyNestEgg.OnServerEvent:Connect(function(player, eggId)
		if type(eggId) ~= "string" or not Eggs.Eggs[eggId] then return end
		local now = os.clock()
		if now - (lastPurchase[player] or -math.huge) < 0.75 then return end
		lastPurchase[player] = now
		local plot = findPlot(player)
		local spot = findSpot(plot)
		if not plot or busy[plot] or not isNear(player, spot) then Service.SendState(player, "Walk to your P1 nest first"); return end
		local info = policy[player]
		if not info or info.ArePaidRandomItemsRestricted then
			Service.SendState(player, "Random egg purchases are unavailable for this account")
			return
		end
		local ok, result = Inventory.PurchaseEgg(player, eggId)
		if ok then Service.Refresh(player) end
		Service.SendState(player, ok and "Egg placed! Hold E at your nest to open it." or result)
	end)
	Remotes.GetPetInventory.OnServerInvoke = function(player)
		return Inventory.Get(player)
	end
end

return Service
