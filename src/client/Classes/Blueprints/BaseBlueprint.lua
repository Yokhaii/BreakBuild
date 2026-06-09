--[=[
	Client BaseBlueprint - Client-side Blueprint Class
	Extends shared BaseBlueprint with client-specific visual functionality
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SharedBaseBlueprint = require(ReplicatedStorage.Shared.Classes.Blueprints.BaseBlueprint)

local ClientBaseBlueprint = {}
ClientBaseBlueprint.__index = ClientBaseBlueprint
setmetatable(ClientBaseBlueprint, { __index = SharedBaseBlueprint })

-- Constants
local BILLBOARD_OFFSET = Vector3.new(0, 3, 0)
local WRONG_BLOCK_HIGHLIGHT_COLOR = Color3.fromRGB(255, 50, 50)
local CORRECT_BLOCK_HIGHLIGHT_COLOR = Color3.fromRGB(50, 255, 50)

function ClientBaseBlueprint.new(data)
	local self = SharedBaseBlueprint.new(data)
	setmetatable(self, ClientBaseBlueprint)

	-- Client-specific properties
	self.Model = nil -- Reference to the model in workspace
	self.HoverBillboard = nil -- BillboardGui for hover label
	self.WrongBlockHighlights = {} -- { [blockId]: Highlight }

	return self
end

-- Set the model reference (called when syncing from server)
function ClientBaseBlueprint:SetModel(model: Model)
	self.Model = model
end

-- Show hover label at a specific offset showing required block type
function ClientBaseBlueprint:ShowHoverLabel(offset: Vector3, buildingAreaOrigin: Vector3)
	-- Remove existing hover billboard
	self:HideHoverLabel()

	local requiredType = self:GetRequiredBlockAt(offset)
	if not requiredType then return end

	-- Create billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BlueprintHoverLabel"
	billboard.Size = UDim2.new(0, 150, 0, 40)
	billboard.StudsOffset = BILLBOARD_OFFSET
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 50

	-- Create background
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	background.BackgroundTransparency = 0.2
	background.BorderSizePixel = 0
	background.Parent = billboard

	-- Add corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = background

	-- Create text label
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "RequiredText"
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "Need: " .. requiredType
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextSize = 16
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = background

	-- Position at the offset
	local worldPosition = self:OffsetToWorld(offset, buildingAreaOrigin)

	-- Create an attachment point part (invisible)
	local attachPart = Instance.new("Part")
	attachPart.Name = "HoverAttachment"
	attachPart.Size = Vector3.new(0.1, 0.1, 0.1)
	attachPart.Position = worldPosition
	attachPart.Anchored = true
	attachPart.CanCollide = false
	attachPart.Transparency = 1
	attachPart.Parent = workspace

	billboard.Adornee = attachPart
	billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	self.HoverBillboard = billboard
	self._HoverAttachment = attachPart
end

-- Hide hover label
function ClientBaseBlueprint:HideHoverLabel()
	if self.HoverBillboard then
		self.HoverBillboard:Destroy()
		self.HoverBillboard = nil
	end

	if self._HoverAttachment then
		self._HoverAttachment:Destroy()
		self._HoverAttachment = nil
	end
end

-- Create wrong block highlight (red outline)
function ClientBaseBlueprint:CreateWrongBlockHighlight(blockModel: Instance, blockId: string)
	-- Remove existing highlight for this block if any
	self:RemoveWrongBlockHighlight(blockId)

	-- Create highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "WrongBlockHighlight_" .. blockId
	highlight.FillColor = WRONG_BLOCK_HIGHLIGHT_COLOR
	highlight.FillTransparency = 0.8
	highlight.OutlineColor = WRONG_BLOCK_HIGHLIGHT_COLOR
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = blockModel
	highlight.Parent = blockModel

	self.WrongBlockHighlights[blockId] = highlight
end

-- Remove wrong block highlight
function ClientBaseBlueprint:RemoveWrongBlockHighlight(blockId: string)
	local highlight = self.WrongBlockHighlights[blockId]
	if highlight then
		highlight:Destroy()
		self.WrongBlockHighlights[blockId] = nil
	end
end

-- Remove all wrong block highlights
function ClientBaseBlueprint:ClearWrongBlockHighlights()
	for blockId, highlight in pairs(self.WrongBlockHighlights) do
		highlight:Destroy()
	end
	self.WrongBlockHighlights = {}
end

-- Update visuals for all blocks (filled = solid, unfilled = transparent)
function ClientBaseBlueprint:UpdateVisuals()
	if not self.Model or not self.Definition then return end

	local GRID_SIZE = 4

	for _, blockReq in ipairs(self.Definition.blocks) do
		local offsetKey = self:_OffsetToKey(blockReq.offset)
		local partName = "GhostBlock_" .. offsetKey

		local part = self.Model:FindFirstChild(partName, true)
		if part and part:IsA("BasePart") then
			local filledBlock = self.FilledBlocks[offsetKey]

			if filledBlock then
				-- Check if correct block type
				if filledBlock.blockType == blockReq.blockType then
					-- Correct block - make solid (but keep ghost since real block is placed)
					part.Transparency = 1 -- Hide ghost, real block is visible
				else
					-- Wrong block - keep ghost visible with different color
					part.Transparency = 0.5
					part.BrickColor = BrickColor.new("Bright red")
				end
			else
				-- Not filled - show ghost
				part.Transparency = self.Definition.ghostTransparency or 0.7
				part.BrickColor = BrickColor.new("Bright blue")
			end
		end
	end
end

-- Update visual for a single block slot
function ClientBaseBlueprint:UpdateBlockVisual(offset: Vector3)
	if not self.Model or not self.Definition then return end

	local offsetKey = self:_OffsetToKey(offset)
	local partName = "GhostBlock_" .. offsetKey

	local part = self.Model:FindFirstChild(partName, true)
	if not part or not part:IsA("BasePart") then return end

	local filledBlock = self.FilledBlocks[offsetKey]
	local requiredType = self:GetRequiredBlockAt(offset)

	if filledBlock then
		if filledBlock.blockType == requiredType then
			-- Correct block - hide ghost
			part.Transparency = 1
		else
			-- Wrong block - show red ghost
			part.Transparency = 0.5
			part.BrickColor = BrickColor.new("Bright red")
		end
	else
		-- Not filled - show blue ghost
		part.Transparency = self.Definition.ghostTransparency or 0.6
		part.BrickColor = BrickColor.new("Bright blue")
	end
end

-- Flash effect when block is placed (correct or wrong)
function ClientBaseBlueprint:FlashBlockSlot(offset: Vector3, isCorrect: boolean)
	if not self.Model or not self.Definition then return end

	local offsetKey = self:_OffsetToKey(offset)
	local partName = "GhostBlock_" .. offsetKey

	local part = self.Model:FindFirstChild(partName, true)
	if not part or not part:IsA("BasePart") then return end

	-- Store original properties
	local originalTransparency = part.Transparency
	local originalColor = part.BrickColor

	-- Flash color
	local flashColor = isCorrect and CORRECT_BLOCK_HIGHLIGHT_COLOR or WRONG_BLOCK_HIGHLIGHT_COLOR

	-- Create flash effect
	task.spawn(function()
		for i = 1, 3 do
			part.BrickColor = BrickColor.new(flashColor)
			part.Transparency = 0.3
			task.wait(0.1)
			part.BrickColor = originalColor
			part.Transparency = originalTransparency
			task.wait(0.1)
		end
	end)
end

-- Cleanup
function ClientBaseBlueprint:Destroy()
	self:HideHoverLabel()
	self:ClearWrongBlockHighlights()
	self.Model = nil
end

return ClientBaseBlueprint
