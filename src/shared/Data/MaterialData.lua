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

-- Material properties (can be expanded later)
MaterialData.Properties = {
    Dirt = {
        displayName = "Dirt",
        rarity = "Common",
        color = Color3.fromRGB(139, 90, 43),
    },
    Stone = {
        displayName = "Stone",
        rarity = "Common",
        color = Color3.fromRGB(128, 128, 128),
    },
    Sand = {
        displayName = "Sand",
        rarity = "Common",
        color = Color3.fromRGB(238, 214, 175),
    },
    Log = {
        displayName = "Log",
        rarity = "Common",
        color = Color3.fromRGB(101, 67, 33),
    },
    RawIron = {
        displayName = "Raw Iron",
        rarity = "Uncommon",
        color = Color3.fromRGB(192, 192, 192),
    },
    RawGold = {
        displayName = "Raw Gold",
        rarity = "Rare",
        color = Color3.fromRGB(255, 215, 0),
    },
    RawDiamond = {
        displayName = "Raw Diamond",
        rarity = "Very Rare",
        color = Color3.fromRGB(0, 191, 255),
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

return MaterialData
