--[=[
	StudBackground Component
	A tiled background image that maintains the same NUMBER of tiles
	across all screen resolutions.

	The tile size scales with viewport so you always see the same
	tile count regardless of screen size (phone, 1080p, 4K, etc.)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Camera = workspace.CurrentCamera

local Config = require(script.Config)

local function StudBackground(props, hooks)
	-- State to track calculated tile size
	local tileSize, setTileSize = hooks.useState(Config.BaseTileSize)

	-- Calculate tile size based on viewport to maintain same tile count
	local function calculateTileSize()
		local viewportSize = Camera.ViewportSize

		-- Scale factor: how much bigger/smaller is current screen vs reference
		local scaleFactor = viewportSize.X / Config.ReferenceWidth

		-- Scale the tile size proportionally
		local newTileSize = math.round(Config.BaseTileSize * scaleFactor)

		return newTileSize
	end

	-- Update tile size on mount and when viewport changes
	hooks.useEffect(function()
		-- Initial calculation
		setTileSize(calculateTileSize())

		-- Listen for viewport size changes (window resize, orientation change)
		local connection = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setTileSize(calculateTileSize())
		end)

		-- Cleanup
		return function()
			connection:Disconnect()
		end
	end, {})

	-- Build children table with optional UICorner and UIStroke
	local children = {}

	-- Add UICorner if CornerRadius is provided
	if props.CornerRadius then
		children.UICorner = Roact.createElement("UICorner", {
			CornerRadius = props.CornerRadius,
		})
	end

	-- Add UIStroke if stroke properties are provided
	if props.StrokeThickness or props.StrokeColor then
		children.UIStroke = Roact.createElement("UIStroke", {
			Color = props.StrokeColor or Color3.fromRGB(0, 0, 0),
			Thickness = props.StrokeThickness or 2,
			Transparency = props.StrokeTransparency or 0,
			ApplyStrokeMode = props.StrokeMode or Enum.ApplyStrokeMode.Border,
		})
	end

	-- Merge with any passed children
	if props[Roact.Children] then
		for key, child in pairs(props[Roact.Children]) do
			children[key] = child
		end
	end

	return Roact.createElement("ImageLabel", {
		Name = props.Name or "StudBackground",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = props.BackgroundColor or Config.BackgroundColor,
		BackgroundTransparency = props.BackgroundTransparency or 0,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex or 1,

		-- Image properties
		Image = props.Image or Config.Image,
		ImageColor3 = props.ImageColor or Config.ImageColor,
		ImageTransparency = props.ImageTransparency or Config.ImageTransparency,

		-- Tiling - scaled to maintain same tile count
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(tileSize, tileSize),
	}, children)
end

StudBackground = RoactHooks.new(Roact)(StudBackground)
return StudBackground
