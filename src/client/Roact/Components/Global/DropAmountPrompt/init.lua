--[=[
	DropAmountPrompt Component
	"Drop how many?" panel opened on touch when a stack is dragged out of the inventory.
	The number field only accepts digits, up to the stack size.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local FancyText = require(Components.Global.FancyText)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local function getInventoryController()
	return Knit.GetController("InventoryController")
end

local function createButton(text: string, color: Color3, layoutOrder: number, zIndex: number, onClick)
	return Roact.createElement("TextButton", {
		Size = Config.ButtonSize,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = layoutOrder,
		ZIndex = zIndex,
		[Roact.Event.Activated] = onClick,
	}, {
		Background = Roact.createElement(StudBackground, {
			ZIndex = zIndex,
			BackgroundColor = color,
			ImageTransparency = Config.ButtonStudTransparency,
			CornerRadius = Config.ButtonCornerRadius,
			StrokeColor = Config.ButtonStrokeColor,
			StrokeThickness = Config.ButtonStrokeThickness,
			StrokeTransparency = 0,
		}),

		Label = Roact.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = Config.ButtonTextColor,
			TextScaled = true,
			FontFace = Config.Font,
			ZIndex = zIndex + 1,
		}, {
			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.ButtonTextStrokeColor,
				Thickness = Config.ButtonTextStrokeThickness,
			}),
			UITextSizeConstraint = Roact.createElement("UITextSizeConstraint", {
				MaxTextSize = Config.MaxTextSize,
				MinTextSize = Config.MinTextSize,
			}),
			UIPadding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0.2, 0),
				PaddingBottom = UDim.new(0.2, 0),
			}),
		}),
	})
end

local function DropAmountPrompt(props, hooks)
	local prompt = RoduxHooks.useSelector(hooks, function(state)
		return state.DropPromptReducer.Prompt
	end)

	local inputRef = hooks.useValue(Roact.createRef())

	if not prompt then
		return nil
	end

	local maxQuantity = prompt.maxQuantity
	local zIndex = Config.ZIndex

	local function confirm()
		local input = inputRef.value:getValue()
		local quantity = input and tonumber(input.Text)
		if not quantity or quantity < 1 then return end
		getInventoryController():ConfirmDropPrompt(quantity)
	end

	local function cancel()
		getInventoryController():CancelDropPrompt()
	end

	return Roact.createElement("ImageButton", {
		Name = "DropAmountPrompt",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Config.BackdropColor,
		BackgroundTransparency = Config.BackdropTransparency,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
		ZIndex = zIndex,
		[Roact.Event.Activated] = cancel,
	}, {
		-- Keyed by prompt id so the number field resets for every new prompt
		["Panel" .. prompt.id] = Roact.createElement("ImageButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = Config.PanelPosition,
			Size = Config.PanelSize,
			BackgroundTransparency = 1,
			Image = "",
			AutoButtonColor = false,
			ZIndex = zIndex + 1,
			[Roact.Event.Activated] = function() end, -- Clicks on the panel don't cancel
		}, {
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = Config.PanelAspectRatio,
			}),

			Background = Roact.createElement(StudBackground, {
				ZIndex = zIndex + 1,
				BackgroundColor = Config.PanelBackgroundColor,
				ImageTransparency = Config.PanelStudTransparency,
				CornerRadius = Config.CornerRadius,
				StrokeColor = Config.PanelStrokeColor,
				StrokeThickness = Config.PanelStrokeThickness,
				StrokeTransparency = 0,
			}),

			Title = Roact.createElement(FancyText, {
				Text = Config.TitleText,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = Config.TitlePosition,
				Size = Config.TitleSize,
				TextColor3 = Config.TitleColor,
				StrokeColor = Config.TitleStrokeColor,
				StrokeThickness = Config.TitleStrokeThickness,
				ZIndex = zIndex + 2,
			}),

			AmountRow = Roact.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = Config.RowPosition,
				Size = Config.RowSize,
				BackgroundTransparency = 1,
				ZIndex = zIndex + 2,
			}, {
				UIListLayout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = Config.RowPadding,
				}),

				ItemImage = Roact.createElement("ImageLabel", {
					Size = Config.ImageSize,
					BackgroundTransparency = 1,
					Image = Images[prompt.itemName] or "",
					ScaleType = Enum.ScaleType.Fit,
					LayoutOrder = 1,
					ZIndex = zIndex + 2,
				}),

				Input = Roact.createElement("TextBox", {
					Size = Config.InputSize,
					BackgroundColor3 = Config.InputBackgroundColor,
					BorderSizePixel = 0,
					Text = tostring(maxQuantity),
					PlaceholderText = "1 - " .. maxQuantity,
					PlaceholderColor3 = Config.InputPlaceholderColor,
					TextColor3 = Config.InputTextColor,
					TextScaled = true,
					FontFace = Config.Font,
					ClearTextOnFocus = true,
					LayoutOrder = 2,
					ZIndex = zIndex + 2,
					[Roact.Ref] = inputRef.value,
					-- Digits only, never above the stack size
					[Roact.Change.Text] = function(rbx)
						local digits = (string.gsub(rbx.Text, "%D", ""))
						local quantity = tonumber(digits)
						if quantity and quantity > maxQuantity then
							digits = tostring(maxQuantity)
						end
						if digits ~= rbx.Text then
							rbx.Text = digits
						end
					end,
					[Roact.Event.FocusLost] = function(rbx, enterPressed)
						local quantity = tonumber(rbx.Text)
						if not quantity then
							rbx.Text = tostring(maxQuantity)
						elseif quantity < 1 then
							rbx.Text = "1"
						end
						if enterPressed then
							confirm()
						end
					end,
				}, {
					UICorner = Roact.createElement("UICorner", {
						CornerRadius = Config.InputCornerRadius,
					}),
					UIStroke = Roact.createElement("UIStroke", {
						Color = Config.InputStrokeColor,
						Thickness = Config.InputStrokeThickness,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					UITextSizeConstraint = Roact.createElement("UITextSizeConstraint", {
						MaxTextSize = Config.MaxTextSize,
						MinTextSize = Config.MinTextSize,
					}),
				}),

				MaxLabel = Roact.createElement(FancyText, {
					Text = "/ " .. maxQuantity,
					Size = Config.MaxLabelSize,
					TextColor3 = Config.MaxLabelColor,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 3,
					ZIndex = zIndex + 2,
				}),
			}),

			Buttons = Roact.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = Config.ButtonsPosition,
				Size = Config.ButtonsSize,
				BackgroundTransparency = 1,
				ZIndex = zIndex + 2,
			}, {
				UIListLayout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = Config.ButtonsPadding,
				}),

				Cancel = createButton(Config.CancelText, Config.CancelColor, 1, zIndex + 2, cancel),
				Drop = createButton(Config.DropText, Config.DropColor, 2, zIndex + 2, confirm),
			}),
		}),
	})
end

DropAmountPrompt = RoactHooks.new(Roact)(DropAmountPrompt)
return DropAmountPrompt
