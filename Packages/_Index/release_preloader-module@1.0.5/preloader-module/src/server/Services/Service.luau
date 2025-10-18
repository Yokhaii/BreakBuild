--|| Services ||--
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--|| Imports ||--
local ImportFolder = ReplicatedStorage:FindFirstChild("Packages")

local src = script
while src and src.Name ~= "src" do
	src = src:FindFirstAncestorWhichIsA("Folder")
end

local function importPackage(name: string)
	local RootFolder = src and src:FindFirstAncestorWhichIsA("Folder") or nil

	return RootFolder and require(RootFolder[name]) or require(ImportFolder:FindFirstChild(name))
end

local Knit = importPackage("knit")
local Signal = importPackage("signal")
local Core = importPackage("core")

--|| Service ||--
local Service = Knit.CreateService({
	Name = "Service",

	Client = {},
})

--|| Client Methods ||--

--|| Server Methods ||--

--|| Knit Lifecycle ||--
function Service:KnitInit() end

return Service
