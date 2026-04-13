--[[
	Blueprint Scanner Plugin
	Scans the BuildingArea and generates a blueprint definition

	INSTALLATION:
	1. Save this file as BlueprintScanner.lua
	2. In Roblox Studio, go to Plugins > Plugins Folder
	3. Copy this file into that folder
	4. Restart Roblox Studio
	5. You'll see "Blueprint Scanner" in the Plugins tab

	USAGE:
	1. Build your blueprint in the BuildingArea (only the blueprint blocks)
	2. Click "Scan Blueprint" in the toolbar
	3. Enter the blueprint name when prompted
	4. The definition will be printed to Output and copied to clipboard
]]

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local StudioService = game:GetService("StudioService")

-- Constants
local DEFAULT_GRID_SIZE = 4
local SMALL_GRID_SIZE = 2  -- For 2x2x2 blocks like SprucePlank
local PLUGIN_NAME = "Blueprint Scanner"

-- Create toolbar and button
local toolbar = plugin:CreateToolbar(PLUGIN_NAME)
local scanButton = toolbar:CreateButton(
	"Scan Blueprint",
	"Scan the BuildingArea and generate blueprint definition",
	"rbxassetid://6031071053" -- Blueprint icon
)

-- Find BuildingArea in workspace
local function findBuildingArea()
	local buildingZone = workspace:FindFirstChild("BuildingZone")
	if not buildingZone then
		warn("[BlueprintScanner] BuildingZone not found in workspace")
		return nil
	end

	local buildingArea = buildingZone:FindFirstChild("BuildingArea")
	if not buildingArea then
		warn("[BlueprintScanner] BuildingArea not found in BuildingZone")
		return nil
	end

	return buildingArea, buildingZone
end

-- Get the position of a block (handles both Models and Parts)
local function getBlockPosition(block)
	if block:IsA("Model") and block.PrimaryPart then
		return block.PrimaryPart.Position
	elseif block:IsA("BasePart") then
		return block.Position
	end
	return nil
end

-- Get block type from the block
-- Block names follow the pattern: "ItemName_Placed"
local function getBlockType(block)
	-- Check for ItemName StringValue first (if added)
	local itemNameValue = block:FindFirstChild("ItemName")
	if itemNameValue and itemNameValue:IsA("StringValue") then
		return itemNameValue.Value
	end

	-- Extract from block name (format: "ItemName_Placed")
	local name = block.Name

	-- Remove common suffixes
	name = name:gsub("_Placed$", "")
	name = name:gsub("_Block$", "")

	return name
end

-- Get the building area origin (floor level)
local function getBuildingAreaOrigin(buildingArea)
	local areaPosition = buildingArea.Position
	-- Origin is at floor level (Y - 32 for a 64-stud tall area)
	return Vector3.new(areaPosition.X, areaPosition.Y - 32, areaPosition.Z)
end

-- Scan all placed blocks in the BuildingZone
-- Only scans direct children that have a BlockId (actual placed blocks)
local function scanBlocks(buildingZone, buildingArea)
	local blocks = {}
	local areaOrigin = getBuildingAreaOrigin(buildingArea)

	for _, child in ipairs(buildingZone:GetChildren()) do
		-- Skip the BuildingArea itself
		if child == buildingArea then
			continue
		end

		-- Only scan items that have a BlockId (actual placed blocks)
		-- This filters out WallLimit, Floor, decorative parts inside models, etc.
		local blockIdValue = child:FindFirstChild("BlockId")
		if not blockIdValue or not blockIdValue:IsA("StringValue") then
			continue
		end

		local position = getBlockPosition(child)
		if position then
			local blockType = getBlockType(child)

			-- Calculate relative position from area origin
			local relativePos = position - areaOrigin

			-- Round to nearest 2 studs to preserve differences between 2x2x2 blocks
			-- This works for both 4x4x4 (centers at 2,6,10...) and 2x2x2 (centers at 1,3,5...)
			local gridX = math.round(relativePos.X / SMALL_GRID_SIZE) * SMALL_GRID_SIZE
			local gridY = math.round(relativePos.Y / SMALL_GRID_SIZE) * SMALL_GRID_SIZE
			local gridZ = math.round(relativePos.Z / SMALL_GRID_SIZE) * SMALL_GRID_SIZE

			table.insert(blocks, {
				position = Vector3.new(gridX, gridY, gridZ),
				blockType = blockType,
				instance = child,
				-- Store raw positions for accurate anchor detection
				rawX = relativePos.X,
				rawY = relativePos.Y,
				rawZ = relativePos.Z,
			})
		end
	end

	return blocks
