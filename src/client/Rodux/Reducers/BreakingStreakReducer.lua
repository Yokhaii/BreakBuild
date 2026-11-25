local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

-- Breaking streak, owned by BreakingService (Step 0 = warming up or no streak)
local defaultState = {
	Step = 0,
	Blocks = 0, -- Blocks broken in a row
	Bonus = 0, -- Break time reduction (0.1 = 10% faster)
	IsIdle = false, -- Not breaking: the reset countdown is running
}

local BreakingStreakReducer = Rodux.createReducer(defaultState, {
	setBreakingStreak = function(_, action)
		return {
			Step = action.step,
			Blocks = action.blocks,
			Bonus = action.bonus,
			IsIdle = action.isIdle == true,
		}
	end,
})

return BreakingStreakReducer
