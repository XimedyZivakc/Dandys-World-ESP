local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ESPEnabled = true
local NameTagData = {}
local ProcessedFolders = {}
local PlayerConnections = {}
local ProcessedResearchCapsules = {}
local ProcessedPromptModels = {}
local ProcessedGigiHoard = {}
local ProcessedBlotZones = {}
local ProcessedBlotModels = {}
local TextConnections = {}

local PumpkinColor = Color3.fromRGB(251, 151, 62)
local PumpkinOutlineColor = Color3.fromRGB(0, 0, 0)
local PumpkinTransparency = 0.5

local PlayerColor = Color3.fromRGB(0, 0, 255)
local PlayerOutlineColor = Color3.fromRGB(255, 255, 255)

local GigiHoardColor = Color3.fromRGB(255, 105, 105)
local GigiHoardOutlineColor = Color3.fromRGB(0, 0, 0)
local GigiHoardStrokeColor = Color3.fromRGB(0, 0, 0)

local BlotHandZoneColor = Color3.fromRGB(128, 128, 128)
local BlotHandZoneOutlineColor = Color3.fromRGB(255, 255, 255)

local ICHOR_THRESHOLD = Vector3.new(
	6.218016147613525,
	3.065999984741211,
	3.065999984741211
)

local HighlightNames = {
	PlayerHighlight = true,
	MonstersHighlight = true,
	GeneratorsHighlight = true,
	ItemsHighlight = true,
	TrickOrTreatDoorsHighlight = true,
	HolidayPickupsHighlight = true,
	PumpkinHighlight = true,
	GigiHoardHighlight = true,
	BlotHandZoneHighlight = true
}

local function replaceBlott(value)
	if typeof(value) ~= "string" then
		return value
	end

	return value:gsub("[Bb][Ll][Oo][Tt][Tt]", "Blot")
end

local NameTagsFolder = PlayerGui:FindFirstChild("HighlightNameTags")

if not NameTagsFolder then
	NameTagsFolder = Instance.new("Folder")
	NameTagsFolder.Name = "HighlightNameTags"
	NameTagsFolder.Parent = PlayerGui
end

local function normalizeMonsterName(name)
	name = replaceBlott(tostring(name or "")):lower()
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	name = name:gsub("[%s_%-]", "")

	local previousName

	repeat
		previousName = name
		name = name:gsub("^twisted", "")
		name = name:gsub("^monster", "")
		name = name:gsub("monster$", "")
	until name == previousName

	return name
end

local function isSpecialMonster(name)
	local normalized = normalizeMonsterName(name)

	return normalized == "ribecca"
		or normalized == "soulvester"
		or normalized == "eclipse"
		or normalized == "gourdy"
end

local function addSpaces(name)
	name = tostring(name or "")
	name = name:gsub("^Monster", "")
	name = name:gsub("Monster$", "")
	name = name:gsub("(%l)(%u)", "%1 %2")
	name = name:gsub("(%u)(%u%l)", "%1 %2")
	name = name:gsub("(%a)(%d)", "%1 %2")
	name = name:gsub("(%d)(%a)", "%1 %2")

	return replaceBlott(name)
end

local function isInsideFolder(model, folderName)
	local current = model.Parent

	while current and current ~= Workspace do
		if current.Name == folderName then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isInsideBlotHandZone(object)
	local current = object
	local currentRoom = Workspace:FindFirstChild("CurrentRoom")

	if not currentRoom then
		return false
	end

	while current and current ~= Workspace do
		if (current.Name == "BlotHandZone_1"
			or current.Name == "BlotHandZone_2")
			and current:IsDescendantOf(currentRoom) then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isIchorFull(model)
	local ichor = model:FindFirstChild("Ichor", true)

	if not ichor or not ichor:IsA("BasePart") then
		return false
	end

	local size = ichor.Size

	return size.X >= ICHOR_THRESHOLD.X
		and size.Y >= ICHOR_THRESHOLD.Y
		and size.Z >= ICHOR_THRESHOLD.Z
end

local function isGeneratorCompleted(model)
	if not model then
		return false
	end

	local stats = model:FindFirstChild("Stats")
	local completed = stats and stats:FindFirstChild("Completed")

	return completed ~= nil
		and completed:IsA("BoolValue")
		and completed.Value == true
end

local function getDisplayName(model)
	if model.Name == "GigiHoard" then
		return replaceBlott("GigiHoard")
	end

	if isInsideFolder(model, "TrickOrTreatDoors") then
		return "Trick or Treat Door"
	end

	local realName = model.Name

	if realName:match("^Monster")
		or realName:match("Monster$")
		or isInsideFolder(model, "Monsters") then

		realName = realName:gsub("^Monster", "")
		realName = realName:gsub("Monster$", "")
		realName = realName:gsub("^%s+", "")
		realName = realName:gsub("%s+$", "")
		realName = addSpaces(realName)
		realName = replaceBlott(realName)

		if realName:match("^Twisted%s+") then
			return replaceBlott(realName)
		end

		return replaceBlott("Twisted " .. realName)
	end

	return replaceBlott(addSpaces(realName))
end

local function getTagName(model)
	local success, debugId = pcall(function()
		return model:GetDebugId()
	end)

	if success and debugId then
		return "ModelNameTag_" .. debugId
	end

	return "ModelNameTag_" .. model:GetFullName():gsub("[^%w_]", "_")
end

local function getPromptAdornee(model)
	if not model or not model.Parent then
		return nil
	end

	local promptObject = model:FindFirstChild("Prompt", true)

	if promptObject and promptObject:IsA("BasePart") then
		return promptObject
	end

	return nil
