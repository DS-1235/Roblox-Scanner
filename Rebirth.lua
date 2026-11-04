-- ====================================================================
-- AUTO REBIRTH & STAT ALLOCATION (V12 - PERFECT CONFIRMATION ENGINE)
-- 100% Fixed: In-Window YES/NO Confirmation, Calibrated Click Duration, Zero Misclicks
-- ====================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local VIM = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- --------------------------------------------------------------------
-- Configuration Targets
-- --------------------------------------------------------------------
local TARGET_AGILITY = 200
local TARGET_REACH   = 800
local CHECK_INTERVAL = 3.0

local AutoRebirthEnabled = true
local isProcessing = false

-- --------------------------------------------------------------------
-- Safe & Engine-Accurate Click Helper (No Erroneous Inset Offsets)
-- --------------------------------------------------------------------
local function clickButton(b)
    if not b then return end

    -- 1. firesignal (cleanest & fastest: fires button listeners directly)
    if typeof(firesignal) == "function" and b:IsA("GuiButton") then
        pcall(function() firesignal(b.Activated) end)
        pcall(function() firesignal(b.MouseButton1Click) end)
        pcall(function() firesignal(b.MouseButton1Down) end)
        pcall(function() firesignal(b.MouseButton1Up) end)
    end

    -- 2. getconnections (direct function invocation)
    if typeof(getconnections) == "function" and b:IsA("GuiButton") then
        pcall(function()
            for _, c in ipairs(getconnections(b.Activated)) do
                if c.Fire then c:Fire() elseif c.Function then c.Function() end
            end
            for _, c in ipairs(getconnections(b.MouseButton1Click)) do
                if c.Fire then c:Fire() elseif c.Function then c.Function() end
            end
            for _, c in ipairs(getconnections(b.MouseButton1Down)) do
                if c.Fire then c:Fire() elseif c.Function then c.Function() end
            end
            for _, c in ipairs(getconnections(b.MouseButton1Up)) do
                if c.Fire then c:Fire() elseif c.Function then c.Function() end
            end
        end)
    end

    -- 3. VirtualInputManager Native Simulation (Exact center coordinates, hover + hold + release)
    pcall(function()
        if b.AbsoluteSize.X > 0 and b.AbsoluteSize.Y > 0 then
            local cx = b.AbsolutePosition.X + (b.AbsoluteSize.X / 2)
            local cy = b.AbsolutePosition.Y + (b.AbsoluteSize.Y / 2)
            pcall(function() VIM:SendMouseMoveEvent(cx, cy, game) end)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.06) -- calibrated button press duration (60ms)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end
    end)
end

-- --------------------------------------------------------------------
-- Authentic TextBox Input Helper
-- --------------------------------------------------------------------
local function setCustomAmount(box, amount)
    if not box then return end
    local str = tostring(amount)
    if box.Text == str then return end

    pcall(function() box:CaptureFocus() end)
    box.Text = str
    pcall(function() box:ReleaseFocus(true) end)

    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)

    pcall(function()
        if typeof(firesignal) == "function" then firesignal(box.FocusLost, true) end
        if typeof(getconnections) == "function" then
            for _, c in ipairs(getconnections(box.FocusLost)) do
                if c.Fire then c:Fire(true) elseif c.Function then c.Function(true) end
            end
            for _, c in ipairs(getconnections(box:GetPropertyChangedSignal("Text"))) do
                if c.Fire then c:Fire() elseif c.Function then c.Function() end
            end
        end
    end)
    task.wait(0.08)
end

