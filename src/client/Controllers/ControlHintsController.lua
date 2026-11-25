--[=[
	ControlHintsController
	Works out what a left click would do right now, for the ControlHints panel (bottom right of the HUD).
	It only reads the hover state the other controllers already keep, so the hint matches the game:
	  - Breaking tool aiming at a breakable in range -> "Break" (even if its tier is too low)
	  - Hammer aiming at something it can remove    -> "Remove"
	  - Block with its placement preview shown       -> "Place"
	  - Blueprint / structure with its preview shown -> "Place"
	  - Anything else: a hovered structure can name an action with GetHoverAction(screenPosition)
	    on its client class (the CropField returns "Plant" for seeds on an empty plot)
	Desktop only (the hover state is not tracked on touch).
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

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local ControlHintsController = Knit.CreateController({ Name = "ControlHintsController" })

local mouse = Players.LocalPlayer:GetMouse()

local BreakingController
local BuildingController
local BlueprintPlacementController

local function getEquippedItemConfig()
	local inventory = Store:getState().InventoryReducer
	local slot = inventory.EquippedSlot
	if slot == nil then
		return nil
	end
	if slot == 0 then
		return ItemData.GetItem("Hammer")
	end
	local item = inventory.Hotbar[slot]
	return item and ItemData.GetItem(item.itemName)
end

local function getHoveredStructureAction(): string?
	local structure = BuildingController:GetHoveredStructure()
	local blueprintId = structure and structure:FindFirstChild("BlueprintId")
	local blueprint = blueprintId and BlueprintPlacementController:GetActiveBlueprint(blueprintId.Value)
	if blueprint and blueprint.GetHoverAction then
		return blueprint:GetHoverAction(Vector2.new(mouse.X, mouse.Y))
	end
	return nil
end

local function computePrimaryAction(): string?
	local itemConfig = getEquippedItemConfig()
	if not itemConfig then
		return nil
	end

	if itemConfig.isRemovalTool then
		return if BuildingController:GetRemovalTarget() then "Remove" else nil
	end
	if itemConfig.isBreakingTool then
		return if BreakingController:GetHoveredBreakableId() then "Break" else nil
	end
	if itemConfig.type == "Block" then
		return if BuildingController:IsPreviewVisible() then "Place" else nil
	end
	if itemConfig.isBlueprintTool or itemConfig.isStructure then
		return if BlueprintPlacementController:IsPreviewVisible() then "Place" else nil
	end
	return getHoveredStructureAction()
end

--|| Initialization ||--

function ControlHintsController:KnitStart()
	if UserInputService.TouchEnabled then
		return
	end

	BreakingController = Knit.GetController("BreakingController")
	BuildingController = Knit.GetController("BuildingController")
	BlueprintPlacementController = Knit.GetController("BlueprintPlacementController")

	-- Heartbeat runs after the RenderStepped / Heartbeat hover updates of the other controllers
	RunService.Heartbeat:Connect(function()
		local primaryAction = computePrimaryAction()
		if primaryAction ~= Store:getState().UIReducer.PrimaryAction then
			Store:dispatch(UIActions.setPrimaryAction(primaryAction))
		end
	end)
end

return ControlHintsController
