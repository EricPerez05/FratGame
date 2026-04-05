-- BuildSystemServer.lua
-- Place this Script inside ServerScriptService
-- Combines: BasementPropManager, PlaceBuildItem, DeleteFurniture, PurchaseHandler

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- ============================================================
--  CONFIGURATION
-- ============================================================
local CONFIG = {
	GRID_SIZE          = 4,
	BASEMENTS_FOLDER   = "Basements",
	PROPS_FOLDER_NAME  = "PlacedProps",
	PROP_TEMPLATES     = "PropTemplates",
	AUTO_SAVE_INTERVAL = 60,
	FURNITURE_FOLDER   = "Furniture",
}

-- ============================================================
--  DATASTORES
-- ============================================================
local propDataStore = DataStoreService:GetDataStore("PlayerBasementProps")

-- ============================================================
--  REMOTE EVENTS
-- ============================================================
local propPlacementRemote = ReplicatedStorage:WaitForChild("PropPlacementRemote")
local deleteEvent          = ReplicatedStorage:WaitForChild("DeleteFurniture")
local purchaseItemRF       = ReplicatedStorage:WaitForChild("PurchaseItem")

-- ============================================================
--  REFERENCES
-- ============================================================
local propTemplates   = ReplicatedStorage:WaitForChild(CONFIG.PROP_TEMPLATES)
local basementsFolder = workspace:WaitForChild(CONFIG.BASEMENTS_FOLDER)
local buildModeFolder = nil

-- ============================================================
--  STORE DATA
-- ============================================================
local ServerStoreData = {
	["items"] = {
		{ ID = "DoubleXPPotion", Name = "Double XP Potion", Cost = 5000,  ReqLevel = 10 },
		{ ID = "GoldenBackpack", Name = "Golden Backpack",  Cost = 25000, ReqLevel = 15 },
		{ ID = "Locked3",        Name = "Item 3",           Cost = 50000, ReqLevel = 20 },
		{ ID = "Locked4",        Name = "Item 4",           Cost = 75000, ReqLevel = 20 },
	},
	["boosts"] = {}
}

-- ============================================================
--  MEMORY
-- ============================================================
local playerProps     = {}  -- [userId] = { [propId] = { ... } }
local playerBasements = {}  -- [userId] = basementNumber
local playerPurchases = {}  -- [userId] = { itemId, ... }

-- ============================================================
--  HELPERS
-- ============================================================
local function getHouseNumberForPlayer(player)
	if playerBasements[player.UserId] then
		return playerBasements[player.UserId]
	end
	if GameConfig and GameConfig.playerHouses then
		local house = GameConfig.playerHouses[player]
		if house then
			local num = tonumber(house.Name:match("%d+"))
			playerBasements[player.UserId] = num
			return num
		end
	end
	return nil
end