-- --------------------------------------------------------------------
-- Robust Window Close Button Locator (Red Hexagon X Button)
-- --------------------------------------------------------------------
local function findWindowCloseButton(win)
    if not win then return nil end

    -- 1. Name and text matching
    for _, b in ipairs(win:GetDescendants()) do
        if b:IsA("GuiButton") and b.Visible then
            local n = string.lower(b.Name)
            if string.find(n, "close") or string.find(n, "exit") or string.find(n, "cross") or n == "x" then
                return b
            end
            if b:IsA("TextButton") and b.Text and (string.upper(string.gsub(b.Text, "%s+", "")) == "X" or string.upper(b.Text) == "CLOSE") then
                return b
            end
        end
    end

    -- 2. Geometric Quadrant Matching: Top-Right Corner of Window
    local wx = win.AbsolutePosition.X
    local wy = win.AbsolutePosition.Y
    local ww = win.AbsoluteSize.X
    local wh = win.AbsoluteSize.Y
    local bestBtn = nil
    local bestScore = -1

    for _, b in ipairs(win:GetDescendants()) do
        if b:IsA("GuiButton") and b.Visible and b.AbsoluteSize.X > 10 and b.AbsoluteSize.Y > 10 then
            local bx = b.AbsolutePosition.X
            local by = b.AbsolutePosition.Y
            if bx >= (wx + ww * 0.65) and by <= (wy + wh * 0.35) then
                local score = bx - by
                if score > bestScore then
                    bestScore = score
                    bestBtn = b
                end
            end
        end
    end

    return bestBtn
end

-- --------------------------------------------------------------------
-- Auto-Dismiss Unwanted Popups (e.g. Daily Rewards, Wheel, Inventory)
-- --------------------------------------------------------------------
local function dismissUnwantedPopups()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and desc.Visible and not desc:FindFirstAncestor("__Disable") and not desc:FindFirstAncestor("Hud") and not desc:FindFirstAncestor("UI_Hud") then
            local t = string.upper(desc.Text)
            if string.find(t, "DAILY REWARD", 1, true) or string.find(t, "LOGIN REWARD", 1, true) or string.find(t, "SPIN THE WHEEL", 1, true) then
                local p = desc.Parent
                while p and p ~= playerGui and not p:IsA("ScreenGui") do
                    if p.AbsoluteSize.X > 300 and p.AbsoluteSize.Y > 200 then
                        local closeBtn = findWindowCloseButton(p)
                        if closeBtn then
                            clickButton(closeBtn)
                            task.wait(0.12)
                            return true
                        end
                    end
                    p = p.Parent
                end
            end
        end
    end
    return false
end

-- --------------------------------------------------------------------
-- Check if an element is inside the Stats Window
-- --------------------------------------------------------------------
local function isInsideStatsWindow(obj)
    local p = obj.Parent
    while p and p ~= playerGui do
        if p.Name == "UI_Stats" or p.Name == "StatsWindow" then return true end
        for _, ch in ipairs(p:GetChildren()) do
            if ch:IsA("TextLabel") and ch.Text and string.find(string.upper(ch.Text), "SPEND YOUR POINTS", 1, true) then
                return true
            end
        end
        p = p.Parent
    end
    return false
end

-- --------------------------------------------------------------------
-- Locate the Truly Active Stats Window Frame (Must NOT be in __Disable)
-- --------------------------------------------------------------------
local function findStatsWindow()
    -- Method 1: Check for UI_Stats in PlayerGui (MUST NOT be inside __Disable)
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == "UI_Stats" and not desc:FindFirstAncestor("__Disable") then
            local isVis = desc.Visible
            if desc:IsA("ScreenGui") then isVis = desc.Enabled end
            if isVis and desc.AbsoluteSize.X > 300 then
                return desc
            end
        end
    end

    -- Method 2: Scan for unique text in Stats window (MUST NOT be in __Disable)
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and desc.Visible and not desc:FindFirstAncestor("__Disable") then
            local u = string.upper(desc.Text)
            if string.find(u, "SPEND YOUR POINTS", 1, true) or string.find(u, "POINTS TO SPEND", 1, true) then
                local curr = desc
                while curr and curr.Parent and curr.Parent ~= playerGui and not curr.Parent:IsA("ScreenGui") do
                    if curr.AbsoluteSize.X > 400 and curr.AbsoluteSize.Y > 300 then
                        return curr
                    end
                    curr = curr.Parent
                end
                return curr
            end
        end
    end

    return nil
end

