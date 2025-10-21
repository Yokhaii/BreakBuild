-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Player
local player = Players.LocalPlayer

-- Data
local MaterialData = require(ReplicatedStorage.Shared.Data.MaterialData)

-- BreakingController
local BreakingController = Knit.CreateController({
	Name = "BreakingController",
})

-- Constants
local GRID_ROWS = 6
local GRID_COLS = 7
local FLOAT_HEIGHT = 0.5 -- How high materials float up and down
local FLOAT_DURATION = 2 -- Duration of one float cycle
local FALL_SPEED = 0.3 -- Duration for falling animation
local SPAWN_DURATION = 0.4 -- Duration for spawn animation
local COLLECTION_DURATION = 0.5 -- Duration for collection tween animation (configurable)

-- Types
type MaterialInstance = {
	model: Model,
	baseTween: Tween?,
	basePosition: Vector3,
}

-- Private variables
local BreakingService
local materialInstances: {{MaterialInstance?}} = {}
local gridData: {{string}} = {}
local heldMaterialModel: Model? = nil -- Currently held material model
local heldMaterialWeld: WeldConstraint? = nil -- Weld holding material to player

--|| Local Functions ||--

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

-- Create floating tween animation
local function createFloatTween(model: Model, basePosition: Vector3): Tween
	if not model.PrimaryPart then
		warn("Model has no PrimaryPart for float tween:", model.Name)
		return nil
	end

	local baseCFrame = CFrame.new(basePosition)
	local floatCFrame = baseCFrame + Vector3.new(0, FLOAT_HEIGHT, 0)

	local tweenInfo = TweenInfo.new(
		FLOAT_DURATION,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- Repeat infinitely
		true -- Reverse
	)

	local tween = TweenService:Create(model.PrimaryPart, tweenInfo, {
		CFrame = floatCFrame
	})

	return tween
end

-- Create collection animation (material flies to player)
local function playCollectionAnimation(x: number, y: number, materialType: string)
	-- Get the material's current position
	local startPosition = getAttachmentPosition(x, y)
	if not startPosition then
		warn("Failed to get position for collection animation:", x, y)
		return
	end

	-- Get player's character
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	-- Find material in ReplicatedStorage
	local materialsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if materialsFolder then
		materialsFolder = materialsFolder:FindFirstChild("Materials")
	end

	if not materialsFolder then
		warn("Assets/Materials folder not found in ReplicatedStorage!")
		return
	end

	local materialTemplate = materialsFolder:FindFirstChild(materialType)
	if not materialTemplate or not materialTemplate:IsA("Model") then
		warn("Material model not found for collection:", materialType)
		return
	end

	-- Clone the material for the animation
	local materialClone = materialTemplate:Clone()

	-- Set initial position
	if materialClone.PrimaryPart then
		materialClone:SetPrimaryPartCFrame(CFrame.new(startPosition))
	else
		warn("Material clone has no PrimaryPart:", materialType)
		materialClone:Destroy()
		return
	end

	materialClone.Parent = Workspace

	-- Create tween to player
	local tweenInfo = TweenInfo.new(
		COLLECTION_DURATION,
		Enum.EasingStyle.Exponential,
		Enum.EasingDirection.Out
	)

	-- Tween position and scale (shrink using model Scale)
	local targetCFrame = humanoidRootPart.CFrame
	local targetScale = 0.1 -- Shrink to 10% of original size

	-- Find the Scale value in the model (Roblox models have a Scale NumberValue)
	local scaleValue = materialClone:FindFirstChild("Scale", true)

	local positionTween = TweenService:Create(materialClone.PrimaryPart, tweenInfo, {
		CFrame = targetCFrame
	})

	local scaleTween = nil
	if scaleValue and scaleValue:IsA("NumberValue") then
		scaleTween = TweenService:Create(scaleValue, tweenInfo, {
			Value = scaleValue.Value * targetScale
		})
	end

	-- Play tweens
	positionTween:Play()
	if scaleTween then
		scaleTween:Play()
	end

	-- Destroy the clone after animation completes
	task.delay(COLLECTION_DURATION, function()
		materialClone:Destroy()
	end)
