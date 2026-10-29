--[[
	ObjectiveController.lua
	Client-side actions for the objective system:
	  - claim rewards / pin and unpin side objectives (ObjectiveService)
	  - open and close the Objectives frame
	  - "Objective complete" / "Tutorial complete" notifications (rewards are claimed later, from the frame)
	Objective state itself is synced into ObjectiveReducer by Modules/Synchronization/Objective.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Knit packages
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Data
local ObjectiveData = require(ReplicatedStorage.Shared.Data.ObjectiveData)

-- Rodux
local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)
local UIActions = require(Client.Rodux.Actions.UIActions)
local ObjectiveStatus = require(Client.Modules.ObjectiveStatus)

-- ObjectiveController
local ObjectiveController = Knit.CreateController({
	Name = "ObjectiveController",
})

-- Constants
local FRAME_NAME = "Objectives"
local NOTIFICATION_COLOR = Color3.fromRGB(255, 220, 60)
local ERROR_COLOR = Color3.fromRGB(255, 90, 90)

-- Private variables
local ObjectiveService
local TextNotificationController
local InventoryController
local pendingRequests = {} -- { [objectiveId]: true } while a claim/pin request is in flight

--|| Private Functions ||--

local function showNotification(text: string, color: Color3)
	if TextNotificationController then
		TextNotificationController:Show(text, color)
	end
end

local function isTutorialIndex(mainIndex: number): boolean
	local objective = ObjectiveData.Main[mainIndex]
	return objective ~= nil and objective.tutorial == true
end

-- Notify when an objective completes, and when the last tutorial objective completes
local function onStoreChanged(newState, oldState)
	local newObjectives = newState.ObjectiveReducer
	local oldObjectives = oldState.ObjectiveReducer
	if oldObjectives.MainIndex == 0 or newObjectives == oldObjectives then return end

	for objectiveId in pairs(newObjectives.Completed) do
		if not oldObjectives.Completed[objectiveId] then
			local objective = ObjectiveData.GetObjective(objectiveId)
			if objective then
				showNotification(string.format(ObjectiveData.Texts.ObjectiveCompleted, ObjectiveStatus.GetTaskText(objective)), NOTIFICATION_COLOR)
			end
		end
	end

	if isTutorialIndex(oldObjectives.MainIndex) and not isTutorialIndex(newObjectives.MainIndex)
		and newObjectives.MainIndex > oldObjectives.MainIndex then
		showNotification(ObjectiveData.Texts.TutorialCompleted, NOTIFICATION_COLOR)
	end
end

-- Send one request per objective at a time, showing the server's reason on failure
local function sendRequest(objectiveId: string, request)
	if pendingRequests[objectiveId] then return end
	pendingRequests[objectiveId] = true

	request()
		:andThen(function(result)
			if result and not result.success and result.reason then
				showNotification(result.reason, ERROR_COLOR)
			end
		end)
		:catch(function(err)
			warn("[ObjectiveController] Request failed:", err)
		end)
		:finally(function()
			pendingRequests[objectiveId] = nil
		end)
end

--|| Public Functions ||--

function ObjectiveController:ClaimObjective(objectiveId: string)
	sendRequest(objectiveId, function()
		return ObjectiveService:ClaimObjective(objectiveId)
	end)
end

function ObjectiveController:TogglePin(objectiveId: string)
	local objectivesState = Store:getState().ObjectiveReducer
	local pinned = not ObjectiveStatus.IsPinned(objectivesState, objectiveId)

	if pinned and #objectivesState.Pinned >= ObjectiveData.MaxPinned then
		showNotification(string.format("You can only pin %d objectives", ObjectiveData.MaxPinned), ERROR_COLOR)
		return
	end

	sendRequest(objectiveId, function()
		return ObjectiveService:SetPinned(objectiveId, pinned)
	end)
end

function ObjectiveController:OpenObjectives()
	if Store:getState().InventoryReducer.BackpackOpen then
		InventoryController:CloseBackpack()
	end
	Store:dispatch(UIActions.setCurrentFrame(FRAME_NAME))
end

function ObjectiveController:CloseObjectives()
	if Store:getState().UIReducer.CurrentFrame == FRAME_NAME then
		Store:dispatch(UIActions.setCurrentFrame("HUD"))
	end
end

function ObjectiveController:IsObjectivesOpen(): boolean
	return Store:getState().UIReducer.CurrentFrame == FRAME_NAME
end

--|| Initialization ||--

function ObjectiveController:KnitStart()
	ObjectiveService = Knit.GetService("ObjectiveService")
	TextNotificationController = Knit.GetController("TextNotificationController")
	InventoryController = Knit.GetController("InventoryController")

	Store.changed:connect(onStoreChanged)
end

return ObjectiveController
