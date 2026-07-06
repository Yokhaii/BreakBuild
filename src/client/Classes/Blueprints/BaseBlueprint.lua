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

-- Crafting progress billboard — matches the TopPanelFrame stud style
local STUD_IMAGE = "rbxassetid://6927295847"
local STUD_TILE_SIZE = UDim2.fromOffset(64, 64) -- fixed pixel tile for world-space billboard

-- Outer shell (grey, like the TopPanelFrame outer background)
local SHELL_COLOR = Color3.fromRGB(145, 145, 145)
local SHELL_IMG_TRANSP = 0.7
local SHELL_CORNER = UDim.new(0.35, 0)
local SHELL_STROKE_COL = Color3.fromRGB(255, 255, 255)
local SHELL_STROKE_T = 0.87
local SHELL_STROKE_W = 1.5

-- Inner track (dark, like the TopPanelFrame content area)
local TRACK_COLOR = Color3.fromRGB(40, 40, 40)
local TRACK_IMG_TRANSP = 0.75
local TRACK_CORNER = UDim.new(0.28, 0)

-- Fill color (matches the craft button color per-station — grey neutral default)
local FILL_COLOR = Color3.fromRGB(114, 114, 114)
local FILL_IMG_TRANSP = 0.55

-- Billboard world dimensions — tweak these to move / resize the widget
local CRAFT_BILLBOARD_SIZE = UDim2.fromScale(5.4, 0.65)
local CRAFT_BILLBOARD_OFFSET = Vector3.new(0, 3, 0)
local CRAFT_BILLBOARD_MAX_DIST = 60

-- Layout proportions inside the billboard (all Scale values)
-- Time label occupies the top portion; shell occupies the bottom portion
local SHELL_HEIGHT = 0.8 -- fraction of billboard height used by the bar shell
local TIME_LABEL_SIZE = UDim2.fromScale(1, 1 - SHELL_HEIGHT)

local TRACK_W = 0.99 -- track width relative to shell
local TRACK_H = 0.86 -- track height relative to shell

-- Time label appearance
local TIME_LABEL_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local TIME_LABEL_COLOR = Color3.fromRGB(255, 255, 255)
local TIME_LABEL_STROKE_COL = Color3.fromRGB(0, 0, 0)
local TIME_LABEL_STROKE_W = 1.5

function ClientBaseBlueprint.new(data)
	local self = SharedBaseBlueprint.new(data)
	setmetatable(self, ClientBaseBlueprint)

	-- Client-specific properties
	self.Model = nil -- Reference to the model in workspace
	self.HoverBillboard = nil -- BillboardGui for hover label
	self.WrongBlockHighlights = {} -- { [blockId]: Highlight }
	self._CraftingBillboard = nil -- BillboardGui (single, contains bar + time label)
	self._CraftingBarFill = nil -- Fill ImageLabel inside the bar
	self._CraftingTimeLabel = nil -- TextLabel inside the billboard

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
	if not requiredType then
		return
	end

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
	if not self.Model or not self.Definition then
		return
	end

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
	if not self.Model or not self.Definition then
		return
	end

	local offsetKey = self:_OffsetToKey(offset)
	local partName = "GhostBlock_" .. offsetKey

	local part = self.Model:FindFirstChild(partName, true)
	if not part or not part:IsA("BasePart") then
		return
	end

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
	if not self.Model or not self.Definition then
		return
	end

	local offsetKey = self:_OffsetToKey(offset)
	local partName = "GhostBlock_" .. offsetKey

	local part = self.Model:FindFirstChild(partName, true)
	if not part or not part:IsA("BasePart") then
		return
	end

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

