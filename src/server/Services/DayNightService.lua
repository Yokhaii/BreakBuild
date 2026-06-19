-- Knit
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

-- Services
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- Config
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DayNightConfig = require(ReplicatedStorage.Shared.Config.DayNightConfig)

local DAY_DURATION = DayNightConfig.DAY_DURATION
local NIGHT_DURATION = DayNightConfig.NIGHT_DURATION
local DAY_CLOCK = DayNightConfig.DAY_CLOCK
local DAWN_CLOCK = DayNightConfig.DAWN_CLOCK

local CYCLE_DURATION = DAY_DURATION + NIGHT_DURATION

-- Night wraps past midnight: 14 → 29 (5 AM next day) so we can lerp without jumping
local NIGHT_END_CLOCK = DAWN_CLOCK + 24

local DayNightService = Knit.CreateService({
	Name = "DayNightService",
	Client = {},
})

local function cycleTimeToClockTime(cycleTime: number): number
	if cycleTime < DAY_DURATION then
		return DAY_CLOCK
	else
		local t = (cycleTime - DAY_DURATION) / NIGHT_DURATION
		return (DAY_CLOCK + t * (NIGHT_END_CLOCK - DAY_CLOCK)) % 24
	end
end

--|| Knit Lifecycle ||--

function DayNightService:KnitInit()
end

function DayNightService:KnitStart()
	local cycleTime = 0

	RunService.Heartbeat:Connect(function(delta)
		cycleTime = (cycleTime + delta) % CYCLE_DURATION

		Lighting.ClockTime = cycleTimeToClockTime(cycleTime)
	end)
end

return DayNightService
