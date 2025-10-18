local Adjustment = {}

Adjustment.Compress = function(Number: number): number
	return math.log10(Number + 1) * (2 ^ 63) / 308.254
end

Adjustment.Decompress = function(Number: number): number
	return (10 ^ (Number / (2 ^ 63) * 308.254)) - 1
end

return Adjustment
