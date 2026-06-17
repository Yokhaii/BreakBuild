local images = {}

local function copy(source, destination, cb)
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy(value, destination, cb)
		else
			destination[key] = cb(value)
		end
	end
end

local function recursiveAdd(folder, tab)
	for _, file in folder:GetChildren() do
		if file:IsA("Folder") then
			recursiveAdd(file, tab)
		elseif file:IsA("ModuleScript") then
			local _images = require(file)

			copy(_images, tab, function(value)
				return "rbxassetid://" .. value
			end)
		end
	end
end

recursiveAdd(script, images)

return images
