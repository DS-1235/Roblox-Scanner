-- ====================================================================
-- SOLO LEVELING / ANIME SHADOW: PRODUCTION AUTO-REBIRTH & STAT SYSTEM (V14)
-- ====================================================================

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove prior UI instances to prevent conflicts
for _, name in ipairs({"NS_Rebirth", "AutoRebirthGui", "SoloRebirth_V13", "SoloRebirth_V14"}) do
    local old = playerGui:FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end

-- Configuration Targets
local TARGET_AGILITY = 200
local TARGET_REACH   = 800

-- Runtime State
local isRunning = true
local isProcessing = false
local rebirthCount = 0

-- --------------------------------------------------------------------
-- 1. VISIBILITY & HIERARCHY HELPERS
-- --------------------------------------------------------------------
local function cleanText(str)
    if type(str) ~= "string" then return "" end
    local noTags = string.gsub(str, "<[^>]+>", "")
    return string.upper(string.match(noTags, "^%s*(.-)%s*$") or "")
end

local function isRealVisible(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if obj.AbsoluteSize.X <= 4 or obj.AbsoluteSize.Y <= 4 then return false end
    if obj.AbsolutePosition.X < -50 or obj.AbsolutePosition.Y < -50 then return false end

    local curr = obj
    while curr and curr ~= playerGui do
        if curr.Name == "__Disable" then return false end
        if curr:IsA("GuiObject") and not curr.Visible then return false end
        curr = curr.Parent
    end
    return true
end

-- --------------------------------------------------------------------
-- 2. BULLETPROOF BUTTON CLICKING (Exact Center, No Inset Drift)
-- --------------------------------------------------------------------
local function clickButton(b)
    if not b then return end

    if typeof(firesignal) == "function" and b:IsA("GuiButton") then
        pcall(function() firesignal(b.Activated) end)
        pcall(function() firesignal(b.MouseButton1Click) end)
    end

    if typeof(getconnections) == "function" and b:IsA("GuiButton") then
        pcall(function()
            for _, c in ipairs(getconnections(b.Activated)) do
                if c.Fire then c:Fire() elseif c.Function then c.Function() end
            end
            for _, c in ipairs(getconnections(b.MouseButton1Click)) do
                if c.Fire then c:Fire() elseif c.Function then c.Function() end
            end
        end)
    end

    pcall(function()
        if b.AbsoluteSize.X > 0 and b.AbsoluteSize.Y > 0 then
            local cx = b.AbsolutePosition.X + (b.AbsoluteSize.X / 2)
            local cy = b.AbsolutePosition.Y + (b.AbsoluteSize.Y / 2)
            pcall(function() VIM:SendMouseMoveEvent(cx, cy, game) end)
            task.wait(0.01)
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end
    end)
end

-- --------------------------------------------------------------------
-- 3. HUD STATS BUTTON & STATS WINDOW LOCATORS
-- --------------------------------------------------------------------
local function getHudStatsButton()
    local exact = playerGui:FindFirstChild("Hud", true)
    if exact then
        local hive = exact:FindFirstChild("lb_hive", true)
        if hive then
            local statsBtn = hive:FindFirstChild("stats", true)
            if statsBtn and statsBtn:IsA("GuiButton") and isRealVisible(statsBtn) then
                return statsBtn
            end
        end
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == "stats" and desc:IsA("GuiButton") and isRealVisible(desc) then
            if not desc:FindFirstAncestor("__Disable") and desc:FindFirstAncestor("Hud") then
                return desc
            end
        end
    end
    return nil
end

local function findStatsWindow()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:FindFirstAncestor("__Disable") then continue end

        if desc.Name == "UI_Stats" and isRealVisible(desc) then
            return desc
        end

        if desc:IsA("TextLabel") and isRealVisible(desc) then
            local clean = cleanText(desc.Text)
            if clean == "SPEND YOUR POINTS" or clean == "STATS" then
                local p = desc.Parent
                while p and p ~= playerGui do
                    if p.Name == "UI_Stats" or (p:IsA("Frame") and p.AbsoluteSize.X > 350) then
                        if isRealVisible(p) then return p end
                    end
                    p = p.Parent
                end
            end
        end
    end
    return nil
end

local function findWindowCloseButton(win)
    if not win then return nil end
    local best = nil
    local bestDist = math.huge
    local winX = win.AbsolutePosition.X + win.AbsoluteSize.X
    local winY = win.AbsolutePosition.Y

    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("GuiButton") and isRealVisible(desc) then
            local clean = cleanText(desc.Text)
            local name = string.lower(desc.Name)
            local isX = (clean == "X" or name == "close" or name == "btn_close" or string.find(name, "close"))

            local dist = math.sqrt((desc.AbsolutePosition.X - winX)^2 + (desc.AbsolutePosition.Y - winY)^2)
            if isX or (desc.AbsolutePosition.X > win.AbsolutePosition.X + (win.AbsoluteSize.X * 0.82) and desc.AbsolutePosition.Y < win.AbsolutePosition.Y + 120) then
                if dist < bestDist then
                    bestDist = dist
                    best = desc
                end
            end
        end
    end
    return best
end

local function dismissUnwantedPopups()
    for _, name in ipairs({"UI_Daily", "UI_Inventory", "DailyRewards", "DailyReward"}) do
        for _, desc in ipairs(playerGui:GetDescendants()) do
            if desc:FindFirstAncestor("__Disable") then continue end
            if desc.Name == name and isRealVisible(desc) then
                local closeBtn = findWindowCloseButton(desc)
                if closeBtn then clickButton(closeBtn) end
            end
        end
    end
end

-- --------------------------------------------------------------------
-- 4. MAX LEVEL & REBIRTH DETECTION
-- --------------------------------------------------------------------
local function isPlayerAtMaxLevel()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:FindFirstAncestor("__Disable") then continue end
        if desc:IsA("TextLabel") and desc.Text and isRealVisible(desc) then
            local clean = cleanText(desc.Text)
            if string.find(clean, "MAX") and (string.find(clean, "LEVEL") or string.find(clean, "LV")) then
                return true
            end
        end
    end

    local win = findStatsWindow()
    if win then
        for _, desc in ipairs(win:GetDescendants()) do
            if desc:IsA("GuiButton") and isRealVisible(desc) then
                local clean = cleanText(desc.Text)
                if clean == "REBIRTH" then return true end
            end
        end
    end

    return false
end

local function findRebirthButton(win)
    if not win then return nil end
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("GuiButton") and isRealVisible(desc) then
            local clean = cleanText(desc.Text)
            if clean == "REBIRTH" then
                return desc
            end
        end
    end
    return nil
end

local function findRebirthConfirmYesButton()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:FindFirstAncestor("__Disable") then continue end
        if not desc:IsA("GuiObject") or not isRealVisible(desc) then continue end

        local rawText = (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text or ""
        local clean = cleanText(rawText)

        if clean == "YES" or clean == "CONFIRM" then
            local container = desc.Parent
            local isRebirthModal = false

            for _ = 1, 6 do
                if not container or container == playerGui then break end
                for _, sib in ipairs(container:GetDescendants()) do
                    if (sib:IsA("TextLabel") or sib:IsA("TextButton")) and sib.Text then
                        local sibClean = cleanText(sib.Text)
                        if string.find(sibClean, "REBIRTH") or string.find(sibClean, "RESET") or sibClean == "NO" then
                            isRebirthModal = true
                            break
                        end
                    end
                end
                if isRebirthModal then break end
                container = container.Parent
            end

            if isRebirthModal then
                local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                if btn and isRealVisible(btn) and not string.find(string.lower(btn.Name), "no") then
                    return btn
                end
                return desc
            end
        end
    end
    return nil
end

-- --------------------------------------------------------------------
-- 5. STAT POINTS & FAST ALLOCATION
-- --------------------------------------------------------------------
local function getAvailablePoints(win)
    if not win then return 0 end
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextLabel") and isRealVisible(desc) and desc.Text then
            local clean = cleanText(desc.Text)
            local cleanNum = string.gsub(desc.Text, ",", "")
            local num = tonumber(string.match(cleanNum, "(%d+)"))
            if num and num > 0 and (string.find(clean, "POINTS") or string.find(clean, "SPEND")) then
                if not string.find(clean, "EARNED") and not string.find(clean, "SPENT") then
                    return num
                end
            end
        end
    end

    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextLabel") and isRealVisible(desc) and desc.Text then
            local s = string.gsub(desc.Text, ",", "")
            local num = tonumber(string.match(s, "^%s*(%d+)%s*$"))
            if num and num > 0 and num < 1000000 then
                return num
            end
        end
    end
    return 0
end

local function getCustomBox(win)
    if not win then return nil end
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextBox") and isRealVisible(desc) then
            return desc
        end
    end
    return nil
end

local function setCustomAmount(box, amount)
    if not box then return end
    local targetVal = math.max(1, math.floor(amount))
    local str = tostring(targetVal)
    if box.Text == str then return end

    pcall(function()
        if box.AbsoluteSize.X > 0 and box.AbsoluteSize.Y > 0 then
            local cx = box.AbsolutePosition.X + (box.AbsoluteSize.X / 2)
            local cy = box.AbsolutePosition.Y + (box.AbsoluteSize.Y / 2)
            VIM:SendMouseMoveEvent(cx, cy, game)
            task.wait(0.01)
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.03)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end
    end)
    pcall(function() box:CaptureFocus() end)
    task.wait(0.02)

    box.Text = str
    task.wait(0.02)

    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.03)
        VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)
    task.wait(0.02)

    pcall(function() box:ReleaseFocus(true) end)

    pcall(function()
        if typeof(firesignal) == "function" then
            firesignal(box.FocusLost, true)
            firesignal(box:GetPropertyChangedSignal("Text"))
        end
        if typeof(getconnections) == "function" then
            for _, c in ipairs(getconnections(box.FocusLost)) do
                if c.Fire then c:Fire(true) elseif c.Function then c.Function(true) end
            end
            for _, c in ipairs(getconnections(box:GetPropertyChangedSignal("Text"))) do
                if c.Fire then c:Fire() elseif c.Function then c.Function() end
            end
        end
    end)
    task.wait(0.04)
