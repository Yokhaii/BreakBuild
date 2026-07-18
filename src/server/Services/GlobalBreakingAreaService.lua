local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GlobalBreakingConfig = require(ReplicatedStorage.Shared.Config.GlobalBreakingConfig)
local BiomeData = require(ReplicatedStorage.Shared.Data.BiomeData)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local BreakingService

local GlobalBreakingAreaService = Knit.CreateService({
	Name = "GlobalBreakingAreaService",
	Client = {
		CycleReset = Knit.CreateSignal(),
		CycleTimeRemaining = Knit.CreateSignal(),
	},
})

local originPosition: Vector3 = Vector3.zero
local currentSeed: number = 0
local cycleStartTime: number = 0
local containerFolder: Folder? = nil
local currentBiome: string = ""

local lowestRevealedY: number = 0
local placedBlocks: {[string]: Instance} = {}
local placementQueue: {{x: number, y: number, z: number, materialType: string}} = {}

-- Used by Mountain biome
local heightmap: {[number]: {[number]: number}} = {}

local function encodeKey(x: number, y: number, z: number): string
	return x .. "," .. y .. "," .. z
end

local function gridToWorldPosition(x: number, y: number, z: number): Vector3
	local blockSize = GlobalBreakingConfig.BlockSize.X
	local halfGrid = (GlobalBreakingConfig.GridSizeX * blockSize) / 2
	local worldX = originPosition.X - halfGrid + (x * blockSize) + (blockSize / 2)
	local worldY = originPosition.Y + (y * blockSize) + (blockSize / 2)
	local worldZ = originPosition.Z - halfGrid + (z * blockSize) + (blockSize / 2)
	return Vector3.new(worldX, worldY, worldZ)
end

local function makeBreakableId(x: number, y: number, z: number): string
	return "global_" .. x .. "_" .. y .. "_" .. z
end

local function createBlockModel(materialType: string, position: Vector3, breakableId: string): Instance?
	local itemConfig = ItemData.GetItem(materialType)
	if not itemConfig or not itemConfig.buildingPartPath then
		warn("[GlobalBreakingAreaService] No buildingPartPath for material:", materialType)
		return nil
	end

	local pathParts = string.split(itemConfig.buildingPartPath, ".")
	local current = ReplicatedStorage

	local startIndex = 1
	if pathParts[1] == "ReplicatedStorage" then
		startIndex = 2
	end

	for i = startIndex, #pathParts do
		current = current:FindFirstChild(pathParts[i])
		if not current then
			warn("[GlobalBreakingAreaService] Building part not found at path:", itemConfig.buildingPartPath)
			return nil
		end
	end

	local model = current:Clone()
	model.Name = "GlobalBlock_" .. breakableId

	if model:IsA("Model") and model.PrimaryPart then
		model:SetPrimaryPartCFrame(CFrame.new(position))
	elseif model:IsA("BasePart") then
		model.Position = position
		model.Size = GlobalBreakingConfig.BlockSize
		model.Anchored = true
		model.CanCollide = true
	end

	local targetPart
	if model:IsA("Model") and model.PrimaryPart then
		targetPart = model.PrimaryPart
	elseif model:IsA("BasePart") then
		targetPart = model
	else
		targetPart = model
	end

	local idValue = Instance.new("StringValue")
	idValue.Name = "BreakableId"
	idValue.Value = breakableId
	idValue.Parent = targetPart

	local playerIdValue = Instance.new("IntValue")
	playerIdValue.Name = "PlayerId"
	playerIdValue.Value = GlobalBreakingConfig.GlobalPlayerId
	playerIdValue.Parent = targetPart

	local materialValue = Instance.new("StringValue")
	materialValue.Name = "MaterialType"
	materialValue.Value = materialType
	materialValue.Parent = targetPart

	model.Parent = containerFolder

	return model
end

