-- PurchaseReceiptService
-- The game's ONLY MarketplaceService.ProcessReceipt handler. Roblox honours a
-- single callback and a second assignment silently replaces the first, so
-- every Developer Product is granted here, branching on which config its id
-- belongs to. Started by DataSaveScript, which owns the save it relies on.
--
-- Each purchase is granted at most once. Granted PurchaseIds are kept in the
-- player's save (ProcessedReceipts), and PurchaseGranted is only returned
-- after a save containing both the grant and its PurchaseId succeeds. Any
-- other outcome returns NotProcessedYet, and Roblox re-sends the receipt later
-- (next purchase or next join), where the stored id prevents a double grant.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CashPackConfig = require(ReplicatedStorage:WaitForChild("CashPackConfig"))
local GemConfig = require(ReplicatedStorage:WaitForChild("GemConfig"))

local PurchaseReceiptService = {}

-- Roblox stops re-sending a receipt once it has been acknowledged, so only
-- recent ids need to be remembered.
local MAX_REMEMBERED_RECEIPTS = 100
-- A re-sent receipt often arrives while the player is still loading in.
local DATA_WAIT_TIMEOUT_SECONDS = 60

-- [Player] = { [PurchaseId] = os.time() it was granted }
local processedByPlayer = setmetatable({}, { __mode = "k" })
-- [productId] = { currency = "Cash" | "Gems", amount = number, itemId = string }
local grantsByProductId = {}
local savePlayer = nil

local function getCashValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Cash")
end

local function getBankedGemsValue(player)
	local gemData = player:FindFirstChild("GemData")
	return gemData and gemData:FindFirstChild("BankedGems")
end

local VALUE_GETTERS = {
	Cash = getCashValue,
	-- Bought gems go straight to the bank so paid currency is never at risk.
	Gems = getBankedGemsValue,
}

-- Warns rather than errors on a bad entry: DataSaveScript requires this
-- module, and a config typo must never stop saves from working.
local function registerProducts(config, currency, configName)
	for _, item in ipairs(config) do
		local productId = tonumber(item.productId) or 0
		if productId ~= 0 then
			if type(item.amount) ~= "number" or item.amount <= 0 then
				warn(("[PurchaseReceiptService] %s '%s' has no positive amount; it will not be granted."):format(configName, tostring(item.id)))
			elseif grantsByProductId[productId] then
				warn(("[PurchaseReceiptService] Product %d is used by both '%s' and '%s'; only the first is granted."):format(
					productId, grantsByProductId[productId].itemId, tostring(item.id)))
			else
				grantsByProductId[productId] = { currency = currency, amount = math.floor(item.amount), itemId = item.id }
			end
		end
	end
end

registerProducts(CashPackConfig, "Cash", "CashPackConfig")
registerProducts(GemConfig, "Gems", "GemConfig")

local function waitForLoadedData(player)
	local deadline = os.clock() + DATA_WAIT_TIMEOUT_SECONDS
	while player.Parent and not player:GetAttribute("DataLoaded") and os.clock() < deadline do
		task.wait(0.5)
	end
	return player.Parent ~= nil
		and player:GetAttribute("DataLoaded") == true
		and not player:GetAttribute("DataLoadFailed")
		and not player:GetAttribute("DataSessionLost")
		and processedByPlayer[player] ~= nil
end

local function processReceipt(receipt)
	local grant = grantsByProductId[receipt.ProductId]
	if not grant then
		-- Left unprocessed, not refused, so the purchase is honoured once a
		-- grant is defined for it.
		warn(("[PurchaseReceiptService] No grant defined for product %d (purchase %s)."):format(
			receipt.ProductId, tostring(receipt.PurchaseId)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not waitForLoadedData(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local processed = processedByPlayer[player]
	if not processed[receipt.PurchaseId] then
		local value = VALUE_GETTERS[grant.currency](player)
		if not value then
			warn(("[PurchaseReceiptService] %s has no %s value; purchase %s left unprocessed."):format(
				player.Name, grant.currency, tostring(receipt.PurchaseId)))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- No yield between the grant and recording it.
		value.Value += grant.amount
		processed[receipt.PurchaseId] = os.time()
	end

	if savePlayer(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- The grant and its id stay in memory and go out with the next successful
	-- save, so the re-sent receipt will find the id and not grant twice.
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Called by DataSaveScript after a successful load.
function PurchaseReceiptService.Resolve(player, savedData)
	local processed = {}
	local saved = type(savedData) == "table" and savedData.ProcessedReceipts
	if type(saved) == "table" then
		for purchaseId, grantedAt in pairs(saved) do
			if type(purchaseId) == "string" then
				processed[purchaseId] = tonumber(grantedAt) or 0
			end
		end
	end
	processedByPlayer[player] = processed
end

-- Called by DataSaveScript when building the save payload.
function PurchaseReceiptService.Serialize(player)
	local processed = processedByPlayer[player]
	if not processed then
		return {}
	end

	local purchaseIds = {}
	for purchaseId in pairs(processed) do
		table.insert(purchaseIds, purchaseId)
	end
	if #purchaseIds > MAX_REMEMBERED_RECEIPTS then
		table.sort(purchaseIds, function(a, b)
			return processed[a] > processed[b]
		end)
		for index = MAX_REMEMBERED_RECEIPTS + 1, #purchaseIds do
			processed[purchaseIds[index]] = nil
		end
	end

	return table.clone(processed)
end

-- `saveFunction(player) -> boolean` must persist the player's full payload,
-- including Serialize(player), and return true only when the write succeeded.
function PurchaseReceiptService.Start(saveFunction)
	savePlayer = saveFunction
	MarketplaceService.ProcessReceipt = processReceipt
end

return PurchaseReceiptService
