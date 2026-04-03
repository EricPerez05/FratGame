local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

warn("[CLIENT BOOT]", "isClient=", RunService:IsClient(), "script=", script:GetFullName())

task.defer(function()
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Client Boot",
			Text = "LocalScript is running",
			Duration = 3,
		})
	end)
end)