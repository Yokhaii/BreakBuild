return function(scriptName, message, status)
	if status ~= "message" and status ~= "warning" and status ~= "error" then
		status = "message"
	end

	if status == "message" then
		print("[" .. scriptName .. "] - " .. message)
	elseif status == "warning" then
		warn("[" .. scriptName .. "] - " .. message)
	elseif status == "error" then
		error("[" .. scriptName .. "] - " .. message)
	end
end
