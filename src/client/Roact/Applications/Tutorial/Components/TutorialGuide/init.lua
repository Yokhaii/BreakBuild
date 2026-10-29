--[=[
	TutorialGuide Component
	Top-middle HUD panel explaining the current tutorial step:
	"TUTORIAL x/y" title above the sub-step hint computed by TutorialController.

	Props:
		StepIndex, StepCount (number)
		Hint                 (string)
		ZIndex
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local HudPanel = require(Components.Frames.HudPanel)

local Config = require(script.Config)

local function TutorialGuide(props, _hooks)
	local zIndex = props.ZIndex or 1

	return Roact.createElement(HudPanel, {
		Name = "TutorialGuide",
		Size = Config.Size,
		Position = Config.Position,
		AnchorPoint = Config.AnchorPoint,
		Title = string.format(Config.TitleText, props.StepIndex or 1, props.StepCount or 1),
		TitleShare = Config.TitleShare,
		ZIndex = zIndex,
	}, {
		Body = Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = zIndex + 1,
		}, {
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = Config.PaddingHorizontal,
				PaddingRight = Config.PaddingHorizontal,
				PaddingTop = Config.PaddingVertical,
				PaddingBottom = Config.PaddingVertical,
			}),

			Hint = Roact.createElement(FancyText, {
				Text = props.Hint or "",
				Size = Config.HintSize,
				TextColor3 = Config.HintColor,
				FontFace = Config.HintFont,
				ZIndex = zIndex + 2,
			}),
		}),
	})
end

TutorialGuide = RoactHooks.new(Roact)(TutorialGuide)
return TutorialGuide
