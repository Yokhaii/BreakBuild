local BiomeData = {}

BiomeData.Biomes = {
	Mountain = {
		displayName = "Mountain",
		generationType = "heightmap",
		material = "Stone",
		layers = {
			{ maxHeightPercent = 1.0, material = "Stone" },
		},
	},

	FloatingIsland = {
		displayName = "Floating Island",
		generationType = "islands",
		material = "Stone",
		islandCount = {10, 15},
		islandRadius = {1, 3},
		minHeight = 3,
		maxHeight = 75,
		undergroundLayers = 3,
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
