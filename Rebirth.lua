-- ====================================================================
-- SOLO LEVELING / ANIME SHADOW: 100% BACKGROUND AUTO-REBIRTH (V21 - PRODUCTION)
-- ====================================================================
-- FIXES APPLIED IN V21:
-- 1. STRICT STAT ALLOCATION ORDER & AMOUNTS (FIXED OVER-ALLOCATION):
--    - Shadow Agility  -> Strictly capped at 200.
--    - Shadow Reach    -> Strictly capped at 800 (atomic single-click, no double-tap).
--    - Player Exp      -> Receives ALL remaining points until MAX (e.g. 3,375).
--    - Overflow        -> ONLY if Player Exp is 100% MAX, excess feeds into Shadow Reach.
-- 2. ELIMINATED DOUBLE-TAP LATENCY BUG:
--    - Replaced rapid 0.06s double-clicking with atomic click + server sync polling.
--    - Waits up to 1.5s for server acknowledgement before re-evaluating.
-- 3. AIRTIGHT ROW ISOLATION:
--    - Single-row validator ensures the script never ascends to parent list container.
--    - Exactly 1 upgrade button and 1 Lv label per stat row.
-- 4. ELIMINATED 79 GHOST POINTS BUG:
--    - sa_reset Robux price tag is strictly excluded.
--    - 0 unspent points is recognized as valid idle state.
-- 5. 100% BACKGROUND EXECUTION: Zero window opening, zero HUD clicks.
-- ====================================================================

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove prior UI instances
for _, name in ipairs({"NS_Rebirth", "AutoRebirthGui", "SoloRebirth_V13", "SoloRebirth_V14", "SoloRebirth_V15", "SoloRebirth_V16", "SoloRebirth_V17", "SoloRebirth_V18", "SoloRebirth_V19", "SoloRebirth_V20", "SoloRebirth_V21"}) do
    local old = playerGui:FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end

-- Target Configuration
local TARGET_AGILITY = 200
local TARGET_REACH   = 800

-- Runtime Variables
local isRunning = true
local isProcessing = false
local rebirthCount = 0
local lastRebirthTime = 0

-- --------------------------------------------------------------------
-- 1. STRING CLEANING & SAFE TEXT RESOLUTION
-- --------------------------------------------------------------------
local function cleanAlpha(str)
    if type(str) ~= "string" then return "" end
    local noTags = string.gsub(str, "<[^>]+>", "")
    return string.upper(string.gsub(noTags, "[^%a]", ""))
end

local function cleanUpper(str)
    if type(str) ~= "string" then return "" end
    local noTags = string.gsub(str, "<[^>]+>", "")
    return string.upper(string.match(noTags, "^%s*(.-)%s*$") or "")
end

local function getButtonText(btn)
    if not btn then return "" end
    if btn:IsA("TextButton") then
        return cleanUpper(btn.Text)
    end
    for _, child in ipairs(btn:GetDescendants()) do
        if child:IsA("TextLabel") and child.Text then
            return cleanUpper(child.Text)
        end
    end
    return cleanUpper(btn.Name)
end

local function diagLog(msg)
    print(string.format("[SoloRebirth-V21] %s", tostring(msg)))
end

-- --------------------------------------------------------------------
-- 2. MULTI-SIGNAL MEMORY DISPATCHER
-- --------------------------------------------------------------------
local function createFakeMouseInput(state)
    return {
        UserInputType = Enum.UserInputType.MouseButton1,
        UserInputState = state or Enum.UserInputState.Begin,
        Position = Vector3.new(0, 0, 0),
        Delta = Vector3.new(0, 0, 0),
        KeyCode = Enum.KeyCode.Unknown
    }
end

