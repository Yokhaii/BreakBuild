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

	-- Debug: Show loaded data
	print("[Workbench] ========== WORKBENCH CREATED ==========")
	print("[Workbench] Blueprint ID:", self.Id)
	print("[Workbench] CompletedAt:", self.CompletedAt)

	-- Count filled blocks
	local filledCount = 0
	for key, blockData in pairs(self.FilledBlocks) do
		filledCount = filledCount + 1
		print("[Workbench] Filled block:", key, "->", blockData.blockType)
	end
	print("[Workbench] Total filled blocks:", filledCount)

	local requiredCount = self.Definition and #self.Definition.blocks or 0
	print("[Workbench] Required blocks:", requiredCount)

	-- Check if blueprint was already completed when loaded from saved data
	if self.CompletedAt > 0 then
		print("[Workbench] CompletedAt > 0, blueprint was marked as completed")
		self:_OnWorkbenchCompleted()
	else
		-- Also check if it should be complete (all blocks filled correctly)
		local isActuallyComplete = self:IsComplete()
		print("[Workbench] IsComplete() check:", isActuallyComplete)
		if isActuallyComplete then
			print("[Workbench] Blueprint is complete but CompletedAt was 0, fixing...")
			self.CompletedAt = os.time()
			self:_OnWorkbenchCompleted()
		end
	end
	print("[Workbench] ========================================")

	return self
end

-- Called when workbench is completed
function Workbench:_OnWorkbenchCompleted()
	self.IsActive = true
	print("[Workbench] ************************************")
	print("[Workbench] * WORKBENCH COMPLETED AND ACTIVE! *")
	print("[Workbench] ************************************")
	print("[Workbench] Blueprint ID:", self.Id)
	print("[Workbench] IsActive:", self.IsActive)
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
