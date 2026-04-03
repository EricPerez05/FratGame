-- HouseClaimer.lua
-- Place this script inside ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CONFIG = GameConfig.HOUSES

local housesFolder = workspace:WaitForChild(CONFIG.HOUSES_FOLDER)
if not housesFolder then
	warn("[HouseClaimer] Could not find Houses folder in Workspace.")
	return
end

local houseOwners = {}

local function getDoor(house)
	return house:FindFirstChild(CONFIG.DOOR_PART)
end

local function setDoorState(house, locked)
	local door = getDoor(house)
	if not door then return end
	door.BrickColor = locked and CONFIG.LOCKED_COLOR or CONFIG.OPEN_COLOR
end

local function getPlayerHouse(player)
	for house, owner in pairs(houseOwners) do
		if owner == player then return house end
	end
	return nil
end

for _, house in ipairs(housesFolder:GetChildren()) do
	local door = getDoor(house)
	if not door then
		warn("[HouseClaimer] House '" .. house.Name .. "' has no Door part — skipping.")
		continue
	end

	setDoorState(house, false)

	door.Touched:Connect(function(hit)
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
		setDoorState(house, true)
		print("[HouseClaimer] " .. player.Name .. " claimed " .. house.Name)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	local house = getPlayerHouse(player)
	if house then
		houseOwners[house] = nil
		setDoorState(house, false)
		print("[HouseClaimer] " .. player.Name .. " left — " .. house.Name .. " is now available.")
	end
end)

print("[HouseClaimer] House system loaded with " .. #housesFolder:GetChildren() .. " houses.")