-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Signal = require(game:GetService("ReplicatedStorage").Packages.Signal)

-- Services
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local CustomProximityPromptService = Knit.CreateService({
    Name = "ProximityPromptService",
    Client = {},
})

-- Types
type PromptConfig = {
    actionText: string?, -- Changed from 'text' to 'actionText'
    objectText: string?,
    holdDuration: number?,
    maxActivationDistance: number?,
    exclusivity: Enum.ProximityPromptExclusivity?,
    gamepadKeyCode: Enum.KeyCode?,
    keyboardKeyCode: Enum.KeyCode?,
    requiresLineOfSight: boolean?,
    autoLocalize: boolean?,
    clickablePrompt: boolean?,
    enabled: boolean?,
    style: Enum.ProximityPromptStyle?,
    -- Visual customization
    uiOffset: Vector2?,
    -- Custom properties
    promptId: string?, -- Custom identifier for the prompt
    cooldown: number?, -- Cooldown time in seconds
    playerWhitelist: {Player}?, -- Only these players can use the prompt
    playerBlacklist: {Player}?, -- These players cannot use the prompt
    usageLimit: number?, -- How many times this prompt can be used (nil = unlimited)
    resetOnPlayerLeaving: boolean? -- Reset usage count when player leaves
}

type PromptCallback = (player: Player, promptInstance: ProximityPrompt, promptData: PromptData) -> ()

type PromptData = {
    id: string,
    instance: ProximityPrompt,
    config: PromptConfig,
    callback: PromptCallback,
    parent: Instance,
    usageCount: number,
    lastUsedTime: number,
    playerUsageCount: {[Player]: number} -- Track usage per player
}

-- Private variables
local activePrompts: {[string]: PromptData} = {}
local promptIdCounter = 0

-- Signals
local PromptTriggered = Signal.new()
local PromptAdded = Signal.new()
local PromptRemoved = Signal.new()

-- Private Functions

-- Generate unique prompt ID
local function generatePromptId(): string
    promptIdCounter = promptIdCounter + 1
    return string.format("Prompt_%d_%d", promptIdCounter, tick())
end

-- Get the best part to attach the prompt to
local function getBestPartForPrompt(object: Instance): BasePart?
    if object:IsA("BasePart") then
        return object
    elseif object:IsA("Model") then
        -- Try to find PrimaryPart first
        if object.PrimaryPart then
            return object.PrimaryPart
        end

        -- Look for common part names
        local commonNames = {"Handle", "Main", "Core", "Base", "Root", "Center"}
        for _, name in ipairs(commonNames) do
            local part = object:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                return part
            end
        end

        -- Find any BasePart
        for _, child in ipairs(object:GetChildren()) do
            if child:IsA("BasePart") then
                return child
            end
        end

        -- Recursively search in descendants
        for _, descendant in ipairs(object:GetDescendants()) do
            if descendant:IsA("BasePart") then
                return descendant
            end
        end
    end

    return nil
end

-- Apply configuration to proximity prompt
local function applyPromptConfig(prompt: ProximityPrompt, config: PromptConfig)
    -- Basic properties
    if config.actionText then prompt.ActionText = config.actionText end
    if config.objectText then prompt.ObjectText = config.objectText end
    if config.holdDuration then prompt.HoldDuration = config.holdDuration end
    if config.maxActivationDistance then prompt.MaxActivationDistance = config.maxActivationDistance end
    if config.exclusivity then prompt.Exclusivity = config.exclusivity end
    if config.gamepadKeyCode then prompt.GamepadKeyCode = config.gamepadKeyCode end
    if config.keyboardKeyCode then prompt.KeyboardKeyCode = config.keyboardKeyCode end
    if config.requiresLineOfSight ~= nil then prompt.RequiresLineOfSight = config.requiresLineOfSight end
    if config.autoLocalize ~= nil then prompt.AutoLocalize = config.autoLocalize end
    if config.clickablePrompt ~= nil then prompt.ClickablePrompt = config.clickablePrompt end
    if config.enabled ~= nil then prompt.Enabled = config.enabled end
    if config.style then prompt.Style = config.style end
    if config.uiOffset then prompt.UIOffset = config.uiOffset end
end

