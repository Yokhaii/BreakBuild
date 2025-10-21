-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Signal = require(game:GetService("ReplicatedStorage").Packages.Signal)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Data
local MaterialData = require(ReplicatedStorage.Shared.Data.MaterialData)

-- Services (to be initialized)
local ProximityPromptService
local InventoryService

local BreakingService = Knit.CreateService({
	Name = "BreakingService",
	Client = {
		GridUpdated = Knit.CreateSignal(),
		MaterialDestroyed = Knit.CreateSignal(),
		MaterialMoved = Knit.CreateSignal(),
		MaterialSpawned = Knit.CreateSignal(),
		MaterialGrabbed = Knit.CreateSignal(), -- (x, y, materialType)
		MaterialPlaced = Knit.CreateSignal(), -- (fromX, fromY, toX, toY)
		MaterialCollected = Knit.CreateSignal(), -- (x, y, materialType) - For tween animation
	},
})

-- Constants
local GRID_ROWS = 6
local GRID_COLS = 7
local MATCH_COUNT = 3 -- Number of materials needed to match

-- Types
type GridCell = {
	materialType: string,
	part: BasePart?,
	movePromptId: string?,
	destroyPromptId: string?,
}

type PlayerGrid = {
	grid: {{GridCell}},
	isProcessing: boolean, -- Prevent multiple operations at once
	heldMaterial: {x: number, y: number, materialType: string}?, -- Currently held material
	originalSpeed: number?, -- Player's original walk speed
}

-- Private variables
local playerGrids: {[Player]: PlayerGrid} = {}

--|| Private Functions ||--

-- Create empty grid
local function createEmptyGrid(): {{GridCell}}
	local grid = {}
	for x = 1, GRID_ROWS do
		grid[x] = {}
		for y = 1, GRID_COLS do
			grid[x][y] = {
				materialType = "",
				part = nil,
				movePromptId = nil,
				destroyPromptId = nil,
			}
		end
	end
	return grid
end

-- Initialize grid with random materials
local function initializeGrid(grid: {{GridCell}})
	for x = 1, GRID_ROWS do
		for y = 1, GRID_COLS do
			grid[x][y].materialType = MaterialData.GetRandomMaterial()
		end
	end
end

-- Get attachment position for grid cell
local function getAttachmentPosition(x: number, y: number): Vector3?
	local mountain = Workspace:FindFirstChild("Mountain")
	if not mountain or not mountain.PrimaryPart then
		warn("Mountain or Mountain.PrimaryPart not found in Workspace!")
		return nil
	end

	local attachmentName = string.format("%d,%d", x, y)
	local attachment = mountain.PrimaryPart.MaterialsAttachments:FindFirstChild(attachmentName)

	if not attachment or not attachment:IsA("Attachment") then
		warn("Attachment not found:", attachmentName)
		return nil
	end

	return attachment.WorldPosition
end

-- Give material to player's inventory
local function giveMaterialToPlayer(player: Player, materialType: string)
	if not InventoryService then
		warn("InventoryService not initialized!")
		return
	end

	-- Add the material as an item to the player's inventory
	local success = InventoryService:AddItem(player, materialType, 1)
	if not success then
		warn("Failed to add item to inventory:", materialType)
	end
end

-- Create invisible part at grid position
local function createGridPart(x: number, y: number, materialType: string): BasePart?
	local position = getAttachmentPosition(x, y)
	if not position then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = string.format("GridPart_%d_%d", x, y)
	part.Size = Vector3.new(3, 3, 3) -- Adjust size as needed
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1 -- Invisible
	part.Parent = Workspace:FindFirstChild("Mountain") or Workspace

	-- Store grid coordinates in part
	local xValue = Instance.new("IntValue")
	xValue.Name = "GridX"
	xValue.Value = x
	xValue.Parent = part

	local yValue = Instance.new("IntValue")
	yValue.Name = "GridY"
	yValue.Value = y
	yValue.Parent = part

	return part
end

