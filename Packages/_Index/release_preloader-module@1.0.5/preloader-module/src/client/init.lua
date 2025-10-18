local Preloader = {}

-- Game Services
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Signal = require(ReplicatedStorage.Packages.Signal)
local LoadingTracker = require(script.Modules.Preloader.LoadingTracker)

-- Cache
local preloadUI
local touchGUIFrame
local fillFrame
local loadingText
local imageLabelBackground
local characterControls

Preloader.EndPreloaderSignal = Signal.new()
Preloader.ControllersLoadedSignal = Signal.new()
local loadingTracker

-- Default paths
local defaultPaths = {
	controllersPath = nil,
	imagesPath = nil,
	componentsPath = nil,
}

-- Default configuration
local defaultConfig = {
	showLoadingScreen = true,
	loadControllers = false,
	loadImages = false,
	loadUI = false,
	initialDelay = 0.5,
	finalDelay = 1.5,
	skipEnabled = true,
	keepLoadingScreen = false,
	batchSize = 1, 
	paths = defaultPaths,
}

-- Current configuration
local config = table.clone(defaultConfig)

local isSkipped = false
local inScriptLoading = false

-- Configure the preloader with custom options
function Preloader:Configure(options)
	-- Deep merge paths if provided
	if options.paths then
		options.paths = {
			controllersPath = options.paths.controllersPath or defaultPaths.controllersPath,
			imagesPath = options.paths.imagesPath or defaultPaths.imagesPath,
			componentsPath = options.paths.componentsPath or defaultPaths.componentsPath,
		}
	else
		options.paths = defaultPaths
	end

	-- Merge provided options with defaults
	for key, value in pairs(options) do
		config[key] = value
	end

	-- Initialize loading tracker with relevant options
	loadingTracker = LoadingTracker.new({
		trackControllers = config.loadControllers,
		trackImages = config.loadImages,
		trackUI = config.loadUI,
	})
end

function Preloader:UpdateProgressBar(percent, text)
	if not config.showLoadingScreen then
		return
	end
	if fillFrame and loadingText then
		fillFrame.Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)
		loadingText.Text = text
	end
end

function Preloader:SetInScripLoading(bool)
	inScriptLoading = bool
end

function Preloader:_SkipButton()
	if not config.skipEnabled then
		return
	end
	isSkipped = true
	if inScriptLoading then
		self:EndPreload()
	end
end

function Preloader:isSkipped()
	return isSkipped
end

-- Disable player movement
function Preloader:_DisablePlayerMovement()
	local player = Players.LocalPlayer
	if not player then return end
	
	-- Store original character control settings
	characterControls = {
		walkSpeed = 0,
		jumpPower = 0,
		autoJumpEnabled = false,
		originalWalkSpeed = StarterPlayer.CharacterWalkSpeed,
		originalJumpPower = StarterPlayer.CharacterJumpPower,
		originalAutoJump = StarterPlayer.AutoJumpEnabled,
	}
	
	-- Disable jumping with ContextActionService
	ContextActionService:BindAction("NoJump", function() 
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space)
	
	-- Disable WASD movement keys
	ContextActionService:BindAction("NoMove", function() 
		return Enum.ContextActionResult.Sink
	end, false, 
		Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
		Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right)
	
	-- Disable character movement directly
	local character = player.Character or player.CharacterAdded:Wait()
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			characterControls.originalWalkSpeed = humanoid.WalkSpeed
			characterControls.originalJumpPower = humanoid.JumpPower
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
	end
end

-- Enable player movement
function Preloader:_EnablePlayerMovement()
	local player = Players.LocalPlayer
	if not player or not characterControls then return end
	
	-- Unbind movement restrictions
	ContextActionService:UnbindAction("NoJump")
	ContextActionService:UnbindAction("NoMove")
	
	-- Restore character movement
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = characterControls.originalWalkSpeed
			humanoid.JumpPower = characterControls.originalJumpPower
		end
	end
	
	-- Clean up
	characterControls = nil
end

function Preloader:_InitPreloader()
	if not config.showLoadingScreen then
		return
	end

	-- Disable default loading screen
	ReplicatedFirst:RemoveDefaultLoadingScreen()

	-- Disabling core UI
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

	-- Handle touch GUI
	local player = Players.LocalPlayer
	local playerGUI = player:FindFirstChild("PlayerGui")
	if UserInputService.TouchEnabled then
		local touchGUI = playerGUI:WaitForChild("TouchGui", 5)
		if touchGUI then
			touchGUIFrame = touchGUI:FindFirstChild("TouchControlFrame")
			if touchGUIFrame then
				touchGUIFrame.Visible = false
			end
		end
	end

	-- Freeze input
	ContextActionService:BindAction("freeze", function()
		return Enum.ContextActionResult.Sink
	end, false, unpack(Enum.PlayerActions:GetEnumItems()))
	
	-- Disable player movement
	self:_DisablePlayerMovement()

	-- Cache UI elements
	preloadUI = playerGUI:FindFirstChild("LoadingUI")
	if preloadUI then
		pcall(function()
			fillFrame = preloadUI.ImageLabelBackground.BottomLeftImage.Background.Fill
			loadingText = preloadUI.ImageLabelBackground.BottomLeftImage.TextLabel
			imageLabelBackground = preloadUI.ImageLabelBackground
		end)
	end
