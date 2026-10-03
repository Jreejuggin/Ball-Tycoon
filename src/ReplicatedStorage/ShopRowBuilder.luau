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
local Theme = require(ReplicatedStorage:WaitForChild("UITheme"))
local UISurface = require(ReplicatedStorage:WaitForChild("UISurface"))

local player = Players.LocalPlayer

local ShopRowBuilder = {}

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
	local T = Theme.row

	local row = Instance.new("Frame")
	row.Name = item.id .. "Row"
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, T.height)
	row.BackgroundColor3 = T.background
	row.BorderSizePixel = 0
	row.Parent = itemList

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, T.cornerRadius)
	rowCorner.Parent = row

	local rowStroke = Instance.new("UIStroke")
	rowStroke.Color = T.strokeColor
	rowStroke.Thickness = T.strokeThickness
	rowStroke.Transparency = T.strokeTransparency
	rowStroke.Parent = row

	-- Icon badge
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = T.iconPosition
	icon.Size = T.iconSize
	icon.BackgroundColor3 = item.iconColor
	icon.BorderSizePixel = 0
	icon.Parent = row

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = T.iconCorner
	iconCorner.Parent = icon

	local iconLabel = Instance.new("TextLabel")
	iconLabel.BackgroundTransparency = 1
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.Font = T.iconFont
	iconLabel.TextSize = T.iconTextSize
	iconLabel.TextColor3 = T.iconTextColor
	iconLabel.TextStrokeColor3 = T.iconStrokeColor
	iconLabel.TextStrokeTransparency = T.iconStrokeTransparency
	iconLabel.Text = item.iconText
	iconLabel.Parent = icon

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = T.namePosition
	nameLabel.Size = T.nameSize
	nameLabel.Font = T.nameFont
	nameLabel.TextSize = T.nameTextSize
	nameLabel.TextColor3 = T.nameColor
	nameLabel.TextStrokeColor3 = T.nameStrokeColor
	nameLabel.TextStrokeTransparency = T.nameStrokeTransparency
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = item.name
	nameLabel.Parent = row

	-- Price
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.BackgroundTransparency = 1
	priceLabel.Position = T.pricePosition
	priceLabel.Size = T.priceSize
	priceLabel.Font = T.priceFont
	priceLabel.TextSize = T.priceTextSize
	priceLabel.TextColor3 = T.priceColor
	priceLabel.TextStrokeTransparency = T.priceStrokeTransparency
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.Text = item.priceText
	priceLabel.Parent = row

	-- Buy button
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.AnchorPoint = Vector2.new(1, 0.5)
	buyButton.Position = T.buyPosition
	buyButton.Size = T.buySize
	buyButton.BackgroundColor3 = T.buyColor
	buyButton.BorderSizePixel = 0
	buyButton.Font = T.buyFont
	buyButton.TextSize = T.buyTextSize
	buyButton.TextColor3 = T.buyTextColor
	buyButton.TextStrokeColor3 = T.buyStrokeColor
	buyButton.TextStrokeTransparency = T.buyStrokeTransparency
	buyButton.Text = "BUY"
	buyButton.Parent = row

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, T.buyCorner)
	buyCorner.Parent = buyButton

	local buyGradient = Instance.new("UIGradient")
	buyGradient.Rotation = T.buyGradientRotation
	buyGradient.Color = T.buyGradient
	buyGradient.Parent = buyButton

	-- Themes that define buySurface replace the plain gradient above with a
	-- gradient + tiled pattern over an extruded lip, and move the caption into
	-- a child label. The UICorner and UIGradient already created are updated in
	-- place, not duplicated. Production leaves buySurface nil and keeps its
	-- plain "BUY" text.
	if T.buySurface then
		UISurface.applyTexturedSurface(buyButton, T.buySurface)
		buyButton.Text = ""

		-- The pattern is a child, and children always render above their
		-- parent, so it would cover the button's own Text. The caption goes in
		-- a sibling label with a higher ZIndex instead, kept short by the lip
		-- so it centres on the lit face.
		local caption = Instance.new("TextLabel")
		caption.Name = "Caption"
		caption.Size = UDim2.new(1, 0, 1, -(T.buySurface.depth or 0))
		caption.BackgroundTransparency = 1
		caption.Text = T.buySurface.captionText
		caption.Font = T.buyFont
		caption.TextSize = T.buyTextSize
		caption.TextColor3 = T.buyTextColor
		caption.TextStrokeColor3 = T.buyStrokeColor
		caption.TextStrokeTransparency = T.buyStrokeTransparency
		caption.ZIndex = 2
		caption.Parent = buyButton
	end

	buyButton.MouseButton1Click:Connect(function()
		if onBuy then
			onBuy(item)
		else
			defaultRobuxBuy(item, logPrefix)
		end
	end)

	ButtonHoverEffect.apply(buyButton, Theme.hover.buyButton)

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