-- Setup proximity prompts for a grid cell
local function setupProximityPrompts(player: Player, x: number, y: number, part: BasePart)
	local playerGrid = playerGrids[player]
	if not playerGrid then return end

	local cell = playerGrid.grid[x][y]

	-- Move/Grab/Place prompt (changes based on player state)
	local movePromptId = ProximityPromptService:AddPrompt(part, {
		actionText = "Grab",
		objectText = cell.materialType,
		holdDuration = 0,
		maxActivationDistance = 8,
		enabled = true,
	}, function(triggeringPlayer: Player, promptInstance: ProximityPrompt, promptData)
		if triggeringPlayer ~= player then return end
		BreakingService:HandleGrabOrPlace(player, x, y)
	end)

	-- Destroy prompt
	local destroyPromptId = ProximityPromptService:AddPrompt(part, {
		actionText = "Destroy",
		objectText = cell.materialType,
		holdDuration = 0.5,
		maxActivationDistance = 8,
		enabled = true,
	}, function(triggeringPlayer: Player, promptInstance: ProximityPrompt, promptData)
		if triggeringPlayer ~= player then return end
		BreakingService:DestroyMaterial(player, x, y)
	end)

	cell.movePromptId = movePromptId
	cell.destroyPromptId = destroyPromptId
end

-- Update move prompt text based on grab state
local function updateMovePrompt(player: Player, x: number, y: number)
	local playerGrid = playerGrids[player]
	if not playerGrid then return end

	local cell = playerGrid.grid[x][y]
	if not cell.movePromptId then return end

	if playerGrid.heldMaterial then
		-- Player is holding something - show "Place" on valid spots
		ProximityPromptService:UpdatePromptConfig(cell.movePromptId, {
			actionText = "Place Here",
			objectText = cell.materialType ~= "" and cell.materialType or "Empty",
		})
	else
		-- Player not holding - show "Grab"
		ProximityPromptService:UpdatePromptConfig(cell.movePromptId, {
			actionText = "Grab",
			objectText = cell.materialType,
		})
	end
end

-- Update prompt object text when material changes
local function updatePromptMaterialName(player: Player, x: number, y: number)
	local playerGrid = playerGrids[player]
	if not playerGrid then return end

	local cell = playerGrid.grid[x][y]

	-- Update move prompt
	if cell.movePromptId then
		ProximityPromptService:UpdatePromptConfig(cell.movePromptId, {
			objectText = cell.materialType ~= "" and cell.materialType or "Empty",
		})
	end

	-- Update destroy prompt
	if cell.destroyPromptId then
		ProximityPromptService:UpdatePromptConfig(cell.destroyPromptId, {
			objectText = cell.materialType ~= "" and cell.materialType or "Empty",
		})
	end
end

-- Check if two cells are adjacent (top, bottom, left, right only)
local function areAdjacent(x1: number, y1: number, x2: number, y2: number): boolean
	local dx = math.abs(x2 - x1)
	local dy = math.abs(y2 - y1)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)
end

-- Update all prompts based on grab state
local function updatePromptsForGrabState(player: Player)
	local playerGrid = playerGrids[player]
	if not playerGrid then return end

	if playerGrid.heldMaterial then
		-- Player is holding something - only enable adjacent prompts
		local heldX = playerGrid.heldMaterial.x
		local heldY = playerGrid.heldMaterial.y

		for x = 1, GRID_ROWS do
			for y = 1, GRID_COLS do
				local cell = playerGrid.grid[x][y]
				local isAdjacent = areAdjacent(heldX, heldY, x, y)

				-- Enable move prompt only for adjacent cells
				if cell.movePromptId then
					ProximityPromptService:SetPromptEnabled(cell.movePromptId, isAdjacent)
					if isAdjacent then
						updateMovePrompt(player, x, y)
					end
				end

				-- Disable destroy prompts while holding
				if cell.destroyPromptId then
					ProximityPromptService:SetPromptEnabled(cell.destroyPromptId, false)
				end
			end
		end
	else
		-- Player not holding - enable all non-empty prompts
		for x = 1, GRID_ROWS do
			for y = 1, GRID_COLS do
				local cell = playerGrid.grid[x][y]
				local hasMateria = cell.materialType ~= ""

				if cell.movePromptId then
					ProximityPromptService:SetPromptEnabled(cell.movePromptId, hasMateria)
					if hasMateria then
						updateMovePrompt(player, x, y)
					end
				end

				if cell.destroyPromptId then
					ProximityPromptService:SetPromptEnabled(cell.destroyPromptId, hasMateria)
				end
			end
		end
	end