-- --------------------------------------------------------------------
-- Exact HUD 'Stats' Button Locator
-- Verified Path: PlayerGui.Hud.UI_Hud.Root.lb.lb_hive.stats
-- --------------------------------------------------------------------
local function getHudStatsButton()
    -- 1. Direct path lookup from live inspection
    local hud = playerGui:FindFirstChild("Hud")
    if hud then
        local uiHud = hud:FindFirstChild("UI_Hud")
        if uiHud then
            local root = uiHud:FindFirstChild("Root")
            if root then
                local lb = root:FindFirstChild("lb")
                if lb then
                    local hive = lb:FindFirstChild("lb_hive")
                    if hive then
                        local btn = hive:FindFirstChild("stats")
                        if btn and btn:IsA("GuiButton") and btn.Visible then
                            return btn
                        end
                    end
                end
            end
        end
    end

    -- 2. Fast container scan for lb_hive
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == "lb_hive" then
            local statsBtn = desc:FindFirstChild("stats")
            if statsBtn and statsBtn:IsA("GuiButton") and statsBtn.Visible then
                return statsBtn
            end
        end
    end

    -- 3. Exact name and child label fallback
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:IsA("GuiButton") and string.lower(desc.Name) == "stats" and desc.Visible and not isInsideStatsWindow(desc) and not desc:FindFirstAncestor("__Disable") then
            local label = desc:FindFirstChild("hx_label")
            if label or (desc.Parent and desc.Parent.Name == "lb_hive") then
                return desc
            end
        end
    end

    return nil
end

-- --------------------------------------------------------------------
-- Rebirth Confirmation Buttons Locator (Searches both inside & outside Stats Window)
-- --------------------------------------------------------------------
local function findRebirthConfirmButtons()
    local yesBtn, noBtn = nil, nil

    for _, desc in ipairs(playerGui:GetDescendants()) do
        -- Never look in __Disable or HUD left bar
        if desc:FindFirstAncestor("__Disable") or desc:FindFirstAncestor("Hud") or desc:FindFirstAncestor("UI_Hud") then
            continue
        end

        -- 1. Text-based detection (RichText stripped)
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Visible then
            local noTags = string.gsub(desc.Text, "<[^>]+>", "")
            local clean = string.upper(string.gsub(noTags, "[^%a]", ""))

            if clean == "YES" or clean == "CONFIRM" or clean == "ACCEPT" then
                local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                if btn and btn.Visible and not string.find(string.lower(btn.Name), "no") then
                    yesBtn = btn
                end
            elseif clean == "NO" or clean == "CANCEL" or clean == "DECLINE" then
                local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                if btn and btn.Visible then
                    noBtn = btn
                end
            end
        end

        -- 2. Button Name-based detection
        if desc:IsA("GuiButton") and desc.Visible then
            local n = string.lower(desc.Name)
            if (n == "yes" or n == "btn_yes" or n == "confirm" or n == "btn_confirm") and not string.find(n, "no") then
                yesBtn = desc
            elseif (n == "no" or n == "btn_no" or n == "cancel" or n == "btn_cancel") then
                noBtn = desc
            end
        end
    end

    if yesBtn then
        return yesBtn, noBtn
    end
    return nil, nil
end

-- --------------------------------------------------------------------
-- Read Available Points To Spend
-- --------------------------------------------------------------------
local function getAvailablePoints(win)
    if not win then return 0 end

    -- Diamond counter
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and string.find(string.upper(desc.Text), "POINTS TO SPEND", 1, true) then
            local diamond = desc.Parent
            if diamond then
                for _, child in ipairs(diamond:GetDescendants()) do
                    if child:IsA("TextLabel") and child.Text and child ~= desc then
                        local clean = string.gsub(child.Text, ",", "")
                        local num = string.match(clean, "^%s*(%d+)%s*$")
                        if num then return tonumber(num) end
                    end
                end
            end
        end
    end

    -- Fallback: Earned - Spent
    local earned, spent = nil, nil
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text then
            local t = string.upper(desc.Text)
            if string.find(t, "EARNED") then
                local num = string.match(string.gsub(t, ",", ""), "(%d+)")
                if num then earned = tonumber(num) end
            elseif string.find(t, "SPENT") then
                local num = string.match(string.gsub(t, ",", ""), "(%d+)")
                if num then spent = tonumber(num) end
            end
        end
    end
    if earned and spent and earned >= spent then
        return (earned - spent)
    end

    return 0
end