-- Check if player can use the prompt
local function canPlayerUsePrompt(player: Player, promptData: PromptData): boolean
    local config = promptData.config

    -- Check whitelist
    if config.playerWhitelist then
        local inWhitelist = false
        for _, whitelistedPlayer in ipairs(config.playerWhitelist) do
            if whitelistedPlayer == player then
                inWhitelist = true
                break
            end
        end
        if not inWhitelist then
            return false
        end
    end

    -- Check blacklist
    if config.playerBlacklist then
        for _, blacklistedPlayer in ipairs(config.playerBlacklist) do
            if blacklistedPlayer == player then
                return false
            end
        end
    end

    -- Check cooldown
    if config.cooldown and config.cooldown > 0 then
        local timeSinceLastUse = tick() - promptData.lastUsedTime
        if timeSinceLastUse < config.cooldown then
            return false
        end
    end

    -- Check usage limit (global)
    if config.usageLimit and promptData.usageCount >= config.usageLimit then
        return false
    end

    return true
end

-- Handle prompt triggered
local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
    -- Find the prompt data
    local promptData = nil
    for _, data in pairs(activePrompts) do
        if data.instance == prompt then
            promptData = data
            break
        end
    end

    if not promptData then
        warn("Triggered prompt not found in active prompts!")
        return
    end

    -- Check if player can use the prompt
    if not canPlayerUsePrompt(player, promptData) then
        return
    end

    -- Update usage tracking
    promptData.usageCount = promptData.usageCount + 1
    promptData.lastUsedTime = tick()

    -- Track per-player usage
    if not promptData.playerUsageCount[player] then
        promptData.playerUsageCount[player] = 0
    end
    promptData.playerUsageCount[player] = promptData.playerUsageCount[player] + 1

    -- Fire signals
    PromptTriggered:Fire(player, prompt, promptData)

    -- Call the callback
    if promptData.callback then
        local success, errorMessage = pcall(promptData.callback, player, prompt, promptData)
        if not success then
            warn("Error in ProximityPrompt callback:", errorMessage)
        end
    end

    -- Check if prompt should be disabled after reaching usage limit
    if promptData.config.usageLimit and promptData.usageCount >= promptData.config.usageLimit then
        prompt.Enabled = false
    end
end

-- Handle player leaving (for cleanup)
local function onPlayerRemoving(player: Player)
    for promptId, promptData in pairs(activePrompts) do
        -- Reset usage count if configured
        if promptData.config.resetOnPlayerLeaving then
            promptData.playerUsageCount[player] = nil
        end

        -- Remove from whitelist/blacklist if present
        if promptData.config.playerWhitelist then
            for i, whitelistedPlayer in ipairs(promptData.config.playerWhitelist) do
                if whitelistedPlayer == player then
                    table.remove(promptData.config.playerWhitelist, i)
                    break
                end
            end
        end

        if promptData.config.playerBlacklist then
            for i, blacklistedPlayer in ipairs(promptData.config.playerBlacklist) do
                if blacklistedPlayer == player then
                    table.remove(promptData.config.playerBlacklist, i)
                    break
                end
            end
        end
    end
end

--|| Public Functions ||--

-- Add a proximity prompt to an object
function CustomProximityPromptService:AddPrompt(object: Instance, config: PromptConfig, callback: PromptCallback?): string?
    if not object then
        warn("Cannot add ProximityPrompt: object is nil")
        return nil
    end

    -- Find the best part to attach the prompt to
    local targetPart = getBestPartForPrompt(object)
    if not targetPart then
        warn("Cannot add ProximityPrompt: no suitable BasePart found in", object.Name)
        return nil
    end

    -- Generate unique ID
    local promptId = config.promptId or generatePromptId()

    -- Check if prompt with this ID already exists
    if activePrompts[promptId] then
        warn("ProximityPrompt with ID", promptId, "already exists!")
        return nil
    end

    -- Create the proximity prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "ProximityPrompt_" .. promptId
    prompt.Parent = targetPart

    -- Apply configuration
    applyPromptConfig(prompt, config)

    -- Create prompt data
    local promptData: PromptData = {
        id = promptId,
        instance = prompt,
        config = config,
        callback = callback,
        parent = object,
        usageCount = 0,
        lastUsedTime = 0,
        playerUsageCount = {}
    }

    -- Store in active prompts
    activePrompts[promptId] = promptData

    -- Fire signal
    PromptAdded:Fire(promptId, promptData)

    return promptId
