--[[
    MaterialData.lua
    Contains configuration for all materials in the Breaking system
    Including spawn weights, properties, and other material-specific data
]]

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
        -- Breaking properties
        breakTime = 1.0,
        requiredTier = "Hand", -- Can be broken by bare hands
    },
    Stone = {
        displayName = "Stone",
        rarity = "Common",
        color = Color3.fromRGB(128, 128, 128),
        -- Breaking properties
        breakTime = 2.0,
        requiredTier = "Hand", -- Can be broken by bare hands
    },
    Sand = {
        displayName = "Sand",
        rarity = "Common",
        color = Color3.fromRGB(238, 214, 175),
        -- Breaking properties
        breakTime = 0.8,
        requiredTier = "Hand", -- Can be broken by bare hands
    },
    Log = {
        displayName = "Log",
        rarity = "Common",
        color = Color3.fromRGB(101, 67, 33),
        -- Breaking properties
        breakTime = 1.5,
        requiredTier = "Wood",
    },
    RawIron = {
        displayName = "Raw Iron",
        rarity = "Uncommon",
        color = Color3.fromRGB(192, 192, 192),
        -- Breaking properties
        breakTime = 3.0,
        requiredTier = "Stone",
    },
    RawGold = {
        displayName = "Raw Gold",
        rarity = "Rare",
        color = Color3.fromRGB(255, 215, 0),
        -- Breaking properties
        breakTime = 2.5,
        requiredTier = "Iron",
    },
    RawDiamond = {
        displayName = "Raw Diamond",
        rarity = "Very Rare",
        color = Color3.fromRGB(0, 191, 255),
        -- Breaking properties
        breakTime = 4.0,
        requiredTier = "Iron",
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

-- Check if a tool tier can break a material
function MaterialData.CanToolBreak(toolTier: string, materialName: string): boolean
    local props = MaterialData.Properties[materialName]
    if not props then return false end

    local toolLevel = MaterialData.ToolTierOrder[toolTier] or 0
    local requiredLevel = MaterialData.ToolTierOrder[props.requiredTier] or 0

    return toolLevel >= requiredLevel
end

-- Get the break time for a material with tool speed applied
function MaterialData.GetBreakTime(materialName: string, toolBreakSpeed: number): number
    local props = MaterialData.Properties[materialName]
    if not props then return 2.0 end -- Default fallback

    local baseTime = props.breakTime or 2.0
    return baseTime / (toolBreakSpeed or 1.0)
end

return MaterialData
