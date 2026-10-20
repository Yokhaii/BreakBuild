local Config = {}

Config.NotificationHeight = UDim.new(0, 36)
Config.NotificationWidth = UDim.new(0, 160)
Config.Padding = UDim.new(0, 4)

Config.IconSize = UDim2.fromOffset(28, 28)
Config.IconPadding = UDim.new(0, 6)

Config.TextColor = Color3.fromRGB(255, 255, 255)
Config.StrokeColor = Color3.fromRGB(30, 30, 30)
Config.StrokeThickness = 1.5

Config.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

Config.DisplayDuration = 2
Config.FadeOutDuration = 0.4
Config.SlideUpDistance = 40

return Config
