local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ClientBaseBlueprint = require(script.Parent.BaseBlueprint)

-- Passive structure: the billboard shows the nest capacity (stored/maxStored) and the next trip timer.
-- Clicking the completed nest collects the loot (PassiveBlueprintService)
local BirdNest = {}
BirdNest.__index = BirdNest
setmetatable(BirdNest, { __index = ClientBaseBlueprint })

local REFRESH_INTERVAL = 0.25
local ERROR_COLOR = Color3.fromRGB(255, 80, 80)

local function formatTime(secs: number): string
	secs = math.ceil(secs)
	local mins = math.floor(secs / 60)
	local displaySecs = secs % 60
	return mins > 0 and string.format("%d:%02d", mins, displaySecs) or string.format("%ds", displaySecs)
end

function BirdNest.new(data)
	local self = ClientBaseBlueprint.new(data)
	setmetatable(self, BirdNest)
	self._PassiveState = nil -- { stored, maxStored, interval, secsRemaining? }
	self._NextTripAt = nil -- os.clock() when the bird is back (nil = nest full)
	self._RefreshThread = nil
	return self
end

function BirdNest:SetModel(model: Model)
	ClientBaseBlueprint.SetModel(self, model)

	Knit.GetService("PassiveBlueprintService"):GetState(self.Id):andThen(function(state)
		if state then
			self:SetPassiveState(state)
		end
	end)
end

function BirdNest:SetPassiveState(state)
	self._PassiveState = state
	self._NextTripAt = state.secsRemaining and os.clock() + state.secsRemaining or nil
	self:_RefreshBillboard()

	if not self._RefreshThread then
		self._RefreshThread = task.spawn(function()
			while self._PassiveState do
				task.wait(REFRESH_INTERVAL)
				self:_RefreshBillboard()
			end
		end)
	end
end

function BirdNest:_RefreshBillboard()
	local state = self._PassiveState
	if not state then return end

	local secsRemaining = self._NextTripAt and math.max(0, self._NextTripAt - os.clock())
	local progress = secsRemaining and 1 - secsRemaining / state.interval or 1
	self:ShowCraftingProgress(progress)

	local label = self._CraftingTimeLabel
	if not label then return end

	-- Nest capacity (trips waiting / maxStored) + time until the bird is back
	local timeText = secsRemaining and formatTime(secsRemaining) or "Full"
	label.Text = string.format("%d/%d · %s", state.stored, state.maxStored, timeText)
end

function BirdNest:_OnInteract(player)
	local TextNotificationController = Knit.GetController("TextNotificationController")

	Knit.GetService("PassiveBlueprintService"):Collect(self.Id):andThen(function(collected, remaining)
		if remaining > 0 then
			TextNotificationController:Show("Inventory full!", ERROR_COLOR)
		elseif collected == 0 then
			TextNotificationController:Show("The bird hasn't brought anything back yet")
		end
	end)
end

function BirdNest:Destroy()
	self._PassiveState = nil
	self._RefreshThread = nil
	ClientBaseBlueprint.Destroy(self)
end

return BirdNest