end

local function getCenteredAdornee(model)
	if not model or not model:IsA("Model") or not model.Parent then
		return nil
	end

	if isInsideFolder(model, "Generators") then
		return getPromptAdornee(model)
	end

	if isInsideFolder(model, "Monsters") then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart", true)

		if humanoid and root and root:IsA("BasePart") then
			return root
		end

		local head = model:FindFirstChild("Head", true)

		if head and head:IsA("BasePart") then
			return head
		end

		if root and root:IsA("BasePart") then
			return root
		end
	end

	local player = Players:GetPlayerFromCharacter(model)

	if player then
		local root = model:FindFirstChild("HumanoidRootPart")

		if root and root:IsA("BasePart") then
			return root
		end

		local head = model:FindFirstChild("Head")

		if head and head:IsA("BasePart") then
			return head
		end
	end

	local part = model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)

	if not part or not part:IsA("BasePart") then
		return nil
	end

	local success, boundingCFrame = pcall(function()
		return model:GetBoundingBox()
	end)

	if not success or not boundingCFrame then
		return part
	end

	local attachment = part:FindFirstChild("ESP_CenterAttachment")

	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "ESP_CenterAttachment"
		attachment.Parent = part
	end

	attachment.Position = part.CFrame:PointToObjectSpace(boundingCFrame.Position)

	return attachment
end

local function getStrokeColor(text)
	local billboard = text:FindFirstAncestorOfClass("BillboardGui")

	if billboard and billboard.Adornee then
		local model = billboard.Adornee:FindFirstAncestorOfClass("Model")

		if model then
			if model.Name == "GigiHoard" then
				return GigiHoardStrokeColor
			end

			if model:FindFirstChild("PlayerHighlight") then
				return PlayerOutlineColor
			end

			if model:FindFirstChild("GeneratorsHighlight")
				or model:FindFirstChild("MonstersHighlight") then
				return Color3.fromRGB(255, 255, 255)
			end
		end
	end

	return Color3.fromRGB(0, 0, 0)
end

local function configureTextLabel(text)
	text.Text = replaceBlott(text.Text)

	text.TextScaled = false
	text.TextSize = 13
	text.AnchorPoint = Vector2.zero
	text.Position = UDim2.new(0, 0, 0, 0)
	text.Size = UDim2.new(1, 0, 1, 0)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.BackgroundTransparency = 1

	local stroke = text:FindFirstChildOfClass("UIStroke")

	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = text
	end

	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = getStrokeColor(text)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 1.8
	stroke.Transparency = 0

	local billboard = text:FindFirstAncestorOfClass("BillboardGui")

	if billboard and billboard.Adornee then
		local model = billboard.Adornee:FindFirstAncestorOfClass("Model")

		if model and model.Name == "GigiHoard" then
			text.TextStrokeColor3 = GigiHoardStrokeColor
			text.TextStrokeTransparency = 0
		end
	end
end

local function configureBillboard(billboard)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 500
	billboard.LightInfluence = 0
	billboard.StudsOffset = Vector3.zero
	billboard.StudsOffsetWorldSpace = Vector3.zero
	billboard.ClipsDescendants = false
	billboard.Enabled = ESPEnabled

	for _, object in ipairs(billboard:GetChildren()) do
		if object:IsA("TextLabel") then
			configureTextLabel(object)
		end
	end
end

local function forcePromptPosition(model, billboard)
	if not model or not billboard or not billboard.Parent then
		return
	end

	if not isInsideFolder(model, "Generators") then
		return
	end

	local promptPart = getPromptAdornee(model)

	if not promptPart then
		return
	end

	if billboard.Adornee ~= promptPart then
		billboard.Adornee = promptPart
	end

	billboard.StudsOffset = Vector3.zero
	billboard.StudsOffsetWorldSpace = Vector3.zero

	local text = billboard:FindFirstChild("NameText")

	if text and text:IsA("TextLabel") then
		text.Position = UDim2.new(0, 0, 0, 0)
		text.AnchorPoint = Vector2.zero
		text.Size = UDim2.new(1, 0, 1, 0)
		text.Visible = true
	end
end

local function createNameTag(model, color)
	if not model or not model:IsA("Model") or not model.Parent then
		return nil
	end

	if isGeneratorCompleted(model) then
		return nil
	end

	if model.Name == "GigiHoard" then
		color = GigiHoardColor
	end

	local adornee = getCenteredAdornee(model)

	if not adornee then
		return nil
	end

	if not adornee:IsA("BasePart") and not adornee:IsA("Attachment") then
		return nil
	end

	local tagName = getTagName(model)
	local billboard = NameTagsFolder:FindFirstChild(tagName)

	if not billboard or not billboard:IsA("BillboardGui") then
		if billboard then
			billboard:Destroy()
		end

		billboard = Instance.new("BillboardGui")
		billboard.Name = tagName
		billboard.Size = UDim2.new(0, 180, 0, 20)
		billboard.Parent = NameTagsFolder
	end

	local text = billboard:FindFirstChild("NameText")

	if not text or not text:IsA("TextLabel") then
		if text then
			text:Destroy()
		end

		text = Instance.new("TextLabel")
		text.Name = "NameText"
		text.Size = UDim2.new(1, 0, 1, 0)
		text.Position = UDim2.new(0, 0, 0, 0)
		text.AnchorPoint = Vector2.zero
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextColor3 = color
		text.TextStrokeColor3 = Color3.new(0, 0, 0)
		text.TextStrokeTransparency = 0.25
		text.Parent = billboard
	end

	billboard.Adornee = adornee

	local player = Players:GetPlayerFromCharacter(model)

	if player and player ~= LocalPlayer then
		if player.DisplayName:lower() == player.Name:lower() then
			text.Text = replaceBlott("@" .. player.Name)
			billboard.Size = UDim2.new(0, 180, 0, 20)
		else
			text.Text = replaceBlott(player.DisplayName .. "\n@" .. player.Name)
			billboard.Size = UDim2.new(0, 180, 0, 36)
		end

		text.TextColor3 = PlayerColor
	else
		text.Text = getDisplayName(model)
		text.TextColor3 = color
	end

	if model.Name == "GigiHoard" then
		text.TextColor3 = GigiHoardColor
		text.TextStrokeColor3 = GigiHoardStrokeColor
		text.TextStrokeTransparency = 0
	end

	text.Visible = true
	text.TextWrapped = true

	configureTextLabel(text)
	configureBillboard(billboard)
	forcePromptPosition(model, billboard)

	return billboard
