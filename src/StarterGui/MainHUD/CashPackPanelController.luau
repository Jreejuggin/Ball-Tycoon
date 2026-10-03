-- CashPackPanelController
-- Builds one row per entry in ReplicatedStorage.CashPackConfig and wires
-- each Buy button to a real Robux purchase prompt. Mirrors ShopPanelController
-- exactly -- same pattern, same guard for placeholder Developer Product IDs.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local CashPackConfig = require(ReplicatedStorage:WaitForChild("CashPackConfig"))
local ButtonHoverEffect = require(ReplicatedStorage:WaitForChild("ButtonHoverEffect"))
local Theme = require(ReplicatedStorage:WaitForChild("UITheme"))
local UISurface = require(ReplicatedStorage:WaitForChild("UISurface"))

local function createPackRow(item, layoutOrder, itemList)
	local T = Theme.cashPackRow

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

	-- Icon badge (pack size abbreviation, e.g. "5K", "1M")
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

	-- "50% OFF!" badge above the Buy button, matching the reference style
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
	discountLabel.Text = "50% OFF!"
	discountLabel.Parent = row

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
				"[CashPack] '%s' has no real Developer Product ID yet. Create one in Creator Dashboard > Monetization > Developer Products, then set productId in CashPackConfig.",
				item.name
			))
			return
		end
		MarketplaceService:PromptProductPurchase(player, item.productId)
	end)

	ButtonHoverEffect.apply(buyButton, Theme.hover.buyButton)

	return row
end

-- The panel is built at runtime by MainHUDBuilder, so this can no longer be a
-- LocalScript parented to it. MainHUDController passes in the row container
-- straight from the builder's refs, so this never looks it up by name.
return function(itemList)
	for index, item in ipairs(CashPackConfig) do
		createPackRow(item, index, itemList)
	end
end

