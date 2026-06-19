local DayNightConfig = {
	DAY_DURATION = 14 * 60,   -- 840 seconds: clock locked at DAY_CLOCK
	NIGHT_DURATION = 7 * 60,  -- 420 seconds: clock transitions from DAY_CLOCK to DAWN_CLOCK

	DAY_CLOCK = 14,   -- 2:00 PM (held all day)
	DAWN_CLOCK = 5,   -- 5:00 AM (reached at end of night transition)
}

return DayNightConfig