end

local function removeNameTag(model)
	if not model then
		return
	end

	local data = NameTagData[model]

	if data then
		if data.connections then
			for _, connection in ipairs(data.connections) do
				if connection and connection.Connected then
					connection:Disconnect()
				end
			end
		end

		NameTagData[model] = nil
	end

	local success, tagName = pcall(getTagName, model)

	if success then
		local tag = NameTagsFolder:FindFirstChild(tagName)

		if tag then
			tag:Destroy()
		end
	end
end

local function addNameTag(model, color)
	if not model or not model:IsA("Model") then
		return
	end

	if isGeneratorCompleted(model) then
		removeNameTag(model)
		return
	end

	if model.Name == "GigiHoard" then
		color = GigiHoardColor
	end

	local data = NameTagData[model]

	if not data then
		data = {
			color = color,
			connections = {},
			refreshQueued = false
		}

		NameTagData[model] = data

		local function queueRefresh()
			if data.refreshQueued then
				return
			end

			data.refreshQueued = true

			task.defer(function()
				data.refreshQueued = false

				if NameTagData[model] ~= data then
					return
				end

				if not model.Parent then
					removeNameTag(model)
					return
				end

				if isGeneratorCompleted(model) then
					removeNameTag(model)
					return
				end

				createNameTag(model, data.color)
			end)
		end

		table.insert(data.connections, model.DescendantAdded:Connect(function(object)
			if object.Name == "Prompt"
				or object:IsA("BasePart")
				or object:IsA("Attachment")
				or object:IsA("ProximityPrompt") then
				queueRefresh()
			end
		end))

		table.insert(data.connections, model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				removeNameTag(model)
			end
		end))
	end

	data.color = color

	createNameTag(model, color)
end

local function addHighlight(model, color, outlineColor, highlightName, fillTransparency)
	if not model or not model:IsA("Model") then
		return
	end

	if highlightName == "GeneratorsHighlight"
		and (isGeneratorCompleted(model) or isIchorFull(model)) then

		local existing = model:FindFirstChild(highlightName)

		if existing and existing:IsA("Highlight") then
			existing:Destroy()
		end

		removeNameTag(model)
		return
	end

	if model.Name == "GigiHoard" then
		color = GigiHoardColor
		outlineColor = GigiHoardOutlineColor
		highlightName = "GigiHoardHighlight"
		fillTransparency = 0.5
	end

	local highlight = model:FindFirstChild(highlightName)

	if not highlight or not highlight:IsA("Highlight") then
		if highlight then
			highlight:Destroy()
		end

		highlight = Instance.new("Highlight")
		highlight.Name = highlightName
		highlight.Parent = model
	end

	highlight.Adornee = model
	highlight.FillColor = color
	highlight.OutlineColor = outlineColor
	highlight.FillTransparency = fillTransparency
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = ESPEnabled

	addNameTag(model, color)
end

local function setupGigiHoard(model)
	if not model or not model:IsA("Model") or model.Name ~= "GigiHoard" then
		return
	end

	if ProcessedGigiHoard[model] then
		addHighlight(model, GigiHoardColor, GigiHoardOutlineColor, "GigiHoardHighlight", 0.5)
		return
	end

	ProcessedGigiHoard[model] = true

	addHighlight(model, GigiHoardColor, GigiHoardOutlineColor, "GigiHoardHighlight", 0.5)

	local connection

	connection = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			if connection then
				connection:Disconnect()
			end

			ProcessedGigiHoard[model] = nil
			removeNameTag(model)

			local highlight = model:FindFirstChild("GigiHoardHighlight")

			if highlight and highlight:IsA("Highlight") then
				highlight:Destroy()
			end
		elseif model.Parent then
			task.defer(function()
				if model:IsDescendantOf(Workspace) then
					addHighlight(model, GigiHoardColor, GigiHoardOutlineColor, "GigiHoardHighlight", 0.5)
				end
			end)
		end
	end)
end

local function setResearchHighlight(model, highlightName, color, outlineColor, transparency)
	if not model or not model:IsA("Model") or not model.Parent then
		return
	end

	local highlight = model:FindFirstChild(highlightName)

	if highlight and not highlight:IsA("Highlight") then
		highlight:Destroy()
		highlight = nil
	end

	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = highlightName
		highlight.Parent = model
	end

	highlight.Adornee = model
	highlight.FillColor = color
	highlight.OutlineColor = outlineColor
	highlight.FillTransparency = transparency
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = ESPEnabled
end

local function addPumpkinHighlightOnly(model)
	setResearchHighlight(
		model,
		"PumpkinHighlight",
		PumpkinColor,
		PumpkinOutlineColor,
		PumpkinTransparency
	)
