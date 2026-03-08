--[[
	BillboardContexts.lua
	Defines different contexts for the GeneralPlayer Billboard

	Each context specifies:
	- Options: Array of button configurations (max 3 + Close button)
	- Each option has: text (displayed on button) and callback (function to execute)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local BillboardContexts = {}

--[[
	Example Context: CuttingLog
	Used when player is near a log that can be cut
]]
BillboardContexts.CuttingLog = {
	Options = {
		{
			Text = "Cut Log",
			Callback = function(player, data)
				-- Example: Call a server service to cut one log
				-- local WoodCuttingService = Knit.GetService("WoodCuttingService")
				-- WoodCuttingService:CutLog(data.LogPart)
				print("Cut Log clicked for player:", player.Name)
			end,
		},
		{
			Text = "Cut All Logs",
			Callback = function(player, data)
				-- Example: Call a server service to cut all logs in area
				-- local WoodCuttingService = Knit.GetService("WoodCuttingService")
				-- WoodCuttingService:CutAllLogs(data.Position)
				print("Cut All Logs clicked for player:", player.Name)
			end,
		},
	},
}

--[[
	Example Context: NPCDialogue
	Used when player interacts with an NPC
]]
BillboardContexts.NPCDialogue = {
	Options = {
		{
			Text = "Talk",
			Callback = function(player, data)
				-- Example: Start dialogue with NPC
				-- local DialogueController = Knit.GetController("DialogueController")
				-- DialogueController:StartDialogue(data.NPCName)
				print("Talk clicked for NPC:", data and data.NPCName or "Unknown")
			end,
		},
		{
			Text = "Trade",
			Callback = function(player, data)
				-- Example: Open trading interface
				-- local TradeController = Knit.GetController("TradeController")
				-- TradeController:OpenTradeWithNPC(data.NPCName)
				print("Trade clicked for NPC:", data and data.NPCName or "Unknown")
			end,
		},
		{
			Text = "Quest",
			Callback = function(player, data)
				-- Example: Show available quests
				-- local QuestController = Knit.GetController("QuestController")
				-- QuestController:ShowQuestsForNPC(data.NPCName)
				print("Quest clicked for NPC:", data and data.NPCName or "Unknown")
			end,
		},
	},
}

--[[
	Example Context: CraftingTable
	Used when player is near a crafting table
]]
BillboardContexts.CraftingTable = {
	Options = {
		{
			Text = "Open Crafting",
			Callback = function(player, data)
				-- Example: Open crafting UI
				-- local CraftingController = Knit.GetController("CraftingController")
				-- CraftingController:OpenCraftingUI(data.TableType)
				print("Open Crafting clicked for table:", data and data.TableType or "Basic")
			end,
		},
	},
}

--[[
	Example Context: StorageChest
	Used when player interacts with a storage chest
]]
BillboardContexts.StorageChest = {
	Options = {
		{
			Text = "Open",
			Callback = function(player, data)
				-- Example: Open storage interface
				-- local StorageController = Knit.GetController("StorageController")
				-- StorageController:OpenChest(data.ChestId)
				print("Open chest clicked:", data and data.ChestId or "Unknown")
			end,
		},
		{
			Text = "Upgrade",
			Callback = function(player, data)
				-- Example: Upgrade chest capacity
				-- local StorageService = Knit.GetService("StorageService")
				-- StorageService:UpgradeChest(data.ChestId)
				print("Upgrade chest clicked:", data and data.ChestId or "Unknown")
			end,
		},
	},
}

return BillboardContexts
