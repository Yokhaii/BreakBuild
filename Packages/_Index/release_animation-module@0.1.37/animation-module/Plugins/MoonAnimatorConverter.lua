local plugin = script:FindFirstAncestorWhichIsA("Plugin")
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create toolbar and button
local toolbar = plugin:CreateToolbar("MoonAnimator Converter")
local convertButton = toolbar:CreateButton("Convert", "Convert MoonAnimator data", "rbxassetid://4458901886")

-- Helper function to find rig name from parsed data
local function getRigName(parsedData)
	if not parsedData or not parsedData.Items then return nil end

	for _, item in ipairs(parsedData.Items) do
		if item.Path and item.Path.ItemType == "Rig" then
			return item.Path.InstanceNames[#item.Path.InstanceNames]
		end
	end
	return nil
end

-- Helper function to check if the Rig item has CFrame root motion keyframes
local function hasRigRootMotion(stringValue, parsedData)
	if not parsedData or not parsedData.Items then return false end

	for i, item in ipairs(parsedData.Items) do
		if item.Path and item.Path.ItemType == "Rig" then
			local itemFolder = stringValue:FindFirstChild(tostring(i))
			if itemFolder and itemFolder:IsA("Folder") then
				local cframeFolder = itemFolder:FindFirstChild("CFrame")
				if cframeFolder and cframeFolder:IsA("Folder") and #cframeFolder:GetChildren() > 0 then
					return true
				end
			end
		end
	end
	return false
end

-- Helper function to determine animation type based on data
local function getAnimationType(parsedData, stringValue)
	-- Check for rig first
	local hasRig = false
	for _, item in ipairs(parsedData.Items or {}) do
		if item.Path and item.Path.ItemType == "Rig" then
			hasRig = true
			print("Found Rig item")
			break
		end
	end

	print("hasRig:", hasRig)

	if hasRig then
		-- Has Rig, check if it has other items too
		local hasOtherItems = false
		for _, item in ipairs(parsedData.Items or {}) do
			if item.Path then
				local itemType = item.Path.ItemType
				print("Checking item type:", itemType)
				if itemType == "ParticleEmitter" or itemType == "Model" or
					itemType == "BasePart" or itemType == "MeshPart" or itemType == "Camera" or itemType == "Beam" or itemType == "Trail" then
					hasOtherItems = true
					print("Found other item:", itemType)
					break
				end
			end
		end

		-- Check if the Rig has root motion (CFrame on the Rig item itself)
		local hasRootMotion = hasRigRootMotion(stringValue, parsedData)
		if hasRootMotion then
			hasOtherItems = true
			print("Found Rig root motion (CFrame on Rig item)")
		end

		print("hasOtherItems:", hasOtherItems)

		if hasOtherItems then
			print("Returning Moon")
			return "Moon", nil  -- Rig + other items = Moon
		else
			print("Returning Basic")
			return "Basic", nil -- Rig only = Basic
		end
	else
		-- No Rig = NoRig
		print("Returning NoRig")
		return "NoRig", nil
	end
end

local function getInitialCFrame(parsedData)
	if parsedData and parsedData.Items and #parsedData.Items > 0 then
		-- Look for the rig item to get initial CFrame
		for _, item in ipairs(parsedData.Items) do
			if item.Path.ItemType == "Rig" then
				local rigName = item.Path.InstanceNames[#item.Path.InstanceNames]
				local rig = workspace:FindFirstChild(rigName)
				if rig then
					local humanoidRootPart = rig:FindFirstChild("HumanoidRootPart")
					if humanoidRootPart then
						return humanoidRootPart.CFrame
					end
				end
			end
		end
	end
	warn("Could not find initial CFrame. Using CFrame.new() as fallback.")
	return CFrame.new()
end

local function parseCFrameValue(cframe)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cframe:GetComponents()
	return string.format("CFrame.new(%f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f)",
		x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

local function formatLuaTable(tbl, indent)
	indent = indent or ""
	local result = "{\n"
	local keys = {}
	for k in pairs(tbl) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		if type(a) == "number" and type(b) == "number" then
			return a < b
		else
			return tostring(a) < tostring(b)
		end
	end)
	for _, k in ipairs(keys) do
		local v = tbl[k]
		local key
		if type(k) == "number" then
			key = "[" .. k .. "]"
		elseif type(k) == "string" and tonumber(k) then
			key = '["' .. k .. '"]'
		else
			key = k
		end
		result = result .. indent .. "    " .. key .. " = "
		if type(v) == "table" then
			result = result .. formatLuaTable(v, indent .. "    ")
		elseif type(v) == "string" then
			result = result .. '"' .. v .. '"'
		elseif typeof(v) == "CFrame" then
			result = result .. parseCFrameValue(v)
		else
			result = result .. tostring(v)
		end
		result = result .. ",\n"
	end
	return result .. indent .. "}"
end

local function parseEasing(easesFolder)
	local easing = {
		Direction = Enum.EasingDirection.In,
		Style = Enum.EasingStyle.Linear
	}

	local styleMapping = {
		Linear = Enum.EasingStyle.Linear,
		Sine = Enum.EasingStyle.Sine,
		Quad = Enum.EasingStyle.Quad,
		Cubic = Enum.EasingStyle.Cubic,
		Quart = Enum.EasingStyle.Quart,
		Quint = Enum.EasingStyle.Quint,
		Expo = Enum.EasingStyle.Exponential,
		Circ = Enum.EasingStyle.Circular,
		Back = Enum.EasingStyle.Back,
		Elastic = Enum.EasingStyle.Elastic,
		Bounce = Enum.EasingStyle.Bounce
	}

	if easesFolder then
		local direction = easesFolder:FindFirstChild("Direction", true)
		local style = easesFolder:FindFirstChild("Type", true)

		if direction then
			easing.Direction = direction.Value == "In" and Enum.EasingDirection.In or
				direction.Value == "Out" and Enum.EasingDirection.Out or
				Enum.EasingDirection.InOut
		end

		if style then
			if style.Value == "Constant" then
				easing.Style = "Constant"
			else
				easing.Style = styleMapping[style.Value] or Enum.EasingStyle.Linear
			end
		end
	end

	return easing
end

local function createModePrompt()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModePrompt"

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 200, 0, 100)
	frame.Position = UDim2.new(0.5, -100, 0.5, -50)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Text = "Select Mode"
	title.Parent = frame

	local freeButton = Instance.new("TextButton")
	freeButton.Size = UDim2.new(0.5, -5, 0, 30)
	freeButton.Position = UDim2.new(0, 5, 1, -35)
	freeButton.Text = "Free"
	freeButton.Parent = frame

	local relativeButton = Instance.new("TextButton")
	relativeButton.Size = UDim2.new(0.5, -5, 0, 30)
	relativeButton.Position = UDim2.new(0.5, 0, 1, -35)
	relativeButton.Text = "Relative"
	relativeButton.Parent = frame

	return screenGui, freeButton, relativeButton
end

local function getMode()
	local screenGui, freeButton, relativeButton = createModePrompt()
	screenGui.Parent = game:GetService("CoreGui")

	local choice = nil
	local connection1 = freeButton.MouseButton1Click:Connect(function() choice = "Free" end)
	local connection2 = relativeButton.MouseButton1Click:Connect(function() choice = "Relative" end)

	repeat
		wait()
	until choice ~= nil

	connection1:Disconnect()
	connection2:Disconnect()
	screenGui:Destroy()

	return choice
end

-- Model selection prompt for NoRig animations
local function createModelSelectionPrompt()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModelSelectionPrompt"

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300, 0, 120)
	frame.Position = UDim2.new(0.5, -150, 0.5, -60)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Text = "Select the animated model in workspace, then click Confirm"
	title.TextWrapped = true
	title.Parent = frame

	local confirmButton = Instance.new("TextButton")
	confirmButton.Size = UDim2.new(0, 100, 0, 30)
	confirmButton.Position = UDim2.new(0.5, -50, 1, -40)
	confirmButton.Text = "Confirm"
	confirmButton.Parent = frame

	return screenGui, confirmButton
