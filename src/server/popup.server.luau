-- PopupEvents.lua
-- Place this Script inside ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get or create PopupEvents folder
local events = ReplicatedStorage:FindFirstChild("PopupEvents")
if not events then
	events = Instance.new("Folder")
	events.Name = "PopupEvents"
	events.Parent = ReplicatedStorage
end

-- Only create events if they don't already exist
local function getOrCreate(name)
	local existing = events:FindFirstChild(name)
	if existing then return existing end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = events
	return event
end

getOrCreate("XPGained")
getOrCreate("NPCRecruited")
getOrCreate("RushTimer")

print("[PopupEvents] Remote events ready.")