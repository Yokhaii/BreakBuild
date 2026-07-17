--[[
	Tool Generator Plugin
	Creates Minecraft-style tools (Pickaxe, Shovel, Sword, Axe) from small cube parts.

	INSTALLATION:
	1. In Roblox Studio, go to Plugins > Plugins Folder
	2. Copy this file into that folder
	3. Restart Roblox Studio
	4. You'll see "Tool Generator" buttons in the Plugins tab

	USAGE:
	1. Click a tool button (Pickaxe, Shovel, Sword, Axe)
	2. A model made of small cubes will be created at the origin (or selected part position)
	3. The model is placed in Workspace for preview — move it to ReplicatedStorage/Tools when ready

	CUSTOMIZATION:
	- PIXEL_SIZE: size of each cube (default 0.25 studs)
	- Tool grids use characters to define materials:
	  "H" = Handle (brown wood)
	  "B" = Blade (grey stone)
	  "." = Empty (no part)
]]

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local PLUGIN_NAME = "Tool Generator"
local PIXEL_SIZE = 0.25

-- Material color definitions
local MATERIALS = {
	H = { -- Handle
		Color = Color3.fromRGB(139, 90, 43),
		Material = Enum.Material.Wood,
		Name = "Handle",
	},
	B = { -- Blade (stone)
		Color = Color3.fromRGB(158, 158, 158),
		Material = Enum.Material.Slate,
		Name = "Blade",
	},
	I = { -- Iron blade
		Color = Color3.fromRGB(200, 200, 210),
		Material = Enum.Material.Metal,
		Name = "IronBlade",
	},
	D = { -- Diamond blade
		Color = Color3.fromRGB(80, 220, 220),
		Material = Enum.Material.Neon,
		Name = "DiamondBlade",
	},
	G = { -- Gold blade
		Color = Color3.fromRGB(255, 215, 0),
		Material = Enum.Material.Metal,
		Name = "GoldBlade",
	},
}

-- Tool pixel grids (read top-to-bottom, left-to-right)
-- Each row is a string, each character is a pixel
-- Tools are defined in a 2D side view (like Minecraft inventory icons)

local TOOL_GRIDS = {
	Pickaxe = {
		grid = {
			"BBBBBBBBBBB",
			"BB.......BB",
			"B.........B",
			".....H.....",
			".....H.....",
			".....H.....",
			".....H.....",
			".....H.....",
			".....H.....",
			".....H.....",
			".....H.....",
			".....H.....",
			".....H.....",
			".....H.....",
		},
		description = "A stone pickaxe",
	},

	Axe = {
		grid = {
			"...BBBBB",
			"..BBBBBB",
			"..BBBBBB",
			"..BBBBBB",
			"...BBBBB",
			"....HBBB",
			"....HBB.",
			"....H...",
			"....H...",
			"....H...",
			"....H...",
			"....H...",
			"....H...",
			"....H...",
			"....H...",
			"....H...",
		},
		description = "A stone axe",
	},

	Sword = {
		grid = {
			"...B...",
			"...B...",
			"...B...",
			"...B...",
			"...B...",
			"...B...",
			"...B...",
			"...B...",
			"..BBB..",
			"..BHB..",
			"...H...",
			"...H...",
			"...H...",
			"...H...",
			"...H...",
			"...H...",
		},
		description = "A stone sword",
	},

	Shovel = {
		grid = {
			"..BBBBB..",
			".BBBBBBB.",
			"BBBBBBBBB",
			"BBBBBBBBB",
			"BBBBBBBBB",
			".BBBBBBB.",
			"..BBBBB..",
			"....H....",
			"....H....",
			"....H....",
			"....H....",
			"....H....",
			"....H....",
			"....H....",
			"....H....",
			"....H....",
		},
		description = "A stone shovel",
	},
}

-- Create toolbar and buttons
local toolbar = plugin:CreateToolbar(PLUGIN_NAME)

local buttons = {}
for toolName, _ in pairs(TOOL_GRIDS) do
	buttons[toolName] = toolbar:CreateButton(
		toolName,
		"Generate a " .. toolName .. " model",
		"rbxassetid://6031071053"
	)
end

local allButton = toolbar:CreateButton(
	"All Tools",
	"Generate all tool models side by side",
	"rbxassetid://6031071053"
)

-- Get spawn position (selected part or origin)
local function getSpawnPosition()
	local selected = Selection:Get()
	if selected and #selected > 0 then
		local obj = selected[1]
		if obj:IsA("BasePart") then
			return obj.Position + Vector3.new(0, 5, 0)
		elseif obj:IsA("Model") and obj.PrimaryPart then
			return obj.PrimaryPart.Position + Vector3.new(0, 5, 0)
		end
	end
	return Vector3.new(0, 5, 0)
end

-- Generate a tool model from a grid definition
local function generateTool(toolName, gridData, spawnPosition)
	ChangeHistoryService:SetWaypoint("Before Tool Generation")

	local grid = gridData.grid
	local model = Instance.new("Model")
	model.Name = toolName

	local rows = #grid
	local cols = 0
	for _, row in ipairs(grid) do
		cols = math.max(cols, #row)
	end

	local parts = {}
	local primaryPart = nil

	for rowIdx, row in ipairs(grid) do
		for colIdx = 1, #row do
			local char = row:sub(colIdx, colIdx)
			local matDef = MATERIALS[char]

			if matDef then
				local part = Instance.new("Part")
				part.Name = matDef.Name .. "_" .. rowIdx .. "_" .. colIdx
				part.Size = Vector3.new(PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE)
				part.Anchored = true
				part.CanCollide = false
				part.Color = matDef.Color
				part.Material = matDef.Material
				part.TopSurface = Enum.SurfaceType.Smooth
				part.BottomSurface = Enum.SurfaceType.Smooth

				-- Position: X = column, Y = inverted row (so top of grid = top of model)
				local x = (colIdx - 1) * PIXEL_SIZE
				local y = (rows - rowIdx) * PIXEL_SIZE
				local z = 0

				part.Position = spawnPosition + Vector3.new(
					x - (cols * PIXEL_SIZE / 2),
					y - (rows * PIXEL_SIZE / 2),
					z
				)

				part.Parent = model
				table.insert(parts, part)

				if not primaryPart then
					primaryPart = part
				end
			end
		end
	end

	if primaryPart then
		model.PrimaryPart = primaryPart
	end

	-- Weld all parts together
	for i = 2, #parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = primaryPart
		weld.Part1 = parts[i]
		weld.Parent = primaryPart
	end

	model.Parent = workspace

	ChangeHistoryService:SetWaypoint("After Tool Generation: " .. toolName)

	return model
end

-- Connect individual tool buttons
for toolName, button in pairs(buttons) do
	button.Click:Connect(function()
		local spawnPos = getSpawnPosition()
		local model = generateTool(toolName, TOOL_GRIDS[toolName], spawnPos)
		Selection:Set({model})
		print(string.format("[ToolGenerator] Created %s (%d parts)", toolName, #model:GetChildren()))
	end)
end

-- Connect "All Tools" button
allButton.Click:Connect(function()
	local spawnPos = getSpawnPosition()
	local models = {}
	local offset = 0

	for toolName, gridData in pairs(TOOL_GRIDS) do
		local pos = spawnPos + Vector3.new(offset, 0, 0)
		local model = generateTool(toolName, gridData, pos)
		table.insert(models, model)
		offset = offset + 4
	end

	Selection:Set(models)
	print(string.format("[ToolGenerator] Created all %d tools", #models))
end)

print("[ToolGenerator] Plugin loaded! Click a tool button to generate it.")
