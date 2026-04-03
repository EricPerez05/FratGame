-- BasementTeleport.lua
-- Place this script inside ServerScriptService
-- Requires two parts per house:
--   "ToBasement" part inside each House model in the Houses folder
--   "ToSpawn"    part inside each Basement model in the Basements folder
-- Only the owner of the house can use the teleport platforms

local Players = game:GetService("Players")

-- ============================================================
--  CONFIGURATION
-- ============================================================
local CONFIG = {
	HOUSES_FOLDER   = "Houses",
	BASEMENTS_FOLDER = "Basements",

	TO_BASEMENT_PART = "ToBasement",   -- Part name inside each House
	TO_SPAWN_PART    = "ToSpawn",      -- Part name inside each Basement

	-- Basement teleport positions (insert your positions here)
	-- Key = house number, Value = Vector3 position
	BASEMENT_POSITIONS = {
		[1] = Vector3.new(407.5, -26.5, 515),    -- REPLACE with Basement 1 position
		[2] = Vector3.new(-18.25, -27.5, 515),    -- REPLACE with Basement 2 position
		[3] = Vector3.new(210, -27.645, 925),    -- REPLACE with Basement 3 position
		[4] = Vector3.new(-400, -27.145, 925),    -- REPLACE with Basement 4 position
	},

	SPAWN_POSITION  = Vector3.new(195, -3.85, -254.009),  -- REPLACE with your spawn position
	TELEPORT_Y_OFFSET = 5,                   -- Height offset above target position
	DEBOUNCE_TIME   = 1.5,                   -- Seconds before player can teleport again
}
-- ============================================================

local housesFolder   = workspace:WaitForChild(CONFIG.HOUSES_FOLDER)
local basementsFolder = workspace:WaitForChild(CONFIG.BASEMENTS_FOLDER)

-- Shared debounce table
local debounce = {}

-- ----------------------------------------------------------------
-- getOwnerOfHouse(): returns the player who owns a given house number
-- This reads from the existing HouseClaim script's ownership
-- ----------------------------------------------------------------
local function getHouseNumberForPlayer(player)
	-- Check GameConfig shared playerHouses table first
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ok, GameConfig = pcall(function()
		return require(ReplicatedStorage:WaitForChild("GameConfig", 3))
	end)

	if ok and GameConfig and GameConfig.playerHouses then
		local house = GameConfig.playerHouses[player]
		if house then
			-- Extract house number from house model name (e.g. "House1" -> 1)
			local num = tonumber(house.Name:match("%d+"))
			return num
		end
	end
	return nil
end

-- ----------------------------------------------------------------
-- teleportPlayer(): safely move a player to a position
-- ----------------------------------------------------------------
local function teleportPlayer(player, position)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	rootPart.CFrame = CFrame.new(position + Vector3.new(0, CONFIG.TELEPORT_Y_OFFSET, 0))
end

-- ----------------------------------------------------------------
-- setupDebounce(): returns true if player can teleport, false if on cooldown
-- ----------------------------------------------------------------
local function checkDebounce(player)
	if debounce[player.UserId] then return false end
	debounce[player.UserId] = true
	task.delay(CONFIG.DEBOUNCE_TIME, function()
		debounce[player.UserId] = nil
	end)
	return true
end

-- ----------------------------------------------------------------
-- Setup ToBasement platforms inside each house
-- ----------------------------------------------------------------
for i = 1, 4 do
	local house = housesFolder:FindFirstChild("House" .. i)
	if not house then
		warn("[BasementTeleport] Could not find House" .. i)
		continue
	end

	local platform = house:FindFirstChild(CONFIG.TO_BASEMENT_PART)
	if not platform then
		warn("[BasementTeleport] Could not find " .. CONFIG.TO_BASEMENT_PART .. " in House" .. i)
		continue
	end

	platform.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- Only the house owner can use this platform
		local ownedHouseNum = getHouseNumberForPlayer(player)
		if ownedHouseNum ~= i then
			print("[BasementTeleport] " .. player.Name .. " does not own House" .. i)
			return
		end

		if not checkDebounce(player) then return end

		local targetPos = CONFIG.BASEMENT_POSITIONS[i]
		if not targetPos then
			warn("[BasementTeleport] No basement position set for House" .. i)
			return
		end

		teleportPlayer(player, targetPos)
		print("[BasementTeleport] " .. player.Name .. " teleported to Basement " .. i)
	end)
end

-- ----------------------------------------------------------------
-- Setup ToSpawn platforms inside each basement
-- ----------------------------------------------------------------
for i = 1, 4 do
	local basement = basementsFolder:FindFirstChild("Basement" .. i)
	if not basement then
		warn("[BasementTeleport] Could not find Basement" .. i)
		continue
	end

	local platform = basement:FindFirstChild(CONFIG.TO_SPAWN_PART)
	if not platform then
		warn("[BasementTeleport] Could not find " .. CONFIG.TO_SPAWN_PART .. " in Basement" .. i)
		continue
	end

	platform.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		if player:GetAttribute("BuildModeActive") then
			return
		end

		-- Only the owner of this basement can use this platform
		local ownedHouseNum = getHouseNumberForPlayer(player)
		if ownedHouseNum ~= i then
			print("[BasementTeleport] " .. player.Name .. " does not own Basement" .. i)
			return
		end

		if not checkDebounce(player) then return end

		teleportPlayer(player, CONFIG.SPAWN_POSITION)
		print("[BasementTeleport] " .. player.Name .. " teleported to spawn")
	end)
end

print("[BasementTeleport] Teleport system loaded for " .. 4 .. " houses.")