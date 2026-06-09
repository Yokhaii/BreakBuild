--[=[
	Server Workbench Blueprint Class
	Specific implementation for Workbench blueprint
]=]

local ServerBaseBlueprint = require(script.Parent.BaseBlueprint)

local Workbench = {}
Workbench.__index = Workbench
setmetatable(Workbench, { __index = ServerBaseBlueprint })

function Workbench.new(data)
	local self = ServerBaseBlueprint.new(data)
	setmetatable(self, Workbench)

	-- Workbench-specific properties
	self.IsActive = false -- Whether the workbench is usable

	-- Connect completion event for future completions
	self.OnCompleted:Connect(function()
		self:_OnWorkbenchCompleted()
	end)

	-- Check if blueprint was already completed when loaded from saved data
	if self.CompletedAt > 0 then
		self:_OnWorkbenchCompleted()
	elseif self:IsComplete() then
		-- Fix CompletedAt if all blocks are filled but it wasn't marked
		self.CompletedAt = os.time()
		self:_OnWorkbenchCompleted()
	end

	return self
end

-- Called when workbench is completed
function Workbench:_OnWorkbenchCompleted()
	self.IsActive = true
	-- TODO: Enable crafting functionality
end

-- Check if player can use this workbench
function Workbench:CanPlayerUse(playerId: number): boolean
	if not self.IsActive then
		return false
	end

	-- For now, only owner can use
	-- TODO: Implement sharing/permissions
	return playerId == self.OwnerId
end

-- Override DestroyModel to handle workbench-specific cleanup
function Workbench:DestroyModel()
	self.IsActive = false
	ServerBaseBlueprint.DestroyModel(self)
end

return Workbench
