--[=[
	Client Workbench Blueprint Class
	Specific implementation for Workbench blueprint on client
]=]

local ClientBaseBlueprint = require(script.Parent.BaseBlueprint)

local Workbench = {}
Workbench.__index = Workbench
setmetatable(Workbench, { __index = ClientBaseBlueprint })

function Workbench.new(data)
	local self = ClientBaseBlueprint.new(data)
	setmetatable(self, Workbench)

	-- Workbench-specific client properties
	self.InteractionPrompt = nil -- ProximityPrompt for interaction

	return self
end

-- Show interaction prompt when workbench is complete
function Workbench:ShowInteractionPrompt()
	if not self.Model or not self:IsComplete() then return end

	-- Remove existing prompt
	self:HideInteractionPrompt()

	-- Find primary part or first part
	local targetPart = self.Model.PrimaryPart or self.Model:FindFirstChildWhichIsA("BasePart")
	if not targetPart then return end

	-- Create proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WorkbenchPrompt"
	prompt.ActionText = "Use"
	prompt.ObjectText = "Workbench"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = targetPart

	prompt.Triggered:Connect(function(player)
		self:_OnInteract(player)
	end)

	self.InteractionPrompt = prompt
end

-- Hide interaction prompt
function Workbench:HideInteractionPrompt()
	if self.InteractionPrompt then
		self.InteractionPrompt:Destroy()
		self.InteractionPrompt = nil
	end
end

-- Handle interaction
function Workbench:_OnInteract(player)
	print("[Workbench] Player", player.Name, "interacted with workbench")
	-- TODO: Open crafting UI
end

-- Override Destroy
function Workbench:Destroy()
	self:HideInteractionPrompt()
	ClientBaseBlueprint.Destroy(self)
end

return Workbench
