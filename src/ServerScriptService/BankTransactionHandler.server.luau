--[[
	BankTransactionHandler
	Server-authoritative deposit/withdraw between a player's spendable Cash
	and their safe BankedCash. The client only ever requests an action and
	an amount; this script is the sole source of truth for whether it's
	valid and what the resulting balances are.

	Design:
	- Deposits are free and instant (encourages actually using the bank).
	- Withdrawals have a small fee and a short cooldown, so banking isn't
	  a zero-cost way to dodge a PvP loss mechanic the instant it's needed.
	- BankedCash lives outside leaderstats (in a BankData folder) since it
	  isn't meant to show on the default Roblox leaderboard.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BankTransactionEvent = ReplicatedStorage:WaitForChild("BankTransactionEvent")

local WITHDRAW_FEE_RATE = 0.03 -- 3% fee on withdrawals only
local WITHDRAW_COOLDOWN_SECONDS = 5

-- Per-player cooldown tracking. Cleared on leave to avoid a slow memory leak.
local lastWithdrawTime = {}

local function getBalances(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	local bankData = player:FindFirstChild("BankData")
	local bankedCash = bankData and bankData:FindFirstChild("BankedCash")
	return cash, bankedCash
end

local function sanitizeAmount(rawAmount, maxAvailable)
	if typeof(rawAmount) ~= "number" or rawAmount ~= rawAmount then -- rejects NaN
		return nil
	end
	local amount = math.floor(rawAmount)
	if amount <= 0 then
		return nil
	end
	return math.min(amount, maxAvailable)
end

local function handleDeposit(player, cash, bankedCash, rawAmount)
	local amount = sanitizeAmount(rawAmount, cash.Value)
	if not amount then
		BankTransactionEvent:FireClient(player, false, "Invalid deposit amount.")
		return
	end

	cash.Value -= amount
	bankedCash.Value += amount
end

local function handleWithdraw(player, cash, bankedCash, rawAmount)
	local now = os.clock()
	local lastTime = lastWithdrawTime[player.UserId]
	if lastTime and (now - lastTime) < WITHDRAW_COOLDOWN_SECONDS then
		local remaining = math.ceil(WITHDRAW_COOLDOWN_SECONDS - (now - lastTime))
		BankTransactionEvent:FireClient(player, false, ("Wait %ds before withdrawing again."):format(remaining))
		return
	end

	local amount = sanitizeAmount(rawAmount, bankedCash.Value)
	if not amount then
		BankTransactionEvent:FireClient(player, false, "Invalid withdrawal amount.")
		return
	end

	local fee = math.floor(amount * WITHDRAW_FEE_RATE)
	local amountAfterFee = amount - fee

	bankedCash.Value -= amount
	cash.Value += amountAfterFee
	lastWithdrawTime[player.UserId] = now
end

BankTransactionEvent.OnServerEvent:Connect(function(player, action, rawAmount)
	local cash, bankedCash = getBalances(player)
	if not cash or not bankedCash then
		-- Data hasn't loaded yet, or something is misconfigured. Fail closed.
		return
	end

	if action == "Deposit" then
		handleDeposit(player, cash, bankedCash, rawAmount)
	elseif action == "Withdraw" then
		handleWithdraw(player, cash, bankedCash, rawAmount)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastWithdrawTime[player.UserId] = nil
end)