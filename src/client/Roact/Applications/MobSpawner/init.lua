--[=[
	MobSpawner Application (dev only, N key, CurrentFrame == "MobSpawner")
	Spawns mobs frozen in front of the player, then lets the dev enable them and force
	behaviors (flee, come, chase, hit) to test the mob system. Buttons go through MobController.
	Counts come from DevMobReducer (MobService.DevStateChanged).
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
local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components

-- Components
local BaseFrame = require(Components.Frames.BaseFrame)
local FancyText = require(Components.Global.FancyText)
local DevButton = require(script.Components.DevButton)

-- Data
local MobData = require(ReplicatedStorage.Shared.Data.MobData)

local Config = require(script.Config)

local ACTION_ROWS = 4

local sortedMobTypes
local function getSortedMobTypes()
	if sortedMobTypes then return sortedMobTypes end
	sortedMobTypes = {}
	for mobType in pairs(MobData.Mobs) do
		table.insert(sortedMobTypes, mobType)
	end
	table.sort(sortedMobTypes, function(a, b)
		return MobData.Mobs[a].displayName < MobData.Mobs[b].displayName
	end)
	return sortedMobTypes
end

local function getMobController()
	return Knit.GetController("MobController")
end

-- Canvas height (in visible list heights) needed by every row + padding
local function getCanvasHeight(): number
	local rowCount = 2 + #getSortedMobTypes() + ACTION_ROWS + 1
	local total = Config.SectionHeight * 2
		+ Config.MobRowHeight * #getSortedMobTypes()
		+ Config.ActionRowHeight * ACTION_ROWS
		+ Config.ToggleHeight
		+ Config.ListPadding * (rowCount - 1)
		+ Config.ListInnerPadding.Scale * 2
	return math.max(1, total)
end

local function sectionTitle(text: string, height: UDim2, layoutOrder: number, zIndex: number)
	return Roact.createElement(FancyText, {
		Text = text,
		Size = height,
		TextColor3 = Config.SectionTextColor,
		StrokeColor = Config.SectionStrokeColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
	})
end

-- Two buttons side by side: { text, onClick, color? }
local function actionRow(left, right, height: UDim2, layoutOrder: number, zIndex: number)
	local function button(action, xAlign)
		return Roact.createElement(DevButton, {
			Text = action[1],
			OnClick = action[2],
			Color = action[3] or Config.ActionColor,
			Size = UDim2.fromScale(Config.ActionButtonWidth, 1),
			Position = UDim2.fromScale(xAlign, 0),
			AnchorPoint = Vector2.new(xAlign, 0),
			ZIndex = zIndex + 1,
		})
	end
	return Roact.createElement("Frame", {
		Size = height,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
	}, {
		Left = button(left, 0),
		Right = right and button(right, 1) or nil,
	})
end

local function mobRow(mobType: string, count: number, height: UDim2, layoutOrder: number, zIndex: number)
	local children = {
		Name = Roact.createElement(FancyText, {
			Text = string.format(Config.MobCountText, MobData.Mobs[mobType].displayName, count),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = Config.MobNameSize,
			TextColor3 = Config.MobNameTextColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = zIndex + 1,
		}),
	}
	for i, amount in ipairs(Config.SpawnAmounts) do
		local xScale = 1 - (#Config.SpawnAmounts - i) * (Config.SpawnButtonSize.X.Scale + 0.02)
		children["Spawn" .. amount] = Roact.createElement(DevButton, {
			Text = "+" .. amount,
			Color = Config.SpawnButtonColor,
			Size = Config.SpawnButtonSize,
			Position = UDim2.fromScale(xScale, 0.5),
			AnchorPoint = Vector2.new(1, 0.5),
			ZIndex = zIndex + 1,
			OnClick = function()
				getMobController():DevSpawn(mobType, amount)
			end,
		})
	end
	return Roact.createElement("Frame", {
		Size = height,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
	}, children)
end

local function MobSpawner(_props, hooks)
	local currentFrame = RoduxHooks.useSelector(hooks, function(state)
		return state.UIReducer.CurrentFrame
	end)
	local devState = RoduxHooks.useSelector(hooks, function(state)
		return state.DevMobReducer
	end)

	if currentFrame ~= Config.FrameName then
		return Roact.createElement("Frame", { Visible = false })
	end

	-- Children sizes are relative to the canvas, so divide by its height
	local canvasHeight = getCanvasHeight()
	local function rowHeight(height: number): UDim2
		return UDim2.fromScale(1, height / canvasHeight)
	end

	local zIndex = Config.ZIndex + 2
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local innerPadding = UDim.new(Config.ListInnerPadding.Scale / canvasHeight, 0)
	local listChildren = {
		UIListLayout = Roact.createElement("UIListLayout", {
			Padding = UDim.new(Config.ListPadding / canvasHeight, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		UIPadding = Roact.createElement("UIPadding", {
			PaddingTop = innerPadding,
			PaddingBottom = innerPadding,
			PaddingLeft = Config.ListInnerPadding,
			PaddingRight = Config.ListInnerPadding,
		}),
		SpawnTitle = sectionTitle(Config.SpawnSectionText, rowHeight(Config.SectionHeight), nextOrder(), zIndex),
	}

	for _, mobType in ipairs(getSortedMobTypes()) do
		listChildren["Mob_" .. mobType] = mobRow(mobType, devState.ByType[mobType] or 0, rowHeight(Config.MobRowHeight), nextOrder(), zIndex)
	end

	local controller = getMobController()
	local actionHeight = rowHeight(Config.ActionRowHeight)
	listChildren.MobsTitle = sectionTitle(
		string.format(Config.MobsSectionText, devState.Total, devState.Frozen, devState.DevSpawned),
		rowHeight(Config.SectionHeight),
		nextOrder(),
		zIndex
	)
	listChildren.Row1 = actionRow(
		{ "Enable frozen", function() controller:DevEnableAll() end },
		{ "Freeze all", function() controller:DevFreezeAll() end },
		actionHeight, nextOrder(), zIndex
	)
	listChildren.Row2 = actionRow(
		{ "Flee from me", function() controller:DevFleeFromMe() end },
		{ "Come to me", function() controller:DevComeToMe() end },
		actionHeight, nextOrder(), zIndex
	)
	listChildren.Row3 = actionRow(
		{ "Chase me", function() controller:DevChaseMe() end },
		{ "Hit nearest", function() controller:DevHitNearest() end },
		actionHeight, nextOrder(), zIndex
	)
	listChildren.Row4 = actionRow(
		{ "Despawn dev", function() controller:DevDespawn(true) end, Config.DangerColor },
		{ "Despawn all", function() controller:DevDespawn(false) end, Config.DangerColor },
		actionHeight, nextOrder(), zIndex
	)
	listChildren.NaturalToggle = Roact.createElement(DevButton, {
		Text = string.format(Config.NaturalSpawnText, devState.NaturalSpawning and "ON" or "OFF"),
		Color = devState.NaturalSpawning and Config.ToggleOnColor or Config.ToggleOffColor,
		Size = rowHeight(Config.ToggleHeight),
		LayoutOrder = nextOrder(),
		ZIndex = zIndex,
		OnClick = function()
			controller:DevToggleNaturalSpawning()
		end,
	})

	return Roact.createElement(BaseFrame, {
		Name = "MobSpawner",
		Visible = true,
		Title = Config.Title,
		Size = Config.FrameSize,
		Position = Config.FramePosition,
		AspectRatio = Config.FrameAspectRatio,
		ZIndex = Config.ZIndex,
		OnClose = function()
			controller:CloseMobSpawner()
		end,
	}, {
		List = Roact.createElement("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = Config.ScrollBarThickness,
			ScrollBarImageColor3 = Config.ScrollBarColor,
			CanvasSize = UDim2.fromScale(0, canvasHeight),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ZIndex = zIndex,
		}, listChildren),
	})
end

MobSpawner = RoactHooks.new(Roact)(MobSpawner)
return MobSpawner
