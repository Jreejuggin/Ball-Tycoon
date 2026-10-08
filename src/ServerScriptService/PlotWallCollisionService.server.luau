--!strict
-- Keeps plot perimeter collision synchronized with the Home Walls purchase.
-- Empty, unowned, and pre-purchase plots remain fully walkable.
local PLOT_COUNT = 10
local WALL_MODEL_NAME = "PerimeterWall"

local function getWallsActivated(plot: Instance): BoolValue?
	local centreSlots = plot:FindFirstChild("CentreSlots")
	local homeCentre = centreSlots and centreSlots:FindFirstChild("Centre02_Home")
	local structureSlots = homeCentre and homeCentre:FindFirstChild("StructureSlots")
	local wallSlot = structureSlots and structureSlots:FindFirstChild("Slot_Walls")
	local buyPad = wallSlot and wallSlot:FindFirstChild("BuyPad")
	local activated = buyPad and buyPad:FindFirstChild("Activated")

	if activated and activated:IsA("BoolValue") then
		return activated
	end
	return nil
end

local function setWallPartState(part: BasePart, enabled: boolean)
	part.Anchored = true
	part.CanCollide = enabled
	part.CanTouch = enabled
	part.CanQuery = enabled
end

local function applyWallCollision(wallModel: Instance, enabled: boolean)
	for _, descendant in ipairs(wallModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			setWallPartState(descendant, enabled)
		end
	end
end

local function wirePlot(plot: Instance): (number, boolean)
	local wallModel = plot:FindFirstChild(WALL_MODEL_NAME)
	local wallsActivated = getWallsActivated(plot)
	if not wallModel or not wallsActivated then
		warn(("[PlotWallCollisionService] Missing wall model or Walls activation state on %s."):format(plot.Name))
		return 0, false
	end

	local partCount = 0
	for _, descendant in ipairs(wallModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			partCount += 1
		end
	end

	local function refresh()
		applyWallCollision(wallModel, wallsActivated.Value)
	end

	wallsActivated:GetPropertyChangedSignal("Value"):Connect(refresh)
	wallModel.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			setWallPartState(descendant, wallsActivated.Value)
		end
	end)

	refresh()
	return partCount, true
end

local wiredPlots = 0
local wiredParts = 0

for plotIndex = 1, PLOT_COUNT do
	local plot = workspace:FindFirstChild("P" .. plotIndex)
	if plot then
		local partCount, wired = wirePlot(plot)
		wiredParts += partCount
		if wired then
			wiredPlots += 1
		end
	else
		warn(("[PlotWallCollisionService] Missing P%d."):format(plotIndex))
	end
end

print(("[PlotWallCollisionService] Wired %d perimeter part(s) across %d plot(s); collision follows Walls ownership."):format(
	wiredParts,
	wiredPlots
))