end

-- Enable/disable all prompts for a player
local function setAllPromptsEnabled(player: Player, enabled: boolean)
	local playerGrid = playerGrids[player]
	if not playerGrid then return end

	for x = 1, GRID_ROWS do
		for y = 1, GRID_COLS do
			local cell = playerGrid.grid[x][y]

			if cell.movePromptId then
				ProximityPromptService:SetPromptEnabled(cell.movePromptId, enabled)
			end

			if cell.destroyPromptId then
				ProximityPromptService:SetPromptEnabled(cell.destroyPromptId, enabled)
			end
		end
	end
end

-- Check for matches (3 or more in a row)
local function checkMatches(grid: {{GridCell}}): {{x: number, y: number}}
	local matchedCells = {}

	-- Check horizontal matches
	for x = 1, GRID_ROWS do
		local currentMaterial = grid[x][1].materialType
		local matchStart = 1
		local matchLength = 1

		for y = 2, GRID_COLS + 1 do
			local material = y <= GRID_COLS and grid[x][y].materialType or ""

			if material == currentMaterial and material ~= "" then
				matchLength = matchLength + 1
			else
				-- Check if we have a match
				if matchLength >= MATCH_COUNT then
					for i = matchStart, matchStart + matchLength - 1 do
						table.insert(matchedCells, {x = x, y = i})
					end
				end
				currentMaterial = material
				matchStart = y
				matchLength = 1
			end
		end
	end

	-- Check vertical matches
	for y = 1, GRID_COLS do
		local currentMaterial = grid[1][y].materialType
		local matchStart = 1
		local matchLength = 1

		for x = 2, GRID_ROWS + 1 do
			local material = x <= GRID_ROWS and grid[x][y].materialType or ""

			if material == currentMaterial and material ~= "" then
				matchLength = matchLength + 1
			else
				-- Check if we have a match
				if matchLength >= MATCH_COUNT then
					for i = matchStart, matchStart + matchLength - 1 do
						table.insert(matchedCells, {x = i, y = y})
					end
				end
				currentMaterial = material
				matchStart = x
				matchLength = 1
			end
		end
	end

	return matchedCells
end

-- Remove duplicates from matched cells
local function removeDuplicateMatches(matches: {{x: number, y: number}}): {{x: number, y: number}}
	local seen = {}
	local unique = {}

	for _, match in ipairs(matches) do
		local key = string.format("%d,%d", match.x, match.y)
		if not seen[key] then
			seen[key] = true
			table.insert(unique, match)
		end
	end

	return unique
end

-- Apply gravity one step in ALL columns at once
-- Returns true if any material fell, false otherwise
local function applyGravityOneStepAllColumns(player: Player, grid: {{GridCell}}): boolean
	local anyFell = false

	-- Process all columns in parallel (in one step)
	for y = 1, GRID_COLS do
		-- Find the first empty cell from bottom to top in this column
		for x = GRID_ROWS, 2, -1 do
			if grid[x][y].materialType == "" then
				-- Look for material directly above
				for aboveX = x - 1, 1, -1 do
					if grid[aboveX][y].materialType ~= "" then
						-- Move material down one step
						grid[x][y].materialType = grid[aboveX][y].materialType
						grid[aboveX][y].materialType = ""

						-- Update proximity prompt names
						updatePromptMaterialName(player, x, y)
						updatePromptMaterialName(player, aboveX, y)

						-- Notify client
						BreakingService.Client.MaterialMoved:Fire(player, aboveX, y, x, y)
						anyFell = true
						break -- Only move one material per column per step
					end
				end
				break -- Only fill one empty cell per column per step
			end
		end
	end

	return anyFell
end

-- Spawn new materials ALWAYS at row 1 for ALL columns that need them
-- Returns true if any material was spawned, false otherwise
local function spawnMaterialsOneStep(player: Player, grid: {{GridCell}}): boolean
	local anySpawned = false

	for y = 1, GRID_COLS do
		-- Check if this column has any empty cells
		local hasEmpty = false
		for x = 1, GRID_ROWS do
			if grid[x][y].materialType == "" then
				hasEmpty = true
				break
			end
		end

		-- If column has empty cells and top is empty, spawn at row 1
		if hasEmpty and grid[1][y].materialType == "" then
			grid[1][y].materialType = MaterialData.GetRandomMaterial()

			-- Update proximity prompt name
			updatePromptMaterialName(player, 1, y)

			-- Notify client to spawn at row 1
			BreakingService.Client.MaterialSpawned:Fire(player, 1, y, grid[1][y].materialType)
			anySpawned = true
		end
	end

	return anySpawned
