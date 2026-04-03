-- DayNightTimer.lua
-- Server-wide recruitment timer + synced day/night cycle
-- Place this script in ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- Create RemoteEvent for timer GUI if it doesn't exist
local popupEvents = ReplicatedStorage:FindFirstChild("PopupEvents")
if not popupEvents then
	popupEvents = Instance.new("Folder")
	popupEvents.Name = "PopupEvents"
	popupEvents.Parent = ReplicatedStorage
end

local timerEvent = popupEvents:FindFirstChild("RushTimer")
if not timerEvent then
	timerEvent = Instance.new("RemoteEvent")
	timerEvent.Name = "RushTimer"
	timerEvent.Parent = popupEvents
end



local currentDay = 1
local DAYS = {"MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"}

local dayUpdate = popupEvents:FindFirstChild("DayUpdate")
if not dayUpdate then
	dayUpdate = Instance.new("RemoteEvent")
	dayUpdate.Name = "DayUpdate"
	dayUpdate.Parent = popupEvents
end

local function advanceDay()
	currentDay = (currentDay % 7) + 1
	for _, player in ipairs(Players:GetPlayers()) do
		dayUpdate:FireClient(player, currentDay)
	end
	print("[DayNight] Day advanced to " .. DAYS[currentDay])
end

Players.PlayerAdded:Connect(function(player)
	task.wait(2)
	dayUpdate:FireClient(player, currentDay)
end)






-- =========================
-- CONFIG
-- =========================
local DAY_DURATION = 480   -- 10 minutes for recruitment/day
local NIGHT_DURATION =  120 -- optional night
local UPDATE_INTERVAL = 0.1    -- seconds

-- Lighting config
local SUNRISE = 6
local SUNSET  = 18
local NIGHT_AMBIENT = Color3.fromRGB(20, 20, 40)
local DAY_AMBIENT   = Color3.fromRGB(200, 200, 200)
local NIGHT_OUTDOOR_AMBIENT = Color3.fromRGB(10, 10, 30)
local DAY_OUTDOOR_AMBIENT   = Color3.fromRGB(180, 180, 180)
local NIGHT_BRIGHTNESS = 0.2
local DAY_BRIGHTNESS   = 2

-- =========================
-- Helper Functions
-- =========================
local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return Color3.new(
		lerp(c1.R, c2.R, t),
		lerp(c1.G, c2.G, t),
		lerp(c1.B, c2.B, t)
	)
end

-- Update lighting based on progress (0 → 1)
local function updateLighting(progress)
	Lighting.ClockTime = lerp(SUNRISE, SUNSET, progress)
	Lighting.Ambient        = lerpColor(NIGHT_AMBIENT, DAY_AMBIENT, math.sin(progress * math.pi))
	Lighting.OutdoorAmbient = lerpColor(NIGHT_OUTDOOR_AMBIENT, DAY_OUTDOOR_AMBIENT, math.sin(progress * math.pi))
	Lighting.Brightness     = lerp(NIGHT_BRIGHTNESS, DAY_BRIGHTNESS, math.sin(progress * math.pi))
end

-- =========================
-- Main Cycle Loop
-- =========================
task.spawn(function()
	while true do
		local startTime = tick()
		while tick() - startTime < DAY_DURATION do
			local elapsed = tick() - startTime
			local progress = elapsed / DAY_DURATION
			-- Update lighting
			updateLighting(progress)

			-- Server-wide timer (seconds left)
			local secondsLeft = math.max(0, math.floor(DAY_DURATION - elapsed))
			-- Fire all players
			for _, player in ipairs(Players:GetPlayers()) do
				timerEvent:FireClient(player, secondsLeft)
			end

			task.wait(UPDATE_INTERVAL)
		end

		-- Optional night cycle
		advanceDay()  -- add this right here
		startTime = tick()
		while tick() - startTime < NIGHT_DURATION do
			local elapsed = tick() - startTime
			local progress = elapsed / NIGHT_DURATION
			-- ClockTime night → sunrise
			Lighting.ClockTime = lerp(SUNSET, SUNRISE, progress)
			Lighting.Ambient        = lerpColor(DAY_AMBIENT, NIGHT_AMBIENT, progress)
			Lighting.OutdoorAmbient = lerpColor(DAY_OUTDOOR_AMBIENT, NIGHT_OUTDOOR_AMBIENT, progress)
			Lighting.Brightness     = lerp(DAY_BRIGHTNESS, NIGHT_BRIGHTNESS, progress)

			-- Timer = 0 during night
			for _, player in ipairs(Players:GetPlayers()) do
				timerEvent:FireClient(player, 0)
			end
			task.wait(UPDATE_INTERVAL)
		end
	end
end)

print("[DayNightTimer] Day/Night cycle with server timer loaded.")