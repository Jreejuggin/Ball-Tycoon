-- Prevent Roblox's automatic Humanoid nameplate from displaying "BuyPad"
-- above legacy dropper purchase pads. Custom price/dropper BillboardGuis do not
-- require a Humanoid, so removing these objects does not affect purchases or UI.

local Workspace = game:GetService("Workspace")

local function isDropperBuyPadHumanoid(instance)
	if not instance:IsA("Humanoid") then
		return false
	end

	local buyPad = instance.Parent
	local slot = buyPad and buyPad.Parent
	local machineFolder = slot and slot.Parent

	return buyPad ~= nil
		and buyPad:IsA("Model")
		and buyPad.Name == "BuyPad"
		and machineFolder ~= nil
		and (machineFolder.Name == "DropperSlots" or machineFolder.Name == "DropperSlots2")
end

local function removeLegacyNameDisplay(instance)
	if not isDropperBuyPadHumanoid(instance) then
		return
	end

	-- Suppress the nameplate immediately, then remove the unused Humanoid.
	instance.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	instance.NameDisplayDistance = 0
	instance.HealthDisplayDistance = 0
	instance:Destroy()
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	removeLegacyNameDisplay(descendant)
end

Workspace.DescendantAdded:Connect(removeLegacyNameDisplay)
