-- ArrowPreview
-- TEMPORARY, Studio-only preview for ArrowIndicator + ArrowTrail. Points a
-- hovering marker at your own plot's first dropper BuyPad and runs a flowing
-- chevron trail from you to it, so both can be eyeballed in Studio before
-- Phase 5 wires them into the actual tutorial flow. Delete this whole file
-- once Phase 5 lands -- it is not part of the real tutorial, it only exists
-- to preview the modules early.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

local ArrowIndicator = require(ReplicatedStorage:WaitForChild("ArrowIndicator"))
local ArrowTrail = require(ReplicatedStorage:WaitForChild("ArrowTrail"))

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
	local trail = ArrowTrail.new(buyPad)
	print("[ArrowPreview] Marker + trail pointing at " .. buyPad:GetFullName() .. " -- delete this file once Phase 5 lands.")

	-- The trail follows Players.LocalPlayer itself, so respawning is fine and
	-- there's no Skip/step-advance wiring here -- that's what Phase 5 builds.
end)
