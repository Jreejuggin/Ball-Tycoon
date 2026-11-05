-- Simple P1 prototype shop and pet list. All purchases are rechecked on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Eggs = require(ReplicatedStorage.EggConfig)
local Config = require(ReplicatedStorage.Shared.EggHatch.HatchConfig)
local Remotes = ReplicatedStorage.Remotes
local state

local function create(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties) do object[key] = value end
	object.Parent = parent
	return object
end

local gui = create("ScreenGui", player:WaitForChild("PlayerGui"), {
	Name = "EggNestGui", ResetOnSpawn = false, DisplayOrder = 15,
})
local toggle = create("TextButton", gui, {
	Name = "PetsButton", Text = "Nest & Pets", Position = UDim2.new(1, -150, 1, -64),
	Size = UDim2.fromOffset(136, 44), BackgroundColor3 = Color3.fromRGB(66, 57, 100),
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 16,
})
create("UICorner", toggle, { CornerRadius = UDim.new(0, 12) })
local panel = create("Frame", gui, {
	Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.88, 0.8), BackgroundColor3 = Color3.fromRGB(27, 25, 42), Visible = false,
})
create("UISizeConstraint", panel, { MaxSize = Vector2.new(600, 640) })
create("UICorner", panel, { CornerRadius = UDim.new(0, 16) })
create("TextLabel", panel, {
	Text = "Your Nest & Pets", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 12),
	Size = UDim2.new(1, -80, 0, 32), TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold, TextSize = 23, TextXAlignment = Enum.TextXAlignment.Left,
})
local close = create("TextButton", panel, {
	Text = "X", BackgroundTransparency = 1, Position = UDim2.new(1, -52, 0, 6),
	Size = UDim2.fromOffset(44, 44), TextColor3 = Color3.new(1, 1, 1), TextSize = 22,
})
local status = create("TextLabel", panel, {
	Name = "Status", Text = "Walk to your P1 nest to buy an egg.", BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 44), TextWrapped = true,
	TextColor3 = Color3.fromRGB(216, 209, 237), Font = Enum.Font.Gotham, TextSize = 14,
})
local list = create("ScrollingFrame", panel, {
	Position = UDim2.fromOffset(16, 104), Size = UDim2.new(1, -32, 1, -120),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
})
create("UIListLayout", list, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
local rows = {}
local owned = create("TextLabel", list, {
	Name = "OwnedPets", LayoutOrder = 10, Size = UDim2.new(1, -8, 0, 40), AutomaticSize = Enum.AutomaticSize.Y,
	Text = "Pets: none yet", TextWrapped = true, BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1), TextSize = 15, Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
})
for index, eggId in ipairs(Eggs.Order) do
	local egg = Eggs.Eggs[eggId]
	local row = create("Frame", list, {
		Name = eggId, LayoutOrder = index, Size = UDim2.new(1, -8, 0, 126),
		BackgroundColor3 = Color3.fromRGB(44, 39, 62),
	})
	create("UICorner", row, { CornerRadius = UDim.new(0, 10) })
	local button = create("TextButton", row, {
		Name = "Buy", Text = egg.DisplayName .. "  -  " .. egg.Price .. " " .. egg.Currency,
		Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 44),
		BackgroundColor3 = Color3.fromRGB(93, 76, 144), TextColor3 = Color3.new(1, 1, 1),
		TextSize = 15, Font = Enum.Font.GothamBold, TextWrapped = true,
	})
	create("UICorner", button, { CornerRadius = UDim.new(0, 8) })
	local odds = {}
	for _, pet in ipairs(egg.Pets) do
		table.insert(odds, Config.GetPetDisplayName(pet.PetId) .. " (" .. pet.Rarity .. ") " .. pet.Chance .. "%")
	end
	create("TextLabel", row, {
		Text = table.concat(odds, "  |  "), Position = UDim2.fromOffset(10, 58),
		Size = UDim2.new(1, -20, 0, 62), TextWrapped = true, BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(220, 214, 231), TextSize = 12, Font = Enum.Font.Gotham,
	})
	button.Activated:Connect(function()
		if state and state.NestEgg then status.Text = "Open the egg on your nest first."; return end
		Remotes.BuyNestEgg:FireServer(eggId)
	end)
	rows[eggId] = button
end

local function update(newState, message)
	state = newState
	if not state then return end
	local lines = {}
	for id, count in pairs(state.Pets or {}) do
		if count > 0 then table.insert(lines, Config.GetPetDisplayName(id) .. " x" .. count) end
	end
	table.sort(lines)
	owned.Text = "Your pets\n" .. (#lines > 0 and table.concat(lines, "\n") or "None yet. Open an egg at your nest!")
	status.Text = message or (state.NestEgg and "An egg is waiting on your nest. Hold E to open it." or "Walk to your P1 nest to buy an egg.")
	for _, button in pairs(rows) do button.AutoButtonColor = not state.NestEgg end
end

Remotes.EggInventory.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	update(payload.State, payload.Message)
	if payload.OpenShop then panel.Visible = true end
	if payload.State and payload.State.NestEgg and payload.Message and payload.Message:find("Egg placed", 1, true) then panel.Visible = false end
end)
local function refresh()
	local ok, result = pcall(function() return Remotes.GetPetInventory:InvokeServer() end)
	if ok then update(result) end
end
toggle.Activated:Connect(function() panel.Visible = not panel.Visible; if panel.Visible then refresh() end end)
close.Activated:Connect(function() panel.Visible = false end)
task.spawn(function()
	while not player:GetAttribute("DataLoaded") do player:GetAttributeChangedSignal("DataLoaded"):Wait() end
	refresh()
end)
