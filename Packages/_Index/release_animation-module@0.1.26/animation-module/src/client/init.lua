--|| Services ||--
local Players = game:GetService("Players")
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
local NoRigAnimationDataFolder = ReplicatedStorage.Shared.NoRigAnimationDataFolder

local AnimationModule = require(script.Modules.AnimationModule)
local MoonAnimationModule = require(script.Modules.MoonAnimationModule)
local NoRigAnimationModule = require(script.Modules.NoRigAnimationModule)

-- Player
local player = Players.LocalPlayer

--|| Knit Services ||--
local AnimationService = nil

--|| Controller ||--
local AnimationCtrl = Knit.CreateController({
	Name = "AnimationCtrl",
	Animations = {},
	InstanceConnections = {}, -- Track connections to instance destruction events
})

-- Utility function to get a position from a part or position value
function AnimationCtrl:GetPositionFromSource(source)
	if typeof(source) == "CFrame" then
		return source
	elseif typeof(source) == "Vector3" then
		return CFrame.new(source)
	elseif typeof(source) == "Instance" and source:IsA("BasePart") then
		return source.CFrame
	elseif typeof(source) == "Instance" and source:IsA("Model") and source.PrimaryPart then
		return source.PrimaryPart.CFrame
	else
		warn("Invalid position source provided")
		return nil
	end
end

-- Determine the animation type from the name
function AnimationCtrl:GetAnimationType(AnimationName)
	local function findModuleRecursive(folder, name)
		local found = folder:FindFirstChild(name)
		if found then
			return found
		end

		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Folder") then
				local result = findModuleRecursive(child, name)
				if result then
					return result
				end
			end
		end
		return nil
	end

	local regularAnim = findModuleRecursive(AnimationDataFolder, AnimationName)
	local moonAnim = findModuleRecursive(MoonAnimationDataFolder, AnimationName)
	local noRigAnim = findModuleRecursive(NoRigAnimationDataFolder, AnimationName)
	
	local animationData, animationType
	
	if regularAnim then
		animationData = require(regularAnim)
		animationType = "Basic"
	elseif moonAnim then
		animationData = require(moonAnim)
		animationType = "Moon"
	elseif noRigAnim then
		animationData = require(noRigAnim)
		animationType = "NoRig"
	else
		return nil, nil
	end
	
	return animationType, animationData
end

function AnimationCtrl:GetAnimationKey(AnimationName, CharacterOrTarget)
    local animationType, _ = self:GetAnimationType(AnimationName)
    
    if not animationType then
        return nil
    end
    
    -- For NoRig animations
    if animationType == "NoRig" then
        -- For Instances, use full name for unique key
        if typeof(CharacterOrTarget) == "Instance" then
            return AnimationName .. "_norig_" .. CharacterOrTarget:GetFullName()
        else
            -- For CFrame or Vector3 (legacy support), use string representation
            return AnimationName .. "_norig_" .. tostring(CharacterOrTarget)
        end
    -- For Basic and Moon animations
    else
        if typeof(CharacterOrTarget) ~= "Instance" or not (CharacterOrTarget:IsA("Model")) then
            warn("Character is required for Basic and Moon animations")
            return nil
        end
        
        return AnimationName .. "_" .. CharacterOrTarget:GetFullName()
    end
end

-- NEW FUNCTION: Set up automatic cleanup when an instance is destroyed
function AnimationCtrl:SetupInstanceDestroyConnection(instance)
    -- Only set up connections for Instances
    if typeof(instance) ~= "Instance" then
        return
    end
    
    -- Check if we already have a connection for this instance
    if self.InstanceConnections[instance] then
        return
    end
    
    -- Create a new connection
    self.InstanceConnections[instance] = instance.Destroying:Connect(function()
        -- Clean up all animations related to this instance
        self:CleanupInstanceAnimations(instance)
        -- Remove the connection
        self.InstanceConnections[instance]:Disconnect()
        self.InstanceConnections[instance] = nil
    end)
end

