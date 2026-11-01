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

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(260, 125)
frame.Position = UDim2.new(0.5, -130, 0.15, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
frame.ZIndex = 10
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local function createButton(text, xOffset, width)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(width, 32)
	button.Position = UDim2.fromOffset(xOffset, 82)
	button.Text = text
	button.TextSize = 14
	button.ZIndex = 11
	button.Parent = frame
	return button
end

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -10, 0, 65)
infoLabel.Position = UDim2.fromOffset(5, 5)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.TextSize = 13
infoLabel.TextWrapped = true
infoLabel.ZIndex = 11
infoLabel.Text = "Status: Click START to auto-scan"
infoLabel.Parent = frame

local startButton = createButton("START", 5, 120)
local closeButton = createButton("CLOSE", 135, 120)

local active = false
local alive = true
local loggedPaths = {}
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
		if desc ~= infoLabel and desc ~= startButton and desc ~= closeButton then
			if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and isEffectivelyVisible(desc) then
				local rawText = string.upper(desc.Text or "")
				for _, marker in ipairs(TARGET_TEXTS) do
					if string.find(rawText, marker, 1, true) then
						local fullPath = desc:GetFullName()
						if not loggedPaths[fullPath] then
							loggedPaths[fullPath] = true
							totalFound += 1
							newMatches += 1

							print("===================================================")
							print(string.format("[MATCH #%d] Text: %q (%s)", totalFound, desc.Text, desc.ClassName))
							print("FULL PATH:", fullPath)

							-- Walk up 2 levels to inspect parent containers & sibling buttons
							local parent1 = desc.Parent
							local parent2 = parent1 and parent1.Parent
							local searchRoot = parent2 or parent1

							if searchRoot then
								print("CONTAINER:", searchRoot:GetFullName(), "(" .. searchRoot.ClassName .. ")")
								for _, item in ipairs(searchRoot:GetDescendants()) do
									if item:IsA("GuiButton") then
										local btnText = item:IsA("TextButton") and item.Text or ""
										print(string.format("   -> BUTTON: %s | Class: %s | Text: %q",
											item:GetFullName(), item.ClassName, btnText))
									elseif item:IsA("TextLabel") and item ~= desc then
										print(string.format("   -> LABEL: %s | Text: %q",
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

	infoLabel.Text = string.format(
		"Auto-Scan Active\nTotal Logged: %d (+%d new)\nCheck F9 Console",
		totalFound,
		newMatches
	)
end

startButton.MouseButton1Click:Connect(function()
	active = not active
	startButton.Text = active and "STOP" or "START"
	if active then
		loggedPaths = {}
		totalFound = 0
		print("========== AUTO UI INSPECTOR STARTED ==========")
		inspectHierarchy()
	else
		infoLabel.Text = "Scanner paused (Logged: " .. totalFound .. ")"
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