end

-- Process matches and gravity in sequence with proper animation timing
local function processMatchesAndGravity(player: Player, skipInitialWait: boolean?)
	local playerGrid = playerGrids[player]
	if not playerGrid or playerGrid.isProcessing then return end

	playerGrid.isProcessing = true
	setAllPromptsEnabled(player, false) -- Disable all player interactions

	task.spawn(function()
		local iterations = 0
		local maxIterations = 20 -- Prevent infinite loops

		-- Initial wait before checking for matches (only on grid spawn, not on player actions)
		if not skipInitialWait then
			task.wait(0.5)
		end

		while iterations < maxIterations do
			iterations = iterations + 1

			-- Check for matches
			local matches = checkMatches(playerGrid.grid)
			matches = removeDuplicateMatches(matches)

			if #matches > 0 then
				-- Destroy matched materials (all at once)
				for _, match in ipairs(matches) do
					local materialType = playerGrid.grid[match.x][match.y].materialType
					playerGrid.grid[match.x][match.y].materialType = ""

					-- Fire collection signal for tween animation
					BreakingService.Client.MaterialCollected:Fire(player, match.x, match.y, materialType)

					-- Give material to player's inventory
					giveMaterialToPlayer(player, materialType)

					BreakingService.Client.MaterialDestroyed:Fire(player, match.x, match.y, true) -- true = match
				end

				-- Wait for destruction animation to complete
				task.wait(0.5)

				-- Apply gravity step by step (all columns in parallel each step)
				local gravityIterations = 0
				while gravityIterations < 50 do -- Safety limit
					gravityIterations = gravityIterations + 1

					-- Process one fall step in ALL columns simultaneously
					local anyFell = applyGravityOneStepAllColumns(player, playerGrid.grid)
					if anyFell then
						-- Wait for fall animations to complete
						task.wait(0.3)
					else
						-- No more falling in any column, break
						break
					end
				end

				-- Wait a bit before spawning
				task.wait(0.2)

				-- Spawn and fall cycle: spawn at top, then let gravity pull them down
				local spawnIterations = 0
				while spawnIterations < 20 do -- Safety limit
					spawnIterations = spawnIterations + 1

					-- Spawn one material at row 1 in each column that needs it
					local anySpawned = spawnMaterialsOneStep(player, playerGrid.grid)
					if anySpawned then
						-- Wait for spawn animations to complete
						task.wait(0.4)

						-- Now let gravity pull down the newly spawned materials
						local fallIterations = 0
						while fallIterations < 10 do -- Safety limit for falling
							fallIterations = fallIterations + 1

							local anyFell = applyGravityOneStepAllColumns(player, playerGrid.grid)
							if anyFell then
								-- Wait for fall animations
								task.wait(0.3)
							else
								-- Nothing fell, materials have settled
								break
							end
						end
					else
						-- All columns filled, break
						break
					end
				end

				-- Wait before checking for new matches
				task.wait(0.3)

				-- Continue checking for new matches
			else
				-- No more matches, done
				break
			end
		end

		-- Re-enable player interactions
		setAllPromptsEnabled(player, true)
		playerGrid.isProcessing = false
	end)
end

--|| Public Functions ||--

-- Initialize grid for player
function BreakingService:InitializePlayerGrid(player: Player)
	if playerGrids[player] then
		warn("Grid already exists for player:", player.Name)
		return
	end

	local grid = createEmptyGrid()
	initializeGrid(grid)

	playerGrids[player] = {
		grid = grid,
		isProcessing = false,
		heldMaterial = nil,
		originalSpeed = nil,
	}

	-- Create parts and prompts
	for x = 1, GRID_ROWS do
		for y = 1, GRID_COLS do
			local cell = grid[x][y]
			local part = createGridPart(x, y, cell.materialType)
			if part then
				cell.part = part
				setupProximityPrompts(player, x, y, part)
			end
		end
	end

	-- Note: Client will fetch initial grid using GetGrid()
	-- Check for initial matches and process them
	task.delay(2, function()
		processMatchesAndGravity(player)
	end)
