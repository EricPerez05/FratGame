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

	local mainRoom = basement:FindFirstChild("Main Room")
	if mainRoom then
		local floor = mainRoom:FindFirstChild("ConcreteFloor")
		if floor then
			return {
				position = floor.Position,
				size     = floor.Size,
				topY     = floor.Position.Y + floor.Size.Y / 2
			}
		end
	end

	for _, child in pairs(basement:GetDescendants()) do
		if child:IsA("BasePart") and child.Name:lower():find("floor") then
			return {
				position = child.Position,
				size     = child.Size,
				topY     = child.Position.Y + child.Size.Y / 2
			}
		end
	end
	return nil
end

local function gridToWorld(gridX, gridZ, floorInfo)
	local worldX = floorInfo.position.X - floorInfo.size.X / 2 + (gridX + 0.5) * CONFIG.GRID_SIZE
	local worldZ = floorInfo.position.Z - floorInfo.size.Z / 2 + (gridZ + 0.5) * CONFIG.GRID_SIZE
	return Vector3.new(worldX, floorInfo.topY + 0.1, worldZ)
end

local function isGridPositionValid(gridX, gridZ, floorInfo)
	local maxGridX = math.floor(floorInfo.size.X / CONFIG.GRID_SIZE) - 1
	local maxGridZ = math.floor(floorInfo.size.Z / CONFIG.GRID_SIZE) - 1
	return gridX >= 0 and gridX <= maxGridX and gridZ >= 0 and gridZ <= maxGridZ
end

local function isGridPositionOccupied(userId, gridX, gridZ, excludePropId)
	local props = playerProps[userId]
	if not props then return false end
	for propId, propData in pairs(props) do
		if propId ~= excludePropId then
			local template = propTemplates:FindFirstChild(propData.templateName)
			if template then
				local gridSize = template:GetAttribute("GridSize") or 1
				for dx = 0, gridSize - 1 do
					for dz = 0, gridSize - 1 do
						if propData.gridX + dx == gridX and propData.gridZ + dz == gridZ then
							return true, propId
						end
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
local function placeProp(player, basementNumber, templateName, gridX, gridZ, rotation)
	local playerHouseNum = getHouseNumberForPlayer(player)
	if playerHouseNum ~= basementNumber then
		return false, "You don't own this basement"
	end

	local userId  = player.UserId
	local template = propTemplates:FindFirstChild(templateName)
	if not template then return false, "Invalid prop template" end

	local floorInfo = getBasementFloorInfo(basementNumber)
	if not floorInfo then return false, "Basement floor not found" end

	if not isGridPositionValid(gridX, gridZ, floorInfo) then
		return false, "Invalid grid position"
	end

	local gridSize = template:GetAttribute("GridSize") or 1
	for dx = 0, gridSize - 1 do
		for dz = 0, gridSize - 1 do
			local occupied = isGridPositionOccupied(userId, gridX + dx, gridZ + dz)
			if occupied then return false, "Position is occupied" end
		end
	end

	local worldPos = gridToWorld(gridX, gridZ, floorInfo)
	local prop = template:Clone()
	prop.Name     = templateName
	prop.Position = worldPos
	prop.Rotation = Vector3.new(0, rotation, 0)

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
	pcall(function()
		propDataStore:SetAsync("Player_" .. userId, data)
	end)
end

local function loadPlayerProps(player)
	local userId  = player.UserId
	local success, data = pcall(function()
		return propDataStore:GetAsync("Player_" .. userId)
	end)
	if not success or not data then return end

	playerProps[userId] = {}
	local basementNumber = getHouseNumberForPlayer(player)
	if not basementNumber then return end

	for _, propData in ipairs(data) do
		if propData.basementNumber == basementNumber then
			local template  = propTemplates:FindFirstChild(propData.templateName)
			local floorInfo = getBasementFloorInfo(basementNumber)
			if template and floorInfo then
				local worldPos = gridToWorld(propData.gridX, propData.gridZ, floorInfo)
				local prop = template:Clone()
				prop.Position = worldPos
				prop.Rotation = Vector3.new(0, propData.rotation, 0)
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
		local basementNumber, templateName, gridX, gridZ, rotation = unpack(args)
		local success, result = placeProp(player, basementNumber, templateName, gridX, gridZ, rotation)
		propPlacementRemote:FireClient(player, "PlacePropResult", success, result)

	elseif action == "RemoveProp" then
		local basementNumber, propId = unpack(args)
		local success, result = removeProp(player, basementNumber, propId)
		propPlacementRemote:FireClient(player, "RemovePropResult", success, result)

	elseif action == "GetBasementProps" then
		local basementNumber = args[1]
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
		local floorInfo = getBasementFloorInfo(args[1])
		propPlacementRemote:FireClient(player, "FloorInfoData", args[1], floorInfo)
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
	task.wait(1)
	loadPlayerProps(player)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerProps(player.UserId)
	playerProps[player.UserId]     = nil
	playerBasements[player.UserId] = nil
	playerPurchases[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		task.wait(1)
		loadPlayerProps(player)
	end)
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