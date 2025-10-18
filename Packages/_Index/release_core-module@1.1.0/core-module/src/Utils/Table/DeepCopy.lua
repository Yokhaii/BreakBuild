local function DeepCopy(template: { [any]: any })
	local new = {}
	for index, value in template do
		if type(value) == "table" then
			new[index] = DeepCopy(value)
		else
			new[index] = value
		end
	end
	return new
end

return DeepCopy
