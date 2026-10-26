local BiomeTransitionActions = {}

function BiomeTransitionActions.showTransition()
	return {
		type = "BiomeTransition_Show",
	}
end

function BiomeTransitionActions.hideTransition()
	return {
		type = "BiomeTransition_Hide",
	}
end

return BiomeTransitionActions
