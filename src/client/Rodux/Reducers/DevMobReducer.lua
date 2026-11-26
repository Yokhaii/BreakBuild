local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local defaultState = {
	Total = 0, -- Live mobs
	Frozen = 0, -- Mobs not enabled yet (Immobile)
	DevSpawned = 0, -- Mobs spawned from the dev panel
	ByType = {}, -- [mobType] = count
	NaturalSpawning = false, -- MobSpawnService on / off
}

local DevMobReducer = Rodux.createReducer(defaultState, {
	setDevMobState = function(_state, action)
		local state = action.state
		return {
			Total = state.Total or 0,
			Frozen = state.Frozen or 0,
			DevSpawned = state.DevSpawned or 0,
			ByType = state.ByType or {},
			NaturalSpawning = state.NaturalSpawning == true,
		}
	end,
})

return DevMobReducer