-- NEW FUNCTION: Clean up all animations for a specific instance
function AnimationCtrl:CleanupInstanceAnimations(instance)
    if typeof(instance) ~= "Instance" then
        return
    end
    
    local instancePath = instance:GetFullName()
    local animationsToRemove = {}
    
    -- Find all animation keys that contain this instance's path
    for key, animation in pairs(self.Animations) do
        if key:find(instancePath, 1, true) then
            animation:stop()
            animation:destroy()
            table.insert(animationsToRemove, key)
        end
    end
    
    -- Remove the animations from the table
    for _, key in ipairs(animationsToRemove) do
        self.Animations[key] = nil
    end
    
    -- Log cleanup for debugging
    if #animationsToRemove > 0 then
        print("Cleaned up " .. #animationsToRemove .. " animations for " .. instancePath)
    end
end

function AnimationCtrl:GetOrCreateAnimation(AnimationName, CharacterOrTarget)
    local animationType, animationData = self:GetAnimationType(AnimationName)
    
    if not animationType or not animationData then
        warn("Animation data not found for: " .. AnimationName)
        return nil
    end
    
    local key = self:GetAnimationKey(AnimationName, CharacterOrTarget)
    if not key then
        return nil
    end
    
    if self.Animations[key] then
        return self.Animations[key]
    end
    
    local animation
    
    if animationType == "Basic" then
        animation = AnimationModule.new(animationData.Id, animationData, CharacterOrTarget)
    elseif animationType == "Moon" then
        animation = MoonAnimationModule.new(animationData.Id, animationData, CharacterOrTarget)
    elseif animationType == "NoRig" then
        -- Now directly pass the target to NoRigAnimationModule
        animation = NoRigAnimationModule.new(animationData.Id, animationData, CharacterOrTarget)
    else
        warn("Unknown animation type for animation: " .. AnimationName)
        return nil
    end
    
    -- Set up automatic cleanup if character/target is an Instance
    if typeof(CharacterOrTarget) == "Instance" then
        self:SetupInstanceDestroyConnection(CharacterOrTarget)
    end
    
    animation:preload()
    self.Animations[key] = animation
    return animation
end

function AnimationCtrl:GetAnimation(AnimationName, CharacterOrPosition)
	local key = self:GetAnimationKey(AnimationName, CharacterOrPosition)
	if not key then
		return nil
	end
	
	return self.Animations[key]
end

function AnimationCtrl:PlayAnim(AnimationName, CharacterOrPosition)
	-- Handle nil CharacterOrPosition for Basic/Moon animations
	local animationType, _ = self:GetAnimationType(AnimationName)
	if not animationType then
		warn("Animation not found: " .. AnimationName)
		return nil
	end
	
	if not CharacterOrPosition and animationType ~= "NoRig" then
		CharacterOrPosition = player.Character
	end
	
	local animation = self:GetOrCreateAnimation(AnimationName, CharacterOrPosition)
	if animation then
		animation:play()
	end
	return animation
end

function AnimationCtrl:StopAnim(AnimationName, CharacterOrPosition)
	local animation = self:GetAnimation(AnimationName, CharacterOrPosition)
	if animation then
		animation:stop()
	end
	return animation
end

function AnimationCtrl:PlayAndDestroyAnimation(AnimationName, CharacterOrPosition)
	local animation = self:GetOrCreateAnimation(AnimationName, CharacterOrPosition)
	if animation then
		animation:play()

		-- If it's a NoRig animation, use the "finished" Signal
		if animation.animationData.AnimationType == "NoRig" then
			animation.finished:Connect(function()
				task.wait(0.5) -- Small delay to ensure any end-of-animation logic completes
				self:DestroyAnimation(AnimationName, CharacterOrPosition)
			end)
		else
			-- For other animation types, rely on the animationTrack
			animation.animationTrack.Stopped:Connect(function()
				task.wait(0.5) -- Small delay to ensure any end-of-animation logic completes
				self:DestroyAnimation(AnimationName, CharacterOrPosition)
			end)
		end
	end
	return animation
end

function AnimationCtrl:PlayNoRigAnimAtTarget(AnimationName, Target)
    if not Target then
        warn("Target is required for PlayNoRigAnimAtTarget")
        return nil
    end
    
    -- Directly use the target without conversion
    return self:PlayAnim(AnimationName, Target)
end

function AnimationCtrl:PlayNoRigAnimAtPosition(AnimationName, Position)
    if not Position then
        warn("Position is required for PlayNoRigAnimAtPosition")
        return nil
    end
    
    -- For backward compatibility
    return self:PlayNoRigAnimAtTarget(AnimationName, Position)
end

function AnimationCtrl:PreloadAnimation(AnimationName, CharacterOrPosition)
	local animationType, _ = self:GetAnimationType(AnimationName)
	if not animationType then
		warn("Animation not found: " .. AnimationName)
		return nil
	end
	
	if not CharacterOrPosition and animationType ~= "NoRig" then
		CharacterOrPosition = player.Character
		if not CharacterOrPosition then
			warn("The Character you're trying to load an animation on is nil")
			return nil
		end
	end

	return self:GetOrCreateAnimation(AnimationName, CharacterOrPosition)
end

function AnimationCtrl:DestroyAnimation(AnimationName, CharacterOrPosition)
	local animation = self:GetAnimation(AnimationName, CharacterOrPosition)
	if animation then
		animation:destroy()
		
		local key = self:GetAnimationKey(AnimationName, CharacterOrPosition)
		if key then
			self.Animations[key] = nil
		end
	end
end

function AnimationCtrl:CleanupPlayerAnimations(playerDis)
	for key, animation in pairs(self.Animations) do
		if key:find(playerDis.Name) then
			animation:destroy()
			self.Animations[key] = nil
		end
	end
end

function AnimationCtrl:PlayerServerAnimOnSelf(AnimationName, cameraReplication)
	return self:PlayServerAnim(AnimationName, player.Character, cameraReplication)
end

function AnimationCtrl:PlayServerAnim(AnimationName, CharacterOrPosition, cameraReplication)
	self:PlayAnim(AnimationName, CharacterOrPosition)
	return AnimationService:PlayAnimation(AnimationName, CharacterOrPosition, cameraReplication)
end

function AnimationCtrl:PlayOnlyItemsMoonAnim(AnimationName, CharacterOrPosition, cameraReplication)
	local animation = self:GetOrCreateAnimation(AnimationName, CharacterOrPosition)
	if animation and animation.animationData then
		if animation.animationData.AnimationType == "Moon" then
			animation:playOnlyItems(cameraReplication)
		elseif animation.animationData.AnimationType == "NoRig" then
			-- For NoRig animations, just play them normally since they already focus on items
			animation:play()
		end
	end
end

function AnimationCtrl:PlayRequestedAnimFromServ(AnimationName, CharacterOrTarget, cameraReplication)
    local animationType, animationData = self:GetAnimationType(AnimationName)
    
    if not animationType or not animationData then
        warn("Animation data not found for: " .. AnimationName)
        return
    end
    
    if animationType == "NoRig" then
        -- For NoRig, we just need a target (can be any instance, CFrame, or Vector3)
        if CharacterOrTarget then
            self:PlayAnim(AnimationName, CharacterOrTarget)
        else
            warn("Target is required for NoRig animations")
        end
    else
        -- For Basic and Moon, we need a character
        if typeof(CharacterOrTarget) == "Instance" and CharacterOrTarget:IsA("Model") then
            local playerForAnim = Players:GetPlayerFromCharacter(CharacterOrTarget)
            
            if playerForAnim then
                if animationType == "Basic" then
                    return
                elseif playerForAnim ~= player then
                    self:PlayOnlyItemsMoonAnim(AnimationName, CharacterOrTarget, cameraReplication)
                else
                    self:PlayAnim(AnimationName, CharacterOrTarget)
                end
            else
                self:PlayAnim(AnimationName, CharacterOrTarget)
            end
        else
            warn("Character is required for Basic and Moon animations")
        end
    end
end

-- NEW FUNCTION: Clean up all instance connections when the controller is being destroyed
function AnimationCtrl:CleanupAllConnections()
    for instance, connection in pairs(self.InstanceConnections) do
        if connection and typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    self.InstanceConnections = {}
end

--|| Knit Lifecycle ||--
function AnimationCtrl:KnitInit()
	AnimationService = Knit.GetService("AnimationServ")

	AnimationService.PlayAnimSignal:Connect(function(animationName, CharacterOrPosition, cameraReplication)
		self:PlayRequestedAnimFromServ(animationName, CharacterOrPosition, cameraReplication)
	end)

	Players.PlayerRemoving:Connect(function(playerDis)
		self:CleanupPlayerAnimations(playerDis)
	end)
end

-- NEW: Clean up when the controller is being destroyed (if applicable in your framework)
function AnimationCtrl:KnitStop()
    self:CleanupAllConnections()
    
    -- Clean up all animations
    for key, animation in pairs(self.Animations) do
        if animation then
            animation:destroy()
        end
    end
    self.Animations = {}
end

return AnimationCtrl