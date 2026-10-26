local initialState = {
	IsActive = false,
}

local function BiomeTransitionReducer(state, action)
	state = state or initialState

	if action.type == "BiomeTransition_Show" then
		return {
			IsActive = true,
		}
	elseif action.type == "BiomeTransition_Hide" then
		return {
			IsActive = false,
		}
	end

	return state
end

return BiomeTransitionReducer
