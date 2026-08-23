--!strict

--[[
	This loader is NOT necessary!
	If you don't want to use the loader:
	
	* Move every single folder to their respective Roblox service.
		- ReplicatedStorage folder -> ReplicatedStorage
		- StarterGUI folder -> StarterGui
		- StarterPlayerScripts folder -> StarterPlayer.StarterPlayerScripts
	* Then, ungroup these root folders (Ctrl + U or right click then click ungroup)
	* Now, you can safely delete the MusicGUI_Loader and have everything still work (if you put everything in their right spot!)

]]

----- [[ SERVICES ]] -----

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayerScripts = game:GetService("StarterPlayer").StarterPlayerScripts

----- [[ VARIABLES ]] -----

local ReplicatedStorage_MoverFolder = script.ReplicatedStorage
local StarterGUI_MoverFolder = script.StarterGUI
local StarterPlayerScripts_MoverFolder = script.StarterPlayer.StarterPlayerScripts


local function transferFolderChildrenToDestination(folder: Folder, destination: Instance)
	for i, child in folder:GetChildren() do
		local directoryWithSameNameAtDest = destination:FindFirstChild(child.Name)
		
		if directoryWithSameNameAtDest and directoryWithSameNameAtDest:IsA("Folder") then
			-- There is a directory in destination with the same name as the child we are currently moving, so we should move the child into that directory.
			if child:IsA("Folder") then
				transferFolderChildrenToDestination(child, directoryWithSameNameAtDest)
			else
				child.Parent = directoryWithSameNameAtDest
			end
		else
			child.Parent = destination
		end

	end
end

local function load()
	transferFolderChildrenToDestination(ReplicatedStorage_MoverFolder, ReplicatedStorage)
	
	transferFolderChildrenToDestination(StarterGUI_MoverFolder, StarterGui)
	
	transferFolderChildrenToDestination(StarterPlayerScripts_MoverFolder, StarterPlayerScripts)
end

load()