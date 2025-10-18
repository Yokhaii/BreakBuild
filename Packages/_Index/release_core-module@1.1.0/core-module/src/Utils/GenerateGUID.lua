local HttpService = game:GetService("HttpService")

return function(ids: number)
	local UUID = ""

	for _ = 0, ids - 1 do
		UUID = UUID .. HttpService:GenerateGUID(false)
	end

	return UUID
end