end

local function removePumpkinHighlight(model)
	if not model then
		return
	end

	local highlight = model:FindFirstChild("PumpkinHighlight")

	if highlight and highlight:IsA("Highlight") then
		highlight:Destroy()
	end
end

local function setupBlotHighlight(object)
	if not object or not (object:IsA("BasePart") or object:IsA("Model")) then
		return
	end

	local highlight = object:FindFirstChild("BlotHandZoneHighlight")

	if highlight and not highlight:IsA("Highlight") then
		highlight:Destroy()
		highlight = nil
	end

	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "BlotHandZoneHighlight"
		highlight.Parent = object
	end

	highlight.Adornee = object
	highlight.FillColor = BlotHandZoneColor
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = BlotHandZoneOutlineColor
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = ESPEnabled

	if object:IsA("Model") then
		ProcessedBlotModels[object] = true
	end
end

local function setupBlotModel(model)
	if not model or not model:IsA("Model") or not model.Parent then
		return
	end

	if not isInsideBlotHandZone(model) then
		return
	end

	setupBlotHighlight(model)
end

local function setupBlotZone(zone)
	if not zone
		or not (zone:IsA("BasePart") or zone:IsA("Model"))
		or (zone.Name ~= "BlotHandZone_1" and zone.Name ~= "BlotHandZone_2") then
		return
	end

	local currentRoom = Workspace:FindFirstChild("CurrentRoom")

	if not currentRoom or not zone:IsDescendantOf(currentRoom) then
		return
	end

	setupBlotHighlight(zone)

	if ProcessedBlotZones[zone] then
		for _, object in ipairs(zone:GetDescendants()) do
			if object:IsA("Model") then
				setupBlotModel(object)
			end
		end

		return
	end

	local state = {}
	ProcessedBlotZones[zone] = state

	for _, object in ipairs(zone:GetDescendants()) do
		if object:IsA("Model") then
			setupBlotModel(object)
		end
	end

	state.descendantAdded = zone.DescendantAdded:Connect(function(object)
		task.defer(function()
			if not zone:IsDescendantOf(Workspace) then
				return
			end

			if object:IsA("Model") then
				setupBlotModel(object)
			end

			for _, child in ipairs(object:GetDescendants()) do
				if child:IsA("Model") then
					setupBlotModel(child)
				end
			end
		end)
	end)

	state.ancestryChanged = zone.AncestryChanged:Connect(function()
		if not zone:IsDescendantOf(Workspace) then
			if state.descendantAdded then
				state.descendantAdded:Disconnect()
			end

			if state.ancestryChanged then
				state.ancestryChanged:Disconnect()
			end

			ProcessedBlotZones[zone] = nil
		end
	end)
end

local function setESPEnabled(enabled)
	ESPEnabled = enabled

	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("Highlight") and HighlightNames[object.Name] then
			if object.Name == "GeneratorsHighlight" then
				local model = object.Parent

				if model and model:IsA("Model")
					and (isIchorFull(model) or isGeneratorCompleted(model)) then
					object:Destroy()
					removeNameTag(model)
				else
					object.Enabled = enabled
				end
			else
				object.Enabled = enabled
			end
		end
	end

	for _, object in ipairs(NameTagsFolder:GetChildren()) do
		if object:IsA("BillboardGui") then
			object.Enabled = enabled
		end
	end

	if enabled then
		for model, data in pairs(NameTagData) do
			if model and model.Parent and data then
				if not isGeneratorCompleted(model) then
					createNameTag(model, data.color)
				else
					removeNameTag(model)
				end
			end
		end
	end
end

local function findElevatorModels()
	local elevators = {}

	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("Model")
			and object.Name == "Elevator"
			and object:IsDescendantOf(Workspace) then
			table.insert(elevators, object)
		end
	end

	if Workspace:IsA("Model") and Workspace.Name == "Elevator" then
		table.insert(elevators, Workspace)
	end

	return elevators
end

local function teleportToElevator()
	local character = LocalPlayer.Character

	if not character or not character.Parent then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 or not rootPart then
		return
	end

	local elevators = findElevatorModels()
	local nearestElevator
	local nearestDistance = math.huge

	for _, elevator in ipairs(elevators) do
		if elevator.Parent then
			local success, pivot = pcall(function()
				return elevator:GetPivot()
			end)

			if success and pivot then
				local distance = (rootPart.Position - pivot.Position).Magnitude

				if distance < nearestDistance then
					nearestDistance = distance
					nearestElevator = elevator
				end
			end
		end
	end

	if not nearestElevator then
		return
	end

	local success, pivot = pcall(function()
		return nearestElevator:GetPivot()
	end)

	if not success or not pivot then
		return
	end

	character:PivotTo(pivot * CFrame.new(0, 3, 0))
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == Enum.KeyCode.P then
		setESPEnabled(not ESPEnabled)
	elseif input.KeyCode == Enum.KeyCode.L then
		teleportToElevator()
	end
end)