end

local function findAddButtonInRow(row)
    for _, desc in ipairs(row:GetDescendants()) do
        if desc:IsA("GuiButton") and isRealVisible(desc) then
            local clean = cleanText(desc.Text)
            local name = string.lower(desc.Name)
            if string.find(clean, "+") or string.find(name, "add") or string.find(name, "upg") or clean == "MAX" then
                return desc
            end
        end
    end
    return nil
end

local function getStatRow(win, statName)
    if not win then return nil end
    local targetClean = cleanText(statName)

    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextLabel") and isRealVisible(desc) and desc.Text then
            local clean = cleanText(desc.Text)
            if string.find(clean, targetClean, 1, true) then
                local row = desc.Parent
                while row and row ~= win and row.Parent ~= win do
                    row = row.Parent
                end
                if not row then row = desc.Parent end

                local rowText = ""
                for _, child in ipairs(row:GetDescendants()) do
                    if child:IsA("TextLabel") and child.Text then
                        rowText = rowText .. " " .. child.Text
                    end
                end

                local cur, mx = string.match(string.gsub(rowText, ",", ""), "Lv%s*(%d+)%s*/%s*(%d+)")
                local isMax = string.find(cleanText(rowText), "MAX") ~= nil

                return {
                    current = tonumber(cur) or 0,
                    max = tonumber(mx) or 3225,
                    isMax = isMax or (tonumber(cur) ~= nil and tonumber(mx) ~= nil and tonumber(cur) >= tonumber(mx)),
                    button = findAddButtonInRow(row)
                }
            end
        end
    end
    return nil
