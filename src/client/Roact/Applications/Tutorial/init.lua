--[=[
	Tutorial Application
	Onboarding tutorial overlay, mounted in its own ScreenGui above the game UI.
	  TaskTracker — current task, progress and sub-step hint (top-right)
	  Spotlight   — darkens the screen except the UI element to click, with a click icon
	Task progress comes from TutorialService; the sub-step (hint + spotlight target)
	is computed by TutorialController.
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

-- Data
local TutorialData = require(ReplicatedStorage.Shared.Data.TutorialData)

-- Components
local TaskTracker = require(script.Components.TaskTracker)
local Spotlight = require(script.Components.Spotlight)

local Config = require(script.Config)

local function TutorialApplication(_, hooks)
	local tutorialState = RoduxHooks.useSelector(hooks, function(state)
		return state.TutorialReducer
	end)

	local isActive = tutorialState.CurrentTask >= 1 and not tutorialState.Completed
	local task = isActive and TutorialData.Tasks[tutorialState.CurrentTask] or nil

	if not task then
		return Roact.createElement("Frame", { Visible = false, Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1 })
	end

	return Roact.createElement("Frame", {
		Name = "Tutorial",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		TaskTracker = Roact.createElement(TaskTracker, {
			TaskIndex = tutorialState.CurrentTask,
			TaskCount = #TutorialData.Tasks,
			Title = task.title,
			Current = tutorialState.Current,
			Required = tutorialState.Required,
			Hint = tutorialState.Hint,
			ZIndex = Config.TrackerZIndex,
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
