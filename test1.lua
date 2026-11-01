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
logBox.TextYAlignment = Enum.TextYAlignment.Top
logBox.TextWrapped = true
logBox.MultiLine = true
logBox.TextEditable = false
logBox.ClearTextOnFocus = false
logBox.Text = "-- Waiting for scan --"
logBox.ZIndex = 12
logBox.Parent = scrollFrame

local startButton = createButton("START", 5, 180)
local closeButton = createButton("CLOSE", 195, 180)

local active = false
local alive = true
local loggedPaths = {}
local logLines = {}
local totalFound = 0

-- Target text markers from your screenshots
local TARGET_TEXTS = {
	"DUNGEON COMPLETED",
	"COMPLETED",
	"PAY WITH GEMS",
	"USE TICKETS",
	"OPEN PARTIES",
	"CREATE PARTY",
	"YOUR PARTY",
	"PARTY RUNES",
	"START",
	"LEAVE"
}

local function appendLog(line)
	table.insert(logLines, line)
	print(line)
end

local function isEffectivelyVisible(guiObj)
	local current = guiObj
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		elseif current:IsA("LayerCollector") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return true
end

local function inspectHierarchy()
	local newMatches = 0

	for _, desc in ipairs(playerGui:GetDescendants()) do
		if not desc:IsDescendantOf(gui) then
			if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and isEffectivelyVisible(desc) then
				local rawText = string.upper(desc.Text or "")
				for _, marker in ipairs(TARGET_TEXTS) do
					if string.find(rawText, marker, 1, true) then
						local fullPath = desc:GetFullName()
						if not loggedPaths[fullPath] then
							loggedPaths[fullPath] = true
							totalFound += 1
							newMatches += 1

							appendLog(string.format("=== [MATCH #%d] %q (%s) ===", totalFound, desc.Text, desc.ClassName))
							appendLog("PATH: " .. fullPath)

							-- Walk up 2 levels to inspect parent containers & sibling buttons
							local parent1 = desc.Parent
							local parent2 = parent1 and parent1.Parent
							local searchRoot = parent2 or parent1

							if searchRoot then
								appendLog("ROOT: " .. searchRoot:GetFullName() .. " (" .. searchRoot.ClassName .. ")")
								for _, item in ipairs(searchRoot:GetDescendants()) do
									if item:IsA("GuiButton") then
										local btnText = item:IsA("TextButton") and item.Text or ""
										appendLog(string.format("  [BTN] %s | %s | %q",
											item:GetFullName(), item.ClassName, btnText))
									elseif item:IsA("TextLabel") and item ~= desc then
										appendLog(string.format("  [LBL] %s | %q",
											item:GetFullName(), item.Text))
									end
								end
							end
						end
						break
					end
				end
			end
		end
	end

	if newMatches > 0 then
		logBox.Text = table.concat(logLines, "\n")
	end

	infoLabel.Text = string.format("Active | Logged: %d (+%d new) | Click box -> Ctrl+A, Ctrl+C", totalFound, newMatches)
end

startButton.MouseButton1Click:Connect(function()
	active = not active
	startButton.Text = active and "STOP" or "START"
	if active then
		loggedPaths = {}
		logLines = {}
		totalFound = 0
		logBox.Text = "Scanning..."
		inspectHierarchy()
	else
		infoLabel.Text = "Paused (Logged: " .. totalFound .. ") | Click box -> Ctrl+A, Ctrl+C"
	end
end)

closeButton.MouseButton1Click:Connect(function()
	alive = false
	active = false
	gui:Destroy()
end)

task.spawn(function()
	while alive and gui.Parent do
		task.wait(2)
		if alive and active then
			inspectHierarchy()
		end
	end
end)
