local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RushCountdownGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = playerGui

-- Calendar (days of week) - sits above the timer bar
local DAYS = {"MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"}
local currentDay = 1  -- starts on Monday

local calendarFrame = Instance.new("Frame")
calendarFrame.Size = UDim2.new(0.4, 0, 0.04, 0)
calendarFrame.Position = UDim2.new(0.3, 0, -0.02, 0)  -- sits just above the timer
calendarFrame.BackgroundTransparency = 1
calendarFrame.BorderSizePixel = 0
calendarFrame.Parent = ScreenGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0.01, 0)
layout.Parent = calendarFrame

local dayLabels = {}
for i, day in ipairs(DAYS) do
	local dayBox = Instance.new("Frame")
	dayBox.Size = UDim2.new(1/7, -4, 1, 0)
	dayBox.BackgroundColor3 = i == currentDay 
		and Color3.fromRGB(255, 200, 50) 
		or Color3.fromRGB(40, 40, 40)
	dayBox.BackgroundTransparency = i == currentDay and 0.1 or 0.4
	dayBox.BorderSizePixel = 0
	dayBox.LayoutOrder = i
	dayBox.Parent = calendarFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = dayBox

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = i == currentDay 
		and Color3.fromRGB(30, 30, 30) 
		or Color3.fromRGB(180, 180, 180)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = day
	label.Parent = dayBox

	dayLabels[i] = { box = dayBox, label = label }
end

-- Function to advance to next day
local function advanceDay()
	-- Unhighlight current day
	dayLabels[currentDay].box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	dayLabels[currentDay].box.BackgroundTransparency = 0.4
	dayLabels[currentDay].label.TextColor3 = Color3.fromRGB(180, 180, 180)

	-- Move to next day
	currentDay = (currentDay % 7) + 1

	-- Highlight new day
	dayLabels[currentDay].box.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	dayLabels[currentDay].box.BackgroundTransparency = 0.1
	dayLabels[currentDay].label.TextColor3 = Color3.fromRGB(30, 30, 30)
end









-- Background Frame
local Background = Instance.new("Frame")
Background.Size = UDim2.new(0.4, 0, 0.06, 0)
Background.Position = UDim2.new(0.3, 0, 0.02, 0)
Background.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Background.BackgroundTransparency = 0.2
Background.BorderSizePixel = 0
Background.Parent = ScreenGui
local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 8)
bgCorner.Parent = Background

-- Progress Bar
local Bar = Instance.new("Frame")
Bar.Size = UDim2.new(1, 0, 1, 0)
Bar.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
Bar.BorderSizePixel = 0
Bar.Parent = Background
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 8)
barCorner.Parent = Bar

-- Gradient on bar
local Gradient = Instance.new("UIGradient")
Gradient.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 150)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 50, 50))
}
Gradient.Rotation = 90
Gradient.Parent = Bar

-- Time Label
local Label = Instance.new("TextLabel")
Label.Size = UDim2.new(1, 0, 1, 0)
Label.BackgroundTransparency = 1
Label.TextColor3 = Color3.fromRGB(255, 255, 255)
Label.Font = Enum.Font.GothamBold
Label.TextScaled = true
Label.TextStrokeTransparency = 0.5
Label.Text = "[ 10:00:00 ]"
Label.Parent = Background

-- Timer Logic
local TOTAL_DURATION = 600  -- 10 minutes in seconds
local startTime = tick()
local rushStarted = false

RunService.RenderStepped:Connect(function()
	local elapsed = tick() - startTime
	local timeLeft = math.max(0, TOTAL_DURATION - elapsed)
	
	-- Calculate minutes, seconds, milliseconds
	local minutes = math.floor(timeLeft / 60)
	local seconds = math.floor(timeLeft % 60)
	local milliseconds = math.floor((timeLeft % 1) * 100)
	
	-- Update text
	Label.Text = string.format("[ %02d:%02d:%02d ]", minutes, seconds, milliseconds)
	
	-- Update bar (synced with countdown)
	local pct = timeLeft / TOTAL_DURATION
	Bar.Size = UDim2.new(pct, 0, 1, 0)
	
	-- Rush event trigger and reset
	if timeLeft <= 0 and not rushStarted then
		rushStarted = true
		print("RUSH EVENT STARTED")
		Label.Text = "[ 00:00:00 ]"
		-- Reset timer
		task.wait(0.1)
		startTime = tick()
		rushStarted = false
	end
end)

local popupEvents = game:GetService("ReplicatedStorage"):WaitForChild("PopupEvents")
local dayUpdate = popupEvents:WaitForChild("DayUpdate")

dayUpdate.OnClientEvent:Connect(function(day)
	for i, d in ipairs(dayLabels) do
		d.box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		d.box.BackgroundTransparency = 0.4
		d.label.TextColor3 = Color3.fromRGB(180, 180, 180)
	end
	dayLabels[day].box.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	dayLabels[day].box.BackgroundTransparency = 0.1
	dayLabels[day].label.TextColor3 = Color3.fromRGB(30, 30, 30)
end)