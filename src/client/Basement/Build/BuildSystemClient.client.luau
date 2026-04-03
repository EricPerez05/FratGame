--BuildSystemClient.lua
-- Client-side script for basement prop placement UI and grid visualization

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local propPlacementRemote = ReplicatedStorage:WaitForChild("PropPlacementRemote")
local propTemplates = ReplicatedStorage:WaitForChild("PropTemplates")

-- Configuration
local CONFIG = {
	GRID_SIZE = 4,
}

-- State
local isBuildMode = false
local currentBasementNumber = nil
local floorInfo = nil
local selectedTemplate = nil
local currentGridParts = {}
local hoverVisual = nil
local placedProps = {}

-- Create UI
local function createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BasementBuildUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	-- Main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 300, 0, 400)
	mainFrame.Position = UDim2.new(1, -320, 0.5, -200)
	mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = mainFrame
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Basement Props"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 24
	title.Font = Enum.Font.GothamBold
	title.Parent = mainFrame
	
	-- Props container
	local propsContainer = Instance.new("ScrollingFrame")
	propsContainer.Name = "PropsContainer"
	propsContainer.Size = UDim2.new(1, -20, 1, -120)
	propsContainer.Position = UDim2.new(0, 10, 0, 60)
	propsContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	propsContainer.BorderSizePixel = 0
	propsContainer.ScrollBarThickness = 6
	propsContainer.Parent = mainFrame
	
	local containerCorner = Instance.new("UICorner")
	containerCorner.Parent = propsContainer
	
	local propsLayout = Instance.new("UIGridLayout")
	propsLayout.CellSize = UDim2.new(0, 80, 0, 80)
	propsLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	propsLayout.Parent = propsContainer
	
	-- Populate props
	for _, template in pairs(propTemplates:GetChildren()) do
		local propButton = Instance.new("TextButton")
		propButton.Name = template.Name
		propButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		propButton.Text = template.Name
		propButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		propButton.TextSize = 12
		propButton.Font = Enum.Font.Gotham
		propButton.Parent = propsContainer
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.Parent = propButton
		
		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(1, 0, 0, 20)
		priceLabel.Position = UDim2.new(0, 0, 1, -20)
		priceLabel.BackgroundTransparency = 1
		priceLabel.Text = "$" .. (template:GetAttribute("Price") or 0)
		priceLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		priceLabel.TextSize = 14
		priceLabel.Font = Enum.Font.GothamBold
		priceLabel.Parent = propButton
		
		propButton.MouseButton1Click:Connect(function()
			selectedTemplate = template.Name
			-- Highlight selected
			for _, btn in pairs(propsContainer:GetChildren()) do
				if btn:IsA("TextButton") then
					btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
				end
			end
			propButton.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
			-- Update hover visual
			onTemplateSelected()
		end)
	end
	
	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(1, -20, 0, 40)
	closeButton.Position = UDim2.new(0, 10, 1, -50)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.Text = "Close Build Mode"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 16
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = mainFrame
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.Parent = closeButton
	
	closeButton.MouseButton1Click:Connect(function()
		toggleBuildMode(false)
	end)
	
	-- Toggle button (always visible)
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleButton"
	toggleButton.Size = UDim2.new(0, 150, 0, 40)
	toggleButton.Position = UDim2.new(0, 10, 0.5, 0)
	toggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	toggleButton.Text = "Build Mode"
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.TextSize = 16
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.Visible = false
	toggleButton.Parent = screenGui
	
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.Parent = toggleButton
	
	toggleButton.MouseButton1Click:Connect(function()
		toggleBuildMode(not isBuildMode)
	end)
	
	return screenGui
end

local ui = createUI()

-- Get physical grid lines from basement
local function getPhysicalGridParts()
	local basementsFolder = workspace:FindFirstChild("Basements")
	if not basementsFolder then return {} end
	
	local basement = basementsFolder:FindFirstChild("Basement" .. currentBasementNumber)
	if not basement then return {} end
	
	local mainRoom = basement:FindFirstChild("Main Room")
	if not mainRoom then return {} end
	
	local gridFolder = mainRoom:FindFirstChild("PropGrid")
	if not gridFolder then return {} end
	
	local parts = {}
	for _, part in pairs(gridFolder:GetChildren()) do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	return parts
end

