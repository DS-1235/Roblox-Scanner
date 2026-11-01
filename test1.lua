local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove existing UI if re-running
local oldGui = playerGui:FindFirstChild("NS_Inspector")
if oldGui then
	oldGui:Destroy()
end

-- Create ScreenGui (Forced on top of all other menus)
local gui = Instance.new("ScreenGui")
gui.Name = "NS_Inspector"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Slightly taller frame to fit the copyable log box
local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(380, 260)
frame.Position = UDim2.new(0.5, -190, 0.12, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
frame.ZIndex = 10
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local function createButton(text, xOffset, width)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(width, 32)
	button.Position = UDim2.fromOffset(xOffset, 220)
	button.Text = text
	button.TextSize = 14
	button.ZIndex = 11
	button.Parent = frame
	return button
end

-- Top Status Bar
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -10, 0, 24)
infoLabel.Position = UDim2.fromOffset(5, 4)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.TextSize = 13
infoLabel.ZIndex = 11
infoLabel.Text = "Click START, then click box & press Ctrl+A, Ctrl+C"
infoLabel.Parent = frame

-- Scrollable container for the copyable TextBox
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -10, 0, 182)
scrollFrame.Position = UDim2.fromOffset(5, 32)
scrollFrame.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ZIndex = 11
scrollFrame.Parent = frame

-- Copyable TextBox (Read-only, allows Ctrl+A and Ctrl+C)
local logBox = Instance.new("TextBox")
logBox.Size = UDim2.new(1, -12, 0, 0)
logBox.Position = UDim2.fromOffset(4, 4)
logBox.AutomaticSize = Enum.AutomaticSize.Y
logBox.BackgroundTransparency = 1
logBox.TextColor3 = Color3.fromRGB(220, 235, 255)
logBox.TextSize = 12
logBox.Font = Enum.Font.Code
logBox.TextXAlignment = Enum.TextXAlignment.Left
logBox.
