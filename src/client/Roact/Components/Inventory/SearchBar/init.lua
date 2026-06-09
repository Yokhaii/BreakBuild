--[=[
	SearchBar Component
	Outer grey StudBackground frame (like Hotbar card)
	with a dark slot inside containing the text input
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local InventoryActions = require(Actions.InventoryActions)

local Config = require(script.Config)

local function SearchBar(props, hooks)
	local store = RoduxHooks.useStore(hooks)

	local searchQuery = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer.SearchQuery or ""
	end)

	local function handleTextChanged(rbx)
		store:dispatch(InventoryActions.setSearchQuery(rbx.Text))
	end

	return Roact.createElement("Frame", {
		Name = "SearchBarContainer",
		Size = Config.ContainerSize,
		Position = Config.ContainerPosition,
		AnchorPoint = Config.ContainerAnchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 3,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.ContainerCornerRadius,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = Config.ContainerStrokeColor,
			Thickness = Config.ContainerStrokeThickness,
			Transparency = Config.ContainerStrokeTransparency,
		}),

		ContainerBackground = Roact.createElement(StudBackground, {
			ZIndex = 1,
			BackgroundColor = Config.ContainerBackgroundColor,
			ImageTransparency = Config.ContainerStudImageTransparency,
			CornerRadius = Config.ContainerCornerRadius,
		}),

		SearchSlot = Roact.createElement("Frame", {
			Name = "SearchSlot",
			Size = Config.SlotSize,
			Position = Config.SlotPosition,
			AnchorPoint = Config.SlotAnchorPoint,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 5,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.SlotCornerRadius,
			}),

			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.SlotStrokeColor,
				Thickness = Config.SlotStrokeThickness,
				Transparency = Config.SlotStrokeTransparency,
			}),

			SlotBackground = Roact.createElement(StudBackground, {
				ZIndex = 5,
				BackgroundColor = Config.SlotBackgroundColor,
				ImageTransparency = Config.SlotStudImageTransparency,
				CornerRadius = Config.SlotCornerRadius,
			}),

			TextBox = Roact.createElement("TextBox", {
				Name = "TextBox",
				Size = Config.TextBoxSize,
				Position = Config.TextBoxPosition,
				AnchorPoint = Config.TextBoxAnchorPoint,
				BackgroundTransparency = 1,
				Text = searchQuery,
				PlaceholderText = Config.PlaceholderText,
				PlaceholderColor3 = Config.PlaceholderColor,
				TextColor3 = Config.TextColor,
				TextSize = Config.TextSize,
				TextScaled = true,
				Font = Config.Font,
				TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false,
				ZIndex = 6,
				[Roact.Change.Text] = handleTextChanged,
			}),
		}),
	})
end

SearchBar = RoactHooks.new(Roact)(SearchBar)
return SearchBar
