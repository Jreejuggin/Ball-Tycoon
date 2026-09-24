-- StructureGhostPreviewScript (LocalScript)
-- Shows a local-only "ghost" preview of the current not-yet-purchased
-- Home Centre stage when the plot OWNER approaches the single central
-- StructureBuyPad. CurrentStructure is replicated by the server, so retired
-- per-stage pad positions are never used. Nobody else sees this: it sets the
-- parts' Transparency directly from a LocalScript, which is a per-client
-- -only override -- property writes made by a LocalScript never replicate
-- back to the server or to other players. Collision is untouched here on
-- purpose -- unpurchased structure pieces are already non-colliding
-- (CanCollide = false) by design, so walkability is already guaranteed; this
-- script only ever adjusts visibility.
--
-- NOTE: this deliberately does NOT use BasePart.LocalTransparencyModifier.
-- That property's formula is:
--   Displayed = Transparency + ((1 - Transparency) * LocalTransparencyModifier)
-- Since these parts sit at Transparency = 1 while hidden, the (1 - Transparency)
-- term is always 0, so no modifier value can ever make them visible -- it can
-- only ever push transparency UP from a visible base, not reveal something
-- that starts fully invisible. A direct Transparency write doesn't have that
-- limitation and is just as local-only.
--
-- IMPORTANT: a part must never be reverted back to hidden once its slot has
-- actually been purchased. When a slot is bought, the server makes that part
-- genuinely visible to everyone (a real replicated change). If our own revert
-- logic doesn't check for that and blindly hides anything that drops out of
-- ghost range, it will stomp the server's correct update right after
-- purchase -- but ONLY on the buyer's own client, since nobody else ever had
-- a local override. Every revert path below re-checks the slot's live
-- Activated value first, specifically to avoid that.
--
-- Fully plot-agnostic: it finds whichever plot (P1-P10) the local player
-- owns and reads that plot's Home Centre StructureSlots folder dynamically.
-- This one script covers all 10 plots and respects the Home Centre unlock.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local GHOST_TRANSPARENCY = 0.6 -- matches the ghost transparency used elsewhere (dropper/worker buy pads)
local HIDDEN_TRANSPARENCY = 1 -- the base, fully-hidden state these parts sit at pre-purchase
local TRIGGER_RADIUS = 10 -- studs (~10 feet at Roblox's ~1 stud = 1 foot scale)

-- Cache of tagged parts per StructureGroup, keyed to whichever plot we most
-- recently resolved -- avoids rescanning the whole plot every 0.1s.
local cachedPlot = nil
local partsCache = {}

-- Maps a currently-ghosted part -> the Activated BoolValue of the slot that
-- owns it. Keeping this reference lets every revert path check FRESH
-- purchase state before touching Transparency, instead of just trusting
-- stale set-membership from a previous loop pass.
local ghostedParts = {}

local function getTargetParts(plot, groupName)
	if cachedPlot ~= plot then
		partsCache = {}
		cachedPlot = plot
	end
	if not partsCache[groupName] then
		local parts = {}
		for _, desc in ipairs(plot:GetDescendants()) do
			if desc:IsA("BasePart") and desc:GetAttribute("StructureGroup") == groupName then
				table.insert(parts, desc)
			end
		end
		partsCache[groupName] = parts
	end
	return partsCache[groupName]
end

local function findOwnedPlot()
	for i = 1, 10 do
		local plot = workspace:FindFirstChild("P" .. i)
		if plot and plot:GetAttribute("Owner") == player.UserId then
			return plot
		end
	end
	return nil
end

-- Resolve the one slot represented by the new central buy pad. The server
-- writes CurrentStructure, so the client never guesses which stage is active.
local function getSlotForGroup(structureSlots, groupName)
	for _, slot in ipairs(structureSlots:GetChildren()) do
		local groupValue = slot:FindFirstChild("StructureGroup")
		if groupValue and groupValue.Value == groupName then
			return slot
		end
	end
	return nil
end

-- Only reverts a part if its slot is confirmed STILL unpurchased right now.
-- If it's been purchased since we last checked, we leave it alone entirely --
-- the server has already made it genuinely visible, and this client should
-- see that real state, not a stale local override.
local function revertIfStillUnpurchased(part, activated)
	if not (activated and activated.Value) then
		part.Transparency = HIDDEN_TRANSPARENCY
	end
end

local function clearAllGhosts()
	for part, activated in pairs(ghostedParts) do
		revertIfStillUnpurchased(part, activated)
	end
	table.clear(ghostedParts)
end

while true do
	task.wait(0.1)

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		clearAllGhosts()
		continue
	end

	local plot = findOwnedPlot()
	if not plot then
		clearAllGhosts()
		continue
	end

	local centreSlots = plot:FindFirstChild("CentreSlots")
	local homeCentre = centreSlots and centreSlots:FindFirstChild("Centre02_Home")
	local homeActivated = homeCentre and homeCentre:FindFirstChild("Activated")
	local structureSlots = homeCentre and homeCentre:FindFirstChild("StructureSlots")
	local centralPad = homeCentre and homeCentre:FindFirstChild("StructureBuyPad")
	if not homeActivated or not homeActivated.Value or not structureSlots or not centralPad then
		clearAllGhosts()
		continue
	end

	local groupName = centralPad:GetAttribute("CurrentStructure")
	local slot = type(groupName) == "string"
		and groupName ~= ""
		and getSlotForGroup(structureSlots, groupName)
	local slotPad = slot and slot:FindFirstChild("BuyPad")
	local activated = slotPad and slotPad:FindFirstChild("Activated")
	local nowGhosted = {}

	-- Preview only the stage currently advertised by the central pad, and
	-- measure approach distance from that same pad rather than retired pads.
	if activated and not activated.Value
		and (hrp.Position - centralPad.Position).Magnitude <= TRIGGER_RADIUS then
		for _, part in ipairs(getTargetParts(plot, groupName)) do
			part.Transparency = GHOST_TRANSPARENCY
			part.CanCollide = false
			nowGhosted[part] = activated
		end
	end

	-- Revert anything that was ghosted last pass but no longer qualifies --
	-- guarded by a fresh purchase-state check, so a just-purchased part is
	-- never touched (see revertIfStillUnpurchased above).
	for part, activated in pairs(ghostedParts) do
		if not nowGhosted[part] then
			revertIfStillUnpurchased(part, activated)
		end
	end

	ghostedParts = nowGhosted
end