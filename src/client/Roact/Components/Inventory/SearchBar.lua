--[=[
	SearchBar Component
	Search input for filtering backpack items
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local InventoryActions = require(Actions.InventoryActions)

local function SearchBar(props, hooks)
	local store = RoduxHooks.useStore(hooks)

	local searchQuery = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer.SearchQuery or ""
	end)

	local function handleTextChanged(rbx)
		store:dispatch(InventoryActions.setSearchQuery(rbx.Text))
	end

	return Roact.createElement("Frame", {
		Name = "SearchBar",
		Size = UDim2.fromOffset(182, 47),
		Position = UDim2.fromScale(0.696, -0.181),
		BackgroundColor3 = Color3.fromRGB(91, 91, 91),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Thickness = 1,
			Color = Color3.fromRGB(0, 0, 0),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),

		TextBox = Roact.createElement("TextBox", {
			Name = "TextBox",
			Size = UDim2.fromOffset(164, 33),
			Position = UDim2.fromScale(0.055, 0.17),
			BackgroundTransparency = 1,
			Text = searchQuery,
			PlaceholderText = "Search",
			PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
			TextColor3 = Color3.fromRGB(0, 0, 0),
			TextSize = 14,
			Font = Enum.Font.SourceSans,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			[Roact.Change.Text] = handleTextChanged,
		}),
	})
end

SearchBar = RoactHooks.new(Roact)(SearchBar)
return SearchBar