-- Build the stud-style progress billboard (lazy, called once).
local function buildCraftingBillboard(adornee)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CraftingProgressBillboard"
	billboard.Size = CRAFT_BILLBOARD_SIZE
	billboard.StudsOffsetWorldSpace = CRAFT_BILLBOARD_OFFSET
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = CRAFT_BILLBOARD_MAX_DIST
	billboard.Adornee = adornee
	billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Time label — floats above the bar, using the top portion of the billboard space
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "TimeLabel"
	timeLabel.Size = TIME_LABEL_SIZE
	timeLabel.Position = UDim2.fromScale(0, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = ""
	timeLabel.TextColor3 = TIME_LABEL_COLOR
	timeLabel.TextScaled = true
	timeLabel.FontFace = TIME_LABEL_FONT
	timeLabel.ZIndex = 4
	timeLabel.Parent = billboard

	local timeLabelStroke = Instance.new("UIStroke")
	timeLabelStroke.Color = TIME_LABEL_STROKE_COL
	timeLabelStroke.Thickness = TIME_LABEL_STROKE_W
	timeLabelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	timeLabelStroke.Parent = timeLabel

	-- Outer shell — grey stud panel, anchored to the bottom of the billboard
	local shell = Instance.new("ImageLabel")
	shell.Name = "Shell"
	shell.Size = UDim2.fromScale(1, SHELL_HEIGHT)
	shell.Position = UDim2.fromScale(0, 1)
	shell.AnchorPoint = Vector2.new(0, 1)
	shell.BackgroundColor3 = SHELL_COLOR
	shell.BorderSizePixel = 0
	shell.Image = STUD_IMAGE
	shell.ImageColor3 = Color3.fromRGB(255, 255, 255)
	shell.ImageTransparency = SHELL_IMG_TRANSP
	shell.ScaleType = Enum.ScaleType.Tile
	shell.TileSize = STUD_TILE_SIZE
	shell.ZIndex = 1
	shell.Parent = billboard

	local shellCorner = Instance.new("UICorner")
	shellCorner.CornerRadius = SHELL_CORNER
	shellCorner.Parent = shell

	local shellStroke = Instance.new("UIStroke")
	shellStroke.Color = SHELL_STROKE_COL
	shellStroke.Thickness = SHELL_STROKE_W
	shellStroke.Transparency = SHELL_STROKE_T
	shellStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	shellStroke.Parent = shell

	-- Inner track — dark stud, inset inside the shell, clips the fill
	local track = Instance.new("ImageLabel")
	track.Name = "Track"
	track.Size = UDim2.fromScale(TRACK_W, TRACK_H)
	track.Position = UDim2.fromScale(0.5, 0.5)
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.BackgroundColor3 = TRACK_COLOR
	track.BorderSizePixel = 0
	track.Image = STUD_IMAGE
	track.ImageColor3 = Color3.fromRGB(255, 255, 255)
	track.ImageTransparency = TRACK_IMG_TRANSP
	track.ScaleType = Enum.ScaleType.Tile
	track.TileSize = STUD_TILE_SIZE
	track.ClipsDescendants = true
	track.ZIndex = 2
	track.Parent = shell

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = TRACK_CORNER
	trackCorner.Parent = track

	-- Fill — colored stud, grows left-to-right, clipped by track's rounded corners
	local fill = Instance.new("ImageLabel")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.Position = UDim2.fromScale(0, 0)
	fill.AnchorPoint = Vector2.new(0, 0)
	fill.BackgroundColor3 = FILL_COLOR
	fill.BorderSizePixel = 0
	fill.Image = STUD_IMAGE
	fill.ImageColor3 = Color3.fromRGB(255, 255, 255)
	fill.ImageTransparency = FILL_IMG_TRANSP
	fill.ScaleType = Enum.ScaleType.Tile
	fill.TileSize = STUD_TILE_SIZE
	fill.ZIndex = 3
	fill.Parent = track

	return billboard, fill, timeLabel
end

-- Show (or create) the stud-style crafting progress billboard.
-- progress: 0..1   secsRemaining: seconds left (nil = don't update label)
function ClientBaseBlueprint:ShowCraftingProgress(progress: number, secsRemaining: number?)
	if not self.Model then
		return
	end

	local adornee = self.Model:FindFirstChild("BillboardAttach", true)
		or self.Model.PrimaryPart
		or self.Model:FindFirstChildWhichIsA("BasePart")
	if not adornee then
		return
	end

	if not self._CraftingBillboard then
		local billboard, fill, timeLabel = buildCraftingBillboard(adornee)
		self._CraftingBillboard = billboard
		self._CraftingBarFill = fill
		self._CraftingTimeLabel = timeLabel
	end

	self._CraftingBarFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)

	if secsRemaining ~= nil then
		if secsRemaining <= 0 and progress >= 1 then
			self._CraftingTimeLabel.Text = "Ready!"
		else
			local secs = math.ceil(secsRemaining)
			local mins = math.floor(secs / 60)
			local displaySecs = secs % 60
			self._CraftingTimeLabel.Text = mins > 0 and string.format("%d:%02d", mins, displaySecs)
				or string.format("%ds", displaySecs)
		end
	end

	self:OnCrafting(progress)
end

-- Destroy the crafting progress billboard.
function ClientBaseBlueprint:HideCraftingProgress()
	if self._CraftingBillboard then
		self._CraftingBillboard:Destroy()
		self._CraftingBillboard = nil
		self._CraftingBarFill = nil
		self._CraftingTimeLabel = nil
	end
end

-- Override in subclasses to react to crafting progress updates (sounds, particles, etc.).
-- progress: 0..1
function ClientBaseBlueprint:OnCrafting(progress: number)
	-- stub — override per station class
end

-- Override in subclasses to react when the craft is received by the player
-- (i.e. the station is opened and the ready craft is collected).
function ClientBaseBlueprint:OnCraftReceived()
	-- stub — override per station class
end

-- Cleanup
function ClientBaseBlueprint:Destroy()
	self:HideHoverLabel()
	self:ClearWrongBlockHighlights()
	self:HideCraftingProgress()
	self.Model = nil
end

return ClientBaseBlueprint