local function placeBedrockBlock(x: number, y: number, z: number)
	local key = encodeKey(x, y, z)
	if placedBlocks[key] then return end

	local position = gridToWorldPosition(x, y, z)
	local itemConfig = ItemData.GetItem("Bedrock")
	if not itemConfig or not itemConfig.buildingPartPath then return end

	local pathParts = string.split(itemConfig.buildingPartPath, ".")
	local current = ReplicatedStorage
	local startIndex = 1
	if pathParts[1] == "ReplicatedStorage" then startIndex = 2 end
	for i = startIndex, #pathParts do
		current = current:FindFirstChild(pathParts[i])
		if not current then return end
	end

	local model = current:Clone()
	model.Name = "Bedrock_" .. key

	if model:IsA("Model") and model.PrimaryPart then
		model:SetPrimaryPartCFrame(CFrame.new(position))
	elseif model:IsA("BasePart") then
		model.Position = position
		model.Size = GlobalBreakingConfig.BlockSize
		model.Anchored = true
		model.CanCollide = true
	end

	model.Parent = containerFolder
	placedBlocks[key] = model
end

local function placeBlockImmediate(x: number, y: number, z: number, materialType: string)
	if materialType == "Bedrock" then
		placeBedrockBlock(x, y, z)
		return
	end

	local key = encodeKey(x, y, z)
	if placedBlocks[key] then return end

	local position = gridToWorldPosition(x, y, z)
	local breakableId = makeBreakableId(x, y, z)
	local model = createBlockModel(materialType, position, breakableId)
	if not model then return end

	placedBlocks[key] = model

	BreakingService:RegisterGlobalBreakable(breakableId, {
		materialType = materialType,
		dropItem = materialType,
		dropAmount = 1,
		position = position,
		part = model,
	})
end

local function placeLayer(y: number, materialType: string?, biome: {}?)
	local gridX = GlobalBreakingConfig.GridSizeX
	local gridZ = GlobalBreakingConfig.GridSizeZ
	local mat
	if biome then
		if y == 0 then
			mat = biome.topMaterial or biome.material or "Stone"
		elseif y == -1 then
			mat = biome.subMaterial or biome.material or "Stone"
		else
			mat = biome.material or "Stone"
		end
	else
		mat = materialType or "Stone"
	end

	for x = 0, gridX - 1 do
		for z = 0, gridZ - 1 do
			table.insert(placementQueue, {x = x, y = y, z = z, materialType = mat})
		end
	end
end

--|| Mountain Generation ||--

local function generateMountainHeightmap()
	heightmap = {}
	local noise = GlobalBreakingConfig.MountainNoise
	local gridX = GlobalBreakingConfig.GridSizeX
	local gridZ = GlobalBreakingConfig.GridSizeZ

	local seedOffset = (currentSeed % 10000) / 10
	local edgeFade = 5

	for x = 0, gridX - 1 do
		heightmap[x] = {}
		for z = 0, gridZ - 1 do
			local height = noise.BaseHeight
			local frequency = noise.Scale
			local amplitude = noise.Amplitude

			for _ = 1, noise.Octaves do
				local noiseVal = math.noise(x * frequency, z * frequency, seedOffset)
				height = height + noiseVal * amplitude
				frequency = frequency * noise.Lacunarity
				amplitude = amplitude * noise.Persistence
			end

			local distFromEdge = math.min(x, z, (gridX - 1) - x, (gridZ - 1) - z)
			local fade = math.clamp(distFromEdge / edgeFade, 0, 1)
			local aboveBase = math.max(0, height - noise.BaseHeight) * fade
			height = noise.BaseHeight + aboveBase

			heightmap[x][z] = math.max(0, math.floor(height))
		end
	end
end

