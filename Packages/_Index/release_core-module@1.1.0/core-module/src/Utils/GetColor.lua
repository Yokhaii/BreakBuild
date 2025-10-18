local Colors = table.freeze({
	["INFO"] = Color3.fromRGB(55, 94, 222),
	["SUCCESS"] = Color3.fromRGB(54, 212, 40),
	["ERROR"] = Color3.fromRGB(212, 40, 40),

	--|| Pets ||--

	-- Names
	["Normal"] = Color3.fromRGB(255, 255, 255),
	["Gold"] = Color3.fromRGB(237, 201, 116),
	["Rainbow"] = Color3.fromRGB(230, 72, 72),

	-- Rarities
	["Common"] = Color3.fromRGB(255, 255, 255),
	["Uncommon"] = Color3.fromRGB(87, 220, 87),
	["Rare"] = Color3.fromRGB(46, 102, 255),
	["Epic"] = Color3.fromRGB(170, 0, 255),
	["Legendary"] = Color3.fromRGB(255, 170, 0),
	["Mythical"] = Color3.fromRGB(227, 66, 44),
	["Exclusive"] = Color3.fromRGB(157, 19, 255),
})

return function(colorName: string)
	if not colorName then
		warn("[Core Module] - Missing or incorrect parameters.")
		return
	end

	return Colors[colorName]
end
