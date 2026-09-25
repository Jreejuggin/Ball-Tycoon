-- WorkerGiftCooldownService
-- Owns the Daily Worker Gifts claim cooldown so DataSaveScript only has to hand
-- it the raw DataStore result and ask for a number back at save time.
--
-- Mirrors TutorialProgressService's three-way DataStore outcome handling:
--   success = true,  savedData = nil    -> brand-new player, never claimed
--   success = true,  savedData = table  -> returning player, restore timestamp
--   success = false                     -> transient load failure, do nothing
-- A failed load must never look like "no cooldown active." IsAvailable and
-- GetRemainingSeconds both refuse outright while DataLoadFailed is set,
-- regardless of what the (possibly stale or unseeded) timestamp attribute says.

local WorkerGiftCooldownService = {}

WorkerGiftCooldownService.COOLDOWN_SECONDS = 24 * 60 * 60

-- Unix timestamp (os.time()) of the player's last successful claim, or 0 if
-- they have never claimed. Mirrored onto the Player so other server systems
-- can read it without a module dependency.
local LAST_CLAIM_ATTR = "LastWorkerGiftClaim"

-- Called once per join, before DataLoaded is set, so every other system can
-- keep using DataLoaded as the single "player state is ready" barrier.
function WorkerGiftCooldownService.Resolve(player, loadSucceeded, savedData)
	if not loadSucceeded then
		-- Fail safe. Leave the attribute unset rather than guessing 0 ("never
		-- claimed"); IsAvailable/GetRemainingSeconds already refuse to grant
		-- anything while DataLoadFailed is set, independent of this value.
		return
	end

	local lastClaim = 0
	if type(savedData) == "table" then
		lastClaim = tonumber(savedData.LastWorkerGiftClaim) or 0
	end
	player:SetAttribute(LAST_CLAIM_ATTR, lastClaim)
end

function WorkerGiftCooldownService.Serialize(player)
	return tonumber(player:GetAttribute(LAST_CLAIM_ATTR)) or 0
end

function WorkerGiftCooldownService.IsAvailable(player)
	if player:GetAttribute("DataLoadFailed") then
		return false
	end

	local lastClaim = tonumber(player:GetAttribute(LAST_CLAIM_ATTR)) or 0
	return (os.time() - lastClaim) >= WorkerGiftCooldownService.COOLDOWN_SECONDS
end

-- Seconds until the next claim unlocks. 0 means available now. Reports a full
-- cooldown (rather than 0) while DataLoadFailed is set, so a countdown UI
-- driven by this never displays "ready" off the back of a load failure.
function WorkerGiftCooldownService.GetRemainingSeconds(player)
	if player:GetAttribute("DataLoadFailed") then
		return WorkerGiftCooldownService.COOLDOWN_SECONDS
	end

	local lastClaim = tonumber(player:GetAttribute(LAST_CLAIM_ATTR)) or 0
	local elapsed = os.time() - lastClaim
	return math.max(0, WorkerGiftCooldownService.COOLDOWN_SECONDS - elapsed)
end

-- Records a successful claim. The claim flow (server-validated) is the only
-- intended caller; nothing here decides eligibility.
function WorkerGiftCooldownService.MarkClaimed(player)
	if player:GetAttribute("DataLoadFailed") then
		warn("Refused to record a Worker Gift claim for " .. player.Name .. " because their data did not load.")
		return false
	end

	player:SetAttribute(LAST_CLAIM_ATTR, os.time())
	return true
end

-- Dev reset. Server-only by construction (nothing on the client can reach a
-- ModuleScript in ServerScriptService); call it from the Studio command bar as
-- require(game.ServerScriptService.WorkerGiftCooldownService).Reset(game.Players.PlayerName)
-- to re-test the claim flow repeatedly without waiting 24 hours.
function WorkerGiftCooldownService.Reset(player)
	if player:GetAttribute("DataLoadFailed") then
		warn("Refused to reset Worker Gift cooldown for " .. player.Name .. " because their data did not load.")
		return false
	end

	player:SetAttribute(LAST_CLAIM_ATTR, 0)
	return true
end

return WorkerGiftCooldownService
