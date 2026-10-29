--[=[
	Tutorial Application
	Onboarding tutorial overlay, mounted in its own ScreenGui above the game UI.
	  TutorialGuide — top-middle panel explaining the current step ("TUTORIAL x/y" + hint)
	  Spotlight     — darkens the screen except the UI element to click, with a click icon
	The tutorial steps are the main objectives flagged `tutorial` (ObjectiveReducer); the
	hint and spotlight target are computed by TutorialController.
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

-- Data
local ObjectiveData = require(ReplicatedStorage.Shared.Data.ObjectiveData)

-- Components
local Spotlight = require(script.Components.Spotlight)
local TutorialGuide = require(script.Components.TutorialGuide)

local Config = require(script.Config)

-- Tutorial objectives are the first main objectives
local TUTORIAL_STEP_COUNT = ObjectiveData.GetFirstNonTutorialIndex() - 1

local function TutorialApplication(_, hooks)
	local tutorialState = RoduxHooks.useSelector(hooks, function(state)
		return state.TutorialReducer
	end)

	local mainIndex = RoduxHooks.useSelector(hooks, function(state)
		return state.ObjectiveReducer.MainIndex
	end)

	local objective = ObjectiveData.Main[mainIndex]
	local isTutorialActive = objective ~= nil and objective.tutorial == true

	if not isTutorialActive then
		return Roact.createElement("Frame", { Visible = false, Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1 })
	end

	return Roact.createElement("Frame", {
		Name = "Tutorial",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Guide = Roact.createElement(TutorialGuide, {
			StepIndex = mainIndex,
			StepCount = TUTORIAL_STEP_COUNT,
			Hint = tutorialState.Hint or objective.task or objective.title,
			ZIndex = Config.GuideZIndex,
		}),

		Spotlight = tutorialState.SpotlightTarget and Roact.createElement(Spotlight, {
			TargetId = tutorialState.SpotlightTarget,
			Hint = tutorialState.Hint,
			ZIndex = Config.SpotlightZIndex,
		}) or nil,
	})
end

TutorialApplication = RoactHooks.new(Roact)(TutorialApplication)
return TutorialApplication
