local Abbreviate = require(script.Parent.Abbreviate)
local MaxNumber = Abbreviate:stringToNumber("1k")

return function(Value)
	local R
	if Value >= MaxNumber then
		R = Abbreviate:numberToString(Value)
	else
		R = Abbreviate.commify(Value)
	end
	return R
end
