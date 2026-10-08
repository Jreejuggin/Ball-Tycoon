--[[
	BankZoneHandler
	Server-authoritative gem banking. A player who stands inside the BankZone
	part, carrying at least one gem, for DEPOSIT_DELAY_SECONDS has all their
	carried Gems moved into BankedGems. The client never requests a deposit
	and never reports a balance; it only displays what the server tells it.

	Zone membership is checked by polling character positions (not Touched),
	which is more reliable and costs one small loop for the whole server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BankDepositEvent = ReplicatedStorage:WaitForChild("BankDepositEvent")

local DEPOSIT_DELAY_SECONDS = 5
local CHECK_INTERVAL_SECONDS = 0.25

local bankZone = Workspace:WaitForChild("MiddleShops")
	:WaitForChild("BankStructure")
	:WaitForChild("BankZone")

-- player -> os.clock() time their current deposit countdown began
local countdownStart = {}

local function isInsideZone(position)
	local offset = bankZone.CFrame:PointToObjectSpace(position)
	local half = bankZone.Size / 2
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Y) <= half.Y
		and math.abs(offset.Z) <= half.Z
end

local function getGemValues(player)
	local gemData = player:FindFirstChild("GemData")
	if not gemData then
		return nil, nil
	end
	return gemData:FindFirstChild("Gems"), gemData:FindFirstChild("BankedGems")
end

-- Returns the character's position only if they are alive.
local function getLivingPosition(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root then
		return root.Position
	end
	return nil
end

local function clearCountdown(player)
	if countdownStart[player] then
		countdownStart[player] = nil
		-- Setting an attribute to nil removes it; the client hides its countdown.
		player:SetAttribute("BankDepositSecondsLeft", nil)
	end
end

local function depositGems(player, gems, bankedGems)
	local amount = gems.Value
	if amount <= 0 then
		return
	end

	-- No yield between these lines, so nothing else can change the values mid-move.
	gems.Value -= amount
	bankedGems.Value += amount

	BankDepositEvent:FireClient(player, amount, bankedGems.Value)
end

local function updatePlayer(player, now)
	if not player:GetAttribute("DataLoaded") then
		clearCountdown(player)
		return
	end

	local gems, bankedGems = getGemValues(player)
	local position = getLivingPosition(player)

	if not gems or not bankedGems or not position or gems.Value <= 0 or not isInsideZone(position) then
		clearCountdown(player)
		return
	end

	local startedAt = countdownStart[player]
	if not startedAt then
		startedAt = now
		countdownStart[player] = now
	end

	local remaining = DEPOSIT_DELAY_SECONDS - (now - startedAt)
	if remaining <= 0 then
		clearCountdown(player)
		depositGems(player, gems, bankedGems)
	else
		player:SetAttribute("BankDepositSecondsLeft", math.ceil(remaining))
	end
end

task.spawn(function()
	while true do
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			updatePlayer(player, now)
		end
		task.wait(CHECK_INTERVAL_SECONDS)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	countdownStart[player] = nil
end)