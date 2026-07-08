-- Services
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

local KeybindController = Knit.CreateController({ Name = "KeybindController" })

-- Registry: id -> { keyCode, callback, condition? }
local binds = {}

--[=[
	Register a keybind.
	  id        – unique string; re-registering the same id overwrites the previous bind
	  keyCode   – Enum.KeyCode to listen for
	  callback  – called when the key is pressed and any condition passes
	  options   – optional table:
	              condition: () -> boolean  – if provided, keybind only fires when true

	Returns an unregister function for easy cleanup.
]=]
function KeybindController:Register(
	id: string,
	keyCode: Enum.KeyCode,
	callback: () -> (),
	options: { condition: (() -> boolean)? }?
): () -> ()
	binds[id] = {
		keyCode = keyCode,
		callback = callback,
		condition = options and options.condition,
	}
	return function()
		binds[id] = nil
	end
end

function KeybindController:Unregister(id: string)
	binds[id] = nil
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	for _, bind in pairs(binds) do
		if input.KeyCode == bind.keyCode then
			if not bind.condition or bind.condition() then
				bind.callback()
			end
		end
	end
end

function KeybindController:KnitStart()
	UserInputService.InputBegan:Connect(onInputBegan)
end

return KeybindController
