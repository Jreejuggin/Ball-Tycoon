-- Render the server-published equipment for every player. These pets are cosmetic.
-- One render connection handles all followers; no network traffic is sent per frame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("PetFollowConfig"))
local templates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
local localPlayer = Players.LocalPlayer
local entries = {}
local rootFolder = Instance.new("Folder")
rootFolder.Name = "LocalPetFollowers"
rootFolder.Parent = workspace

local function clearPets(entry)
	for _, pet in ipairs(entry.pets) do pet:Destroy() end
	entry.pets = {}
	entry.frame = nil
end

local function rebuild(player)
	local entry = entries[player]
	if not entry then return end
	local previousCounts = {}
	for _, pet in ipairs(entry.pets) do
		local id = pet:GetAttribute("PetId")
		previousCounts[id] = (previousCounts[id] or 0) + 1
	end
	clearPets(entry)
	local encoded = player:GetAttribute("EquippedPetIds")
	if type(encoded) ~= "string" then return end
	local ok, ids = pcall(HttpService.JSONDecode, HttpService, encoded)
	if not ok or type(ids) ~= "table" then return end
	for slot = 1, math.min(#ids, Config.MaxEquippedPets) do
		local template = type(ids[slot]) == "string" and templates:FindFirstChild(ids[slot])
		if template and template:IsA("BasePart") then
			local pet = template:Clone()
			pet.Name = tostring(player.UserId) .. "_" .. slot .. "_" .. template.Name
			for _, child in ipairs(pet:GetDescendants()) do
				if child:IsA("LuaSourceContainer") or child:IsA("JointInstance") or child:IsA("Constraint") then child:Destroy() end
			end
			pet.Anchored = true
			pet.CanCollide = false
			pet.CanTouch = false
			pet.CanQuery = false
			pet.Massless = true
			pet.CastShadow = false
			pet.PivotOffset = CFrame.identity
			local largest = math.max(pet.Size.X, pet.Size.Y, pet.Size.Z)
			if largest > Config.MaxVisualSize then pet.Size *= Config.MaxVisualSize / largest end
			pet.LocalTransparencyModifier = 1
			pet:SetAttribute("OwnerUserId", player.UserId)
			pet:SetAttribute("PetId", template.Name)
			pet:SetAttribute("EquippedSlot", slot)
			local previous = previousCounts[template.Name] or 0
			previousCounts[template.Name] = math.max(0, previous - 1)
			pet:SetAttribute("VisibleAfter", previous > 0 and 0 or (player:GetAttribute("PetFollowerRevealAt") or 0))
			pet.Parent = rootFolder
			table.insert(entry.pets, pet)
		end
	end
end

local function addPlayer(player)
	if entries[player] then return end
	local entry = { pets = {}, connections = {} }
	entries[player] = entry
	table.insert(entry.connections, player:GetAttributeChangedSignal("EquippedPetIds"):Connect(function() rebuild(player) end))
	table.insert(entry.connections, player.CharacterAdded:Connect(function() entry.frame = nil end))
	table.insert(entry.connections, player.CharacterRemoving:Connect(function()
		entry.frame = nil
		for _, pet in ipairs(entry.pets) do pet.LocalTransparencyModifier = 1 end
	end))
	rebuild(player)
end

local function removePlayer(player)
	local entry = entries[player]
	if not entry then return end
	for _, connection in ipairs(entry.connections) do connection:Disconnect() end
	clearPets(entry)
	entries[player] = nil
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)
for _, player in ipairs(Players:GetPlayers()) do addPlayer(player) end

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	local localCharacter = localPlayer.Character
	local localHead = localCharacter and localCharacter:FindFirstChild("Head")
	local firstPerson = camera and localHead and (camera.CFrame.Position - localHead.Position).Magnitude < 1
	local now = workspace:GetServerTimeNow()
	for player, entry in pairs(entries) do
		if #entry.pets == 0 then continue end
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local visible = head and root and humanoid and humanoid.Health > 0 and player:GetAttribute("DataLoaded") == true
			and camera and (camera.CFrame.Position - head.Position).Magnitude <= Config.RenderDistance
			and not (player == localPlayer and firstPerson)
		if visible then
			local target = CFrame.new(head.Position) * root.CFrame.Rotation
			if not entry.frame or (entry.frame.Position - target.Position).Magnitude > Config.TeleportSnapDistance then
				entry.frame = target
			else
				entry.frame = entry.frame:Lerp(target, 1 - math.exp(-Config.FollowResponsiveness * dt))
			end
			local formation = Config.Formations[#entry.pets]
			for index, pet in ipairs(entry.pets) do
				local phase = now * Config.BobSpeed + index * 1.7
				pet.CFrame = entry.frame * CFrame.new(formation[index] + Vector3.new(0, math.sin(phase) * Config.BobHeight, 0))
					* CFrame.Angles(0, math.sin(phase * 0.5) * 0.08, 0)
				pet.LocalTransparencyModifier = now >= pet:GetAttribute("VisibleAfter") and 0 or 1
			end
		else
			entry.frame = nil
			for _, pet in ipairs(entry.pets) do pet.LocalTransparencyModifier = 1 end
		end
	end
end)