end

-- Find the anchor block (ground level, leftmost when facing +Z)
-- Uses raw world positions for accurate ground detection
local function findAnchorBlock(blocks, buildingArea)
	if #blocks == 0 then
		return nil
	end

	-- Get the actual floor level (top of ground/grass)
	local areaOrigin = getBuildingAreaOrigin(buildingArea)
	local floorY = areaOrigin.Y

	-- Find the block with the lowest bottom edge (closest to the floor)
	-- Block bottom = center Y - half height (assuming 4 stud blocks, half = 2)
	-- We use rawY which is the actual world Y position
	local minBottomY = math.huge
	for _, block in ipairs(blocks) do
		-- Estimate block bottom (center - 2 for standard blocks)
		-- Using rawY stored during scan
		local bottomY = block.rawY - 2
		if bottomY < minBottomY then
			minBottomY = bottomY
		end
	end

	-- Filter to blocks at ground level (within small tolerance)
	local groundBlocks = {}
	local tolerance = 1 -- 1 stud tolerance for different block sizes
	for _, block in ipairs(blocks) do
		local bottomY = block.rawY - 2
		if math.abs(bottomY - minBottomY) <= tolerance then
			table.insert(groundBlocks, block)
		end
	end

	if #groundBlocks == 0 then
		groundBlocks = blocks -- Fallback to all blocks
	end

	-- Find the leftmost (minimum X) among ground blocks
	-- If tie, pick the one with minimum Z (front)
	local anchor = groundBlocks[1]
	for _, block in ipairs(groundBlocks) do
		if block.rawX < anchor.rawX then
			anchor = block
		elseif block.rawX == anchor.rawX and block.rawZ < anchor.rawZ then
			anchor = block
		end
	end

	return anchor
end

-- Calculate offsets relative to anchor
local function calculateOffsets(blocks, anchor)
	local offsets = {}

	for _, block in ipairs(blocks) do
		local offset = block.position - anchor.position
		table.insert(offsets, {
			offset = offset,
			blockType = block.blockType,
		})
	end

	-- Sort by Y, then X, then Z for consistent output
	table.sort(offsets, function(a, b)
		if a.offset.Y ~= b.offset.Y then
			return a.offset.Y < b.offset.Y
		elseif a.offset.X ~= b.offset.X then
			return a.offset.X < b.offset.X
		else
			return a.offset.Z < b.offset.Z
		end
	end)

	return offsets
end

-- Calculate the total size of the blueprint
local function calculateSize(offsets)
	local maxX, maxY, maxZ = 0, 0, 0

	for _, data in ipairs(offsets) do
		maxX = math.max(maxX, data.offset.X)
		maxY = math.max(maxY, data.offset.Y)
		maxZ = math.max(maxZ, data.offset.Z)
	end

	-- Add one block size to get total dimensions (assuming largest block size)
	return Vector3.new(maxX + DEFAULT_GRID_SIZE, maxY + DEFAULT_GRID_SIZE, maxZ + DEFAULT_GRID_SIZE)
end

