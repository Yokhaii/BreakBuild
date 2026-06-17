local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(script.Config)

local function CycleTimer(_, hooks)
	local timeRemaining, setTimeRemaining = hooks.useState(0)

	hooks.useEffect(function()
		local GlobalBreakingAreaService = Knit.GetService("GlobalBreakingAreaService")
		local connection = GlobalBreakingAreaService.CycleTimeRemaining:Connect(function(seconds)
			setTimeRemaining(seconds)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	local minutes = math.floor(timeRemaining / 60)
	local seconds = timeRemaining % 60
	local timerText = string.format("%d:%02d", minutes, seconds)

	return Roact.createElement("Frame", {
		Name = "CycleTimer",
		AnchorPoint = Config.FrameAnchorPoint,
		Position = Config.FramePosition,
		Size = Config.FrameSize,
		BackgroundColor3 = Config.BackgroundColor,
		BackgroundTransparency = Config.BackgroundTransparency,
	}, {
		Corner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),

		TimerLabel = Roact.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = timerText,
			TextColor3 = Config.TextColor,
			Font = Config.TextFont,
			TextSize = Config.TextSize,
		}),
	})
end

CycleTimer = RoactHooks.new(Roact)(CycleTimer)
return CycleTimer
