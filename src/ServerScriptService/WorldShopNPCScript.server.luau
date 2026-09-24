--[[
	WorldShopNPCScript
	Connects every shopkeeper NPC's ProximityPrompt to the OpenWorldShopEvent.

	Data-driven / scalable: instead of hardcoding 5 separate connections,
	this scans Workspace.MiddleShops for any Model named "<ShopId>Keeper"
	containing a ProximityPrompt named "InteractPrompt", and wires it up
	automatically. Adding a 6th shop later just means naming its NPC
	Model "<NewShopId>Keeper" -- no script changes needed.

	This is purely a "show the offerings" panel opener. No currency or
	inventory changes happen here, so there is nothing unsafe about
	firing this per player -- it's read-only. If/when real purchasing
	is added, that logic MUST live in a server script (never trust the
	client to report what it bought or how much it paid).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldShopConfig = require(ReplicatedStorage:WaitForChild("WorldShopConfig"))
local OpenWorldShopEvent = ReplicatedStorage:WaitForChild("OpenWorldShopEvent")

local middleShops = Workspace:WaitForChild("MiddleShops")

local KEEPER_SUFFIX = "Keeper"

local function trySetupNPC(model)
	if not model:IsA("Model") then
		return
	end

	-- Derive the shop id from the model name, e.g. "BallShopKeeper" -> "BallShop"
	local name = model.Name
	if name:sub(-#KEEPER_SUFFIX) ~= KEEPER_SUFFIX then
		return
	end
	local shopId = name:sub(1, #name - #KEEPER_SUFFIX)

	local shopData = WorldShopConfig.Shops[shopId]
	if not shopData then
		warn(("WorldShopNPCScript: no WorldShopConfig entry found for shop id '%s' (from NPC '%s')"):format(shopId, name))
		return
	end

	local body = model.PrimaryPart or model:FindFirstChild("Body")
	local prompt = body and body:FindFirstChild("InteractPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end

	prompt.Triggered:Connect(function(player)
		OpenWorldShopEvent:FireClient(player, shopId)
	end)
end

-- Wire up any NPCs that already exist in the workspace.
for _, structureModel in ipairs(middleShops:GetChildren()) do
	for _, descendant in ipairs(structureModel:GetChildren()) do
		trySetupNPC(descendant)
	end
end

-- Also handle NPCs added later (e.g. if a new shop is built while the server is running).
middleShops.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") then
		trySetupNPC(descendant)
	end
end)