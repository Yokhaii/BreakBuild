--[=[
	ObjectiveCard Component
	One objective in the Objectives frame list: tag, title, description, progress
	(or locked / claimed text), rewards, and the CLAIM / PIN buttons.

	Props:
		Objective    (table)    -- ObjectiveData entry
		Status       (string)   -- ObjectiveStatus value
		Current, Required (number)
		IsPinned     (boolean)
		LayoutOrder, ZIndex
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components
local FancyText = require(Components.Global.FancyText)
local StudBackground = require(Components.Global.StudBackground)
local ItemSlot = require(Components.Global.ItemSlot)
local ObjectiveButton = require(Components.Objectives.ObjectiveButton)
local ProgressBar = require(Components.Objectives.ProgressBar)
local ObjectiveStatus = require(Client.Modules.ObjectiveStatus)

local ObjectiveData = require(ReplicatedStorage.Shared.Data.ObjectiveData)
local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local function getStatusText(objective, status): string?
	if status == ObjectiveStatus.Claimed then
		return Config.ClaimedText
	elseif status == ObjectiveStatus.Locked then
		if objective.isMain then
			return Config.LockedMainText
		end
		local unlockObjective = ObjectiveData.GetObjective(objective.unlockAfter or "")
		return string.format(Config.LockedSideText, unlockObjective and unlockObjective.title or "?")
	end
	return nil
end

local function ObjectiveCard(props, hooks)
	local baseZIndex = props.ZIndex or 1
	local objective = props.Objective
	local status = props.Status
	local rewards = objective.rewards or {}

	local isComplete = status == ObjectiveStatus.Complete
	local isLocked = status == ObjectiveStatus.Locked
	local isClaimed = status == ObjectiveStatus.Claimed
	local canPin = not objective.isMain and (status == ObjectiveStatus.Active or isComplete)

	local onClaim = hooks.useCallback(function()
		Knit.GetController("ObjectiveController"):ClaimObjective(objective.id)
	end, { objective.id })

	local onTogglePin = hooks.useCallback(function()
		Knit.GetController("ObjectiveController"):TogglePin(objective.id)
	end, { objective.id })

	-- Rewards: dollars + item slots
	local rewardElements = {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = Config.RewardsRowPadding,
		}),
	}
	if rewards.Dollars and rewards.Dollars > 0 then
		rewardElements.Dollars = Roact.createElement(FancyText, {
			Text = "$" .. ObjectiveStatus.FormatNumber(rewards.Dollars),
			Size = Config.DollarRewardSize,
			TextColor3 = Config.DollarRewardColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
			ZIndex = baseZIndex + 4,
		})
	end
	for index, reward in ipairs(rewards.Items or {}) do
		rewardElements["Item_" .. index] = Roact.createElement(ItemSlot, {
			Image = Images[reward.itemName],
			ItemName = reward.itemName,
			Quantity = reward.quantity,
			Size = Config.RewardItemSize,
			LayoutOrder = index,
			ZIndex = baseZIndex + 4,
		})
	end

	-- Progress bar while in progress / ready, status text otherwise
	local statusText = getStatusText(objective, status)
	local required = math.max(props.Required or 1, 1)
	local progressElement
	if statusText then
		progressElement = Roact.createElement(FancyText, {
			Text = statusText,
			Size = Config.StatusTextSize,
			TextColor3 = isClaimed and Config.ClaimedTextColor or Config.LockedTextColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 4,
			ZIndex = baseZIndex + 12,
		})
	else
		progressElement = Roact.createElement(ProgressBar, {
			Progress = (props.Current or 0) / required,
			Text = ObjectiveStatus.FormatProgress(props.Current or 0, required),
			Size = Config.BarSize,
			LayoutOrder = 4,
			ZIndex = baseZIndex + 4,
		})
	end

	local dimTransparency = (isLocked and Config.LockedOverlayTransparency)
		or (isClaimed and Config.ClaimedOverlayTransparency)
		or nil

	return Roact.createElement("Frame", {
		Name = "ObjectiveCard_" .. objective.id,
		Size = Config.CardSize,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		ZIndex = baseZIndex,
	}, {
		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = Config.AspectRatio,
		}),

		CardBackground = Roact.createElement(StudBackground, {
			ZIndex = baseZIndex + 1,
			BackgroundColor = Config.CardStudBackgroundColor,
			ImageTransparency = Config.CardStudImageTransparency,
			CornerRadius = Config.CornerRadius,
			StrokeColor = isComplete and Config.CompleteStrokeColor or Config.CardStrokeColor,
			StrokeThickness = Config.CardStrokeThickness,
			StrokeTransparency = isComplete and Config.CompleteStrokeTransparency or Config.CardStrokeTransparency,
		}),

		Content = Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = baseZIndex + 2,
		}, {
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = Config.ContentPaddingHorizontal,
				PaddingRight = Config.ContentPaddingHorizontal,
				PaddingTop = Config.ContentPaddingVertical,
				PaddingBottom = Config.ContentPaddingVertical,
			}),

			Info = Roact.createElement("Frame", {
				Size = Config.InfoSize,
				BackgroundTransparency = 1,
				ZIndex = baseZIndex + 3,
			}, {
				UIListLayout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = Config.InfoListPadding,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				Tag = Roact.createElement(FancyText, {
					Text = objective.isMain and Config.MainTagText or Config.SideTagText,
					Size = Config.TagSize,
					TextColor3 = objective.isMain and Config.MainTagColor or Config.SideTagColor,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
					ZIndex = baseZIndex + 4,
				}),

				Title = Roact.createElement(FancyText, {
					Text = objective.title,
					Size = Config.TitleSize,
					TextColor3 = Config.TitleColor,
					StrokeColor = Config.TitleStrokeColor,
					StrokeThickness = Config.TitleStrokeThickness,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 2,
					ZIndex = baseZIndex + 4,
				}),

				Description = Roact.createElement("TextLabel", {
					Text = objective.description or "",
					Size = Config.DescriptionSize,
					BackgroundTransparency = 1,
					TextColor3 = Config.DescriptionColor,
					TextScaled = true,
					TextWrapped = true,
					FontFace = Config.DescriptionFont,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 3,
					ZIndex = baseZIndex + 4,
				}),

				Progress = progressElement,
			}),

			Side = Roact.createElement("Frame", {
				Size = Config.SideSize,
				Position = Config.SidePosition,
				AnchorPoint = Config.SideAnchorPoint,
				BackgroundTransparency = 1,
				ZIndex = baseZIndex + 3,
			}, {
				UIListLayout = Roact.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = Config.SideListPadding,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				RewardsLabel = Roact.createElement(FancyText, {
					Text = Config.RewardsLabelText,
					Size = Config.RewardsLabelSize,
					TextColor3 = Config.RewardsLabelColor,
					TextXAlignment = Enum.TextXAlignment.Left,
					StrokeTransparency = 1,
					LayoutOrder = 1,
					ZIndex = baseZIndex + 4,
				}),

				Rewards = Roact.createElement("Frame", {
					Size = Config.RewardsRowSize,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					ZIndex = baseZIndex + 4,
				}, rewardElements),

				Buttons = (isComplete or canPin) and Roact.createElement("Frame", {
					Size = Config.ButtonRowSize,
					BackgroundTransparency = 1,
					LayoutOrder = 3,
					ZIndex = baseZIndex + 4,
				}, {
					UIListLayout = Roact.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = Config.ButtonRowPadding,
					}),

					Claim = isComplete and Roact.createElement(ObjectiveButton, {
						Text = Config.ClaimText,
						Variant = "Claim",
						Size = Config.ButtonSize,
						LayoutOrder = 1,
						OnClick = onClaim,
						ZIndex = baseZIndex + 5,
					}) or nil,

					Pin = canPin and Roact.createElement(ObjectiveButton, {
						Text = props.IsPinned and Config.UnpinText or Config.PinText,
						Variant = props.IsPinned and "Unpin" or "Pin",
						Size = Config.ButtonSize,
						LayoutOrder = 2,
						OnClick = onTogglePin,
						ZIndex = baseZIndex + 5,
					}) or nil,
				}) or nil,
			}),
		}),

		DimOverlay = dimTransparency and Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Config.DimOverlayColor,
			BackgroundTransparency = dimTransparency,
			ZIndex = baseZIndex + 10,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.CornerRadius,
			}),
		}) or nil,
	})
end

ObjectiveCard = RoactHooks.new(Roact)(ObjectiveCard)
return ObjectiveCard
