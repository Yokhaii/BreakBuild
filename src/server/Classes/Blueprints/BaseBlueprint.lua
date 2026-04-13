--[=[
	Server BaseBlueprint - Server-side Blueprint Class
	Extends shared BaseBlueprint with server-specific functionality
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SharedBaseBlueprint = require(ReplicatedStorage.Shared.Classes.Blueprints.BaseBlueprint)
local Signal = require(ReplicatedStorage.Packages.Signal)

local ServerBaseBlueprint = {}
ServerBaseBlueprint.__index = ServerBaseBlueprint
setmetatable(ServerBaseBlueprint, { __index = SharedBaseBlueprint })

function ServerBaseBlueprint.new(data)
	local self = SharedBaseBlueprint.new(data)
	setmetatable(self, ServerBaseBlueprint)

	-- Server-specific properties
	self.Model = nil -- The ghost model in the world
	self.BlockModels = {} -- References to block models within the blueprint

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
	print("[ServerBaseBlueprint:FillBlock] Called with offset:", offset, "blockType:", blockType, "blockId:", blockId)
	print("[ServerBaseBlueprint:FillBlock] Blueprint ID:", self.Id, "Type:", self.BlueprintType)

	if not self:IsPositionInBounds(offset) then
		warn("[ServerBaseBlueprint:FillBlock] Offset out of bounds:", offset)
		return false, false
	end

	local offsetKey = self:_OffsetToKey(offset)
	print("[ServerBaseBlueprint:FillBlock] Offset key:", offsetKey)

	-- Check if already filled
	if self.FilledBlocks[offsetKey] then
		warn("[ServerBaseBlueprint:FillBlock] Slot already filled at:", offsetKey)
		return false, false
	end

	-- Get required block type
	local requiredType = self:GetRequiredBlockAt(offset)
	local isCorrect = (requiredType == blockType)
	print("[ServerBaseBlueprint:FillBlock] Required type:", requiredType, "Got:", blockType, "IsCorrect:", isCorrect)

	-- Store the filled block
	self.FilledBlocks[offsetKey] = {
		blockType = blockType,
		blockId = blockId,
	}
	print("[ServerBaseBlueprint:FillBlock] Block stored at key:", offsetKey)

	-- Fire appropriate event
	if isCorrect then
		print("[ServerBaseBlueprint:FillBlock] Firing OnBlockFilled event")
		self.OnBlockFilled:Fire(offset, blockType, blockId)

		-- Check if blueprint is now complete
		print("[ServerBaseBlueprint:FillBlock] Checking if blueprint is complete...")
		local isComplete = self:IsComplete()
		print("[ServerBaseBlueprint:FillBlock] IsComplete result:", isComplete, "CompletedAt:", self.CompletedAt)

		if isComplete and self.CompletedAt == 0 then
			self.CompletedAt = os.time()
			print("[ServerBaseBlueprint:FillBlock] *** BLUEPRINT COMPLETED! Firing OnCompleted event ***")
			self.OnCompleted:Fire()
		end
	else
		print("[ServerBaseBlueprint:FillBlock] Firing OnWrongBlock event - expected:", requiredType)
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
		-- Apply rotation
		local rotation = CFrame.Angles(0, math.rad(self.Rotation), 0)
		model:SetPrimaryPartCFrame(CFrame.new(worldPosition) * rotation)

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
		part.Position = buildingAreaOrigin + self.RelativePosition + blockReq.offset + Vector3.new(GRID_SIZE/2, GRID_SIZE/2, GRID_SIZE/2)
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = self.Definition.ghostTransparency or 0.7
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

	self.Model = model
	return model
end

-- Apply ghost effect to all parts in the model
function ServerBaseBlueprint:_ApplyGhostEffect(model: Model)
	local transparency = self.Definition and self.Definition.ghostTransparency or 0.7

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
	if not self.Model then return end

	local offsetKey = self:_OffsetToKey(offset)
	local partName = "GhostBlock_" .. offsetKey

	local part = self.Model:FindFirstChild(partName, true)
	if part and part:IsA("BasePart") then
		if isFilled then
			-- Make solid
			part.Transparency = 0
		else
			-- Make ghost
			part.Transparency = self.Definition and self.Definition.ghostTransparency or 0.7
		end
	end
end

return ServerBaseBlueprint