local function generateMountain()
	generateMountainHeightmap()

	local gridX = GlobalBreakingConfig.GridSizeX
	local gridZ = GlobalBreakingConfig.GridSizeZ

	-- Place above-ground blocks
	for x = 0, gridX - 1 do
		for z = 0, gridZ - 1 do
			local columnHeight = heightmap[x] and heightmap[x][z] or 0
			for y = 1, columnHeight do
				local normalizedHeight = columnHeight > 0 and (y / columnHeight) or 0
				local mat = BiomeData.GetMaterialAtHeight("Mountain", normalizedHeight)
				table.insert(placementQueue, {x = x, y = y, z = z, materialType = mat})
			end
		end
	end

	-- Place ground + underground layers
	local initialLayers = GlobalBreakingConfig.InitialUndergroundLayers
	local biome = BiomeData.Biomes.Mountain
	for y = 0, -(initialLayers - 1), -1 do
		placeLayer(y, nil, biome)
	end

	-- Place bedrock floor at the bottom
	local bedrockY = -(GlobalBreakingConfig.MaxDepth + 1)
	placeLayer(bedrockY, "Bedrock")

	lowestRevealedY = -(initialLayers - 1)
end

--|| Floating Island Generation ||--

local function generateFloatingIslands()
	-- Base terrain identical to Mountain
	generateMountain()

	local biome = BiomeData.Biomes.FloatingIsland
	local gridX = GlobalBreakingConfig.GridSizeX
	local gridZ = GlobalBreakingConfig.GridSizeZ

	local rng = Random.new(currentSeed)
	local islandCount = rng:NextInteger(biome.islandCount[1], biome.islandCount[2])

	-- Start the chain near the center of the grid at minimum height
	local prevCenterX = math.floor(gridX / 2)
	local prevCenterZ = math.floor(gridZ / 2)
	local prevRadius = rng:NextInteger(biome.islandRadius[1], biome.islandRadius[2])
	local currentY = biome.minHeight

	local function placeIsland(centerX, centerZ, centerY, radius)
		local heightVariation = math.max(2, math.floor(radius * 0.7))
		for dx = -radius, radius do
			for dz = -radius, radius do
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist <= radius then
					local falloff = 1 - (dist / radius)
					local columnHeight = math.max(1, math.floor(heightVariation * falloff + 0.5))
					local x = centerX + dx
					local z = centerZ + dz
					if x >= 0 and x < gridX and z >= 0 and z < gridZ then
						for dy = 0, columnHeight - 1 do
							local normalizedHeight = (dy + 1) / columnHeight
							local mat = BiomeData.GetMaterialAtHeight("FloatingIsland", normalizedHeight)
							table.insert(placementQueue, {x = x, y = centerY + dy, z = z, materialType = mat})
						end
						for dy = 1, columnHeight - 1 do
							table.insert(placementQueue, {x = x, y = centerY - dy, z = z, materialType = biome.material})
						end
					end
				end
			end
		end
	end

	placeIsland(prevCenterX, prevCenterZ, currentY, prevRadius)

	for _ = 2, islandCount do
		local radius = rng:NextInteger(biome.islandRadius[1], biome.islandRadius[2])

		-- Next island is placed just outside jump range from the previous island edge
		-- Distance between centers = prevRadius + radius + gap (1-2 blocks)
		local gap = rng:NextInteger(1, biome.maxJumpGap)
		local minDist = prevRadius + radius + gap
		local maxDist = minDist + 2

		local angle = rng:NextNumber() * math.pi * 2
		local dist = rng:NextInteger(minDist, maxDist)
		local centerX = math.floor(prevCenterX + math.cos(angle) * dist + 0.5)
		local centerZ = math.floor(prevCenterZ + math.sin(angle) * dist + 0.5)

		-- Clamp to grid bounds
		centerX = math.clamp(centerX, radius, gridX - 1 - radius)
		centerZ = math.clamp(centerZ, radius, gridZ - 1 - radius)

		-- Step height up by 1-2 blocks each island
		local heightStep = rng:NextInteger(biome.heightStep[1], biome.heightStep[2])
		currentY = math.min(currentY + heightStep, biome.maxHeight)

		placeIsland(centerX, centerZ, currentY, radius)

		prevCenterX = centerX
		prevCenterZ = centerZ
		prevRadius = radius
	end
end

--|| Core Functions ||--

local function destroyAllBlocks()
	for key, part in pairs(placedBlocks) do
		local parts = string.split(key, ",")
		local x, y, z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
		local breakableId = makeBreakableId(x, y, z)
		BreakingService:UnregisterGlobalBreakable(breakableId)
		if part and part.Parent then
			part:Destroy()
		end
	end

	placedBlocks = {}
	placementQueue = {}
	heightmap = {}
	lowestRevealedY = 0
