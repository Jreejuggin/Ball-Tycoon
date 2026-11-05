-- WorkerVoiceLineController
-- One server-wide loop controls occasional worker barks. This avoids one timer
-- per worker, prevents audio spam, and keeps workers feeling alive without
-- talking over the core tycoon feedback sounds.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SFXSettings = require(ReplicatedStorage:WaitForChild("SFXSettings"))

local VOICE_LINE_IDS = {
	"rbxassetid://111426373017081",
	"rbxassetid://73964096479702",
	"rbxassetid://78005173847052",
}

local MIN_INTERVAL_SECONDS = 35
local MAX_INTERVAL_SECONDS = 60
local NO_WORKER_RETRY_SECONDS = 8
local SAME_WORKER_COOLDOWN_SECONDS = 120

local WORKER_NAMES = {
	Worker1 = true,
	ConveyorWorker = true,
	BigConveyorWorker = true,
}

local lastSpokeAtByWorker = setmetatable({}, {__mode = "k"})

local function isPlotModel(model)
	return model and model.Parent == workspace and string.match(model.Name, "^P%d+$") ~= nil
end

local function getPlotForWorker(worker)
	local current = worker
	while current and current.Parent ~= workspace do
		current = current.Parent
	end
	return isPlotModel(current) and current or nil
end

local function getWorkerSoundPart(worker)
	local head = worker:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end

	local hrp = worker:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	return nil
end

local function isEligibleWorker(worker)
	if not worker:IsA("Model") then
		return false
	end
	if not WORKER_NAMES[worker.Name] and worker:GetAttribute("WorkerLevel") == nil then
		return false
	end
	if not getPlotForWorker(worker) then
		return false
	end

	local humanoid = worker:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	return getWorkerSoundPart(worker) ~= nil
end

local function getEligibleWorkers()
	local workers = {}
	local now = os.clock()

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if isEligibleWorker(descendant) then
			local lastSpokeAt = lastSpokeAtByWorker[descendant]
			if not lastSpokeAt or now - lastSpokeAt >= SAME_WORKER_COOLDOWN_SECONDS then
				table.insert(workers, descendant)
			end
		end
	end

	if #workers == 0 then
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if isEligibleWorker(descendant) then
				table.insert(workers, descendant)
			end
		end
	end

	return workers
end

local function playVoiceLine(worker)
	local soundPart = getWorkerSoundPart(worker)
	if not soundPart then
		return false
	end

	local sound = Instance.new("Sound")
	sound.Name = "WorkerVoiceLine"
	sound.SoundId = VOICE_LINE_IDS[math.random(1, #VOICE_LINE_IDS)]
	sound.Volume = 0.75
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 70
	sound.Looped = false
	SFXSettings.ApplyToSound(sound)
	sound.Parent = soundPart

	local endedConnection
	endedConnection = sound.Ended:Connect(function()
		if endedConnection then
			endedConnection:Disconnect()
		end
		sound:Destroy()
	end)

	sound:Play()
	Debris:AddItem(sound, 12)
	lastSpokeAtByWorker[worker] = os.clock()
	return true
end

math.randomseed(os.clock() * 1000000)

task.wait(math.random(12, 22))

while true do
	local workers = getEligibleWorkers()
	if #workers > 0 then
		local worker = workers[math.random(1, #workers)]
		playVoiceLine(worker)
		task.wait(math.random(MIN_INTERVAL_SECONDS, MAX_INTERVAL_SECONDS))
	else
		task.wait(NO_WORKER_RETRY_SECONDS)
	end
end
