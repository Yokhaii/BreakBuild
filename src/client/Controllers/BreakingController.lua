--[[
	BreakingController.lua
	Unified client-side breaking controller
	- Detects ANY breakable object (blocks, tree logs, rocks, etc.)
	- Shows preview highlight when hovering
	- Sends break requests to BreakingService
	- Handles visual feedback (animations, VFX)
	- Plays spawn animations for blocks (from BreakingAreaService)
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Animation = require(Packages.Animation)

-- Player
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Data & Config
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local MaterialData = require(ReplicatedStorage.Shared.Data.MaterialData)
local BreakingConfig = require(ReplicatedStorage.Shared.Config.BreakingConfig)

-- BreakingController
local BreakingController = Knit.CreateController({
	Name = "BreakingController",
})

-- Constants
local HIGHLIGHT_PREVIEW_COLOR = Color3.fromRGB(255, 255, 255)

-- Types
type BreakableData = {
	id: string,
	materialType: string,
	position: Vector3,
}

-- Private variables
local BreakingService
local BreakingAreaService
local InventoryController
local breakableData: {[string]: BreakableData} = {} -- Track breakable positions
local isMouseDown = false
local currentBreakingId: string? = nil
local currentBreakingProgress: number = 0

-- Client-side humanoid animation state
local isPlayingMiningAnimation = false

-- Preview state
local hoveredBreakableId: string? = nil
local previewHighlight: Highlight? = nil
local previewBillboard: BillboardGui? = nil

-- Spawn animation state (for blocks)
local animatingBlocks: {[string]: Model} = {}

-- Breaking shake animation state
local shakeModel: (Model | BasePart)? = nil
local shakeOriginalCFrame: CFrame? = nil
local SHAKE_BASE_FREQUENCY = 2
local SHAKE_MAX_FREQUENCY = 10
local SHAKE_AMPLITUDE = 0.05

-- Breaking VFX state
local breakingVFXParticles: {ParticleEmitter} = {}
local breakingVFXScalable: {ParticleEmitter} = {} -- Square_50, Square_200 that scale with progress
local breakingVFXBaseRates: {[ParticleEmitter]: number} = {} -- Store base rates
local breakingColor: Color3? = nil
local VFX_FOLDER_PATH = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Breaking"):WaitForChild("4x4")

-- References
local breakingZone = nil

--|| Animation Functions ||--

-- Create a local model for spawn animation (blocks only)
local function createLocalBlockModel(materialType: string, position: Vector3, blockId: string): Model?
	local itemConfig = ItemData.GetItem(materialType)
	if not itemConfig or not itemConfig.buildingPartPath then
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
			return nil
		end
	end

	if not current:IsA("Model") and not current:IsA("BasePart") then
		return nil
	end

	local model = current:Clone()
	model.Name = "SpawnAnim_" .. blockId

	if model:IsA("Model") and model.PrimaryPart then
		model:SetPrimaryPartCFrame(CFrame.new(position))
	elseif model:IsA("BasePart") then
		model.Position = position
		model.Size = BreakingConfig.BlockSize
		model.Anchored = true
		model.CanCollide = false
	end

	-- Make parts non-collidable during animation
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	return model
end

-- Animate a model/part from start to end position over duration
local function animatePosition(model: Instance, startPos: Vector3, endPos: Vector3, duration: number, easingStyle: Enum.EasingStyle, easingDir: Enum.EasingDirection)
	local startTime = tick()
	local isModel = model:IsA("Model")

	while true do
		local elapsed = tick() - startTime
		local alpha = math.clamp(elapsed / duration, 0, 1)

		-- Apply easing
		local easedAlpha = TweenService:GetValue(alpha, easingStyle, easingDir)
		local currentPos = startPos:Lerp(endPos, easedAlpha)

		if isModel and model.PrimaryPart then
			model:PivotTo(CFrame.new(currentPos))
		elseif model:IsA("BasePart") then
			model.Position = currentPos
		end

		if alpha >= 1 then break end
		RunService.Heartbeat:Wait()
	end
end

-- Play spawn animation for a block
local function playSpawnAnimation(blockData: {id: string, materialType: string, position: Vector3})
	local blockId = blockData.id
	local finalPosition = blockData.position

	local model = createLocalBlockModel(blockData.materialType, finalPosition, blockId)
	if not model then return end

	-- Start position (underground)
	local startY = finalPosition.Y + BreakingConfig.SpawnStartOffset
	local overshootY = finalPosition.Y + BreakingConfig.SpawnOvershootHeight
	local startPos = Vector3.new(finalPosition.X, startY, finalPosition.Z)
	local overshootPos = Vector3.new(finalPosition.X, overshootY, finalPosition.Z)

	-- Set initial position
	if model:IsA("Model") and model.PrimaryPart then
		model:PivotTo(CFrame.new(startPos))
	elseif model:IsA("BasePart") then
		model.Position = startPos
	end

	-- Parent to workspace
	local zone = breakingZone or Workspace
	model.Parent = zone

	animatingBlocks[blockId] = model

	-- Animation phases
	local phase1Duration = BreakingConfig.SpawnAnimationDuration * 0.6
	local phase2Duration = BreakingConfig.SpawnAnimationDuration * 0.4

	-- Phase 1: Rise up with overshoot
	animatePosition(model, startPos, overshootPos, phase1Duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	-- Phase 2: Settle to final position
	animatePosition(model, overshootPos, finalPosition, phase2Duration, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)

	-- Cleanup
	if animatingBlocks[blockId] then
		animatingBlocks[blockId]:Destroy()
		animatingBlocks[blockId] = nil
	end
end

--|| Mining Animation ||--

local function startMiningAnimation()
	local character = player.Character
	if not character then return end
	Animation:PlayAnim("Humanoid_Mining", character)
	isPlayingMiningAnimation = true
end

local function stopMiningAnimation()
	local character = player.Character
	if not character then return end
	Animation:StopAnim("Humanoid_Mining", character)
	isPlayingMiningAnimation = false
end

--|| Shake Animation ||--

local function startShakeAnimation(model: Model | BasePart)
	if model:IsA("Model") and model.PrimaryPart then
		shakeModel = model
		shakeOriginalCFrame = model.PrimaryPart.CFrame
	elseif model:IsA("BasePart") then
		shakeModel = model
		shakeOriginalCFrame = model.CFrame
	end
end

local function stopShakeAnimation()
	if shakeModel and shakeOriginalCFrame then
		if shakeModel:IsA("Model") and shakeModel.PrimaryPart then
			shakeModel:SetPrimaryPartCFrame(shakeOriginalCFrame)
		elseif shakeModel:IsA("BasePart") then
			shakeModel.CFrame = shakeOriginalCFrame
		end
	end
	shakeModel = nil
	shakeOriginalCFrame = nil
end

local function updateShakeAnimation(progress: number)
	if not shakeModel or not shakeOriginalCFrame then return end

	local frequency = SHAKE_BASE_FREQUENCY + (SHAKE_MAX_FREQUENCY - SHAKE_BASE_FREQUENCY) * progress
	local time = tick()
	local offset = math.sin(time * frequency * math.pi * 2) * SHAKE_AMPLITUDE

	-- Shake up/down (Y axis)
	local newCFrame = shakeOriginalCFrame * CFrame.new(0, offset, 0)

	if shakeModel:IsA("Model") and shakeModel.PrimaryPart then
		shakeModel:SetPrimaryPartCFrame(newCFrame)
	elseif shakeModel:IsA("BasePart") then
		shakeModel.CFrame = newCFrame
	end
end

--|| Breaking VFX ||--

local function startBreakingVFX(model: Model | BasePart)
	-- Get color from material
	local materialValue
	if model:IsA("Model") and model.PrimaryPart then
		materialValue = model.PrimaryPart:FindFirstChild("MaterialType")
	else
		materialValue = model:FindFirstChild("MaterialType")
	end

	if materialValue then
		local matProps = MaterialData.GetProperties(materialValue.Value)
		if matProps then
			breakingColor = matProps.color
		end
	end

	-- Find target part
	local targetPart
	if model:IsA("Model") and model.PrimaryPart then
		targetPart = model.PrimaryPart
	elseif model:IsA("BasePart") then
		targetPart = model
	end

	if not targetPart then return end

	-- Try to get VFX from folder
	local vfxFolder = ReplicatedStorage:FindFirstChild("Assets")
	if vfxFolder then
		vfxFolder = vfxFolder:FindFirstChild("VFX")
		if vfxFolder then
			vfxFolder = vfxFolder:FindFirstChild("Breaking")
			if vfxFolder then
				vfxFolder = vfxFolder:FindFirstChild("4x4")
			end
		end
	end

	if vfxFolder then
		-- Use existing VFX emitters: Emit_50, Square_50, Square_200
		local emitterNames = {"Emit_50", "Square_50", "Square_200"}
		for _, emitterName in ipairs(emitterNames) do
			local emitterTemplate = vfxFolder:FindFirstChild(emitterName)
			if emitterTemplate and emitterTemplate:IsA("ParticleEmitter") then
				local emitter = emitterTemplate:Clone()
				if breakingColor then
					emitter.Color = ColorSequence.new(breakingColor)
				end
				emitter.Parent = targetPart
				emitter.Enabled = true
				table.insert(breakingVFXParticles, emitter)

				-- Track Square_50 and Square_200 for rate scaling based on progress
				if emitterName == "Square_50" or emitterName == "Square_200" then
					breakingVFXBaseRates[emitter] = emitter.Rate
					emitter.Rate = emitter.Rate / 5 -- Start at 1/5 of base rate
					table.insert(breakingVFXScalable, emitter)
				end
			end
		end
	else
		-- Fallback: create simple particles
		local attachment = Instance.new("Attachment")
		attachment.Parent = targetPart

		local particle = Instance.new("ParticleEmitter")
		particle.Color = ColorSequence.new(breakingColor or Color3.new(0.5, 0.5, 0.5))
		particle.Size = NumberSequence.new(0.3, 0)
		particle.Lifetime = NumberRange.new(0.3, 0.6)
		particle.Rate = 20
		particle.Speed = NumberRange.new(3, 6)
		particle.SpreadAngle = Vector2.new(45, 45)
		particle.Parent = attachment

		table.insert(breakingVFXParticles, particle)
	end
end

local function updateBreakingVFX(progress: number)
	-- Scale Square_50 and Square_200 rate from 1/5 to full based on progress
	for _, emitter in ipairs(breakingVFXScalable) do
		local baseRate = breakingVFXBaseRates[emitter]
		if baseRate then
			-- Lerp from baseRate/5 to baseRate based on progress
			local minRate = baseRate / 5
			emitter.Rate = minRate + (baseRate - minRate) * progress
		end
	end
end

local function stopBreakingVFX()
	for _, particle in ipairs(breakingVFXParticles) do
		if particle then
			particle.Enabled = false
			-- Clean up after particles fade
			task.delay(1, function()
				if particle and particle.Parent then
					particle:Destroy()
				end
			end)
		end
	end
	breakingVFXParticles = {}
	breakingVFXScalable = {}
	breakingVFXBaseRates = {}
	breakingColor = nil
end

--|| Tool Checking ||--

local function getToolConfig()
	if not InventoryController then
		return { toolTier = BreakingConfig.BareHandToolTier, breakSpeed = BreakingConfig.BareHandBreakSpeed, isBareHand = true }
	end

	local inventory = InventoryController:GetInventory()
	if not inventory or not inventory.EquippedSlot then
		return { toolTier = BreakingConfig.BareHandToolTier, breakSpeed = BreakingConfig.BareHandBreakSpeed, isBareHand = true }
	end

	local equippedItem = inventory.Hotbar[inventory.EquippedSlot]
	if not equippedItem then
		return { toolTier = BreakingConfig.BareHandToolTier, breakSpeed = BreakingConfig.BareHandBreakSpeed, isBareHand = true }
	end

	local itemConfig = ItemData.GetItem(equippedItem.itemName)
	if not itemConfig or not itemConfig.isBreakingTool then
		return { toolTier = BreakingConfig.BareHandToolTier, breakSpeed = BreakingConfig.BareHandBreakSpeed, isBareHand = true }
	end

	return itemConfig
end

local function canBreakHoveredObject(): boolean
	if not hoveredBreakableId then return false end

	local breakable = breakableData[hoveredBreakableId]
	if not breakable then return false end

	local toolConfig = getToolConfig()

	if toolConfig.canBreakAll then
		return true
	end

	return MaterialData.CanToolBreak(toolConfig.toolTier, breakable.materialType)
end

local function updateMiningAnimation()
	local shouldPlay = isMouseDown and canBreakHoveredObject()

	if shouldPlay and not isPlayingMiningAnimation then
		startMiningAnimation()
	elseif not shouldPlay and isPlayingMiningAnimation then
		stopMiningAnimation()
	end
end

--|| Zone Functions ||--

local function getBreakingZone()
	if not breakingZone then
		breakingZone = Workspace:FindFirstChild("BreakingZone")
	end
	return breakingZone
end

--|| Detection Functions ||--

-- Detect any breakable under cursor via raycast
local function detectBreakableUnderCursor(): (string?, Instance?)
	local camera = Workspace.CurrentCamera
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayOrigin = mouseRay.Origin
	local rayDirection = mouseRay.Direction * 1000

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {player.Character}

	local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if not raycastResult then
		return nil, nil
	end

	local hitInstance = raycastResult.Instance
	local hitPosition = raycastResult.Position

	-- Traverse up from hit instance to find BreakableId
	local current = hitInstance
	while current and current ~= Workspace do
		-- Check if current instance has BreakableId directly
		local breakableIdValue = current:FindFirstChild("BreakableId")
		local playerIdValue = current:FindFirstChild("PlayerId")

		if breakableIdValue and playerIdValue and playerIdValue.Value == player.UserId then
			-- Found breakable, check range
			local character = player.Character
			if character then
				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				if humanoidRootPart then
					local distance = (hitPosition - humanoidRootPart.Position).Magnitude
					if distance <= BreakingConfig.BreakRange then
						-- If this is a BasePart inside a Model, return the Model for highlighting
						if current:IsA("BasePart") and current.Parent and current.Parent:IsA("Model") then
							local parentModel = current.Parent
							-- Check if parent Model's PrimaryPart has same BreakableId
							if parentModel.PrimaryPart and parentModel.PrimaryPart:FindFirstChild("BreakableId") then
								local parentBreakableId = parentModel.PrimaryPart:FindFirstChild("BreakableId")
								if parentBreakableId and parentBreakableId.Value == breakableIdValue.Value then
									return breakableIdValue.Value, parentModel
								end
							end
						end
						return breakableIdValue.Value, current
					end
				end
			end
			return nil, nil
		end

		-- Check if current is a Model with PrimaryPart that has BreakableId
		if current:IsA("Model") and current.PrimaryPart then
			breakableIdValue = current.PrimaryPart:FindFirstChild("BreakableId")
			playerIdValue = current.PrimaryPart:FindFirstChild("PlayerId")

			if breakableIdValue and playerIdValue and playerIdValue.Value == player.UserId then
				-- Found breakable on PrimaryPart, check range
				local character = player.Character
				if character then
					local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
					if humanoidRootPart then
						local distance = (hitPosition - humanoidRootPart.Position).Magnitude
						if distance <= BreakingConfig.BreakRange then
							return breakableIdValue.Value, current
						end
					end
				end
				return nil, nil
			end
		end

		current = current.Parent
	end

	return nil, nil
end

--|| Preview Functions ||--

local function clearPreviewHighlight()
	if previewHighlight then
		previewHighlight:Destroy()
		previewHighlight = nil
	end
	if previewBillboard then
		previewBillboard:Destroy()
		previewBillboard = nil
	end
	hoveredBreakableId = nil
end

local function updatePreviewHighlight(breakableId: string?, model: Instance?)
	if breakableId == hoveredBreakableId then
		return
	end

	clearPreviewHighlight()
	hoveredBreakableId = breakableId

	if not breakableId or not model then
		return
	end

	-- Get target part for billboard
	local targetPart
	if model:IsA("BasePart") then
		targetPart = model
	elseif model:IsA("Model") and model.PrimaryPart then
		targetPart = model.PrimaryPart
	end

	-- Create highlight
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0.7
	highlight.OutlineColor = Color3.new(0, 0, 0)
	highlight.Adornee = model
	highlight.Parent = model
	previewHighlight = highlight

	-- Create billboard with material name
	if targetPart then
		local breakable = breakableData[breakableId]
		local materialType = breakable and breakable.materialType or "Unknown"
		local matProps = MaterialData.GetProperties(materialType)
		local displayName = matProps and matProps.displayName or materialType

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(2, 0, 2, 0)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.Adornee = targetPart
		billboard.AlwaysOnTop = true

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = displayName
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextStrokeTransparency = 0.5
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextScaled = true
		textLabel.Parent = billboard

		billboard.Parent = targetPart
		previewBillboard = billboard
	end
end

local function updatePreview()
	local breakableId, model = detectBreakableUnderCursor()
	updatePreviewHighlight(breakableId, model)
end

--|| Breaking Functions ||--

local function stopBreaking()
	if not currentBreakingId then return end

	currentBreakingId = nil
	currentBreakingProgress = 0

	stopShakeAnimation()
	stopBreakingVFX()

	BreakingService:StopBreaking()
end

local function startBreaking(breakableId: string)
	if currentBreakingId == breakableId then return end

	if currentBreakingId then
		stopBreaking()
	end

	currentBreakingId = breakableId
	currentBreakingProgress = 0

	-- Find model for VFX
	local _, model = detectBreakableUnderCursor()
	if model then
		startShakeAnimation(model)
		startBreakingVFX(model)
	end

	BreakingService:StartBreaking(breakableId)
end

local function updateBreaking()
	if not isMouseDown then
		if currentBreakingId then
			stopBreaking()
		end
		return
	end

	local targetId = hoveredBreakableId

	if not targetId or not canBreakHoveredObject() then
		if currentBreakingId then
			stopBreaking()
		end
		return
	end

	if currentBreakingId ~= targetId then
		startBreaking(targetId)
	end
end

--|| Event Handlers ||--

local function onBreakableRegistered(data: {id: string, materialType: string, position: Vector3})
	breakableData[data.id] = {
		id = data.id,
		materialType = data.materialType,
		position = data.position,
	}
end

local function onBreakableUnregistered(breakableId: string)
	breakableData[breakableId] = nil

	if animatingBlocks[breakableId] then
		animatingBlocks[breakableId]:Destroy()
		animatingBlocks[breakableId] = nil
	end
end

local function onBreakingProgress(breakableId: string, progress: number)
	if breakableId ~= currentBreakingId then return end

	currentBreakingProgress = progress
	updateShakeAnimation(progress)
	updateBreakingVFX(progress)
end

local function onBreakingStopped(breakableId: string)
	if breakableId == currentBreakingId then
		stopBreaking()
	end
end

local function onBreakableBroken(breakableId: string, dropItem: string, position: Vector3)
	-- Clear preview if we were hovering this
	if hoveredBreakableId == breakableId then
		clearPreviewHighlight()
	end

	-- Stop breaking if we were breaking this
	if currentBreakingId == breakableId then
		stopBreaking()
	end

	-- Get color from material before removing from tracking
	local materialType = breakableData[breakableId] and breakableData[breakableId].materialType
	local burstColor = Color3.new(0.5, 0.5, 0.5) -- Default gray
	if materialType then
		local matProps = MaterialData.GetProperties(materialType)
		if matProps and matProps.color then
			burstColor = matProps.color
		end
	end

	-- Remove from tracking
	breakableData[breakableId] = nil

	-- Play break VFX burst at position
	task.spawn(function()
		-- Create invisible 3x3x3 part for particle emission
		local burstPart = Instance.new("Part")
		burstPart.Name = "BreakBurst"
		burstPart.Size = Vector3.new(3, 3, 3)
		burstPart.Position = position
		burstPart.Anchored = true
		burstPart.CanCollide = false
		burstPart.CanQuery = false
		burstPart.Transparency = 1
		burstPart.Parent = Workspace

		-- Try to get Emit_50 from VFX folder
		local vfxFolder = ReplicatedStorage:FindFirstChild("Assets")
		if vfxFolder then vfxFolder = vfxFolder:FindFirstChild("VFX") end
		if vfxFolder then vfxFolder = vfxFolder:FindFirstChild("Breaking") end
		if vfxFolder then vfxFolder = vfxFolder:FindFirstChild("4x4") end

		local emitter
		if vfxFolder then
			local emitterTemplate = vfxFolder:FindFirstChild("Emit_50")
			if emitterTemplate and emitterTemplate:IsA("ParticleEmitter") then
				emitter = emitterTemplate:Clone()
				emitter.Color = ColorSequence.new(burstColor)
				emitter.Parent = burstPart
			end
		end

		-- Fallback if no VFX folder
		if not emitter then
			emitter = Instance.new("ParticleEmitter")
			emitter.Color = ColorSequence.new(burstColor)
			emitter.Size = NumberSequence.new(0.4, 0)
			emitter.Lifetime = NumberRange.new(0.5, 1)
			emitter.Speed = NumberRange.new(5, 10)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Parent = burstPart
		end

		-- Emit burst
		emitter:Emit(50)

		-- Clean up after particles fade
		task.delay(2, function()
			if burstPart and burstPart.Parent then
				burstPart:Destroy()
			end
		end)
	end)
end

-- Block spawn animation (from BreakingAreaService)
local function onBlockAboutToSpawn(blockData: {id: string, materialType: string, position: Vector3})
	-- Store data
	breakableData[blockData.id] = {
		id = blockData.id,
		materialType = blockData.materialType,
		position = blockData.position,
	}

	-- Play spawn animation
	task.spawn(function()
		playSpawnAnimation(blockData)
	end)
end

local function onBlockSpawned(blockData: {id: string, materialType: string, position: Vector3})
	-- Block is now fully spawned on server, animation should be done
end

--|| Input Handling ||--

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isMouseDown = true
	end
end

local function onInputEnded(input: InputObject, gameProcessed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isMouseDown = false
		if currentBreakingId then
			stopBreaking()
		end
	end
end

--|| Update Loop ||--

local function onHeartbeat(deltaTime: number)
	updatePreview()
	updateBreaking()
	updateMiningAnimation()

	if currentBreakingId and shakeModel then
		updateShakeAnimation(currentBreakingProgress)
	end
end

--|| Knit Lifecycle ||--

function BreakingController:KnitInit()
	breakingZone = getBreakingZone()
end

function BreakingController:KnitStart()
	BreakingService = Knit.GetService("BreakingService")
	BreakingAreaService = Knit.GetService("BreakingAreaService")
	InventoryController = Knit.GetController("InventoryController")

	-- Connect to BreakingService events
	BreakingService.BreakableRegistered:Connect(onBreakableRegistered)
	BreakingService.BreakableUnregistered:Connect(onBreakableUnregistered)
	BreakingService.BreakingProgress:Connect(onBreakingProgress)
	BreakingService.BreakingStopped:Connect(onBreakingStopped)
	BreakingService.BreakableBroken:Connect(onBreakableBroken)

	-- Connect to BreakingAreaService events (for spawn animations)
	BreakingAreaService.BlockAboutToSpawn:Connect(onBlockAboutToSpawn)
	BreakingAreaService.BlockSpawned:Connect(onBlockSpawned)

	-- Input
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	-- Update loop
	RunService.Heartbeat:Connect(onHeartbeat)

	-- Get initial breakables
	task.spawn(function()
		local breakables = BreakingService:GetBreakables()
		if breakables and type(breakables) == "table" then
			for id, data in pairs(breakables) do
				if type(data) == "table" then
					breakableData[id] = {
						id = id,
						materialType = data.materialType,
						position = data.position,
					}
				end
			end
		end
	end)
end

return BreakingController
