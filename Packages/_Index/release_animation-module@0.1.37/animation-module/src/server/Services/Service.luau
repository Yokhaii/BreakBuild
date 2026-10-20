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

local AnimationDataFolder = ReplicatedStorage.Shared.AnimationDataFolder
local MoonAnimationDataFolder = ReplicatedStorage.Shared.MoonAnimationDataFolder

local AnimationServ = Knit.CreateService({
	Name = "AnimationServ",
	Client = {
		PlayAnimSignal = Knit.CreateSignal(),
		PlayMoonBehaviorsSignal = Knit.CreateSignal(),
		StopAnimSignal = Knit.CreateSignal(),
	},
})

-- Weak outer keys so cache entries are collected when the model is GC'd.
-- Shape: { [model] = { [animationName] = AnimationTrack } }
local ServerAnimCache: { [Model]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

function AnimationServ.Client:PlayAnimation(_, animationName, characterName, cameraReplication)
	AnimationServ:PlayAnimationForAll(animationName, characterName, cameraReplication)
end

function AnimationServ:PlayAnimationForAll(animationName, characterName, cameraReplication)
	self.Client.PlayAnimSignal:FireAll(animationName, characterName, cameraReplication)
end

local function findAnimationData(animationName: string)
	local function searchFolder(folder)
		local found = folder:FindFirstChild(animationName)
		if found then return found end
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Folder") then
				local result = searchFolder(child)
				if result then return result end
			end
		end
		return nil
	end

	local moonModule = searchFolder(MoonAnimationDataFolder)
	if moonModule then
		return "Moon", require(moonModule)
	end

	local basicModule = searchFolder(AnimationDataFolder)
	if basicModule then
		return "Basic", require(basicModule)
	end

	return nil, nil
end

local function getOrCreateAnimator(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		return animator
	end

	local controller = model:FindFirstChildOfClass("AnimationController")
	if controller then
		local animator = controller:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = controller
		end
		return animator
	end

	return nil
end

local function getOrCreateTrack(animator: Animator, animationData: { Id: string, Priority: string?, Loop: boolean?, FadeTime: number?, Weight: number?, Speed: number? }): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = animationData.Id
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority[animationData.Priority or "Action"]
	track.Looped = animationData.Loop or false
	animation:Destroy()
	return track
end

-- Preload an animation server-side so the asset is hot when PlayAnimOnServer is called.
-- Safe to call during mob spawn; yields until the asset is ready.
function AnimationServ:PreloadAnimOnServer(model: Model, animationName: string)
	local _, animationData = findAnimationData(animationName)
	if not animationData then
		warn("AnimationServ:PreloadAnimOnServer — animation not found:", animationName)
		return
	end

	local animator = getOrCreateAnimator(model)
	if not animator then
		warn("AnimationServ:PreloadAnimOnServer — no Animator on model:", model:GetFullName())
		return
	end

	if not ServerAnimCache[model] then
		ServerAnimCache[model] = {}
		-- Evict on destroy so the weak key doesn't linger in the inner table.
		model.Destroying:Connect(function()
			ServerAnimCache[model] = nil
		end)
	end

	if ServerAnimCache[model][animationName] then
		return -- already cached
	end

	local track = getOrCreateTrack(animator, animationData)
	ServerAnimCache[model][animationName] = track
end

-- Play an animation server-side so Roblox replicates the track to all clients.
-- For Moon animations, also signals clients to run the behavior layer synced
-- against the replicated track's TimePosition.
function AnimationServ:PlayAnimOnServer(model: Model, animationName: string, cameraReplication: boolean?, fadeTime: number?): AnimationTrack?
	local animationType, animationData = findAnimationData(animationName)
	if not animationType or not animationData then
		warn("AnimationServ:PlayAnimOnServer — animation not found:", animationName)
		return nil
	end

	local animator = getOrCreateAnimator(model)
	if not animator then
		warn("AnimationServ:PlayAnimOnServer — no Animator on model:", model:GetFullName())
		return nil
	end

	-- Reuse the preloaded track when available; fall back to a fresh load.
	local track: AnimationTrack
	if ServerAnimCache[model] and ServerAnimCache[model][animationName] then
		track = ServerAnimCache[model][animationName]
	else
		track = getOrCreateTrack(animator, animationData)
	end

	track:Play(fadeTime or animationData.FadeTime or 0, animationData.Weight or 1, animationData.Speed or 1)

	if animationType == "Moon" then
		self.Client.PlayMoonBehaviorsSignal:FireAll(animationName, model, cameraReplication)
	end

	return track
end

function AnimationServ:StopAnimOnServer(model: Model, animationName: string, fadeTime: number?)
	local _, animationData = findAnimationData(animationName)
	if not animationData then
		warn("AnimationServ:StopAnimOnServer — animation not found:", animationName)
		return
	end

	local animator = getOrCreateAnimator(model)
	if not animator then return end

	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Animation and track.Animation.AnimationId == animationData.Id then
			track:Stop(fadeTime or 0)
		end
	end

	self.Client.StopAnimSignal:FireAll(animationName, model)
end

function AnimationServ:KnitStart()
end

return AnimationServ