local function getBasementFloorInfo(basementNumber)
	local basement = basementsFolder:FindFirstChild("Basement" .. basementNumber)
	if not basement then return nil end

	local bestConcrete = nil
	local bestConcreteArea = -1
	local bestAnyFloor = nil
	local bestAnyArea = -1

	for _, descendant in ipairs(basement:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name:lower():find("floor") then
			local area = descendant.Size.X * descendant.Size.Z

			if area > bestAnyArea then
				bestAnyArea = area
				bestAnyFloor = descendant
			end

			if descendant.Name == "ConcreteFloor" and area > bestConcreteArea then
				bestConcreteArea = area
				bestConcrete = descendant
			end
		end
	end

	local floor = bestConcrete or bestAnyFloor
	if not floor then return nil end

	return {
		position = floor.Position,
		size = floor.Size,
		topY = floor.Position.Y + floor.Size.Y / 2,
		bottomY = floor.Position.Y - floor.Size.Y / 2,
	}
end

local function gridToWorld(gridX, gridZ, floorInfo)
	local worldX = floorInfo.position.X - floorInfo.size.X / 2 + (gridX + 0.5) * CONFIG.GRID_SIZE
	local worldZ = floorInfo.position.Z - floorInfo.size.Z / 2 + (gridZ + 0.5) * CONFIG.GRID_SIZE
	return Vector3.new(worldX, floorInfo.topY + 0.1, worldZ)
end

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

local function getTemplateForPlacement(templateName)
	local template = propTemplates:FindFirstChild(templateName) or propTemplates:FindFirstChild(templateName, true)
	if template then
		return template
	end

	local resolvedBuildModeFolder = resolveBuildModeFolder()
	if resolvedBuildModeFolder then
		template = resolvedBuildModeFolder:FindFirstChild(templateName, true)
		if template then
			return template
		end
	end

	return nil
end

local function placeInstanceAtWorld(instance, worldPos, rotation)
	if instance:IsA("BasePart") then
		instance.Position = worldPos
		instance.Rotation = Vector3.new(0, rotation, 0)
		return true
	end

	if instance:IsA("Model") then
		local _, bboxSize = instance:GetBoundingBox()
		local pivotPos = Vector3.new(worldPos.X, worldPos.Y + bboxSize.Y * 0.5, worldPos.Z)
		instance:PivotTo(CFrame.new(pivotPos) * CFrame.Angles(0, math.rad(rotation), 0))
		return true
	end

	local model = instance:FindFirstChildWhichIsA("Model", true)
	if model then
		return placeInstanceAtWorld(model, worldPos, rotation)
	end

	local part = instance:FindFirstChildWhichIsA("BasePart", true)
	if part then
		local holder = Instance.new("Model")
		holder.Name = instance.Name
		instance.Parent = holder
		placeInstanceAtWorld(holder, worldPos, rotation)
		return true
	end

	return false
end

local function getTemplateGridSize(templateName)
	local template = getTemplateForPlacement(templateName)
	if not template then
		return 1
	end

	local gridSize = template:GetAttribute("GridSize")
	if type(gridSize) == "number" and gridSize >= 1 then
		return math.floor(gridSize)
	end

	return 1
end

local function isGridPositionValid(gridX, gridZ, floorInfo)
	local maxGridX = math.floor(floorInfo.size.X / CONFIG.GRID_SIZE) - 1
	local maxGridZ = math.floor(floorInfo.size.Z / CONFIG.GRID_SIZE) - 1
	return gridX >= 0 and gridX <= maxGridX and gridZ >= 0 and gridZ <= maxGridZ
end

local function normalizePlacementGrid(gridX, gridZ, floorInfo, gridSize)
	if type(gridX) ~= "number" or type(gridZ) ~= "number" then
		return nil, nil
	end

	local maxGridX = math.floor(floorInfo.size.X / CONFIG.GRID_SIZE) - 1
	local maxGridZ = math.floor(floorInfo.size.Z / CONFIG.GRID_SIZE) - 1
	local maxOriginX = maxGridX - (gridSize - 1)
	local maxOriginZ = maxGridZ - (gridSize - 1)

	if maxOriginX < 0 or maxOriginZ < 0 then
		return nil, nil
	end

	local snappedX = math.clamp(math.floor(gridX), 0, maxOriginX)
	local snappedZ = math.clamp(math.floor(gridZ), 0, maxOriginZ)
	return snappedX, snappedZ
end

local function isGridPositionOccupied(userId, gridX, gridZ, floorKey, excludePropId)
	local props = playerProps[userId]
	if not props then return false end
	for propId, propData in pairs(props) do
		if propId ~= excludePropId then
			local gridSize = getTemplateGridSize(propData.templateName)
			for dx = 0, gridSize - 1 do
				for dz = 0, gridSize - 1 do
					if propData.gridX + dx == gridX and propData.gridZ + dz == gridZ then
						return true, propId
					end
				end
			end
		end
	end
	return false
end

-- ============================================================
--  PROP PLACEMENT
-- ============================================================
local function placeProp(player, basementNumber, templateName, gridX, gridZ, rotation, hitWorldPos)
	local playerHouseNum = getHouseNumberForPlayer(player)
	if playerHouseNum ~= basementNumber then
		return false, "You don't own this basement"
	end

	local userId  = player.UserId
	local template = getTemplateForPlacement(templateName)
	if not template then return false, "Invalid prop template" end

	local floorInfo = getBasementFloorInfo(basementNumber)
	if not floorInfo then return false, "Basement floor not found" end

	local gridSize = getTemplateGridSize(templateName)
	local normalizedGridX, normalizedGridZ = normalizePlacementGrid(gridX, gridZ, floorInfo, gridSize)
	if normalizedGridX == nil or normalizedGridZ == nil then
		return false, "Invalid grid position"
	end

	gridX, gridZ = normalizedGridX, normalizedGridZ

	if not isGridPositionValid(gridX, gridZ, floorInfo) then
		return false, "Invalid grid position"
	end

	for dx = 0, gridSize - 1 do
		for dz = 0, gridSize - 1 do
			local occupied = isGridPositionOccupied(userId, gridX + dx, gridZ + dz, nil)
			if occupied then return false, "Position is occupied" end
		end
	end

	local worldPos = gridToWorld(gridX, gridZ, floorInfo)
	local prop = template:Clone()
	prop.Name = templateName

	if not placeInstanceAtWorld(prop, worldPos, rotation) then
		prop:Destroy()
		return false, "Template has no placeable geometry"
	end

	local propId = HttpService:GenerateGUID(false)
	prop:SetAttribute("PropId", propId)
	prop:SetAttribute("GridX",  gridX)
	prop:SetAttribute("GridZ",  gridZ)
	prop:SetAttribute("Owner",  userId)

	local basement   = basementsFolder:FindFirstChild("Basement" .. basementNumber)
	local propsFolder = basement:FindFirstChild(CONFIG.PROPS_FOLDER_NAME)
	if not propsFolder then
		propsFolder = Instance.new("Folder")
		propsFolder.Name   = CONFIG.PROPS_FOLDER_NAME
		propsFolder.Parent = basement
	end
	prop.Parent = propsFolder

	if not playerProps[userId] then playerProps[userId] = {} end
	playerProps[userId][propId] = {
		templateName  = templateName,
		gridX         = gridX,
		gridZ         = gridZ,
		rotation      = rotation,
		basementNumber = basementNumber,
		instance      = prop
	}

	return true, propId
end

local function removeProp(player, basementNumber, propId)
	local playerHouseNum = getHouseNumberForPlayer(player)
	if playerHouseNum ~= basementNumber then
		return false, "You don't own this basement"
	end

	local props = playerProps[player.UserId]
	if not props or not props[propId] then return false, "Prop not found" end

	if props[propId].instance then
		props[propId].instance:Destroy()
	end
	props[propId] = nil
	return true
end

-- ============================================================
--  DATASTORE SAVE / LOAD
-- ============================================================
local function savePlayerProps(userId)
	local props = playerProps[userId]
	if not props then return end
	local data = {}
	for propId, propData in pairs(props) do
		table.insert(data, {
			propId        = propId,
			templateName  = propData.templateName,
			gridX         = propData.gridX,
			gridZ         = propData.gridZ,
			rotation      = propData.rotation,
			basementNumber = propData.basementNumber
		})
	end
	local ok, err = pcall(function()
		propDataStore:SetAsync("Player_" .. userId, data)
	end)
	if not ok then
		warn("[ServerHandlers] Failed to save props for user " .. tostring(userId) .. ": " .. tostring(err))
	end
end

local function loadPlayerProps(player)
	local userId  = player.UserId
	local basementNumber = getHouseNumberForPlayer(player)
	if not basementNumber then
		return false
	end

	local success, data = pcall(function()
		return propDataStore:GetAsync("Player_" .. userId)
	end)
	if not success then
		warn("[ServerHandlers] Failed to load props for " .. player.Name)
		return false
	end
	if not data then
		playerProps[userId] = {}
		return true
	end

	playerProps[userId] = {}

	for _, propData in ipairs(data) do
		if propData.basementNumber == basementNumber then
			local template  = getTemplateForPlacement(propData.templateName)
			local floorInfo = getBasementFloorInfo(basementNumber)
			if template and floorInfo then
				local worldPos = gridToWorld(propData.gridX, propData.gridZ, floorInfo)
				local prop = template:Clone()
				if not placeInstanceAtWorld(prop, worldPos, propData.rotation) then
					prop:Destroy()
					continue
				end
				prop:SetAttribute("PropId", propData.propId)
				prop:SetAttribute("GridX",  propData.gridX)
				prop:SetAttribute("GridZ",  propData.gridZ)

				local basement   = basementsFolder:FindFirstChild("Basement" .. basementNumber)
				local propsFolder = basement:FindFirstChild(CONFIG.PROPS_FOLDER_NAME)
				if not propsFolder then
					propsFolder = Instance.new("Folder")
					propsFolder.Name   = CONFIG.PROPS_FOLDER_NAME
					propsFolder.Parent = basement
				end
				prop.Parent = propsFolder

				playerProps[userId][propData.propId] = {
					templateName  = propData.templateName,
					gridX         = propData.gridX,
					gridZ         = propData.gridZ,
					rotation      = propData.rotation,
					basementNumber = basementNumber,
					instance      = prop
				}
			end
		end
	end
	print("[ServerHandlers] Loaded props for " .. player.Name)
	return true
end

local function queueLoadPlayerProps(player)
	task.spawn(function()
		for _ = 1, 30 do
			if not player.Parent then
				return
			end

			if loadPlayerProps(player) then
				return
			end

			task.wait(1)
		end
		warn("[ServerHandlers] Timed out waiting to load props for " .. player.Name)
	end)
end

local function saveAllPlayers()
	for userId in pairs(playerProps) do
		savePlayerProps(userId)
	end
end

-- ============================================================
--  PROP PLACEMENT REMOTE
-- ============================================================
propPlacementRemote.OnServerEvent:Connect(function(player, action, ...)
	local args = {...}
	if action == "PlaceProp" then
		local basementNumber, templateName, gridX, gridZ, rotation, hitWorldPos = unpack(args)
		local success, result = placeProp(player, basementNumber, templateName, gridX, gridZ, rotation, hitWorldPos)
		propPlacementRemote:FireClient(player, "PlacePropResult", success, result)

	elseif action == "RemoveProp" then
		local basementNumber, propId = unpack(args)
		local success, result = removeProp(player, basementNumber, propId)
		propPlacementRemote:FireClient(player, "RemovePropResult", success, result)

	elseif action == "GetBasementProps" then
		local basementNumber = args[1]
		if getHouseNumberForPlayer(player) ~= basementNumber then
			propPlacementRemote:FireClient(player, "BasementPropsData", basementNumber, {})
			return
		end
		local props = playerProps[player.UserId] or {}
		local propsList = {}
		for propId, propData in pairs(props) do
			if propData.basementNumber == basementNumber then
				table.insert(propsList, {
					propId       = propId,
					templateName = propData.templateName,
					gridX        = propData.gridX,
					gridZ        = propData.gridZ,
					rotation     = propData.rotation
				})
			end
		end
		propPlacementRemote:FireClient(player, "BasementPropsData", basementNumber, propsList)

	elseif action == "GetFloorInfo" then
		local basementNumber = args[1]
		if getHouseNumberForPlayer(player) ~= basementNumber then
			propPlacementRemote:FireClient(player, "FloorInfoData", basementNumber, nil)
			return
		end
		local floorInfo = getBasementFloorInfo(basementNumber)
		propPlacementRemote:FireClient(player, "FloorInfoData", basementNumber, floorInfo)

	elseif action == "SetBuildMode" then
		local isEnabled = args[1] == true
		player:SetAttribute("BuildModeActive", isEnabled)
	end
end)

-- ============================================================
--  DELETE FURNITURE
-- ============================================================
deleteEvent.OnServerEvent:Connect(function(player, furnitureItem)
	if not furnitureItem or not furnitureItem.Parent then return end

	local furnitureFolder = workspace:FindFirstChild(CONFIG.FURNITURE_FOLDER)
	if not furnitureFolder then return end

	local current = furnitureItem
	while current do
		if current.Parent == furnitureFolder then
			print(player.Name .. " deleted " .. furnitureItem.Name)
			furnitureItem:Destroy()
			return
		end
		current = current.Parent
	end
	warn("Item is not in Furniture folder:", furnitureItem.Name)
end)

-- ============================================================
--  STORE PURCHASES
-- ============================================================
purchaseItemRF.OnServerInvoke = function(player, category, itemId)
	if type(category) ~= "string" or type(itemId) ~= "string" then
		return false, "Invalid request"
	end

	-- Get money from MoneySystem via GameConfig
	local data = GameConfig.getPlayerData and GameConfig.getPlayerData(player)
	if not data then return false, "Player data not found" end

	local leaderstats = player:FindFirstChild("leaderstats")
	local level = leaderstats and leaderstats:FindFirstChild("Level")
	if not level then return false, "Missing Level stat" end

	local categoryItems = ServerStoreData[category]
	if not categoryItems then return false, "Invalid category" end

	local itemData
	for _, item in ipairs(categoryItems) do
		if item.ID == itemId then itemData = item break end
	end
	if not itemData then return false, "Item not found" end

	if level.Value < itemData.ReqLevel then
		return false, "Level " .. itemData.ReqLevel .. " required"
	end
	if data.money < itemData.Cost then
		return false, "Not enough money"
	end

	-- Deduct money directly from MoneySystem data
	data.money = data.money - itemData.Cost

	if not playerPurchases[player.UserId] then
		playerPurchases[player.UserId] = {}
	end
	table.insert(playerPurchases[player.UserId], itemId)

	print(player.Name .. " purchased " .. itemData.Name .. " for $" .. itemData.Cost)
	return true, "Successfully purchased " .. itemData.Name
end

-- ============================================================
--  PLAYER EVENTS
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("BuildModeActive", false)
	queueLoadPlayerProps(player)
end)

Players.PlayerRemoving:Connect(function(player)
	player:SetAttribute("BuildModeActive", false)
	savePlayerProps(player.UserId)
	playerProps[player.UserId]     = nil
	playerBasements[player.UserId] = nil
	playerPurchases[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	queueLoadPlayerProps(player)
end

-- ============================================================
--  AUTO SAVE + SHUTDOWN
-- ============================================================
task.spawn(function()
	while true do
		task.wait(CONFIG.AUTO_SAVE_INTERVAL)
		saveAllPlayers()
		print("[ServerHandlers] Auto-saved all player props")
	end
end)

game:BindToClose(saveAllPlayers)

print("[ServerHandlers] Loaded successfully")