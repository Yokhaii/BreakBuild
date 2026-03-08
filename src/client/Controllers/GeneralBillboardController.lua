--[[
	GeneralBillboardController.lua
	Handles the GeneralPlayer Billboard UI system

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
local BillboardConfig = require(ReplicatedStorage.Shared.Config.BillboardConfig)
local BillboardContexts = require(ReplicatedStorage.Shared.Data.BillboardContexts)

-- Player
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

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

--|| Private Functions ||--

-- Sets up button hover and click animations
local function setupButtonAnimations(buttonFrame, callback)
	local contentButton = buttonFrame:FindFirstChild("Content")
	if not contentButton then
		warn("Content button not found in frame:", buttonFrame.Name)
		return
	end

	local isHovering = false
	local hoverTween = nil
	local unhoverTween = nil

	-- Store original values
	local originalPositionX = contentButton.Position.X.Scale
	local originalTransparency = contentButton.BackgroundTransparency

	-- Hover enter
	local mouseEnterConnection = contentButton.MouseEnter:Connect(function()
		isHovering = true

		-- Cancel any existing tweens
		if unhoverTween then
			unhoverTween:Cancel()
		end

		-- Create hover tween
		local hoverInfo = TweenInfo.new(
			BillboardConfig.Hover.TweenTime,
			BillboardConfig.Hover.EasingStyle,
			BillboardConfig.Hover.EasingDirection
		)

		hoverTween = TweenService:Create(contentButton, hoverInfo, {
			Position = UDim2.new(
				BillboardConfig.Hover.PositionXEnd,
				contentButton.Position.X.Offset,
				contentButton.Position.Y.Scale,
				contentButton.Position.Y.Offset
			),
			BackgroundTransparency = BillboardConfig.Hover.TransparencyEnd,
		})

		hoverTween:Play()
	end)

	-- Hover leave
	local mouseLeaveConnection = contentButton.MouseLeave:Connect(function()
		isHovering = false

		-- Cancel any existing tweens
		if hoverTween then
			hoverTween:Cancel()
		end

		-- Create unhover tween (back to original)
		local unhoverInfo = TweenInfo.new(
			BillboardConfig.Hover.TweenTime,
			BillboardConfig.Hover.EasingStyle,
			BillboardConfig.Hover.EasingDirection
		)

		unhoverTween = TweenService:Create(contentButton, unhoverInfo, {
			Position = UDim2.new(
				originalPositionX,
				contentButton.Position.X.Offset,
				contentButton.Position.Y.Scale,
				contentButton.Position.Y.Offset
			),
			BackgroundTransparency = originalTransparency,
		})

		unhoverTween:Play()
	end)

	-- Click animation
	local clickConnection = contentButton.MouseButton1Click:Connect(function()
		-- Change to greyish white and flash transparency
		local originalColor = contentButton.BackgroundColor3
		contentButton.BackgroundColor3 = BillboardConfig.Click.BackgroundColor

		-- Create flash animation
		local flashInfo = TweenInfo.new(
			BillboardConfig.Click.FlashTime,
			BillboardConfig.Click.EasingStyle,
			BillboardConfig.Click.EasingDirection
		)

		local flashTween = TweenService:Create(contentButton, flashInfo, {
			BackgroundTransparency = BillboardConfig.Click.TransparencyFlash,
		})

		flashTween:Play()

		-- Wait for flash and then fade back
		flashTween.Completed:Connect(function()
			local fadeBackInfo = TweenInfo.new(
				BillboardConfig.Click.FlashTime,
				BillboardConfig.Click.EasingStyle,
				BillboardConfig.Click.EasingDirection
			)

			local fadeBackTween = TweenService:Create(contentButton, fadeBackInfo, {
				BackgroundTransparency = 1,
			})

			fadeBackTween:Play()

			-- Restore original color after animation
			fadeBackTween.Completed:Connect(function()
				contentButton.BackgroundColor3 = originalColor
			end)
		end)

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

	-- Hide all button frames initially
	for _, frame in pairs(buttonFrames) do
		frame.Visible = false
	end

	-- Setup option buttons (1, 2, 3)
	for i, option in ipairs(context.Options) do
		if i > 3 then
			warn("Context has more than 3 options, ignoring extras")
			break
		end

		local frameKey = tostring(i)
		local buttonFrame = buttonFrames[frameKey]
		if buttonFrame then
			local contentButton = buttonFrame:FindFirstChild("Content")
			if contentButton then
				contentButton.Text = option.Text
				buttonFrame.Visible = true
				setupButtonAnimations(buttonFrame, option.Callback)
			end
		end
	end

	-- Setup Close button
	local closeFrame = buttonFrames.Close
	if closeFrame then
		local contentButton = closeFrame:FindFirstChild("Content")
		if contentButton then
			contentButton.Text = "Close"
			closeFrame.Visible = true
			setupButtonAnimations(closeFrame, function()
				GeneralBillboardController:Hide()
			end)
		end
	end

	return true
end

--|| Public Functions ||--

function GeneralBillboardController:Show(contextName, data)
	if not billboardGui then
		warn("Billboard GUI not initialized")
		return
	end

	-- Configure billboard with context
	if configureBillboard(contextName, data) then
		billboardGui.Enabled = true
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

--|| Initialization ||--

function GeneralBillboardController:KnitStart()
	-- Wait for character if needed
	if not character.Parent then
		character = player.Character or player.CharacterAdded:Wait()
		humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	end

	-- Clone billboard from ReplicatedStorage
	local billboardTemplate = ReplicatedStorage:WaitForChild("GeneralPlayer")
	billboardGui = billboardTemplate:Clone()
	billboardGui.Parent = humanoidRootPart

	-- Get main frame and button frames
	mainFrame = billboardGui:FindFirstChildOfClass("Frame")
	if not mainFrame then
		warn("Main frame not found in GeneralPlayer billboard")
		return
	end

	-- Store references to button frames
	buttonFrames["1"] = mainFrame:FindFirstChild("1")
	buttonFrames["2"] = mainFrame:FindFirstChild("2")
	buttonFrames["3"] = mainFrame:FindFirstChild("3")
	buttonFrames.Close = mainFrame:FindFirstChild("Close")

	-- Verify all frames exist
	for key, frame in pairs(buttonFrames) do
		if not frame then
			warn("Button frame not found:", key)
		end
	end

	-- Hide billboard by default
	billboardGui.Enabled = false

	-- Handle character respawn
	player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
		humanoidRootPart = character:WaitForChild("HumanoidRootPart")

		-- Cleanup old billboard
		if billboardGui then
			cleanupButtons()
			billboardGui:Destroy()
		end

		-- Clone new billboard
		billboardGui = billboardTemplate:Clone()
		billboardGui.Parent = humanoidRootPart
		billboardGui.Enabled = false

		-- Re-get references
		mainFrame = billboardGui:FindFirstChildOfClass("Frame")
		if mainFrame then
			buttonFrames["1"] = mainFrame:FindFirstChild("1")
			buttonFrames["2"] = mainFrame:FindFirstChild("2")
			buttonFrames["3"] = mainFrame:FindFirstChild("3")
			buttonFrames.Close = mainFrame:FindFirstChild("Close")
		end
	end)

	print("GeneralBillboardController started")
end

return GeneralBillboardController
