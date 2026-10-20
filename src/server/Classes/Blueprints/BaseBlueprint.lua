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

	-- Update ghost block visuals (progressive reveal)
	self:UpdateBlockVisuals()

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

	-- Update ghost block visuals (progressive reveal)
	self:UpdateBlockVisuals()

	return true
end

-- Create a Glass proxy part with its own Highlight as a sibling of the ghost part
function ServerBaseBlueprint:_CreateGlassProxy(ghostPart: BasePart)
	local proxy = Instance.new("Part")
	proxy.Name = ghostPart.Name .. "_Glass"
	proxy.Size = ghostPart.Size
	proxy.CFrame = ghostPart.CFrame
	proxy.Anchored = true
	proxy.CanCollide = false
	proxy.CanQuery = false
	proxy.CanTouch = false
	proxy.CastShadow = false
	proxy.Material = Enum.Material.Glass
	proxy.Transparency = 1
	proxy.Parent = ghostPart.Parent

	local highlight = Instance.new("Highlight")
	highlight.Name = "GlassHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0.65
	highlight.OutlineColor = Color3.fromRGB(100, 170, 255)
	highlight.Adornee = proxy
	highlight.Parent = proxy

	return proxy
end

-- Find the part in a model closest to a target world position
local MATCH_TOLERANCE = 3
local function findPartAtPosition(model, targetWorldPos)
	local bestPart = nil
	local bestDist = math.huge
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			local dist = (desc.Position - targetWorldPos).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestPart = desc
			end
		end
	end
	if bestDist <= MATCH_TOLERANCE then
		return bestPart
	end
	return nil
end

-- Create the ghost model in the world with progressive reveal.
-- Clones the actual blueprint model so original materials/meshes/colors are preserved.
function ServerBaseBlueprint:CreateModel(buildingAreaOrigin: Vector3, parentZone: Instance?): Model?
	if not self.Definition then
		warn("[ServerBaseBlueprint] Cannot create model: no definition")
		return nil
	end

	-- Resolve model from ReplicatedStorage
	local pathParts = string.split(self.Definition.modelPath, ".")
	local current = ReplicatedStorage
	local startIndex = pathParts[1] == "ReplicatedStorage" and 2 or 1
	for i = startIndex, #pathParts do
		current = current:FindFirstChild(pathParts[i])
		if not current then
			warn("[ServerBaseBlueprint] Blueprint model not found:", self.Definition.modelPath)
			return nil
		end
	end

	local model = current:Clone()
	model.Name = "Blueprint_" .. self.Id

	local worldPosition = buildingAreaOrigin + self.RelativePosition

	-- Position the model using its PrimaryPart as anchor
	if model:IsA("Model") and model.PrimaryPart then
		model:SetPrimaryPartCFrame(CFrame.new(worldPosition))
	end

	-- Make all parts non-collidable and anchored
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.Anchored = true
			desc.CastShadow = false
		end
	end

	-- Map each definition block to its model part by position, rename for lookup
	local transparency = self.Definition.ghostTransparency or 0.55
	local visibleKeys = self:GetVisibleOffsetKeys()

	for _, blockReq in ipairs(self.Definition.blocks) do
		local offsetKey = self:_OffsetToKey(blockReq.offset)
		local targetPos = worldPosition + blockReq.offset
		local part = findPartAtPosition(model, targetPos)

		if part then
			part.Name = "GhostBlock_" .. offsetKey
			local isVisible = not self.FilledBlocks[offsetKey] and visibleKeys[offsetKey]
			part.Transparency = isVisible and transparency or 1

			if isVisible then
				self:_CreateGlassProxy(part)
			end
		end
	end

	-- Parent to the player's zone
	if parentZone then
		model.Parent = parentZone
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

	-- Store blueprint type for display name
	local typeValue = Instance.new("StringValue")
	typeValue.Name = "BlueprintType"
	typeValue.Value = self.BlueprintType
	typeValue.Parent = model

	self.Model = model
	return model
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

-- Update visual state of all block positions (progressive reveal)
function ServerBaseBlueprint:UpdateBlockVisuals()
	if not self.Model or not self.Definition then
		return
	end

	local transparency = self.Definition.ghostTransparency or 0.55
	local visibleKeys = self:GetVisibleOffsetKeys()

	for _, blockReq in ipairs(self.Definition.blocks) do
		local offsetKey = self:_OffsetToKey(blockReq.offset)
		local partName = "GhostBlock_" .. offsetKey
		local glassName = partName .. "_Glass"
		local isVisible = not self.FilledBlocks[offsetKey] and visibleKeys[offsetKey]

		local part = self.Model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.Transparency = isVisible and transparency or 1
		end

		local glass = self.Model:FindFirstChild(glassName)
		if isVisible and not glass and part then
			self:_CreateGlassProxy(part)
		elseif not isVisible and glass then
			glass:Destroy()
		end
	end
end

-- Create the completed structure model, replacing the ghost model
-- Returns the completed model instance
function ServerBaseBlueprint:CreateCompletedModel(buildingAreaOrigin: Vector3, parentZone: Instance?): Model?
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

	-- Parent to the player's zone
	if parentZone then
		model.Parent = parentZone
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
