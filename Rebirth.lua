local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove existing UI if re-running
local oldGui = playerGui:FindFirstChild("NS_Rebirth")
if oldGui then
	oldGui:Destroy()
end

-- Create Draggable UI (Always on top of game menus)
local gui = Instance.new("ScreenGui")
gui.Name = "NS_Rebirth"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(300, 150)
frame.Position = UDim2.new(0.5, -150, 0.15, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -10, 0, 95)
infoLabel.Position = UDim2.fromOffset(5, 5)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.TextSize = 12
infoLabel.TextWrapped = true
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Text = "Auto Rebirth & Stats (1-Click Input): Ready\nClick START to begin"
infoLabel.Parent = frame

local function createButton(text, xOffset, width)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(width, 32)
	button.Position = UDim2.fromOffset(xOffset, 108)
	button.Text = text
	button.TextSize = 14
	button.Parent = frame
	return button
end

local startButton = createButton("START", 5, 140)
local closeButton = createButton("CLOSE", 155, 140)

-- State & Configuration
local active = false
local alive = true
local busy = false
local rebirthCount = 0

local AGILITY_TARGET = 200
local INITIAL_RANGE_TARGET = 800
local ACTION_DELAY = 0.35

local function logStatus(stageText, detailText)
	local msg = string.format(
		"[Rebirths: %d] %s\n%s",
		rebirthCount,
		stageText,
		detailText or ""
	)
	infoLabel.Text = msg
	print("[AutoRebirth] " .. stageText .. (detailText and (" | " .. detailText) or ""))
end

-- Checks if an element is effectively visible on screen (and not in __Disable)
local function isVisible(obj)
	if not obj or not obj:IsDescendantOf(playerGui) then
		return false
	end
	local cur = obj
	while cur and cur ~= playerGui do
		if cur.Name == "__Disable" then
			return false
		end
		if cur:IsA("GuiObject") and not cur.Visible then
			return false
		end
		if cur:IsA("LayerCollector") and not cur.Enabled then
			return false
		end
		cur = cur.Parent
	end
	return obj.AbsoluteSize.X > 2 and obj.AbsoluteSize.Y > 2
end

-- Clicks a GuiButton safely
local function clickButton(btn)
	if not btn then return end
	if typeof(firesignal) == "function" then
		pcall(function() firesignal(btn.Activated) end)
		pcall(function() firesignal(btn.MouseButton1Click) end)
	else
		local inset = GuiService:GetGuiInset()
		local cx = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
		local cy = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2) + inset.Y
		VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
		task.wait(0.05)
		VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
	end
end

-- Trims whitespace and converts string to uppercase
local function cleanUpper(str)
	if type(str) ~= "string" then return "" end
	return string.upper(string.match(str, "^%s*(.-)%s*$") or "")
end

-- Finds the clickable GuiButton associated with a TextLabel/TextButton
local function getClickableFromLabel(lbl)
	if not lbl then return nil end
	if lbl:IsA("GuiButton") and isVisible(lbl) then
		return lbl
	end
	local ancestorBtn = lbl:FindFirstAncestorWhichIsA("GuiButton")
	if ancestorBtn and isVisible(ancestorBtn) then
		return ancestorBtn
	end
	local parent = lbl.Parent
	if parent then
		for _, child in ipairs(parent:GetDescendants()) do
			if child:IsA("GuiButton") and isVisible(child) then
				return child
			end
		end
	end
	return nil
end

