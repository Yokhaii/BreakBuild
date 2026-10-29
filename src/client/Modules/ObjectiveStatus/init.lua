--[=[
	ObjectiveStatus
	Derives the display status of objectives from ObjectiveReducer state.

	  ObjectiveStatus.Get(objectivesState, objective) -> status, current, required
	    status: "Locked" | "Active" | "Complete" (reward ready to claim) | "Claimed"
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectiveData = require(ReplicatedStorage.Shared.Data.ObjectiveData)
local Images = require(ReplicatedStorage.Shared.Data.Images)

local ObjectiveStatus = {}

ObjectiveStatus.Locked = "Locked"
ObjectiveStatus.Active = "Active"
ObjectiveStatus.Complete = "Complete"
ObjectiveStatus.Claimed = "Claimed"

function ObjectiveStatus.Get(objectivesState, objective): (string, number, number)
	local required = objective.goal.amount or 1

	if objectivesState.Claimed[objective.id] then
		return ObjectiveStatus.Claimed, required, required
	elseif objectivesState.Completed[objective.id] then
		return ObjectiveStatus.Complete, required, required
	end

	-- Only active objectives have progress (the current main one + unlocked side ones)
	local progress = objectivesState.Progress[objective.id]
	if not progress then
		return ObjectiveStatus.Locked, 0, required
	end
	return ObjectiveStatus.Active, progress.Current, progress.Required
end

-- True when at least one completed objective still has its reward to claim
function ObjectiveStatus.HasUnclaimed(objectivesState): boolean
	for objectiveId in pairs(objectivesState.Completed) do
		if not objectivesState.Claimed[objectiveId] then
			return true
		end
	end
	return false
end

-- The current main objective, or nil once the chain is finished (or not synced yet)
function ObjectiveStatus.GetCurrentMain(objectivesState)
	return ObjectiveData.Main[objectivesState.MainIndex]
end

function ObjectiveStatus.IsPinned(objectivesState, objectiveId: string): boolean
	return table.find(objectivesState.Pinned, objectiveId) ~= nil
end

-- 950 -> "950", 12500 -> "12.5K", 1000000 -> "1M"
function ObjectiveStatus.FormatNumber(value: number): string
	local suffixes = { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, entry in ipairs(suffixes) do
		if value >= entry[1] and value >= 10000 then
			local formatted = string.format("%.1f", value / entry[1]):gsub("%.0$", "")
			return formatted .. entry[2]
		end
	end
	return tostring(math.floor(value))
end

-- Short task text for the HUD ("Collect 4 Logs")
function ObjectiveStatus.GetTaskText(objective): string
	return objective.task or objective.title
end

-- Image of the item illustrating an objective, or nil (e.g. EarnDollars goals)
function ObjectiveStatus.GetIcon(objective): string?
	local goal = objective.goal
	local itemName = objective.icon or goal.itemName
	if not itemName and goal.blueprintType then
		itemName = goal.type == "CompleteBlueprint" and ("Completed" .. goal.blueprintType) or (goal.blueprintType .. "Blueprint")
	end
	return itemName and Images[itemName] or nil
end

-- "Craft Half Stone (12/24)" for goals that need more than one
function ObjectiveStatus.FormatProgress(current: number, required: number): string?
	if required <= 1 then return nil end
	return ObjectiveStatus.FormatNumber(current) .. "/" .. ObjectiveStatus.FormatNumber(required)
end

return ObjectiveStatus
