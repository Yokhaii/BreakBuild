--[=[
	TutorialTargets
	Registry of UI elements the tutorial can spotlight.

	Components tag an element with a ref:
	  [Roact.Ref] = TutorialTargets.Ref("InventoryButton")

	The tutorial then looks it up by id:
	  TutorialTargets.Get("InventoryButton") -- GuiObject if mounted and visible, else nil

	Ids in use: InventoryButton, HotbarSlot_<1-7>, BlueprintCard_<Name>, BlueprintGetButton_<Name>,
	<StationType>Recipe_<RecipeId>, <StationType>CraftButton_<RecipeId> (StationType = Inventory/Workbench)
]=]

local TutorialTargets = {}

local targets = {} -- { [targetId]: GuiObject }
local refCallbacks = {} -- { [targetId]: (GuiObject?) -> () }, cached so Roact sees a stable ref

local function isVisibleOnScreen(guiObject: GuiObject): boolean
	if guiObject.AbsoluteSize.X <= 0 or guiObject.AbsoluteSize.Y <= 0 then
		return false
	end

	local current: Instance? = guiObject
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("LayerCollector") then
			return current.Enabled and current:FindFirstAncestorWhichIsA("PlayerGui") ~= nil
		end
		current = current.Parent
	end

	return false
end

-- Returns a Roact ref callback that registers the element under `targetId`
function TutorialTargets.Ref(targetId: string)
	local callback = refCallbacks[targetId]
	if not callback then
		callback = function(instance)
			targets[targetId] = instance
		end
		refCallbacks[targetId] = callback
	end
	return callback
end

-- Returns the registered element if it is currently visible on screen
function TutorialTargets.Get(targetId: string?): GuiObject?
	if not targetId then return nil end

	local instance = targets[targetId]
	if instance and isVisibleOnScreen(instance) then
		return instance
	end
	return nil
end

return TutorialTargets
