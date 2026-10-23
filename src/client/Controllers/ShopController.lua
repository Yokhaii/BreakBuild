local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)
local UIActions = require(Client.Rodux.Actions.UIActions)
local ShopActions = require(Client.Rodux.Actions.ShopActions)
local InventoryActions = require(Client.Rodux.Actions.InventoryActions)

local ShopController = Knit.CreateController({
	Name = "ShopController",
})

local INTERACTION_RANGE = 48
local BILLBOARD_TEXT = "Buy / Sell"

local player = Players.LocalPlayer

local ShopService
local InventoryController

local shopModel = nil
local currentHighlight = nil
local currentBillboard = nil
local isHovering = false
local isShopOpen = false
local isOpening = false

local function getShopModel()
	if shopModel and shopModel.Parent then
		return shopModel
	end
	shopModel = Workspace:FindFirstChild("Shop")
	return shopModel
end

local function clearHighlight()
	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end
	if currentBillboard then
		currentBillboard:Destroy()
		currentBillboard = nil
	end
	isHovering = false
end

local function showHighlight(target)
	if isHovering then return end
	isHovering = true

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Color3.new(0, 0, 0)
	highlight.Adornee = target
	highlight.Parent = target
	currentHighlight = highlight

	local adornee = target:FindFirstChild("BillboardAttach", true)
	if not adornee then
		if target:IsA("Model") and target.PrimaryPart then
			adornee = target.PrimaryPart
		elseif target:IsA("Model") then
			adornee = target:FindFirstChildWhichIsA("BasePart")
		else
			adornee = target
		end
	end

	if adornee then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(3, 0, 1.5, 0)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.Adornee = adornee
		billboard.AlwaysOnTop = true

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = BILLBOARD_TEXT
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextStrokeTransparency = 0.5
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextScaled = true
		textLabel.Parent = billboard

		billboard.Parent = target
		currentBillboard = billboard
	end
end

local function isDescendantOfShop(instance)
	local model = getShopModel()
	if not model then return false end
	return instance == model or instance:IsDescendantOf(model)
end

function ShopController:OpenShop()
	if isShopOpen or isOpening then return end
	isOpening = true

	ShopService:OpenShop()
		:andThen(function(result)
			isOpening = false
			if not result or not result.success then
				warn("[ShopController] OpenShop failed:", result and result.reason or "unknown")
				return
			end

			isShopOpen = true
			Store:dispatch(ShopActions.openShop(result.balance))
			Store:dispatch(UIActions.setCurrentFrame("Shop"))
			InventoryController:OpenBackpack()
		end)
		:catch(function(err)
			isOpening = false
			warn("[ShopController] OpenShop error:", err)
		end)
end

local function restoreSellPoolToInventory()
	local pool = Store:getState().ShopReducer.SellPool
	for _, entry in ipairs(pool) do
		if entry.gridIndex and entry.itemId then
			Store:dispatch(InventoryActions.restoreGridSlot(entry.gridIndex, {
				id = entry.itemId,
				itemName = entry.itemName,
				quantity = entry.quantity,
			}))
		end
	end
end

function ShopController:CloseShop()
	if not isShopOpen then return end
	restoreSellPoolToInventory()
	isShopOpen = false
	Store:dispatch(ShopActions.closeShop())
end

function ShopController:IsShopOpen()
	return isShopOpen
end

function ShopController:BuyItems(basket)
	ShopService:BuyItems(basket)
		:andThen(function(result)
			if result and result.success then
				Store:dispatch(ShopActions.clearBasket())
			else
				warn("[ShopController] BuyItems failed:", result and result.reason or "unknown")
			end
		end)
		:catch(function(err)
			warn("[ShopController] BuyItems error:", err)
		end)
end

function ShopController:SellItems(sellPool)
	ShopService:SellItems(sellPool)
		:andThen(function(result)
			if result and result.success then
				Store:dispatch(ShopActions.clearSellPool())
			else
				warn("[ShopController] SellItems failed:", result and result.reason or "unknown")
			end
		end)
		:catch(function(err)
			warn("[ShopController] SellItems error:", err)
		end)
end

function ShopController:KnitStart()
	ShopService = Knit.GetService("ShopService")
	InventoryController = Knit.GetController("InventoryController")

	Store.changed:connect(function(newState, oldState)
		local oldFrame = oldState.UIReducer and oldState.UIReducer.CurrentFrame
		local newFrame = newState.UIReducer and newState.UIReducer.CurrentFrame

		if oldFrame == "Shop" and newFrame ~= "Shop" and isShopOpen then
			restoreSellPoolToInventory()
			isShopOpen = false
			Store:dispatch(ShopActions.closeShop())
		end
	end)

	local camera = Workspace.CurrentCamera

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	RunService.RenderStepped:Connect(function()
		if isShopOpen then
			clearHighlight()
			return
		end

		local character = player.Character
		if not character then
			clearHighlight()
			return
		end

		raycastParams.FilterDescendantsInstances = { character }

		local mouseLocation = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

		local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
		if not result or not result.Instance then
			clearHighlight()
			return
		end

		if not isDescendantOfShop(result.Instance) then
			clearHighlight()
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			clearHighlight()
			return
		end

		local model = getShopModel()
		if not model then
			clearHighlight()
			return
		end

		local shopCFrame = model:IsA("Model") and model:GetBoundingBox() or model.CFrame
		local shopPos = shopCFrame.Position
		local dist = (rootPart.Position - shopPos).Magnitude
		if dist > INTERACTION_RANGE then
			clearHighlight()
			return
		end

		showHighlight(model)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not isHovering then return end
		if isShopOpen or isOpening then return end

		self:OpenShop()
	end)
end

return ShopController