end

local function pickRandomBiome(): string
	local biomeNames = {}
	for name, _ in pairs(BiomeData.Biomes) do
		table.insert(biomeNames, name)
	end
	return biomeNames[math.random(1, #biomeNames)]
end

local function generateAndPlace()
	currentSeed = os.time() + math.random(1, 10000)
	currentBiome = pickRandomBiome()

	local biome = BiomeData.Biomes[currentBiome]
	if not biome then
		currentBiome = BiomeData.DefaultBiome
		biome = BiomeData.Biomes[currentBiome]
	end

	if biome.generationType == "heightmap" then
		generateMountain()
	elseif biome.generationType == "islands" then
		generateFloatingIslands()
	end
end

local function revealNextUndergroundLayer()
	local nextY = lowestRevealedY - 1
	if nextY < -GlobalBreakingConfig.MaxDepth then return end

	lowestRevealedY = nextY

	local biome = BiomeData.Biomes[currentBiome]
	placeLayer(nextY, nil, biome)
end

local function parseBreakableId(breakableId: string): (number?, number?, number?)
	local prefix = "global_"
	if string.sub(breakableId, 1, #prefix) ~= prefix then return nil, nil, nil end

	local rest = string.sub(breakableId, #prefix + 1)
	local x, y, z = string.match(rest, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")
	if not x then return nil, nil, nil end

	return tonumber(x), tonumber(y), tonumber(z)
end

local function onGlobalBreakableDestroyed(player: Player, breakableId: string, dropItem: string, position: Vector3)
	local x, y, z = parseBreakableId(breakableId)
	if not x then return end

	local key = encodeKey(x, y, z)
	placedBlocks[key] = nil

	if y == lowestRevealedY then
		revealNextUndergroundLayer()
	end
end

local function processPlacementQueue()
	if #placementQueue == 0 then return end

	local batchSize = GlobalBreakingConfig.PlacementBatchSize
	for _ = 1, math.min(batchSize, #placementQueue) do
		local entry = table.remove(placementQueue, 1)
		if entry then
			placeBlockImmediate(entry.x, entry.y, entry.z, entry.materialType)
		end
	end
end

local function startCycleTimer()
	cycleStartTime = tick()

	task.spawn(function()
		while true do
			local elapsed = tick() - cycleStartTime
			local remaining = math.max(0, GlobalBreakingConfig.CycleDuration - elapsed)

			for _, p in ipairs(Players:GetPlayers()) do
				GlobalBreakingAreaService.Client.CycleTimeRemaining:Fire(p, math.ceil(remaining))
			end

			if remaining <= 0 then
				for _, p in ipairs(Players:GetPlayers()) do
					GlobalBreakingAreaService.Client.CycleReset:Fire(p)
				end

				destroyAllBlocks()
				generateAndPlace()

				cycleStartTime = tick()
			end

			task.wait(GlobalBreakingConfig.TimerUpdateInterval)
		end
	end)
end

function GlobalBreakingAreaService:KnitInit()
	local originPart = Workspace:FindFirstChild(GlobalBreakingConfig.OriginPartName)
	if originPart then
		originPosition = originPart.Position
	else
		warn("[GlobalBreakingAreaService] Origin part not found:", GlobalBreakingConfig.OriginPartName)
		originPosition = Vector3.zero
	end

	containerFolder = Workspace:FindFirstChild("GlobalBreakingBlocks")
	if not containerFolder then
		containerFolder = Instance.new("Folder")
		containerFolder.Name = "GlobalBreakingBlocks"
		containerFolder.Parent = Workspace
	end
end

function GlobalBreakingAreaService:KnitStart()
	BreakingService = Knit.GetService("BreakingService")

	BreakingService.BreakableDestroyed:Connect(onGlobalBreakableDestroyed)

	generateAndPlace()

	RunService.Heartbeat:Connect(processPlacementQueue)

	startCycleTimer()
end

return GlobalBreakingAreaService
