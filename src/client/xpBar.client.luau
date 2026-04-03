-- XPBar.lua
-- Place this LocalScript inside StarterPlayerScripts

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ============================================================
--  CONFIGURATION
-- ============================================================
local CONFIG = {
	BAR_COLOR        = Color3.fromRGB(80, 130, 255),   -- XP bar fill color
	BAR_BG_COLOR     = Color3.fromRGB(30, 30, 30),     -- Bar background color
	TEXT_COLOR       = Color3.fromRGB(255, 255, 255),  -- Text color
	TWEEN_DURATION   = 0.4,                            -- Seconds for bar fill animation
	BAR_HEIGHT       = 28,                             -- Height of the bar in pixels
	BOTTOM_PADDING   = 10,                             -- Distance from bottom of screen
}
-- ============================================================

-- Wait for leaderstats to be created by the server (no timeout - will keep waiting)
local leaderstats = player:WaitForChild("leaderstats")
local levelStat = leaderstats:WaitForChild("Level")
local xpStat = leaderstats:WaitForChild("XP")
local xpToNextStat = player:WaitForChild("XPToNext")

-- ----------------------------------------------------------------
-- Build the GUI
-- ----------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XPBarGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player.PlayerGui

-- Outer container sitting at the bottom of the screen
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0.6, 0, 0, CONFIG.BAR_HEIGHT + 16)
container.Position = UDim2.new(0.2, 0, 1, -(CONFIG.BAR_HEIGHT + 16 + CONFIG.BOTTOM_PADDING))
container.BackgroundTransparency = 1
container.Parent = screenGui

-- Level label on the left
local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.Size = UDim2.new(0, 60, 1, 0)
levelLabel.Position = UDim2.new(0, 0, 0, 0)
levelLabel.BackgroundTransparency = 1
levelLabel.TextColor3 = CONFIG.TEXT_COLOR
levelLabel.TextScaled = true
levelLabel.Font = Enum.Font.GothamBold
levelLabel.Text = "LVL 1"
levelLabel.Parent = container

-- Bar background
local barBg = Instance.new("Frame")
barBg.Name = "BarBg"
barBg.Size = UDim2.new(1, -70, 0, CONFIG.BAR_HEIGHT)
barBg.Position = UDim2.new(0, 65, 0.5, -CONFIG.BAR_HEIGHT / 2)
barBg.BackgroundColor3 = CONFIG.BAR_BG_COLOR
barBg.BorderSizePixel = 0
barBg.Parent = container

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(1, 0)
bgCorner.Parent = barBg

-- Bar fill
local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.Position = UDim2.new(0, 0, 0, 0)
barFill.BackgroundColor3 = CONFIG.BAR_COLOR
barFill.BorderSizePixel = 0
barFill.ClipsDescendants = true
barFill.Parent = barBg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = barFill

-- XP numbers label centered on the bar
local xpLabel = Instance.new("TextLabel")
xpLabel.Name = "XPLabel"
xpLabel.Size = UDim2.new(1, 0, 1, 0)
xpLabel.Position = UDim2.new(0, 0, 0, 0)
xpLabel.BackgroundTransparency = 1
xpLabel.TextColor3 = CONFIG.TEXT_COLOR
xpLabel.TextScaled = true
xpLabel.Font = Enum.Font.GothamBold
xpLabel.Text = "0 / 100 XP"
xpLabel.ZIndex = 2
xpLabel.Parent = barBg

-- ----------------------------------------------------------------
-- updateBar(): smoothly animate the bar to the current XP value
-- ----------------------------------------------------------------
local currentTween = nil

local function updateBar()
	local level   = levelStat.Value
	local xp      = xpStat.Value
	local xpToNext = xpToNextStat.Value

	-- Update text
	levelLabel.Text = "LVL " .. level
	xpLabel.Text    = xp .. " / " .. xpToNext .. " XP"

	-- Calculate fill percentage
	local fillPercent = math.clamp(xp / xpToNext, 0, 1)

	-- Cancel any existing tween
	if currentTween then currentTween:Cancel() end

	-- Smoothly animate the bar fill
	currentTween = TweenService:Create(
		barFill,
		TweenInfo.new(CONFIG.TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(fillPercent, 0, 1, 0) }
	)
	currentTween:Play()
end

-- ----------------------------------------------------------------
-- Listen for changes
-- ----------------------------------------------------------------
xpStat.Changed:Connect(updateBar)
levelStat.Changed:Connect(updateBar)
xpToNextStat.Changed:Connect(updateBar)

-- Set initial state
updateBar()