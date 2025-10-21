--|| Services ||--
local RunService = game:GetService("RunService")

--|| Constants ||--
local SRC = script.src

--|| Runtime Environment Check ||--
if RunService:IsServer() then
	if not SRC:FindFirstChild("server") then
		error("[" .. script.Name .. "] Service for this module not found.")
	end

	return require(SRC.server.Services.Service)
elseif RunService:IsClient() then
	if not SRC:FindFirstChild("client") then
		error("[" .. script.Name .. "] Controller for this module not found.")
	end

	return require(SRC.client)
else
	error("[" .. script.Name .. "] Invalid Run Environment.")
	return nil
end
