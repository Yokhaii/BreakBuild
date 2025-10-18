return function(player)
	return type(player) == "userdata" and typeof(player) == "Instance" and player.IsA and player:IsA("Player")
end
