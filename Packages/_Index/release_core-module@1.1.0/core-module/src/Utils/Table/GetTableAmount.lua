return function(T: { [any]: any }): number
	local c = 0
	for _, _ in T do
		c += 1
	end
	return c
end
