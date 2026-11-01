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
infoLabel.Text = "Nearest candidate: Waiting"
infoLabel.Parent = frame

-- Buttons
local startButton = createButton("START", 5, 120)
local closeButton = createButton("CLOSE", 135, 120)

-- State Variables
local active = false
local alive = true

-- Combined Scan & Teleport Function
local function scanAndTeleport()
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not myRoot then
		infoLabel.Text = "Waiting for character..."
		return
	end

	local nearestRoot = nil
	local nearestDistance = math.huge
	local nearestModel = nil

	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Model")
			and model ~= character
			and not Players:GetPlayerFromCharacter(model) then

			local root = model:FindFirstChild("HumanoidRootPart", true)

			if root and root:IsA("BasePart") then
				local distance = (myRoot.Position - root.Position).Magnitude

				if distance < nearestDistance then
					nearestDistance = distance
					nearestRoot = root
					nearestModel = model
				end
			end
		end
	end

	if nearestRoot and nearestModel then
		local roundedDist = math.floor(nearestDistance)

		-- Calculate position: 5 studs in front of target, 2 studs up
		local destination = nearestRoot.Position
			+ nearestRoot.CFrame.LookVector * 5
			+ Vector3.new(0, 2, 0)

		-- Teleport character (and face the target)
		character:PivotTo(CFrame.lookAt(destination, nearestRoot.Position))

		-- Update UI
		infoLabel.Text = string.format(
			"Candidate: %s\nDistance: %d studs (Teleported)",
			nearestModel.Name,
			roundedDist
		)

		-- Console Output
		print("TARGET:", nearestModel:GetFullName())
		print("DISTANCE:", roundedDist)
	else
		infoLabel.Text = "No candidate found"
		warn("No candidate found")
	end
end

-- Button Connections
startButton.MouseButton1Click:Connect(function()
	active = not active
	startButton.Text = active and "STOP" or "START"
	if active then
		scanAndTeleport()
	else
		infoLabel.Text = "Scanner paused"
	end
end)

closeButton.MouseButton1Click:Connect(function()
	alive = false
	active = false
	gui:Destroy()
end)

-- Background Loop (Runs every 4 seconds when active)
task.spawn(function()
	while alive and gui.Parent do
		task.wait(4)
		if alive and active then
			scanAndTeleport()
		end
	end
end)
