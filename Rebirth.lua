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

-- Create Draggable Control UI
local gui = Instance.new("ScreenGui")
gui.Name = "NS_Rebirth"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(310, 150)
frame.Position = UDim2.new(0.5, -155, 0.15, 0)
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
infoLabel.Text = "Windowless Auto-Rebirth (Fixed Popup): Ready\nClick START"
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

local startButton = createButton("START", 5, 145)
local closeButton = createButton("CLOSE", 160, 145)

-- State & Configuration
local active = false
local alive = true
local busy = false
local rebirthCount = 0

local AGILITY_TARGET = 200
local INITIAL_RANGE_TARGET = 800
local ACTION_DELAY = 0.25

local function logStatus(stageText, detailText)
	local msg = string.format(
		"[Rebirths: %d] %s\n%s",
		rebirthCount,
		stageText,
		detailText or ""
	)
	infoLabel.Text = msg
	print("[BgRebirth] " .. stageText .. (detailText and (" | " .. detailText) or ""))
end

local function cleanUpper(str)
	if type(str) ~= "string" then return "" end
	return string.upper(string.match(str, "^%s*(.-)%s*$") or "")
end

-- Fires signals in the background
local function fireSignalBackground(signal, ...)
	if not signal then return false end
	local fired = false
	if typeof(getconnections) == "function" then
		local ok, conns = pcall(getconnections, signal)
		if ok and type(conns) == "table" and #conns > 0 then
			for _, conn in ipairs(conns) do
				if conn.Function then
					pcall(task.spawn, conn.Function, ...)
					fired = true
				elseif conn.Fire then
					pcall(conn.Fire, conn, ...)
					fired = true
				end
			end
		end
	end
	if not fired and typeof(firesignal) == "function" then
		local ok = pcall(firesignal, signal, ...)
		if ok then fired = true end
	end
	return fired
end

-- Safely clicks a button (supports both background signal firing and VIM mouse tap)
local function clickButtonSafe(btn)
	if not btn then return end
	fireSignalBackground(btn.Activated)
	fireSignalBackground(btn.MouseButton1Click)

	pcall(function()
		local inset = GuiService:GetGuiInset()
		local cx = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
		local cy = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2) + inset.Y
		VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
		task.wait(0.04)
		VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
	end)
end

-- Collects all candidate GuiButtons from a label
local function getAllButtonsFromLabel(lbl)
	local buttons = {}
	local seen = {}
	local function addBtn(b)
		if b and b:IsA("GuiButton") and not seen[b] then
			seen[b] = true
			table.insert(buttons, b)
		end
	end
	if not lbl then return buttons end
	addBtn(lbl)
	addBtn(lbl:FindFirstAncestorWhichIsA("GuiButton"))
	local p1 = lbl.Parent
	if p1 then
		addBtn(p1)
		for _, child in ipairs(p1:GetDescendants()) do
			addBtn(child)
		end
	end
	return buttons
end

local function triggerElementBackground(lblOrBtn)
	if not lblOrBtn then return false end
	if lblOrBtn:IsA("GuiButton") then
		clickButtonSafe(lblOrBtn)
		return true
	end
	local targets = getAllButtonsFromLabel(lblOrBtn)
	if #targets > 0 then
		for _, b in ipairs(targets) do
			clickButtonSafe(b)
		end
		return true
	end
	return false
end

-- Checks if an element is locally visible
local function isLocallyVisible(obj, stopAt)
	if not obj then return false end
	local cur = obj
	while cur and cur ~= stopAt and cur ~= playerGui do
		if cur.Name == "Menus" or cur.Name == "__Disable" or cur:IsA("ScreenGui") then
			break
		end
		if cur:IsA("GuiObject") and not cur.Visible then
			return false
		end
		cur = cur.Parent
	end
	return true
end

