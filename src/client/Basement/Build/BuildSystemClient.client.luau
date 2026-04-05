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
local buildModeFolder = nil

-- Configuration
local CONFIG = {
	GRID_SIZE = 4,
	BUILD_ZONE_ENTER_PADDING = 20,
	BUILD_ZONE_EXIT_PADDING = 35,
	BUILD_ZONE_HEIGHT_PADDING = 20,
	BASEMENT_FLOOR_Y_THRESHOLD = -30,
}

-- State
local isBuildMode = false
local currentBasementNumber = nil
local floorInfo = nil
local selectedTemplate = nil
local currentGridParts = {}
local hoverVisual = nil
local hoverVisualOffsets = nil
local placedProps = {}
local selectedCategory = "bars"
local availableCategories = {}
local categoryItems = {}

local toggleBuildMode
local onTemplateSelected

local function resolveBuildModeFolder()
	if buildModeFolder and buildModeFolder.Parent then
		return buildModeFolder
	end

	buildModeFolder = ReplicatedStorage:FindFirstChild("Build Mode")
		or workspace:FindFirstChild("Build Mode")
		or ReplicatedStorage:FindFirstChild("BuildMode")
		or workspace:FindFirstChild("BuildMode")

	return buildModeFolder
end

local function isRenderableTemplate(instance)
	if not instance then return false end
	if instance:IsA("BasePart") or instance:IsA("Model") then
		return true
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Model") then
			return true
		end
	end

	return false
end

local function getCategoryNameForTemplate(template)
	local categoryAttr = template:GetAttribute("Category")
	if type(categoryAttr) == "string" and #categoryAttr > 0 then
		return string.lower(categoryAttr)
	end

	local lowerName = string.lower(template.Name)
	if string.find(lowerName, "stool") then
		return "stools"
	end
	if string.find(lowerName, "bar") then
		return "bars"
	end

	return "all"
end

local function addTemplateToCategory(categoryName, template)
	if not template or not isRenderableTemplate(template) then
		return
	end

	if not categoryItems[categoryName] then
		categoryItems[categoryName] = {}
		table.insert(availableCategories, categoryName)
	end

	for _, existingTemplate in ipairs(categoryItems[categoryName]) do
		if existingTemplate.Name == template.Name then
			return
		end
	end

	table.insert(categoryItems[categoryName], template)
end

local function rebuildCatalogIndex()
	availableCategories = {}
	categoryItems = {}

	local resolvedBuildModeFolder = resolveBuildModeFolder()
	if resolvedBuildModeFolder and resolvedBuildModeFolder:IsA("Folder") then
		for _, categoryFolder in ipairs(resolvedBuildModeFolder:GetChildren()) do
			if categoryFolder:IsA("Folder") then
				local categoryName = string.lower(categoryFolder.Name)
				for _, template in ipairs(categoryFolder:GetChildren()) do
					addTemplateToCategory(categoryName, template)
				end
			end
		end
	end

	if #availableCategories == 0 then
		for _, template in ipairs(propTemplates:GetChildren()) do
			local categoryName = getCategoryNameForTemplate(template)
			addTemplateToCategory(categoryName, template)
		end
	end

	table.sort(availableCategories, function(a, b)
		if a == "bars" then return true end
		if b == "bars" then return false end
		if a == "stools" then return true end
		if b == "stools" then return false end
		return a < b
	end)
end

local function getCatalogFolder(categoryName)
	local resolvedBuildModeFolder = resolveBuildModeFolder()
	if resolvedBuildModeFolder and resolvedBuildModeFolder:IsA("Folder") then
		return resolvedBuildModeFolder:FindFirstChild(categoryName)
	end
	return nil
end

local function getTemplatesForCategory(categoryName)
	return categoryItems[categoryName] or {}
end

local function getTemplateForPlacement(itemName)
	local template = propTemplates:FindFirstChild(itemName)
	if template then
		return template
	end

	local bars = getCatalogFolder("bars")
	if bars then
		template = bars:FindFirstChild(itemName) or bars:FindFirstChild(itemName, true)
		if template then return template end
	end

	local stools = getCatalogFolder("stools")
	if stools then
		template = stools:FindFirstChild(itemName) or stools:FindFirstChild(itemName, true)
		if template then return template end
	end

	template = propTemplates:FindFirstChild(itemName, true)
	if template then
		return template
	end

	for _, templates in pairs(categoryItems) do
		for _, categoryTemplate in ipairs(templates) do
			if categoryTemplate.Name == itemName then
				return categoryTemplate
			end
		end
	end

	return nil
