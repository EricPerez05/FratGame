local RunService = game:GetService("RunService")

warn("[SERVER BOOT]", "isServer=", RunService:IsServer(), "script=", script:GetFullName())

local marker = Instance.new("Part")
marker.Name = "ServerBootMarker"
marker.Anchored = true
marker.Size = Vector3.new(6, 1, 6)
marker.Position = Vector3.new(0, 5, 0)
marker.BrickColor = BrickColor.new("Bright green")
marker.Parent = workspace