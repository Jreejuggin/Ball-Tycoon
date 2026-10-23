-- RowIcon
-- The icon at the left of a purchase row: the item's art when it has an
-- iconAssetId, or a coloured badge with its iconText when it has none, or when
-- the art fails to load.
--
-- Shared by CashPackPanelController (cash and gem cards) and ShopRowBuilder
-- (the Shop and MiddleShops rows), so every panel's icons behave the same way.
--
-- Style fields read from T:
--   iconPosition, iconSize, iconCorner, iconFont, iconTextSize, iconTextColor,
--   iconStrokeColor, iconStrokeTransparency   (the badge)
--   iconBackground                            (optional badge colour when the
--                                              item has no iconColor)
--   iconImagePosition, iconImageSize, iconImageCrop   (the art slot)
--
-- A style without iconImageSize never shows art, only the badge. That is what
-- keeps the production theme's shop rows, which do not define the art slot,
-- on their badges.

local ContentProvider = game:GetService("ContentProvider")

local RowIcon = {}

-- Fallback badge (e.g. "5K", "AC") for an item with no art, or whose art
-- failed to load.
local function createIconBadge(item, row, T)
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = T.iconPosition
	icon.Size = T.iconSize
	icon.BackgroundColor3 = item.iconColor or T.iconBackground
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
end

local function fetchFailed(status)
	return status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut
end

-- Adds the icon for `item` to `row`, styled by T.
function RowIcon.create(item, row, T)
	if not (item.iconAssetId and item.iconAssetId ~= "" and T.iconImageSize) then
		createIconBadge(item, row, T)
		return
	end

	-- Item art. The slot clips an oversized ImageLabel rather than sizing the
	-- label directly: ScaleType.Fit fits the whole source square, transparent
	-- padding included, so on its own it would shrink the art to a fraction of
	-- the slot. Blowing the label up by 1/iconImageCrop and clipping brings the
	-- padding back off-slot. A style whose art needs no zoom sets the crop to
	-- (1, 1).
	--
	-- The zoom is one shared ratio, identical on every row, so the size
	-- progression drawn into the art is preserved rather than doubled. It is a
	-- ratio, not a pixel rect, so it holds whatever resolution the art is
	-- uploaded at -- ImageRectOffset would not.
	local slot = Instance.new("Frame")
	slot.Name = "Icon"
	slot.AnchorPoint = Vector2.new(0, 0.5)
	slot.Position = T.iconImagePosition
	slot.Size = T.iconImageSize
	slot.BackgroundTransparency = 1
	slot.ClipsDescendants = true
	slot.Parent = row

	local icon = Instance.new("ImageLabel")
	icon.Name = "Image"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(1 / T.iconImageCrop.X, 1 / T.iconImageCrop.Y)
	icon.BackgroundTransparency = 1
	icon.Image = item.iconAssetId
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = slot

	-- If the art fails to download, swap the slot for the badge. Don't rely on
	-- this for an image pending or rejected in moderation: those can render as
	-- a blank square without the fetch ever failing.
	local function swapToBadge()
		if slot.Parent then
			slot:Destroy()
			createIconBadge(item, row, T)
		end
	end
	if fetchFailed(ContentProvider:GetAssetFetchStatus(item.iconAssetId)) then
		swapToBadge()
	elseif not icon.IsLoaded then
		local connection
		connection = ContentProvider:GetAssetFetchStatusChangedSignal(item.iconAssetId):Connect(function(status)
			if fetchFailed(status) then
				connection:Disconnect()
				swapToBadge()
			elseif status == Enum.AssetFetchStatus.Success then
				connection:Disconnect()
			end
		end)
		slot.Destroying:Connect(function()
			connection:Disconnect()
		end)
	end
end

return RowIcon
