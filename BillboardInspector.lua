--[[
	BillboardInspector.lua

	Run this in Roblox Studio's Command Bar to extract all properties
	of the GeneralPlayer billboard.

	Copy the output from the Output window and send it back.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local output = {}

local function addLine(text)
	table.insert(output, text)
end

local function serializeColor3(color)
	return string.format("Color3.fromRGB(%d, %d, %d)",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255))
end

local function serializeUDim2(udim2)
	return string.format("UDim2.new(%.4f, %d, %.4f, %d)",
		udim2.X.Scale, udim2.X.Offset,
		udim2.Y.Scale, udim2.Y.Offset)
end

local function serializeUDim(udim)
	return string.format("UDim.new(%.4f, %d)", udim.Scale, udim.Offset)
end

local function serializeVector2(vec)
	return string.format("Vector2.new(%.4f, %.4f)", vec.X, vec.Y)
end

local function serializeVector3(vec)
	return string.format("Vector3.new(%.4f, %.4f, %.4f)", vec.X, vec.Y, vec.Z)
end

local function serializeEnum(enum)
	return tostring(enum)
end

local function inspectInstance(instance, indent)
	indent = indent or 0
	local prefix = string.rep("  ", indent)

	addLine("")
	addLine(prefix .. "=== " .. instance.ClassName .. ": \"" .. instance.Name .. "\" ===")

	-- Common properties for all GUI objects
	if instance:IsA("GuiObject") then
		addLine(prefix .. "Name = \"" .. instance.Name .. "\"")
		addLine(prefix .. "Position = " .. serializeUDim2(instance.Position))
		addLine(prefix .. "Size = " .. serializeUDim2(instance.Size))
		addLine(prefix .. "AnchorPoint = " .. serializeVector2(instance.AnchorPoint))
		addLine(prefix .. "BackgroundColor3 = " .. serializeColor3(instance.BackgroundColor3))
		addLine(prefix .. "BackgroundTransparency = " .. instance.BackgroundTransparency)
		addLine(prefix .. "BorderSizePixel = " .. instance.BorderSizePixel)
		addLine(prefix .. "Visible = " .. tostring(instance.Visible))
		addLine(prefix .. "ZIndex = " .. instance.ZIndex)
		addLine(prefix .. "LayoutOrder = " .. instance.LayoutOrder)
		addLine(prefix .. "ClipsDescendants = " .. tostring(instance.ClipsDescendants))

		if instance:IsA("GuiButton") then
			addLine(prefix .. "AutoButtonColor = " .. tostring(instance.AutoButtonColor))
		end
	end

	-- BillboardGui specific
	if instance:IsA("BillboardGui") then
		addLine(prefix .. "Name = \"" .. instance.Name .. "\"")
		addLine(prefix .. "Size = " .. serializeUDim2(instance.Size))
		addLine(prefix .. "StudsOffset = " .. serializeVector3(instance.StudsOffset))
		addLine(prefix .. "StudsOffsetWorldSpace = " .. serializeVector3(instance.StudsOffsetWorldSpace))
		addLine(prefix .. "ExtentsOffset = " .. serializeVector3(instance.ExtentsOffset))
		addLine(prefix .. "ExtentsOffsetWorldSpace = " .. serializeVector3(instance.ExtentsOffsetWorldSpace))
		addLine(prefix .. "LightInfluence = " .. instance.LightInfluence)
		addLine(prefix .. "MaxDistance = " .. instance.MaxDistance)
		addLine(prefix .. "AlwaysOnTop = " .. tostring(instance.AlwaysOnTop))
		addLine(prefix .. "Active = " .. tostring(instance.Active))
		addLine(prefix .. "Enabled = " .. tostring(instance.Enabled))
		addLine(prefix .. "ClipsDescendants = " .. tostring(instance.ClipsDescendants))
		addLine(prefix .. "ZIndexBehavior = " .. serializeEnum(instance.ZIndexBehavior))
	end

	-- Frame specific
	if instance:IsA("Frame") then
		-- Already covered by GuiObject
	end

	-- TextButton / TextLabel specific
	if instance:IsA("TextButton") or instance:IsA("TextLabel") then
		addLine(prefix .. "Text = \"" .. instance.Text .. "\"")
		addLine(prefix .. "TextColor3 = " .. serializeColor3(instance.TextColor3))
		addLine(prefix .. "TextSize = " .. instance.TextSize)
		addLine(prefix .. "TextScaled = " .. tostring(instance.TextScaled))
		addLine(prefix .. "TextWrapped = " .. tostring(instance.TextWrapped))
		addLine(prefix .. "TextXAlignment = " .. serializeEnum(instance.TextXAlignment))
		addLine(prefix .. "TextYAlignment = " .. serializeEnum(instance.TextYAlignment))
		addLine(prefix .. "TextTransparency = " .. instance.TextTransparency)
		addLine(prefix .. "Font = " .. serializeEnum(instance.Font))
		addLine(prefix .. "RichText = " .. tostring(instance.RichText))

		if instance:FindFirstChildOfClass("UITextSizeConstraint") then
			local constraint = instance:FindFirstChildOfClass("UITextSizeConstraint")
			addLine(prefix .. "-- UITextSizeConstraint:")
			addLine(prefix .. "  MinTextSize = " .. constraint.MinTextSize)
			addLine(prefix .. "  MaxTextSize = " .. constraint.MaxTextSize)
		end
	end

	-- ImageButton / ImageLabel specific
	if instance:IsA("ImageButton") or instance:IsA("ImageLabel") then
		addLine(prefix .. "Image = \"" .. instance.Image .. "\"")
		addLine(prefix .. "ImageColor3 = " .. serializeColor3(instance.ImageColor3))
		addLine(prefix .. "ImageTransparency = " .. instance.ImageTransparency)
		addLine(prefix .. "ScaleType = " .. serializeEnum(instance.ScaleType))
		if instance.ScaleType == Enum.ScaleType.Slice then
			addLine(prefix .. "SliceCenter = Rect.new(" .. instance.SliceCenter.Min.X .. ", " .. instance.SliceCenter.Min.Y .. ", " .. instance.SliceCenter.Max.X .. ", " .. instance.SliceCenter.Max.Y .. ")")
			addLine(prefix .. "SliceScale = " .. instance.SliceScale)
		end
	end

	-- UICorner
	if instance:IsA("UICorner") then
		addLine(prefix .. "CornerRadius = " .. serializeUDim(instance.CornerRadius))
	end

	-- UIStroke
	if instance:IsA("UIStroke") then
		addLine(prefix .. "Color = " .. serializeColor3(instance.Color))
		addLine(prefix .. "Thickness = " .. instance.Thickness)
		addLine(prefix .. "Transparency = " .. instance.Transparency)
		addLine(prefix .. "ApplyStrokeMode = " .. serializeEnum(instance.ApplyStrokeMode))
		addLine(prefix .. "LineJoinMode = " .. serializeEnum(instance.LineJoinMode))
	end

	-- UIPadding
	if instance:IsA("UIPadding") then
		addLine(prefix .. "PaddingTop = " .. serializeUDim(instance.PaddingTop))
		addLine(prefix .. "PaddingBottom = " .. serializeUDim(instance.PaddingBottom))
		addLine(prefix .. "PaddingLeft = " .. serializeUDim(instance.PaddingLeft))
		addLine(prefix .. "PaddingRight = " .. serializeUDim(instance.PaddingRight))
	end

	-- UIListLayout
	if instance:IsA("UIListLayout") then
		addLine(prefix .. "FillDirection = " .. serializeEnum(instance.FillDirection))
		addLine(prefix .. "HorizontalAlignment = " .. serializeEnum(instance.HorizontalAlignment))
		addLine(prefix .. "VerticalAlignment = " .. serializeEnum(instance.VerticalAlignment))
		addLine(prefix .. "Padding = " .. serializeUDim(instance.Padding))
		addLine(prefix .. "SortOrder = " .. serializeEnum(instance.SortOrder))
	end

	-- UIGridLayout
	if instance:IsA("UIGridLayout") then
		addLine(prefix .. "CellPadding = " .. serializeUDim2(instance.CellPadding))
		addLine(prefix .. "CellSize = " .. serializeUDim2(instance.CellSize))
		addLine(prefix .. "FillDirection = " .. serializeEnum(instance.FillDirection))
		addLine(prefix .. "FillDirectionMaxCells = " .. instance.FillDirectionMaxCells)
		addLine(prefix .. "HorizontalAlignment = " .. serializeEnum(instance.HorizontalAlignment))
		addLine(prefix .. "VerticalAlignment = " .. serializeEnum(instance.VerticalAlignment))
		addLine(prefix .. "SortOrder = " .. serializeEnum(instance.SortOrder))
	end

	-- UISizeConstraint
	if instance:IsA("UISizeConstraint") then
		addLine(prefix .. "MinSize = " .. serializeVector2(instance.MinSize))
		addLine(prefix .. "MaxSize = " .. serializeVector2(instance.MaxSize))
	end

	-- UIAspectRatioConstraint
	if instance:IsA("UIAspectRatioConstraint") then
		addLine(prefix .. "AspectRatio = " .. instance.AspectRatio)
		addLine(prefix .. "AspectType = " .. serializeEnum(instance.AspectType))
		addLine(prefix .. "DominantAxis = " .. serializeEnum(instance.DominantAxis))
	end

	-- UIGradient
	if instance:IsA("UIGradient") then
		addLine(prefix .. "Color = " .. tostring(instance.Color)) -- ColorSequence
		addLine(prefix .. "Transparency = " .. tostring(instance.Transparency)) -- NumberSequence
		addLine(prefix .. "Offset = " .. serializeVector2(instance.Offset))
		addLine(prefix .. "Rotation = " .. instance.Rotation)
	end

	-- Recurse into children
	for _, child in ipairs(instance:GetChildren()) do
		inspectInstance(child, indent + 1)
	end
end

-- Find the billboard
local billboard = ReplicatedStorage:FindFirstChild("GeneralPlayer")
if not billboard then
	warn("GeneralPlayer billboard not found in ReplicatedStorage!")
	return
end

addLine("========================================")
addLine("BILLBOARD INSPECTOR OUTPUT")
addLine("GeneralPlayer Billboard Structure")
addLine("========================================")

inspectInstance(billboard, 0)

addLine("")
addLine("========================================")
addLine("END OF INSPECTION")
addLine("========================================")

-- Print all output
local fullOutput = table.concat(output, "\n")
print(fullOutput)

-- Also return it for easy copying
return fullOutput
