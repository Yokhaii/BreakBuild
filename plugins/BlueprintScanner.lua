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
	2. Select the block you want to use as the ANCHOR (PrimaryPart) in the viewport
	3. Click "Scan Blueprint" in the toolbar
	4. The definition will be printed to Output and copied to clipboard

	The anchor can be ANY block in the blueprint (not just a corner).
	Offsets will be calculated relative to the selected anchor and may be negative.

	MIXED BLOCK SIZES (4x4x4 and 2x2x2):
	The plugin automatically corrects offset parity so every slot lands on a
	position that the game's snap system can reach:
	  - 4x4x4 blocks snap to EVEN world coordinates  (2, 4, 6 ...)
	  - 2x2x2 blocks snap to ODD  world coordinates  (1, 3, 5 ...)
	  Rule: offset = target_world - anchor_world
	    same-size pair  → offset must be EVEN
	    mixed-size pair → offset must be ODD  (on every axis)
	A warning is printed if any raw offset had to be corrected, which means the
	blocks in the BuildingArea were not on the proper snapped grid.
]]

local Selection = game:GetService("Selection")
local StudioService = game:GetService("StudioService")

-- Constants
local GRID_SIZE = 2 -- matches BuildingService / BlueprintService
local PLUGIN_NAME = "Blueprint Scanner"

