--[=[
	ObjectivesTracker Component
	HUD panel (HudPanel) under the SpawnButton: a light grey "OBJECTIVES" title (click to open
	the Objectives frame, red dot when a reward is ready to claim) above one task per line:
	  - the current main objective, then the next ones greyed out (Config.UpcomingMainCount)
	  - the side objectives the player pinned (green once complete)
	Rewards are only claimed from the Objectives frame.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components
local HudPanel = require(Components.Frames.HudPanel)
local ObjectiveStatus = require(Client.Modules.ObjectiveStatus)

local ObjectiveData = require(ReplicatedStorage.Shared.Data.ObjectiveData)

local ObjectiveRow = require(script.Parent.ObjectiveRow)

local Config = require(script.Config)

local function ObjectivesTracker(_, hooks)
	local objectivesState = RoduxHooks.useSelector(hooks, function(state)
		return state.ObjectiveReducer
	end)

	local onOpen = hooks.useCallback(function()
		Knit.GetController("ObjectiveController"):OpenObjectives()
	end, {})

	if objectivesState.MainIndex == 0 then
		return Roact.createElement("Frame", { Visible = false, Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1 })
	end

	local zIndex = Config.ZIndex

	-- Groups of rows: the current + upcoming main objectives, then the pinned side objectives
	local groups = {}

	local mainGroup = {}
	for offset = 0, Config.UpcomingMainCount do
		local objective = ObjectiveData.Main[objectivesState.MainIndex + offset]
		if objective then
			table.insert(mainGroup, objective)
		end
	end
	if #mainGroup > 0 then
		table.insert(groups, mainGroup)
	end

	local pinnedGroup = {}
	for _, objectiveId in ipairs(objectivesState.Pinned) do
		local objective = ObjectiveData.GetObjective(objectiveId)
		if objective then
			table.insert(pinnedGroup, objective)
		end
	end
	if #pinnedGroup > 0 then
		table.insert(groups, pinnedGroup)
	end

	-- The content panel grows with its rows; rows are sized relative to its padded area
	local rowCount = #mainGroup + #pinnedGroup
	local innerHeight = rowCount * Config.RowHeight + math.max(#groups - 1, 0) * Config.DividerHeight
	local contentHeight = innerHeight + Config.ContentPadding * 2

	local rows = {}
	local layoutOrder = 0
	for groupIndex, group in ipairs(groups) do
		if groupIndex > 1 then
			layoutOrder = layoutOrder + 1
			rows["Divider_" .. groupIndex] = Roact.createElement("Frame", {
				Size = UDim2.fromScale(1, Config.DividerHeight / innerHeight),
				BackgroundTransparency = 1,
				LayoutOrder = layoutOrder,
				ZIndex = zIndex + 1,
			}, {
				Line = Roact.createElement("Frame", {
					Size = Config.DividerSize,
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Config.DividerColor,
					BackgroundTransparency = Config.DividerTransparency,
					BorderSizePixel = 0,
					ZIndex = zIndex + 1,
				}),
			})
		end

		for _, objective in ipairs(group) do
			layoutOrder = layoutOrder + 1
			local status, current, required = ObjectiveStatus.Get(objectivesState, objective)
			rows["Row_" .. objective.id] = Roact.createElement(ObjectiveRow, {
				Objective = objective,
				Status = status,
				Current = current,
				Required = required,
				Size = UDim2.fromScale(1, Config.RowHeight / innerHeight),
				LayoutOrder = layoutOrder,
				ZIndex = zIndex + 1,
			})
		end
	end

	local totalHeight = Config.TitleHeight + (rowCount > 0 and contentHeight or 0)

	return Roact.createElement("Frame", {
		Name = "ObjectivesTracker",
		AnchorPoint = Config.AnchorPoint,
		Position = Config.Position,
		Size = Config.Size,
		BackgroundTransparency = 1,
		ZIndex = zIndex,
	}, {
		Panel = Roact.createElement(HudPanel, {
			Size = UDim2.fromScale(1, totalHeight),
			Title = Config.TitleText,
			TitleShare = Config.TitleHeight / totalHeight,
			OnTitleClick = onOpen,
			ShowBadge = ObjectiveStatus.HasUnclaimed(objectivesState),
			ZIndex = zIndex,
		}, {
			Rows = Roact.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = zIndex + 1,
			}, {
				UIPadding = Roact.createElement("UIPadding", {
					PaddingLeft = Config.ContentPaddingHorizontal,
					PaddingRight = Config.ContentPaddingHorizontal,
					PaddingTop = UDim.new(Config.ContentPadding / contentHeight, 0),
					PaddingBottom = UDim.new(Config.ContentPadding / contentHeight, 0),
				}),

				UIListLayout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				Items = Roact.createFragment(rows),
			}),
		}),
	})
end

ObjectivesTracker = RoactHooks.new(Roact)(ObjectivesTracker)
return ObjectivesTracker
