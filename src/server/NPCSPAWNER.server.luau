-- NPCSpawner.lua
-- Place this script inside ServerScriptService

local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CONFIG = GameConfig.SPAWNER

local npcFolder = ServerStorage:FindFirstChild("NPCs")
if not npcFolder then
	warn("[NPCSpawner] Could not find 'NPCs' folder in ServerStorage.")
	return
end

local npcTemplates = npcFolder:GetChildren()
if #npcTemplates == 0 then
	warn("[NPCSpawner] NPCs folder is empty!")
	return
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local excluded = rayParams.FilterDescendantsInstances or {}
		table.insert(excluded, character)
		rayParams.FilterDescendantsInstances = excluded
	end)
end)

local function findSpawnPosition()
	for _ = 1, CONFIG.MAX_PLACE_ATTEMPTS do
		local angle  = math.random() * 2 * math.pi
		local radius = math.sqrt(math.random()) * CONFIG.SPAWN_RADIUS
		local origin = CONFIG.MAP_CENTER
			+ Vector3.new(math.cos(angle) * radius, CONFIG.RAYCAST_HEIGHT, math.sin(angle) * radius)

		local result = workspace:Raycast(origin, Vector3.new(0, -CONFIG.RAYCAST_HEIGHT * 2, 0), rayParams)
		if result and result.Position.Y >= CONFIG.MIN_SPAWN_Y then
			return result.Position + Vector3.new(0, CONFIG.NPC_Y_OFFSET, 0)
		end
	end
	return nil
end

local function startIdleBehavior(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local rootPart = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	humanoid.WalkSpeed = 0

	local recruitedFlag = Instance.new("BoolValue")
	recruitedFlag.Name = "Recruited"
	recruitedFlag.Value = false
	recruitedFlag.Parent = npc

	task.spawn(function()
		while npc and npc.Parent and humanoid.Health > 0 do
			if recruitedFlag.Value then break end

			local waitTime = math.random(CONFIG.IDLE_LOOK_INTERVAL[1], CONFIG.IDLE_LOOK_INTERVAL[2])
			task.wait(waitTime)

			if not npc.Parent or recruitedFlag.Value then break end

			local randomAngle = math.random() * 2 * math.pi
			local targetCFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, randomAngle, 0)
			local startCFrame = rootPart.CFrame
			local elapsed = 0
			local duration = 1 / CONFIG.IDLE_LOOK_SPEED

			while elapsed < duration do
				if not npc.Parent or recruitedFlag.Value then break end
				elapsed = elapsed + task.wait()
				rootPart.CFrame = startCFrame:Lerp(targetCFrame, math.min(elapsed / duration, 1))
			end
		end
	end)
end

local function startPatrolBehavior(npc, spawnPos)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local rootPart = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	humanoid.WalkSpeed = CONFIG.PATROL_SPEED

	local recruitedFlag = Instance.new("BoolValue")
	recruitedFlag.Name = "Recruited"
	recruitedFlag.Value = false
	recruitedFlag.Parent = npc

	task.spawn(function()
		while npc and npc.Parent and humanoid.Health > 0 do
			if recruitedFlag.Value then break end

			local angle  = math.random() * 2 * math.pi
			local radius = math.random() * CONFIG.PATROL_RADIUS
			local target = spawnPos + Vector3.new(
				math.cos(angle) * radius,
				0,
				math.sin(angle) * radius
			)

			humanoid:MoveTo(target)
			humanoid.MoveToFinished:Wait()

			local waitTime = math.random(CONFIG.PATROL_WAIT[1], CONFIG.PATROL_WAIT[2])
			task.wait(waitTime)
		end
	end)
end

local function spawnNPC()
	local spawnPos = findSpawnPosition()
	if not spawnPos then
		warn("[NPCSpawner] Failed to find a valid spawn position.")
		return
	end

	local template = npcTemplates[math.random(1, #npcTemplates)]
	local npc = template:Clone()
	npc.Parent = workspace

	-- Unanchor all parts
	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	local rootPart = npc:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = CFrame.new(spawnPos)
		rootPart.Anchored = false
	elseif npc.PrimaryPart then
		npc:SetPrimaryPartCFrame(CFrame.new(spawnPos))
	end

	local roll = math.random()
	if roll < CONFIG.IDLE_CHANCE then
		startIdleBehavior(npc)
	else
		startPatrolBehavior(npc, spawnPos)
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			task.delay(CONFIG.RESPAWN_DELAY, function()
				npc:Destroy()
				spawnNPC()
			end)
		end)
	end

	return npc
end

while true do
	print("[NPCSpawner] Spawning new wave...")

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:FindFirstChildOfClass("Humanoid") and not game.Players:GetPlayerFromCharacter(obj) then
			obj:Destroy()
		end
	end

	for i = 1, CONFIG.SPAWN_COUNT do
		task.wait(0.1)
		spawnNPC()
	end

	print(("[NPCSpawner] Spawned %d NPCs successfully."):format(CONFIG.SPAWN_COUNT))
	task.wait(CONFIG.WAVE_INTERVAL)
end