return function(parent: Instance, path: table)
	local element = parent
	for _, child in path do
		element = element:FindFirstChild(child)

		if element == nil then
			return nil
		end
	end

	return element
end