end

local function resolveRenderableInstance(source)
	if not source then return nil end
	if source:IsA("BasePart") or source:IsA("Model") then
		return source
	end

	for _, child in ipairs(source:GetDescendants()) do
		if child:IsA("Model") then
			return child
		end
	end

	for _, child in ipairs(source:GetDescendants()) do
		if child:IsA("BasePart") then
			return child
		end
	end

	return nil
end

local function getPreviewPrimaryPart(instance)
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function createItemPreview(previewFrame, source)
	previewFrame.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
	previewFrame.Ambient = Color3.fromRGB(210, 210, 210)
	previewFrame.LightColor = Color3.fromRGB(255, 255, 255)
	previewFrame.LightDirection = Vector3.new(-1, -1, -1)

	local renderSource = resolveRenderableInstance(source)
	if not renderSource then
		return false
	end

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = previewFrame

	local previewClone = renderSource:Clone()
	local primaryPart = getPreviewPrimaryPart(previewClone)
	if not primaryPart then
		previewClone:Destroy()
		return false
	end

	if previewClone:IsA("BasePart") then
		previewClone.Anchored = true
		previewClone.CFrame = CFrame.new(0, previewClone.Size.Y * 0.5, 0)
	else
		for _, desc in ipairs(previewClone:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.AssemblyLinearVelocity = Vector3.zero
				desc.AssemblyAngularVelocity = Vector3.zero
			end
		end
		previewClone:PivotTo(CFrame.new(0, 0, 0))
	end

	previewClone.Parent = worldModel

	local camera = Instance.new("Camera")
	previewFrame.CurrentCamera = camera
	camera.Parent = previewFrame

	local cframe, size
	if previewClone:IsA("Model") then
		cframe, size = previewClone:GetBoundingBox()
	else
		cframe, size = previewClone.CFrame, previewClone.Size
	end

	local maxDim = math.max(size.X, size.Y, size.Z)
	local distance = math.max(maxDim * 2.4, 3)
	camera.CFrame = CFrame.new(cframe.Position + Vector3.new(distance, distance * 0.75, distance), cframe.Position)
	camera.FieldOfView = 50
	return true
end

local function updateSelectionVisuals(propsContainer)
	for _, child in ipairs(propsContainer:GetChildren()) do
		if child:IsA("TextButton") then
			if child.Name == selectedTemplate then
				child.BackgroundColor3 = Color3.fromRGB(95, 140, 220)
			else
				child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			end
		end
	end
end

local function populateCategoryItems(screenGui, categoryName)
	local propsContainer = screenGui.MainFrame.PropsContainer
	for _, child in ipairs(propsContainer:GetChildren()) do
		if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	local templates = getTemplatesForCategory(categoryName)
	if #templates == 0 then
		warn("[BuildModeClient] No templates found for category " .. categoryName)
		propsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
		return
	end

	for _, template in ipairs(templates) do
		local propButton = Instance.new("TextButton")
		propButton.Name = template.Name
		propButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		propButton.Text = ""
		propButton.AutoButtonColor = false
		propButton.Parent = propsContainer

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = propButton

		local previewFrame = Instance.new("ViewportFrame")
		previewFrame.Size = UDim2.new(1, -8, 1, -36)
		previewFrame.Position = UDim2.new(0, 4, 0, 4)
		previewFrame.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
		previewFrame.BorderSizePixel = 0
		previewFrame.Parent = propButton

		local previewCorner = Instance.new("UICorner")
		previewCorner.CornerRadius = UDim.new(0, 6)
		previewCorner.Parent = previewFrame

		local previewOk = createItemPreview(previewFrame, template)
		if not previewOk then
			local noPreviewLabel = Instance.new("TextLabel")
			noPreviewLabel.Size = UDim2.fromScale(1, 1)
			noPreviewLabel.BackgroundTransparency = 1
			noPreviewLabel.Text = "No Preview"
			noPreviewLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
			noPreviewLabel.TextSize = 12
			noPreviewLabel.Font = Enum.Font.Gotham
			noPreviewLabel.Parent = previewFrame
		end

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -8, 0, 18)
		nameLabel.Position = UDim2.new(0, 4, 1, -30)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = template.Name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 12
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = propButton

		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(1, -8, 0, 16)
		priceLabel.Position = UDim2.new(0, 4, 1, -16)
		priceLabel.BackgroundTransparency = 1
		priceLabel.Text = "$" .. (template:GetAttribute("Price") or 0)
		priceLabel.TextColor3 = Color3.fromRGB(110, 255, 130)
		priceLabel.TextSize = 12
		priceLabel.Font = Enum.Font.GothamBold
		priceLabel.TextXAlignment = Enum.TextXAlignment.Left
		priceLabel.Parent = propButton

		propButton.MouseButton1Click:Connect(function()
			selectedTemplate = template.Name
			updateSelectionVisuals(propsContainer)
			onTemplateSelected()
		end)
	end

	local grid = propsContainer:FindFirstChildOfClass("UIGridLayout")
	if grid then
		propsContainer.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 8)
	end

	updateSelectionVisuals(propsContainer)
