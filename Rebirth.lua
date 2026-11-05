local Players = game:GetService("Players")
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
infoLabel.Text = "Windowless Auto-Rebirth: Ready\nClick START (No windows will open)"
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

-- Fires a signal in the background without moving the mouse or needing the UI visible
local function fireSignalBackground(signal, ...)
	if not signal then return false end
	local fired = false

	if typeof(firesignal) == "function" then
		local ok = pcall(firesignal, signal, ...)
		if ok then fired = true end
	end

	if not fired and typeof(getconnections) == "function" then
		local ok, conns = pcall(getconnections, signal)
		if ok and type(conns) == "table" then
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

	return fired
end

-- Triggers a GuiButton completely in the background
local function triggerButtonBackground(btn)
	if not btn then return false end
	local ok1 = fireSignalBackground(btn.Activated)
	local ok2 = fireSignalBackground(btn.MouseButton1Click)
	fireSignalBackground(btn.MouseButton1Down, 0, 0)
	task.wait(0.02)
	fireSignalBackground(btn.MouseButton1Up, 0, 0)
	return ok1 or ok2
end

-- Checks if an element is enabled within its own local panel (even if parent ScreenGui is in __Disable)
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

-- Resolves the clickable GuiButton from a TextLabel or TextButton
local function getButtonFromLabel(lbl)
	if not lbl then return nil end
	if lbl:IsA("GuiButton") then
		return lbl
	end
	local ancestorBtn = lbl:FindFirstAncestorWhichIsA("GuiButton")
	if ancestorBtn then
		return ancestorBtn
	end
	local parent = lbl.Parent
	if parent then
		for _, child in ipairs(parent:GetDescendants()) do
			if child:IsA("GuiButton") then
				return child
			end
		end
	end
	return nil
end