end

local function getAnimatedModel()
	local screenGui, confirmButton = createModelSelectionPrompt()
	screenGui.Parent = game:GetService("CoreGui")

	local confirmed = false
	local connection = confirmButton.MouseButton1Click:Connect(function()
		confirmed = true
	end)

	repeat
		wait()
	until confirmed

	connection:Disconnect()
	screenGui:Destroy()

	-- Get the selected model from Selection service
	local selectedInstances = Selection:Get()
	if #selectedInstances == 1 and selectedInstances[1]:IsA("Model") then
		return selectedInstances[1].Name
	else
		warn("Please select exactly one Model in the workspace")
		return nil
	end
end

-- Build a set of part names that are BasePart/MeshPart items in the animation
local function getBasePartItemNames(parsedData)
	local names = {}
	for _, item in ipairs(parsedData.Items or {}) do
		local t = item.Path.ItemType
		if t == "BasePart" or t == "MeshPart" then
			names[item.Path.InstanceNames[#item.Path.InstanceNames]] = true
		end
	end
	return names
end

-- Extract BasePart items (with all children) to the assets folder
local function extractBaseParts(parsedData, animationName, animationType, rigName, animatedModelName)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assetsFolder.Name = "Assets"
	assetsFolder.Parent = ReplicatedStorage

	local animationsFolder = assetsFolder:FindFirstChild("Animations") or Instance.new("Folder")
	animationsFolder.Name = "Animations"
	animationsFolder.Parent = assetsFolder

	local animationFolder = animationsFolder:FindFirstChild(animationName)
	if not animationFolder then
		animationFolder = Instance.new("Folder")
		animationFolder.Name = animationName
		animationFolder.Parent = animationsFolder
	end

	local targetModel = nil
	if animationType == "NoRig" then
		targetModel = workspace:FindFirstChild(animatedModelName)
	elseif animationType == "Moon" then
		targetModel = rigName and workspace:FindFirstChild(rigName)
	end

	if not targetModel then
		warn("Could not find target model for BasePart extraction")
		return
	end

	print("Extracting base parts for", animationType, "animation...")

	for _, item in ipairs(parsedData.Items) do
		local itemType = item.Path.ItemType
		if itemType == "BasePart" or itemType == "MeshPart" then
			local itemName = item.Path.InstanceNames[#item.Path.InstanceNames]
			local part = targetModel:FindFirstChild(itemName, true)
			if part and part:IsA("BasePart") then
				local partCopy = part:Clone()
				partCopy.Parent = animationFolder
				print("Extracted BasePart:", itemName, "with", #partCopy:GetDescendants(), "descendants")
			else
				warn("Could not find BasePart:", itemName, "in", targetModel.Name)
			end
		end
	end

	print("BasePart extraction complete!")
end

-- Extract ParticleEmitters for NoRig and Moon animations
local function extractParticleEmitters(parsedData, animationName, animationType, rigName, animatedModelName, basePartItemNames)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assetsFolder.Name = "Assets"
	assetsFolder.Parent = ReplicatedStorage

	local animationsFolder = assetsFolder:FindFirstChild("Animations") or Instance.new("Folder")
	animationsFolder.Name = "Animations"
	animationsFolder.Parent = assetsFolder

	-- Reuse the folder created by extractBaseParts (or create it if running standalone)
	local animationFolder = animationsFolder:FindFirstChild(animationName)
	if not animationFolder then
		animationFolder = Instance.new("Folder")
		animationFolder.Name = animationName
		animationFolder.Parent = animationsFolder
	end

	print("Extracting particle emitters for", animationType, "animation...")

	-- Determine the target model based on animation type
	local targetModel = nil
	if animationType == "NoRig" then
		targetModel = workspace:FindFirstChild(animatedModelName)
		if not targetModel then
			warn("Could not find animated model:", animatedModelName)
			return
		end
	elseif animationType == "Moon" then
		if rigName then
			targetModel = workspace:FindFirstChild(rigName)
			if not targetModel then
				warn("Could not find rig model:", rigName)
				return
			end
		end
	end

	-- Track cloned Attachments to avoid duplicates (key = Attachment instance)
	local clonedAttachments = {}

	for _, item in ipairs(parsedData.Items) do
		local itemType = item.Path.ItemType
		local itemName = item.Path.InstanceNames[#item.Path.InstanceNames]

		if itemType == "ParticleEmitter" then
			local fullPath = item.Path.InstanceNames
			local fullTypes = item.Path.InstanceTypes
			local currentObj = nil

			if targetModel then
				-- Start from the target model and navigate through the path
				currentObj = targetModel

				-- Find the model name in the path to determine starting point
				local modelStartIndex = nil
				for i, pathName in ipairs(fullPath) do
					if pathName == targetModel.Name then
						modelStartIndex = i
						break
					end
				end

				if modelStartIndex then
					-- Navigate from the model through the remaining path
					for i = modelStartIndex + 1, #fullPath - 1 do -- Stop before the ParticleEmitter itself
						local nextName = fullPath[i]
						local nextObj = currentObj:FindFirstChild(nextName)

						-- If not found directly, try recursive search (for Attachments that might be nested)
						if not nextObj then
							nextObj = currentObj:FindFirstChild(nextName, true)
						end

						if not nextObj then
							warn("Could not navigate to:", nextName, "in", currentObj.Name, "for emitter", itemName)
							warn("  Available children:", table.concat(
								(function()
									local names = {}
									for _, child in ipairs(currentObj:GetChildren()) do
										table.insert(names, child.Name .. "(" .. child.ClassName .. ")")
									end
									return names
								end)(),
								", "
							))
							break
						end
						currentObj = nextObj
					end
				else
					-- If model name not found in path, try navigating from game
					currentObj = game
					for i = 2, #fullPath - 1 do -- Skip "game", stop before ParticleEmitter
						currentObj = currentObj:FindFirstChild(fullPath[i])
						if not currentObj then
							warn("Could not navigate to:", fullPath[i], "in full path for", itemName)
							break
						end
					end
				end
			else
				-- No target model, navigate from game (fallback)
				currentObj = game
				for i = 2, #fullPath - 1 do -- Skip "game", stop before ParticleEmitter
					currentObj = currentObj:FindFirstChild(fullPath[i])
					if not currentObj then
						warn("Could not navigate to:", fullPath[i], "in path for", itemName)
						break
					end
				end
			end

			-- Now look for the ParticleEmitter in the current object (part or attachment)
			if currentObj then
				local emitter = currentObj:FindFirstChild(itemName)
				if emitter and emitter:IsA("ParticleEmitter") then
					-- Determine where the emitter was found and if it's in an attachment
					local parentType = currentObj.ClassName
					local isInAttachment = (parentType == "Attachment")

					if isInAttachment then
						-- If the attachment's parent part is itself a BasePart item, skip —
						-- those attachments are already bundled inside the cloned part.
						local partName = currentObj.Parent and currentObj.Parent.Name or "UnknownPart"
						if basePartItemNames and basePartItemNames[partName] then
							print("Skipping Attachment in BasePart item:", partName, "/", currentObj.Name)
						-- Check if we already cloned this Attachment
						elseif not clonedAttachments[currentObj] then
							-- Clone the ENTIRE Attachment once (preserves Position, CFrame, Axis, etc.)
							local assetName = partName .. "_" .. currentObj.Name
							local attachmentCopy = currentObj:Clone()
							attachmentCopy.Name = assetName
							attachmentCopy.Parent = animationFolder
							clonedAttachments[currentObj] = assetName
							print("Extracted Attachment:", assetName, "with", #attachmentCopy:GetChildren(), "emitters")
						else
							print("Skipping duplicate Attachment for emitter:", itemName, "(already cloned as", clonedAttachments[currentObj] .. ")")
						end
					else
						-- Original behavior: clone just the emitter
						local emitterCopy = emitter:Clone()
						emitterCopy.Parent = animationFolder
						print("Extracted ParticleEmitter:", itemName, "from", parentType)
					end
				else
					warn("Could not find ParticleEmitter:", itemName, "in:", currentObj.Name)
				end
			end
		end
	end

	print("Particle emitter extraction complete!")
	return clonedAttachments
end

-- Extract Beams and their Attachments for NoRig and Moon animations
local function extractBeams(parsedData, animationName, animationType, rigName, animatedModelName, clonedAttachments)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assetsFolder.Name = "Assets"
	assetsFolder.Parent = ReplicatedStorage

	local animationsFolder = assetsFolder:FindFirstChild("Animations") or Instance.new("Folder")
	animationsFolder.Name = "Animations"
	animationsFolder.Parent = assetsFolder

	local animationFolder = animationsFolder:FindFirstChild(animationName)
	if not animationFolder then
		animationFolder = Instance.new("Folder")
		animationFolder.Name = animationName
		animationFolder.Parent = animationsFolder
	end

	print("Extracting beams for", animationType, "animation...")

	-- Determine the target model based on animation type
	local targetModel = nil
	if animationType == "NoRig" then
		targetModel = workspace:FindFirstChild(animatedModelName)
		if not targetModel then
			warn("Could not find animated model:", animatedModelName)
			return clonedAttachments
		end
	elseif animationType == "Moon" then
		if rigName then
			targetModel = workspace:FindFirstChild(rigName)
			if not targetModel then
				warn("Could not find rig model:", rigName)
				return clonedAttachments
			end
		end
	end

	-- Use shared clonedAttachments map (passed from extractParticleEmitters)
	clonedAttachments = clonedAttachments or {}

	for _, item in ipairs(parsedData.Items) do
		local itemType = item.Path.ItemType
		local itemName = item.Path.InstanceNames[#item.Path.InstanceNames]

		if itemType == "Beam" then
			local fullPath = item.Path.InstanceNames
			local currentObj = nil

			if targetModel then
				currentObj = targetModel

				-- Find the model name in the path to determine starting point
				local modelStartIndex = nil
				for i, pathName in ipairs(fullPath) do
					if pathName == targetModel.Name then
						modelStartIndex = i
						break
					end
				end

				if modelStartIndex then
					-- Navigate from the model through the remaining path to the Beam's parent
					for i = modelStartIndex + 1, #fullPath - 1 do
						local nextName = fullPath[i]
						local nextObj = currentObj:FindFirstChild(nextName)

						if not nextObj then
							nextObj = currentObj:FindFirstChild(nextName, true)
						end

						if not nextObj then
							warn("Could not navigate to:", nextName, "in", currentObj.Name, "for beam", itemName)
							break
						end
						currentObj = nextObj
					end
				else
					currentObj = game
					for i = 2, #fullPath - 1 do
						currentObj = currentObj:FindFirstChild(fullPath[i])
						if not currentObj then
							warn("Could not navigate to:", fullPath[i], "in full path for", itemName)
							break
						end
					end
				end
			else
				currentObj = game
				for i = 2, #fullPath - 1 do
					currentObj = currentObj:FindFirstChild(fullPath[i])
					if not currentObj then
						warn("Could not navigate to:", fullPath[i], "in path for", itemName)
						break
					end
				end
			end

			-- Now look for the Beam in the current object (part)
			if currentObj then
				local beam = currentObj:FindFirstChild(itemName)
				if beam and beam:IsA("Beam") then
					-- Clone the Beam
					local beamCopy = beam:Clone()
					beamCopy.Name = itemName
					beamCopy.Parent = animationFolder

					-- Get and clone Attachment0 if exists
					local attachment0 = beam.Attachment0
					if attachment0 and attachment0:IsA("Attachment") then
						if not clonedAttachments[attachment0] then
							local attachmentCopy = attachment0:Clone()
							local partName = attachment0.Parent and attachment0.Parent.Name or "UnknownPart"
							local assetName = partName .. "_" .. attachment0.Name
							attachmentCopy.Name = assetName
							attachmentCopy.Parent = animationFolder
							clonedAttachments[attachment0] = assetName
							print("Extracted Attachment0:", assetName, "for beam:", itemName)
						end
						-- Store the asset name as an attribute on the beam
						beamCopy:SetAttribute("Attachment0Asset", clonedAttachments[attachment0])
						beamCopy:SetAttribute("Attachment0Part", attachment0.Parent and attachment0.Parent.Name or "")
					end

					-- Get and clone Attachment1 if exists
					local attachment1 = beam.Attachment1
					if attachment1 and attachment1:IsA("Attachment") then
						if not clonedAttachments[attachment1] then
							local attachmentCopy = attachment1:Clone()
							local partName = attachment1.Parent and attachment1.Parent.Name or "UnknownPart"
							local assetName = partName .. "_" .. attachment1.Name
							attachmentCopy.Name = assetName
							attachmentCopy.Parent = animationFolder
							clonedAttachments[attachment1] = assetName
							print("Extracted Attachment1:", assetName, "for beam:", itemName)
						end
						-- Store the asset name as an attribute on the beam
						beamCopy:SetAttribute("Attachment1Asset", clonedAttachments[attachment1])
						beamCopy:SetAttribute("Attachment1Part", attachment1.Parent and attachment1.Parent.Name or "")
					end

					-- Clear the attachment references on the clone (they'll be set at runtime)
					beamCopy.Attachment0 = nil
					beamCopy.Attachment1 = nil

					print("Extracted Beam:", itemName)
				else
					warn("Could not find Beam:", itemName, "in:", currentObj.Name)
				end
			end
		end
	end

	print("Beam extraction complete!")
	return clonedAttachments
end


-- Extract Trails and their Attachments for Moon animations
local function extractTrails(parsedData, animationName, animationType, rigName, animatedModelName, clonedAttachments)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assetsFolder.Name = "Assets"
	assetsFolder.Parent = ReplicatedStorage

	local animationsFolder = assetsFolder:FindFirstChild("Animations") or Instance.new("Folder")
	animationsFolder.Name = "Animations"
	animationsFolder.Parent = assetsFolder

	local animationFolder = animationsFolder:FindFirstChild(animationName)
	if not animationFolder then
		animationFolder = Instance.new("Folder")
		animationFolder.Name = animationName
		animationFolder.Parent = animationsFolder
	end

	print("Extracting trails for", animationType, "animation...")

	local targetModel = nil
	if animationType == "NoRig" then
		targetModel = workspace:FindFirstChild(animatedModelName)
		if not targetModel then
			warn("Could not find animated model:", animatedModelName)
			return clonedAttachments
		end
	elseif animationType == "Moon" then
		if rigName then
			targetModel = workspace:FindFirstChild(rigName)
			if not targetModel then
				warn("Could not find rig model:", rigName)
				return clonedAttachments
			end
		end
	end

	clonedAttachments = clonedAttachments or {}

	for _, item in ipairs(parsedData.Items) do
		local itemType = item.Path.ItemType
		local itemName = item.Path.InstanceNames[#item.Path.InstanceNames]

		if itemType == "Trail" then
			local fullPath = item.Path.InstanceNames
			local currentObj = nil

			if targetModel then
				currentObj = targetModel

				local modelStartIndex = nil
				for i, pathName in ipairs(fullPath) do
					if pathName == targetModel.Name then
						modelStartIndex = i
						break
					end
				end

				if modelStartIndex then
					for i = modelStartIndex + 1, #fullPath - 1 do
						local nextName = fullPath[i]
						local nextObj = currentObj:FindFirstChild(nextName) or currentObj:FindFirstChild(nextName, true)
						if not nextObj then
							warn("Could not navigate to:", nextName, "in", currentObj.Name, "for trail", itemName)
							break
						end
						currentObj = nextObj
					end
				else
					currentObj = game
					for i = 2, #fullPath - 1 do
						currentObj = currentObj:FindFirstChild(fullPath[i])
						if not currentObj then
							warn("Could not navigate to:", fullPath[i], "in full path for", itemName)
							break
						end
					end
				end
			else
				currentObj = game
				for i = 2, #fullPath - 1 do
					currentObj = currentObj:FindFirstChild(fullPath[i])
					if not currentObj then
						warn("Could not navigate to:", fullPath[i], "in path for", itemName)
						break
					end
				end
			end

			if currentObj then
				local trail = currentObj:FindFirstChild(itemName)
				if trail and trail:IsA("Trail") then
					local trailCopy = trail:Clone()
					trailCopy.Name = itemName
					trailCopy.Parent = animationFolder

					local attachment0 = trail.Attachment0
					if attachment0 and attachment0:IsA("Attachment") then
						if not clonedAttachments[attachment0] then
							local attachmentCopy = attachment0:Clone()
							local partName = attachment0.Parent and attachment0.Parent.Name or "UnknownPart"
							local assetName = partName .. "_" .. attachment0.Name
							attachmentCopy.Name = assetName
							attachmentCopy.Parent = animationFolder
							clonedAttachments[attachment0] = assetName
							print("Extracted Attachment0:", assetName, "for trail:", itemName)
						end
						trailCopy:SetAttribute("Attachment0Asset", clonedAttachments[attachment0])
						trailCopy:SetAttribute("Attachment0Part", attachment0.Parent and attachment0.Parent.Name or "")
					end

					local attachment1 = trail.Attachment1
					if attachment1 and attachment1:IsA("Attachment") then
						if not clonedAttachments[attachment1] then
							local attachmentCopy = attachment1:Clone()
							local partName = attachment1.Parent and attachment1.Parent.Name or "UnknownPart"
							local assetName = partName .. "_" .. attachment1.Name
							attachmentCopy.Name = assetName
							attachmentCopy.Parent = animationFolder
							clonedAttachments[attachment1] = assetName
							print("Extracted Attachment1:", assetName, "for trail:", itemName)
						end
						trailCopy:SetAttribute("Attachment1Asset", clonedAttachments[attachment1])
						trailCopy:SetAttribute("Attachment1Part", attachment1.Parent and attachment1.Parent.Name or "")
					end

					trailCopy.Attachment0 = nil
					trailCopy.Attachment1 = nil

					print("Extracted Trail:", itemName)
				else
					warn("Could not find Trail:", itemName, "in:", currentObj.Name)
				end
			end
		end
	end

	print("Trail extraction complete!")
	return clonedAttachments
end

local function parseBehaviors(stringValue, mode, parsedData, animatedModelName)
	local behaviors = {}
	local indexMap = {}
	local currentOutputIndex = 1

	print("Parsing behaviors with mode:", mode)
	print("Animated model:", animatedModelName)

	-- Get reference CFrame for Relative mode
	local referenceCFrame = CFrame.new()
	if mode == "Relative" and animatedModelName then
		local animatedModel = workspace:FindFirstChild(animatedModelName)
		if animatedModel and animatedModel:IsA("Model") then
			if animatedModel.PrimaryPart then
				referenceCFrame = animatedModel.PrimaryPart.CFrame
				print("Using animated model's PrimaryPart CFrame as reference")
			else
				for _, part in ipairs(animatedModel:GetDescendants()) do
					if part:IsA("BasePart") then
						referenceCFrame = part.CFrame
						print("Using animated model's first BasePart CFrame as reference")
						break
					end
				end
			end
		end
	end

	-- Parse the behaviors
	for i = 1, #stringValue:GetChildren() do
		local itemFolder = stringValue:FindFirstChild(tostring(i))
		if itemFolder and itemFolder:IsA("Folder") then
			local itemType = "Unknown"
			local itemName = "Unknown"
			if parsedData and parsedData.Items and parsedData.Items[i] and parsedData.Items[i].Path then
				itemType = parsedData.Items[i].Path.ItemType
				itemName = parsedData.Items[i].Path.InstanceNames[#parsedData.Items[i].Path.InstanceNames]
			end

			print("Processing behaviors for item", i, ":", itemType, itemName)

			local behaviorData = {}

			-- For Rig items, only process the CFrame folder (root motion)
			local isRigItem = (itemType == "Rig")

			for _, behaviorFolder in ipairs(itemFolder:GetChildren()) do
				if behaviorFolder:IsA("Folder") and behaviorFolder.Name ~= "Rig" and behaviorFolder.Name ~= "MarkerTrack" then
					local behaviorType = behaviorFolder.Name

					-- For Rig items, only extract CFrame (root motion), skip everything else
					if isRigItem and behaviorType ~= "CFrame" then
						continue
					end

					behaviorData[behaviorType] = {}

					local frames = {}
					for _, frameFolder in ipairs(behaviorFolder:GetChildren()) do
						if frameFolder:IsA("Folder") and tonumber(frameFolder.Name) then
							table.insert(frames, tonumber(frameFolder.Name))
						end
					end
					table.sort(frames)

					local previousEasing = nil
					for j, frameNumber in ipairs(frames) do
						local frameFolder = behaviorFolder:FindFirstChild(tostring(frameNumber))
						local valuesFolder = frameFolder:FindFirstChild("Values")
						local easesFolder = frameFolder:FindFirstChild("Eases")
						if valuesFolder then
							local behavior = {}
							if behaviorType == "CFrame" then
								local cframeValue = valuesFolder:FindFirstChildOfClass("CFrameValue")
								if cframeValue then
									local parsedCFrame

									if mode == "Relative" then
										parsedCFrame = referenceCFrame:ToObjectSpace(cframeValue.Value)
									else
										parsedCFrame = cframeValue.Value
									end

									behavior.Values = parsedCFrame
									behavior.Easing = j == #frames and previousEasing or parseEasing(easesFolder)
									previousEasing = behavior.Easing
								end
							elseif behaviorType == "Size" then
								local sizeValue = valuesFolder:FindFirstChildOfClass("Vector3Value")
								if sizeValue then
									behavior.Values = {
										x = sizeValue.Value.X,
										y = sizeValue.Value.Y,
										z = sizeValue.Value.Z
									}
									behavior.Easing = j == #frames and previousEasing or parseEasing(easesFolder)
									previousEasing = behavior.Easing
								end
							elseif behaviorType == "Transparency" or behaviorType == "FieldOfView" then
								local numberValue = valuesFolder:FindFirstChildOfClass("NumberValue")
								if numberValue then
									behavior.Values = tonumber(numberValue.Value)
									behavior.Easing = j == #frames and previousEasing or parseEasing(easesFolder)
									previousEasing = behavior.Easing
								end
							else  -- Enabled or Emit
								local valueInstance = valuesFolder:FindFirstChildOfClass("NumberValue") or valuesFolder:FindFirstChildOfClass("BoolValue")
								if valueInstance then
									behavior.Values = valueInstance.Value
								end
							end
							if next(behavior) then
								behaviorData[behaviorType][frameNumber] = behavior
							end
						end
					end
					if next(behaviorData[behaviorType]) == nil then
						behaviorData[behaviorType] = nil
					end
				end
			end

			if next(behaviorData) then
				indexMap[i] = currentOutputIndex
				behaviors[currentOutputIndex] = behaviorData
				currentOutputIndex = currentOutputIndex + 1
			end
		end
	end

	return behaviors, indexMap
end

local function convertMoonAnimatorData()
	local selectedInstances = Selection:Get()
	if #selectedInstances ~= 1 or not selectedInstances[1]:IsA("StringValue") then
		warn("Please select a single StringValue instance containing MoonAnimator data.")
		return
	end

	local stringValue = selectedInstances[1]
	local jsonData = stringValue.Value

	local success, parsedData = pcall(function()
		return HttpService:JSONDecode(jsonData)
	end)

	if not success then
		warn("Failed to parse JSON data:", parsedData)
		return
	end

	local animationType, _ = getAnimationType(parsedData, stringValue)
	print("Initial Animation Type:", animationType)

	local info = parsedData.Information
	local items = parsedData.Items

	-- Check if this is a camera animation
	local isCameraAnimation = false
	for _, item in ipairs(items) do
		if item.Path and item.Path.ItemType == "Camera" then
			isCameraAnimation = true
			break
		end
	end

	-- Get rig name for Basic and Moon animations
	local rigName = nil
	if animationType == "Basic" or animationType == "Moon" then
		rigName = getRigName(parsedData)
		print("Rig name:", rigName)
		if not rigName then
			warn("Could not find rig name in animation data")
			return
		end
	end

	-- For NoRig animations, get the animated model
	local animatedModelName = nil
	if animationType == "NoRig" then
		animatedModelName = getAnimatedModel()
		if not animatedModelName then
			warn("No valid model selected. Conversion cancelled.")
			return
		end
		print("Animated model selected:", animatedModelName)

		-- Now determine the final animation type
		if isCameraAnimation then
			-- Keep as NoRig if has camera
			animationType = "NoRig"
		else
			-- Check what we actually have in the animation
			local hasBaseParts = false
			local hasModels = false

			for _, item in ipairs(items) do
				if item.Path then
					if item.Path.ItemType == "BasePart" or item.Path.ItemType == "MeshPart" then
						hasBaseParts = true
					elseif item.Path.ItemType == "Model" then
						hasModels = true
					end
				end
			end

			-- If we have parts/models OR if we selected a model, it's NoRig
			-- Otherwise it might be just ParticleEmitters (still NoRig)
			animationType = "NoRig"
		end

		print("Final Animation Type:", animationType)
	end

	local mode = getMode()
	print("User selected mode:", mode)

	-- Create the new module script
	local newScript = Instance.new("ModuleScript")
	newScript.Name = stringValue.Name .. "Converted"

	-- Initialize the output table
	local luaTable = {
		AnimationType = animationType,
		Name = stringValue.Name,
		Priority = info.ExportPriority or "Action",
		Loop = info.Looped or false,
		Speed = 1,
		Weight = 1,
		isExclusive = false,
		Items = {}
	}

	-- Add Id field only for Basic and Moon animations
	if animationType == "Basic" or animationType == "Moon" then
		luaTable.Id = info.Id or "rbxassetid://YOUR_ANIMATION_ID_HERE"
	end

	-- Get reference model name for parseBehaviors
	local referenceModelName = animationType == "NoRig" and animatedModelName or rigName

	-- Process behaviors
	local behaviors, indexMap = parseBehaviors(stringValue, mode, parsedData, referenceModelName)

	-- Add all items that have behaviors (using indexMap to preserve correct indices)
	for i, item in ipairs(items) do
		if indexMap[i] then
			local outputIndex = indexMap[i]
			local itemType = item.Path.ItemType
			local itemName = item.Path.InstanceNames[#item.Path.InstanceNames]

			if itemType == "Rig" then
				luaTable.Items[outputIndex] = {
					Type = "RigMovement",
					Mode = mode,
					TpBack = false,
				}
				print("Added RigMovement item at index:", outputIndex)
			elseif itemType == "Camera" then
				luaTable.Items[outputIndex] = {
					Type = "Camera",
					Mode = mode,
					TweenInitialFrame = false,
				}
				print("Added camera item at index:", outputIndex)
			elseif itemType == "Model" then
				luaTable.Items[outputIndex] = {
					Name = itemName,
					Place = "",
					Type = "Model",
					Mode = mode,
				}
				print("Added model item:", itemName, "at index:", outputIndex)
			elseif itemType == "BasePart" or itemType == "MeshPart" then
				local path = item.Path.InstanceNames
				local parentName = path[#path - 1]
				local rootName = (animationType == "Moon") and rigName or animatedModelName
				local partPlace = (parentName == rootName) and "" or parentName
				luaTable.Items[outputIndex] = {
					Name = itemName,
					Place = partPlace,
					Type = "BasePart",
					Mode = mode,
					PartClass = itemType
				}
				print("Added part item:", itemName, "in:", partPlace ~= "" and partPlace or "(model root)", "at index:", outputIndex)
			elseif itemType == "ParticleEmitter" then
				local path = item.Path.InstanceNames
				local emitterName = path[#path]
				local parentName = path[#path - 1]

				-- Check if the parent is an Attachment by looking at InstanceTypes
				local parentType = item.Path.InstanceTypes[#item.Path.InstanceTypes - 1]
				local isInAttachment = (parentType == "Attachment")

				-- Determine the host part name (grandparent when in attachment, parent otherwise)
				local hostPartName = isInAttachment and path[#path - 2] or parentName

				local basePartNames = getBasePartItemNames(parsedData)
				if basePartNames[hostPartName] then
					-- Emitter is bundled inside a BasePart item — keep it visible in Items
					-- but mark it so the runtime knows not to load it from assets separately.
					luaTable.Items[outputIndex] = {
						Name = emitterName,
						Type = "ParticleEmitter",
						BundledInPart = hostPartName,
					}
					print("Added bundled emitter item:", emitterName, "owned by BasePart:", hostPartName, "at index:", outputIndex)
				else
					local itemData = {
						Name = emitterName,
						Place = "",
						Type = "ParticleEmitter",
						Attachment = isInAttachment
					}

					if isInAttachment then
						local attachmentName = parentName
						itemData.Place = hostPartName
						itemData.AttachmentAsset = hostPartName .. "_" .. attachmentName
						print("Added emitter item:", emitterName, "in attachment:", attachmentName, "in part:", hostPartName, "at index:", outputIndex)
					else
						itemData.Place = hostPartName
						print("Added emitter item:", emitterName, "directly in part:", hostPartName, "at index:", outputIndex)
					end

					luaTable.Items[outputIndex] = itemData
				end
			elseif itemType == "Beam" then
				local path = item.Path.InstanceNames
				local beamName = path[#path]
				local parentName = path[#path - 1]

				local itemData = {
					Name = beamName,
					Place = parentName,
					Type = "Beam",
				}

				print("Added beam item:", beamName, "in part:", parentName, "at index:", outputIndex)
				luaTable.Items[outputIndex] = itemData
			elseif itemType == "Trail" then
				local path = item.Path.InstanceNames
				local trailName = path[#path]
				local parentName = path[#path - 1]

				local itemData = {
					Name = trailName,
					Place = parentName,
					Type = "Trail",
				}

				print("Added trail item:", trailName, "in part:", parentName, "at index:", outputIndex)
				luaTable.Items[outputIndex] = itemData
			end
		end
	end

	luaTable.Behaviors = behaviors

	local tableString = "return " .. formatLuaTable(luaTable)
	newScript.Source = tableString
	newScript.Parent = stringValue.Parent

	-- Extract particle emitters and beams for NoRig and Moon animations
	if animationType == "NoRig" or animationType == "Moon" then
		local basePartNames = getBasePartItemNames(parsedData)
		extractBaseParts(parsedData, stringValue.Name, animationType, rigName, animatedModelName)
		local clonedAttachments = extractParticleEmitters(parsedData, stringValue.Name, animationType, rigName, animatedModelName, basePartNames)
		clonedAttachments = extractBeams(parsedData, stringValue.Name, animationType, rigName, animatedModelName, clonedAttachments)
		extractTrails(parsedData, stringValue.Name, animationType, rigName, animatedModelName, clonedAttachments)
	end

	print("Conversion complete. New ModuleScript created:", newScript:GetFullName())
end

convertButton.Click:Connect(convertMoonAnimatorData)