local function setupPlayer(player)
	if player == LocalPlayer or PlayerConnections[player] then
		return
	end

	local connections = {}
	PlayerConnections[player] = connections

	local function highlightCharacter(character)
		if not character or not character.Parent then
			return
		end

		addHighlight(
			character,
			PlayerColor,
			PlayerOutlineColor,
			"PlayerHighlight",
			0.5
		)

		local billboard = NameTagsFolder:FindFirstChild(getTagName(character))
		local text = billboard and billboard:FindFirstChild("NameText")

		if text and text:IsA("TextLabel") then
			if player.DisplayName:lower() == player.Name:lower() then
				text.Text = replaceBlott("@" .. player.Name)
				billboard.Size = UDim2.new(0, 180, 0, 20)
			else
				text.Text = replaceBlott(player.DisplayName .. "\n@" .. player.Name)
				billboard.Size = UDim2.new(0, 180, 0, 36)
			end

			text.TextColor3 = PlayerColor
			text.TextWrapped = true
			text.Visible = true

			configureTextLabel(text)
		end
	end

	if player.Character then
		highlightCharacter(player.Character)
	end

	connections.characterAdded = player.CharacterAdded:Connect(highlightCharacter)

	connections.displayNameChanged =
		player:GetPropertyChangedSignal("DisplayName"):Connect(function()
			if player.Character then
				highlightCharacter(player.Character)
			end
		end)

	connections.nameChanged =
		player:GetPropertyChangedSignal("Name"):Connect(function()
			if player.Character then
				highlightCharacter(player.Character)
			end
		end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	local connections = PlayerConnections[player]

	if connections then
		for _, connection in pairs(connections) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end

		PlayerConnections[player] = nil
	end

	if player.Character then
		removeNameTag(player.Character)
	end
end)

local function getResearchMonsterValue(model)
	for _, object in ipairs(model:GetDescendants()) do
		if object.Name == "Monster" and (
			object:IsA("StringValue")
			or object:IsA("ObjectValue")
		) then
			return object
		end
	end

	return nil
end

local function setupResearchCapsule(model)
	if not model:IsA("Model") or model.Name ~= "ResearchCapsule" then
		return
	end

	if ProcessedResearchCapsules[model] then
		return
	end

	local state = {
		connections = {},
		valueConnections = {},
		lastMonsterValue = nil,
		updating = false,
		updateQueued = false
	}

	ProcessedResearchCapsules[model] = state

	local function getMonsterName(valueObject)
		if not valueObject then
			return nil
		end

		local value

		if valueObject:IsA("StringValue") then
			value = valueObject.Value
		elseif valueObject:IsA("ObjectValue") then
			value = valueObject.Value

			if value and value:IsA("Instance") then
				value = value.Name
			end
		end

		if typeof(value) ~= "string" or value == "" then
			return nil
		end

		value = value:gsub("^%s+", ""):gsub("%s+$", "")
		value = value:gsub("^Monster", "")
		value = value:gsub("Monster$", "")
		value = value:gsub("^%s+", ""):gsub("%s+$", "")
		value = addSpaces(value)
		value = replaceBlott(value)

		if value == "" then
			return nil
		end

		return value
	end

	local function queueResearchUpdate()
		if state.updateQueued or state.updating then
			return
		end

		state.updateQueued = true

		task.defer(function()
			state.updateQueued = false

			if ProcessedResearchCapsules[model] ~= state or not model.Parent then
				return
			end

			state.updating = true

			pcall(function()
				local adornee = getCenteredAdornee(model)

				if not adornee then
					return
				end

				local monsterValue = getResearchMonsterValue(model)
				local monsterName = getMonsterName(monsterValue)
				local specialMonster = monsterName ~= nil
					and isSpecialMonster(monsterName)

				if specialMonster then
					local itemsHighlight = model:FindFirstChild("ItemsHighlight")

					if itemsHighlight then
						itemsHighlight:Destroy()
					end

					addPumpkinHighlightOnly(model)
				else
					removePumpkinHighlight(model)

					setResearchHighlight(
						model,
						"ItemsHighlight",
						Color3.fromRGB(0, 255, 0),
						Color3.fromRGB(0, 0, 0),
						0.5
					)
				end

				local billboardName = getTagName(model)
				local billboard = NameTagsFolder:FindFirstChild(billboardName)

				if not billboard or not billboard:IsA("BillboardGui") then
					if billboard then
						billboard:Destroy()
					end

					billboard = Instance.new("BillboardGui")
					billboard.Name = billboardName
					billboard.Parent = NameTagsFolder
				end

				billboard.Adornee = adornee
				billboard.Size = UDim2.new(0, 220, 0, 40)
				billboard.AlwaysOnTop = true
				billboard.MaxDistance = 500
				billboard.LightInfluence = 0
				billboard.StudsOffset = Vector3.zero
				billboard.StudsOffsetWorldSpace = Vector3.zero
				billboard.ClipsDescendants = false
				billboard.Enabled = ESPEnabled

				local text = billboard:FindFirstChild("NameText")

				if not text or not text:IsA("TextLabel") then
					if text then
						text:Destroy()
					end

					text = Instance.new("TextLabel")
					text.Name = "NameText"
					text.BackgroundTransparency = 1
					text.Font = Enum.Font.FredokaOne
					text.TextStrokeColor3 = Color3.new(0, 0, 0)
					text.TextStrokeTransparency = 0.25
					text.Parent = billboard
				end

				if monsterName then
					local displayMonsterName = replaceBlott(monsterName)

					if displayMonsterName:match("^Twisted%s+") then
						text.Text = replaceBlott("Research Capsule\n(" .. displayMonsterName .. ")")
					else
						text.Text = replaceBlott("Research Capsule\n(Twisted " .. displayMonsterName .. ")")
					end
				else
					text.Text = "Research Capsule"
				end

				text.BackgroundTransparency = 1
				text.Size = UDim2.new(1, 0, 1, 0)
				text.Position = UDim2.new(0, 0, 0, 0)
				text.TextColor3 = specialMonster
					and PumpkinColor
					or Color3.fromRGB(0, 255, 0)
				text.TextWrapped = true
				text.TextScaled = false
				text.TextSize = 13
				text.Visible = true

				configureTextLabel(text)
			end)

			state.updating = false
		end)
	end

	local function watchMonsterValue()
		if not model.Parent then
			return
		end

		local monsterValue = getResearchMonsterValue(model)

		if state.lastMonsterValue ~= monsterValue then
			for _, connection in ipairs(state.valueConnections) do
				if connection.Connected then
					connection:Disconnect()
				end
			end

			table.clear(state.valueConnections)
			state.lastMonsterValue = monsterValue

			if monsterValue then
				table.insert(
					state.valueConnections,
					monsterValue:GetPropertyChangedSignal("Value"):Connect(queueResearchUpdate)
				)
			end
		end

		queueResearchUpdate()
	end

	table.insert(state.connections, model.DescendantAdded:Connect(function()
		task.defer(watchMonsterValue)
	end))

	table.insert(state.connections, model.DescendantRemoving:Connect(function()
		task.defer(watchMonsterValue)
	end))

	table.insert(state.connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			for _, connection in ipairs(state.connections) do
				if connection.Connected then
					connection:Disconnect()
				end
			end

			for _, connection in ipairs(state.valueConnections) do
				if connection.Connected then
					connection:Disconnect()
				end
			end

			ProcessedResearchCapsules[model] = nil
			removeNameTag(model)
			removePumpkinHighlight(model)

			local itemsHighlight = model:FindFirstChild("ItemsHighlight")

			if itemsHighlight then
				itemsHighlight:Destroy()
			end
		else
			task.defer(watchMonsterValue)
		end
	end))

	watchMonsterValue()
