-- ShopRowBuilder
-- Shared row-building logic for every shop-style panel in the game (Shop,
-- Cash packs, and the MiddleShops panels). One item config in, one fully
-- wired UI row out -- icon, name, price, Buy button, and the standard
-- hover animation/sound.
--
-- Purchase flow is pluggable via `onBuy` so this same builder can drive
-- both Robux purchases (the default, used by the main Shop) and in-game
-- Cash purchases (used by MiddleShops) without duplicating the row UI code.
--
-- Usage (Robux, default):
--   ShopRowBuilder.buildRows(someScrollingFrame, someConfigTable, "[Shop]")
--
-- Usage (custom purchase flow, e.g. Cash-based):
--   ShopRowBuilder.buildRows(itemList, config, "[CreatureShop]", function(item)
--       purchaseEvent:FireServer("CreatureShopConfig", item.id)
--   end)

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ButtonHoverEffect = require(ReplicatedStorage:WaitForChild("ButtonHoverEffect"))

local player = Players.LocalPlayer

local ShopRowBuilder = {}

local ROW_HEIGHT = 84

-- Default purchase flow: real Robux purchase via MarketplaceService, guarded
-- against placeholder Developer Product IDs. Used whenever `onBuy` isn't
-- provided to buildRows (e.g. the main Shop panel).
local function defaultRobuxBuy(item, logPrefix)
	if not item.productId or item.productId == 0 then
		warn(string.format(
			"%s '%s' has no real Developer Product ID yet. Create one in Creator Dashboard > Monetization > Developer Products, then set productId in its config.",
			logPrefix or "[Shop]",
			item.name
		))
		return
	end
	MarketplaceService:PromptProductPurchase(player, item.productId)
end

local function createRow(itemList, item, layoutOrder, logPrefix, onBuy)
	local row = Instance.new("Frame")
	row.Name = item.id .. "Row"
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.fromRGB(24, 22, 18)
	row.BorderSizePixel = 0
	row.Parent = itemList

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 14)
	rowCorner.Parent = row

	local rowStroke = Instance.new("UIStroke")
	rowStroke.Color = Color3.fromRGB(200, 160, 60)
	rowStroke.Thickness = 1.5
	rowStroke.Transparency = 0.3
	rowStroke.Parent = row

	-- Icon badge
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 10, 0.5, 0)
	icon.Size = UDim2.new(0, 60, 0, 60)
	icon.BackgroundColor3 = item.iconColor
	icon.BorderSizePixel = 0
	icon.Parent = row

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0.5, 0)
	iconCorner.Parent = icon

	local iconLabel = Instance.new("TextLabel")
	iconLabel.BackgroundTransparency = 1
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.Font = Enum.Font.GothamBlack
	iconLabel.TextSize = 16
	iconLabel.TextColor3 = Color3.new(1, 1, 1)
	iconLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	iconLabel.TextStrokeTransparency = 0
	iconLabel.Text = item.iconText
	iconLabel.Parent = icon

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 84, 0, 10)
	nameLabel.Size = UDim2.new(0, 150, 0, 24)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 18
	nameLabel.TextColor3 = Color3.fromRGB(255, 205, 60)
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = item.name
	nameLabel.Parent = row

	-- Price
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.BackgroundTransparency = 1
	priceLabel.Position = UDim2.new(0, 84, 0, 38)
	priceLabel.Size = UDim2.new(0, 150, 0, 22)
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextSize = 16
	priceLabel.TextColor3 = Color3.new(1, 1, 1)
	priceLabel.TextStrokeTransparency = 0.4
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.Text = item.priceText
	priceLabel.Parent = row

	-- Buy button
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.AnchorPoint = Vector2.new(1, 0.5)
	buyButton.Position = UDim2.new(1, -10, 0.5, 0)
	buyButton.Size = UDim2.new(0, 80, 0, 40)
	buyButton.BackgroundColor3 = Color3.fromRGB(70, 190, 80)
	buyButton.BorderSizePixel = 0
	buyButton.Font = Enum.Font.GothamBlack
	buyButton.TextSize = 18
	buyButton.TextColor3 = Color3.new(1, 1, 1)
	buyButton.TextStrokeColor3 = Color3.new(0, 0, 0)
	buyButton.TextStrokeTransparency = 0
	buyButton.Text = "BUY"
	buyButton.Parent = row

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 10)
	buyCorner.Parent = buyButton

	local buyGradient = Instance.new("UIGradient")
	buyGradient.Rotation = 90
	buyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 230, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 160, 60)),
	})
	buyGradient.Parent = buyButton

	buyButton.MouseButton1Click:Connect(function()
		if onBuy then
			onBuy(item)
		else
			defaultRobuxBuy(item, logPrefix)
		end
	end)

	ButtonHoverEffect.apply(buyButton, { scale = 1.1, lift = 3 })

	return row
end

-- Builds one row per entry in `config` inside `itemList` (a ScrollingFrame).
-- `logPrefix` is cosmetic, e.g. "[BallShop]", used in warnings.
-- `onBuy(item)` is optional -- pass it to override the default Robux
-- purchase flow (e.g. to fire a RemoteEvent for an in-game Cash purchase).
function ShopRowBuilder.buildRows(itemList, config, logPrefix, onBuy)
	-- Clear any existing rows first (safe to call more than once).
	for _, child in ipairs(itemList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, item in ipairs(config) do
		createRow(itemList, item, index, logPrefix, onBuy)
	end
end

return ShopRowBuilder