-- Update grid visuals (show/hide grid lines)
local function updateGridVisuals()
	currentGridParts = getPhysicalGridParts()
	
	for _, gridLine in pairs(currentGridParts) do
		if isBuildMode then
			gridLine.Transparency = 0 -- Visible (white lines)
		else
			gridLine.Transparency = 1 -- Invisible
		end
	end
end

-- Create hover visual for prop preview
local function createHoverVisual()
	if hoverVisual then
		hoverVisual:Destroy()
		hoverVisual = nil
	end
	
	if not selectedTemplate then return end
	
	local template = propTemplates:FindFirstChild(selectedTemplate)
	if not template then return end
	
	hoverVisual = Instance.new("Part")
	hoverVisual.Name = "HoverVisual"
	hoverVisual.Size = template.Size
	hoverVisual.Transparency = 0.5
	hoverVisual.Color = Color3.fromRGB(100, 255, 100) -- Green for hover preview
	hoverVisual.Material = Enum.Material.Neon
	hoverVisual.Anchored = true
	hoverVisual.CanCollide = false
	hoverVisual.Parent = workspace.CurrentCamera
end

-- Update hover visual when template changes
local function onTemplateSelected()
	if isBuildMode and selectedTemplate then
		createHoverVisual()
	elseif hoverVisual then
		hoverVisual:Destroy()
		hoverVisual = nil
	end
end

-- Get grid position from mouse
local function getGridPositionFromMouse()
	if not floorInfo then return nil, nil end
	
	local mouse = player:GetMouse()
	local ray = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {player.Character or nil}
	
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)
	
	if result and result.Position then
		local gridX = math.floor((result.Position.X - floorInfo.position.X + floorInfo.size.X / 2) / CONFIG.GRID_SIZE)
		local gridZ = math.floor((result.Position.Z - floorInfo.position.Z + floorInfo.size.Z / 2) / CONFIG.GRID_SIZE)
		return gridX, gridZ
	end
	
	return nil, nil
end

-- Toggle build mode
function toggleBuildMode(enabled)
	isBuildMode = enabled
	ui.MainFrame.Visible = enabled

	if enabled then
		-- hide player and ceiling, move camera up
		local char = player.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then
					part.LocalTransparencyModifier = 1
				end
			end
		end
		local basement = workspace:FindFirstChild("Basements")
			and workspace.Basements:FindFirstChild("Basement" .. currentBasementNumber)
		if basement then
			for _, part in ipairs(basement:GetDescendants()) do
				if part:IsA("BasePart") and part.Name:lower():find("ceiling") then
					part.LocalTransparencyModifier = 1
				end
			end
		end
		local camera = workspace.CurrentCamera
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.new(root.Position + Vector3.new(0, 30, 0), root.Position)
		end
		propPlacementRemote:FireServer("GetFloorInfo", currentBasementNumber)
		propPlacementRemote:FireServer("GetBasementProps", currentBasementNumber)
	else
		-- restore player and ceiling, restore camera
		local char = player.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then
					part.LocalTransparencyModifier = 0
				end
			end
		end
		local basement = workspace:FindFirstChild("Basements")
			and workspace.Basements:FindFirstChild("Basement" .. currentBasementNumber)
		if basement then
			for _, part in ipairs(basement:GetDescendants()) do
				if part:IsA("BasePart") and part.Name:lower():find("ceiling") then
					part.LocalTransparencyModifier = 0
				end
			end
		end
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		for _, gridLine in pairs(currentGridParts) do
			gridLine.Transparency = 1
		end
		currentGridParts = {}
		if hoverVisual then
			hoverVisual:Destroy()
			hoverVisual = nil
		end
	end
end

-- Handle remote events
propPlacementRemote.OnClientEvent:Connect(function(action, ...)
	local args = {...}
	
	if action == "FloorInfoData" then
		local basementNumber, info = unpack(args)
		if basementNumber == currentBasementNumber then
			floorInfo = info
			updateGridVisuals()
		end
		
	elseif action == "BasementPropsData" then
		local basementNumber, props = unpack(args)
		if basementNumber == currentBasementNumber then
			placedProps = {}
			for _, propData in ipairs(props) do
				placedProps[propData.propId] = propData
			end
			updateGridVisuals()
		end
		
	elseif action == "PlacePropResult" then
		local success, result = unpack(args)
		if success then
			-- Refresh props
			propPlacementRemote:FireServer("GetBasementProps", currentBasementNumber)
		else
			warn("Failed to place prop: " .. (result or "Unknown error"))
		end
		
	elseif action == "RemovePropResult" then
		local success, result = unpack(args)
		if success then
			propPlacementRemote:FireServer("GetBasementProps", currentBasementNumber)
		else
			warn("Failed to remove prop: " .. (result or "Unknown error"))
		end
	end
end)