end

-- Create UI
local function createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BasementBuildUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	
	-- Main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1, -24, 0, 240)
	mainFrame.Position = UDim2.new(0, 12, 1, -252)
	mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = mainFrame
	
	local mainStroke = Instance.new("UIStroke")
	mainStroke.Thickness = 1
	mainStroke.Color = Color3.fromRGB(72, 72, 72)
	mainStroke.Parent = mainFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 240, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "Build Mode Catalog"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.Parent = mainFrame

	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, 14)
	headerPadding.Parent = title

	local tabsFrame = Instance.new("Frame")
	tabsFrame.Name = "TabsFrame"
	tabsFrame.Size = UDim2.new(1, -450, 0, 36)
	tabsFrame.Position = UDim2.new(0, 250, 0, 6)
	tabsFrame.BackgroundTransparency = 1
	tabsFrame.Parent = mainFrame

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 8)
	tabsLayout.Parent = tabsFrame

	local function createTabButton(tabName)
		local tabButton = Instance.new("TextButton")
		tabButton.Name = tabName
		tabButton.Size = UDim2.new(0, 96, 1, 0)
		tabButton.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
		tabButton.Text = string.upper(tabName)
		tabButton.TextColor3 = Color3.fromRGB(240, 240, 240)
		tabButton.TextSize = 13
		tabButton.Font = Enum.Font.GothamBold
		tabButton.Parent = tabsFrame

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 8)
		tabCorner.Parent = tabButton

		tabButton.MouseButton1Click:Connect(function()
			selectedCategory = tabName
			populateCategoryItems(screenGui, selectedCategory)

			for _, child in ipairs(tabsFrame:GetChildren()) do
				if child:IsA("TextButton") then
					if child.Name == selectedCategory then
						child.BackgroundColor3 = Color3.fromRGB(95, 140, 220)
					else
						child.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
					end
				end
			end
		end)

		return tabButton
	end

	rebuildCatalogIndex()
	if #availableCategories == 0 then
		warn("[BuildModeClient] No furniture templates found in PropTemplates or Build Mode")
	else
		if not categoryItems[selectedCategory] then
			selectedCategory = availableCategories[1]
		end

		for _, categoryName in ipairs(availableCategories) do
			local tabButton = createTabButton(categoryName)
			if categoryName == selectedCategory then
				tabButton.BackgroundColor3 = Color3.fromRGB(95, 140, 220)
			end
		end
	end
	
	-- Props container
	local propsContainer = Instance.new("ScrollingFrame")
	propsContainer.Name = "PropsContainer"
	propsContainer.Size = UDim2.new(1, -20, 1, -76)
	propsContainer.Position = UDim2.new(0, 10, 0, 50)
	propsContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	propsContainer.BorderSizePixel = 0
	propsContainer.ScrollBarThickness = 6
	propsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	propsContainer.Parent = mainFrame
	
	local containerCorner = Instance.new("UICorner")
	containerCorner.Parent = propsContainer

	local containerPadding = Instance.new("UIPadding")
	containerPadding.PaddingLeft = UDim.new(0, 8)
	containerPadding.PaddingRight = UDim.new(0, 8)
	containerPadding.PaddingTop = UDim.new(0, 8)
	containerPadding.PaddingBottom = UDim.new(0, 8)
	containerPadding.Parent = propsContainer
	
	local propsLayout = Instance.new("UIGridLayout")
	propsLayout.CellSize = UDim2.new(0, 126, 0, 128)
	propsLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	propsLayout.SortOrder = Enum.SortOrder.Name
	propsLayout.Parent = propsContainer

	propsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		propsContainer.CanvasSize = UDim2.new(0, 0, 0, propsLayout.AbsoluteContentSize.Y + 8)
	end)
	
	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 170, 0, 34)
	closeButton.Position = UDim2.new(1, -180, 0, 8)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.Text = "Exit Build Mode"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 14
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

	if #availableCategories > 0 then
		populateCategoryItems(screenGui, selectedCategory)
	end
	
	return screenGui
