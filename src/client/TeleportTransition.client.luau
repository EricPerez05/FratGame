-- TeleportTransition.client.luau
-- Renders a black fullscreen transition for teleport events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local transitionFolder = ReplicatedStorage:WaitForChild("TeleportEvents")
local transitionEvent = transitionFolder:WaitForChild("TeleportTransition")

local gui = Instance.new("ScreenGui")
gui.Name = "TeleportTransitionGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10000
gui.Parent = playerGui

local cover = Instance.new("Frame")
cover.Name = "BlackCover"
cover.Size = UDim2.fromScale(1, 1)
cover.Position = UDim2.fromScale(0, 0)
cover.BackgroundColor3 = Color3.new(0, 0, 0)
cover.BackgroundTransparency = 1
cover.BorderSizePixel = 0
cover.Parent = gui

local activeTween

local function tweenCover(targetTransparency, duration)
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	activeTween = TweenService:Create(
		cover,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = targetTransparency }
	)
	activeTween:Play()
	activeTween.Completed:Wait()
	activeTween = nil
end

transitionEvent.OnClientEvent:Connect(function(action, duration)
	local tweenDuration = typeof(duration) == "number" and duration or 0.35

	if action == "Close" then
		tweenCover(0, tweenDuration)
	elseif action == "Open" then
		tweenCover(1, tweenDuration)
	end
end)
