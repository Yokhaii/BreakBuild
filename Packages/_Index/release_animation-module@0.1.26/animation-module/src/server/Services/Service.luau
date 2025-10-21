local ReplicatedStorage = game:GetService("ReplicatedStorage")

--|| Imports ||--
local ImportFolder = ReplicatedStorage:FindFirstChild("Packages")

local src = script
while src and src.Name ~= "src" do
	src = src:FindFirstAncestorWhichIsA("Folder")
end

local function importPackage(name: string)
	local RootFolder = src and src:FindFirstAncestorWhichIsA("Folder") or nil

	return RootFolder and require(RootFolder[name]) or require(ImportFolder:FindFirstChild(name))
end

local Knit = importPackage("knit")

local AnimationServ = Knit.CreateService({
	Name = "AnimationServ",
	Client = {
		PlayAnimSignal = Knit.CreateSignal(),
	},
})

function AnimationServ.Client:PlayAnimation(_, animationName, characterName, cameraReplication)
	-- This function will be called by the client
	AnimationServ:PlayAnimationForAll(animationName, characterName, cameraReplication)
end

function AnimationServ:PlayAnimationForAll(animationName, characterName, cameraReplication)
	-- This function plays the animation for all clients
	self.Client.PlayAnimSignal:FireAll(animationName, characterName, cameraReplication)
end

function AnimationServ:KnitStart()
	-- Any initialization logic
end

return AnimationServ
