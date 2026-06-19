local BiomeData = {}

BiomeData.Biomes = {
	Mountain = {
		displayName = "Mountain",
		generationType = "heightmap",
		material = "Stone",
		topMaterial = "Grass",
		subMaterial = "Dirt",
		layers = {
			{ maxHeightPercent = 0.75, material = "Stone" },
			{ maxHeightPercent = 0.90, material = "Dirt" },
			{ maxHeightPercent = 1.0,  material = "Grass" },
		},
	},

	FloatingIsland = {
		displayName = "Floating Island",
		generationType = "islands",
		material = "Stone",
		topMaterial = "Grass",
		subMaterial = "Dirt",
		layers = {
			{ maxHeightPercent = 0.75, material = "Stone" },
			{ maxHeightPercent = 0.90, material = "Dirt" },
			{ maxHeightPercent = 1.0,  material = "Grass" },
		},
		islandCount = {10, 15},
		islandRadius = {3, 9},
		minHeight = 12,
		maxHeight = 75,
		heightStep = {1, 2},
		maxJumpGap = 2,
	},
}

BiomeData.DefaultBiome = "Mountain"

function BiomeData.GetMaterialAtHeight(biomeName: string, normalizedHeight: number): string
	local biome = BiomeData.Biomes[biomeName]
	if not biome then return "Stone" end

	if biome.layers then
		for _, layer in ipairs(biome.layers) do
			if normalizedHeight <= layer.maxHeightPercent then
				return layer.material
			end
		end
	end

	return biome.material or "Stone"
end

return BiomeData
