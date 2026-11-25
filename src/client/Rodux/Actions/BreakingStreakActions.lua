local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local BreakingStreakActions = {}

BreakingStreakActions.setBreakingStreak = Rodux.makeActionCreator("setBreakingStreak", function(step, blocks, bonus, isIdle)
	return {
		step = step,
		blocks = blocks,
		bonus = bonus,
		isIdle = isIdle,
	}
end)

return BreakingStreakActions