end

-- Create material model instance at position
local function createMaterialInstance(x: number, y: number, materialType: string): MaterialInstance?
	if materialType == "" then return nil end

	-- Get attachment position
	local position = getAttachmentPosition(x, y)
	if not position then
		warn("Failed to get position for", x, y)
		return nil
	end

	-- Find material in ReplicatedStorage
	local materialsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if materialsFolder then
		materialsFolder = materialsFolder:FindFirstChild("Materials")
	end

	if not materialsFolder then
		warn("Assets/Materials folder not found in ReplicatedStorage!")
		return nil
	end

	local materialTemplate = materialsFolder:FindFirstChild(materialType)
	if not materialTemplate or not materialTemplate:IsA("Model") then
		warn("Material model not found:", materialType)
		return nil
	end

	-- Clone the material
	local materialModel = materialTemplate:Clone()

	-- Set position
	if materialModel.PrimaryPart then
		materialModel:SetPrimaryPartCFrame(CFrame.new(position))
	else
		warn("Material model has no PrimaryPart:", materialType)
		materialModel:Destroy()
		return nil
	end

	materialModel.Parent = Workspace

	-- Create floating animation
	local floatTween = createFloatTween(materialModel, position)
	floatTween:Play()

	return {
		model = materialModel,
		baseTween = floatTween,
		basePosition = position,
	}
end

-- Remove material instance
local function removeMaterialInstance(x: number, y: number)
	if not materialInstances[x] or not materialInstances[x][y] then return end

	local instance = materialInstances[x][y]
	if instance then
		if instance.baseTween then
			instance.baseTween:Cancel()
		end
		if instance.model then
			instance.model:Destroy()
		end
		materialInstances[x][y] = nil
	end
end

-- Animate material destruction
local function animateDestroy(x: number, y: number, isMatch: boolean)
	local instance = materialInstances[x][y]
	if not instance or not instance.model then return end

	-- Cancel float tween
	if instance.baseTween then
		instance.baseTween:Cancel()
	end

	-- Create destruction animation (shrink and fade)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)

	-- Animate all parts
	for _, part in ipairs(instance.model:GetDescendants()) do
		if part:IsA("BasePart") then
			local destroyTween = TweenService:Create(part, tweenInfo, {
				Transparency = 1,
				Size = part.Size * 0.1
			})
			destroyTween:Play()
		end
	end

	-- Remove after animation
	task.delay(0.3, function()
		removeMaterialInstance(x, y)
	end)
end

