--[[
	TutorialController.lua
	Client-side guidance for the onboarding tutorial.
	The current task comes from TutorialService (TutorialReducer). From it and the
	UI / inventory / crafting state, this controller works out the current sub-step and drives:
	  - a world Beam (+ outline Highlight) from the player to the 3D target (log, table, blueprint, stone...)
	  - the UI spotlight target and hint text (TutorialReducer.SpotlightTarget / Hint)
	Sub-steps are recomputed continuously, so the guidance recovers if the player
	closes a menu or does things out of order.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Data & Config
local TutorialData = require(ReplicatedStorage.Shared.Data.TutorialData)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)

-- Rodux
local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)
local TutorialActions = require(Client.Rodux.Actions.TutorialActions)
local TutorialTargets = require(Client.Modules.TutorialTargets)

-- TutorialController
local TutorialController = Knit.CreateController({
	Name = "TutorialController",
})

-- Player
local player = Players.LocalPlayer

-- Constants
local HOTBAR_SIZE = 7
local INVENTORY_BUTTON = "InventoryButton"
local Hints = TutorialData.Hints

-- Frames that replace the inventory crafting panel inside the backpack
local STATION_FRAMES = {
	Workbench = true,
	Furnace = true,
	Chest = true,
	Shop = true,
}

-- Private variables
local BuildingController
local TextNotificationController
local zoneName: string? = nil
local lastGuideUpdate = 0

-- World guidance objects (local only, parented under the camera)
local guideFolder: Folder? = nil
local beam: Beam? = nil
local beamTargetPart: BasePart? = nil
local targetHighlight: Highlight? = nil
local playerAttachment: Attachment? = nil

-- Closest breakable cache: { [materialType]: { part: BasePart?, refreshedAt: number } }
local closestBreakables = {}

--|| Inventory Helpers ||--

local function countItem(inventoryState, itemName: string): number
	local total = 0
	for _, item in pairs(inventoryState.Backpack or {}) do
		if item and item.itemName == itemName then
			total = total + (item.quantity or 1)
		end
	end
	for _, item in pairs(inventoryState.Hotbar or {}) do
		if item and item.itemName == itemName then
			total = total + (item.quantity or 1)
		end
	end
	return total
end

local function countPoolItem(state, itemName: string): number
	local total = 0
	for _, entry in ipairs(state.CraftingPoolReducer.Pool or {}) do
		if entry.itemName == itemName then
			total = total + entry.quantity
		end
	end
	return total
end

-- First hotbar slot whose item matches `predicate(itemConfig, item)`
local function findHotbarSlot(inventoryState, predicate): number?
	local hotbar = inventoryState.Hotbar or {}
	for slot = 1, HOTBAR_SIZE do
		local item = hotbar[slot]
		if item and predicate(ItemData.GetItem(item.itemName), item) then
			return slot
		end
	end
	return nil
end

local function getEquippedItem(inventoryState)
	local slot = inventoryState.EquippedSlot
	if not slot or slot == 0 then return nil end
	return inventoryState.Hotbar and inventoryState.Hotbar[slot] or nil
end

local function getDisplayName(itemName: string): string
	local itemConfig = ItemData.GetItem(itemName)
	return itemConfig and itemConfig.displayName or itemName
end

--|| World Target Finders ||--

local function getZone(): Instance?
	return zoneName and Workspace:FindFirstChild(zoneName) or nil
end

local function findBlueprintsTable(): Instance?
	local zone = getZone()
	local platform = zone and zone:FindFirstChild("Platform")
	return platform and platform:FindFirstChild("Blueprints") or nil
end

local function findBuildingArea(): BasePart?
	local zone = getZone()
	return zone and zone:FindFirstChild("BuildingArea") or nil
end

-- Find the player's placed blueprint (ghost) or completed structure of the given type
local function findPlacedBlueprint(blueprintType: string, completed: boolean): Instance?
	local zone = getZone()
	if not zone then return nil end

	for _, child in ipairs(zone:GetChildren()) do
		local typeValue = child:FindFirstChild("BlueprintType")
		local ownerValue = child:FindFirstChild("OwnerId")
		local isCompleted = child:FindFirstChild("IsCompletedStructure") ~= nil
		if typeValue and typeValue.Value == blueprintType
			and ownerValue and ownerValue.Value == player.UserId
			and isCompleted == completed then
			return child
		end
	end
	return nil
