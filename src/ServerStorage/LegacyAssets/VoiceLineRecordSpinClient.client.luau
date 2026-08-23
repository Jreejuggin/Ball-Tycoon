--!strict
-- VoiceLineRecordSpinClient
-- Cosmetic-only record rotation. The server owns the Unlocked attribute.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "ThemedModel"
local MODEL_NAME = "VoiceLineRecordPlayer"
local SPIN_SPEED = math.rad(33)
local RECORD_PART_NAMES = {
	"Neutral_VinylRecord",
	"Neutral_VinylGrooves",
	"Theme_RecordLabel",
	"Icon_RecordMicrophone",
}

local tracked: { [Instance]: { BasePart } } = {}
local pendingConnections: { [Instance]: RBXScriptConnection } = {}
local pendingResolution: { [Instance]: boolean } = {}

local function resolveRecordParts(model: Instance): { BasePart }
	local parts = {}
	for _, name in ipairs(RECORD_PART_NAMES) do
		local instance = model:FindFirstChild(name, true)
		if instance and instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
	end
	return parts
end

local function cacheWhenReady(instance: Instance)
	if pendingResolution[instance] then
		return
	end
	pendingResolution[instance] = true
	task.spawn(function()
		while instance.Parent and CollectionService:HasTag(instance, TAG) do
			local parts = resolveRecordParts(instance)
			if #parts == #RECORD_PART_NAMES then
				tracked[instance] = parts
				pendingResolution[instance] = nil
				return
			end
			task.wait(0.25)
		end
		pendingResolution[instance] = nil
	end)
end

local function register(instance: Instance)
	if instance.Name ~= MODEL_NAME then
		return
	end
	if not instance:IsDescendantOf(workspace) then
		if pendingConnections[instance] then
			return
		end
		pendingConnections[instance] = instance.AncestryChanged:Connect(function()
			if instance:IsDescendantOf(workspace) then
				local connection = pendingConnections[instance]
				if connection then
					connection:Disconnect()
					pendingConnections[instance] = nil
				end
				cacheWhenReady(instance)
			elseif instance.Parent == nil and not instance:IsDescendantOf(game) then
				local connection = pendingConnections[instance]
				if connection then
					connection:Disconnect()
					pendingConnections[instance] = nil
				end
			end
		end)
		return
	end
	cacheWhenReady(instance)
end

local function unregister(instance: Instance)
	tracked[instance] = nil
	pendingResolution[instance] = nil
	local connection = pendingConnections[instance]
	if connection then
		connection:Disconnect()
		pendingConnections[instance] = nil
	end
end

for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
	register(instance)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)

RunService.Heartbeat:Connect(function(deltaTime)
	local rotation = CFrame.Angles(0, SPIN_SPEED * deltaTime, 0)
	for model, parts in pairs(tracked) do
		if model.Parent == nil then
			tracked[model] = nil
		elseif model:GetAttribute("Unlocked") == true then
			for _, part in ipairs(parts) do
				if part.Parent then
					part.CFrame *= rotation
				end
			end
		end
	end
end)
