local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local DistanceFade = require(script.Parent.Parent.Modules.DistanceFade)
local DistanceFadeConfig = require(ReplicatedStorage.Shared.Config.DistanceFadeConfig)

local DistanceFadeController = Knit.CreateController({
	Name = "DistanceFadeController",
})

--[[
	Active effects registry.
	Key = unique string ID chosen by the caller.
	Value = {
		instance: DistanceFade object,
		connection: RBXScriptConnection (Heartbeat),
		targetPart: BasePart (the part the effect tracks position from, or nil for default HumanoidRootPart),
	}
]]
local activeEffects = {}

-- Resolve a preset name or settings table into a full settings table
local function resolveSettings(presetOrSettings)
	if type(presetOrSettings) == "string" then
		local preset = DistanceFadeConfig.Presets[presetOrSettings]
		assert(preset, "DistanceFadeConfig preset not found: " .. presetOrSettings)
		return preset
	elseif type(presetOrSettings) == "table" then
		return presetOrSettings
	end
	return nil
end

--[[
	Apply a DistanceFade effect to a part's faces.

	Parameters:
		id: string — unique identifier for this effect (used to stop it later)
		part: BasePart — the part to apply the surface effect onto
		faces: {Enum.NormalId} — which faces to apply the effect to
		presetOrSettings: string | table — preset name from DistanceFadeConfig, or a custom settings table
		options: table? — optional extra config:
			trackPart: BasePart? — the part whose position drives the distance calculation
			                       (defaults to LocalPlayer's HumanoidRootPart)

	Returns: string (the id)
]]
function DistanceFadeController:Apply(id, part, faces, presetOrSettings, options)
	assert(id, "DistanceFadeController:Apply requires an id")
	assert(part and part:IsA("BasePart"), "DistanceFadeController:Apply requires a BasePart")
	assert(faces and #faces > 0, "DistanceFadeController:Apply requires at least one face")

	if activeEffects[id] then
		self:Stop(id)
	end

	local settings = resolveSettings(presetOrSettings)
	local trackPart = options and options.trackPart or nil

	local instance = DistanceFade.new()
	if settings then
		instance:UpdateSettings(settings)
	end

	for _, face in ipairs(faces) do
		instance:AddFace(part, face)
	end

	local effectEntry = {
		instance = instance,
		connection = nil,
		trackPart = trackPart,
		part = part,
	}

	effectEntry.connection = RunService.Heartbeat:Connect(function()
		local pos = nil
		if effectEntry.trackPart then
			pos = effectEntry.trackPart.Position
		end
		instance:Step(pos)
	end)

	activeEffects[id] = effectEntry

	return id
end

--[[
	Stop and clean up a DistanceFade effect by its id.
]]
function DistanceFadeController:Stop(id)
	local effect = activeEffects[id]
	if not effect then
		return
	end

	effect.connection:Disconnect()
	effect.instance:Clear()
	activeEffects[id] = nil
end

--[[
	Check if an effect with the given id is currently active.
]]
function DistanceFadeController:IsActive(id)
	return activeEffects[id] ~= nil
end

--[[
	Update the settings of an active effect.
	presetOrSettings: string (preset name) or table (custom settings)
]]
function DistanceFadeController:UpdateSettings(id, presetOrSettings)
	local effect = activeEffects[id]
	if not effect then
		return
	end

	local settings = resolveSettings(presetOrSettings)
	if settings then
		effect.instance:UpdateSettings(settings)
	end
end

--[[
	Change which part the effect tracks for distance calculations.
	Pass nil to revert to default (LocalPlayer HumanoidRootPart).
]]
function DistanceFadeController:SetTrackPart(id, trackPart)
	local effect = activeEffects[id]
	if not effect then
		return
	end
	effect.trackPart = trackPart
end

--[[
	Stop all active effects.
]]
function DistanceFadeController:StopAll()
	for id in pairs(activeEffects) do
		self:Stop(id)
	end
end

function DistanceFadeController:KnitStart()
end

return DistanceFadeController
