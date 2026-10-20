local Config = {}

Config.NotificationHeight = UDim.new(0.05, 0)
Config.NotificationWidth = UDim.new(0.15, 0)
Config.Padding = UDim.new(0.005, 0)

Config.IconSize = UDim2.fromScale(1, 1)
Config.IconPadding = UDim.new(0.012, 0)

Config.TextColor = Color3.fromRGB(255, 255, 255)
Config.StrokeColor = Color3.fromRGB(30, 30, 30)
Config.StrokeThickness = 1.5

Config.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

Config.SlideInDuration = 0.15
Config.SlideInDistance = 60
Config.DisplayDuration = 2
Config.FadeOutDuration = 0.4
Config.SlideUpDistance = 40

return Config
