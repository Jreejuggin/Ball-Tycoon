-- CashFormat
-- Shared number formatting for currency displays. withCommas/toPriceText give
-- full amounts, e.g. 50000 -> "$50,000" (MiddleShops configs and price
-- labels). abbreviate gives the short HUD form for both Cash and Gems.

local CashFormat = {}

local SUFFIXES = { "K", "M", "B" }

-- 1234567 -> "1.23M", always two decimals so the HUD stays a fixed width as
-- the number grows. Under 1,000 it returns the plain number. No currency
-- symbol: callers add one if they want it.
function CashFormat.abbreviate(amount)
	if amount < 1000 then
		return tostring(amount)
	end

	local value = amount
	local suffixIndex = 0
	while value >= 1000 and suffixIndex < #SUFFIXES do
		value = value / 1000
		suffixIndex += 1
	end

	return string.format("%.2f%s", value, SUFFIXES[suffixIndex])
end

function CashFormat.withCommas(amount)
	local formatted = tostring(math.floor(amount))
	local result = formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	result = result:gsub("^,", "")
	return result
end

function CashFormat.toPriceText(amount)
	return "$" .. CashFormat.withCommas(amount)
end

return CashFormat
