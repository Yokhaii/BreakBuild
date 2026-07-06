--[=[
	Server BaseBlueprint - Server-side Blueprint Class
	Extends shared BaseBlueprint with server-specific functionality
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local SharedBaseBlueprint = require(ReplicatedStorage.Shared.Classes.Blueprints.BaseBlueprint)
local Signal = require(ReplicatedStorage.Packages.Signal)

local ServerBaseBlueprint = {}
ServerBaseBlueprint.__index = ServerBaseBlueprint
setmetatable(ServerBaseBlueprint, { __index = SharedBaseBlueprint })

-- Animation constants for placement wave effect
local WAVE_DURATION = 0.4
local WAVE_OFFSET = Vector3.new(0, 0.5, 0)
local WAVE_DELAY_PER_DISTANCE = 0.05

function ServerBaseBlueprint.new(data)
	local self = SharedBaseBlueprint.new(data)
	setmetatable(self, ServerBaseBlueprint)

	-- Server-specific properties
	self.Model = nil -- The ghost model (when incomplete) or completed model
	self.BlockModels = {} -- References to block models within the blueprint
	self.IsStructureComplete = false -- Whether the completed structure model is shown
	self.CompletedModel = nil -- Reference to the completed structure model

	-- Events
	self.OnCompleted = Signal.new()
	self.OnDestroyed = Signal.new()
	self.OnBlockFilled = Signal.new()
	self.OnWrongBlock = Signal.new()

	return self
end

-- Fill a block slot in the blueprint
-- Returns: success, isCorrect (true if correct block type, false if wrong)
function ServerBaseBlueprint:FillBlock(offset: Vector3, blockType: string, blockId: string): (boolean, boolean)
	if not self:IsPositionInBounds(offset) then
		return false, false
	end

	local offsetKey = self:_OffsetToKey(offset)

	-- Check if already filled
	if self.FilledBlocks[offsetKey] then
		return false, false
	end

	-- Get required block type
	local requiredType = self:GetRequiredBlockAt(offset)
	local isCorrect = (requiredType == blockType)

	-- Store the filled block
	self.FilledBlocks[offsetKey] = {
		blockType = blockType,
		blockId = blockId,
	}

	-- Fire appropriate event
	if isCorrect then
		self.OnBlockFilled:Fire(offset, blockType, blockId)

		-- Check if blueprint is now complete
		if self:IsComplete() and self.CompletedAt == 0 then
			self.CompletedAt = os.time()
			self.OnCompleted:Fire()
		end
	else
		self.OnWrongBlock:Fire(offset, blockType, requiredType)
	end

	return true, isCorrect
end

-- Remove a filled block from the blueprint
function ServerBaseBlueprint:RemoveFilledBlock(offset: Vector3): boolean
	local offsetKey = self:_OffsetToKey(offset)

	if not self.FilledBlocks[offsetKey] then
		return false -- No block at this offset
	end

	-- If blueprint was completed, it's no longer complete
	local wasComplete = self.CompletedAt > 0
	if wasComplete then
		self.CompletedAt = 0
		self.OnDestroyed:Fire()
	end

	self.FilledBlocks[offsetKey] = nil
	return true
end

-- Create glass proxy parts for highlight support on transparent models
-- Roblox only shows highlights on transparent parts if they use Glass material
-- This creates a permanent highlight effect on the blueprint ghost
function ServerBaseBlueprint:_CreateHighlightProxy(model: Model): Model
	local proxyModel = Instance.new("Model")
	proxyModel.Name = "HighlightProxy"

	-- Clone each BasePart as a Glass material version for highlighting
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local proxyPart = Instance.new("Part")
			proxyPart.Name = descendant.Name .. "_Proxy"
			proxyPart.Size = descendant.Size
			proxyPart.CFrame = descendant.CFrame
			proxyPart.Anchored = true
			proxyPart.CanCollide = false
			proxyPart.CanQuery = false
			proxyPart.CanTouch = false
			proxyPart.CastShadow = false
			proxyPart.Transparency = 1 -- Fully invisible
			proxyPart.Material = Enum.Material.Glass -- Glass allows highlights on transparent parts
			proxyPart.Parent = proxyModel
		end
	end

	-- Also handle PrimaryPart if it exists
	if model.PrimaryPart then
		local proxyPart = Instance.new("Part")
		proxyPart.Name = "PrimaryPart_Proxy"
		proxyPart.Size = model.PrimaryPart.Size
		proxyPart.CFrame = model.PrimaryPart.CFrame
		proxyPart.Anchored = true
		proxyPart.CanCollide = false
		proxyPart.CanQuery = false
		proxyPart.CanTouch = false
		proxyPart.CastShadow = false
		proxyPart.Transparency = 1
		proxyPart.Material = Enum.Material.Glass
		proxyModel.PrimaryPart = proxyPart
		proxyPart.Parent = proxyModel
	end

	proxyModel.Parent = model

	local highlight = Instance.new("Highlight")
	highlight.Name = "BlueprintHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0.95
	highlight.OutlineColor = Color3.fromRGB(0, 0, 0) -- Blue outline
	highlight.Adornee = proxyModel
	highlight.Parent = proxyModel

	return proxyModel
end

-- Create the ghost model in the world
function ServerBaseBlueprint:CreateModel(buildingAreaOrigin: Vector3): Model?
	if not self.Definition then
		warn("[ServerBaseBlueprint] Cannot create model: no definition")
		return nil
	end

	-- Parse model path
	local pathParts = string.split(self.Definition.modelPath, ".")
	local current = ReplicatedStorage

	local startIndex = 1
	if pathParts[1] == "ReplicatedStorage" then
		startIndex = 2
	end

	for i = startIndex, #pathParts do
		current = current:FindFirstChild(pathParts[i])
		if not current then
			-- Model doesn't exist yet, create a simple placeholder
			warn("[ServerBaseBlueprint] Blueprint model not found:", self.Definition.modelPath)
			return self:_CreatePlaceholderModel(buildingAreaOrigin)
		end
	end

	-- Clone the model
	local model = current:Clone()
	model.Name = "Blueprint_" .. self.Id

	-- Calculate world position
	local worldPosition = buildingAreaOrigin + self.RelativePosition

	-- Position the model
	if model:IsA("Model") and model.PrimaryPart then
		model:SetPrimaryPartCFrame(CFrame.new(worldPosition))

		-- Make ghost (transparent)
		self:_ApplyGhostEffect(model)
	end

	-- Parent to BuildingZone
	local buildingZone = Workspace:FindFirstChild("BuildingZone")
	if buildingZone then
		model.Parent = buildingZone
	else
		model.Parent = Workspace
	end

	-- Create highlight proxy (glass parts for highlight support on transparent models)
	self:_CreateHighlightProxy(model)

	-- Store blueprint ID in model
	local idValue = Instance.new("StringValue")
	idValue.Name = "BlueprintId"
	idValue.Value = self.Id
	idValue.Parent = model

	-- Store owner ID
	local ownerValue = Instance.new("IntValue")
	ownerValue.Name = "OwnerId"
	ownerValue.Value = self.OwnerId
	ownerValue.Parent = model

	-- Store blueprint type for display name
	local typeValue = Instance.new("StringValue")
	typeValue.Name = "BlueprintType"
	typeValue.Value = self.BlueprintType
	typeValue.Parent = model

	self.Model = model
	return model
end

-- Create a placeholder model when the actual model doesn't exist
function ServerBaseBlueprint:_CreatePlaceholderModel(buildingAreaOrigin: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Blueprint_" .. self.Id .. "_Placeholder"

	-- Create a part for each required block position
	local GRID_SIZE = 4
	for _, blockReq in ipairs(self.Definition.blocks) do
		local part = Instance.new("Part")
		part.Name = "GhostBlock_" .. self:_OffsetToKey(blockReq.offset)
		part.Size = Vector3.new(GRID_SIZE, GRID_SIZE, GRID_SIZE)
		part.Position = buildingAreaOrigin
			+ self.RelativePosition
			+ blockReq.offset
			+ Vector3.new(GRID_SIZE / 2, GRID_SIZE / 2, GRID_SIZE / 2)
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = self.Definition.ghostTransparency or 0.55
		part.BrickColor = BrickColor.new("Bright blue")
		part.Material = Enum.Material.ForceField
		part.Parent = model
	end

	-- Set primary part
	local firstPart = model:FindFirstChildWhichIsA("Part")
	if firstPart then
		model.PrimaryPart = firstPart
	end

	-- Parent to BuildingZone
	local buildingZone = Workspace:FindFirstChild("BuildingZone")
	if buildingZone then
		model.Parent = buildingZone
	else
		model.Parent = Workspace
	end

	-- Create highlight proxy (glass parts for highlight support on transparent models)
	self:_CreateHighlightProxy(model)

	-- Store blueprint ID
	local idValue = Instance.new("StringValue")
	idValue.Name = "BlueprintId"
	idValue.Value = self.Id
	idValue.Parent = model

	-- Store owner ID
	local ownerValue = Instance.new("IntValue")
	ownerValue.Name = "OwnerId"
	ownerValue.Value = self.OwnerId
	ownerValue.Parent = model

	-- Store blueprint type for display name
	local typeValue = Instance.new("StringValue")
	typeValue.Name = "BlueprintType"
	typeValue.Value = self.BlueprintType
	typeValue.Parent = model

	self.Model = model
	return model
end

-- Apply ghost effect to all parts in the model
function ServerBaseBlueprint:_ApplyGhostEffect(model: Model)
	local transparency = self.Definition and self.Definition.ghostTransparency or 0.55

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = transparency
			descendant.CanCollide = false
			descendant.Anchored = true
		end
	end
end

-- Destroy the model
function ServerBaseBlueprint:DestroyModel()
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end

	-- Cleanup signals
	self.OnCompleted:Destroy()
	self.OnDestroyed:Destroy()
	self.OnBlockFilled:Destroy()
	self.OnWrongBlock:Destroy()
end

-- Update visual state of a specific block position (solid vs ghost)
function ServerBaseBlueprint:UpdateBlockVisual(offset: Vector3, isFilled: boolean)
	if not self.Model then
		return
	end

	local offsetKey = self:_OffsetToKey(offset)
	local partName = "GhostBlock_" .. offsetKey

	local part = self.Model:FindFirstChild(partName, true)
	if part and part:IsA("BasePart") then
		if isFilled then
			-- Make solid
			part.Transparency = 0
		else
			-- Make ghost
			part.Transparency = self.Definition and self.Definition.ghostTransparency or 0.55
		end
	end
end

-- Create the completed structure model, replacing the ghost model
-- Returns the completed model instance
function ServerBaseBlueprint:CreateCompletedModel(buildingAreaOrigin: Vector3): Model?
	if not self.Definition then
		warn("[ServerBaseBlueprint] Cannot create completed model: no definition")
		return nil
	end

	local completedModelPath = self.Definition.completedModelPath
	if not completedModelPath then
		warn("[ServerBaseBlueprint] No completedModelPath defined for:", self.BlueprintType)
		return nil
	end

	-- Parse model path
	local pathParts = string.split(completedModelPath, ".")
	local current = ReplicatedStorage

	local startIndex = 1
	if pathParts[1] == "ReplicatedStorage" then
		startIndex = 2
	end

	for i = startIndex, #pathParts do
		current = current:FindFirstChild(pathParts[i])
		if not current then
			warn("[ServerBaseBlueprint] Completed model not found:", completedModelPath)
			return nil
		end
	end

	-- Destroy the ghost model
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end

	-- Clone the completed model
	local model = current:Clone()
	model.Name = "CompletedBlueprint_" .. self.Id

	-- Calculate world position (same as ghost model positioning)
	local worldPosition = buildingAreaOrigin + self.RelativePosition

	-- Position the model
	if model:IsA("Model") and model.PrimaryPart then
		model:SetPrimaryPartCFrame(CFrame.new(worldPosition))

		-- Anchor all parts
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = true
				descendant.Anchored = true
			end
		end
	end

	-- Parent to BuildingZone
	local buildingZone = Workspace:FindFirstChild("BuildingZone")
	if buildingZone then
		model.Parent = buildingZone
	else
		model.Parent = Workspace
	end

	-- Store blueprint ID in model
	local idValue = Instance.new("StringValue")
	idValue.Name = "BlueprintId"
	idValue.Value = self.Id
	idValue.Parent = model

	-- Store owner ID
	local ownerValue = Instance.new("IntValue")
	ownerValue.Name = "OwnerId"
	ownerValue.Value = self.OwnerId
	ownerValue.Parent = model

	-- Mark as completed structure
	local completedValue = Instance.new("BoolValue")
	completedValue.Name = "IsCompletedStructure"
	completedValue.Value = true
	completedValue.Parent = model

	-- Store blueprint type for item drop
	local typeValue = Instance.new("StringValue")
	typeValue.Name = "BlueprintType"
	typeValue.Value = self.BlueprintType
	typeValue.Parent = model

	self.CompletedModel = model
	self.Model = model
	self.IsStructureComplete = true

	-- Play placement wave animation
	self:_PlayPlacementAnimation(model, worldPosition)

	return model
end

-- Play a wave animation on the model parts
function ServerBaseBlueprint:_PlayPlacementAnimation(model: Model, centerPosition: Vector3)
	if not model then
		return
	end

	local parts = {}
	local maxDistance = 0

	-- Collect all parts and calculate distances from center
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local distance = (descendant.Position - centerPosition).Magnitude
			maxDistance = math.max(maxDistance, distance)
			table.insert(parts, {
				part = descendant,
				distance = distance,
				originalPosition = descendant.Position,
			})
		end
	end

	-- Animate each part with a delay based on distance
	for _, partData in ipairs(parts) do
		local part = partData.part
		local delay = (partData.distance / math.max(maxDistance, 1)) * WAVE_DELAY_PER_DISTANCE * #parts

		-- Start slightly above original position
		local startPos = partData.originalPosition + WAVE_OFFSET
		part.Position = startPos

		-- Animate to original position
		task.delay(delay, function()
			if part and part.Parent then
				local tweenInfo = TweenInfo.new(WAVE_DURATION, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
				local tween = TweenService:Create(part, tweenInfo, {
					Position = partData.originalPosition,
				})
				tween:Play()
			end
		end)
	end
end

-- Get the breakable ID for this completed structure
function ServerBaseBlueprint:GetBreakableId(): string
	return "structure_" .. self.Id
end

-- Get the drop item name for when this structure is broken
function ServerBaseBlueprint:GetDropItemName(): string?
	if self.Definition and self.Definition.completedItemName then
		return self.Definition.completedItemName
	end
	return nil
end

return ServerBaseBlueprint