end

-- --------------------------------------------------------------------
-- 6. REBIRTH WORKFLOW
-- --------------------------------------------------------------------
local function handleRebirthFlow(win, updateStatus)
    local yesBtn = findRebirthConfirmYesButton()

    if not yesBtn then
        local rebirthBtn = findRebirthButton(win)
        if not rebirthBtn then return false end

        updateStatus("Clicking REBIRTH...", Color3.fromRGB(241, 196, 15))
        clickButton(rebirthBtn)

        for _ = 1, 8 do
            task.wait(0.1)
            yesBtn = findRebirthConfirmYesButton()
            if yesBtn then break end
        end
    end

    if yesBtn then
        updateStatus("Confirming YES on Popup...", Color3.fromRGB(46, 204, 113))
        task.wait(0.15)
        clickButton(yesBtn)

        for _ = 1, 10 do
            task.wait(0.1)
            if not findRebirthConfirmYesButton() then
                rebirthCount = rebirthCount + 1
                updateStatus(string.format("Rebirth #%d Successful!", rebirthCount), Color3.fromRGB(46, 204, 113))
                task.wait(0.3)
                return true
            end
        end
        return true
    end

    return false
end

-- --------------------------------------------------------------------
-- 7. CONTROL UI
-- --------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SoloRebirth_V14"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 165)
frame.Position = UDim2.new(0.5, -160, 0.12, 0)
frame.BackgroundColor3 = Color3.fromRGB(22, 27, 34)
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
title.Text = "⚡ Auto Rebirth & Stats (V14)"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 36)
statusLabel.Position = UDim2.fromOffset(10, 32)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Initializing..."
statusLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
statusLabel.TextSize = 12
statusLabel.TextWrapped = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = frame

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 42)
statsLabel.Position = UDim2.fromOffset(10, 70)
statsLabel.BackgroundColor3 = Color3.fromRGB(13, 17, 23)
statsLabel.TextColor3 = Color3.fromRGB(88, 166, 255)
statsLabel.TextSize = 11
statsLabel.Font = Enum.Font.GothamMedium
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.Text = " Points: - | Agi: -/200\n Reach: -/800 | Exp: -/MAX"
statsLabel.Parent = frame

