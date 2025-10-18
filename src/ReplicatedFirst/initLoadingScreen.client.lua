-- Const
local BACKGROUND_COLOR = Color3.new(1, 1, 1)
local PROGRESS_BAR_BG_COLOR = Color3.new(0, 0, 0)  -- Black background
local PROGRESS_BAR_FILL_COLOR = Color3.new(1, 1, 1) -- White fill
local PROGRESS_BAR_POSITION = UDim2.fromScale(0.5, 0.48)
local PROGRESS_BAR_SIZE = UDim2.fromScale(1.8, 0.6)  -- Made it a bit bigger
local PROGRESS_BAR_CORNER_RADIUS = UDim.new(0, 5)
local TEXT_POSITION = UDim2.fromScale(0.5, 0.6)
local TEXT_SIZE = UDim2.fromScale(0.9, 0.94)
local TEXT_FONT_SIZE = 18

-- Creating Loading Screen
local LoadingUI = Instance.new("ScreenGui")
LoadingUI.DisplayOrder = 5
LoadingUI.IgnoreGuiInset = true
LoadingUI.Name = "LoadingUI"

-- Background frame (now just a frame for the blur)
local ImageLabelBackground = Instance.new("Frame")
ImageLabelBackground.Parent = LoadingUI
ImageLabelBackground.Name = "ImageLabelBackground"
ImageLabelBackground.BackgroundColor3 = Color3.new(0, 0, 0)
ImageLabelBackground.BackgroundTransparency = 0
ImageLabelBackground.Size = UDim2.new(1, 0, 1, 0)

local BottomLeftImage = Instance.new("ImageLabel")
BottomLeftImage.Parent = ImageLabelBackground
BottomLeftImage.Name = "BottomLeftImage"
BottomLeftImage.Size = UDim2.fromScale(0.32, 0.42)
BottomLeftImage.BackgroundTransparency = 1
BottomLeftImage.Position = UDim2.fromScale(0.35,0.7)

local UIAspectRatio = Instance.new("UIAspectRatioConstraint")
UIAspectRatio.AspectRatio = 2.83
UIAspectRatio.Parent = BottomLeftImage

-- Fill bar background
local Background = Instance.new("Frame")
Background.Name = "Background"
Background.Parent = BottomLeftImage
Background.BackgroundColor3 = PROGRESS_BAR_BG_COLOR
Background.AnchorPoint = Vector2.new(0.5, 0.5)
Background.BorderColor3 = Color3.fromRGB(255,255,255)
Background.BorderSizePixel = 3
Background.Position = PROGRESS_BAR_POSITION
Background.Size = PROGRESS_BAR_SIZE

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = PROGRESS_BAR_CORNER_RADIUS
UICorner.Parent = Background

local UIStroke = Instance.new("UIStroke")
UIStroke.Parent = Background
UIStroke.Color = Color3.fromRGB(255, 255, 255)  -- White border
UIStroke.Thickness = 2

-- Fill bar
local Fill = Instance.new("Frame")
Fill.Name = "Fill"
Fill.Parent = Background
Fill.BackgroundColor3 = PROGRESS_BAR_FILL_COLOR
Fill.AnchorPoint = Vector2.new(0, 0.5)
Fill.Position = UDim2.new(0, 0, 0.5, 0)
Fill.Size = UDim2.new(0, 0, 1, 0)

local fillUICorner = Instance.new("UICorner")
fillUICorner.CornerRadius = PROGRESS_BAR_CORNER_RADIUS
fillUICorner.Parent = Fill

-- Text
local TextLabel = Instance.new("TextLabel")
TextLabel.Parent = BottomLeftImage
TextLabel.BackgroundTransparency = 1
TextLabel.Text = "Loading..."
TextLabel.AnchorPoint = Vector2.new(0.5, 0.5)
TextLabel.Position = TEXT_POSITION
TextLabel.Size = TEXT_SIZE
TextLabel.TextSize = TEXT_FONT_SIZE
TextLabel.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
TextLabel.TextColor3 = Color3.fromRGB(155, 155, 155)

local UIAspectRatio = Instance.new("UIAspectRatioConstraint")
UIAspectRatio.AspectRatio = 2.83
UIAspectRatio.Parent = TextLabel


-- wait for the loading screen
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGUI = player:WaitForChild("PlayerGui", 10)
LoadingUI.Parent = playerGUI

-- Function to clean up when loading is done
local function cleanupLoading()
    if LoadingUI and LoadingUI.Parent then
        LoadingUI:Destroy()
    end
end

task.wait(0.1)

-- Remove the default loading screen
game.ReplicatedFirst:RemoveDefaultLoadingScreen()

return {
    GUI = LoadingUI,
    Cleanup = cleanupLoading
}