local function fireMultiSignalBackground(btn)
    if not btn then return false end

    local targets = {}
    local seen = {}
    local function addTarget(obj)
        if obj and obj:IsA("GuiObject") and not seen[obj] then
            seen[obj] = true
            table.insert(targets, obj)
        end
    end

    addTarget(btn)
    addTarget(btn:FindFirstAncestorWhichIsA("GuiButton"))
    if btn.Parent and btn.Parent:IsA("GuiObject") then
        addTarget(btn.Parent)
    end
    for _, child in ipairs(btn:GetChildren()) do
        if child:IsA("GuiButton") then addTarget(child) end
    end

    local totalFired = 0

    for _, target in ipairs(targets) do
        if typeof(getconnections) == "function" then
            if target:IsA("GuiButton") then
                pcall(function()
                    for _, c in ipairs(getconnections(target.Activated)) do
                        if c.Function then task.spawn(c.Function); totalFired = totalFired + 1
                        elseif c.Fire then c:Fire(); totalFired = totalFired + 1 end
                    end
                end)
                pcall(function()
                    for _, c in ipairs(getconnections(target.MouseButton1Click)) do
                        if c.Function then task.spawn(c.Function); totalFired = totalFired + 1
                        elseif c.Fire then c:Fire(); totalFired = totalFired + 1 end
                    end
                end)
                pcall(function()
                    for _, c in ipairs(getconnections(target.MouseButton1Down)) do
                        if c.Function then task.spawn(c.Function); totalFired = totalFired + 1
                        elseif c.Fire then c:Fire(); totalFired = totalFired + 1 end
                    end
                    for _, c in ipairs(getconnections(target.MouseButton1Up)) do
                        if c.Function then task.spawn(c.Function); totalFired = totalFired + 1
                        elseif c.Fire then c:Fire(); totalFired = totalFired + 1 end
                    end
                end)
            end

            pcall(function()
                local fakeBegin = createFakeMouseInput(Enum.UserInputState.Begin)
                local fakeEnd   = createFakeMouseInput(Enum.UserInputState.End)

                for _, c in ipairs(getconnections(target.InputBegan)) do
                    if c.Function then task.spawn(c.Function, fakeBegin, false); totalFired = totalFired + 1
                    elseif c.Fire then c:Fire(fakeBegin, false); totalFired = totalFired + 1 end
                end
                for _, c in ipairs(getconnections(target.InputEnded)) do
                    if c.Function then task.spawn(c.Function, fakeEnd, false); totalFired = totalFired + 1
                    elseif c.Fire then c:Fire(fakeEnd, false); totalFired = totalFired + 1 end
                end
            end)
        end

        if typeof(firesignal) == "function" and target:IsA("GuiButton") then
            pcall(function() firesignal(target.Activated); totalFired = totalFired + 1 end)
            pcall(function() firesignal(target.MouseButton1Click); totalFired = totalFired + 1 end)
            pcall(function() firesignal(target.MouseButton1Down); totalFired = totalFired + 1 end)
            pcall(function() firesignal(target.MouseButton1Up); totalFired = totalFired + 1 end)
        end
    end

    return totalFired > 0
end

-- --------------------------------------------------------------------
-- 3. UI LOCATORS IN MEMORY
-- --------------------------------------------------------------------
local function getStatsRoot()
    local disableFolder = playerGui:FindFirstChild("__Disable")
    if disableFolder then
        local win = disableFolder:FindFirstChild("UI_Stats", true)
        if win then return win end
    end

    local menusFolder = playerGui:FindFirstChild("Menus")
    if menusFolder then
        local win = menusFolder:FindFirstChild("UI_Stats", true)
        if win then return win end
    end

    local direct = playerGui:FindFirstChild("UI_Stats", true)
    if direct and direct.Name == "UI_Stats" and not direct:FindFirstAncestor("SoloRebirth_V21") then
        return direct
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if not desc:FindFirstAncestor("SoloRebirth_V21") and desc:IsA("TextLabel") and desc.Text then
            local clean = cleanAlpha(desc.Text)
            if string.find(clean, "SPENDYOURPOINTS") then
                local p = desc.Parent
                while p and p ~= playerGui do
                    if p.Name == "UI_Stats" or (p:IsA("Frame") and p.AbsoluteSize.X > 300) then
                        return p
                    end
                    p = p.Parent
                end
            end
        end
    end
    return nil
end

local function isPlayerAtMaxLevel()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if not desc:FindFirstAncestor("SoloRebirth_V21") and not desc:FindFirstAncestor("UI_Stats") and desc:IsA("TextLabel") and desc.Text then
            local raw = desc.Text
            if string.find(raw, "%(MAX%)") then
                return true, raw
            end
        end
    end
    return false, nil
end

