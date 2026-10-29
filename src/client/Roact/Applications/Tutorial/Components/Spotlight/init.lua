--[=[
	Spotlight Component
	Darkens the whole screen except a hole around a registered UI target (TutorialTargets),
	with a pulsing ring, a bobbing click icon and the hint text next to the hole.
	The four dark frames around the hole sink input, so only the target can be clicked.
	If the target is not mounted / visible, nothing is shown and nothing is blocked.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Client = StarterPlayer.StarterPlayerScripts.Client
local FancyText = require(Client.Roact.Components.Global.FancyText)
local TutorialTargets = require(Client.Modules.TutorialTargets)

local ClickIcon = require(script.Parent.ClickIcon)

local Config = require(script.Config)

-- Position and size (in screen scale) of each dark frame around the hole
local OVERLAY_SIDES = {
	Top = function(hole)
		return UDim2.fromScale(0, 0), UDim2.fromScale(1, hole.Top)
	end,
	Bottom = function(hole)
		return UDim2.fromScale(0, hole.Bottom), UDim2.fromScale(1, 1 - hole.Bottom)
	end,
	Left = function(hole)
		return UDim2.fromScale(0, hole.Top), UDim2.fromScale(hole.Left, hole.Bottom - hole.Top)
	end,
	Right = function(hole)
		return UDim2.fromScale(hole.Right, hole.Top), UDim2.fromScale(1 - hole.Right, hole.Bottom - hole.Top)
	end,
}

local function Spotlight(props, hooks)
	local baseZIndex = props.ZIndex or 10
	local rootRef = hooks.useValue(Roact.createRef())

	-- false when hidden, otherwise { Left, Top, Right, Bottom } in screen scale
	local hole, setHole = hooks.useBinding(false)
	local iconPosition, setIconPosition = hooks.useBinding(UDim2.fromScale(0, 0))
	local hintPosition, setHintPosition = hooks.useBinding(UDim2.fromScale(0, 0))
	local hintAnchorPoint, setHintAnchorPoint = hooks.useBinding(Vector2.new(0.5, 0))
	local ringTransparency, setRingTransparency = hooks.useBinding(0)

	-- Follow the target every frame (it can move: scrolling lists, layout changes, resizes)
	hooks.useEffect(function()
		local startedAt = os.clock()

		local connection = RunService.RenderStepped:Connect(function()
			local root = rootRef.value:getValue()
			local target = TutorialTargets.Get(props.TargetId)
			if not root or not target or root.AbsoluteSize.X <= 0 or root.AbsoluteSize.Y <= 0 then
				setHole(false)
				return
			end

			local rootSize = root.AbsoluteSize
			local padding = math.min(target.AbsoluteSize.X, target.AbsoluteSize.Y) * Config.HolePadding
			local paddingVector = Vector2.new(padding, padding)
			local topLeft = target.AbsolutePosition - root.AbsolutePosition - paddingVector
			local bottomRight = topLeft + target.AbsoluteSize + paddingVector * 2

			local left = math.clamp(topLeft.X / rootSize.X, 0, 1)
			local top = math.clamp(topLeft.Y / rootSize.Y, 0, 1)
			local right = math.clamp(bottomRight.X / rootSize.X, 0, 1)
			local bottom = math.clamp(bottomRight.Y / rootSize.Y, 0, 1)
			setHole({ Left = left, Top = top, Right = right, Bottom = bottom })

			local wave = math.sin((os.clock() - startedAt) * Config.PulseSpeed)
			local centerX = (left + right) / 2
			local centerY = (top + bottom) / 2

			setIconPosition(UDim2.fromScale(
				centerX + Config.IconOffset.X,
				centerY + Config.IconOffset.Y + wave * Config.IconBobAmplitude
			))
			setRingTransparency(Config.RingMinTransparency
				+ (wave * 0.5 + 0.5) * (Config.RingMaxTransparency - Config.RingMinTransparency))

			-- Hint goes on the side of the hole with the most room
			local hintX = math.clamp(centerX, Config.HintEdgeMargin, 1 - Config.HintEdgeMargin)
			if centerY > 0.5 then
				setHintPosition(UDim2.fromScale(hintX, top - Config.HintGapAbove))
				setHintAnchorPoint(Vector2.new(0.5, 1))
			else
				setHintPosition(UDim2.fromScale(hintX, bottom + Config.HintGapBelow))
				setHintAnchorPoint(Vector2.new(0.5, 0))
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { props.TargetId })

	local isVisible = hole:map(function(value)
		return value ~= false
	end)

	local children = {}

	for side, getRect in pairs(OVERLAY_SIDES) do
		children["Overlay" .. side] = Roact.createElement("ImageButton", {
			Name = "Overlay" .. side,
			Position = hole:map(function(value)
				return value and (getRect(value)) or UDim2.fromScale(0, 0)
			end),
			Size = hole:map(function(value)
				if not value then return UDim2.fromScale(0, 0) end
				local _, size = getRect(value)
				return size
			end),
			Visible = isVisible,
			BackgroundColor3 = Config.OverlayColor,
			BackgroundTransparency = Config.OverlayTransparency,
			BorderSizePixel = 0,
			Image = "",
			AutoButtonColor = false,
			Active = true,
			ZIndex = baseZIndex,
		})
	end

	children.Ring = Roact.createElement("Frame", {
		Name = "Ring",
		Position = hole:map(function(value)
			return value and UDim2.fromScale(value.Left, value.Top) or UDim2.fromScale(0, 0)
		end),
		Size = hole:map(function(value)
			return value and UDim2.fromScale(value.Right - value.Left, value.Bottom - value.Top) or UDim2.fromScale(0, 0)
		end),
		Visible = isVisible,
		BackgroundTransparency = 1,
		ZIndex = baseZIndex + 1,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.RingCornerRadius,
		}),
		UIStroke = Roact.createElement("UIStroke", {
			Color = Config.RingColor,
			Thickness = Config.RingThickness,
			Transparency = ringTransparency,
		}),
	})

	children.ClickIcon = Roact.createElement(ClickIcon, {
		Position = iconPosition,
		Visible = isVisible,
		ZIndex = baseZIndex + 3,
	})

	children.Hint = props.Hint and Roact.createElement("Frame", {
		Name = "Hint",
		Size = Config.HintSize,
		Position = hintPosition,
		AnchorPoint = hintAnchorPoint,
		Visible = isVisible,
		BackgroundTransparency = 1,
		ZIndex = baseZIndex + 2,
	}, {
		Label = Roact.createElement(FancyText, {
			Text = props.Hint,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = Config.HintColor,
			ZIndex = baseZIndex + 2,
		}),
	}) or nil

	return Roact.createElement("Frame", {
		Name = "Spotlight",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,
		[Roact.Ref] = rootRef.value,
	}, children)
end

Spotlight = RoactHooks.new(Roact)(Spotlight)
return Spotlight