end

-- Remove a proximity prompt by ID
function CustomProximityPromptService:RemovePrompt(promptId: string): boolean
    local promptData = activePrompts[promptId]
    if not promptData then
        warn("ProximityPrompt with ID", promptId, "not found!")
        return false
    end

    -- Destroy the prompt instance
    if promptData.instance then
        promptData.instance:Destroy()
    end

    -- Remove from active prompts
    activePrompts[promptId] = nil

    -- Fire signal
    PromptRemoved:Fire(promptId, promptData)

    return true
end

-- Remove all prompts from an object
function CustomProximityPromptService:RemoveAllPromptsFromObject(object: Instance): number
    local removedCount = 0

    for promptId, promptData in pairs(activePrompts) do
        if promptData.parent == object then
            self:RemovePrompt(promptId)
            removedCount = removedCount + 1
        end
    end

    return removedCount
end

-- Update prompt configuration
function CustomProximityPromptService:UpdatePromptConfig(promptId: string, newConfig: PromptConfig): boolean
    local promptData = activePrompts[promptId]
    if not promptData then
        warn("ProximityPrompt with ID", promptId, "not found!")
        return false
    end

    -- Merge new config with existing config
    for key, value in pairs(newConfig) do
        promptData.config[key] = value
    end

    -- Apply updated configuration
    applyPromptConfig(promptData.instance, promptData.config)

    return true
end

-- Get prompt data by ID
function CustomProximityPromptService:GetPromptData(promptId: string): PromptData?
    return activePrompts[promptId]
end

-- Get all active prompts
function CustomProximityPromptService:GetAllPrompts(): {[string]: PromptData}
    return activePrompts
end

-- Get prompts attached to a specific object
function CustomProximityPromptService:GetPromptsFromObject(object: Instance): {[string]: PromptData}
    local objectPrompts = {}

    for promptId, promptData in pairs(activePrompts) do
        if promptData.parent == object then
            objectPrompts[promptId] = promptData
        end
    end

    return objectPrompts
end

-- Enable/disable prompt
function CustomProximityPromptService:SetPromptEnabled(promptId: string, enabled: boolean): boolean
    local promptData = activePrompts[promptId]
    if not promptData then
        warn("ProximityPrompt with ID", promptId, "not found!")
        return false
    end

    promptData.instance.Enabled = enabled
    promptData.config.enabled = enabled

    return true
end

-- Reset prompt usage count
function CustomProximityPromptService:ResetPromptUsage(promptId: string, player: Player?): boolean
    local promptData = activePrompts[promptId]
    if not promptData then
        warn("ProximityPrompt with ID", promptId, "not found!")
        return false
    end

    if player then
        -- Reset for specific player
        promptData.playerUsageCount[player] = 0
    else
        -- Reset global usage
        promptData.usageCount = 0
        promptData.lastUsedTime = 0
        promptData.playerUsageCount = {}

        -- Re-enable if it was disabled due to usage limit
        if promptData.config.usageLimit then
            promptData.instance.Enabled = true
        end
    end

    return true
end

-- Clear all prompts
function CustomProximityPromptService:ClearAllPrompts(): number
    local clearedCount = 0

    for promptId, _ in pairs(activePrompts) do
        self:RemovePrompt(promptId)
        clearedCount = clearedCount + 1
    end

    return clearedCount
end

-- Get signals for external connections
function CustomProximityPromptService:GetPromptTriggeredSignal()
    return PromptTriggered
end

function CustomProximityPromptService:GetPromptAddedSignal()
    return PromptAdded
end

function CustomProximityPromptService:GetPromptRemovedSignal()
    return PromptRemoved
end

--|| Client Functions ||--

-- Client can request prompt data (read-only)
function CustomProximityPromptService.Client:GetPromptData(player: Player, promptId: string)
    return self.Server:GetPromptData(promptId)
end

function CustomProximityPromptService.Client:GetAllPrompts(player: Player)
    return self.Server:GetAllPrompts()
end

-- KNIT START
function CustomProximityPromptService:KnitStart()
    -- Connect to ProximityPromptService
    ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)

    -- Connect to player leaving
    Players.PlayerRemoving:Connect(onPlayerRemoving)

end

return CustomProximityPromptService