-- Update hover visual position
RunService.RenderStepped:Connect(function()
	if not isBuildMode or not floorInfo then
		return
	end
	
	local gridX, gridZ = getGridPositionFromMouse()
	if gridX and gridZ then
		-- Update hover visual position
		if hoverVisual and selectedTemplate then
			local worldX = floorInfo.position.X - floorInfo.size.X / 2 + (gridX + 0.5) * CONFIG.GRID_SIZE
			local worldZ = floorInfo.position.Z - floorInfo.size.Z / 2 + (gridZ + 0.5) * CONFIG.GRID_SIZE
			hoverVisual.Position = Vector3.new(worldX, floorInfo.topY + hoverVisual.Size.Y / 2 + 0.1, worldZ)
		end
	end
end)

-- Handle mouse click to place prop
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 and isBuildMode and selectedTemplate then
		local gridX, gridZ = getGridPositionFromMouse()
		if gridX and gridZ then
			propPlacementRemote:FireServer("PlaceProp", currentBasementNumber, selectedTemplate, gridX, gridZ, 0)
		end
	end
	
	-- Right click to remove prop
	if input.UserInputType == Enum.UserInputType.MouseButton2 and isBuildMode then
		local gridX, gridZ = getGridPositionFromMouse()
		if gridX and gridZ then
			-- Find prop at this position
			for propId, propData in pairs(placedProps) do
				local template = propTemplates:FindFirstChild(propData.templateName)
				if template then
					local gridSize = template:GetAttribute("GridSize") or 1
					for dx = 0, gridSize - 1 do
						for dz = 0, gridSize - 1 do
							if propData.gridX + dx == gridX and propData.gridZ + dz == gridZ then
								propPlacementRemote:FireServer("RemoveProp", currentBasementNumber, propId)
								break
							end
						end
					end
				end
			end
		end
	end
	
	-- Press B to toggle build mode
	if input.KeyCode == Enum.KeyCode.B and currentBasementNumber then
		toggleBuildMode(not isBuildMode)
	end
end)

-- Detect when player enters basement
local function checkBasementLocation()
	local character = player.Character
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local position = hrp.Position
	
	-- Check if in any basement
	local basementsFolder = workspace:FindFirstChild("Basements")
	if not basementsFolder then return end
	
	for i = 1, 4 do
		local basement = basementsFolder:FindFirstChild("Basement" .. i)
		if basement then
			local floorInfo = nil
			local mainRoom = basement:FindFirstChild("Main Room")
			if mainRoom then
				local floor = mainRoom:FindFirstChild("ConcreteFloor")
				if floor then
					floorInfo = {
						position = floor.Position,
						size = floor.Size,
						topY = floor.Position.Y + floor.Size.Y / 2
					}
				end
			end
			
			if floorInfo then
				local inBasement = math.abs(position.X - floorInfo.position.X) < floorInfo.size.X / 2 + 5
					and math.abs(position.Z - floorInfo.position.Z) < floorInfo.size.Z / 2 + 5
					and position.Y < floorInfo.topY + 10
				
				if inBasement then
					if currentBasementNumber ~= i then
						currentBasementNumber = i
						ui.ToggleButton.Visible = true
						
						if isBuildMode then
							propPlacementRemote:FireServer("GetFloorInfo", currentBasementNumber)
							propPlacementRemote:FireServer("GetBasementProps", currentBasementNumber)
						end
					end
					return
				end
			end
		end
	end
	
	-- Not in any basement
	currentBasementNumber = nil
	ui.ToggleButton.Visible = false
	if isBuildMode then
		toggleBuildMode(false)
	end
end

RunService.Heartbeat:Connect(checkBasementLocation)
local BUILD_CAMERA_HEIGHT = 30  -- change this to adjust zoom

RunService.RenderStepped:Connect(function()
	if not isBuildMode then return end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	workspace.CurrentCamera.CFrame = CFrame.new(
		root.Position + Vector3.new(0, BUILD_CAMERA_HEIGHT, 0),
		root.Position
	)
end)
print("[BuildModeClient] Loaded successfully")