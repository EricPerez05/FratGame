-- MoneySystem.lua
-- Place this script inside ServerScriptService
-- Handles money generation, recruited member storage, and DataStore saving

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- ============================================================
--  CONFIGURATION
-- ============================================================
local CONFIG = {
	MONEY_TICK     = 1,       -- How often money is generated (seconds)
	AUTOSAVE_INTERVAL = 30,  -- Auto-save every 5 minutes
	DATASTORE_NAME = "FratGameData_v1",
}
-- ============================================================

local dataStore = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)

-- Remote event to update client money UI
local popupEvents = ReplicatedStorage:WaitForChild("PopupEvents")
local moneyUpdate = popupEvents:FindFirstChild("MoneyUpdate")
if not moneyUpdate then
	moneyUpdate = Instance.new("RemoteEvent")
	moneyUpdate.Name = "MoneyUpdate"
	moneyUpdate.Parent = popupEvents
end

-- Per-player data stored in memory
-- key = player, value = { money, roster = { npcName, ... } }
local playerData = {}

-- ----------------------------------------------------------------
-- getDefaultData(): fresh data for a new player
-- ----------------------------------------------------------------
local function getDefaultData()
	return {
		money  = 0,
		roster = {},   -- list of recruited NPC names
	}
end

-- ----------------------------------------------------------------
-- loadData(): load from DataStore or return defaults
-- ----------------------------------------------------------------
local function loadData(player)
	local success, data = pcall(function()
		return dataStore:GetAsync("player_" .. player.UserId)
	end)

	if success and data then
		data.roster  = data.roster or {}
		data.level   = data.level or 1
		data.xp      = data.xp or 0
		data.xpToNext = data.xpToNext or 100
		playerData[player] = data

		-- Restore XP and level once leaderstats exist
		task.spawn(function()
			local leaderstats = player:WaitForChild("leaderstats", 10)
			if not leaderstats then return end

			local levelStat = leaderstats:WaitForChild("Level", 10)
			local xpStat    = leaderstats:WaitForChild("XP", 10)
			local xpToNext  = player:WaitForChild("XPToNext", 10)

			if levelStat then levelStat.Value = data.level end
			if xpStat    then xpStat.Value    = data.xp    end
			if xpToNext  then xpToNext.Value  = data.xpToNext end

			print("[MoneySystem] Restored Level " .. data.level .. " and " .. data.xp .. " XP for " .. player.Name)
		end)

		print("[MoneySystem] Loaded data for " .. player.Name)
	else
		playerData[player] = getDefaultData()
		if not success then
			warn("[MoneySystem] Failed to load data for " .. player.Name .. " — using defaults.")
		end
	end
end

-- ----------------------------------------------------------------
-- saveData(): save to DataStore
-- ----------------------------------------------------------------
local function saveData(player)
	local data = playerData[player]
	if not data then return end

	-- Pull current XP and level and add to save data
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		data.level = leaderstats:FindFirstChild("Level") and leaderstats.Level.Value or 1
		data.xp    = leaderstats:FindFirstChild("XP") and leaderstats.XP.Value or 0
	end
	local xpToNext = player:FindFirstChild("XPToNext")
	if xpToNext then
		data.xpToNext = xpToNext.Value
	end

	local success, err = pcall(function()
		dataStore:SetAsync("player_" .. player.UserId, data)
	end)

	if success then
		print("[MoneySystem] Saved data for " .. player.Name)
	else
		warn("[MoneySystem] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

-- ----------------------------------------------------------------
-- getMoneyPerSecond(): total money/sec from all recruited NPCs
-- ----------------------------------------------------------------
local function getMoneyPerSecond(player)
	local data = playerData[player]
	if not data then return 0 end

	local total = 0
	for _, npcName in ipairs(data.roster) do
		local npcData = GameConfig.getNPCData(npcName)
		if npcData and npcData.MoneyPerSecond then
			total = total + npcData.MoneyPerSecond
		end
	end
	return total
end

-- ----------------------------------------------------------------
-- addToRoster(): called by RecruitmentSystem when NPC is recruited
-- ----------------------------------------------------------------
local function addToRoster(player, npcName)
	local data = playerData[player]
	if not data then return end

	table.insert(data.roster, npcName)
	print("[MoneySystem] Added " .. npcName .. " to " .. player.Name .. "'s roster.")

	-- Update client UI
	local mps = getMoneyPerSecond(player)
	moneyUpdate:FireClient(player, data.money, mps, data.roster)
end

-- ----------------------------------------------------------------
-- startMoneyGeneration(): give money every second while in game
-- ----------------------------------------------------------------
local function startMoneyGeneration(player)
	task.spawn(function()
		while player and player.Parent do
			task.wait(CONFIG.MONEY_TICK)

			local data = playerData[player]
			if not data then break end

			local mps = getMoneyPerSecond(player)
			if mps > 0 then
				data.money = data.money + mps

				-- Fire client to update UI
				moneyUpdate:FireClient(player, data.money, mps, data.roster)
			end
		end
	end)
end

-- ----------------------------------------------------------------
-- Auto-save loop
-- ----------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(CONFIG.AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
		print("[MoneySystem] Auto-saved all player data.")
	end
end)

-- ----------------------------------------------------------------
-- Player added/removing
-- ----------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	loadData(player)
	startMoneyGeneration(player)

	-- Send initial data to client once they're fully loaded
	player.CharacterAdded:Connect(function()
		task.wait(1)
		local data = playerData[player]
		if data then
			moneyUpdate:FireClient(player, data.money, getMoneyPerSecond(player), data.roster)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player] = nil
end)

-- Handle existing players if script loads late
for _, player in ipairs(Players:GetPlayers()) do
	loadData(player)
	startMoneyGeneration(player)
end

-- ----------------------------------------------------------------
-- Expose functions for other scripts
-- ----------------------------------------------------------------
GameConfig.addToRoster   = addToRoster
GameConfig.getPlayerData = function(player) return playerData[player] end

print("[MoneySystem] Money system loaded.")