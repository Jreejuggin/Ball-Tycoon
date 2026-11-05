-- Local prompt visibility and egg motion. The server owns rewards and permissions.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local PromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.Shared.EggHatch.HatchConfig)
local player = Players.LocalPlayer
local watched = {}
local active

local function ownerOf(instance)
	local node = instance.Parent
	while node and node ~= workspace do
		local owner = node:GetAttribute("Owner")
		if owner ~= nil then return owner end
		node = node.Parent
	end
	return nil
end

local function stopWiggle()
	if not active then return end
	active.connection:Disconnect()
	for part, original in pairs(active.parts) do
		if part.Parent then part.CFrame = original end
	end
	active = nil
end

local function unwatch(prompt)
	if active and active.prompt == prompt then stopWiggle() end
	for _, connection in ipairs(watched[prompt] or {}) do connection:Disconnect() end
	watched[prompt] = nil
end

local function watch(prompt)
	if not prompt:IsA("ProximityPrompt") or watched[prompt] then return end
	local connections = {}
	watched[prompt] = connections
	local function visibility()
		local enabled = ownerOf(prompt) == player.UserId and prompt:GetAttribute("ServerEnabled") ~= false
		if prompt.Enabled ~= enabled then prompt.Enabled = enabled end
		if not enabled and active and active.prompt == prompt then stopWiggle() end
	end
	table.insert(connections, prompt:GetPropertyChangedSignal("Enabled"):Connect(visibility))
	table.insert(connections, prompt:GetAttributeChangedSignal("ServerEnabled"):Connect(visibility))
	table.insert(connections, prompt.AncestryChanged:Connect(function()
		if not prompt:IsDescendantOf(workspace) then unwatch(prompt) else visibility() end
	end))
	local node = prompt.Parent
	while node and node ~= workspace do
		table.insert(connections, node:GetAttributeChangedSignal("Owner"):Connect(visibility))
		node = node.Parent
	end
	visibility()
end

for _, tag in ipairs({ Config.OpenPrompt.Tag, "EggShopPrompt" }) do
	for _, prompt in ipairs(CollectionService:GetTagged(tag)) do watch(prompt) end
	CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(unwatch)
end

PromptService.PromptButtonHoldBegan:Connect(function(prompt, who)
	if who ~= player or not CollectionService:HasTag(prompt, Config.OpenPrompt.Tag)
		or ownerOf(prompt) ~= player.UserId then return end
	stopWiggle()
	local part = prompt.Parent
	if not part or not part:IsA("BasePart") then return end
	local original = part.CFrame
	local parts = { [part] = original }
	for _, child in ipairs(part:GetDescendants()) do
		if child:IsA("BasePart") then parts[child] = child.CFrame end
	end
	local bottom = original * CFrame.new(0, -part.Size.Y / 2, 0)
	local started = os.clock()
	active = { prompt = prompt, parts = parts }
	active.connection = RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not part.Parent or not prompt.Enabled or not humanoid or humanoid.Health <= 0 then stopWiggle(); return end
		local elapsed = os.clock() - started
		local progress = math.clamp(elapsed / math.max(prompt.HoldDuration, 0.05), 0, 1)
		local tilt = math.rad(Config.OpenPrompt.WiggleMaxAngle) * (0.25 + 0.75 * progress)
			* math.sin(elapsed * (18 + 22 * progress))
		local transform = bottom * CFrame.Angles(0, 0, tilt) * bottom:Inverse()
		for piece, cf in pairs(parts) do if piece.Parent then piece.CFrame = transform * cf end end
	end)
end)

local function endHold(prompt, who)
	if who == player and active and active.prompt == prompt then stopWiggle() end
end
PromptService.PromptButtonHoldEnded:Connect(endHold)
PromptService.PromptTriggered:Connect(endHold)
PromptService.PromptHidden:Connect(function(prompt)
	if active and active.prompt == prompt then stopWiggle() end
end)
player.CharacterRemoving:Connect(stopWiggle)