end

-- Cleanup player grid
function BreakingService:CleanupPlayerGrid(player: Player)
	local playerGrid = playerGrids[player]
	if not playerGrid then return end

	-- Remove all parts and prompts
	for x = 1, GRID_ROWS do
		for y = 1, GRID_COLS do
			local cell = playerGrid.grid[x][y]

			if cell.movePromptId then
				ProximityPromptService:RemovePrompt(cell.movePromptId)
			end

			if cell.destroyPromptId then
				ProximityPromptService:RemovePrompt(cell.destroyPromptId)
			end

			if cell.part then
				cell.part:Destroy()
			end
		end
	end

	playerGrids[player] = nil
end

-- Get grid for player (client can request)
function BreakingService:GetGrid(player: Player)
	local playerGrid = playerGrids[player]
	if not playerGrid then return nil end

	-- Convert to simple array for client
	local gridData = {}
	for x = 1, GRID_ROWS do
		gridData[x] = {}
		for y = 1, GRID_COLS do
			gridData[x][y] = playerGrid.grid[x][y].materialType
		end
	end

	return gridData
end

-- Handle grab or place action
function BreakingService:HandleGrabOrPlace(player: Player, x: number, y: number)
	local playerGrid = playerGrids[player]
	if not playerGrid or playerGrid.isProcessing then return end

	if playerGrid.heldMaterial then
		-- Player is holding something - try to place it
		self:PlaceMaterial(player, x, y)
	else
		-- Player not holding - try to grab
		self:GrabMaterial(player, x, y)
	end
end

-- Grab a material
function BreakingService:GrabMaterial(player: Player, x: number, y: number)
	local playerGrid = playerGrids[player]
	if not playerGrid or playerGrid.isProcessing then return end

	-- Validate position
	if x < 1 or x > GRID_ROWS or y < 1 or y > GRID_COLS then return end

	local cell = playerGrid.grid[x][y]
	if cell.materialType == "" then
		warn("No material to grab at:", x, y)
		return
	end

	-- Store held material info
	playerGrid.heldMaterial = {
		x = x,
		y = y,
		materialType = cell.materialType,
	}

	-- Get player character and set holding speed
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			playerGrid.originalSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = MaterialData.HoldConfig.holdingWalkSpeed
		end
	end

	-- Notify client to grab material visually
	self.Client.MaterialGrabbed:Fire(player, x, y, cell.materialType)

	-- Update prompts to only show adjacent placement spots
	updatePromptsForGrabState(player)

	print(string.format("Player %s grabbed %s at (%d, %d)", player.Name, cell.materialType, x, y))
end