end

local function setupPromptModel(model, color, outlineColor, highlightName, fillTransparency)
	if not model or not model:IsA("Model") then
		return
	end

	if ProcessedPromptModels[model] then
		return
	end

	local state = {
		connections = {},
		promptConnections = {},
		ichorConnections = {},
		completedConnections = {},
		updateQueued = false,
		lastIchorFull = nil,
		lastPromptActive = nil,
		removed = false
	}

	ProcessedPromptModels[model] = state

	local function removeGeneratorESP()
		local highlight = model:FindFirstChild(highlightName)

		if highlight and highlight:IsA("Highlight") then
			highlight:Destroy()
		end

		removeNameTag(model)
	end

	local function cleanup()
		if state.removed then
			return
		end

		state.removed = true

		for _, connection in ipairs(state.connections) do
			if connection.Connected then
				connection:Disconnect()
			end
		end

		for _, connection in pairs(state.promptConnections) do
			if connection.Connected then
				connection:Disconnect()
			end
		end

		for _, connection in pairs(state.ichorConnections) do
			if connection.Connected then
				connection:Disconnect()
			end
		end

		for _, connection in pairs(state.completedConnections) do
			if connection.Connected then
				connection:Disconnect()
			end
		end

		ProcessedPromptModels[model] = nil
		removeGeneratorESP()
	end

	local function queueUpdate()
		if state.updateQueued or state.removed then
			return
		end

		state.updateQueued = true

		task.defer(function()
			state.updateQueued = false

			if ProcessedPromptModels[model] ~= state or state.removed then
				return
			end

			if not model:IsDescendantOf(Workspace) then
				cleanup()
				return
			end

			if highlightName == "GeneratorsHighlight" and isGeneratorCompleted(model) then
				removeGeneratorESP()
				return
			end

			local highlight = model:FindFirstChild(highlightName)

			if highlightName == "GeneratorsHighlight" then
				local full = isIchorFull(model)

				if full then
					if highlight and highlight:IsA("Highlight") then
						highlight:Destroy()
					end

					removeNameTag(model)
					state.lastIchorFull = true
					return
				end

				state.lastIchorFull = false

				local billboard = NameTagsFolder:FindFirstChild(getTagName(model))

				if not highlight or not highlight:IsA("Highlight") then
					addHighlight(model, color, outlineColor, highlightName, fillTransparency)
				elseif not billboard then
					addNameTag(model, color)
				end

				billboard = NameTagsFolder:FindFirstChild(getTagName(model))

				if billboard and billboard:IsA("BillboardGui") then
					forcePromptPosition(model, billboard)
				end

				return
			end

			local hasPrompt = false
			local hasEnabledPrompt = false

			for _, object in ipairs(model:GetDescendants()) do
				if object:IsA("ProximityPrompt") then
					hasPrompt = true

					if object.Enabled then
						hasEnabledPrompt = true
					end
				end
			end

			local promptActive = hasPrompt and hasEnabledPrompt

			if state.lastPromptActive == promptActive then
				if promptActive then
					local billboard = NameTagsFolder:FindFirstChild(getTagName(model))

					if not highlight or not highlight:IsA("Highlight") then
						addHighlight(model, color, outlineColor, highlightName, fillTransparency)
					elseif not billboard then
						addNameTag(model, color)
					end
				end

				return
			end

			state.lastPromptActive = promptActive

			if promptActive then
				addHighlight(model, color, outlineColor, highlightName, fillTransparency)
			else
				if highlight and highlight:IsA("Highlight") then
					highlight:Destroy()
				end

				removeNameTag(model)
			end
		end)
	end

	local function watchCompleted(completed)
		if highlightName ~= "GeneratorsHighlight"
			or not completed:IsA("BoolValue")
			or state.completedConnections[completed] then
			return
		end

		state.completedConnections[completed] =
			completed:GetPropertyChangedSignal("Value"):Connect(function()
				if completed.Value then
					removeGeneratorESP()
					state.lastPromptActive = false
				else
					queueUpdate()
				end
			end)

		if completed.Value then
			removeGeneratorESP()
		end
	end

	local function findAndWatchCompleted()
		if highlightName ~= "GeneratorsHighlight" then
			return
		end

		local stats = model:FindFirstChild("Stats")
		local completed = stats and stats:FindFirstChild("Completed")

		if completed and completed:IsA("BoolValue") then
			watchCompleted(completed)
		end
	end

	local function watchIchor(ichor)
		if highlightName ~= "GeneratorsHighlight"
			or not ichor:IsA("BasePart")
			or state.ichorConnections[ichor] then
			return
		end

		local lastSize = ichor.Size

		state.ichorConnections[ichor] =
			ichor:GetPropertyChangedSignal("Size"):Connect(function()
				local currentSize = ichor.Size

				local wasFull = lastSize.X >= ICHOR_THRESHOLD.X
					and lastSize.Y >= ICHOR_THRESHOLD.Y
					and lastSize.Z >= ICHOR_THRESHOLD.Z

				local isFull = currentSize.X >= ICHOR_THRESHOLD.X
					and currentSize.Y >= ICHOR_THRESHOLD.Y
					and currentSize.Z >= ICHOR_THRESHOLD.Z

				lastSize = currentSize

				if wasFull ~= isFull then
					queueUpdate()
				end
			end)
	end

	local function watchPrompt(prompt)
		if not prompt:IsA("ProximityPrompt") or state.promptConnections[prompt] then
			return
		end

		state.promptConnections[prompt] =
			prompt:GetPropertyChangedSignal("Enabled"):Connect(queueUpdate)
	end

	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("ProximityPrompt") then
			watchPrompt(object)
		end

		if object.Name == "Ichor" and object:IsA("BasePart") then
			watchIchor(object)
		end
	end

	findAndWatchCompleted()

	table.insert(state.connections, model.DescendantAdded:Connect(function(object)
		if object:IsA("ProximityPrompt") then
			watchPrompt(object)
			queueUpdate()
		elseif object.Name == "Ichor" and object:IsA("BasePart") then
			watchIchor(object)
			queueUpdate()
		elseif object.Name == "Prompt" then
			queueUpdate()
		elseif object.Name == "Completed" and object:IsA("BoolValue") then
			watchCompleted(object)
		elseif object.Name == "Stats" then
			task.defer(findAndWatchCompleted)
		end
	end))

	table.insert(state.connections, model.DescendantRemoving:Connect(function(object)
		if object:IsA("ProximityPrompt") then
			local connection = state.promptConnections[object]

			if connection then
				connection:Disconnect()
				state.promptConnections[object] = nil
			end

			queueUpdate()
		elseif object:IsA("BasePart") and object.Name == "Ichor" then
			local connection = state.ichorConnections[object]

			if connection then
				connection:Disconnect()
				state.ichorConnections[object] = nil
			end

			queueUpdate()
		elseif object:IsA("BoolValue") and object.Name == "Completed" then
			local connection = state.completedConnections[object]

			if connection then
				connection:Disconnect()
				state.completedConnections[object] = nil
			end

			queueUpdate()
		elseif object.Name == "Prompt" then
			queueUpdate()
		end
	end))

	table.insert(state.connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			cleanup()
		else
			queueUpdate()
		end
	end))

	queueUpdate()
