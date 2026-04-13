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
local PROGRESS_BILLBOARD_OFFSET = Vector3.new(0, 5, 0)
local WRONG_BLOCK_HIGHLIGHT_COLOR = Color3.fromRGB(255, 50, 50)
local CORRECT_BLOCK_HIGHLIGHT_COLOR = Color3.fromRGB(50, 255, 50)

function ClientBaseBlueprint.new(data)
	local self = SharedBaseBlueprint.new(data)
	setmetatable(self, ClientBaseBlueprint)

	-- Client-specific properties
	self.Model = nil -- Reference to the model in workspace
	self.HoverBillboard = nil -- BillboardGui for hover label
	self.ProgressBillboard = nil -- BillboardGui for progress display
	self.WrongBlockHighlights = {} -- { [blockId]: Highlight }
	self._ProgressAttachment = nil

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
		part.Transparency = self.Definition.ghostTransparency or 0.7
		part.BrickColor = BrickColor.new("Bright blue")
	end
end

-- Get progress bar color based on completion percentage
function ClientBaseBlueprint:GetProgressColor(): Color3
	local progress = self:GetProgress()

	if progress < 33 then
		return Color3.fromRGB(255, 100, 100) -- Red
	elseif progress < 66 then
		return Color3.fromRGB(255, 200, 100) -- Yellow
	else
		return Color3.fromRGB(100, 255, 100) -- Green
	end
end

-- Show progress billboard above the blueprint
function ClientBaseBlueprint:ShowProgressBillboard(buildingAreaOrigin: Vector3)
	-- Remove existing progress billboard
	self:HideProgressBillboard()

	if not self.Definition then return end

	-- Create billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BlueprintProgressBillboard"
	billboard.Size = UDim2.new(0, 200, 0, 60)
	billboard.StudsOffset = PROGRESS_BILLBOARD_OFFSET
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100

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

	-- Create title label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleText"
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.Position = UDim2.new(0, 0, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = self.Definition.displayName or self.Definition.name
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 14
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = background

	-- Create progress bar background
	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBg"
	progressBg.Size = UDim2.new(0.9, 0, 0, 12)
	progressBg.Position = UDim2.new(0.05, 0, 0, 30)
	progressBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	progressBg.BorderSizePixel = 0
	progressBg.Parent = background

	local progressBgCorner = Instance.new("UICorner")
	progressBgCorner.CornerRadius = UDim.new(0, 4)
	progressBgCorner.Parent = progressBg

	-- Create progress bar fill
	local progress = self:GetProgress() / 100
	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(progress, 0, 1, 0)
	progressFill.BackgroundColor3 = self:GetProgressColor()
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBg

	local progressFillCorner = Instance.new("UICorner")
	progressFillCorner.CornerRadius = UDim.new(0, 4)
	progressFillCorner.Parent = progressFill

	-- Create progress text
	local progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressText"
	progressText.Size = UDim2.new(1, 0, 0, 16)
	progressText.Position = UDim2.new(0, 0, 0, 42)
	progressText.BackgroundTransparency = 1
	progressText.Text = string.format("%d / %d blocks", self:GetFilledBlockCount(), #self.Definition.blocks)
	progressText.TextColor3 = Color3.fromRGB(200, 200, 200)
	progressText.TextSize = 12
	progressText.Font = Enum.Font.Gotham
	progressText.Parent = background

	-- Position at the center of the blueprint
	local blueprintCenter = buildingAreaOrigin + self.RelativePosition + (self.Definition.size / 2)

	-- Create an attachment point part (invisible)
	local attachPart = Instance.new("Part")
	attachPart.Name = "ProgressAttachment"
	attachPart.Size = Vector3.new(0.1, 0.1, 0.1)
	attachPart.Position = blueprintCenter
	attachPart.Anchored = true
	attachPart.CanCollide = false
	attachPart.Transparency = 1
	attachPart.Parent = workspace

	billboard.Adornee = attachPart
	billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	self.ProgressBillboard = billboard
	self._ProgressAttachment = attachPart
end

-- Hide progress billboard
function ClientBaseBlueprint:HideProgressBillboard()
	if self.ProgressBillboard then
		self.ProgressBillboard:Destroy()
		self.ProgressBillboard = nil
	end

	if self._ProgressAttachment then
		self._ProgressAttachment:Destroy()
		self._ProgressAttachment = nil
	end
end

-- Update progress billboard (call after blocks change)
function ClientBaseBlueprint:UpdateProgressBillboard()
	if not self.ProgressBillboard or not self.Definition then return end

	local background = self.ProgressBillboard:FindFirstChild("Background")
	if not background then return end

	-- Update progress bar
	local progressBg = background:FindFirstChild("ProgressBg")
	if progressBg then
		local progressFill = progressBg:FindFirstChild("ProgressFill")
		if progressFill then
			local progress = self:GetProgress() / 100
			progressFill.Size = UDim2.new(progress, 0, 1, 0)
			progressFill.BackgroundColor3 = self:GetProgressColor()
		end
	end

	-- Update progress text
	local progressText = background:FindFirstChild("ProgressText")
	if progressText then
		progressText.Text = string.format("%d / %d blocks", self:GetFilledBlockCount(), #self.Definition.blocks)
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
	self:HideProgressBillboard()
	self:ClearWrongBlockHighlights()
	self.Model = nil
end

return ClientBaseBlueprint