-- Finds labels matching targetText
local function findAllLabels(targetText, searchRoot)
	local root = searchRoot or playerGui
	local target = cleanUpper(targetText)
	local matches = {}
	for _, desc in ipairs(root:GetDescendants()) do
		if not desc:IsDescendantOf(gui) and (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
			if cleanUpper(desc.Text) == target then
				table.insert(matches, desc)
			end
		end
	end
	table.sort(matches, function(a, b)
		local aVis = isLocallyVisible(a)
		local bVis = isLocallyVisible(b)
		if aVis ~= bVis then return aVis end
		return false
	end)
	return matches
end

local function findBestLabel(targetText, searchRoot)
	local list = findAllLabels(targetText, searchRoot)
	return list[1]
end

-- Locates Stats UI root
local function getStatsRoot()
	local spendHeader = findBestLabel("SPEND YOUR POINTS")
	if not spendHeader then return nil end
	local cur = spendHeader
	while cur and cur.Parent and cur.Parent ~= playerGui do
		if cur:IsA("ScreenGui") or cur.Parent.Name == "Menus" or cur.Parent.Name == "__Disable" then
			return cur
		end
		cur = cur.Parent
	end
	return cur
end

-- Locates the exact "REBIRTH?" dialog and its "YES" button
local function findRebirthConfirmYesButton()
	local confirmHeaders = findAllLabels("REBIRTH?")
	for _, header in ipairs(confirmHeaders) do
		local dialogBox = header.Parent
		for _ = 1, 6 do
			if not dialogBox or dialogBox == playerGui then break end
			local yesLbl = findBestLabel("YES", dialogBox)
			local noLbl = findBestLabel("NO", dialogBox)
			if yesLbl and noLbl then
				return yesLbl
			end
			dialogBox = dialogBox.Parent
		end
	end
	return nil
end

-- Checks bottom HUD level bar for "(MAX)"
local function getHudLevelStatus()
	for _, desc in ipairs(playerGui:GetDescendants()) do
		if not desc:IsDescendantOf(gui) and desc:IsA("TextLabel") then
			local txt = desc.Text or ""
			if string.find(txt, "Level ", 1, true) and string.find(txt, "Rank", 1, true) then
				local lowerTxt = string.lower(txt)
				local isMax = string.find(lowerTxt, "(max)", 1, true) ~= nil
					or string.find(lowerTxt, "max", 1, true) ~= nil
				return isMax, txt
			end
		end
	end
	return false, nil
end

-- Reads unspent points
local function getAvailablePoints(statsRoot)
	local pointsHeader = findBestLabel("POINTS", statsRoot)
	if not pointsHeader then return 0 end
	local container = pointsHeader.Parent
	for _ = 1, 2 do
		if container then
			for _, desc in ipairs(container:GetDescendants()) do
				if desc ~= pointsHeader and desc:IsA("TextLabel") then
					local raw = string.gsub(desc.Text or "", "[,%s]", "")
					local num = tonumber(raw)
					if num ~= nil then return num end
				end
			end
			container = container.Parent
		end
	end
	return 0
end

-- Sets custom amount TextBox
local function setCustomAmountBackground(statsRoot, amount)
	local targetInt = math.max(1, math.floor(amount))
	local targetStr = tostring(targetInt)
	local updated = false

	local searchRoots = { statsRoot, playerGui }
	for _, root in ipairs(searchRoots) do
		if root then
			for _, desc in ipairs(root:GetDescendants()) do
				if not desc:IsDescendantOf(gui) and desc:IsA("TextBox") then
					fireSignalBackground(desc.Focused)
					desc.Text = targetStr
					task.wait(0.03)
					fireSignalBackground(desc:GetPropertyChangedSignal("Text"))
					fireSignalBackground(desc.FocusLost, true)
					updated = true
				end
			end
			if updated then break end
		end
	end
	task.wait(0.08)
	return updated
end

-- Reads stat row data
local function getStatRowData(statTitle, statsRoot)
	local titleLabel = findBestLabel(statTitle, statsRoot)
	if not titleLabel then return nil end

	local row = titleLabel.Parent
	while row and row ~= playerGui and row ~= statsRoot do
		local curLv, maxLv = nil, nil
		local actionTarget = nil
		local isMaxed = false

		for _, desc in ipairs(row:GetDescendants()) do
			if desc:IsA("TextLabel") then
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
				if desc:IsA("TextLabel") or desc:IsA("TextButton") then
					local t = cleanUpper(desc.Text)
					if t == "MAX" or string.sub(t, 1, 1) == "+" then
						local btns = getAllButtonsFromLabel(desc)
						if #btns > 0 then
							actionTarget = desc
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
			return curLv, maxLv, actionTarget, isMaxed
		end

		row = row.Parent
	end

	return nil
end

local function allocateStatBackground(statsRoot, stageName, amount, upgradeTarget, summary)
	setCustomAmountBackground(statsRoot, amount)
	logStatus(stageName .. " (+" .. tostring(amount) .. ")", summary)
	triggerElementBackground(upgradeTarget)
	task.wait(ACTION_DELAY)
end

-- Main Loop Step
local function stepBackgroundAutomation()
	if busy then return end
	busy = true

	local statsRoot = getStatsRoot()
	if not statsRoot then
		logStatus("Waiting for Game UI", "Stats hierarchy not found yet")
		busy = false
		return
	end

	-- 1. Check if "REBIRTH?" confirmation popup is open and click YES
	local yesTarget = findRebirthConfirmYesButton()
	if yesTarget then
		logStatus("Confirming Rebirth", "Clicking YES on popup...")
		triggerElementBackground(yesTarget)
		rebirthCount += 1
		task.wait(1.0)
		busy = false
		return
	end

	-- 2. Check if player is at Max Level via bottom HUD "(MAX)" OR the REBIRTH button
	local hudIsMax, hudText = getHudLevelStatus()
	local rebirthLabel = findBestLabel("REBIRTH", statsRoot)
	local rebirthReady = rebirthLabel and isLocallyVisible(rebirthLabel, statsRoot)

	if (hudIsMax or rebirthReady) and rebirthLabel then
		logStatus("Max Level Reached!", "Triggering REBIRTH...")
		triggerElementBackground(rebirthLabel)
		task.wait(0.4)

		-- Click YES on the resulting confirmation popup
		local confirmYes = findRebirthConfirmYesButton()
		if confirmYes then
			logStatus("Rebirth Confirmed!", "Clicking YES on popup...")
			triggerElementBackground(confirmYes)
			rebirthCount += 1
			task.wait(1.0)
		end

		busy = false
		return
	end

	-- 3. Read current Points and Stat Levels
	local points = getAvailablePoints(statsRoot)
	local agiCur, agiMax, agiTarget, agiMaxed = getStatRowData("Shadow Agility", statsRoot)
	local reachCur, reachMax, reachTarget, reachMaxed = getStatRowData("Shadow Reach", statsRoot)
	local expCur, expMax, expTarget, expMaxed = getStatRowData("Player Experience", statsRoot)

	if not (agiCur and reachCur and expCur) then
		logStatus("Reading Stats...", hudText or "Waiting for stat rows...")
		busy = false
		return
	end

	local summary = string.format(
		"Pts: %d | Agi: %d | Reach: %d | Exp: %d/%d",
		points, agiCur, reachCur, expCur, expMax
	)

	if points <= 0 then
		logStatus("Monitoring in Background", summary)
		busy = false
		return
	end

	-- Step 1: Shadow Agility -> 200
	local agiGoal = math.min(AGILITY_TARGET, agiMax)
	if agiCur < agiGoal and not agiMaxed and agiTarget then
		local toAdd = math.min(points, agiGoal - agiCur)
		allocateStatBackground(statsRoot, "Step 1: Shadow Agility -> 200", toAdd, agiTarget, summary)
		busy = false
		return
	end

	-- Step 2: Shadow Reach -> 800
	local reachInitialGoal = math.min(INITIAL_RANGE_TARGET, reachMax)
	if reachCur < reachInitialGoal and not reachMaxed and reachTarget then
		local toAdd = math.min(points, reachInitialGoal - reachCur)
		allocateStatBackground(statsRoot, "Step 2: Shadow Reach -> 800", toAdd, reachTarget, summary)
		busy = false
		return
	end

	-- Step 3: Player Experience -> MAX
	if not expMaxed and expCur < expMax and expTarget then
		local toAdd = math.min(points, expMax - expCur)
		allocateStatBackground(statsRoot, "Step 3: Maxing Player Exp", toAdd, expTarget, summary)
		busy = false
		return
	end

	-- Step 4: Excess -> Shadow Reach
	if not reachMaxed and reachCur < reachMax and reachTarget then
		local toAdd = math.min(points, reachMax - reachCur)
		allocateStatBackground(statsRoot, "Step 4: Excess -> Shadow Reach", toAdd, reachTarget, summary)
		busy = false
		return
	end

	logStatus("Waiting for Max Level (MAX)", summary)
	busy = false
end

-- UI Button Connections
startButton.MouseButton1Click:Connect(function()
	active = not active
	startButton.Text = active and "STOP" or "START"
	if active then
		logStatus("Background Mode Active", "Monitoring HUD & Stats...")
		task.spawn(stepBackgroundAutomation)
	else
		logStatus("Paused", "Click START to resume")
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
			stepBackgroundAutomation()
		end
	end
end)