end

local function setupFolder(folder)
	if ProcessedFolders[folder] then
		return
	end

	ProcessedFolders[folder] = true

	folder.AncestryChanged:Connect(function(_, parent)
		if not parent then
			ProcessedFolders[folder] = nil
		end
	end)

	local color
	local outlineColor
	local highlightName
	local fillTransparency = 1

	if folder.Name == "Monsters" then
		color = Color3.fromRGB(255, 0, 0)
		outlineColor = Color3.fromRGB(255, 255, 255)
		highlightName = "MonstersHighlight"
		fillTransparency = 0.5
	elseif folder.Name == "Generators" then
		color = Color3.fromRGB(150, 150, 150)
		outlineColor = Color3.fromRGB(255, 255, 255)
		highlightName = "GeneratorsHighlight"
		fillTransparency = 0.5
	elseif folder.Name == "Items" then
		color = Color3.fromRGB(0, 255, 0)
		outlineColor = Color3.fromRGB(0, 0, 0)
		highlightName = "ItemsHighlight"
		fillTransparency = 0.5
	elseif folder.Name == "TrickOrTreatDoors" then
		color = PumpkinColor
		outlineColor = PumpkinOutlineColor
		highlightName = "TrickOrTreatDoorsHighlight"
		fillTransparency = 0.5
	elseif folder.Name == "HolidayPickups" then
		color = PumpkinColor
		outlineColor = PumpkinOutlineColor
		highlightName = "PumpkinHighlight"
		fillTransparency = PumpkinTransparency
	else
		return
	end

	local function process(model)
		if not model:IsA("Model") then
			return
		end

		if model.Name == "GigiHoard" then
			setupGigiHoard(model)
			return
		end

		if folder.Name == "Items" and model.Name == "ResearchCapsule" then
			setupResearchCapsule(model)
			return
		end

		if folder.Name == "Monsters" and isSpecialMonster(model.Name) then
			addHighlight(
				model,
				PumpkinColor,
				PumpkinOutlineColor,
				"PumpkinHighlight",
				PumpkinTransparency
			)
			return
		end

		if folder.Name == "Generators" or folder.Name == "TrickOrTreatDoors" then
			setupPromptModel(
				model,
				color,
				outlineColor,
				highlightName,
				fillTransparency
			)
			return
		end

		if folder.Name == "HolidayPickups" then
			addHighlight(
				model,
				PumpkinColor,
				PumpkinOutlineColor,
				"PumpkinHighlight",
				PumpkinTransparency
			)
			return
		end

		if folder.Name == "Items" and model.Name == "Pumpkin" then
			addHighlight(
				model,
				PumpkinColor,
				PumpkinOutlineColor,
				"PumpkinHighlight",
				PumpkinTransparency
			)
		else
			addHighlight(
				model,
				color,
				outlineColor,
				highlightName,
				fillTransparency
			)
		end
	end

	for _, model in ipairs(folder:GetChildren()) do
		process(model)
	end

	folder.ChildAdded:Connect(function(model)
		task.defer(function()
			if model.Parent == folder then
				process(model)
			end
		end)
	end)
