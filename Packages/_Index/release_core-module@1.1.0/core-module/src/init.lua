local Utils = require(script.Utils)

local Class = {
	Action = require(script.Class.Action),
	NPC = require(script.Class.NPC),
	Pet = require(script.Class.Pet),
}

local ErrorCodes = {
	MISSING_PARAMS = "MISSING_PARAMS",
	ALREADY_EXISTS = "ALREADY_EXISTS",
	NOT_FOUND = "NOT_FOUND",
	COOLDOWN = "COOLDOWN",
	NO_CALLBACK = "NO_CALLBACK",
	CONFIG_ERROR = "CONFIG_ERROR",
	CANT_NOW = "CANT_NOW",
	INTERNAL = "INTERNAL",
}

return { Utils = Utils, Class = Class, ErrorCodes = ErrorCodes }