-- Create toolbar and button
local toolbar = plugin:CreateToolbar(PLUGIN_NAME)
local scanButton = toolbar:CreateButton(
	"Scan Blueprint",
	"Scan the BuildingArea and generate blueprint definition",
	"rbxassetid://6031071053"
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

-- Get the size of a block (handles both Models and Parts)
local function getBlockSize(block)
	if block:IsA("Model") and block.PrimaryPart then
		return block.PrimaryPart.Size
	elseif block:IsA("BasePart") then
		return block.Size
	end
	return Vector3.new(4, 4, 4)
end

-- Get block type from the block
local function getBlockType(block)
	local itemNameValue = block:FindFirstChild("ItemName")
	if itemNameValue and itemNameValue:IsA("StringValue") then
		return itemNameValue.Value
	end

	local name = block.Name
	name = name:gsub("_Placed$", "")
	name = name:gsub("_Block$", "")

	return name
end

-- Get the building area origin (floor level)
local function getBuildingAreaOrigin(buildingArea)
	local areaPosition = buildingArea.Position
	return Vector3.new(areaPosition.X, areaPosition.Y - 32, areaPosition.Z)
end

-- Snap one axis of an absolute relative position to the game grid.
-- Mirrors BuildingService.snapToGridForBlockSize exactly.
-- Returns: snapped value, wasCorrected boolean
local function snapAbsoluteAxis(value, halfBlockSize)
	local snapped
	if halfBlockSize % GRID_SIZE == 0 then
		-- 4x4x4 blocks → even positions: 2, 4, 6 ...
		snapped = math.round(value / GRID_SIZE) * GRID_SIZE
	else
		-- 2x2x2 blocks → odd positions: 1, 3, 5 ...
		local gridHalf = GRID_SIZE / 2
		snapped = math.round((value - gridHalf) / GRID_SIZE) * GRID_SIZE + gridHalf
	end
	local wasCorrected = math.abs(value - snapped) > 0.01
	return snapped, wasCorrected
end

-- Snap an absolute relative position to the game grid for a given block size.
local function snapPositionToGrid(pos, blockSize)
	local halfSize = blockSize / 2
	local sx, cx = snapAbsoluteAxis(pos.X, halfSize.X)
	local sy, cy = snapAbsoluteAxis(pos.Y, halfSize.Y)
	local sz, cz = snapAbsoluteAxis(pos.Z, halfSize.Z)
	return Vector3.new(sx, sy, sz), (cx or cy or cz)
end

-- Scan all placed blocks in the BuildingZone
local function scanBlocks(buildingZone, buildingArea)
	local blocks = {}
	local areaOrigin = getBuildingAreaOrigin(buildingArea)

	for _, child in ipairs(buildingZone:GetChildren()) do
		if child == buildingArea then
			continue
		end

		local blockIdValue = child:FindFirstChild("BlockId")
		if not blockIdValue or not blockIdValue:IsA("StringValue") then
			continue
		end

		local position = getBlockPosition(child)
		if position then
			local blockType = getBlockType(child)
			local blockSize = getBlockSize(child)
			local rawRelative = position - areaOrigin

			-- Snap the absolute relative position to the same grid the game uses.
			-- This ensures offsets computed later match what BuildingService records.
			local snappedPos, wasCorrected = snapPositionToGrid(rawRelative, blockSize)
			if wasCorrected then
				warn(string.format(
					"[BlueprintScanner] Block '%s' (%dx%dx%d) was off-grid in Studio: " ..
					"raw (%.2f, %.2f, %.2f) → snapped (%d, %d, %d). " ..
					"Move it onto the correct grid before scanning.",
					blockType,
					blockSize.X, blockSize.Y, blockSize.Z,
					rawRelative.X, rawRelative.Y, rawRelative.Z,
					snappedPos.X, snappedPos.Y, snappedPos.Z
				))
			end

			table.insert(blocks, {
				position = snappedPos,
				blockType = blockType,
				size = blockSize,
				instance = child,
			})
		end
	end

	return blocks
end

-- Get the user-selected anchor block from the Selection service
local function getSelectedAnchor(blocks)
	local selected = Selection:Get()
	if not selected or #selected == 0 then
		warn("[BlueprintScanner] No block selected! Select the desired anchor block in the viewport first.")
		return nil
	end

	if #selected > 1 then
		warn("[BlueprintScanner] Multiple objects selected. Select exactly ONE block as anchor.")
		return nil
	end

	local selectedInstance = selected[1]

	-- Direct instance match
	for _, block in ipairs(blocks) do
		if block.instance == selectedInstance then
			return block
		end
	end

	-- Position-based match (in case of model vs part selection)
	local selectedPos = getBlockPosition(selectedInstance)
	if selectedPos then
		for _, block in ipairs(blocks) do
			local blockPos = getBlockPosition(block.instance)
			if blockPos and (blockPos - selectedPos).Magnitude < 1 then
				return block
			end
		end
	end

	warn("[BlueprintScanner] Selected object is not a scanned block in the BuildingZone.")
	warn("[BlueprintScanner] Make sure the selected block has a BlockId StringValue.")
	return nil
end

-- Calculate offsets relative to anchor.
-- Both anchor and block positions have already been snapped to the game grid
-- in scanBlocks(), so simple integer subtraction is all that's needed.
local function calculateOffsets(blocks, anchor)
	local offsets = {}

	for _, block in ipairs(blocks) do
		local offset   = block.position - anchor.position
		local blockSize = block.size or Vector3.new(4, 4, 4)

		table.insert(offsets, {
			offset    = Vector3.new(math.round(offset.X), math.round(offset.Y), math.round(offset.Z)),
			blockType = block.blockType,
			blockSize = blockSize,
		})
	end

	-- Sort by Y, then X, then Z for consistent output
	table.sort(offsets, function(a, b)
		if a.offset.Y ~= b.offset.Y then return a.offset.Y < b.offset.Y end
		if a.offset.X ~= b.offset.X then return a.offset.X < b.offset.X end
		return a.offset.Z < b.offset.Z
	end)

	return offsets
end

-- Generate the blueprint definition as a standalone file
local function generateDefinition(name, offsets, anchorSize)
	local lines = {}

	table.insert(lines, "--[[")
	table.insert(lines, string.format("\t%s Blueprint Definition", name))
	table.insert(lines, "\tGenerated by Blueprint Scanner Plugin")
	table.insert(lines, "")
	table.insert(lines, "\tAnchor: User-selected block (PrimaryPart of the model)")
	table.insert(lines, "\tAll offsets are relative to the anchor position.")
	table.insert(lines, "]]")
	table.insert(lines, "")

	table.insert(lines, string.format("local %s = {", name))
	table.insert(lines, string.format('\tid = "%s",', name))
	table.insert(lines, string.format('\tname = "%s",', name))
	table.insert(lines, string.format('\tdisplayName = "%s",', name))
	table.insert(lines, '\tdescription = "Description here.",')
	table.insert(lines, "")
	table.insert(lines, "\t-- Block requirements: offset is relative to anchor (PrimaryPart position)")
	table.insert(lines, "\t-- Mixed block sizes: 4x4x4 slots use even offsets, 2x2x2 slots use odd offsets")

	table.insert(lines, '\tblocks = {')
	for _, data in ipairs(offsets) do
		local sizeTag = string.format("%dx%dx%d", data.blockSize.X, data.blockSize.Y, data.blockSize.Z)
		local comment
		if data.offset == Vector3.new(0, 0, 0) then
			comment = string.format(" -- Anchor block (%s)", sizeTag)
		else
			comment = string.format(" -- %s", sizeTag)
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

	table.insert(lines, string.format('\tmodelPath = "ReplicatedStorage.Assets.Blueprints.%s",', name))
	table.insert(lines, string.format('\tcompletedModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.%s",', name))
	table.insert(lines, string.format('\tcompletedItemName = "Completed%s",', name))
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

	task.delay(5, function()
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end)
end

-- Main scan function
local function scanBlueprint()
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

	-- Get user-selected anchor
	local anchor = getSelectedAnchor(blocks)
	if not anchor then
		return
	end

	print(string.format(
		"[BlueprintScanner] Anchor: %s (size %dx%dx%d) at relative pos (%d, %d, %d)",
		anchor.blockType,
		anchor.size.X, anchor.size.Y, anchor.size.Z,
		anchor.position.X, anchor.position.Y, anchor.position.Z
	))
	highlightAnchor(anchor)

	-- Calculate offsets relative to anchor (with parity correction for mixed block sizes)
	local offsets = calculateOffsets(blocks, anchor)

	-- Print per-block summary
	for _, data in ipairs(offsets) do
		print(string.format(
			"[BlueprintScanner]   %s (%dx%dx%d) offset (%d, %d, %d)",
			data.blockType,
			data.blockSize.X, data.blockSize.Y, data.blockSize.Z,
			data.offset.X, data.offset.Y, data.offset.Z
		))
	end

	-- Generate definition
	local name = "NewBlueprint"
	local definition = generateDefinition(name, offsets, anchor.size)

	-- Print to output
	print("\n" .. string.rep("=", 60))
	print("[BlueprintScanner] BLUEPRINT DEFINITION")
	print(string.format("1. Save as: src/shared/Data/Blueprints/%s.lua", name))
	print(string.format("2. Add to init.lua: local %s = require(script.%s)", name, name))
	print(string.format("3. Add to Definitions: %s = %s,", name, name))
	print(string.rep("=", 60))
	print(definition)
	print(string.rep("=", 60))

	-- Try to copy to clipboard
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
	print("[BlueprintScanner] Using selected block as anchor...")
	local success, err = pcall(scanBlueprint)
	if not success then
		warn("[BlueprintScanner] Error:", err)
	end
end)

print("[BlueprintScanner] Plugin loaded! Select anchor block, then click 'Scan Blueprint'.")