-- Animate material falling
local function animateFall(fromX: number, fromY: number, toX: number, toY: number)
	local instance = materialInstances[fromX][fromY]
	if not instance or not instance.model or not instance.model.PrimaryPart then return end

	-- Cancel float tween
	if instance.baseTween then
		instance.baseTween:Cancel()
	end

	-- Get target position
	local targetPosition = getAttachmentPosition(toX, toY)
	if not targetPosition then return end

	-- Calculate offset from current position to maintain model orientation
	local currentCFrame = instance.model.PrimaryPart.CFrame
	local targetCFrame = CFrame.new(targetPosition)

	-- Animate fall using CFrame
	local tweenInfo = TweenInfo.new(FALL_SPEED, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	local fallTween = TweenService:Create(instance.model.PrimaryPart, tweenInfo, {
		CFrame = targetCFrame
	})

	fallTween:Play()

	-- Update instance data
	instance.basePosition = targetPosition
	materialInstances[toX][toY] = instance
	materialInstances[fromX][fromY] = nil

	-- Restart float animation after fall
	fallTween.Completed:Connect(function()
		instance.baseTween = createFloatTween(instance.model, targetPosition)
		if instance.baseTween then
			instance.baseTween:Play()
		end
	end)
end

-- Animate material spawning
local function animateSpawn(x: number, y: number, materialType: string)
	-- Create new instance
	local instance = createMaterialInstance(x, y, materialType)
	if not instance then
		warn("Failed to create material instance for spawn at", x, y, materialType)
		return
	end

	-- Store original properties before modifying
	local originalProperties = {}
	for _, part in ipairs(instance.model:GetDescendants()) do
		if part:IsA("BasePart") then
			originalProperties[part] = {
				Size = part.Size,
				Transparency = part.Transparency
			}
			-- Start small and invisible
			part.Size = part.Size * 0.1
			part.Transparency = 1
		end
	end

	-- Store in grid immediately
	materialInstances[x][y] = instance

	-- Animate spawn (grow and fade in)
	local tweenInfo = TweenInfo.new(SPAWN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	for part, props in pairs(originalProperties) do
		local spawnTween = TweenService:Create(part, tweenInfo, {
			Size = props.Size,
			Transparency = props.Transparency
		})
		spawnTween:Play()
	end
end

-- Initialize material instances from grid
local function initializeMaterialInstances()
	-- Clear existing instances
	for x = 1, GRID_ROWS do
		materialInstances[x] = {}
		for y = 1, GRID_COLS do
			removeMaterialInstance(x, y)
		end
	end

	-- Create new instances
	for x = 1, GRID_ROWS do
		for y = 1, GRID_COLS do
			if gridData[x] and gridData[x][y] and gridData[x][y] ~= "" then
				materialInstances[x][y] = createMaterialInstance(x, y, gridData[x][y])
			end
		end
	end
end

-- Update grid visualization
local function updateGridVisualization(newGridData: {{string}})
	if not newGridData then return end

	gridData = newGridData

	-- Update all cells
	for x = 1, GRID_ROWS do
		for y = 1, GRID_COLS do
			local oldMaterial = materialInstances[x] and materialInstances[x][y]
			local newMaterialType = gridData[x] and gridData[x][y] or ""

			if newMaterialType == "" then
				-- Material removed
				if oldMaterial then
					removeMaterialInstance(x, y)
				end
			else
				-- Material exists
				if not oldMaterial then
					-- New material spawned
					materialInstances[x][y] = createMaterialInstance(x, y, newMaterialType)
				end
			end
		end
	end
end

-- Handle material grab
local function handleMaterialGrabbed(x: number, y: number, materialType: string)
	local instance = materialInstances[x][y]
	if not instance or not instance.model then
		warn("No material instance to grab at", x, y)
		return
	end

	-- Cancel float animation
	if instance.baseTween then
		instance.baseTween:Cancel()
	end

	-- Get player character
	local character = player.Character
	if not character then
		warn("No character found")
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		warn("No HumanoidRootPart found")
		return
	end

	-- Get hold position (check for attachment or use default)
	local holdCFrame
	local holdAttachment = humanoidRootPart:FindFirstChild("HeldMaterialAttachment")
	if holdAttachment and holdAttachment:IsA("Attachment") then
		holdCFrame = humanoidRootPart.CFrame * holdAttachment.CFrame
	else
		-- Use default offset from MaterialData
		holdCFrame = humanoidRootPart.CFrame * MaterialData.HoldConfig.defaultHoldOffset
	end

	-- Move model to hold position
	if instance.model.PrimaryPart then
		-- Unanchor the PrimaryPart so it can be welded to player
		instance.model.PrimaryPart.Anchored = false

		-- Set position
		instance.model:SetPrimaryPartCFrame(holdCFrame)

		-- Create weld to attach to player
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = humanoidRootPart
		weld.Part1 = instance.model.PrimaryPart
		weld.Parent = instance.model.PrimaryPart

		heldMaterialModel = instance.model
		heldMaterialWeld = weld
	end

	print(string.format("Grabbed material %s at (%d, %d)", materialType, x, y))
end

-- Handle material placement
local function handleMaterialPlaced(fromX: number, fromY: number, toX: number, toY: number)
	-- Destroy weld
	if heldMaterialWeld then
		heldMaterialWeld:Destroy()
		heldMaterialWeld = nil
	end

	-- The material swap happens on server, so we just need to move visuals
	local fromInstance = materialInstances[fromX][fromY]
	local toInstance = materialInstances[toX][toY]

	-- Get target positions
	local fromTargetPos = getAttachmentPosition(toX, toY)
	local toTargetPos = getAttachmentPosition(fromX, fromY)

	-- Swap the grid data to match server
	local tempMaterial = gridData[fromX][fromY]
	gridData[fromX][fromY] = gridData[toX][toY]
	gridData[toX][toY] = tempMaterial

	-- Clear the old positions temporarily
	materialInstances[fromX][fromY] = nil
	materialInstances[toX][toY] = nil

	-- Move the held material to its new position
	if fromInstance and fromInstance.model and fromInstance.model.PrimaryPart and fromTargetPos then
		-- Re-anchor the part after unwelding
		fromInstance.model.PrimaryPart.Anchored = true

		-- Animate to new position
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(fromInstance.model.PrimaryPart, tweenInfo, {
			CFrame = CFrame.new(fromTargetPos)
		})
		tween:Play()

		fromInstance.basePosition = fromTargetPos

		-- Restart float animation after placement
		tween.Completed:Connect(function()
			fromInstance.baseTween = createFloatTween(fromInstance.model, fromTargetPos)
			if fromInstance.baseTween then
				fromInstance.baseTween:Play()
			end
		end)

		-- Update to new position
		materialInstances[toX][toY] = fromInstance
	end

	-- Move the other material if it exists
	if toInstance and toInstance.model and toInstance.model.PrimaryPart and toTargetPos then
		-- Animate to new position
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(toInstance.model.PrimaryPart, tweenInfo, {
			CFrame = CFrame.new(toTargetPos)
		})
		tween:Play()

		toInstance.basePosition = toTargetPos

		-- Restart float animation
		tween.Completed:Connect(function()
			toInstance.baseTween = createFloatTween(toInstance.model, toTargetPos)
			if toInstance.baseTween then
				toInstance.baseTween:Play()
			end
		end)

		-- Update to new position
		materialInstances[fromX][fromY] = toInstance
	end

	heldMaterialModel = nil

	print(string.format("Placed material from (%d, %d) to (%d, %d)", fromX, fromY, toX, toY))
	print(string.format("Client grid after swap: (%d,%d)=%s, (%d,%d)=%s",
		fromX, fromY, gridData[fromX][fromY] or "nil",
		toX, toY, gridData[toX][toY] or "nil"))
end

--|| Functions ||--

function BreakingController:KnitStart()
	BreakingService = Knit.GetService("BreakingService")

	-- Listen for grid updates
	BreakingService.GridUpdated:Connect(function(newGridData)
		updateGridVisualization(newGridData)
	end)

	-- Listen for material destroyed
	BreakingService.MaterialDestroyed:Connect(function(x, y, isMatch)
		animateDestroy(x, y, isMatch)
	end)

	-- Listen for material collected (for tween animation)
	BreakingService.MaterialCollected:Connect(function(x, y, materialType)
		playCollectionAnimation(x, y, materialType)
	end)

	-- Listen for material moved/fallen
	BreakingService.MaterialMoved:Connect(function(fromX, fromY, toX, toY)
		animateFall(fromX, fromY, toX, toY)
	end)

	-- Listen for material spawned
	BreakingService.MaterialSpawned:Connect(function(x, y, materialType)
		print(string.format("Client received MaterialSpawned: x=%d, y=%d, material=%s", x, y, materialType))
		task.wait(0.2) -- Small delay before spawning
		animateSpawn(x, y, materialType)
	end)

	-- Listen for material grabbed
	BreakingService.MaterialGrabbed:Connect(function(x, y, materialType)
		handleMaterialGrabbed(x, y, materialType)
	end)

	-- Listen for material placed
	BreakingService.MaterialPlaced:Connect(function(fromX, fromY, toX, toY)
		handleMaterialPlaced(fromX, fromY, toX, toY)
	end)

	-- Initialize grid
	task.wait(2) -- Wait for character to load
	local success, initialGrid = BreakingService:GetGrid():await()
	if success and initialGrid then
		gridData = initialGrid
		initializeMaterialInstances()
	end
end

return BreakingController