end

local function scanCurrentRoom()
	local currentRoom = Workspace:FindFirstChild("CurrentRoom")

	if not currentRoom then
		return
	end

	for _, object in ipairs(currentRoom:GetDescendants()) do
		if object:IsA("Folder") and (
			object.Name == "Monsters"
			or object.Name == "Generators"
			or object.Name == "Items"
			or object.Name == "TrickOrTreatDoors"
			or object.Name == "HolidayPickups"
		) then
			setupFolder(object)
		elseif object:IsA("Model")
			and object.Name == "ResearchCapsule"
			and object.Parent
			and object.Parent.Name == "Items" then
			setupResearchCapsule(object)
		end

		if object.Name == "BlotHandZone_1"
			or object.Name == "BlotHandZone_2" then
			setupBlotZone(object)
		elseif object:IsA("Model") and isInsideBlotHandZone(object) then
			setupBlotModel(object)
		end
	end
end

for _, object in ipairs(Workspace:GetDescendants()) do
	if object:IsA("Model") and object.Name == "GigiHoard" then
		setupGigiHoard(object)
	end
end

scanCurrentRoom()

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "CurrentRoom" then
		task.defer(scanCurrentRoom)

		child.DescendantAdded:Connect(function(object)
			if object.Name == "BlotHandZone_1"
				or object.Name == "BlotHandZone_2" then
				task.defer(function()
					setupBlotZone(object)
				end)
			elseif object:IsA("Model") and isInsideBlotHandZone(object) then
				task.defer(function()
					setupBlotModel(object)
				end)
			end
		end)
	end
end)

Workspace.DescendantAdded:Connect(function(object)
	if object:IsA("Model") and object.Name == "GigiHoard" then
		task.defer(function()
			if object:IsDescendantOf(Workspace) then
				setupGigiHoard(object)
			end
		end)
	end

	if object:IsA("Highlight") and HighlightNames[object.Name] then
		if object.Name == "GeneratorsHighlight" then
			local model = object.Parent

			if model and model:IsA("Model")
				and (isIchorFull(model) or isGeneratorCompleted(model)) then
				object:Destroy()
				removeNameTag(model)
			elseif not ESPEnabled then
				object.Enabled = false
			end
		elseif not ESPEnabled then
			object.Enabled = false
		end
	elseif object:IsA("BillboardGui") and object.Parent == NameTagsFolder then
		if not ESPEnabled then
			object.Enabled = false
		end
	end

	if object:IsA("Folder") and (
		object.Name == "Monsters"
		or object.Name == "Generators"
		or object.Name == "Items"
		or object.Name == "TrickOrTreatDoors"
		or object.Name == "HolidayPickups"
	) then
		local currentRoom = Workspace:FindFirstChild("CurrentRoom")

		if currentRoom and object:IsDescendantOf(currentRoom) then
			setupFolder(object)
		end
	elseif object:IsA("Model") and object.Name == "ResearchCapsule" then
		task.defer(function()
			local currentRoom = Workspace:FindFirstChild("CurrentRoom")

			if object.Parent
				and object.Parent.Name == "Items"
				and currentRoom
				and object:IsDescendantOf(currentRoom) then
				setupResearchCapsule(object)
			end
		end)
	end

	if object.Name == "BlotHandZone_1"
		or object.Name == "BlotHandZone_2" then
		task.defer(function()
			setupBlotZone(object)
		end)
	elseif object:IsA("Model") and isInsideBlotHandZone(object) then
		task.defer(function()
			setupBlotModel(object)
		end)
	end
end)

local function fixBlottText(object)
	if not (
		object:IsA("TextLabel")
		or object:IsA("TextButton")
		or object:IsA("TextBox")
	) then
		return
	end

	local corrected = replaceBlott(object.Text)

	if corrected ~= object.Text then
		object.Text = corrected
	end

	if TextConnections[object] then
		return
	end

	TextConnections[object] =
		object:GetPropertyChangedSignal("Text"):Connect(function()
			local newText = replaceBlott(object.Text)

			if newText ~= object.Text then
				object.Text = newText
			end
		end)

	object.AncestryChanged:Connect(function()
		if not object:IsDescendantOf(game) then
			local connection = TextConnections[object]

			if connection then
				connection:Disconnect()
				TextConnections[object] = nil
			end
		end
	end)
end

for _, object in ipairs(game:GetDescendants()) do
	fixBlottText(object)
end

game.DescendantAdded:Connect(function(object)
	task.defer(function()
		if not object:IsDescendantOf(game) then
			return
		end

		fixBlottText(object)

		for _, descendant in ipairs(object:GetDescendants()) do
			fixBlottText(descendant)
		end
	end)
end)
