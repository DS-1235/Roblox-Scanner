local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove existing UI if re-running the script
local oldGui = playerGui:FindFirstChild("NS")
if oldGui then
	oldGui:Destroy()
end

-- Create ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "NS"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Create Main Draggable Frame
local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(260, 125)
frame.Position = UDim2.new(0.5, -130, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

-- Helper function to create buttons
local function createButton(text, xOffset, width)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(width, 32)
	button.Position = UDim2.fromOffset(xOffset, 82)
	button.Text = text
	button.TextSize = 14
	button.Parent = frame
	return button
end

-- Status Label
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -10, 0, 65)
infoLabel.Position = UDim2.fromOffset(5, 5)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.TextSize = 13
infoLabel.TextWrapped = true
infoLabel.Text = "Status: Waiting to start"
infoLabel.Parent = frame

-- Buttons
local startButton = createButton("START", 5, 120)
local closeButton = createButton("CLOSE", 135, 120)

-- State Variables & Settings
local active = false
local alive = true
local teleportCount = 0
local STEP_DISTANCE = 300
local INTERVAL = 2

-- Forward Teleport Function
local function teleportForward()
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not myRoot then
		infoLabel.Text = "Waiting for character..."
		return
	end

	-- Calculate position 300 studs forward while keeping current rotation
	local newCFrame = myRoot.CFrame + (myRoot.CFrame.LookVector * STEP_DISTANCE)
	character:PivotTo(newCFrame)

	teleportCount += 1
	local pos = newCFrame.Position

	-- Update UI and Console
	infoLabel.Text = string.format(
		"Jumps: %d (+%d studs)\nPos: %d, %d, %d",
		teleportCount,
		STEP_DISTANCE,
		math.floor(pos.X),
		math.floor(pos.Y),
		math.floor(pos.Z)
	)
	print(string.format("Teleport #%d | Moved %d studs forward", teleportCount, STEP_DISTANCE))
end

-- Button Connections
startButton.MouseButton1Click:Connect(function()
	active = not active
	startButton.Text = active and "STOP" or "START"
	if active then
		teleportForward()
	else
		infoLabel.Text = "Status: Paused (Jumps: " .. teleportCount .. ")"
	end
end)

closeButton.MouseButton1Click:Connect(function()
	alive = false
	active = false
	gui:Destroy()
end)

-- Background Loop (Runs every 2 seconds when active)
task.spawn(function()
	while alive and gui.Parent do
		task.wait(INTERVAL)
		if alive and active then
			teleportForward()
		end
	end
end)
