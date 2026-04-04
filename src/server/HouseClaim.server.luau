-- HouseClaimer.lua
-- Place this script inside ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CONFIG = GameConfig.HOUSES
GameConfig.playerHouses = GameConfig.playerHouses or {}

local housesFolder = workspace:WaitForChild(CONFIG.HOUSES_FOLDER)
if not housesFolder then
	warn("[HouseClaimer] Could not find Houses folder in Workspace.")
	return
end

local houseOwners = {}

local function getDoor(house)
	return house:FindFirstChild(CONFIG.DOOR_PART)
end

local function getDoorTouchPart(door)
	if not door then return nil end
	if door:IsA("BasePart") then
		return door
	end
	if door:IsA("Model") then
		return door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function applyDoorColor(part, colorValue)
	if typeof(colorValue) == "BrickColor" then
		part.BrickColor = colorValue
	elseif typeof(colorValue) == "Color3" then
		part.Color = colorValue
	end
end

local function setDoorState(house, locked)
	local door = getDoor(house)
	if not door then return end

	local targetColor = locked and CONFIG.LOCKED_COLOR or CONFIG.OPEN_COLOR
	if door:IsA("BasePart") then
		applyDoorColor(door, targetColor)
		return
	end

	if door:IsA("Model") then
		for _, desc in ipairs(door:GetDescendants()) do
			if desc:IsA("BasePart") then
				applyDoorColor(desc, targetColor)
			end
		end
	end
end

local function getPlayerHouse(player)
	for house, owner in pairs(houseOwners) do
		if owner == player then return house end
	end
	return nil
end

for _, house in ipairs(housesFolder:GetChildren()) do
	local door = getDoor(house)
	local doorTouchPart = getDoorTouchPart(door)
	if not doorTouchPart then
		warn("[HouseClaimer] House '" .. house.Name .. "' has no Door part — skipping.")
		continue
	end

	setDoorState(house, false)

	doorTouchPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		if houseOwners[house] then
			if houseOwners[house] ~= player then
				print("[HouseClaimer] " .. player.Name .. " tried to claim " .. house.Name .. " but it's taken.")
			end
			return
		end

		if getPlayerHouse(player) then
			print("[HouseClaimer] " .. player.Name .. " already owns a house.")
			return
		end

		houseOwners[house] = player
		GameConfig.playerHouses[player] = house
		setDoorState(house, true)
		print("[HouseClaimer] " .. player.Name .. " claimed " .. house.Name)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	local house = getPlayerHouse(player)
	if house then
		houseOwners[house] = nil
		GameConfig.playerHouses[player] = nil
		setDoorState(house, false)
		print("[HouseClaimer] " .. player.Name .. " left — " .. house.Name .. " is now available.")
	end
end)

print("[HouseClaimer] House system loaded with " .. #housesFolder:GetChildren() .. " houses.")