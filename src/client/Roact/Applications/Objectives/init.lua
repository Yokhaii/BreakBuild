--[=[
	Objectives Application
	Full list of the player's objectives, opened by clicking the HUD ObjectivesTracker title.
	Tabs: Active (rewards to claim, current main + unlocked side objectives), Locked (upcoming),
	Done (claimed). CLAIM buttons only exist here; the HUD title shows a red dot when one is ready.
	Side objectives can be pinned to the HUD from here; completed ones are claimed here too.
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Modules
local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Directories
local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components
local ObjectiveStatus = require(Client.Modules.ObjectiveStatus)

-- Components
local PanelFrame = require(Components.Frames.PanelFrame)
local FancyText = require(Components.Global.FancyText)
local CloseButton = require(Components.Global.CloseButton)
local DarkOverlay = require(Components.Global.DarkOverlay)

local ObjectiveTabs = require(script.Components.ObjectiveTabs)
local ObjectiveList = require(script.Components.ObjectiveList)

-- Data
local ObjectiveData = require(ReplicatedStorage.Shared.Data.ObjectiveData)

local Config = require(script.Config)

-- Sort rank inside the Active tab: rewards to claim, then the main objective, then side ones
local function getActiveRank(entry): number
	if entry.Status == ObjectiveStatus.Complete then return 0 end
	if entry.Objective.isMain then return 1 end
	return 2
end

-- Split every objective into the Active / Locked / Completed tabs
local function buildEntries(objectivesState)
	local entriesByTab = { Active = {}, Locked = {}, Completed = {} }
	local order = 0

	local function addObjective(objective)
		order = order + 1
		local status, current, required = ObjectiveStatus.Get(objectivesState, objective)
		local entry = {
			Objective = objective,
			Status = status,
			Current = current,
			Required = required,
			IsPinned = ObjectiveStatus.IsPinned(objectivesState, objective.id),
			Order = order,
		}

		if status == ObjectiveStatus.Claimed then
			table.insert(entriesByTab.Completed, entry)
		elseif status == ObjectiveStatus.Locked then
			table.insert(entriesByTab.Locked, entry)
		else
			table.insert(entriesByTab.Active, entry)
		end
	end

	for _, objective in ipairs(ObjectiveData.Main) do
		addObjective(objective)
	end
	for _, objective in ipairs(ObjectiveData.Side) do
		addObjective(objective)
	end

	table.sort(entriesByTab.Active, function(a, b)
		local rankA, rankB = getActiveRank(a), getActiveRank(b)
		if rankA ~= rankB then
			return rankA < rankB
		end
		return a.Order < b.Order
	end)

	return entriesByTab
end

local function ObjectivesApplication(_, hooks)
	local currentFrame = RoduxHooks.useSelector(hooks, function(state)
		return state.UIReducer.CurrentFrame
	end)

	local objectivesState = RoduxHooks.useSelector(hooks, function(state)
		return state.ObjectiveReducer
	end)

	local selectedTab, setSelectedTab = hooks.useState(Config.DefaultTab)

	local entriesByTab = hooks.useMemo(function()
		return buildEntries(objectivesState)
	end, { objectivesState })

	local onClose = hooks.useCallback(function()
		Knit.GetController("ObjectiveController"):CloseObjectives()
	end, {})

	if currentFrame ~= Config.FrameName then
		return Roact.createElement("Frame", { Visible = false, Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1 })
	end

	local tabs = {}
	for _, tab in ipairs(Config.Tabs) do
		table.insert(tabs, { key = tab.key, label = tab.label, count = #entriesByTab[tab.key] })
	end

	return Roact.createElement(DarkOverlay, {
		Name = "ObjectivesOverlay",
		ZIndex = Config.OverlayZIndex,
		OnClose = onClose,
	}, {
		Container = Roact.createElement("Frame", {
			Name = "ObjectivesContainer",
			Size = Config.ContainerSize,
			Position = Config.ContainerPosition,
			AnchorPoint = Config.ContainerAnchorPoint,
			BackgroundTransparency = 1,
			ZIndex = Config.PanelZIndex,
		}, {
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = Config.ContainerAspectRatio,
			}),

			Panel = Roact.createElement(PanelFrame, {
				Name = "ObjectivesPanel",
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Title = Config.Title,
				ZIndex = Config.PanelZIndex,
			}, {
				Tabs = Roact.createElement(ObjectiveTabs, {
					Tabs = tabs,
					SelectedTab = selectedTab,
					OnSelect = setSelectedTab,
					Size = Config.TabsSize,
					Position = Config.TabsPosition,
					ZIndex = Config.ContentZIndex,
				}),

				PinCount = Roact.createElement(FancyText, {
					Text = string.format(Config.PinCountText, #objectivesState.Pinned, ObjectiveData.MaxPinned),
					Size = Config.PinCountSize,
					Position = Config.PinCountPosition,
					AnchorPoint = Config.PinCountAnchorPoint,
					TextColor3 = Config.PinCountColor,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = Config.ContentZIndex,
				}),

				List = Roact.createElement(ObjectiveList, {
					Entries = entriesByTab[selectedTab],
					Size = Config.ListSize,
					Position = Config.ListPosition,
					ZIndex = Config.ContentZIndex,
				}),
			}),

			CloseButton = Roact.createElement(CloseButton, {
				Position = Config.CloseButtonPosition,
				AnchorPoint = Config.CloseButtonAnchorPoint,
				Size = Config.CloseButtonSize,
				OnClick = onClose,
				ZIndex = Config.ContentZIndex + 6,
			}),
		}),
	})
end

ObjectivesApplication = RoactHooks.new(Roact)(ObjectivesApplication)
return ObjectivesApplication
