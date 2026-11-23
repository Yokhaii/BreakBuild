--[=[
	DroppedItemService
	Items dropped in the world. The server places the model at its landing spot (anchored,
	no physics) and DroppedItemController animates the toss and the hover/spin on clients.
	Any player walking over a landed item picks it up.
]=]

-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local DroppedItemConfig = require(ReplicatedStorage.Shared.Config.DroppedItemConfig)

-- Services (to be initialized)
local InventoryService

local DroppedItemService = Knit.CreateService({
	Name = "DroppedItemService",
	Client = {},
})

-- Types
type DroppedItem = {
	itemName: string,
	quantity: number,
	durability: number?,
	dropperId: number,
	droppedAt: number,
	landedAt: number,
	center: Vector3,
}

-- Private variables
local droppedItems: {[Model]: DroppedItem} = {}
local droppedFolder: Folder

--|| Private Functions ||--

-- Same path format as the held model: "Assets.Items.X" or "ReplicatedStorage.Assets.Items.X"
local function getItemModel(modelPath: string): Model?
	local pathParts = string.split(modelPath, ".")
	local current = ReplicatedStorage
	for i = pathParts[1] == "ReplicatedStorage" and 2 or 1, #pathParts do
		current = current and current:FindFirstChild(pathParts[i])
	end
	if current and current:IsA("Model") then
		return current
	end
	return nil
end

-- World-aligned bounding box of the model's parts: (center, size)
local function getWorldBounds(model: Model): (Vector3, Vector3)
	local minCorner = Vector3.new(math.huge, math.huge, math.huge)
	local maxCorner = -minCorner
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, corner in ipairs({
				Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1),
				Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1),
			}) do
				local point = part.CFrame:PointToWorldSpace(half * corner)
				minCorner = minCorner:Min(point)
				maxCorner = maxCorner:Max(point)
			end
		end
	end
	return (minCorner + maxCorner) / 2, maxCorner - minCorner
end

local function getRaycastParams(): RaycastParams
	local exclude = { droppedFolder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	return params
end

-- Seconds for the toss arc to go from startY to endY
local function getFallTime(startY: number, endY: number): number
	local upSpeed = DroppedItemConfig.TossUpSpeed
	local gravity = DroppedItemConfig.Gravity
	local discriminant = upSpeed * upSpeed + 2 * gravity * (startY - endY)
	if discriminant < 0 then
		return DroppedItemConfig.MinFallTime
	end
	return math.max((upSpeed + math.sqrt(discriminant)) / gravity, DroppedItemConfig.MinFallTime)
end

local function tryPickup(model: Model, dropped: DroppedItem, now: number)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == dropped.dropperId and now - dropped.droppedAt < DroppedItemConfig.OwnerPickupDelay then
			continue
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not humanoid or humanoid.Health <= 0 then
			continue
		end

		local offset = root.Position - dropped.center
		if Vector2.new(offset.X, offset.Z).Magnitude > DroppedItemConfig.PickupRadius
			or math.abs(offset.Y) > DroppedItemConfig.PickupHeight then
			continue
		end

		if not InventoryService:CanAddItem(player, dropped.itemName, dropped.quantity) then
			continue
		end

		if InventoryService:AddItem(player, dropped.itemName, dropped.quantity, false, dropped.durability) then
			droppedItems[model] = nil
			model:Destroy()
			return
		end
	end
end

local function updateDroppedItems()
	local now = workspace:GetServerTimeNow()
	for model, dropped in pairs(droppedItems) do
		if not model.Parent or now - dropped.droppedAt >= DroppedItemConfig.DespawnTime then
			droppedItems[model] = nil
			model:Destroy()
		elseif now >= dropped.landedAt then
			tryPickup(model, dropped, now)
		end
	end
end

--|| Public Functions ||--

-- Tosses an item in front of the player. Returns false (nothing spawned) when there is no ground.
function DroppedItemService:DropItem(player: Player, itemName: string, quantity: number, durability: number?): boolean
	local itemConfig = ItemData.GetItem(itemName)
	local template = itemConfig and itemConfig.modelPath and getItemModel(itemConfig.modelPath)
	if not template then
		warn("Item model not found at path:", itemConfig and itemConfig.modelPath, itemName)
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local params = getRaycastParams()
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0 and look.Unit or Vector3.new(0, 0, -1)

	-- Don't throw through walls
	local dropDistance = DroppedItemConfig.DropDistance
	local wallHit = workspace:Raycast(root.Position, look * dropDistance, params)
	if wallHit then
		dropDistance = math.max((wallHit.Position - root.Position).Magnitude - 1, 0)
	end

	local scatterAngle = math.random() * 2 * math.pi
	local scatter = Vector3.new(math.cos(scatterAngle), 0, math.sin(scatterAngle)) * math.random() * DroppedItemConfig.DropScatter
	local dropPoint = root.Position + look * math.max(dropDistance - DroppedItemConfig.DropScatter, 0) + scatter
	local groundHit = workspace:Raycast(dropPoint, Vector3.new(0, -DroppedItemConfig.MaxGroundSearch, 0), params)
	if not groundHit then
		return false
	end

	-- Authored orientation (tools stand on their handle), positioned by its bounding box
	local model = template:Clone()
	model.Name = itemName .. "_Dropped"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		elseif descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end

	local rotation = template:GetPivot().Rotation
	model:PivotTo(rotation)
	local centerOffset, size = getWorldBounds(model)
	local landCenter = groundHit.Position + Vector3.new(0, size.Y / 2 + DroppedItemConfig.HoverHeight, 0)
	model:PivotTo(CFrame.new(landCenter - centerOffset) * rotation)

	local startCenter = root.Position
		+ look * DroppedItemConfig.TossStartForward
		+ Vector3.new(0, DroppedItemConfig.TossStartHeight, 0)
	local droppedAt = workspace:GetServerTimeNow()
	local fallTime = getFallTime(startCenter.Y, landCenter.Y)

	model:SetAttribute("ItemName", itemName)
	model:SetAttribute("Quantity", quantity)
	model:SetAttribute("StartCenter", startCenter)
	model:SetAttribute("LandCenter", landCenter)
	model:SetAttribute("Height", size.Y)
	model:SetAttribute("DroppedAt", droppedAt)
	model:SetAttribute("FallTime", fallTime)
	CollectionService:AddTag(model, DroppedItemConfig.Tag)

	droppedItems[model] = {
		itemName = itemName,
		quantity = quantity,
		durability = durability,
		dropperId = player.UserId,
		droppedAt = droppedAt,
		landedAt = droppedAt + fallTime,
		center = landCenter,
	}

	model.Parent = droppedFolder
	return true
end

-- KNIT START
function DroppedItemService:KnitStart()
	InventoryService = Knit.GetService("InventoryService")

	droppedFolder = Instance.new("Folder")
	droppedFolder.Name = DroppedItemConfig.FolderName
	droppedFolder.Parent = workspace

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < DroppedItemConfig.PickupCheckInterval then return end
		elapsed = 0
		updateDroppedItems()
	end)
end

return DroppedItemService
