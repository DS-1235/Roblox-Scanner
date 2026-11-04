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
infoLabel.Text = "Background Auto-Rebirth: Ready\nClick START to run in background"
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
local lastSyncTime = os.clock()

local AGILITY_TARGET = 200
local INITIAL_RANGE_TARGET = 800
local ACTION_DELAY = 0.3
local PERIODIC_SYNC_INTERVAL = 12 -- Seconds between quick checks if UI updates are paused while closed

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

local function cleanUpper(str)
	if type(str) ~= "string" then return "" end
	return string.upper(string.match(str, "^%s*(.-)%s*$") or "")
end

-- Checks if an element is actively visible on screen (not inside __Disable)
local function isVisibleOnScreen(obj)
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

-- Checks if an element is marked Visible within its own local hierarchy (works even inside __Disable)
local function isLocallyVisible(obj, stopAt)
	if not obj then return false end
	local cur = obj
	while cur and cur ~= stopAt and cur ~= playerGui do
		if cur:IsA("GuiObject") and not cur.Visible then
			return false
		end
		cur = cur.Parent
	end
	return true
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

-- Resolves a clickable GuiButton from a label or button
local function getClickableFromLabel(lbl, requireScreenVisible)
	if not lbl then return nil end
	local checkFn = requireScreenVisible and isVisibleOnScreen or function(o) return o ~= nil end

	if lbl:IsA("GuiButton") and checkFn(lbl) then
		return lbl
	end
	local ancestorBtn = lbl:FindFirstAncestorWhichIsA("GuiButton")
	if ancestorBtn and checkFn(ancestorBtn) then
		return ancestorBtn
	end
	local parent = lbl.Parent
	if parent then
		for _, child in ipairs(parent:GetDescendants()) do
			if child:IsA("GuiButton") and checkFn(child) then
				return child
			end
		end
	end
	return nil
end

