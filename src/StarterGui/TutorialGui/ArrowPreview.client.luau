-- ArrowPreview
-- TEMPORARY, Studio-only preview for ArrowIndicator (Phase 4). Points a
-- single arrow at your own plot's first dropper BuyPad so the real module
-- can be eyeballed in Studio before Phase 5 wires it into the actual
-- tutorial flow. Delete this whole file once Phase 5 lands -- it is not
-- part of the real tutorial, it only exists to preview the module early.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

local ArrowIndicator = require(ReplicatedStorage:WaitForChild("ArrowIndicator"))

local player = Players.LocalPlayer

local function waitForOwnedPlot()
	while player.Parent do
		local plotName = player:GetAttribute("AssignedPlotName")
		if type(plotName) == "string" then
			local plot = workspace:FindFirstChild(plotName)
			if plot then
				return plot
			end
		end
		task.wait(0.25)
	end
	return nil
end

task.spawn(function()
	local plot = waitForOwnedPlot()
	if not plot then
		return
	end

	local dropperSlots = plot:WaitForChild("DropperSlots", 5)
	local slot1 = dropperSlots and dropperSlots:WaitForChild("Slot1", 5)
	local buyPad = slot1 and slot1:WaitForChild("BuyPad", 5)
	if not buyPad then
		warn("[ArrowPreview] Couldn't find DropperSlots/Slot1/BuyPad under " .. plot:GetFullName())
		return
	end

	local arrow = ArrowIndicator.new(buyPad)
	print("[ArrowPreview] Pointing at " .. buyPad:GetFullName() .. " -- delete this file once Phase 5 lands.")

	-- Kept alive for the rest of the session; there's no Skip/step-advance
	-- wiring here since that's what Phase 5 actually builds.
end)
