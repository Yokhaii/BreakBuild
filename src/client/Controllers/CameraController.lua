--[=[
	CameraController
	Switches between first person and the normal (third person) view.
	Tracks the actual camera distance so the HUD button stays right
	when the player zooms in or out with the scroll wheel / pinch.
	Frees the mouse while a menu is open, so first person players can click the UI.
	On PC the mouse is locked in first person, so the view also toggles with V.
]=]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Rodux
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local UIActions = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions.UIActions)

local CameraController = Knit.CreateController({ Name = "CameraController" })

local player = Players.LocalPlayer

-- Below this camera-to-focus distance the default camera is in first person
local FIRST_PERSON_DISTANCE = 1
-- Zoom distance used when leaving first person
local THIRD_PERSON_ZOOM = 12
local TOGGLE_VIEW_KEY = Enum.KeyCode.V
-- CurrentFrame values with no menu open
local GAMEPLAY_FRAMES = {
	HUD = true,
	None = true,
}

local function isCameraFirstPerson(): boolean
	local camera = workspace.CurrentCamera
	return (camera.CFrame.Position - camera.Focus.Position).Magnitude < FIRST_PERSON_DISTANCE
end

-- Clamps the zoom range for one frame so the default camera snaps to that distance,
-- then gives the full range back so the player can still zoom freely
local isSnappingZoom = false

local function snapZoom(distance: number)
	-- A second snap in the same frame would save the clamped range as the real one
	if isSnappingZoom then
		return
	end
	isSnappingZoom = true

	local minZoom, maxZoom = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
	player.CameraMinZoomDistance = distance
	player.CameraMaxZoomDistance = distance
	task.wait()
	player.CameraMinZoomDistance = minZoom
	player.CameraMaxZoomDistance = maxZoom
	isSnappingZoom = false
end

local function isMenuOpen(state): boolean
	return state.InventoryReducer.BackpackOpen
		or state.DropPromptReducer.Prompt ~= nil
		or not GAMEPLAY_FRAMES[state.UIReducer.CurrentFrame]
end

--|| Public Functions ||--

function CameraController:IsFirstPerson(): boolean
	return Store:getState().UIReducer.IsFirstPerson
end

function CameraController:SetFirstPerson(enabled: boolean)
	-- Zooming (instead of LockFirstPerson) keeps the native scroll / pinch out of first person
	snapZoom(if enabled then player.CameraMinZoomDistance else THIRD_PERSON_ZOOM)
end

function CameraController:ToggleFirstPerson()
	self:SetFirstPerson(not isCameraFirstPerson())
end

--|| Initialization ||--

function CameraController:KnitStart()
	Knit.GetController("KeybindController"):Register("camera_toggle_view", TOGGLE_VIEW_KEY, function()
		CameraController:ToggleFirstPerson()
	end)

	-- Runs right after the default camera, which locks the mouse to the center in first person
	RunService:BindToRenderStep("CameraController", Enum.RenderPriority.Camera.Value + 1, function()
		local state = Store:getState()

		local isFirstPerson = isCameraFirstPerson()
		if isFirstPerson ~= state.UIReducer.IsFirstPerson then
			Store:dispatch(UIActions.setFirstPerson(isFirstPerson))
		end

		if isMenuOpen(state) and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)
end

return CameraController
