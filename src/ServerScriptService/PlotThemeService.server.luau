--!strict
--[[
	PlotThemeService
	Applies server-owned accent colors to tagged plot props.

	Uses CollectionService tag signals instead of plot.DescendantAdded so ball
	spawns do not create unnecessary work.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.PlotThemeConfig)
local PlotTheme = require(ReplicatedStorage.PlotTheme)

local PLOTS_PARENT = workspace

local remoteFolder = ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = Config.RemoteFolderName
	remoteFolder.Parent = ReplicatedStorage
end

local requestPlotColor = remoteFolder:FindFirstChild(Config.RequestEventName)
if not requestPlotColor then
	requestPlotColor = Instance.new("RemoteEvent")
	requestPlotColor.Name = Config.RequestEventName
	requestPlotColor.Parent = remoteFolder
end

local lastRequestAt: { [Player]: number } = {}

local function getPlots(): { Instance }
	local plots = {}
	for _, child in ipairs(PLOTS_PARENT:GetChildren()) do
		if child.Name:match("^P%d+$") then
			table.insert(plots, child)
		end
	end
	table.sort(plots, function(a, b)
		return tonumber(a.Name:match("%d+")) < tonumber(b.Name:match("%d+"))
	end)
	return plots
end

local function findOwnedPlot(player: Player): Instance?
	for _, plot in ipairs(getPlots()) do
		if plot:GetAttribute("Owner") == player.UserId then
			return plot
		end
	end
	return nil
end

local function isFiniteNumber(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function isValidColor(value: any): boolean
	return typeof(value) == "Color3"
		and isFiniteNumber(value.R)
		and isFiniteNumber(value.G)
		and isFiniteNumber(value.B)
end

local function setPlotColor(plot: Instance, color: Color3)
	if plot:GetAttribute("PlotColor") == color then
		PlotTheme.ApplyToPlot(plot)
	else
		plot:SetAttribute("PlotColor", color)
	end
end

local function applyOwnerColor(plot: Instance)
	local ownerId = tonumber(plot:GetAttribute("Owner"))
	if not ownerId then
		setPlotColor(plot, Config.PlotColors[plot.Name] or Color3.fromRGB(150, 150, 150))
		return
	end

	local player = Players:GetPlayerByUserId(ownerId)
	local savedColor = player and player:GetAttribute("SavedPlotColor")
	if typeof(savedColor) == "Color3" then
		setPlotColor(plot, savedColor)
	else
		setPlotColor(plot, Config.PlotColors[plot.Name] or Color3.fromRGB(150, 150, 150))
	end
end

local function themeModel(model: Instance)
	local plot = PlotTheme.GetOwningPlot(model)
	if not plot then
		warn(("[PlotThemeService] %s is tagged but not inside a plot; skipping."):format(
			model:GetFullName()
		))
		return
	end

	PlotTheme.ApplyToModel(model, PlotTheme.GetPlotColor(plot))
end

local function onThemedModelAdded(model: Instance)
	if model:IsDescendantOf(workspace) then
		themeModel(model)
		return
	end

	local connection: RBXScriptConnection
	connection = model.AncestryChanged:Connect(function()
		if model:IsDescendantOf(workspace) then
			connection:Disconnect()
			themeModel(model)
		elseif model.Parent == nil and not model:IsDescendantOf(game) then
			connection:Disconnect()
		end
	end)
end

local function themeAccentPart(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local plot = PlotTheme.GetOwningPlot(instance)
	if not plot then
		warn(("[PlotThemeService] %s is an accent but is not inside a plot; skipping."):format(
			instance:GetFullName()
		))
		return
	end

	PlotTheme.ApplyToAccentPart(instance, PlotTheme.GetPlotColor(plot))
end

local function onAccentPartAdded(instance: Instance)
	if instance:IsDescendantOf(workspace) then
		themeAccentPart(instance)
		return
	end

	local connection: RBXScriptConnection
	connection = instance.AncestryChanged:Connect(function()
		if instance:IsDescendantOf(workspace) then
			connection:Disconnect()
			themeAccentPart(instance)
		elseif instance.Parent == nil and not instance:IsDescendantOf(game) then
			connection:Disconnect()
		end
	end)
end

local plots = getPlots()

-- Tag themed models that were placed in a plot before this service started.
for _, plot in ipairs(plots) do
	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("Model")
			and descendant:FindFirstChild(Config.ThemeFolderName)
			and not CollectionService:HasTag(descendant, Config.Tag)
		then
			CollectionService:AddTag(descendant, Config.Tag)
		end
	end
end

local totalParts = 0
for _, plot in ipairs(plots) do
	totalParts += PlotTheme.ApplyToPlot(plot)

	plot:GetAttributeChangedSignal("PlotColor"):Connect(function()
		PlotTheme.ApplyToPlot(plot)
	end)
	plot:GetAttributeChangedSignal("Owner"):Connect(function()
		applyOwnerColor(plot)
	end)
end

local function connectPlayer(player: Player)
	player:GetAttributeChangedSignal("SavedPlotColor"):Connect(function()
		local plot = findOwnedPlot(player)
		local color = player:GetAttribute("SavedPlotColor")
		if plot and typeof(color) == "Color3" then
			setPlotColor(plot, color)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	connectPlayer(player)
end
Players.PlayerAdded:Connect(connectPlayer)
Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player] = nil
end)

requestPlotColor.OnServerEvent:Connect(function(player: Player, requestedColor: any)
	if not isValidColor(requestedColor) then
		return
	end

	local now = os.clock()
	local previous = lastRequestAt[player] or 0
	if now - previous < Config.RequestCooldownSeconds then
		return
	end
	lastRequestAt[player] = now

	local plot = findOwnedPlot(player)
	if not plot then
		return
	end

	-- Store the choice on the player so it follows them to any assigned plot.
	player:SetAttribute("SavedPlotColor", requestedColor)
	setPlotColor(plot, requestedColor)
end)

for _, plot in ipairs(plots) do
	applyOwnerColor(plot)
end

CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(onThemedModelAdded)
CollectionService:GetInstanceAddedSignal(Config.AccentPartTag):Connect(onAccentPartAdded)

print(("[PlotThemeService] Themed %d part(s) across %d plot(s)."):format(totalParts, #plots))
