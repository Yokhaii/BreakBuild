--[[
	DroppedItemConfig.lua
	Items dropped in the world: toss, pickup and hover/spin animation
]]

return {
	FolderName = "DroppedItems", -- Workspace folder holding the dropped item models
	Tag = "DroppedItem", -- CollectionService tag read by DroppedItemController

	-- Lifetime and pickup
	DespawnTime = 300, -- Seconds before a dropped item disappears
	OwnerPickupDelay = 2, -- Seconds before the player who dropped an item can pick it back up
	PickupRadius = 3.5, -- Horizontal studs between the character and the item
	PickupHeight = 5, -- Vertical studs between the character and the item
	PickupCheckInterval = 0.1, -- Seconds between server pickup checks

	-- Toss (the item flies from in front of the player to the ground)
	DropDistance = 5, -- Studs in front of the player where the item lands
	DropScatter = 1, -- Max random studs added around the landing point so repeated drops don't overlap
	TossStartForward = 1.5, -- Studs in front of the player where the toss starts
	TossStartHeight = 1, -- Studs above the HumanoidRootPart where the toss starts
	TossUpSpeed = 10, -- Initial upward speed of the toss (studs/s)
	Gravity = 60, -- Studs/s² used for the toss arc
	MinFallTime = 0.25, -- Seconds (used when the ground is above the toss start)
	MaxGroundSearch = 100, -- Studs searched below the drop point; no ground = no drop

	-- On the ground
	HoverHeight = 0.6, -- Studs between the ground and the bottom of the item
	BobAmplitude = 0.25, -- Studs
	BobSpeed = 0.5, -- Bobs per second
	SpinSpeed = 90, -- Degrees per second
	AnimateDistance = 200, -- Studs from the camera beyond which items stop animating

	-- Quantity label ("x12") above landed stacks of more than one item
	LabelOffset = 0.8, -- Studs between the top of the item and the label
	LabelSize = UDim2.fromScale(2, 0.9), -- Studs (shrinks with distance)
	LabelMaxDistance = 50,
	LabelFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	LabelTextColor = Color3.fromRGB(255, 255, 255),
	LabelStrokeColor = Color3.fromRGB(0, 0, 0),
	LabelStrokeThickness = 1.5,
}
