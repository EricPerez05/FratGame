-- RecruitmentSystem.lua
-- Place this script inside ServerScriptService

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--for popups
local popupEvents = ReplicatedStorage:FindFirstChild("PopupEvents")
if not popupEvents then
	popupEvents = ReplicatedStorage:WaitForChild("PopupEvents", 30)
end

local recruitEvent = popupEvents:FindFirstChild("NPCRecruited") or popupEvents:WaitForChild("NPCRecruited", 10)
local xpEvent = popupEvents:FindFirstChild("XPGained") or popupEvents:WaitForChild("XPGained", 10)


local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CONFIG     = GameConfig.RECRUITMENT
local HOUSES_CFG = GameConfig.HOUSES
GameConfig.playerHouses = GameConfig.playerHouses or {}

local housesFolder = workspace:WaitForChild(HOUSES_CFG.HOUSES_FOLDER)

local playerHouses = GameConfig.playerHouses

local recruitCooldowns = {}
local recruitedNPCs    = {}
local recruitsToday = {}  -- tracks how many NPCs each player recruited

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





local function showMessage(player, message)
	local screenGui = player.PlayerGui:FindFirstChild("RecruitmentGui")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "RecruitmentGui"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = player.PlayerGui
	end

	local existing = screenGui:FindFirstChild("Message")
	if existing then existing:Destroy() end

	local frame = Instance.new("Frame")
	frame.Name = "Message"
	frame.Size = UDim2.new(0.4, 0, 0.07, 0)
	frame.Position = UDim2.new(0.3, 0, 0.08, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = message
	label.Parent = frame

	task.delay(CONFIG.MESSAGE_DURATION, function()
		if frame and frame.Parent then frame:Destroy() end
	end)
end

local function getDoorPosition(house)
	-- Search inside the matching house folder e.g. Houses/House1/Door
	local houseName = house.Name
	local houseFolder = housesFolder:FindFirstChild(houseName)
	if not houseFolder then
		warn("[RecruitmentSystem] Could not find folder for " .. houseName)
		return nil
	end

	local door = houseFolder:FindFirstChild(HOUSES_CFG.DOOR_PART)
	local doorPart = getDoorTouchPart(door)
	if not doorPart then
		warn("[RecruitmentSystem] No Door part found in " .. houseName)
		return nil
	end

	local pos = doorPart.Position + Vector3.new(0, 0, CONFIG.DOOR_OFFSET)
	print("[RecruitmentSystem] Target position for " .. houseName .. ": " .. tostring(pos))
	return pos
end

local function walkNPCToHouse(npc, house)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local rootPart = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	local targetPos = getDoorPosition(house)
	if not targetPos then return end

	humanoid.WalkSpeed = CONFIG.WALK_SPEED

	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentHeight     = 5,
			AgentRadius     = 2,
			AgentCanJump    = true,
			AgentCanClimb   = false,
			WaypointSpacing = 4,
		})

		local success = pcall(function()
			path:ComputeAsync(rootPart.Position, targetPos)
		end)

		if success and path.Status == Enum.PathStatus.Success then
			for _, waypoint in ipairs(path:GetWaypoints()) do
				if not npc.Parent or humanoid.Health <= 0 then break end
				if waypoint.Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end
				humanoid:MoveTo(waypoint.Position)
				local elapsed = 0
				while elapsed < 3 do
					elapsed = elapsed + task.wait(0.1)
					if (rootPart.Position - waypoint.Position).Magnitude < CONFIG.ARRIVED_DISTANCE then break end
				end
			end
		else
			humanoid:MoveTo(targetPos)
			humanoid.MoveToFinished:Wait()
		end

		npc:Destroy()
	end)

	-- Fade out simultaneously while walking
	task.spawn(function()
		local parts = {}
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end

		local elapsed = 0
		local duration = 4  -- fade duration in seconds, adjust to taste
		while elapsed < duration and npc.Parent do
			elapsed = elapsed + task.wait(0.05)
			local alpha = math.clamp(elapsed / duration, 0, 1)
			for _, part in ipairs(parts) do
				part.Transparency = alpha
			end
		end

		if npc.Parent then npc:Destroy() end
	end)
end



local function recruitNPC(player, npc)
	-- Check daily recruit limit
	local count = recruitsToday[player] or 0
	if count >= 5 then
		showMessage(player, "❌ You already recruited 5 people today!")
		return
	end
	
	if recruitedNPCs[npc] then return end

	local house = playerHouses[player]
	if not house then
		showMessage(player, "Claim a house first before recruiting!")
		return
	end

	local lastRecruit = recruitCooldowns[player]
	if lastRecruit and (tick() - lastRecruit) < CONFIG.RECRUIT_COOLDOWN then return end

	local requiredLevel = GameConfig.getRequiredLevel(npc.Name)
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelStat = leaderstats and leaderstats:WaitForChild("Level", 5)
	local playerLevel = levelStat and levelStat.Value or 1

	if playerLevel < requiredLevel then
		local msg = CONFIG.LOW_LEVEL_MESSAGE
			:gsub("{npc}",   npc.Name)
			:gsub("{level}", tostring(requiredLevel))
		showMessage(player, msg)
		return
	end

	recruitedNPCs[npc]    = player
	recruitCooldowns[player] = tick()

	local recruitedFlag = npc:FindFirstChild("Recruited")
	if recruitedFlag then recruitedFlag.Value = true end
	
	
	
	
	print("[RecruitmentSystem] " .. player.Name .. " recruited " .. npc.Name)
	
	walkNPCToHouse(npc, house)
	if GameConfig.addToRoster then
		GameConfig.addToRoster(player, npc.Name)
	end
	
	if GameConfig.addXP then
		local xpReward = GameConfig.getXPReward(npc.Name)
		GameConfig.addXP(player, xpReward)
		xpEvent:FireClient(player, xpReward)
	end
	recruitEvent:FireClient(player, npc.Name)
end

local function watchNPC(npc)
	if not npc:FindFirstChildOfClass("Humanoid") then return end
	if Players:GetPlayerFromCharacter(npc) then return end

	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				if recruitedNPCs[npc] then return end
				local character = hit.Parent
				local player = Players:GetPlayerFromCharacter(character)
				if not player then return end
				recruitNPC(player, npc)
			end)
		end
	end

	npc.AncestryChanged:Connect(function()
		if not npc.Parent then recruitedNPCs[npc] = nil end
	end)
end

for _, house in ipairs(housesFolder:GetChildren()) do
	local door = house:FindFirstChild(HOUSES_CFG.DOOR_PART)
	local doorPart = getDoorTouchPart(door)
	if not doorPart then continue end

	doorPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local alreadyOwned = false
		for _, h in pairs(playerHouses) do
			if h == house then alreadyOwned = true break end
		end

		if not alreadyOwned and not playerHouses[player] then
			playerHouses[player] = house
			print("[RecruitmentSystem] " .. player.Name .. " owns " .. house.Name)
		end
	end)
end

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

Players.PlayerRemoving:Connect(function(player)
	playerHouses[player]     = nil
	recruitCooldowns[player] = nil
	recruitsToday[player]    = nil
end)

print("[RecruitmentSystem] Recruitment system loaded.")
task.spawn(function()
	while true do
		task.wait(CONFIG.DAY_DURATION)

		print("[RecruitmentSystem] New rush period started!")

		for player, _ in pairs(recruitsToday) do
			recruitsToday[player] = 0
		end

		-- Optional: notify players
		for _, player in ipairs(Players:GetPlayers()) do
			showMessage(player, "🏫 New Rush Period! You can recruit again!")
		end
	end
end)