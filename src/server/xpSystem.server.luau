-- XPSystem.lua
-- Place this script inside ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for PopupEvents with timeout and retry
local popupEvents = ReplicatedStorage:FindFirstChild("PopupEvents")
if not popupEvents then
	popupEvents = ReplicatedStorage:WaitForChild("PopupEvents", 30)
end
if not popupEvents then
	warn("[XPSystem] PopupEvents not found after 30 seconds!")
	return
end

local xpEvent = popupEvents:FindFirstChild("XPGained")
if not xpEvent then
	xpEvent = popupEvents:WaitForChild("XPGained", 10)
end
if not xpEvent then
	warn("[XPSystem] XPGained event not found!")
	return
end

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CONFIG = GameConfig.XP

local npcCooldowns = {}

-- ----------------------------------------------------------------
-- setupLeaderboard(): create stats on the player
-- ----------------------------------------------------------------
local function setupLeaderboard(player)
	-- Prevent duplicate leaderstats
	if player:FindFirstChild("leaderstats") then return end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = leaderstats

	local xp = Instance.new("IntValue")
	xp.Name = "XP"
	xp.Value = 0
	xp.Parent = leaderstats

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = 1000 -- Starting money
	money.Parent = leaderstats

	local xpToNext = Instance.new("IntValue")
	xpToNext.Name = "XPToNext"
	xpToNext.Value = GameConfig.getXPForLevel(2)
	xpToNext.Parent = player
end

-- ----------------------------------------------------------------
-- addXP(): give XP and handle level ups
-- ----------------------------------------------------------------
local function addXP(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local levelStat = leaderstats:FindFirstChild("Level")
	local xpStat    = leaderstats:FindFirstChild("XP")
	local xpToNext  = player:FindFirstChild("XPToNext")
	if not levelStat or not xpStat or not xpToNext then return end

	if levelStat.Value >= CONFIG.MAX_LEVEL then return end

	xpStat.Value = xpStat.Value + amount

	while xpStat.Value >= xpToNext.Value and levelStat.Value < CONFIG.MAX_LEVEL do
		xpStat.Value    = xpStat.Value - xpToNext.Value
		levelStat.Value = levelStat.Value + 1
		xpToNext.Value  = GameConfig.getXPForLevel(levelStat.Value + 1)
		print(player.Name .. " leveled up to Level " .. levelStat.Value
			.. "! Next level requires " .. xpToNext.Value .. " XP.")
	end
end

-- Share addXP with other scripts via GameConfig
GameConfig.addXP = addXP

-- ----------------------------------------------------------------
-- watchNPC(): listen for touches on an NPC
-- ----------------------------------------------------------------
local function watchNPC(npc)
	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				-- Skip if already recruited
				local recruitedFlag = npc:FindFirstChild("Recruited")
				if recruitedFlag and recruitedFlag.Value then return end

				-- Must be a player
				local character = hit.Parent
				local player = Players:GetPlayerFromCharacter(character)
				if not player then return end

				-- Must have a house claimed
				if not GameConfig.playerHouses[player] then return end

				-- Cooldown check
				if npcCooldowns[npc] and (tick() - npcCooldowns[npc]) < CONFIG.NPC_COOLDOWN then return end

				-- Level requirement check
				local leaderstats = player:FindFirstChild("leaderstats")
				local levelStat   = leaderstats and leaderstats:FindFirstChild("Level")
				if not levelStat then return end

				local requiredLevel = GameConfig.getRequiredLevel(npc.Name)
				if levelStat.Value < requiredLevel then return end

				-- All checks passed — give XP
				npcCooldowns[npc] = tick()
				local xpReward = GameConfig.getXPReward(npc.Name)
				addXP(player, xpReward)
				xpEvent:FireClient(player, xpReward)
				print(player.Name .. " touched " .. npc.Name .. " and gained " .. xpReward .. " XP!")
			end)
		end
	end

	npc.AncestryChanged:Connect(function()
		if not npc.Parent then
			npcCooldowns[npc] = nil
		end
	end)
end

-- ----------------------------------------------------------------
-- Watch for NPCs in workspace
-- ----------------------------------------------------------------
local function isNPC(model)
	return model:IsA("Model")
		and model:FindFirstChildOfClass("Humanoid")
		and not Players:GetPlayerFromCharacter(model)
end

workspace.ChildAdded:Connect(function(child)
	if isNPC(child) then watchNPC(child) end
end)

for _, child in ipairs(workspace:GetChildren()) do
	if isNPC(child) then watchNPC(child) end
end

-- ----------------------------------------------------------------
-- Set up leaderboard for players
-- ----------------------------------------------------------------
Players.PlayerAdded:Connect(setupLeaderboard)

for _, player in ipairs(Players:GetPlayers()) do
	setupLeaderboard(player)
end

print("[XPSystem] XP system loaded.")