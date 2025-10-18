local Players = game:GetService("Players")

return function(callback: (Player) -> nil)
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(callback, player)
	end

	return Players.PlayerAdded:Connect(callback)
end
