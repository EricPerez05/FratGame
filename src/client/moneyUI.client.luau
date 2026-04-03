-- MoneyUI.lua
-- Place this LocalScript inside StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Wait for event
local popupEvents = ReplicatedStorage:WaitForChild("PopupEvents")
local moneyUpdate = popupEvents:WaitForChild("MoneyUpdate")

-- ============================================================
--  CONFIGURATION
-- ============================================================
local CONFIG = {
	MONEY_COLOR  = Color3.fromRGB(255, 210, 50),
	BG_COLOR     = Color3.fromRGB(20, 20, 20),
	TEXT_COLOR   = Color3.fromRGB(255, 255, 255),
	MUTED_COLOR  = Color3.fromRGB(180, 180, 180),
	TWEEN_TIME   = 0.3,
}
-- ============================================================

-- ----------------------------------------------------------------
-- Build the UI
-- ----------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MoneyGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player.PlayerGui

-- Main panel top left
local panel = Instance.new("Frame")
panel.Name = "MoneyPanel"
panel.Size = UDim2.new(0, 180, 0, 70)
panel.Position = UDim2.new(0, 12, 0.5, -35)
panel.BackgroundColor3 = CONFIG.BG_COLOR
panel.BackgroundTransparency = 0.3
panel.BorderSizePixel = 0
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

-- Money icon + amount

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "MoneyLabel"
moneyLabel.Size = UDim2.new(1, -50, 0, 30)
moneyLabel.Position = UDim2.new(0, 5, 0, 8)
moneyLabel.BackgroundTransparency = 1
moneyLabel.TextColor3 = CONFIG.MONEY_COLOR
moneyLabel.TextScaled = true
moneyLabel.Font = Enum.Font.GothamBold
moneyLabel.Text = "$0"
moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
moneyLabel.Parent = panel

-- Money per second label
local mpsLabel = Instance.new("TextLabel")
mpsLabel.Name = "MPSLabel"
mpsLabel.Size = UDim2.new(1, -16, 0, 22)
mpsLabel.Position = UDim2.new(0, 10, 0, 42)
mpsLabel.BackgroundTransparency = 1
mpsLabel.TextColor3 = CONFIG.MUTED_COLOR
mpsLabel.TextScaled = true
mpsLabel.Font = Enum.Font.Gotham
mpsLabel.Text = "+$0/sec • 0 members"
mpsLabel.TextXAlignment = Enum.TextXAlignment.Left
mpsLabel.Parent = panel

-- ----------------------------------------------------------------
-- Format large numbers nicely (1000 → 1K, 1000000 → 1M)
-- ----------------------------------------------------------------
local function formatMoney(amount)
	if amount >= 1000000 then
		return string.format("$%.1fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("$%.1fK", amount / 1000)
	else
		return "$" .. math.floor(amount)
	end
end

-- ----------------------------------------------------------------
-- Update UI when server fires money update
-- ----------------------------------------------------------------
local displayedMoney = 0

moneyUpdate.OnClientEvent:Connect(function(money, mps, roster)
	-- Animate money counting up
	local startMoney = displayedMoney
	local targetMoney = money
	displayedMoney = money

	local elapsed = 0
	task.spawn(function()
		while elapsed < CONFIG.TWEEN_TIME do
			elapsed = elapsed + task.wait()
			local alpha = math.min(elapsed / CONFIG.TWEEN_TIME, 1)
			local current = math.floor(startMoney + (targetMoney - startMoney) * alpha)
			moneyLabel.Text = formatMoney(current)
		end
		moneyLabel.Text = formatMoney(targetMoney)
	end)

	-- Update MPS and member count
	local memberCount = roster and #roster or 0
	mpsLabel.Text = string.format("+%s/sec • %d member%s",
		formatMoney(mps):gsub("%$", ""),
		memberCount,
		memberCount == 1 and "" or "s"
	)
end)