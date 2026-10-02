--!strict
-- Keeps every plot perimeter physically solid in Edit defaults and at runtime.
-- This service is intentionally separate from visual theming and progression.
local PLOT_COUNT = 10
local WALL_MODEL_NAME = "PerimeterWall"

local function enforceWallPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = true

	part:GetPropertyChangedSignal("CanCollide"):Connect(function()
		if not part.CanCollide then
			part.CanCollide = true
		end
	end)
end

local function wireWallModel(wallModel: Instance)
	for _, descendant in ipairs(wallModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			enforceWallPart(descendant)
		end
	end

	wallModel.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			enforceWallPart(descendant)
		end
	end)
end

local wiredPlots = 0
local wiredParts = 0

for plotIndex = 1, PLOT_COUNT do
	local plot = workspace:FindFirstChild("P" .. plotIndex)
	local wallModel = plot and plot:FindFirstChild(WALL_MODEL_NAME)
	if wallModel then
		for _, descendant in ipairs(wallModel:GetDescendants()) do
			if descendant:IsA("BasePart") then
				wiredParts += 1
			end
		end
		wireWallModel(wallModel)
		wiredPlots += 1
	else
		warn(("[PlotWallCollisionService] Missing %s on P%d."):format(WALL_MODEL_NAME, plotIndex))
	end
end

print(("[PlotWallCollisionService] Enforced %d perimeter part(s) across %d plot(s)."):format(
	wiredParts,
	wiredPlots
))
