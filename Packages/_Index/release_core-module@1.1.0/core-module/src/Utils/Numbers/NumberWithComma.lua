return function(number)
	local formatted = tostring(number)
	local sep = ","
	local dp = string.find(formatted, "%.") or #formatted + 1

	for i = dp - 3, 1, -3 do
		formatted = formatted:sub(1, i - 1) .. sep .. formatted:sub(i)
	end

	return if #tostring(number) < 4 then number else formatted
end
