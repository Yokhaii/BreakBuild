--[=[
	BlueprintMaterialList Component
	Horizontal strip of required block icons with a quantity badge.
	No background — sits bare below the viewport.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local function BlueprintMaterialList(props, hooks)
	local materials = props.Materials or {}
	local baseZIndex = props.ZIndex or 1

	local slots = {}
	for i, material in ipairs(materials) do
		local image = Images[material.Type] or ""
		slots["Material_" .. i] = Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			ZIndex = baseZIndex,
		}, {
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),

			Icon = Roact.createElement("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = image,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = baseZIndex + 1,
			}),

			Quantity = Roact.createElement("TextLabel", {
				Size = UDim2.fromScale(0.55, 0.35),
				Position = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(1, 1),
				BackgroundTransparency = 1,
				Text = "x" .. tostring(material.Amount),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				FontFace = Font.fromEnum(Enum.Font.GothamBold),
				ZIndex = baseZIndex + 2,
			}, {
				UIStroke = Roact.createElement("UIStroke", {
					Color = Color3.fromRGB(0, 0, 0),
					Thickness = 1.5,
				}),
			}),
		})
	end

	return Roact.createElement("Frame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,
	}, {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.02, 0),
		}),

		Slots = Roact.createFragment(slots),
	})
end

BlueprintMaterialList = RoactHooks.new(Roact)(BlueprintMaterialList)
return BlueprintMaterialList