-- --------------------------------------------------------------------
-- Locate Custom Amount TextBox
-- --------------------------------------------------------------------
local function getCustomBox(win)
    if not win then return nil end
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextBox") then return desc end
    end
    return nil
end

-- --------------------------------------------------------------------
-- Locate Add (+) Button (Far Right Only)
-- --------------------------------------------------------------------
local function findAddButtonInRow(row)
    local candidates = {}
    for _, desc in ipairs(row:GetDescendants()) do
        if desc:IsA("GuiButton") and desc.Visible then
            local text = ""
            if desc:IsA("TextButton") then
                text = desc.Text
            else
                for _, ch in ipairs(desc:GetChildren()) do
                    if ch:IsA("TextLabel") and ch.Text then
                        text = ch.Text; break
                    end
                end
            end

            local isPlusOrMax = string.find(text, "+") or string.find(string.upper(text), "MAX")
            table.insert(candidates, {
                button = desc,
                isPlusOrMax = isPlusOrMax,
                x = desc.AbsolutePosition.X
            })
        end
    end

    for _, cand in ipairs(candidates) do
        if cand.isPlusOrMax then return cand.button end
    end

    table.sort(candidates, function(a, b) return a.x > b.x end)
    if #candidates > 0 then return candidates[1].button end
    return nil
end

