return function(t: { [any]: any }, predicate: (x: any) -> boolean)
	local filtered = {}
	for k, value in t do
		if predicate(value) then
			filtered[k] = value
		end
	end
	return filtered
end