-- Finds a TextLabel/TextButton by exact text (supports both visible-only and background searches)
local function findLabelByText(targetText, requireScreenVisible, searchRoot)
	local root = searchRoot or playerGui
	local target = cleanUpper(targetText)
	for _, desc in ipairs(root:GetDescendants()) do
		if not desc:IsDescendantOf(gui) and (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
			if cleanUpper(desc.Text) == target then
				if not requireScreenVisible or isVisibleOnScreen(desc) then
					return desc
				end
			end
		end
	end
	return nil
end

-- Locates the root window container of the Stats UI (whether open in Menus or closed in __Disable)
local function getStatsWindowRoot(requireScreenVisible)
	local spendHeader = findLabelByText("SPEND YOUR POINTS", requireScreenVisible)
	if not spendHeader then return nil end

	local cur = spendHeader
	for _ = 1, 6 do
		if not cur.Parent or cur.Parent == playerGui or cur.Parent.Name == "Menus" or cur.Parent.Name == "__Disable" then
			break
		end
		cur = cur.Parent
	end
	return cur
end

local function isStatsWindowOpen()
	return findLabelByText("SPEND YOUR POINTS", true) ~= nil
end

-- Finds the top-right red "X" Close button (strictly anchored next to "x100" so it never clicks "RESET STATS")
local function findStatsCloseButton()
	local x100Label = findLabelByText("x100", true)
	if not x100Label then return nil end

	local x100Pos = x100Label.AbsolutePosition
	local headerContainer = x100Label.Parent
	for _ = 1, 4 do
		if headerContainer and headerContainer ~= playerGui then
			for _, desc in ipairs(headerContainer:GetDescendants()) do
				if not desc:IsDescendantOf(gui) and (desc:IsA("TextLabel") or desc:IsA("TextButton")) and isVisibleOnScreen(desc) then
					if cleanUpper(desc.Text) == "X" then
						-- Verify it is to the right of x100 and on the same top header row
						local pos = desc.AbsolutePosition
						if pos.X > x100Pos.X and math.abs(pos.Y - x100Pos.Y) < 70 then
							local btn = getClickableFromLabel(desc, true)
							if btn then
								return btn
							end
						end
					end
				end
			end
			headerContainer = headerContainer.Parent
		end
	end
	return nil
end

-- Closes the Stats window if it is currently open on screen
local function closeStatsWindow()
	if not isStatsWindowOpen() then return end
	local closeBtn = findStatsCloseButton()
	if closeBtn then
		clickButton(closeBtn)
		task.wait(0.25)
	end
end

-- Opens the Stats window by clicking the "Stats" hexagon button
local function openStatsWindow()
	if isStatsWindowOpen() then return true end
	local statsHexLabel = findLabelByText("Stats", true)
	local statsHexBtn = getClickableFromLabel(statsHexLabel, true)
	if statsHexBtn then
		clickButton(statsHexBtn)
		for _ = 1, 10 do
			task.wait(0.1)
			if isStatsWindowOpen() then
				lastSyncTime = os.clock()
				return true
			end
		end
	end
	return isStatsWindowOpen()
end

-- Reads unspent stat points (works both when Stats window is open or in background)
local function getAvailablePoints(statsRoot, requireScreenVisible)
	local pointsHeader = findLabelByText("POINTS", requireScreenVisible, statsRoot)
	if not pointsHeader then return nil end

	local container = pointsHeader.Parent
	for _ = 1, 2 do
		if container then
			for _, desc in ipairs(container:GetDescendants()) do
				if desc ~= pointsHeader and desc:IsA("TextLabel") then
					if not requireScreenVisible or isVisibleOnScreen(desc) then
						local raw = string.gsub(desc.Text or "", "[,%s]", "")
						local num = tonumber(raw)
						if num ~= nil then
							return num
						end
					end
				end
			end
			container = container.Parent
		end
	end
	return nil
end

-- Reads a stat row ("Shadow Agility", "Shadow Reach", "Player Experience")
local function getStatRowData(statTitle, statsRoot, requireScreenVisible)
	local titleLabel = findLabelByText(statTitle, requireScreenVisible, statsRoot)
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
						local b = getClickableFromLabel(desc, requireScreenVisible)
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

-- Checks if the REBIRTH button is available (even in background)
local function isRebirthAvailable(statsRoot, requireScreenVisible)
	local rebirthLabel = findLabelByText("REBIRTH", requireScreenVisible, statsRoot)
	if not rebirthLabel then return false, nil end
	if not isLocallyVisible(rebirthLabel, statsRoot) then
		return false, nil
	end
	local btn = getClickableFromLabel(rebirthLabel, requireScreenVisible)
	if not btn or not isLocallyVisible(btn, statsRoot) then
		return false, nil
	end
	return true, btn
end

-- Finds the custom stat amount TextBox located next to "Talents" and "x1"
local function findAmountInputBox()
	local anchor = findLabelByText("Talents", true) or findLabelByText("x1", true)
	if anchor then
		local topBar = anchor.Parent
		for _ = 1, 4 do
			if topBar and topBar ~= playerGui then
				for _, desc in ipairs(topBar:GetDescendants()) do
					if not desc:IsDescendantOf(gui) and desc:IsA("TextBox") and isVisibleOnScreen(desc) then
						return desc
					end
				end
				topBar = topBar.Parent
			end
		end
	end
	return nil
end

-- Enters the exact stat amount into the top TextBox so 1 click allocates that amount
local function setCustomAmount(amount)
	local targetInt = math.max(1, math.floor(amount))
	local targetStr = tostring(targetInt)

	local box = findAmountInputBox()
	if not box then return false end

	local currentVal = tonumber((string.gsub(box.Text or "", "[,%s]", "")))
	if currentVal == targetInt then
		return true
	end

	pcall(function() box:CaptureFocus() end)
	task.wait(0.05)

	box.Text = targetStr
	task.wait(0.05)

	if typeof(firesignal) == "function" then
		pcall(function() firesignal(box.FocusLost, true) end)
	end
	pcall(function() box:ReleaseFocus(true) end)

	VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
	task.wait(0.04)
	VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
	task.wait(0.18)

	return true
end

-- Allocates `amount` points to the given row button in a single click
local function allocateStatOnce(stageName, amount, upgradeBtn, summary)
	if setCustomAmount(amount) then
		logStatus(stageName .. " (+" .. tostring(amount) .. ")", summary)
		clickButton(upgradeBtn)
		task.wait(ACTION_DELAY)
	end
end

-- Inspects current state (works in background or foreground) to decide if we need the window open
local function checkNeedsAction(requireScreenVisible)
	if findLabelByText("REBIRTH?", true) then
		return true, "Rebirth Confirm Open", ""
	end

	local statsRoot = getStatsWindowRoot(requireScreenVisible)
	if not statsRoot then
		return false, "Stats UI not loaded yet", ""
	end

	local canRebirth = isRebirthAvailable(statsRoot, requireScreenVisible)
	local points = getAvailablePoints(statsRoot, requireScreenVisible) or 0
	local agiCur, agiMax, _, agiMaxed = getStatRowData("Shadow Agility", statsRoot, requireScreenVisible)
	local reachCur, reachMax, _, reachMaxed = getStatRowData("Shadow Reach", statsRoot, requireScreenVisible)
	local expCur, expMax, _, expMaxed = getStatRowData("Player Experience", statsRoot, requireScreenVisible)

	local summary = string.format(
		"Pts: %d | Agi: %s | Reach: %s | Exp: %s/%s",
		points,
		tostring(agiCur or "?"),
		tostring(reachCur or "?"),
		tostring(expCur or "?"),
		tostring(expMax or "?")
	)

	if canRebirth then
		return true, "Max Level! Rebirth Ready", summary
	end

	if points > 0 and agiCur and reachCur and expCur then
		local agiNeed = (not agiMaxed) and (agiCur < math.min(AGILITY_TARGET, agiMax))
		local reachInitNeed = (not reachMaxed) and (reachCur < math.min(INITIAL_RANGE_TARGET, reachMax))
		local expNeed = (not expMaxed) and (expCur < expMax)
		local reachExcessNeed = (not reachMaxed) and (reachCur < reachMax)

		if agiNeed or reachInitNeed or expNeed or reachExcessNeed then
			return true, "Points Available (" .. points .. ")", summary
		end
	end

	return false, "Monitoring in Background", summary
end

-- Executes pending Rebirth and Stat Allocations, then immediately closes the Stats window
local function executeActiveBurst()
	if not openStatsWindow() then
		logStatus("Waiting for UI", "Could not open Stats window right now")
		return
	end

	-- Process up to 6 actions in a single burst so everything finishes in ~1 second
	for _ = 1, 6 do
		if not active then break end

		-- 1. Confirm Rebirth if popup is open
		local rebirthConfirmHeader = findLabelByText("REBIRTH?", true)
		if rebirthConfirmHeader then
			local yesLabel = findLabelByText("YES", true)
			local yesBtn = getClickableFromLabel(yesLabel, true)
			if yesBtn then
				logStatus("Confirming Rebirth", "Clicking YES...")
				clickButton(yesBtn)
				rebirthCount += 1
				task.wait(1.2)
			end
		end

		local statsRoot = getStatsWindowRoot(true)
		if not statsRoot then break end

		-- 2. Click REBIRTH if visible
		local canRebirth, rebirthBtn = isRebirthAvailable(statsRoot, true)
		if canRebirth and rebirthBtn then
			logStatus("Max Level Reached!", "Clicking REBIRTH...")
			clickButton(rebirthBtn)
			task.wait(0.6)
			continue
		end

		-- 3. Read live points & stat rows
		local points = getAvailablePoints(statsRoot, true) or 0
		local agiCur, agiMax, agiBtn, agiMaxed = getStatRowData("Shadow Agility", statsRoot, true)
		local reachCur, reachMax, reachBtn, reachMaxed = getStatRowData("Shadow Reach", statsRoot, true)
		local expCur, expMax, expBtn, expMaxed = getStatRowData("Player Experience", statsRoot, true)

		if not (agiCur and reachCur and expCur) or points <= 0 then
			break
		end

		local summary = string.format(
			"Pts: %d | Agi: %d | Reach: %d | Exp: %d/%d",
			points, agiCur, reachCur, expCur, expMax
		)

		-- Priority 1: Shadow Agility -> 200 (1 click)
		local agiGoal = math.min(AGILITY_TARGET, agiMax)
		if agiCur < agiGoal and not agiMaxed and agiBtn then
			local toAdd = math.min(points, agiGoal - agiCur)
			allocateStatOnce("Step 1: Shadow Agility -> 200", toAdd, agiBtn, summary)
			continue
		end

		-- Priority 2: Shadow Reach -> 800 (1 click)
		local reachInitialGoal = math.min(INITIAL_RANGE_TARGET, reachMax)
		if reachCur < reachInitialGoal and not reachMaxed and reachBtn then
			local toAdd = math.min(points, reachInitialGoal - reachCur)
			allocateStatOnce("Step 2: Shadow Reach -> 800", toAdd, reachBtn, summary)
			continue
		end

		-- Priority 3: Player Experience -> MAX (1 click)
		if not expMaxed and expCur < expMax and expBtn then
			local toAdd = math.min(points, expMax - expCur)
			allocateStatOnce("Step 3: Maxing Player Exp", toAdd, expBtn, summary)
			continue
		end

		-- Priority 4: Excess Points -> Shadow Reach (1 click)
		if not reachMaxed and reachCur < reachMax and reachBtn then
			local toAdd = math.min(points, reachMax - reachCur)
			allocateStatOnce("Step 4: Excess -> Shadow Reach", toAdd, reachBtn, summary)
			continue
		end

		-- All target stats are maxed
		break
	end

	-- Immediately close the Stats window so gameplay is never blocked
	closeStatsWindow()
	lastSyncTime = os.clock()
end

-- Main Background Loop Step
local function stepBackgroundAutomation()
	if busy then return end
	busy = true

	-- Check background state without opening the window
	local needsAction, statusTitle, summary = checkNeedsAction(false)

	-- Periodic quick sync in case the game doesn't update hidden UI labels while closed
	if not needsAction and (os.clock() - lastSyncTime) >= PERIODIC_SYNC_INTERVAL then
		if openStatsWindow() then
			task.wait(0.15)
			needsAction, statusTitle, summary = checkNeedsAction(true)
			if not needsAction then
				closeStatsWindow()
			end
		end
		lastSyncTime = os.clock()
	end

	if needsAction then
		executeActiveBurst()
		local _, postTitle, postSummary = checkNeedsAction(false)
		logStatus(postTitle, postSummary)
	else
		-- Make sure the Stats window stays closed while idle
		if isStatsWindowOpen() then
			closeStatsWindow()
		end
		logStatus(statusTitle, summary)
	end

	busy = false
end

-- Button Connections
startButton.MouseButton1Click:Connect(function()
	active = not active
	startButton.Text = active and "STOP" or "START"
	if active then
		lastSyncTime = 0 -- Force an immediate initial sync on start
		logStatus("Background Mode Started", "Syncing Stats state...")
		task.spawn(stepBackgroundAutomation)
	else
		logStatus("Automation Paused", "Click START to resume")
	end
end)

closeButton.MouseButton1Click:Connect(function()
	alive = false
	active = false
	gui:Destroy()
end)

-- Background Monitor Loop
task.spawn(function()
	while alive and gui.Parent do
		task.wait(0.5)
		if alive and active and not busy then
			stepBackgroundAutomation()
		end
	end
end)