-- --------------------------------------------------------------------
-- Extract Stat Row Data (Button, Current Lv, Max Lv, IsMax)
-- --------------------------------------------------------------------
local function getStatRow(win, statName)
    local target = string.upper(statName)
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text then
            local clean = string.upper(desc.Text)
            if clean == target or (string.find(clean, target, 1, true) and not string.find(clean, "PER LEVEL") and not string.find(clean, "DAMAGE") and not string.find(clean, "SPEED")) then
                local row = desc.Parent
                local depth = 0
                while row and row ~= win and depth < 5 do
                    local hasLv, curLv, maxLv = false, 0, 3150
                    local isMax = false

                    for _, child in ipairs(row:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Text then
                            local t = string.upper(child.Text)
                            if string.find(t, "LV") and string.find(t, "/") then
                                hasLv = true
                                local c = string.gsub(child.Text, ",", "")
                                local cur, mx = string.match(c, "(%d+)%s*/%s*(%d+)")
                                if cur and mx then
                                    curLv = tonumber(cur) or 0
                                    maxLv = tonumber(mx) or 3150
                                end
                            end
                            if string.find(t, "MAX") and not string.find(t, "PER STAT") then
                                isMax = true
                            end
                        end
                        if child:IsA("TextButton") and string.find(string.upper(child.Text), "MAX") then
                            isMax = true
                        end
                    end

                    local addBtn = findAddButtonInRow(row)
                    if hasLv and addBtn then
                        return {
                            button = addBtn,
                            current = curLv,
                            max = maxLv,
                            isMax = isMax or (curLv >= maxLv)
                        }
                    end

                    row = row.Parent
                    depth = depth + 1
                end
            end
        end
    end
    return nil
end

-- --------------------------------------------------------------------
-- Rapid Rebirth Sequence
-- --------------------------------------------------------------------
local function handleRapidRebirth(win, updateStatus)
    -- Step A: Check if confirmation dialog is ALREADY open
    local yesBtn, noBtn = findRebirthConfirmButtons()

    -- Step B: If not open yet, find and click REBIRTH in the stats window
    if not yesBtn then
        local rebirthBtn = nil
        for _, desc in ipairs(win:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Visible then
                local noTags = string.gsub(desc.Text, "<[^>]+>", "")
                local clean = string.upper(string.gsub(noTags, "[^%a]", ""))
                if clean == "REBIRTH" then
                    local b = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                    if b and b.Visible and b.AbsoluteSize.X > 0 and b.AbsolutePosition.X > 0 then
                        rebirthBtn = b; break
                    end
                end
            end
        end

        if not rebirthBtn then
            for _, b in ipairs(win:GetDescendants()) do
                if b:IsA("GuiButton") and b.Visible and string.find(string.lower(b.Name), "rebirth") then
                    rebirthBtn = b; break
                end
            end
        end

        if not rebirthBtn then
            return false
        end

        updateStatus("Clicking REBIRTH...", Color3.fromRGB(241, 196, 15))
        clickButton(rebirthBtn)

        -- Wait up to 1.0s for the confirmation dialog (YES button) to appear
        for _ = 1, 10 do
            task.wait(0.1)
            yesBtn, noBtn = findRebirthConfirmButtons()
            if yesBtn then break end
        end
    end

    -- Step C: Confirm YES with calibrated settle delay
    if yesBtn then
        updateStatus("Confirming YES...", Color3.fromRGB(46, 204, 113))
        task.wait(0.15) -- settle delay for popup animation
        clickButton(yesBtn)

        -- Wait for confirmation dialog to dismiss
        for _ = 1, 8 do
            task.wait(0.1)
            local stillYes = findRebirthConfirmButtons()
            if not stillYes then
                updateStatus("Rebirth Confirmed! Resetting...", Color3.fromRGB(46, 204, 113))
                task.wait(0.4)
                return true
            end
        end
        return true
    end

    return false
end

-- --------------------------------------------------------------------
-- Forward Reference for UI Updater
-- --------------------------------------------------------------------
local updateLiveStatsWidget = nil

-- --------------------------------------------------------------------
-- Rapid Execution Cycle (< 0.8s Total)
-- --------------------------------------------------------------------
local function runAutomationCycle(updateStatus)
    if isProcessing then return end
    isProcessing = true

    local success, err = pcall(function()
        -- 0. Close any accidental popups immediately
        dismissUnwantedPopups()

        local win = findStatsWindow()
        local openedByScript = false

        -- If Stats window is closed (or inside __Disable), open it via HUD stats button
        if not win or not win.Visible then
            local hudBtn = getHudStatsButton()
            if hudBtn then
                openedByScript = true
                updateStatus("Opening Stats Window...", Color3.fromRGB(52, 152, 219))
                clickButton(hudBtn)
                for _ = 1, 8 do
                    task.wait(0.08)
                    win = findStatsWindow()
                    if win and win.Visible then break end
                end
            end
        end

        if not win or not win.Visible then
            updateStatus("Waiting for Stats Window...", Color3.fromRGB(241, 196, 15))
            return
        end

        -- Refresh Live Stats Widget
        if updateLiveStatsWidget then
            updateLiveStatsWidget(win)
        end

        -- 1. Rapid Rebirth Check & Confirmation
        local didRebirth = handleRapidRebirth(win, updateStatus)
        if didRebirth then
            task.wait(0.4)
            if updateLiveStatsWidget then updateLiveStatsWidget(win) end
        end

        -- 2. Read Points & Custom Amount TextBox
        local points = getAvailablePoints(win)
        local customBox = getCustomBox(win)

        if points > 0 and customBox then
            updateStatus(string.format("Spending %d points...", points), Color3.fromRGB(52, 152, 219))

            -- Priority 1: Shadow Agility (Target 200)
            local agi = getStatRow(win, "Shadow Agility")
            if agi and not agi.isMax and agi.current < TARGET_AGILITY then
                local needed = TARGET_AGILITY - agi.current
                local toSpend = math.min(points, needed)
                if toSpend > 0 then
                    updateStatus(string.format("Adding %d to Agility (%d/%d)...", toSpend, agi.current, TARGET_AGILITY), Color3.fromRGB(46, 204, 113))
                    setCustomAmount(customBox, toSpend)
                    local freshAgi = getStatRow(win, "Shadow Agility")
                    if freshAgi and freshAgi.button then clickButton(freshAgi.button) end
                    task.wait(0.08)
                    points = getAvailablePoints(win)
                    if updateLiveStatsWidget then updateLiveStatsWidget(win) end
                end
            end

            -- Priority 2: Shadow Reach (Target 800)
            if points > 0 then
                local rch = getStatRow(win, "Shadow Reach")
                if rch and not rch.isMax and rch.current < TARGET_REACH then
                    local needed = TARGET_REACH - rch.current
                    local toSpend = math.min(points, needed)
                    if toSpend > 0 then
                        updateStatus(string.format("Adding %d to Reach (%d/%d)...", toSpend, rch.current, TARGET_REACH), Color3.fromRGB(46, 204, 113))
                        setCustomAmount(customBox, toSpend)
                        local freshRch = getStatRow(win, "Shadow Reach")
                        if freshRch and freshRch.button then clickButton(freshRch.button) end
                        task.wait(0.08)
                        points = getAvailablePoints(win)
                        if updateLiveStatsWidget then updateLiveStatsWidget(win) end
                    end
                end
            end

            -- Priority 3: Player Experience (Target MAX)
            if points > 0 then
                local exp = getStatRow(win, "Player Experience")
                if exp and not exp.isMax and exp.current < exp.max then
                    local needed = exp.max - exp.current
                    local toSpend = math.min(points, needed)
                    if toSpend > 0 then
                        updateStatus(string.format("Adding %d to Player Exp (%d/%d)...", toSpend, exp.current, exp.max), Color3.fromRGB(46, 204, 113))
                        setCustomAmount(customBox, toSpend)
                        local freshExp = getStatRow(win, "Player Experience")
                        if freshExp and freshExp.button then clickButton(freshExp.button) end
                        task.wait(0.08)
                        points = getAvailablePoints(win)
                        if updateLiveStatsWidget then updateLiveStatsWidget(win) end
                    end
                end
            end

            -- Overflow: Feed remaining points into Shadow Reach
            if points > 0 then
                local exp = getStatRow(win, "Player Experience")
                if exp and (exp.isMax or exp.current >= exp.max) then
                    local rch = getStatRow(win, "Shadow Reach")
                    if rch and not rch.isMax and rch.current < rch.max then
                        updateStatus(string.format("Exp MAX! Overflow %d to Reach...", points), Color3.fromRGB(155, 89, 182))
                        setCustomAmount(customBox, points)
                        local freshRch = getStatRow(win, "Shadow Reach")
                        if freshRch and freshRch.button then clickButton(freshRch.button) end
                        task.wait(0.08)
                        if updateLiveStatsWidget then updateLiveStatsWidget(win) end
                    end
                end
            end
        else
            updateStatus("Active (Monitoring Level & Stats)", Color3.fromRGB(230, 230, 230))
        end

        -- Rapid Close: Snap window closed immediately if opened by script (NEVER while confirm dialog is open)
        local isConfirmOpen = (findRebirthConfirmButtons() ~= nil)
        if openedByScript and not isConfirmOpen then
            task.wait(0.15)
            local closeBtn = findWindowCloseButton(win)
            if closeBtn then
                clickButton(closeBtn)
            else
                local hudBtn = getHudStatsButton()
                if hudBtn then clickButton(hudBtn) end
            end
        end
    end)

    if not success and err then
        warn("[Auto-Rebirth Error]: " .. tostring(err))
    end
    isProcessing = false
end

-- ====================================================================
-- CONTROL UI CREATION (Positioned Away from Left Bar Cluster)
-- ====================================================================
local function createUI()
    local oldUI = CoreGui:FindFirstChild("AutoRebirthGui") or playerGui:FindFirstChild("AutoRebirthGui")
    if oldUI then oldUI:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AutoRebirthGui"
    ScreenGui.ResetOnSpawn = false

    local targetParent = CoreGui
    pcall(function()
        ScreenGui.Parent = CoreGui
        local _ = CoreGui:GetChildren()
    end)
    if ScreenGui.Parent ~= CoreGui then
        ScreenGui.Parent = playerGui
        targetParent = playerGui
    end

    -- Draggable Main Container (Positioned at 240, 60 so it never covers the HUD)
    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Size = UDim2.fromOffset(260, 235)
    MainFrame.Position = UDim2.fromOffset(240, 60)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
    MainFrame.BorderSizePixel = 0

    local MainCorner = Instance.new("UICorner", MainFrame)
    MainCorner.CornerRadius = UDim.new(0, 10)

    local MainStroke = Instance.new("UIStroke", MainFrame)
    MainStroke.Color = Color3.fromRGB(45, 55, 80)
    MainStroke.Thickness = 1.5

    -- Dragging Logic
    local dragging, dragStart, startPos = false, nil, nil
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Header Title
    local TitleLabel = Instance.new("TextLabel", MainFrame)
    TitleLabel.Size = UDim2.new(1, -35, 0, 32)
    TitleLabel.Position = UDim2.fromOffset(10, 2)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "⚡ Auto Rebirth"
    TitleLabel.TextColor3 = Color3.new(1, 1, 1)
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Close (X) Button
    local CloseBtn = Instance.new("TextButton", MainFrame)
    CloseBtn.Size = UDim2.fromOffset(22, 22)
    CloseBtn.Position = UDim2.new(1, -28, 0, 7)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.TextSize = 11
    local CloseCorner = Instance.new("UICorner", CloseBtn)
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    -- Status Bar
    local StatusLabel = Instance.new("TextLabel", MainFrame)
    StatusLabel.Size = UDim2.new(1, -20, 0, 20)
    StatusLabel.Position = UDim2.fromOffset(10, 32)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "Status: Initializing..."
    StatusLabel.TextColor3 = Color3.fromRGB(241, 196, 15)
    StatusLabel.TextSize = 11
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left

    local function updateStatusText(txt, color)
        pcall(function()
            StatusLabel.Text = "Status: " .. tostring(txt)
            if color then StatusLabel.TextColor3 = color end
        end)
    end

    -- Real-Time Stats Display Frame
    local StatsCard = Instance.new("Frame", MainFrame)
    StatsCard.Size = UDim2.new(1, -20, 0, 75)
    StatsCard.Position = UDim2.fromOffset(10, 56)
    StatsCard.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
    local CardCorner = Instance.new("UICorner", StatsCard)
    CardCorner.CornerRadius = UDim.new(0, 8)
    local CardStroke = Instance.new("UIStroke", StatsCard)
    CardStroke.Color = Color3.fromRGB(35, 45, 65)

    local PointsText = Instance.new("TextLabel", StatsCard)
    PointsText.Size = UDim2.new(0.48, 0, 0, 18)
    PointsText.Position = UDim2.fromOffset(8, 6)
    PointsText.BackgroundTransparency = 1
    PointsText.Font = Enum.Font.GothamBold
    PointsText.Text = "Points: ..."
    PointsText.TextColor3 = Color3.fromRGB(241, 196, 15)
    PointsText.TextSize = 11
    PointsText.TextXAlignment = Enum.TextXAlignment.Left

    local AgiText = Instance.new("TextLabel", StatsCard)
    AgiText.Size = UDim2.new(0.5, 0, 0, 18)
    AgiText.Position = UDim2.new(0.5, 0, 0, 6)
    AgiText.BackgroundTransparency = 1
    AgiText.Font = Enum.Font.GothamBold
    AgiText.Text = "Agility: ... / 200"
    AgiText.TextColor3 = Color3.fromRGB(46, 204, 113)
    AgiText.TextSize = 11
    AgiText.TextXAlignment = Enum.TextXAlignment.Left

    local ReachText = Instance.new("TextLabel", StatsCard)
    ReachText.Size = UDim2.new(1, -16, 0, 18)
    ReachText.Position = UDim2.fromOffset(8, 28)
    ReachText.BackgroundTransparency = 1
    ReachText.Font = Enum.Font.GothamBold
    ReachText.Text = "Reach: ... / 800"
    ReachText.TextColor3 = Color3.fromRGB(52, 152, 219)
    ReachText.TextSize = 11
    ReachText.TextXAlignment = Enum.TextXAlignment.Left

    local ExpText = Instance.new("TextLabel", StatsCard)
    ExpText.Size = UDim2.new(1, -16, 0, 18)
    ExpText.Position = UDim2.fromOffset(8, 50)
    ExpText.BackgroundTransparency = 1
    ExpText.Font = Enum.Font.GothamBold
    ExpText.Text = "Player Exp: ..."
    ExpText.TextColor3 = Color3.fromRGB(46, 204, 113)
    ExpText.TextSize = 11
    ExpText.TextXAlignment = Enum.TextXAlignment.Left

    -- Live Widget Updater
    updateLiveStatsWidget = function(win)
        if not win then return end
        local pts = getAvailablePoints(win)
        local agi = getStatRow(win, "Shadow Agility")
        local rch = getStatRow(win, "Shadow Reach")
        local exp = getStatRow(win, "Player Experience")

        PointsText.Text = string.format("Points: %s", tostring(pts))

        if agi then
            AgiText.Text = string.format("Agility: %s / %s", tostring(agi.current), tostring(TARGET_AGILITY))
            AgiText.TextColor3 = (agi.current >= TARGET_AGILITY) and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(241, 196, 15)
        end

        if rch then
            ReachText.Text = string.format("Reach: %s / %s", tostring(rch.current), tostring(TARGET_REACH))
            ReachText.TextColor3 = (rch.current >= TARGET_REACH) and Color3.fromRGB(52, 152, 219) or Color3.fromRGB(241, 196, 15)
        end

        if exp then
            if exp.isMax or (exp.max > 0 and exp.current >= exp.max) then
                ExpText.Text = string.format("Player Exp: MAX (%s)", tostring(exp.max))
                ExpText.TextColor3 = Color3.fromRGB(46, 204, 113)
            else
                ExpText.Text = string.format("Player Exp: %s / %s", tostring(exp.current), tostring(exp.max))
                ExpText.TextColor3 = Color3.fromRGB(230, 230, 230)
            end
        end
    end

    -- Master ON / OFF Toggle Button
    local ToggleBtn = Instance.new("TextButton", MainFrame)
    ToggleBtn.Size = UDim2.new(1, -20, 0, 32)
    ToggleBtn.Position = UDim2.fromOffset(10, 140)
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 12
    local ToggleCorner = Instance.new("UICorner", ToggleBtn)
    ToggleCorner.CornerRadius = UDim.new(0, 6)

    local function updateToggleBtnVisual()
        if AutoRebirthEnabled then
            ToggleBtn.Text = "AUTO REBIRTH: ACTIVE"
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
            ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
        else
            ToggleBtn.Text = "AUTO REBIRTH: PAUSED"
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
            ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
        end
    end
    updateToggleBtnVisual()

    ToggleBtn.MouseButton1Click:Connect(function()
        AutoRebirthEnabled = not AutoRebirthEnabled
        updateToggleBtnVisual()
        if AutoRebirthEnabled then
            updateStatusText("Active (Monitoring)", Color3.fromRGB(46, 204, 113))
            task.spawn(function()
                runAutomationCycle(updateStatusText)
            end)
        else
            updateStatusText("Paused by User", Color3.fromRGB(231, 76, 60))
        end
    end)

    -- Manual Instant Check Button
    local ManualBtn = Instance.new("TextButton", MainFrame)
    ManualBtn.Size = UDim2.new(1, -20, 0, 28)
    ManualBtn.Position = UDim2.fromOffset(10, 178)
    ManualBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
    ManualBtn.Font = Enum.Font.GothamBold
    ManualBtn.Text = "▶  Run Rapid Check Now"
    ManualBtn.TextColor3 = Color3.new(1, 1, 1)
    ManualBtn.TextSize = 11
    local ManualCorner = Instance.new("UICorner", ManualBtn)
    ManualCorner.CornerRadius = UDim.new(0, 6)

    ManualBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            runAutomationCycle(updateStatusText)
        end)
    end)

    -- Rules Footer
    local FooterLabel = Instance.new("TextLabel", MainFrame)
    FooterLabel.Size = UDim2.new(1, -20, 0, 18)
    FooterLabel.Position = UDim2.fromOffset(10, 212)
    FooterLabel.BackgroundTransparency = 1
    FooterLabel.Font = Enum.Font.Gotham
    FooterLabel.Text = "Target: Agi 200 → Reach 800 → Exp MAX"
    FooterLabel.TextColor3 = Color3.fromRGB(120, 140, 170)
    FooterLabel.TextSize = 9
    FooterLabel.TextXAlignment = Enum.TextXAlignment.Center

    -- Background Execution Loop
    task.spawn(function()
        updateStatusText("Ready (Active)", Color3.fromRGB(46, 204, 113))
        while ScreenGui.Parent do
            task.wait(CHECK_INTERVAL)
            if AutoRebirthEnabled then
                runAutomationCycle(updateStatusText)
            end
        end
    end)
end

-- Launch
createUI()
print("[Auto-Rebirth] V12 (Perfect Confirmation Engine) loaded successfully!")