end

local ui = createUI()
local basementFloorCache = {}
local basementFloorCacheTime = 0

local function getBasementNumberFromInstance(instance)
	local current = instance
	while current and current ~= workspace do
		local num = tonumber(current.Name:match("Basement(%d+)"))
		if num then
			return num
		end
		current = current.Parent
	end
	return nil
end

local function getZoneInfoFromFloorPart(floorPart)
	if not floorPart or not floorPart:IsA("BasePart") then return nil end
	return {
		position = floorPart.Position,
		size = floorPart.Size,
		topY = floorPart.Position.Y + floorPart.Size.Y / 2,
		bottomY = floorPart.Position.Y - floorPart.Size.Y / 2,
	}
end

local function getBasementFloorCandidates()
	local now = os.clock()
	if now - basementFloorCacheTime < 2 and #basementFloorCache > 0 then
		return basementFloorCache
	end

	local floors = {}
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "ConcreteFloor" and descendant.Position.Y <= CONFIG.BASEMENT_FLOOR_Y_THRESHOLD then
			local basementNumber = getBasementNumberFromInstance(descendant)
			if basementNumber then
				table.insert(floors, {
					basementNumber = basementNumber,
					zoneInfo = getZoneInfoFromFloorPart(descendant),
				})
			end
		end
	end

	basementFloorCache = floors
	basementFloorCacheTime = now
	return basementFloorCache
end

