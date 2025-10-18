local Utils = {}

local function addDescendantsToTable(parentFolder, parentTable)
	for _, child in ipairs(parentFolder:GetChildren()) do
		if child:IsA("Folder") then
			parentTable[child.Name] = {}
			addDescendantsToTable(child, parentTable[child.Name])
		elseif child:IsA("ModuleScript") then
			parentTable[child.Name] = require(child)
		end
	end
end

addDescendantsToTable(script, Utils)

return Utils
