--[=[
	DroppedItemController
	Animates dropped items locally: the toss arc from the player to the ground, then the
	hover (bob) and spin once landed. The server keeps the model anchored at its landing
	spot and handles pickup (DroppedItemService).
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Config
local DroppedItemConfig = require(ReplicatedStorage.Shared.Config.DroppedItemConfig)

local DroppedItemController = Knit.CreateController({ Name = "DroppedItemController" })

-- Private variables
-- [Model] = { startCenter, landCenter, droppedAt, fallTime, offset (pivot relative to the center), label? }
local animatedItems = {}

--|| Private Functions ||--

-- "x12" above the item. Adorned to an invisible part at the item's center (moved with the
-- model by PivotTo), so it follows the bob without circling around with the spin.
local function createQuantityLabel(model: Model, landCenter: Vector3, quantity: number): BillboardGui
	local anchor = Instance.new("Part")
	anchor.Name = "QuantityLabelAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = CFrame.new(landCenter)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "QuantityLabel"
	billboard.Adornee = anchor
	billboard.Size = DroppedItemConfig.LabelSize
	billboard.StudsOffsetWorldSpace = Vector3.new(0, (model:GetAttribute("Height") or 0) / 2 + DroppedItemConfig.LabelOffset, 0)
	billboard.MaxDistance = DroppedItemConfig.LabelMaxDistance
	billboard.LightInfluence = 0
	billboard.Enabled = false -- Shown once the item has landed
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "x" .. quantity
	label.TextScaled = true
	label.FontFace = DroppedItemConfig.LabelFont
	label.TextColor3 = DroppedItemConfig.LabelTextColor
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = DroppedItemConfig.LabelStrokeColor
	stroke.Thickness = DroppedItemConfig.LabelStrokeThickness
	stroke.Parent = label

	anchor.Parent = model
	return billboard
end

local function onItemAdded(model: Instance)
	if not model:IsA("Model") then return end

	local landCenter = model:GetAttribute("LandCenter")
	if not landCenter then return end

	local offset = CFrame.new(landCenter):Inverse() * model:GetPivot()
	local quantity = model:GetAttribute("Quantity") or 1

	animatedItems[model] = {
		startCenter = model:GetAttribute("StartCenter") or landCenter,
		landCenter = landCenter,
		droppedAt = model:GetAttribute("DroppedAt") or 0,
		fallTime = model:GetAttribute("FallTime") or 0,
		offset = offset,
		label = quantity > 1 and createQuantityLabel(model, landCenter, quantity) or nil,
	}
end

local function onItemRemoved(model: Instance)
	animatedItems[model] = nil
end

local function getCenter(item, now: number): Vector3
	local elapsed = now - item.droppedAt
	if elapsed >= item.fallTime then
		local bob = math.sin((elapsed - item.fallTime) * DroppedItemConfig.BobSpeed * 2 * math.pi)
		return item.landCenter + Vector3.new(0, bob * DroppedItemConfig.BobAmplitude, 0)
	end

	-- Toss arc: linear horizontally, thrown up then falling vertically.
	-- The correction makes it end exactly on the ground when the fall time was clamped.
	local t = math.max(elapsed, 0)
	local alpha = t / item.fallTime
	local position = item.startCenter:Lerp(item.landCenter, alpha)
	local function arcHeight(time: number): number
		return item.startCenter.Y + DroppedItemConfig.TossUpSpeed * time - 0.5 * DroppedItemConfig.Gravity * time * time
	end
	local correction = (item.landCenter.Y - arcHeight(item.fallTime)) * alpha
	return Vector3.new(position.X, arcHeight(t) + correction, position.Z)
end

local function updateItems()
	local now = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position

	for model, item in pairs(animatedItems) do
		if not model.Parent then
			animatedItems[model] = nil
			continue
		end

		if cameraPosition and (item.landCenter - cameraPosition).Magnitude > DroppedItemConfig.AnimateDistance then
			continue
		end

		if item.label then
			item.label.Enabled = now - item.droppedAt >= item.fallTime
		end

		local angle = math.rad((now - item.droppedAt) * DroppedItemConfig.SpinSpeed)
		model:PivotTo(CFrame.new(getCenter(item, now)) * CFrame.Angles(0, angle, 0) * item.offset)
	end
end

--|| Initialization ||--

function DroppedItemController:KnitStart()
	CollectionService:GetInstanceAddedSignal(DroppedItemConfig.Tag):Connect(onItemAdded)
	CollectionService:GetInstanceRemovedSignal(DroppedItemConfig.Tag):Connect(onItemRemoved)
	for _, model in ipairs(CollectionService:GetTagged(DroppedItemConfig.Tag)) do
		onItemAdded(model)
	end

	RunService.RenderStepped:Connect(updateItems)
end

return DroppedItemController