-- Get physical grid lines from basement
local function getPhysicalGridParts()
	local basementsFolder = workspace:FindFirstChild("Basements")
	if not basementsFolder then return {} end

	local parts = {}
	local seen = {}

	for _, basementData in ipairs(getBasementFloorCandidates()) do
		local basement = basementsFolder:FindFirstChild("Basement" .. basementData.basementNumber)
		if basement then
			for _, descendant in ipairs(basement:GetDescendants()) do
				if descendant.Name == "PropGrid" then
					for _, part in ipairs(descendant:GetDescendants()) do
						if part:IsA("BasePart") and not seen[part] then
							seen[part] = true
							table.insert(parts, part)
						end
					end
				end
			end
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
	hoverVisualOffsets = nil
	
	if not selectedTemplate then return end
	
	local template = getTemplateForPlacement(selectedTemplate)
	if not template then return end
	local renderSource = resolveRenderableInstance(template)
	if not renderSource then return end

	hoverVisual = renderSource:Clone()
	hoverVisual.Name = "HoverVisual"
	hoverVisual.Parent = workspace.CurrentCamera

	if hoverVisual:IsA("BasePart") then
		hoverVisual.Anchored = true
		hoverVisual.CanCollide = false
		hoverVisual.CanQuery = false
		hoverVisual.Transparency = 0.5
		hoverVisual.Color = Color3.fromRGB(100, 255, 100)
		hoverVisual.Material = Enum.Material.Neon
		hoverVisualOffsets = {
			isModel = false,
			halfHeight = hoverVisual.Size.Y * 0.5,
		}
		return
	end

	if hoverVisual:IsA("Model") then
		for _, desc in ipairs(hoverVisual:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
				desc.CanQuery = false
				desc.Transparency = 0.5
				desc.Color = Color3.fromRGB(100, 255, 100)
				desc.Material = Enum.Material.Neon
				desc.AssemblyLinearVelocity = Vector3.zero
				desc.AssemblyAngularVelocity = Vector3.zero
			end
		end

		local pivot = hoverVisual:GetPivot()
		local bboxCFrame, bboxSize = hoverVisual:GetBoundingBox()
		local bottomY = bboxCFrame.Position.Y - bboxSize.Y * 0.5
		hoverVisualOffsets = {
			isModel = true,
			pivotToBBoxCenterXZ = Vector3.new(
				pivot.Position.X - bboxCFrame.Position.X,
				0,
				pivot.Position.Z - bboxCFrame.Position.Z
			),
			pivotToBottomY = pivot.Position.Y - bottomY,
		}
		return
	end

	hoverVisual:Destroy()
	hoverVisual = nil
end

-- Update hover visual when template changes
onTemplateSelected = function()
	if isBuildMode and selectedTemplate then
		createHoverVisual()
	elseif hoverVisual then
		hoverVisual:Destroy()
		hoverVisual = nil
	end
end

-- Get grid position from mouse
local function getGridPositionFromMouse()
	if not floorInfo then
		return nil, nil
	end

	local mouse = player:GetMouse()
	local ray = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
	local dirY = ray.Direction.Y

	if math.abs(dirY) < 0.00001 then
		return nil, nil
	end

	local t = (floorInfo.topY - ray.Origin.Y) / dirY
	if t <= 0 then
		return nil, nil
	end

	local hitPosition = ray.Origin + ray.Direction * t
	local gridX = math.floor((hitPosition.X - floorInfo.position.X + floorInfo.size.X / 2) / CONFIG.GRID_SIZE)
	local gridZ = math.floor((hitPosition.Z - floorInfo.position.Z + floorInfo.size.Z / 2) / CONFIG.GRID_SIZE)
	return gridX, gridZ, floorInfo, hitPosition
end

-- Toggle build mode
toggleBuildMode = function(enabled)
	isBuildMode = enabled
	ui.MainFrame.Visible = enabled
	propPlacementRemote:FireServer("SetBuildMode", enabled)

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
	
	local gridX, gridZ, snapFloorInfo = getGridPositionFromMouse()
	if gridX and gridZ then
		-- Update hover visual position
		if hoverVisual and selectedTemplate and hoverVisualOffsets then
			local useFloorInfo = snapFloorInfo or floorInfo
			local worldX = useFloorInfo.position.X - useFloorInfo.size.X / 2 + (gridX + 0.5) * CONFIG.GRID_SIZE
			local worldZ = useFloorInfo.position.Z - useFloorInfo.size.Z / 2 + (gridZ + 0.5) * CONFIG.GRID_SIZE
			local floorY = useFloorInfo.topY + 0.1

			if hoverVisualOffsets.isModel then
				local pivotPos = Vector3.new(
					worldX + hoverVisualOffsets.pivotToBBoxCenterXZ.X,
					floorY + hoverVisualOffsets.pivotToBottomY,
					worldZ + hoverVisualOffsets.pivotToBBoxCenterXZ.Z
				)
				hoverVisual:PivotTo(CFrame.new(pivotPos))
			else
				hoverVisual.Position = Vector3.new(worldX, floorY + hoverVisualOffsets.halfHeight, worldZ)
			end
		end
	end
end)

-- Handle mouse click to place prop
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 and isBuildMode and selectedTemplate then
		local gridX, gridZ, _, hitWorldPos = getGridPositionFromMouse()
		if gridX and gridZ then
			propPlacementRemote:FireServer("PlaceProp", currentBasementNumber, selectedTemplate, gridX, gridZ, 0, hitWorldPos)
		end
	end
	
	-- Right click to remove prop
	if input.UserInputType == Enum.UserInputType.MouseButton2 and isBuildMode then
		local gridX, gridZ = getGridPositionFromMouse()
		if gridX and gridZ then
			-- Find prop at this position
			for propId, propData in pairs(placedProps) do
				local template = getTemplateForPlacement(propData.templateName)
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

	for _, basementData in ipairs(getBasementFloorCandidates()) do
		local basementNumber = basementData.basementNumber
		local zoneInfo = basementData.zoneInfo
		if basementNumber and zoneInfo then
			local edgePadding = (currentBasementNumber == basementNumber) and CONFIG.BUILD_ZONE_EXIT_PADDING or CONFIG.BUILD_ZONE_ENTER_PADDING
			local inBasement = math.abs(position.X - zoneInfo.position.X) < zoneInfo.size.X / 2 + edgePadding
				and math.abs(position.Z - zoneInfo.position.Z) < zoneInfo.size.Z / 2 + edgePadding
				and position.Y < zoneInfo.topY + CONFIG.BUILD_ZONE_HEIGHT_PADDING
				and position.Y > zoneInfo.bottomY - CONFIG.BUILD_ZONE_HEIGHT_PADDING

			if inBasement then
				if currentBasementNumber ~= basementNumber then
					currentBasementNumber = basementNumber
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