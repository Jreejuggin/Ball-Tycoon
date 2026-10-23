-- CashPackPanelController
-- Fills both tabs of the purchase panel: one card per entry in
-- ReplicatedStorage.CashPackConfig (Cash tab) and GemConfig (Gems tab), all
-- built by createPackRow, and wires each Buy button to a real Robux purchase
-- prompt. Same guard for placeholder Developer Product IDs as
-- ShopPanelController. Granting happens server-side in PurchaseReceiptService.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local CashPackConfig = require(ReplicatedStorage:WaitForChild("CashPackConfig"))
local GemConfig = require(ReplicatedStorage:WaitForChild("GemConfig"))
local ButtonHoverEffect = require(ReplicatedStorage:WaitForChild("ButtonHoverEffect"))
local Theme = require(ReplicatedStorage:WaitForChild("UITheme"))
local UISurface = require(ReplicatedStorage:WaitForChild("UISurface"))
local RowIcon = require(ReplicatedStorage:WaitForChild("RowIcon"))

-- One purchase card. T is the card style (Theme.cashPackRow or
-- Theme.gemPackRow); configName only names the config in warnings.
local function createPackRow(item, layoutOrder, itemList, T, configName)

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

	RowIcon.create(item, row, T)

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

	-- Promo line above the Buy button (e.g. "50% OFF!"), if the style has one.
	if T.discountText then
		local discountLabel = Instance.new("TextLabel")
		discountLabel.Name = "DiscountLabel"
		discountLabel.AnchorPoint = Vector2.new(1, 0)
		discountLabel.Position = T.discountPosition
		discountLabel.Size = T.discountSize
		discountLabel.BackgroundTransparency = 1
		discountLabel.Font = T.discountFont
		discountLabel.TextSize = T.discountTextSize
		discountLabel.TextColor3 = T.discountColor
		discountLabel.TextStrokeColor3 = T.discountStrokeColor
		discountLabel.TextStrokeTransparency = T.discountStrokeTransparency
		discountLabel.Text = T.discountText
		discountLabel.Parent = row
	end

	-- Buy button
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.AnchorPoint = Vector2.new(1, 1)
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
	-- gradient + tiled pattern, and move the caption into a child label. The
	-- UICorner and UIGradient already created are updated in place, not
	-- duplicated. Production leaves buySurface nil and keeps its "BUY" text.
	if T.buySurface then
		UISurface.applyTexturedSurface(buyButton, T.buySurface)
		buyButton.Text = ""

		local caption = Instance.new("TextLabel")
		caption.Name = "Caption"
		-- Short by the surface's extruded lip, so "Buy" centres on the lit face
		-- instead of on the whole slab and sitting half the lip too low.
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
		if not item.productId or item.productId == 0 then
			warn(string.format(
				"[%s] '%s' has no real Developer Product ID yet. Create one in Creator Dashboard > Monetization > Developer Products, then set its productId in %s.",
				configName,
				item.name,
				configName
			))
			return
		end
		MarketplaceService:PromptProductPurchase(player, item.productId)
	end)

	ButtonHoverEffect.apply(buyButton, Theme.hover.buyButton)

	return row
end

-- The panel is built at runtime by MainHUDBuilder, so this can no longer be a
-- LocalScript parented to it. MainHUDController passes in each tab's row
-- container straight from the builder's refs ({ cash = ..., gems = ... }), so
-- this never looks one up by name.
return function(lists)
	for index, item in ipairs(CashPackConfig) do
		createPackRow(item, index, lists.cash, Theme.cashPackRow, "CashPackConfig")
	end
	for index, item in ipairs(GemConfig) do
		createPackRow(item, index, lists.gems, Theme.gemPackRow, "GemConfig")
	end
end