-- Place held material
function BreakingService:PlaceMaterial(player: Player, targetX: number, targetY: number)
	local playerGrid = playerGrids[player]
	if not playerGrid or playerGrid.isProcessing or not playerGrid.heldMaterial then return end

	local heldX = playerGrid.heldMaterial.x
	local heldY = playerGrid.heldMaterial.y

	-- Validate target position
	if targetX < 1 or targetX > GRID_ROWS or targetY < 1 or targetY > GRID_COLS then return end

	-- Check if adjacent
	if not areAdjacent(heldX, heldY, targetX, targetY) then
		warn("Can only place on adjacent cells!")
		return
	end

	-- Swap the materials
	local temp = playerGrid.grid[heldX][heldY].materialType
	playerGrid.grid[heldX][heldY].materialType = playerGrid.grid[targetX][targetY].materialType
	playerGrid.grid[targetX][targetY].materialType = temp

	-- Update proximity prompt names for swapped cells
	updatePromptMaterialName(player, heldX, heldY)
	updatePromptMaterialName(player, targetX, targetY)

	-- Restore player speed
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and playerGrid.originalSpeed then
			humanoid.WalkSpeed = playerGrid.originalSpeed
		end
	end

	-- Notify client to place material
	self.Client.MaterialPlaced:Fire(player, heldX, heldY, targetX, targetY)

	-- Clear held material
	playerGrid.heldMaterial = nil
	playerGrid.originalSpeed = nil

	-- Update prompts back to normal
	updatePromptsForGrabState(player)

	print(string.format("Player %s placed material from (%d, %d) to (%d, %d)", player.Name, heldX, heldY, targetX, targetY))
	print(string.format("After swap: (%d,%d)=%s, (%d,%d)=%s",
		heldX, heldY, playerGrid.grid[heldX][heldY].materialType,
		targetX, targetY, playerGrid.grid[targetX][targetY].materialType))

	-- Wait for placement animation to complete and materials to settle, then check for matches
	task.delay(1, function()
		-- Check what matches are found
		local matches = checkMatches(playerGrid.grid)
		print(string.format("Found %d potential matches", #matches))
		for _, match in ipairs(matches) do
			print(string.format("  Match at (%d,%d): %s", match.x, match.y, playerGrid.grid[match.x][match.y].materialType))
		end

		processMatchesAndGravity(player, true)
	end)
end

-- Destroy material at position
function BreakingService:DestroyMaterial(player: Player, x: number, y: number)
	local playerGrid = playerGrids[player]
	if not playerGrid or playerGrid.isProcessing then return end

	if x < 1 or x > GRID_ROWS or y < 1 or y > GRID_COLS then
		warn("Invalid grid position:", x, y)
		return
	end

	local cell = playerGrid.grid[x][y]
	if cell.materialType == "" then
		warn("No material at position:", x, y)
		return
	end

	-- Store material type before destroying
	local materialType = cell.materialType

	-- Destroy the material
	cell.materialType = ""

	-- Update proximity prompt name
	updatePromptMaterialName(player, x, y)

	-- Fire collection signal for tween animation
	self.Client.MaterialCollected:Fire(player, x, y, materialType)

	-- Give material to player's inventory
	giveMaterialToPlayer(player, materialType)

	self.Client.MaterialDestroyed:Fire(player, x, y, false) -- false = manual destroy

	-- Process gravity and matches (skip initial wait since this is a player action)
	processMatchesAndGravity(player, true)
end

-- Swap two materials (used by move system)
function BreakingService:SwapMaterials(player: Player, x1: number, y1: number, x2: number, y2: number)
	local playerGrid = playerGrids[player]
	if not playerGrid or playerGrid.isProcessing then return false end

	-- Validate positions
	if x1 < 1 or x1 > GRID_ROWS or y1 < 1 or y1 > GRID_COLS then return false end
	if x2 < 1 or x2 > GRID_ROWS or y2 < 1 or y2 > GRID_COLS then return false end

	-- Check if adjacent (only top, bottom, left, right)
	local dx = math.abs(x2 - x1)
	local dy = math.abs(y2 - y1)
	if not ((dx == 1 and dy == 0) or (dx == 0 and dy == 1)) then
		warn("Can only swap with adjacent cells!")
		return false
	end

	-- Swap materials
	local temp = playerGrid.grid[x1][y1].materialType
	playerGrid.grid[x1][y1].materialType = playerGrid.grid[x2][y2].materialType
	playerGrid.grid[x2][y2].materialType = temp

	-- Notify client
	self.Client.MaterialMoved:Fire(player, x1, y1, x2, y2)

	-- Process matches and gravity (skip initial wait since this is a player action)
	processMatchesAndGravity(player, true)

	return true
end

--|| Client Functions ||--

function BreakingService.Client:GetGrid(player: Player)
	return self.Server:GetGrid(player)
end

function BreakingService.Client:SwapMaterials(player: Player, x1: number, y1: number, x2: number, y2: number)
	return self.Server:SwapMaterials(player, x1, y1, x2, y2)
end

-- KNIT START
function BreakingService:KnitStart()
	ProximityPromptService = Knit.GetService("ProximityPromptService")
	InventoryService = Knit.GetService("InventoryService")

	-- Setup player grid on join
	local function playerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- Wait for character to load
			task.wait(1)
			self:InitializePlayerGrid(player)
		end)

		if player.Character then
			task.wait(1)
			self:InitializePlayerGrid(player)
		end
	end

	Players.PlayerAdded:Connect(playerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		playerAdded(player)
	end

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayerGrid(player)
	end)
end

return BreakingService
