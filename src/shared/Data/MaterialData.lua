--[[
    MaterialData.lua
    Contains configuration for all materials in the Breaking system
    Including spawn weights, properties, and other material-specific data
]]

local BreakingConfig = require(script.Parent.Parent.Config.BreakingConfig)

local MaterialData = {}

-- Player configuration for holding materials
MaterialData.HoldConfig = {
    -- Walk speed when holding a material
    holdingWalkSpeed = 6,

    -- Offset from HumanoidRootPart where material is held
    -- Will look for an attachment named "HeldMaterialAttachment" in HumanoidRootPart
    -- If not found, will use this default offset
    defaultHoldOffset = CFrame.new(0, 0, -2.393), -- In front and above player
}

-- Material spawn weights (higher = more common)
-- Total weight: 100 for easy percentage calculation
MaterialData.SpawnWeights = {
    Dirt = 25,          -- 25% - Very common
    Stone = 25,         -- 25% - Very common
    Sand = 15,          -- 15% - Common
    Log = 15,           -- 15% - Common
    RawIron = 10,       -- 10% - Uncommon
    RawGold = 7,        -- 7% - Rare
    RawDiamond = 3,     -- 3% - Very rare
}

--[[
    Breaking Properties:
    - breakTime: number - base time in seconds to break this material
    - requiredTier: string - minimum tool tier required to break
      Tiers: "Wood" < "Stone" < "Iron" < "Gold" < "Diamond"
    - requiredToolCategory: string? - tool category required ("Pickaxe", "Axe", "Shovel", "Hammer")
      If nil, any tool (or bare hands) can break it
    - dropMultiplier: number - how many items drop (default 1)
]]

-- Tool tier hierarchy for comparison
-- Hand = 0 means bare hands (no tool)
MaterialData.ToolTierOrder = {
    Hand = 0,
    Wood = 1,
    Stone = 2,
    Iron = 3,
    Gold = 4,
    Diamond = 5,
}

-- Material properties (can be expanded later)
MaterialData.Properties = {
    Dirt = {
        displayName = "Dirt",
        rarity = "Common",
        color = Color3.fromRGB(139, 90, 43),
        breakTime = 1.0,
        requiredTier = "Hand",
        preferredToolCategory = "Shovel",
    },
    Grass = {
        displayName = "Grass",
        rarity = "Common",
        color = Color3.fromRGB(139, 90, 43),
        breakTime = 1.0,
        requiredTier = "Hand",
        preferredToolCategory = "Shovel",
    },
    Stone = {
        displayName = "Stone",
        rarity = "Common",
        color = Color3.fromRGB(128, 128, 128),
        breakTime = 2.0,
        requiredTier = "Hand",
        requiredToolCategory = "Pickaxe",
    },
    Sand = {
        displayName = "Sand",
        rarity = "Common",
        color = Color3.fromRGB(238, 214, 175),
        breakTime = 0.8,
        requiredTier = "Hand",
        preferredToolCategory = "Shovel",
    },
    Log = {
        displayName = "Log",
        rarity = "Common",
        color = Color3.fromRGB(101, 67, 33),
        breakTime = 1.5,
        requiredTier = "Hand",
        preferredToolCategory = "Axe",
    },
    RawIron = {
        displayName = "Raw Iron",
        rarity = "Uncommon",
        color = Color3.fromRGB(192, 192, 192),
        breakTime = 3.0,
        requiredTier = "Stone",
        requiredToolCategory = "Pickaxe",
    },
    RawGold = {
        displayName = "Raw Gold",
        rarity = "Rare",
        color = Color3.fromRGB(255, 215, 0),
        breakTime = 2.5,
        requiredTier = "Iron",
        requiredToolCategory = "Pickaxe",
    },
    RawDiamond = {
        displayName = "Raw Diamond",
        rarity = "Very Rare",
        color = Color3.fromRGB(0, 191, 255),
        breakTime = 4.0,
        requiredTier = "Iron",
        requiredToolCategory = "Pickaxe",
    },
    Structure = {
        displayName = "Structure",
        rarity = "Crafted",
        color = Color3.fromRGB(139, 90, 43),
        breakTime = 2.0,
        requiredTier = "Wood",
        requiredToolCategory = "Hammer",
    },
    Bedrock = {
        displayName = "Bedrock",
        rarity = "Common",
        color = Color3.fromRGB(40, 40, 40),
        unbreakable = true,
        breakTime = math.huge,
        requiredTier = "Diamond",
    },
    IronOreBlock = {
        displayName = "Iron Ore",
        rarity = "Uncommon",
        color = Color3.fromRGB(180, 150, 120),
        breakTime = 3.0,
        requiredTier = "Stone",
        requiredToolCategory = "Pickaxe",
    },
    CoalOreBlock = {
        displayName = "Coal Ore",
        rarity = "Common",
        color = Color3.fromRGB(50, 50, 50),
        breakTime = 2.0,
        requiredTier = "Wood",
        requiredToolCategory = "Pickaxe",
    },
}