end

local function isBreakableAlive(part: BasePart?, materialType: string): boolean
	if not part or not part:IsDescendantOf(Workspace) then return false end
	local materialValue = part:FindFirstChild("MaterialType")
	return materialValue ~= nil and materialValue.Value == materialType
end

-- Grid position of a GlobalBreakingArea block from its id ("global_x_y_z"), nil for other breakables
local function parseGridPosition(breakableId: string): (number?, number?, number?)
	local x, y, z = string.match(breakableId, "^global_(%-?%d+)_(%-?%d+)_(%-?%d+)$")
	if not x then return nil, nil, nil end
	return tonumber(x), tonumber(y), tonumber(z)
end

-- Ranks a candidate: blocks above the ground layer first, then blocks with nothing on top
local function getCandidateRank(breakableId: string, occupiedIds): number
	local x, y, z = parseGridPosition(breakableId)
	if not x then return 2 end -- Not a grid block (e.g. tree logs): always reachable

	local isAboveGround = y >= TutorialConfig.MinGridHeight
	local isExposed = not occupiedIds["global_" .. x .. "_" .. (y + 1) .. "_" .. z]
	return (isAboveGround and 2 or 0) + (isExposed and 1 or 0)
end

-- Closest breakable part of a material (re-searched periodically or when the cached one is gone).
-- Grid blocks above the ground of the Breaking Area are preferred, then blocks with nothing on top,
-- so the target is never buried underground. Falls back to underground blocks if there is no other choice.
local function findClosestBreakable(materialType: string): BasePart?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local cached = closestBreakables[materialType]
	local now = os.clock()
	if cached and isBreakableAlive(cached.part, materialType)
		and now - cached.refreshedAt < TutorialConfig.TargetRefreshInterval then
		return cached.part
	end

	local containerName = TutorialConfig.BreakableContainers[materialType]
	local container = containerName and Workspace:FindFirstChild(containerName)
	local occupiedIds = {}
	local candidates = {}

	if container then
		for _, descendant in ipairs(container:GetDescendants()) do
			if descendant.Name == "BreakableId" and descendant:IsA("StringValue") then
				occupiedIds[descendant.Value] = true

				local part = descendant.Parent
				local materialValue = part and part:FindFirstChild("MaterialType")
				if part:IsA("BasePart") and materialValue and materialValue.Value == materialType then
					table.insert(candidates, { part = part, id = descendant.Value })
				end
			end
		end
	end

	local closestPart, closestDistance, closestRank = nil, math.huge, -1
	for _, candidate in ipairs(candidates) do
		local rank = getCandidateRank(candidate.id, occupiedIds)
		local distance = (candidate.part.Position - rootPart.Position).Magnitude
		if rank > closestRank or (rank == closestRank and distance < closestDistance) then
			closestPart, closestDistance, closestRank = candidate.part, distance, rank
		end
	end

	closestBreakables[materialType] = { part = closestPart, refreshedAt = now }
	return closestPart
end

