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

local ROW_HEIGHT = 84

local function createPackRow(item, layoutOrder, itemList)
	local row = Instance.new("Frame")
	row.Name = item.id .. "Row"
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.fromRGB(18, 22, 18)
	row.BorderSizePixel = 0
	row.Parent = itemList

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 14)
	rowCorner.Parent = row

	local rowStroke = Instance.new("UIStroke")
	rowStroke.Color = Color3.fromRGB(70, 200, 90)
	rowStroke.Thickness = 1.5
	rowStroke.Transparency = 0.2
	rowStroke.Parent = row

	-- Icon badge (pack size abbreviation, e.g. "5K", "1M")
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
	nameLabel.TextColor3 = Color3.fromRGB(90, 220, 110)
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

	-- "50% OFF!" badge above the Buy button, matching the reference style
	local discountLabel = Instance.new("TextLabel")
	discountLabel.Name = "DiscountLabel"
	discountLabel.AnchorPoint = Vector2.new(1, 0)
	discountLabel.Position = UDim2.new(1, -10, 0, 8)
	discountLabel.Size = UDim2.new(0, 90, 0, 16)
	discountLabel.BackgroundTransparency = 1
	discountLabel.Font = Enum.Font.GothamBlack
	discountLabel.TextSize = 13
	discountLabel.TextColor3 = Color3.fromRGB(255, 170, 40)
	discountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	discountLabel.TextStrokeTransparency = 0.3
	discountLabel.Text = "50% OFF!"
	discountLabel.Parent = row

	-- Buy button
	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyButton"
	buyButton.AnchorPoint = Vector2.new(1, 1)
	buyButton.Position = UDim2.new(1, -10, 1, -12)
	buyButton.Size = UDim2.new(0, 90, 0, 40)
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
		if not item.productId or item.productId == 0 then
			warn(string.format(
				"[CashPack] '%s' has no real Developer Product ID yet. Create one in Creator Dashboard > Monetization > Developer Products, then set productId in CashPackConfig.",
				item.name
			))
			return
		end
		MarketplaceService:PromptProductPurchase(player, item.productId)
	end)

	ButtonHoverEffect.apply(buyButton, { scale = 1.1, lift = 3 })

	return row
end

-- The panel is built at runtime by MainHUDBuilder, so this can no longer be a
-- LocalScript parented to it. MainHUDController calls this with the panel.
return function(panel)
	local itemList = panel:WaitForChild("ItemList")

	for index, item in ipairs(CashPackConfig) do
		createPackRow(item, index, itemList)
	end
end