-- List of all valid material names
MaterialData.ValidMaterials = {
    "Dirt",
    "Stone",
    "Sand",
    "Log",
    "RawIron",
    "RawGold",
    "RawDiamond",
    "Structure",
    "IronOreBlock",
    "CoalOreBlock",
}

-- Materials that can spawn in the BreakingZone (only blocks with 3D models)
MaterialData.BreakingZoneMaterials = {
    "Stone",
    "Dirt",
    "Sand",
}

-- Get a random material for BreakingZone spawning
function MaterialData.GetRandomBreakingMaterial(): string
    local materials = MaterialData.BreakingZoneMaterials
    return materials[math.random(1, #materials)]
end

-- Helper function to get a random material based on weights
function MaterialData.GetRandomMaterial(): string
    local totalWeight = 0
    for _, weight in pairs(MaterialData.SpawnWeights) do
        totalWeight = totalWeight + weight
    end

    local randomValue = math.random() * totalWeight
    local currentWeight = 0

    for material, weight in pairs(MaterialData.SpawnWeights) do
        currentWeight = currentWeight + weight
        if randomValue <= currentWeight then
            return material
        end
    end

    -- Fallback (should never happen)
    return "Stone"
end

-- Helper function to validate if a material name is valid
function MaterialData.IsValidMaterial(materialName: string): boolean
    for _, validMaterial in ipairs(MaterialData.ValidMaterials) do
        if validMaterial == materialName then
            return true
        end
    end
    return false
end

-- Helper function to get material properties
function MaterialData.GetProperties(materialName: string)
    return MaterialData.Properties[materialName]
end

-- Check if a tool tier and category can break a material
-- toolCategory is optional; bare hands pass nil and bypass category checks
function MaterialData.CanToolBreak(toolTier: string, materialName: string, toolCategory: string?): boolean
    local props = MaterialData.Properties[materialName]
    if not props then return false end

    if props.unbreakable then return false end

    local toolLevel = MaterialData.ToolTierOrder[toolTier] or 0
    local requiredLevel = MaterialData.ToolTierOrder[props.requiredTier] or 0

    if toolLevel < requiredLevel then return false end

    if props.requiredToolCategory then
        if not toolCategory then return false end
        return toolCategory == props.requiredToolCategory
    end

    return true
end

-- Get the break time for a material with tool speed applied
-- toolCategory is optional; only matching categories get the speed bonus
function MaterialData.GetBreakTime(materialName: string, toolBreakSpeed: number, toolCategory: string?): number
    local props = MaterialData.Properties[materialName]
    if not props then return 2.0 end

    local baseTime = props.breakTime or 2.0

    if props.preferredToolCategory and toolCategory ~= props.preferredToolCategory then
        return baseTime / BreakingConfig.BareHandBreakSpeed
    end

    return baseTime / (toolBreakSpeed or 1.0)
end

return MaterialData
