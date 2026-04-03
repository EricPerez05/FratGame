-- PopupNotifications.lua
-- Place this LocalScript inside StarterPlayerScripts

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ============================================================
--  CONFIGURATION
-- ============================================================
local CONFIG = {
	POPUP_DURATION   = 1.2,    -- How long the popup stays before fading
	FADE_DURATION    = 0.4,    -- How long the fade out takes
	FONT             = Enum.Font.GothamBold,
	TEXT_SIZE        = 28,     -- Font size in pixels

	-- XP popup
	XP_COLOR         = Color3.fromRGB(100, 200, 255),  -- Blue
	XP_PREFIX        = "+",
	XP_SUFFIX        = " XP",

	-- Recruit popup
	RECRUIT_COLOR    = Color3.fromRGB(100, 255, 150),  -- Green
	RECRUIT_PREFIX   = "Recruited ",
	RECRUIT_SUFFIX   = "!",

	-- Positioning (center of screen with random offset)
	BASE_X           = 0.5,    -- Center of screen horizontally
	BASE_Y           = 0.45,   -- Slightly above center vertically
	OFFSET_X         = 0.12,   -- Max random horizontal offset
	OFFSET_Y         = 0.08,   -- Max random vertical offset
}
-- ============================================================

-- Create the ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PopupGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player.PlayerGui

-- ----------------------------------------------------------------
-- showPopup(): creates a popup label that pops up then fades out
-- ----------------------------------------------------------------
local function showPopup(text, color)
	-- Random offset so popups don't stack
	local offsetX = (math.random() - 0.5) * 2 * CONFIG.OFFSET_X
	local offsetY = (math.random() - 0.5) * 2 * CONFIG.OFFSET_Y

	local posX = CONFIG.BASE_X + offsetX
	local posY = CONFIG.BASE_Y + offsetY

	-- Create label
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.3, 0, 0, 50)
	label.Position = UDim2.new(posX - 0.15, 0, posY, 0)
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextSize = CONFIG.TEXT_SIZE
	label.Font = CONFIG.FONT
	label.Text = text
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextScaled = false
	label.ZIndex = 10
	label.TextTransparency = 0
	label.Parent = screenGui

	-- Pop in: scale up quickly
	label.Size = UDim2.new(0, 0, 0, 0)
	label.Position = UDim2.new(posX, 0, posY, 0)
	label.AnchorPoint = Vector2.new(0.5, 0.5)

	local popIn = TweenService:Create(
		label,
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(0.3, 0, 0, 50),
		}
	)
	popIn:Play()

	-- Wait then fade out
	task.delay(CONFIG.POPUP_DURATION, function()
		if not label.Parent then return end

		local fadeOut = TweenService:Create(
			label,
			TweenInfo.new(CONFIG.FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			label:Destroy()
		end)
	end)
end

-- ----------------------------------------------------------------
-- Listen for remote events from the server
-- ----------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for events folder
local events = ReplicatedStorage:WaitForChild("PopupEvents")
local xpEvent      = events:WaitForChild("XPGained")
local recruitEvent = events:WaitForChild("NPCRecruited")

xpEvent.OnClientEvent:Connect(function(amount)
	showPopup(CONFIG.XP_PREFIX .. amount .. CONFIG.XP_SUFFIX, CONFIG.XP_COLOR)
end)

recruitEvent.OnClientEvent:Connect(function(npcName)
	showPopup(CONFIG.RECRUIT_PREFIX .. npcName .. CONFIG.RECRUIT_SUFFIX, CONFIG.RECRUIT_COLOR)
end)