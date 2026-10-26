local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ZoneController = Knit.CreateController({ Name = "ZoneController" })

local player = Players.LocalPlayer

function ZoneController:KnitInit() end

function ZoneController:KnitStart()
	local ZoneService = Knit.GetService("ZoneService")

	ZoneService.PlayerTeleported:Connect(function()
		local character = player.Character
		if not character then return end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return end

		local camera = workspace.CurrentCamera
		if camera.CameraType ~= Enum.CameraType.Custom then return end

		-- Small delay to ensure character rotation is applied first
		task.wait(0.05)

		-- Get the character's new facing direction and position
		local hrpCFrame = humanoidRootPart.CFrame
		local lookVector = hrpCFrame.LookVector
		local position = hrpCFrame.Position

		-- Calculate camera position behind and above the character
		local cameraOffset = Vector3.new(0, 2, 0) -- Height offset
		local cameraDistance = 12 -- Distance behind character
		local cameraPos = position + cameraOffset - (lookVector * cameraDistance)

		-- Create a CFrame looking at the character with downward tilt
		local lookAtPos = position + Vector3.new(0, 1, 0) -- Look slightly above character's feet
		local cameraCFrame = CFrame.lookAt(cameraPos, lookAtPos)

		-- Apply downward tilt
		cameraCFrame = cameraCFrame * CFrame.Angles(math.rad(-25), 0, 0)

		camera.CFrame = cameraCFrame
	end)
end

return ZoneController