-- Finds any TextLabel/TextButton in PlayerGui (including hidden inside __Disable) matching exact text
local function findLabelAnywhere(targetText, searchRoot)
	local root = searchRoot or playerGui
	local target = cleanUpper(targetText)
	for _, desc in ipairs(root:GetDescendants()) do
		if not desc:IsDescendantOf(gui) and (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
			if cleanUpper(desc.Text) == target then
				return desc
			end
		end
	end
	return nil
end

-- Locates the Stats UI container (whether in PlayerGui.Menus or PlayerGui.__Disable)
local function getStatsRoot()
	local spendHeader = findLabelAnywhere("SPEND YOUR POINTS")
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

-- Checks the bottom HUD level bar for "(max)" (e.g., "Level 1685 (max) · Rank GSR+")
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

-- Reads unspent stat points from the "POINTS" diamond in the Stats UI
local function getAvailablePoints(statsRoot)
	local pointsHeader = findLabelAnywhere("POINTS", statsRoot)
	if not pointsHeader then return 0 end

	local container = pointsHeader.Parent
	for _ = 1, 2 do
		if container then
			for _, desc in ipairs(container:GetDescendants()) do
				if desc ~= pointsHeader and desc:IsA("TextLabel") then
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

-- Locates the custom amount TextBox next to "Talents" and "x1" without opening the window
local function findAmountInputBox(statsRoot)
	local anchor = findLabelAnywhere("Talents", statsRoot) or findLabelAnywhere("x1", statsRoot)
	if anchor then
		local topBar = anchor.Parent
		for _ = 1, 4 do
			if topBar and topBar ~= playerGui then
				for _, desc in ipairs(topBar:GetDescendants()) do
					if not desc:IsDescendantOf(gui) and desc:IsA("TextBox") then
						return desc
					end
				end
				topBar = topBar.Parent
			end
		end
	end

	if statsRoot then
		for _, desc in ipairs(statsRoot:GetDescendants()) do
			if not desc:IsDescendantOf(gui) and desc:IsA("TextBox") then
				return desc
			end
		end
	end
	return nil
end

-- Sets the exact stat amount in the background without stealing keyboard focus
local function setCustomAmountBackground(statsRoot, amount)
	local targetInt = math.max(1, math.floor(amount))
	local targetStr = tostring(targetInt)

	local box = findAmountInputBox(statsRoot)
	if not box then
		return false
	end

	box.Text = targetStr
	task.wait(0.04)
	fireSignalBackground(box.FocusLost, true)
	task.wait(0.08)
	return true
end

-- Reads a stat row ("Shadow Agility", "Shadow Reach", "Player Experience") in the background
local function getStatRowData(statTitle, statsRoot)
	local titleLabel = findLabelAnywhere(statTitle, statsRoot)
	if not titleLabel then return nil end

	local row = titleLabel.Parent
	while row and row ~= playerGui and row ~= statsRoot do
		local curLv, maxLv = nil, nil
		local actionBtn = nil
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
						local b = getButtonFromLabel(desc)
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

-- Allocates `amount` points to the target stat row in a single background trigger
local function allocateStatBackground(statsRoot, stageName, amount, upgradeBtn, summary)
	if setCustomAmountBackground(statsRoot, amount) then
		logStatus(stageName .. " (+" .. tostring(amount) .. ")", summary)
		triggerButtonBackground(upgradeBtn)
		task.wait(ACTION_DELAY)
	end
end

-- Main Windowless Automation Loop Step
local function stepBackgroundAutomation()
	if busy then return end
	busy = true

	local statsRoot = getStatsRoot()
	if not statsRoot then
		logStatus("Waiting for Game UI", "Stats hierarchy not found in PlayerGui yet")
		busy = false
		return
	end

	-- 1. Check if the "REBIRTH?" confirmation prompt is active in the hierarchy
	local rebirthConfirmHeader = findLabelAnywhere("REBIRTH?", statsRoot) or findLabelAnywhere("REBIRTH?")
	if rebirthConfirmHeader and isLocallyVisible(rebirthConfirmHeader, statsRoot) then
		local confirmContainer = rebirthConfirmHeader.Parent and rebirthConfirmHeader.Parent.Parent or statsRoot
		local yesLabel = findLabelAnywhere("YES", confirmContainer) or findLabelAnywhere("YES", statsRoot)
		local yesBtn = getButtonFromLabel(yesLabel)
		if yesBtn then
			logStatus("Confirming Rebirth (Bg)", "Triggering YES in background...")
			triggerButtonBackground(yesBtn)
			rebirthCount += 1
			task.wait(1.0)
			busy = false
			return
		end
	end

	-- 2. Check if player is at Max Level via bottom HUD "(max)" OR the REBIRTH button
	local hudIsMax, hudText = getHudLevelStatus()
	local rebirthLabel = findLabelAnywhere("REBIRTH", statsRoot)
	local rebirthBtn = getButtonFromLabel(rebirthLabel)
	local rebirthBtnVisible = rebirthLabel and rebirthBtn and isLocallyVisible(rebirthBtn, statsRoot)

	if (hudIsMax or rebirthBtnVisible) and rebirthBtn then
		logStatus("Max Level Reached!", "Triggering REBIRTH in background...")
		triggerButtonBackground(rebirthBtn)
		task.wait(0.4)

		-- Immediately look for the YES confirmation button and trigger it
		local confirmContainer = statsRoot
		local yesLabel = findLabelAnywhere("YES", confirmContainer) or findLabelAnywhere("YES")
		local yesBtn = getButtonFromLabel(yesLabel)
		if yesBtn and isLocallyVisible(yesBtn, statsRoot) then
			logStatus("Rebirth Confirmed!", "Triggering YES in background...")
			triggerButtonBackground(yesBtn)
			rebirthCount += 1
			task.wait(1.0)
		end

		busy = false
		return
	end

	-- 3. Read current Points and Stat Levels in the background
	local points = getAvailablePoints(statsRoot)
	local agiCur, agiMax, agiBtn, agiMaxed = getStatRowData("Shadow Agility", statsRoot)
	local reachCur, reachMax, reachBtn, reachMaxed = getStatRowData("Shadow Reach", statsRoot)
	local expCur, expMax, expBtn, expMaxed = getStatRowData("Player Experience", statsRoot)

	if not (agiCur and reachCur and expCur) then
		logStatus("Reading Background Stats...", hudText or "Waiting for stat labels...")
		busy = false
		return
	end

	local summary = string.format(
		"Pts: %d | Agi: %d | Reach: %d | Exp: %d/%d",
		points, agiCur, reachCur, expCur, expMax
	)

	-- Wait passively if there are no unspent points
	if points <= 0 then
		logStatus("Monitoring in Background", summary)
		busy = false
		return
	end

	-- Priority 1: Add 200 stats to Shadow Agility in 1 click
	local agiGoal = math.min(AGILITY_TARGET, agiMax)
	if agiCur < agiGoal and not agiMaxed and agiBtn then
		local toAdd = math.min(points, agiGoal - agiCur)
		allocateStatBackground(statsRoot, "Step 1: Shadow Agility -> 200", toAdd, agiBtn, summary)
		busy = false
		return
	end

	-- Priority 2: Add 800 stats to Shadow Reach (Shadow Range) in 1 click
	local reachInitialGoal = math.min(INITIAL_RANGE_TARGET, reachMax)
	if reachCur < reachInitialGoal and not reachMaxed and reachBtn then
		local toAdd = math.min(points, reachInitialGoal - reachCur)
		allocateStatBackground(statsRoot, "Step 2: Shadow Reach -> 800", toAdd, reachBtn, summary)
		busy = false
		return
	end

	-- Priority 3: Add all remaining points to Player Experience until MAX in 1 click
	if not expMaxed and expCur < expMax and expBtn then
		local toAdd = math.min(points, expMax - expCur)
		allocateStatBackground(statsRoot, "Step 3: Maxing Player Exp", toAdd, expBtn, summary)
		busy = false
		return
	end

	-- Priority 4: Add excess points earned while leveling up to Shadow Reach in 1 click
	if not reachMaxed and reachCur < reachMax and reachBtn then
		local toAdd = math.min(points, reachMax - reachCur)
		allocateStatBackground(statsRoot, "Step 4: Excess -> Shadow Reach", toAdd, reachBtn, summary)
		busy = false
		return
	end

	logStatus("Waiting for Max Level (max)", summary)
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