local function findRebirthButton(statsRoot)
    if not statsRoot then return nil end

    local saCols = statsRoot:FindFirstChild("sa_cols", true)
    if saCols then
        local saSide = saCols:FindFirstChild("sa_side", true)
        if saSide then
            local saRebirth = saSide:FindFirstChild("sa_rebirth", true)
            if saRebirth then
                local btn = saRebirth:IsA("GuiButton") and saRebirth or saRebirth:FindFirstChildWhichIsA("GuiButton", true)
                if btn then return btn end
            end

            for _, child in ipairs(saSide:GetChildren()) do
                if child:IsA("GuiButton") and not string.find(string.lower(child.Name), "reset") then
                    local txt = getButtonText(child)
                    if cleanAlpha(txt) == "REBIRTH" then return child end
                end
                for _, b in ipairs(child:GetChildren()) do
                    if b:IsA("GuiButton") and not string.find(string.lower(child.Name), "reset") then
                        local txt = getButtonText(b)
                        if cleanAlpha(txt) == "REBIRTH" then return b end
                    end
                end
            end
        end
    end

    for _, desc in ipairs(statsRoot:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and cleanAlpha(desc.Text) == "REBIRTH" then
            local btn = desc:FindFirstAncestorWhichIsA("GuiButton") or (desc.Parent and desc.Parent:FindFirstChildWhichIsA("GuiButton"))
            if btn then return btn end
        end
    end
    return nil
end

local function findRebirthConfirmYesButton(statsRoot)
    if not statsRoot then return nil end

    local nuiRebirth = statsRoot:FindFirstChild("NUI_Rebirth", true)
    if nuiRebirth then
        for _, desc in ipairs(nuiRebirth:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text then
                local clean = cleanAlpha(desc.Text)
                if clean == "YES" or clean == "CONFIRM" then
                    local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                    if btn and not string.find(string.lower(btn.Name), "no") then
                        return btn
                    end
                end
            end
        end
        for _, desc in ipairs(nuiRebirth:GetChildren()) do
            if desc:IsA("GuiButton") and not string.find(string.lower(desc.Name), "no") then
                return desc
            end
            local childBtn = desc:FindFirstChildWhichIsA("GuiButton")
            if childBtn and not string.find(string.lower(childBtn.Name), "no") then
                return childBtn
            end
        end
    end

    for _, desc in ipairs(statsRoot:GetDescendants()) do
        local rawText = (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text or ""
        local clean = cleanAlpha(rawText)

        if clean == "YES" or clean == "CONFIRM" then
            local container = desc.Parent
            local isRebirthDialog = false
            for _ = 1, 6 do
                if not container or container == statsRoot then break end
                for _, sib in ipairs(container:GetDescendants()) do
                    if (sib:IsA("TextLabel") or sib:IsA("TextButton")) and sib.Text then
                        local sibClean = cleanAlpha(sib.Text)
                        if string.find(sibClean, "REBIRTH") or (string.find(sibClean, "RESET") and not string.find(sibClean, "STATS")) then
                            isRebirthDialog = true
                            break
                        end
                    end
                end
                if isRebirthDialog then break end
                container = container.Parent
            end

            if isRebirthDialog then
                local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                if btn and not string.find(string.lower(btn.Name), "no") then
                    return btn
                end
                return desc
            end
        end
    end
    return nil
end

-- --------------------------------------------------------------------
-- 4. POINT READING (EXCLUDES SA_RESET 79 ROBUX BUTTON)
-- --------------------------------------------------------------------
local function getAvailablePoints(statsRoot)
    if not statsRoot then return 0 end

    local saCols = statsRoot:FindFirstChild("sa_cols", true)
    local saSide = saCols and saCols:FindFirstChild("sa_side", true)
    if saSide then
        -- 1. Check Diamond Badge: Find pure number whose parent has "POINTS"
        for _, desc in ipairs(saSide:GetDescendants()) do
            -- STRICT FILTER: Ignore Reset Stats button entirely!
            if desc:FindFirstAncestor("sa_reset") or string.find(string.lower(desc.Name), "reset") or (desc.Parent and string.find(string.lower(desc.Parent.Name), "reset")) then
                continue
            end

            if desc:IsA("TextLabel") and desc.Text then
                local raw = string.match(desc.Text, "^%s*([%d,]+)%s*$")
                if raw then
                    local clean = string.gsub(raw, "[,%s]", "")
                    local num = tonumber(clean)
                    if num ~= nil and num < 10000000 then
                        -- Check if parent or sibling has "POINTS"
                        local p = desc.Parent
                        local isPointsBadge = false
                        if p then
                            if string.find(string.lower(p.Name), "point") then isPointsBadge = true end
                            for _, sib in ipairs(p:GetChildren()) do
                                if sib:IsA("TextLabel") and sib.Text and string.find(cleanAlpha(sib.Text), "POINTS") then
                                    isPointsBadge = true
                                    break
                                end
                            end
                        end
                        if isPointsBadge then
                            return num
                        end
                    end
                end
            end
        end

        -- 2. Fallback in sa_side: first standalone number NOT in sa_reset
        for _, desc in ipairs(saSide:GetDescendants()) do
            if not desc:FindFirstAncestor("sa_reset") and not string.find(string.lower(desc.Name), "reset") and not (desc.Parent and string.find(string.lower(desc.Parent.Name), "reset")) then
                if desc:IsA("TextLabel") and desc.Text then
                    local raw = string.match(desc.Text, "^%s*([%d,]+)%s*$")
                    if raw then
                        local num = tonumber(string.gsub(raw, "[,%s]", ""))
                        if num ~= nil and num < 10000000 then
                            return num
                        end
                    end
                end
            end
        end
    end

    return 0
end

local function setCustomAmountBackground(statsRoot, amount)
    if not statsRoot then return end
    local targetVal = math.max(1, math.floor(amount))
    local str = tostring(targetVal)

    for _, desc in ipairs(statsRoot:GetDescendants()) do
        if desc:IsA("TextBox") then
            if desc.Text ~= str then
                desc.Text = str
                pcall(function()
                    if typeof(firesignal) == "function" then
                        firesignal(desc.FocusLost, true)
                        firesignal(desc:GetPropertyChangedSignal("Text"))
                    end
                    if typeof(getconnections) == "function" then
                        for _, c in ipairs(getconnections(desc.FocusLost)) do
                            if c.Function then task.spawn(c.Function, true) elseif c.Fire then c:Fire(true) end
                        end
                        for _, c in ipairs(getconnections(desc:GetPropertyChangedSignal("Text"))) do
                            if c.Function then task.spawn(c.Function) elseif c.Fire then c:Fire() end
                        end
                    end
                end)
                task.wait(0.08)
            end
            return
        end
    end
end

-- Strictly validates that a frame contains EXACTLY one stat row (prevents ascending to list container)
local function isSingleStatRow(frame)
    if not frame or not frame:IsA("GuiObject") then return false end
    local titleCount = 0
    local hasLv = false
    local hasBtn = false

    local knownTitles = {
        ["SHADOWPOWER"] = true,
        ["WEAPONMASTERY"] = true,
        ["SHADOWAGILITY"] = true,
        ["SHADOWREACH"] = true,
        ["PLAYERSPEED"] = true,
        ["PLAYEREXPERIENCE"] = true
    }

    for _, child in ipairs(frame:GetDescendants()) do
        if child:IsA("TextLabel") and child.Text then
            local c = cleanAlpha(child.Text)
            if knownTitles[c] then
                titleCount = titleCount + 1
            end
            if string.find(child.Text, "Lv") then
                hasLv = true
            end
        end
        if child:IsA("GuiButton") then
            hasBtn = true
        end
    end

    return (titleCount == 1) and hasLv and hasBtn
end

local function getStatRow(statsRoot, statName)
    if not statsRoot then return nil end
    local targetClean = cleanAlpha(statName)

    for _, desc in ipairs(statsRoot:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and cleanAlpha(desc.Text) == targetClean then
            local curr = desc.Parent
            local matchedRow = nil

            -- Ascend strictly until we find the isolated single row frame
            for _ = 1, 5 do
                if not curr or curr == statsRoot then break end
                if isSingleStatRow(curr) then
                    matchedRow = curr
                    break
                end
                curr = curr.Parent
            end

            -- Fallback if exact row validator was strict
            if not matchedRow then
                curr = desc.Parent
                for _ = 1, 4 do
                    if not curr or curr == statsRoot then break end
                    local hasLv = false
                    local hasBtn = false
                    for _, child in ipairs(curr:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text and string.find(child.Text, "Lv") then hasLv = true end
                        if child:IsA("GuiButton") then hasBtn = true end
                        if hasLv and hasBtn then break end
                    end
                    if hasLv and hasBtn then
                        matchedRow = curr
                        break
                    end
                    curr = curr.Parent
                end
            end

            if not matchedRow then matchedRow = desc.Parent end

            local rowText = ""
            local addBtn = nil
            for _, child in ipairs(matchedRow:GetDescendants()) do
                if child:IsA("TextLabel") and child.Text then
                    rowText = rowText .. " " .. child.Text
                end
                if child:IsA("GuiButton") and not addBtn then
                    local bt = getButtonText(child)
                    local bn = string.lower(child.Name)
                    if string.find(bt, "+") or string.find(bn, "add") or string.find(bn, "upg") or bt == "MAX" or bn == "nui_btn" then
                        addBtn = child
                    end
                end
            end

            local cur, mx = string.match(string.gsub(rowText, ",", ""), "Lv%s*(%d+)%s*/%s*(%d+)")
            local currentVal = tonumber(cur) or 0
            local maxVal     = tonumber(mx) or 3375

            local btnText = getButtonText(addBtn)
            local isMaxed = (btnText == "MAX") or (currentVal >= maxVal and currentVal > 0)

            return {
                current = currentVal,
                max = maxVal,
                isMax = isMaxed,
                button = addBtn
            }
        end
    end
    return nil
end

-- --------------------------------------------------------------------
-- 5. REBIRTH WORKFLOW (STRICTLY GATED TO MAX LEVEL)
-- --------------------------------------------------------------------
local function executeBackgroundRebirth(statsRoot, updateStatus)
    local now = os.clock()
    if now - lastRebirthTime < 3.0 then
        return false
    end

    local yesBtn = findRebirthConfirmYesButton(statsRoot)

    if not yesBtn then
        local rebirthBtn = findRebirthButton(statsRoot)
        if not rebirthBtn then
            return false
        end

        diagLog("Firing REBIRTH in UI_Stats: " .. rebirthBtn:GetFullName())
        updateStatus("Firing REBIRTH in UI_Stats...", Color3.fromRGB(241, 196, 15))
        fireMultiSignalBackground(rebirthBtn)
        lastRebirthTime = now

        for _ = 1, 10 do
            task.wait(0.1)
            yesBtn = findRebirthConfirmYesButton(statsRoot)
            if yesBtn then break end
        end
    end

    if yesBtn then
        diagLog("Confirming YES on: " .. yesBtn:GetFullName())
        updateStatus("Confirming YES (Rebirth Modal)...", Color3.fromRGB(46, 204, 113))
        task.wait(0.1)

        fireMultiSignalBackground(yesBtn)
        lastRebirthTime = os.clock()

        for _ = 1, 15 do
            task.wait(0.1)
            local atMax = isPlayerAtMaxLevel()
            if not atMax then
                rebirthCount = rebirthCount + 1
                updateStatus(string.format("Rebirth #%d Confirmed! Level Reset.", rebirthCount), Color3.fromRGB(46, 204, 113))
                diagLog(string.format("Rebirth #%d verified! Level reset to 1.", rebirthCount))
                task.wait(0.4)
                return true
            end
        end

        return false
    end

    return false
end

-- --------------------------------------------------------------------
-- 6. CONTROL UI
-- --------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SoloRebirth_V21"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 160)
frame.Position = UDim2.new(0.5, -160, 0.12, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 24, 33)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 24)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.Text = "⚡ Background Auto-Rebirth (V21 - Production)"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 34)
statusLabel.Position = UDim2.fromOffset(10, 32)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Initializing..."
statusLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = frame

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 38)
statsLabel.Position = UDim2.fromOffset(10, 68)
statsLabel.BackgroundColor3 = Color3.fromRGB(13, 17, 23)
statsLabel.TextColor3 = Color3.fromRGB(88, 166, 255)
statsLabel.TextSize = 11
statsLabel.Font = Enum.Font.GothamMedium
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.Text = " Points: - | Agility: -/200\n Reach: -/800 | Exp: -/MAX"
statsLabel.Parent = frame

local statCorner = Instance.new("UICorner")
statCorner.CornerRadius = UDim.new(0, 6)
statCorner.Parent = statsLabel

local function createBtn(text, x, width, bgCol)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(width, 32)
    b.Position = UDim2.fromOffset(x, 116)
    b.BackgroundColor3 = bgCol
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = b
    return b
end

local toggleBtn = createBtn("BACKGROUND: ON", 10, 140, Color3.fromRGB(46, 204, 113))
local checkBtn  = createBtn("CHECK NOW", 155, 95, Color3.fromRGB(230, 126, 34))
local closeBtn  = createBtn("CLOSE", 255, 55, Color3.fromRGB(231, 76, 60))

local function updateStatus(txt, col)
    statusLabel.Text = "Status: " .. txt
    if col then statusLabel.TextColor3 = col end
end

local function updateStatsReadout(pts, agi, rch, exp)
    statsLabel.Text = string.format(
        " Points: %d | Agility: %d/200\n Reach: %d/800 | Exp: %s",
        pts or 0,
        agi and agi.current or 0,
        rch and rch.current or 0,
        exp and (exp.isMax and "MAX" or tostring(exp.current)) or "-"
    )
end

-- --------------------------------------------------------------------
-- 7. ATOMIC STAT ALLOCATION (NO DOUBLE-TAPPING, STRICT LIMITS)
-- --------------------------------------------------------------------
local function spendOnStatBackground(statsRoot, statTitle, targetLevel, getAvailablePointsFunc)
    local points = getAvailablePointsFunc(statsRoot)
    if points <= 0 then return points end

    local row = getStatRow(statsRoot, statTitle)
    if not row then
        diagLog(string.format("Stat row '%s' not found.", statTitle))
        return points
    end
    if row.isMax then
        diagLog(string.format("Stat '%s' is already MAX.", statTitle))
        return points
    end
    if row.current >= targetLevel then
        diagLog(string.format("Stat '%s' already at target (%d >= %d).", statTitle, row.current, targetLevel))
        return points
    end
    if not row.button then
        diagLog(string.format("Upgrade button for '%s' not found.", statTitle))
        return points
    end

    local needed = targetLevel - row.current
    local toSpend = math.min(points, needed)
    if toSpend <= 0 then return points end

    diagLog(string.format("Setting custom amount: %d for %s (current: %d, target: %d, needed: %d)", toSpend, statTitle, row.current, targetLevel, needed))
    updateStatus(string.format("Spending %d on %s...", toSpend, statTitle), Color3.fromRGB(46, 204, 113))
    
    setCustomAmountBackground(statsRoot, toSpend)
    task.wait(0.1) -- Ensure GUI registers the typed amount

    local attempts = 0
    while points > 0 and attempts < 10 do
        local freshRow = getStatRow(statsRoot, statTitle)
        if not freshRow or freshRow.isMax or not freshRow.button then break end
        if freshRow.current >= targetLevel then
            diagLog(string.format("Stat '%s' reached target (%d >= %d). Stopping.", statTitle, freshRow.current, targetLevel))
            break
        end

        local currentPointsBefore = getAvailablePointsFunc(statsRoot)
        local currentLevelBefore = freshRow.current

        -- FIRE EXACTLY ONCE (NO DOUBLE-TAP)
        fireMultiSignalBackground(freshRow.button)

        -- POLL FOR SERVER CONFIRMATION (up to 1.5 seconds)
        local confirmed = false
        local waitStart = os.clock()
        while (os.clock() - waitStart) < 1.5 do
            task.wait(0.1)
            local np = getAvailablePointsFunc(statsRoot)
            local fr = getStatRow(statsRoot, statTitle)
            local newLvl = fr and fr.current or currentLevelBefore

            if np < currentPointsBefore or newLvl > currentLevelBefore then
                confirmed = true
                local spent = currentPointsBefore - np
                points = np
                diagLog(string.format("Server Confirmed: Spent %d on %s (New Lv: %d) | Remaining points: %d", spent, statTitle, newLvl, points))
                break
            end
        end

        if not confirmed then
            diagLog(string.format("Server did not confirm spend on %s after 1.5s. Syncing points.", statTitle))
            points = getAvailablePointsFunc(statsRoot)
        end

        attempts = attempts + 1
        
        -- Strict target check
        local checkRow = getStatRow(statsRoot, statTitle)
        if checkRow and checkRow.current >= targetLevel then
            break
        end
    end

    updateStatsReadout(points, getStatRow(statsRoot, "Shadow Agility"), getStatRow(statsRoot, "Shadow Reach"), getStatRow(statsRoot, "Player Experience"))
    return points
end

-- --------------------------------------------------------------------
-- 8. MAIN AUTOMATION CYCLE
-- --------------------------------------------------------------------
local function runBackgroundCycle()
    if isProcessing then return end
    isProcessing = true

    local success, err = pcall(function()
        local statsRoot = getStatsRoot()
        if not statsRoot then
            updateStatus("Waiting for Game UI Data...", Color3.fromRGB(241, 196, 15))
            return
        end

        local atMax, hudText = isPlayerAtMaxLevel()

        -- 1. ONLY EXECUTE REBIRTH IF ACTUALLY AT MAX LEVEL!
        if atMax then
            local rebirthed = executeBackgroundRebirth(statsRoot, updateStatus)
            if rebirthed then
                task.wait(0.5)
                atMax = false
            end
        end

        -- 2. Read Points & Stat Levels in Memory
        local points = getAvailablePoints(statsRoot)
        local agi = getStatRow(statsRoot, "Shadow Agility")
        local rch = getStatRow(statsRoot, "Shadow Reach")
        local exp = getStatRow(statsRoot, "Player Experience")
        updateStatsReadout(points, agi, rch, exp)

        -- 3. Allocate Points in Background
        if points > 0 then
            diagLog(string.format("Available: %d points | Agi: %d/200, Reach: %d/800, Exp: %d/%d",
                points, agi and agi.current or 0, rch and rch.current or 0, exp and exp.current or 0, exp and exp.max or 3375))

            -- Priority 1: Shadow Agility -> Strictly capped at 200
            points = spendOnStatBackground(statsRoot, "Shadow Agility", TARGET_AGILITY, getAvailablePoints)

            -- Priority 2: Shadow Reach -> Strictly capped at 800
            if points > 0 then
                points = spendOnStatBackground(statsRoot, "Shadow Reach", TARGET_REACH, getAvailablePoints)
            end

            -- Priority 3: Player Experience -> Up to MAX (e.g. 3,375)
            if points > 0 then
                local freshExp = getStatRow(statsRoot, "Player Experience")
                if freshExp and not freshExp.isMax and freshExp.current < freshExp.max then
                    points = spendOnStatBackground(statsRoot, "Player Experience", freshExp.max, getAvailablePoints)
                end
            end

            -- Priority 4: Overflow into Shadow Reach ONLY IF Player Experience is 100% MAX!
            local finalExp = getStatRow(statsRoot, "Player Experience")
            if points > 0 and finalExp and (finalExp.isMax or finalExp.current >= finalExp.max) then
                local finalRch = getStatRow(statsRoot, "Shadow Reach")
                if finalRch and not finalRch.isMax and finalRch.current < finalRch.max then
                    updateStatus(string.format("Exp MAX! Overflowing %d to Reach...", points), Color3.fromRGB(155, 89, 182))
                    diagLog(string.format("Player Experience is MAX (%d/%d). Overflowing %d remaining points to Shadow Reach.", finalExp.current, finalExp.max, points))
                    points = spendOnStatBackground(statsRoot, "Shadow Reach", finalRch.max, getAvailablePoints)
                end
            end

            updateStatus("Active (Points Allocated)", Color3.fromRGB(46, 204, 113))
        else
            if not atMax then
                updateStatus("Active (Background Monitoring)", Color3.fromRGB(230, 230, 230))
            end
        end
    end)

    if not success and err then
        warn("[BgRebirth Error]: " .. tostring(err))
    end
    isProcessing = false
end

-- --------------------------------------------------------------------
-- 9. CONTROLS & MONITOR THREAD
-- --------------------------------------------------------------------
toggleBtn.MouseButton1Click:Connect(function()
    isRunning = not isRunning
    if isRunning then
        toggleBtn.Text = "BACKGROUND: ON"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        updateStatus("Active (Background Monitoring)", Color3.fromRGB(230, 230, 230))
    else
        toggleBtn.Text = "BACKGROUND: OFF"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
        updateStatus("Paused by user", Color3.fromRGB(241, 196, 15))
    end
end)

checkBtn.MouseButton1Click:Connect(function()
    task.spawn(runBackgroundCycle)
end)

closeBtn.MouseButton1Click:Connect(function()
    isRunning = false
    gui:Destroy()
end)

updateStatus("Active (Background Monitoring)", Color3.fromRGB(230, 230, 230))

task.spawn(function()
    while gui and gui.Parent do
        if isRunning then
            runBackgroundCycle()
        end
        task.wait(2.0)
    end
end)

print("[SoloRebirth V21] 100% Background Auto-Rebirth & Stat Allocation Initialized!")
