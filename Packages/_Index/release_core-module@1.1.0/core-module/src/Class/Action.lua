local Action = {}
Action.__index = Action

function Action.new(name: string, cooldown: number, callback: () -> any)
	local self = setmetatable({}, Action)

	self.name = name
	self.cooldown = cooldown

	self.callback = callback
	self.middlewares = {}

	return self
end

function Action:BindCallback(callback: () -> any)
	self.callback = callback
end

function Action:AddMiddleware(middleware: () -> any)
	table.insert(self.middlewares, middleware)
end

function Action:Perform(player: Player)
	local OK = true

	for _, middleware in self.middlewares do
		if not middleware() then
			OK = false
			break
		end
	end

	if OK then
		return self.callback(player)
	end

	return false
end

return Action