-- Generate the blueprint definition as a standalone file
local function generateDefinition(name, offsets, size)
	local lines = {}

	-- File header comment
	table.insert(lines, "--[[")
	table.insert(lines, string.format("\t%s Blueprint Definition", name))
	table.insert(lines, "\tGenerated by Blueprint Scanner Plugin")
	table.insert(lines, "")
	table.insert(lines, "\tAnchor: Bottom-left-front block (PrimaryPart of the model)")
	table.insert(lines, "\tAll offsets are relative to the anchor position.")
	table.insert(lines, "]]")
	table.insert(lines, "")

	-- Definition table
	table.insert(lines, string.format("local %s = {", name))
	table.insert(lines, string.format('\tid = "%s",', name:lower()))
	table.insert(lines, string.format('\tname = "%s",', name))
	table.insert(lines, string.format('\tdisplayName = "%s",', name))
	table.insert(lines, '\tdescription = "Description here.",')
	table.insert(lines, string.format('\tsize = Vector3.new(%d, %d, %d),', size.X, size.Y, size.Z))
	table.insert(lines, "")
	table.insert(lines, "\t-- Block requirements: offset is relative to anchor (PrimaryPart position)")

	-- Blocks
	table.insert(lines, '\tblocks = {')
	for i, data in ipairs(offsets) do
		local comment = ""
		if data.offset == Vector3.new(0, 0, 0) then
			comment = " -- Anchor block"
		end
		table.insert(lines, string.format(
			'\t\t{ offset = Vector3.new(%d, %d, %d), blockType = "%s" },%s',
			data.offset.X, data.offset.Y, data.offset.Z,
			data.blockType,
			comment
		))
	end
	table.insert(lines, '\t},')
	table.insert(lines, "")

	-- Footer
	table.insert(lines, string.format('\tmodelPath = "ReplicatedStorage.Assets.Blueprints.%s",', name))
	table.insert(lines, string.format('\tclientClass = "%s",', name))
	table.insert(lines, string.format('\tserverClass = "%s",', name))
	table.insert(lines, '\tmaxQuantity = 1,')
	table.insert(lines, '\trequiredRebirth = 0,')
	table.insert(lines, '}')
	table.insert(lines, "")
	table.insert(lines, string.format("return %s", name))

	return table.concat(lines, "\n")
end

-- Highlight the anchor block
local function highlightAnchor(anchor)
	-- Remove old highlight
	local oldHighlight = workspace:FindFirstChild("BlueprintScannerHighlight")
	if oldHighlight then
		oldHighlight:Destroy()
	end

	if not anchor or not anchor.instance then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "BlueprintScannerHighlight"
	highlight.FillColor = Color3.fromRGB(0, 255, 0)
	highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.Adornee = anchor.instance
	highlight.Parent = workspace

	-- Auto-remove after 5 seconds
	task.delay(5, function()
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end)
end

-- Main scan function
local function scanBlueprint()
	-- Find BuildingArea
	local buildingArea, buildingZone = findBuildingArea()
	if not buildingArea then
		warn("[BlueprintScanner] Could not find BuildingArea")
		return
	end

	-- Scan blocks
	local blocks = scanBlocks(buildingZone, buildingArea)
	if #blocks == 0 then
		warn("[BlueprintScanner] No blocks found in BuildingArea")
		return
	end

	print("[BlueprintScanner] Found", #blocks, "blocks")

	-- Find anchor (ground level, leftmost)
	local anchor = findAnchorBlock(blocks, buildingArea)
	if not anchor then
		warn("[BlueprintScanner] Could not determine anchor block")
		return
	end

	print("[BlueprintScanner] Anchor block:", anchor.blockType)
	print("[BlueprintScanner] Anchor grid position:", anchor.position)
	print("[BlueprintScanner] Anchor raw position (relative): X=", anchor.rawX, "Y=", anchor.rawY, "Z=", anchor.rawZ)
	highlightAnchor(anchor)

	-- Calculate offsets
	local offsets = calculateOffsets(blocks, anchor)

	-- Calculate size
	local size = calculateSize(offsets)
	print("[BlueprintScanner] Blueprint size:", size)

	-- Prompt for name
	local name = "NewBlueprint"
	-- Note: Studio plugins can't show input dialogs easily, so we use a default
	-- The user can change it in the output

	-- Generate definition
	local definition = generateDefinition(name, offsets, size)

	-- Print to output
	print("\n" .. string.rep("=", 60))
	print("[BlueprintScanner] BLUEPRINT DEFINITION")
	print(string.format("1. Save as: src/shared/Data/Blueprints/%s.lua", name))
	print(string.format("2. Add to init.lua: local %s = require(script.%s)", name, name))
	print(string.format("3. Add to Definitions: %s = %s,", name, name))
	print(string.rep("=", 60))
	print(definition)
	print(string.rep("=", 60))

	-- Try to copy to clipboard (may not work in all cases)
	pcall(function()
		StudioService:CopyToClipboard(definition)
		print("[BlueprintScanner] Definition copied to clipboard!")
	end)

	-- Select the anchor block
	Selection:Set({anchor.instance})
end

-- Connect button
scanButton.Click:Connect(function()
	print("[BlueprintScanner] Scanning BuildingArea...")
	local success, err = pcall(scanBlueprint)
	if not success then
		warn("[BlueprintScanner] Error:", err)
	end
end)

print("[BlueprintScanner] Plugin loaded! Click 'Scan Blueprint' to scan your BuildingArea.")