local statCorner = Instance.new("UICorner")
statCorner.CornerRadius = UDim.new(0, 6)
statCorner.Parent = statsLabel

local function createBtn(text, x, width, bgCol)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(width, 32)
    b.Position = UDim2.fromOffset(x, 122)
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

local toggleBtn = createBtn("AUTO REBIRTH: ON", 10, 140, Color3.fromRGB(46, 204, 113))
local checkBtn  = createBtn("RAPID CHECK", 155, 95, Color3.fromRGB(230, 126, 34))
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
-- 8. AUTOMATION CYCLE
-- --------------------------------------------------------------------
local function runAutomationCycle()
    if isProcessing then return end
    isProcessing = true

    local success, err = pcall(function()
        dismissUnwantedPopups()

        local atMax = isPlayerAtMaxLevel()
        local win = findStatsWindow()
        local openedByScript = false

        if atMax and (not win or not isRealVisible(win)) then
            local hudBtn = getHudStatsButton()
            if hudBtn then
                openedByScript = true
                updateStatus("Max Level Reached! Opening Stats...", Color3.fromRGB(52, 152, 219))
                clickButton(hudBtn)
                for _ = 1, 8 do
                    task.wait(0.08)
                    win = findStatsWindow()
                    if win and isRealVisible(win) then break end
                end
            end
        end

        if win and isRealVisible(win) then
            if atMax or findRebirthButton(win) or findRebirthConfirmYesButton() then
                local rebirthed = handleRebirthFlow(win, updateStatus)
                if rebirthed then task.wait(0.3) end
            end

            local points = getAvailablePoints(win)
            local customBox = getCustomBox(win)

            local agi = getStatRow(win, "Shadow Agility")
            local rch = getStatRow(win, "Shadow Reach")
            local exp = getStatRow(win, "Player Experience")
            updateStatsReadout(points, agi, rch, exp)

            if points > 0 and customBox then
                local function spendOnStat(statRow, targetAmount, statTitle)
                    if not statRow or statRow.isMax or statRow.current >= targetAmount then return end
                    local needed = targetAmount - statRow.current
                    local toSpend = math.min(points, needed)
                    if toSpend <= 0 then return end

                    updateStatus(string.format("Adding %d to %s...", toSpend, statTitle), Color3.fromRGB(46, 204, 113))
                    setCustomAmount(customBox, toSpend)

                    local attempts = 0
                    while points > 0 and needed > 0 and attempts < 15 do
                        local freshRow = getStatRow(win, statTitle)
                        if not freshRow or freshRow.isMax or not freshRow.button then break end

                        clickButton(freshRow.button)
                        task.wait(0.05)

                        local freshPoints = getAvailablePoints(win)
                        if freshPoints == points then break end
                        local spent = points - freshPoints
                        needed = needed - spent
                        points = freshPoints
                        attempts = attempts + 1
                    end
                    updateStatsReadout(points, getStatRow(win, "Shadow Agility"), getStatRow(win, "Shadow Reach"), getStatRow(win, "Player Experience"))
                end

                -- Priority 1: Shadow Agility -> 200
                spendOnStat(agi, TARGET_AGILITY, "Shadow Agility")

                -- Priority 2: Shadow Reach -> 800
                rch = getStatRow(win, "Shadow Reach")
                spendOnStat(rch, TARGET_REACH, "Shadow Reach")

                -- Priority 3: Player Experience -> MAX
                exp = getStatRow(win, "Player Experience")
                if exp and not exp.isMax then
                    spendOnStat(exp, exp.max, "Player Experience")
                end

                -- Priority 4: Overflow into Shadow Reach
                exp = getStatRow(win, "Player Experience")
                if exp and exp.isMax and points > 0 then
                    rch = getStatRow(win, "Shadow Reach")
                    if rch and not rch.isMax then
                        updateStatus(string.format("Exp MAX! Overflowing %d to Reach...", points), Color3.fromRGB(155, 89, 182))
                        setCustomAmount(customBox, points)
                        local attempts = 0
                        while points > 0 and attempts < 15 do
                            local freshRch = getStatRow(win, "Shadow Reach")
                            if not freshRch or freshRch.isMax or not freshRch.button then break end

                            clickButton(freshRch.button)
                            task.wait(0.05)

                            local freshPoints = getAvailablePoints(win)
                            if freshPoints == points then break end
                            points = freshPoints
                            attempts = attempts + 1
                        end
                    end
                end
            end

            if openedByScript and not findRebirthConfirmYesButton() then
                task.wait(0.1)
                local closeBtn = findWindowCloseButton(win)
                if closeBtn then
                    clickButton(closeBtn)
                else
                    local hudBtn = getHudStatsButton()
                    if hudBtn then clickButton(hudBtn) end
                end
            end
        else
            updateStatus("Active (Monitoring Level & Stats)", Color3.fromRGB(230, 230, 230))
        end
    end)

    if not success and err then
        warn("[AutoRebirth Error]: " .. tostring(err))
    end
    isProcessing = false
end

-- --------------------------------------------------------------------
-- 9. EVENT BINDINGS & BACKGROUND THREAD
-- --------------------------------------------------------------------
toggleBtn.MouseButton1Click:Connect(function()
    isRunning = not isRunning
    if isRunning then
        toggleBtn.Text = "AUTO REBIRTH: ON"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        updateStatus("Active (Monitoring Level & Stats)", Color3.fromRGB(230, 230, 230))
    else
        toggleBtn.Text = "AUTO REBIRTH: OFF"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
        updateStatus("Paused by user", Color3.fromRGB(241, 196, 15))
    end
end)

checkBtn.MouseButton1Click:Connect(function()
    task.spawn(runAutomationCycle)
end)

closeBtn.MouseButton1Click:Connect(function()
    isRunning = false
    gui:Destroy()
end)

updateStatus("Active (Monitoring Level & Stats)", Color3.fromRGB(230, 230, 230))

task.spawn(function()
    while gui and gui.Parent do
        if isRunning then
            runAutomationCycle()
        end
        task.wait(0.7)
    end
end)

print("[SoloRebirth V14] Production Auto-Rebirth & Stat Allocation Loaded Successfully!")