local function getInstancePosition(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart.Position
		end
		return instance:GetBoundingBox().Position
	end
	return nil
end

-- A breakable part's BreakableId lives on the PrimaryPart of its model: outline the whole model
local function getHighlightAdornee(instance: Instance): Instance
	local parent = instance.Parent
	if instance:IsA("BasePart") and parent and parent:IsA("Model") and parent.PrimaryPart == instance then
		return parent
	end
	return instance
end

--|| World Beam ||--

local function ensureGuideObjects()
	if guideFolder and guideFolder.Parent then return end

	guideFolder = Instance.new("Folder")
	guideFolder.Name = "TutorialGuide"

	beamTargetPart = Instance.new("Part")
	beamTargetPart.Name = "BeamTarget"
	beamTargetPart.Size = Vector3.new(0.2, 0.2, 0.2)
	beamTargetPart.Transparency = 1
	beamTargetPart.Anchored = true
	beamTargetPart.CanCollide = false
	beamTargetPart.CanQuery = false
	beamTargetPart.CanTouch = false
	beamTargetPart.Parent = guideFolder

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = beamTargetPart

	beam = Instance.new("Beam")
	beam.Name = "TutorialBeam"
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(TutorialConfig.BeamColor)
	beam.Width0 = TutorialConfig.BeamWidth
	beam.Width1 = TutorialConfig.BeamWidth
	beam.Transparency = NumberSequence.new(TutorialConfig.BeamTransparency)
	beam.LightEmission = TutorialConfig.BeamLightEmission
	beam.Texture = TutorialConfig.BeamTexture
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureSpeed = TutorialConfig.BeamTextureSpeed
	beam.TextureLength = TutorialConfig.BeamTextureLength
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = guideFolder

	targetHighlight = Instance.new("Highlight")
	targetHighlight.Name = "TutorialHighlight"
	targetHighlight.FillTransparency = 1
	targetHighlight.OutlineColor = TutorialConfig.HighlightColor
	targetHighlight.OutlineTransparency = TutorialConfig.HighlightOutlineTransparency
	targetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	targetHighlight.Enabled = false
	targetHighlight.Parent = guideFolder

	guideFolder.Parent = Workspace.CurrentCamera
end

local function getPlayerAttachment(): Attachment?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	if not playerAttachment or playerAttachment.Parent ~= rootPart then
		playerAttachment = Instance.new("Attachment")
		playerAttachment.Name = "TutorialBeamAttachment"
		playerAttachment.Parent = rootPart
	end
	return playerAttachment
end

local function setWorldTarget(instance: Instance?, highlight: boolean)
	ensureGuideObjects()

	local position = instance and getInstancePosition(instance)
	local attachment = position and getPlayerAttachment()
	if not attachment then
		beam.Enabled = false
		targetHighlight.Enabled = false
		targetHighlight.Adornee = nil
		return
	end

	beamTargetPart.Position = position
	beam.Attachment0 = attachment
	beam.Enabled = true

	local adornee = highlight and getHighlightAdornee(instance) or nil
	if targetHighlight.Adornee ~= adornee then
		targetHighlight.Adornee = adornee
	end
	targetHighlight.Enabled = adornee ~= nil
end

--|| Guide Builders ||--

local function spotlight(hint: string, targetId: string)
	return { Hint = hint, Spotlight = targetId }
end

local function pointAt(hint: string, instance: Instance?, highlight: boolean?)
	return { Hint = hint, WorldTarget = instance, Highlight = highlight ~= false }
end

-- World steps need the backpack closed so the player can see and click the world
local function worldStep(state, hint: string, instance: Instance?, highlight: boolean?)
	if state.InventoryReducer.BackpackOpen then
		return spotlight(Hints.CloseBackpack, INVENTORY_BUTTON)
	end
	return pointAt(hint, instance, highlight)
end

-- Make the player equip a hotbar item matching `predicate`
local function equipStep(state, hint: string, predicate)
	local inventoryState = state.InventoryReducer
	if inventoryState.BackpackOpen then
		return spotlight(Hints.CloseBackpack, INVENTORY_BUTTON)
	end

	local slot = findHotbarSlot(inventoryState, predicate)
	if slot then
		return spotlight(hint, "HotbarSlot_" .. slot)
	end
	return nil
end

local function isNamed(itemName: string)
	return function(_, item)
		return item.itemName == itemName
	end
end

-- Guide the player to collect more of a raw breakable material
local function collectStep(state, hint: string, materialType: string)
	return worldStep(state, hint, findClosestBreakable(materialType))
end

-- Guide the player through crafting an Inventory recipe from the backpack, using ALL their inputs at once:
-- open backpack -> click the recipe until every input is in the pool -> click CRAFT
local function inventoryCraftStep(state, recipe)
	local inventoryState = state.InventoryReducer
	local input = recipe.inputs[1]
	local pool = state.CraftingPoolReducer.Pool or {}

	local poolInput, poolHasOtherItems = 0, false
	for _, entry in ipairs(pool) do
		if entry.itemName == input.itemName then
			poolInput = poolInput + entry.quantity
		else
			poolHasOtherItems = true
		end
	end

	local inputOwned = countItem(inventoryState, input.itemName)
	if inputOwned + poolInput < input.quantity then
		-- Raw inputs (Log) share their name with their breakable material type
		return collectStep(state, Hints.CollectMoreLogs, input.itemName)
	end

	if not inventoryState.BackpackOpen then
		return spotlight(Hints.OpenBackpack, INVENTORY_BUTTON)
	end

	-- A crafting station is open in the backpack instead of the inventory crafting panel
	if STATION_FRAMES[state.UIReducer.CurrentFrame] then
		return spotlight(Hints.CloseBackpack, INVENTORY_BUTTON)
	end

	-- Craft once every full set of inputs is in the pool
	local craftButtonId = "InventoryCraftButton_" .. recipe.id
	local allInputsPooled = inputOwned < input.quantity
	if poolInput >= input.quantity and allInputsPooled and not poolHasOtherItems and TutorialTargets.Get(craftButtonId) then
		return spotlight(Hints.ClickCraft, craftButtonId)
	end

	local totalCrafts = math.floor((inputOwned + poolInput) / input.quantity)
	local pooledCrafts = poolHasOtherItems and 0 or math.floor(poolInput / input.quantity)
	local hint = string.format(Hints.SelectRecipeCount, recipe.displayName, pooledCrafts, totalCrafts)
	return spotlight(hint, "InventoryRecipe_" .. recipe.id)
end

--|| Task Resolvers ||--
-- Each returns the guide for the current sub-step: { Hint, Spotlight?, WorldTarget?, Highlight? }

local taskResolvers = {}

function taskResolvers.CollectLogs(task, state)
	return collectStep(state, Hints.CollectLogs, task.materialType)
end

function taskResolvers.GetWorkbenchBlueprint(task, state)
	if state.UIReducer.CurrentFrame ~= "Blueprint" then
		return worldStep(state, Hints.OpenBlueprintTable, findBlueprintsTable())
	end

	local getButtonId = "BlueprintGetButton_" .. task.blueprintType
	if TutorialTargets.Get(getButtonId) then
		return spotlight(Hints.ClickGet, getButtonId)
	end
	return spotlight(string.format(Hints.SelectBlueprint, task.blueprintType), "BlueprintCard_" .. task.blueprintType)
end

function taskResolvers.PlaceWorkbench(task, state)
	local blueprintItemName = task.blueprintType .. "Blueprint"
	local equippedItem = getEquippedItem(state.InventoryReducer)

	if not equippedItem or equippedItem.itemName ~= blueprintItemName then
		return equipStep(state, Hints.EquipBlueprint, isNamed(blueprintItemName))
			or { Hint = string.format(Hints.MoveToHotbar, getDisplayName(blueprintItemName)) }
	end

	if BuildingController and BuildingController:IsPlayerInBuildingArea() then
		return { Hint = Hints.PlaceBlueprint }
	end
	return pointAt(Hints.PlaceBlueprint, findBuildingArea(), false)
end

function taskResolvers.BuildWorkbench(task, state)
	local inventoryState = state.InventoryReducer
	local tutorialState = state.TutorialReducer
	local blockName = getDisplayName(task.blockType)

	local blocksNeeded = math.max(tutorialState.Required - tutorialState.Current, 0)
	local blocksOwned = countItem(inventoryState, task.blockType)

	if blocksOwned < blocksNeeded then
		return inventoryCraftStep(state, Recipes.GetRecipe(task.blockRecipeId))
	end

	local equippedItem = getEquippedItem(inventoryState)
	if not equippedItem or equippedItem.itemName ~= task.blockType then
		return equipStep(state, string.format(Hints.EquipBlocks, blockName), isNamed(task.blockType))
			or { Hint = string.format(Hints.MoveToHotbar, blockName) }
	end

	return worldStep(state, string.format(Hints.FillBlueprint, blockName), findPlacedBlueprint(task.blueprintType, false))
end

function taskResolvers.CraftPickaxe(task, state)
	local inventoryState = state.InventoryReducer
	local recipe = Recipes.GetRecipe(task.recipeId)
	local input = recipe.inputs[1]
	local inputAvailable = countItem(inventoryState, input.itemName) + countPoolItem(state, input.itemName)

	local isStationOpen = inventoryState.BackpackOpen and state.UIReducer.CurrentFrame == recipe.stationType
	if isStationOpen then
		if state.CraftingReducer.CurrentCraft then
			return { Hint = Hints.WaitForCraft }
		end

		local craftButtonId = recipe.stationType .. "CraftButton_" .. recipe.id
		if TutorialTargets.Get(craftButtonId) then
			return spotlight(Hints.ClickCraft, craftButtonId)
		end
		if inputAvailable >= input.quantity then
			return spotlight(string.format(Hints.SelectRecipe, recipe.displayName), recipe.stationType .. "Recipe_" .. recipe.id)
		end
		-- Not enough ingredients: close the station to craft them from the backpack
		return spotlight(Hints.CloseBackpack, INVENTORY_BUTTON)
	end

	if inputAvailable < input.quantity then
		return inventoryCraftStep(state, Recipes.GetRecipe(task.ingredientRecipeId))
	end

	return worldStep(state, string.format(Hints.OpenStation, recipe.stationType), findPlacedBlueprint(recipe.stationType, true))
end

function taskResolvers.CollectStone(task, state)
	local equippedItem = getEquippedItem(state.InventoryReducer)
	local equippedConfig = equippedItem and ItemData.GetItem(equippedItem.itemName)

	if not equippedConfig or equippedConfig.toolCategory ~= task.toolCategory then
		local equipGuide = equipStep(state, string.format(Hints.EquipTool, task.toolCategory), function(itemConfig)
			return itemConfig ~= nil and itemConfig.toolCategory == task.toolCategory
		end)
		if equipGuide then
			return equipGuide
		end
	end

	return collectStep(state, Hints.CollectStone, task.materialType)
end

--|| Guide Loop ||--

local function resolveGuide(state)
	local tutorialState = state.TutorialReducer
	if tutorialState.Completed or tutorialState.CurrentTask < 1 then return nil end

	local task = TutorialData.Tasks[tutorialState.CurrentTask]
	local resolver = task and taskResolvers[task.id]
	if not resolver then return nil end

	return resolver(task, state)
end

local function applyGuide(guide)
	if guide and guide.WorldTarget then
		setWorldTarget(guide.WorldTarget, guide.Highlight)
	elseif beam then
		setWorldTarget(nil, false)
	end

	local hint = guide and guide.Hint or nil
	local spotlightTarget = guide and guide.Spotlight or nil
	local tutorialState = Store:getState().TutorialReducer
	if tutorialState.Hint ~= hint or tutorialState.SpotlightTarget ~= spotlightTarget then
		Store:dispatch(TutorialActions.setTutorialGuide(hint, spotlightTarget))
	end
end

local function onHeartbeat()
	local now = os.clock()
	if now - lastGuideUpdate < TutorialConfig.GuideUpdateInterval then return end
	lastGuideUpdate = now

	applyGuide(resolveGuide(Store:getState()))
end

-- Notify the player when a task (or the whole tutorial) is completed
local function onStoreChanged(newState, oldState)
	local newTutorial = newState.TutorialReducer
	local oldTutorial = oldState.TutorialReducer
	if oldTutorial.CurrentTask < 1 or oldTutorial.Completed or not TextNotificationController then return end

	if newTutorial.Completed then
		TextNotificationController:Show(TutorialData.TutorialCompletedText, TutorialConfig.HighlightColor)
	elseif newTutorial.CurrentTask > oldTutorial.CurrentTask then
		local completedTask = TutorialData.Tasks[oldTutorial.CurrentTask]
		TextNotificationController:Show(string.format(TutorialData.TaskCompletedText, completedTask.title), TutorialConfig.HighlightColor)
	end
end

--|| Public Functions ||--

function TutorialController:IsTutorialActive(): boolean
	local tutorialState = Store:getState().TutorialReducer
	return tutorialState.CurrentTask >= 1 and not tutorialState.Completed
end

--|| Initialization ||--

function TutorialController:KnitStart()
	BuildingController = Knit.GetController("BuildingController")
	TextNotificationController = Knit.GetController("TextNotificationController")

	local ZoneService = Knit.GetService("ZoneService")
	ZoneService.ZoneAssigned:Connect(function(assignedZoneName)
		zoneName = assignedZoneName
	end)
	ZoneService:GetAssignedZone():andThen(function(assignedZoneName)
		zoneName = zoneName or assignedZoneName
	end)

	Store.changed:connect(onStoreChanged)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return TutorialController
