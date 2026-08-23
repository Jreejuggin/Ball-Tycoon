-- CashFormat
-- Shared helper for displaying in-game Cash amounts with comma separators,
-- e.g. 50000 -> "$50,000". Used by MiddleShops configs/price labels and the
-- purchase result messages.

local CashFormat = {}

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