-- Finds a visible TextLabel/TextButton with exact matching text (case-insensitive)
local function findVisibleLabelByExactText(targetText, searchRoot)
	local root = searchRoot or playerGui
	local target = cleanUpper(targetText)
	for _, desc in ipairs(root:GetDescendants()) do
		if not desc:IsDescendantOf(gui) and (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
			if cleanUpper(desc.Text) == target and isVisible(desc) then
				return desc
			end
		end
	end
	return nil
end

-- Checks if the Stats window is currently open
local function isStatsWindowOpen()
	local spendHeader = findVisibleLabelByExactText("SPEND YOUR POINTS")
	return spendHeader ~= nil
end

-- Reads available stat points from the "POINTS" diamond on the left panel
local function getAvailablePoints()
	local pointsHeader = findVisibleLabelByExactText("POINTS")
	if not pointsHeader then return 0 end

	local container = pointsHeader.Parent
	for _ = 1, 2 do
		if container then
			for _, desc in ipairs(container:GetDescendants()) do
				if desc ~= pointsHeader and desc:IsA("TextLabel") and isVisible(desc) then
					local raw = string.gsub(desc.Text or "", "[,%s]", "")
					local num = tonumber(raw)
					if num ~= nil then
						return num
					end
				end
			end
			container = container.Parent
		end
	end
	return 0
end

-- Finds the custom stat amount TextBox located next to the "Talents" and "x1" buttons
local function findAmountInputBox()
	local anchor = findVisibleLabelByExactText("Talents") or findVisibleLabelByExactText("x1")
	if anchor then
		local topBar = anchor.Parent
		for _ = 1, 4 do
			if topBar and topBar ~= playerGui then
				for _, desc in ipairs(topBar:GetDescendants()) do
					if not desc:IsDescendantOf(gui) and desc:IsA("TextBox") and isVisible(desc) then
						return desc
					end
				end
				topBar = topBar.Parent
			end
		end
	end

	-- Fallback: find any visible TextBox inside PlayerGui (excluding our script UI)
	for _, desc in ipairs(playerGui:GetDescendants()) do
		if not desc:IsDescendantOf(gui) and desc:IsA("TextBox") and isVisible(desc) then
			return desc
		end
	end
	return nil
end

-- Enters the exact stat amount into the top TextBox so 1 click allocates that amount
local function setCustomAmount(amount)
	local targetInt = math.max(1, math.floor(amount))
	local targetStr = tostring(targetInt)

	local box = findAmountInputBox()
	if not box then
		warn("[AutoRebirth] Could not find the custom amount TextBox!")
		return false
	end

	local currentVal = tonumber((string.gsub(box.Text or "", "[,%s]", "")))
	if currentVal == targetInt then
		return true
	end

	pcall(function()
		box:CaptureFocus()
	end)
	task.wait(0.05)

	box.Text = targetStr
	task.wait(0.05)

	if typeof(firesignal) == "function" then
		pcall(function() firesignal(box.FocusLost, true) end)
	end
	pcall(function()
		box:ReleaseFocus(true)
	end)

	-- Send Return key in case the game listens to Enter key release
	VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
	task.wait(0.04)
	VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
	task.wait(0.2)

	return true
end

-- Locates a stat row ("Shadow Agility", "Shadow Reach", "Player Experience")
-- Returns: currentLevel, maxLevel, upgradeButton, isMaxed
local function getStatRowData(statTitle)
	local titleLabel = findVisibleLabelByExactText(statTitle)
	if not titleLabel then return nil end

	local row = titleLabel.Parent
	while row and row ~= playerGui do
		local curLv, maxLv = nil, nil
		local actionBtn = nil
		local isMaxed = false

		for _, desc in ipairs(row:GetDescendants()) do
			if desc:IsA("TextLabel") and isVisible(desc) then
				local txt = desc.Text or ""
				local cStr, mStr = string.match(txt, "[Ll][Vv]%s*([%d,]+)%s*/%s*([%d,]+)")
				if cStr and mStr then
					curLv = tonumber((string.gsub(cStr, ",", "")))
					maxLv = tonumber((string.gsub(mStr, ",", "")))
				end
			end
		end

		if curLv and maxLv then
			for _, desc in ipairs(row:GetDescendants()) do
				if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and isVisible(desc) then
					local t = cleanUpper(desc.Text)
					if t == "MAX" or string.sub(t, 1, 1) == "+" then
						local b = getClickableFromLabel(desc)
						if b then
							actionBtn = b
							if t == "MAX" then
								isMaxed = true
							end
							break
						end
					end
				end
			end

			if curLv >= maxLv then
				isMaxed = true
			end
			return curLv, maxLv, actionBtn, isMaxed
		end

		row = row.Parent
	end

	return nil
end

-- Allocates `amount` points to the given row button in a single click
local function allocateStatOnce(stageName, amount, upgradeBtn, summary)
	if setCustomAmount(amount) then
		logStatus(stageName .. " (+" .. tostring(amount) .. ")", summary)
		clickButton(upgradeBtn)
		task.wait(ACTION_DELAY)
	end
end

-- Main Automation Step
local function stepAutomation()
	if busy then return end
	busy = true

	-- 1. Check if the "REBIRTH?" confirmation dialogue is currently open
	local rebirthConfirmHeader = findVisibleLabelByExactText("REBIRTH?")
	if rebirthConfirmHeader then
		local yesLabel = findVisibleLabelByExactText("YES")
		local yesBtn = getClickableFromLabel(yesLabel)
		if yesBtn then
			logStatus("Confirming Rebirth", "Clicking YES on confirmation popup...")
			clickButton(yesBtn)
			rebirthCount += 1
			task.wait(1.5)
			busy = false
			return
		end
	end

	-- 2. Make sure the Stats window is open
	if not isStatsWindowOpen() then
		local statsHexLabel = findVisibleLabelByExactText("Stats")
		local statsHexBtn = getClickableFromLabel(statsHexLabel)
		if statsHexBtn then
			logStatus("Opening Stats Window", "Clicking Stats menu button...")
			clickButton(statsHexBtn)
			task.wait(1.0)
		else
			logStatus("Waiting for UI", "Stats button / window not visible yet...")
		end
		busy = false
		return
	end

	-- 3. Check if the REBIRTH button is visible (Player is at Max Level)
	local rebirthLabel = findVisibleLabelByExactText("REBIRTH")
	local rebirthBtn = getClickableFromLabel(rebirthLabel)
	if rebirthBtn then
		logStatus("Max Level Reached!", "REBIRTH button detected. Clicking REBIRTH...")
		clickButton(rebirthBtn)
		task.wait(0.8)
		busy = false
		return
	end

	-- 4. Read current Points and Stat Row levels
	local points = getAvailablePoints()
	local agiCur, agiMax, agiBtn, agiMaxed = getStatRowData("Shadow Agility")
	local reachCur, reachMax, reachBtn, reachMaxed = getStatRowData("Shadow Reach")
	local expCur, expMax, expBtn, expMaxed = getStatRowData("Player Experience")

	if not (agiCur and reachCur and expCur) then
		logStatus("Reading Stats...", "Waiting for stat rows to load...")
		busy = false
		return
	end

	local summary = string.format(
		"Pts: %d | Agi: %d | Reach: %d | Exp: %d/%d",
		points, agiCur, reachCur, expCur, expMax
	)

	-- Wait if there are 0 points to spend right now
	if points <= 0 then
		logStatus("Waiting for Level Up / Rebirth", summary)
		busy = false
		return
	end

	-- Step 1: Add 200 stats to Shadow Agility in one click
	local agiGoal = math.min(AGILITY_TARGET, agiMax)
	if agiCur < agiGoal and not agiMaxed and agiBtn then
		local needed = agiGoal - agiCur
		local toAdd = math.min(points, needed)
		allocateStatOnce("Step 1: Shadow Agility -> 200", toAdd, agiBtn, summary)
		busy = false
		return
	end

	-- Step 2: Add 800 stats to Shadow Reach (Shadow Range) in one click
	local reachInitialGoal = math.min(INITIAL_RANGE_TARGET, reachMax)
	if reachCur < reachInitialGoal and not reachMaxed and reachBtn then
		local needed = reachInitialGoal - reachCur
		local toAdd = math.min(points, needed)
		allocateStatOnce("Step 2: Shadow Reach -> 800", toAdd, reachBtn, summary)
		busy = false
		return
	end

	-- Step 3: Add all remaining points to Player Experience until MAX in one click
	if not expMaxed and expCur < expMax and expBtn then
		local needed = expMax - expCur
		local toAdd = math.min(points, needed)
		allocateStatOnce("Step 3: Maxing Player Experience", toAdd, expBtn, summary)
		busy = false
		return
	end

	-- Step 4: Add excess points earned from leveling up to Shadow Reach in one click
	if not reachMaxed and reachCur < reachMax and reachBtn then
		local needed = reachMax - reachCur
		local toAdd = math.min(points, needed)
		allocateStatOnce("Step 4: Excess -> Shadow Reach", toAdd, reachBtn, summary)
		busy = false
		return
	end

	logStatus("Stats Maxed! Waiting for Max Player Level", summary)
	busy = false
end

-- Button Connections
startButton.MouseButton1Click:Connect(function()
	active = not active
	startButton.Text = active and "STOP" or "START"
	if active then
		logStatus("Automation Started", "Scanning Stats window...")
		task.spawn(stepAutomation)
	else
		logStatus("Automation Paused", "Click START to resume")
	end
end)

closeButton.MouseButton1Click:Connect(function()
	alive = false
	active = false
	gui:Destroy()
end)

-- Main Background Loop
task.spawn(function()
	while alive and gui.Parent do
		task.wait(0.4)
		if alive and active and not busy then
			stepAutomation()
		end
	end
end)
