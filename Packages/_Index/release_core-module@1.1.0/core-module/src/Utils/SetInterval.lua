return function(Callback: (any) -> any, Time: number, ...: any): thread
	local args = { ... }
	return task.spawn(function()
		while task.wait(Time) do
			task.spawn(Callback, unpack(args))
		end
	end)
end
