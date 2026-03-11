--[[
	GeneralBillboardController.lua
	Handles the GeneralPlayer Billboard UI system
	Creates the entire billboard UI programmatically (no template needed)

	API:
	- GeneralBillboardController:Show(contextName, data) - Shows billboard with specified context
	- GeneralBillboardController:Hide() - Hides the billboard
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Configuration & Data
local BillboardContexts = require(ReplicatedStorage.Shared.Data.BillboardContexts)

-- Player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- GeneralBillboardController
local GeneralBillboardController = Knit.CreateController({
	Name = "GeneralBillboardController",
})

-- Private variables
local billboardGui = nil
local mainFrame = nil
local buttonFrames = {} -- Stores references to button frames (1, 2, 3, Close)
local activeButtons = {} -- Stores active button connections and tweens
local currentContext = nil
local currentData = nil

-- Animation Constants
local HOVER_TWEEN_TIME = 0.15
local HOVER_EASING = Enum.EasingStyle.Quad

-- UI Constants
local UI_CONSTANTS = {
	-- BillboardGui
	Billboard = {
		Size = UDim2.new(6, 0, 3, 0),
		StudsOffset = Vector3.new(1.5, 0, 0),
		MaxDistance = 50,
		AlwaysOnTop = true,
	},
	-- Main Frame
	MainFrame = {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
	},
	-- Button (TextButton - the entire row is clickable)
	Button = {
		Size = UDim2.new(1, 0, 0.2, 0),
		BackgroundColor3 = Color3.fromRGB(34, 34, 34),
		BackgroundTransparency = 0.7,
		TextColor3 = Color3.fromRGB(255, 252, 210),
		Font = Enum.Font.GothamBold,
		DefaultPaddingLeft = 0.05,
		HoverPaddingLeft = 0.13,
	},
	-- Aspect Ratio
	AspectRatio = 2.34,
	-- Layout
	ListPadding = UDim.new(0, 3),
}

--|| Private Functions ||--

-- Creates a single button (entire row is a TextButton)
local function createButton(name, layoutOrder)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UI_CONSTANTS.Button.Size
	button.BackgroundColor3 = UI_CONSTANTS.Button.BackgroundColor3
	button.BackgroundTransparency = UI_CONSTANTS.Button.BackgroundTransparency
	button.BorderSizePixel = 0
	button.Text = ""
	button.TextColor3 = UI_CONSTANTS.Button.TextColor3
	button.TextSize = 14
	button.TextScaled = true
	button.TextWrapped = true
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.TextYAlignment = Enum.TextYAlignment.Center
	button.Font = UI_CONSTANTS.Button.Font
	button.AutoButtonColor = false
	button.LayoutOrder = layoutOrder
	button.Visible = false

	-- Add padding for text (this is what we'll animate)
	local padding = Instance.new("UIPadding")
	padding.Name = "UIPadding"
	padding.PaddingLeft = UDim.new(UI_CONSTANTS.Button.DefaultPaddingLeft, 0)
	padding.PaddingRight = UDim.new(0.02, 0)
	padding.Parent = button

	-- Add black stroke around text
	local stroke = Instance.new("UIStroke")
	stroke.Name = "UIStroke"
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = button

	return button
end

-- Creates the entire billboard GUI hierarchy
-- Parents to PlayerGui with Adornee for proper input handling
local function createBillboardGui(adornee)
	-- BillboardGui - MUST be in PlayerGui for input to work!
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GeneralPlayerBillboard"
	billboard.Size = UI_CONSTANTS.Billboard.Size
	billboard.StudsOffset = UI_CONSTANTS.Billboard.StudsOffset
	billboard.MaxDistance = UI_CONSTANTS.Billboard.MaxDistance
	billboard.AlwaysOnTop = UI_CONSTANTS.Billboard.AlwaysOnTop
	billboard.Active = true
	billboard.Enabled = false
	billboard.ClipsDescendants = false
	billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	billboard.LightInfluence = 1
	billboard.ResetOnSpawn = false
	billboard.Adornee = adornee -- Point to the character part
	billboard.Parent = playerGui -- Parent to PlayerGui for input!

	-- Main Frame (container)
	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Position = UI_CONSTANTS.MainFrame.Position
	frame.Size = UI_CONSTANTS.MainFrame.Size
	frame.AnchorPoint = UI_CONSTANTS.MainFrame.AnchorPoint
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	-- UIListLayout for vertical arrangement
	local listLayout = Instance.new("UIListLayout")
	listLayout.Name = "UIListLayout"
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.Padding = UI_CONSTANTS.ListPadding
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = frame

	-- UIAspectRatioConstraint
	local aspectRatio = Instance.new("UIAspectRatioConstraint")
	aspectRatio.AspectRatio = UI_CONSTANTS.AspectRatio
	aspectRatio.AspectType = Enum.AspectType.FitWithinMaxSize
	aspectRatio.DominantAxis = Enum.DominantAxis.Width
	aspectRatio.Parent = frame

	-- Create buttons (1, 2, 3, Close)
	local button1 = createButton("1", 1)
	button1.Parent = frame

	local button2 = createButton("2", 2)
	button2.Parent = frame

	local button3 = createButton("3", 3)
	button3.Parent = frame

	local closeButton = createButton("Close", 4)
	closeButton.Parent = frame

	return billboard, frame, {
		["1"] = button1,
		["2"] = button2,
		["3"] = button3,
		["Close"] = closeButton,
	}
end

-- Sets up button hover and click behavior
local function setupButton(button, callback)
	local padding = button:FindFirstChild("UIPadding")
	if not padding then
		warn("UIPadding not found in button:", button.Name)
		return
	end

	local hoverTween = nil
	local unhoverTween = nil
	local defaultPadding = UDim.new(UI_CONSTANTS.Button.DefaultPaddingLeft, 0)
	local hoverPadding = UDim.new(UI_CONSTANTS.Button.HoverPaddingLeft, 0)

	-- Hover enter - move text to the right
	local mouseEnterConnection = button.MouseEnter:Connect(function()
		if unhoverTween then
			unhoverTween:Cancel()
		end

		hoverTween = TweenService:Create(padding, TweenInfo.new(
			HOVER_TWEEN_TIME,
			HOVER_EASING,
			Enum.EasingDirection.Out
		), {
			PaddingLeft = hoverPadding
		})
		hoverTween:Play()
	end)

	-- Hover leave - move text back
	local mouseLeaveConnection = button.MouseLeave:Connect(function()
		if hoverTween then
			hoverTween:Cancel()
		end

		unhoverTween = TweenService:Create(padding, TweenInfo.new(
			HOVER_TWEEN_TIME,
			HOVER_EASING,
			Enum.EasingDirection.Out
		), {
			PaddingLeft = defaultPadding
		})
		unhoverTween:Play()
	end)

	-- Click
	local clickConnection = button.MouseButton1Click:Connect(function()
		print("[GeneralBillboardController] Button clicked:", button.Name)

		-- Execute callback
		if callback then
			callback(player, currentData)
		end

		-- Hide billboard after click
		GeneralBillboardController:Hide()
	end)

	-- Store connections for cleanup
	table.insert(activeButtons, {
		MouseEnter = mouseEnterConnection,
		MouseLeave = mouseLeaveConnection,
		Click = clickConnection,
		HoverTween = hoverTween,
		UnhoverTween = unhoverTween,
		Padding = padding,
		DefaultPadding = defaultPadding,
	})
end

-- Cleans up all button connections and tweens
local function cleanupButtons()
	for _, buttonData in ipairs(activeButtons) do
		if buttonData.MouseEnter then
			buttonData.MouseEnter:Disconnect()
		end
		if buttonData.MouseLeave then
			buttonData.MouseLeave:Disconnect()
		end
		if buttonData.Click then
			buttonData.Click:Disconnect()
		end
		if buttonData.HoverTween then
			buttonData.HoverTween:Cancel()
		end
		if buttonData.UnhoverTween then
			buttonData.UnhoverTween:Cancel()
		end
		-- Reset padding to default
		if buttonData.Padding and buttonData.DefaultPadding then
			buttonData.Padding.PaddingLeft = buttonData.DefaultPadding
		end
	end

	activeButtons = {}
end

-- Configures billboard with a specific context
local function configureBillboard(contextName, data)
	local context = BillboardContexts[contextName]
	if not context then
		warn("Billboard context not found:", contextName)
		return false
	end

	-- Store current context and data
	currentContext = contextName
	currentData = data

	-- Cleanup previous buttons
	cleanupButtons()

	-- Hide all buttons initially
	for _, button in pairs(buttonFrames) do
		button.Visible = false
	end

	-- Setup option buttons (1, 2, 3)
	for i, option in ipairs(context.Options) do
		if i > 3 then
			warn("Context has more than 3 options, ignoring extras")
			break
		end

		local frameKey = tostring(i)
		local button = buttonFrames[frameKey]
		if button then
			button.Text = "#" .. i .. "  " .. option.Text
			button.Visible = true
			setupButton(button, option.Callback)
		end
	end

	-- Setup Close button (always last)
	local closeButton = buttonFrames.Close
	if closeButton then
		closeButton.Text = "X   Close"
		closeButton.Visible = true
		setupButton(closeButton, function()
			GeneralBillboardController:Hide()
		end)
	end

	return true
end

-- Initialize billboard for a character
local function initializeBillboard(character)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoidRootPart then
		warn("HumanoidRootPart not found")
		return
	end

	-- Cleanup old billboard if exists
	if billboardGui then
		cleanupButtons()
		billboardGui:Destroy()
		billboardGui = nil
		mainFrame = nil
		buttonFrames = {}
	end

	-- Create new billboard (parented to PlayerGui with Adornee)
	billboardGui, mainFrame, buttonFrames = createBillboardGui(humanoidRootPart)
	print("[GeneralBillboardController] Billboard created for character")
end

--|| Public Functions ||--

-- Show billboard with context
-- @param contextName: string - The context key from BillboardContexts
-- @param data: table? - Optional data to pass to callbacks
-- @param adornee: BasePart? - Optional part to attach billboard to (defaults to player's HumanoidRootPart)
function GeneralBillboardController:Show(contextName, data, adornee)
	if not billboardGui then
		-- Try to initialize if character exists
		local character = player.Character
		if character then
			initializeBillboard(character)
		else
			warn("Billboard GUI not initialized and no character")
			return
		end
	end

	-- Set adornee - use provided part or fallback to player's HumanoidRootPart
	if adornee and adornee:IsA("BasePart") then
		billboardGui.Adornee = adornee
	elseif not billboardGui.Adornee or not billboardGui.Adornee.Parent then
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				billboardGui.Adornee = hrp
			end
		end
	end

	-- Configure billboard with context
	if configureBillboard(contextName, data) then
		billboardGui.Enabled = true
		print("[GeneralBillboardController] Showing billboard with context:", contextName, "on", billboardGui.Adornee and billboardGui.Adornee:GetFullName() or "nil")
	end
end

function GeneralBillboardController:Hide()
	if billboardGui then
		billboardGui.Enabled = false
		cleanupButtons()
		currentContext = nil
		currentData = nil
	end
end

function GeneralBillboardController:IsVisible()
	return billboardGui and billboardGui.Enabled
end

--|| Initialization ||--

function GeneralBillboardController:KnitStart()
	-- Initialize for current character
	local character = player.Character
	if character then
		initializeBillboard(character)
	end

	-- Handle character respawn
	player.CharacterAdded:Connect(function(newCharacter)
		task.wait(0.1)
		initializeBillboard(newCharacter)
	end)

	print("[GeneralBillboardController] Started - Billboard parented to PlayerGui")
end

return GeneralBillboardController
