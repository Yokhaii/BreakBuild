local LoadingTracker = {}
LoadingTracker.__index = LoadingTracker

-- Constants for different asset types with both upper and lower case keys
local ASSET_WEIGHTS = {
	CONTROLLER = 2,
	controller = 2,
	controllers = 2,
	IMAGE = 1,
	image = 1,
	images = 1,
	UI_COMPONENT = 1.5,
	ui_component = 1.5,
	uiComponents = 1.5,
}

function LoadingTracker.new(options)
	local self = setmetatable({}, LoadingTracker)

	-- Initialize with options
	self.options = options or {
		trackControllers = true,
		trackImages = true,
		trackUI = true,
	}

	self.totalAssets = 0
	self.loadedAssets = 0
	self.totalWeight = 0
	self.loadedWeight = 0

	-- Track specific asset types
	self.stats = {
		controllers = { total = 0, loaded = 0 },
		images = { total = 0, loaded = 0 },
		uiComponents = { total = 0, loaded = 0 },
	}

	return self
end

function LoadingTracker:registerAssets(assetType, count)
	-- Check if this asset type should be tracked
	local trackingMap = {
		controllers = self.options.trackControllers,
		images = self.options.trackImages,
		uiComponents = self.options.trackUI,
	}

	if not trackingMap[assetType] then
		return
	end

	local weight = ASSET_WEIGHTS[assetType] or 1 -- Default to weight of 1 if not found

	self.stats[assetType].total += count
	self.totalAssets += count
	self.totalWeight += count * weight
end

function LoadingTracker:assetLoaded(assetType)
	-- Check if this asset type should be tracked
	local trackingMap = {
		controllers = self.options.trackControllers,
		images = self.options.trackImages,
		uiComponents = self.options.trackUI,
	}

	if not trackingMap[assetType] then
		return
	end

	local weight = ASSET_WEIGHTS[assetType] or 1 -- Default to weight of 1 if not found

	self.stats[assetType].loaded += 1
	self.loadedAssets += 1
	self.loadedWeight += weight
end

function LoadingTracker:getProgress()
	if self.totalWeight == 0 then
		return 1
	end -- Return 1 if nothing to track
	return self.loadedWeight / self.totalWeight
end

function LoadingTracker:getProgressText()
	if self.totalAssets == 0 then
		return "Loading..."
	end
	return string.format(
		"Loading... %d/%d (%d%%)",
		self.loadedAssets,
		self.totalAssets,
		math.floor(self:getProgress() * 100)
	)
end

return LoadingTracker