end

function Preloader:_LoadControllers()
	if not config.loadControllers then
		return
	end

	-- Get all controller modules recursively
	local function getControllerModules(folder)
		local modules = {}
		for _, item in ipairs(folder:GetDescendants()) do
			if item:IsA("ModuleScript") then
				table.insert(modules, item)
			end
		end
		return modules
	end

	local controllerFolder = config.paths.controllersPath
	local controllerModules = getControllerModules(controllerFolder)

	-- Register the total number of controllers
	loadingTracker:registerAssets("controllers", #controllerModules)

	-- Load each controller
	for _, controllerModule in ipairs(controllerModules) do
		task.spawn(function()
			require(controllerModule)
			loadingTracker:assetLoaded("controllers")
			self:UpdateProgressBar(loadingTracker:getProgress(), loadingTracker:getProgressText())
		end)
	end

	-- Fire the controllers loaded signal in the next frame
	task.defer(function()
		print("Firing ControllersLoadedSignal")
		Preloader.ControllersLoadedSignal:Fire(true)
	end)
end

function Preloader:_LoadUI()
	if not config.loadImages then
		return
	end

	local UIDatas = require(config.paths.imagesPath)
	local uiToPreload = {}

	-- Count total images
	local imageCount = 0
	for _ in pairs(UIDatas) do
		imageCount += 1
	end
	loadingTracker:registerAssets("images", imageCount)

	-- Helper function to process a batch of images
	local function processImageBatch(imageBatch)
		local threads = {}

		for _, imageData in ipairs(imageBatch) do
			local thread = task.spawn(function()
				local newImage = Instance.new("ImageLabel")
				newImage.Image = imageData.id
				table.insert(uiToPreload, newImage)
				ContentProvider:PreloadAsync({ newImage }, function(contentId, status)
					if status == Enum.AssetFetchStatus.Success then
						loadingTracker:assetLoaded("images")
						self:UpdateProgressBar(loadingTracker:getProgress(), loadingTracker:getProgressText())

					end
				end)
			end)
			table.insert(threads, thread)
		end

		-- Wait for all threads in the batch to complete
	end

	-- Process images in batches
	local batchSize = config.batchSize
	local currentBatch = {}
	local count = 0

	for imageName, id in pairs(UIDatas) do
		count = count + 1
		table.insert(currentBatch, { name = imageName, id = id })

		-- When we reach batch size or it's the last item, process the batch
		if count % batchSize == 0 or count == imageCount then
			processImageBatch(currentBatch)
			task.wait()
			currentBatch = {} -- Clear the batch for next round
		end
	end

	for index, value in uiToPreload do
		value:Destroy()
	end
end

function Preloader:_LoadRoactComponents()
	if not config.loadUI then
		return
	end

	local function countComponents(folder)
		local count = 0
		for _, item in ipairs(folder:GetDescendants()) do
			if item:IsA("ModuleScript") then
				count += 1
			end
		end
		return count
	end

	local componentsFolder = config.paths.componentsPath
	local componentCount = countComponents(componentsFolder)
	loadingTracker:registerAssets("uiComponents", componentCount)

	local function loadComponents(folder)
		for _, item in ipairs(folder:GetDescendants()) do
			if item:IsA("ModuleScript") then
				require(item)
				loadingTracker:assetLoaded("uiComponents")
				self:UpdateProgressBar(loadingTracker:getProgress(), loadingTracker:getProgressText())
				task.wait(0.05)
			end
		end
	end

	loadComponents(componentsFolder)
end

function Preloader:DestroyLoadingScreen()
	if preloadUI then
		preloadUI:Destroy()
		preloadUI = nil
	end
end

function Preloader:EndPreload()
	-- Re-enable core UI if it was disabled
	if config.showLoadingScreen then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

		if touchGUIFrame then
			touchGUIFrame.Visible = true
		end

		-- Only destroy the UI if we're not keeping the loading screen
		if preloadUI and not config.keepLoadingScreen then
			preloadUI:Destroy()
		end

		ContextActionService:UnbindAction("freeze")
		
		-- Re-enable player movement
		self:_EnablePlayerMovement()
	end

	-- Fire the completion signal in the next frame
	task.defer(function()
		print("Firing EndPreloaderSignal")
		Preloader.EndPreloaderSignal:Fire(true)
	end)
end

function Preloader:PreloadContent()
	if not loadingTracker then
		self:Configure({}) -- Use defaults if not configured
	end

	self:_InitPreloader()
	task.wait(config.initialDelay)

	-- Load everything according to configuration
	self:_LoadControllers()
	self:_LoadUI()
	--self:_LoadRoactComponents()

	if not self:isSkipped() then
		local finalMessage = config.keepLoadingScreen and "You'll be teleported to a new place..."
			or "Loading Complete! Have Fun!"

		self:UpdateProgressBar(1, finalMessage)
		task.wait(config.finalDelay)
		self:EndPreload()
	end
end

return Preloader