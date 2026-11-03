-- ====================================================================
-- AUTO REBIRTH & STAT ALLOCATION (V2 - CONFIRMATION & STATS FIX)
-- ====================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- --------------------------------------------------------------------
-- Configuration
-- --------------------------------------------------------------------
local TARGET_AGILITY = 200   -- Priority 1: 200 Shadow Agility
local TARGET_REACH   = 800   -- Priority 2: 800 Shadow Reach
local CHECK_INTERVAL = 2.0   -- Check frequency in seconds

-- System States
local AutoRebirthEnabled = true
local StealthModeEnabled = true
local isProcessing = false

-- --------------------------------------------------------------------
-- Multi-Layer Safe Click (Zero Cursor Disruption)
-- --------------------------------------------------------------------
local function clickGui(btn)
    if not btn then return end

    -- 1. firesignal
    pcall(function()
        if typeof(firesignal) == "function" then
            firesignal(btn.Activated)
            firesignal(btn.MouseButton1Click)
            firesignal(btn.MouseButton1Down)
            firesignal(btn.MouseButton1Up)
        end
    end)

    -- 2. getconnections
    pcall(function()
        if typeof(getconnections) == "function" then
            for _, sig in ipairs({btn.Activated, btn.MouseButton1Click, btn.MouseButton1Down, btn.MouseButton1Up}) do
                for _, c in ipairs(getconnections(sig)) do
                    if c.Fire then c:Fire() elseif c.Function then c.Function() end
                end
            end
        end
    end)

    -- 3. VirtualInputManager fallback (Engine-level input)
    pcall(function()
        if btn.AbsoluteSize.X > 0 and btn.AbsolutePosition.X > 0 and btn.AbsolutePosition.Y > 0 then
            local inset = GuiService:GetGuiInset()
            local cx = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
            local cy = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2) + inset.Y
            local origMouse = UserInputService:GetMouseLocation()
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.03)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            -- Restore original mouse position immediately
            VIM:SendMouseMoveEvent(origMouse.X, origMouse.Y, game)
        end
    end)
end

-- --------------------------------------------------------------------
-- Authentic TextBox Submission (Triggers Enter & FocusLost)
-- --------------------------------------------------------------------
local function setCustomAmount(box, amount)
    if not box then return end
    local str = tostring(amount)
    if box.Text == str then return end

    pcall(function() box:CaptureFocus() end)
    box.Text = str

    -- Native focus release with enterPressed = true
    pcall(function() box:ReleaseFocus(true) end)

    -- Simulate Enter key press
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end)

    -- Executor connection fallback
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
    task.wait(0.12)
end

-- --------------------------------------------------------------------
-- Locate Stats Window
-- --------------------------------------------------------------------
local function findStatsWindow()
    local menus = playerGui:FindFirstChild("Menus") or playerGui:FindFirstChild("__Disable")
    if menus then
        for _, m in ipairs(menus:GetChildren()) do
            if string.find(string.lower(m.Name), "stat") then return m end
        end
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text then
            local u = string.upper(desc.Text)
            if string.find(u, "SPEND YOUR POINTS", 1, true) or string.find(u, "POINTS TO SPEND", 1, true) then
                local curr = desc
                while curr and curr.Parent and curr.Parent ~= playerGui and not curr.Parent:IsA("ScreenGui") do
                    for _, c in ipairs(curr:GetChildren()) do
                        if c:IsA("GuiButton") and (c.Name == "Close" or (c:IsA("TextButton") and c.Text == "X")) then
                            return curr
                        end
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
-- Locate HUD 'Stats' Hex Button
-- --------------------------------------------------------------------
local function getHudStatsButton()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Visible then
            local clean = string.upper(string.gsub(desc.Text, "<[^>]+>", ""))
            clean = string.gsub(clean, "%s+", "")
            if clean == "STATS" then
                local p = desc.Parent
                local isInside = false
                while p and p ~= playerGui do
                    if p.Name and string.find(string.lower(p.Name), "stat") then
                        isInside = true; break
                    end
                    p = p.Parent
                end
                if not isInside then
                    local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                    if btn and btn.Visible then return btn end
                end
            end
        end
    end
    return nil
end

-- --------------------------------------------------------------------
-- Read Available Points To Spend
-- --------------------------------------------------------------------
local function getAvailablePoints(win)
    if not win then return 0 end

    -- Primary: Diamond counter
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and string.find(string.upper(desc.Text), "POINTS TO SPEND", 1, true) then
            local parent = desc.Parent
            if parent then
                for _, ch in ipairs(parent:GetDescendants()) do
                    if ch ~= desc and ch:IsA("TextLabel") and ch.Text then
                        local clean = string.gsub(ch.Text, ",", "")
                        local num = tonumber(string.match(clean, "^%s*(%d+)%s*$"))
                        if num and not string.find(ch.Text, "per") and not string.find(ch.Text, "=") then
                            return num
                        end
                    end
                end
            end
        end
    end

    -- Mathematical fallback: Earned - Spent
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
-- Locate the Add (+) Button Inside a Row (Far Right Only)
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

    -- 1. Prioritize button containing '+' or 'MAX'
    for _, cand in ipairs(candidates) do
        if cand.isPlusOrMax then return cand.button end
    end

    -- 2. Fallback: Rightmost button in the row
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
                    local hasLv, curLv, maxLv = false, 0, 2850
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
                                    maxLv = tonumber(mx) or 2850
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
-- Rebirth Detection & Confirmation Handling
-- --------------------------------------------------------------------
local function findConfirmationYesButton()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Visible then
            local clean = string.upper(string.gsub(desc.Text, "[^%a]", ""))
            -- Strictly match confirmation words (NEVER match "REBIRTH")
            if clean == "YES" or clean == "CONFIRM" or clean == "ACCEPT" then
                local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                if btn and btn.Visible then return btn end
            end
        end
    end
    return nil
end

local function checkAndTriggerRebirth(win, updateStatus)
    local rebirthBtn = nil
    for _, desc in ipairs(win:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Visible then
            local clean = string.upper(string.gsub(desc.Text, "%s+", ""))
            if clean == "REBIRTH" then
                local b = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                if b and b.Visible and b.AbsoluteSize.X > 0 then
                    rebirthBtn = b
                    break
                end
            end
        end
    end

    if rebirthBtn then
        updateStatus("Clicking REBIRTH...", Color3.fromRGB(241, 196, 15))
        clickGui(rebirthBtn)

        -- Search for the "YES" confirmation button (poll up to 5 times)
        local yesBtn = nil
        for _ = 1, 5 do
            task.wait(0.3)
            yesBtn = findConfirmationYesButton()
            if yesBtn then break end
        end

        if yesBtn then
            updateStatus("Confirming YES...", Color3.fromRGB(46, 204, 113))
            clickGui(yesBtn)
            task.wait(0.4)

            -- Retry once if confirmation dialog is still present
            local retryYes = findConfirmationYesButton()
            if retryYes then
                clickGui(retryYes)
                task.wait(0.4)
            end

            updateStatus("Rebirth Complete! Resetting...", Color3.fromRGB(46, 204, 113))
            task.wait(1.0)
            return true
        else
            updateStatus("Rebirth clicked (no popup appeared)", Color3.fromRGB(230, 126, 34))
            return true
        end
    end
    return false
end

-- --------------------------------------------------------------------
-- Main Automation Loop
-- --------------------------------------------------------------------
local function runAutomationCycle(updateStatus)
    if isProcessing then return end
    isProcessing = true

    local success, err = pcall(function()
        local win = findStatsWindow()
        local hudBtn = getHudStatsButton()
        local openedByScript = false
        local originalPos = nil

        -- Open window if currently closed
        if (not win or not win.Visible) and hudBtn then
            openedByScript = true
            clickGui(hudBtn)
            task.wait(0.35)
            win = findStatsWindow()
        end

        if not win then
            updateStatus("Stats UI not found", Color3.fromRGB(241, 196, 15))
            return
        end

        -- Keep off-screen if Stealth Mode is enabled
        if openedByScript and StealthModeEnabled and win:IsA("GuiObject") then
            originalPos = win.Position
            win.Position = UDim2.fromOffset(-9999, -9999)
        end

        -- 1. Rebirth Check
        local didRebirth = checkAndTriggerRebirth(win, updateStatus)
        if didRebirth then
            task.wait(0.8)
        end

        -- 2. Read Points & Custom TextBox
        local points = getAvailablePoints(win)
        local customBox = getCustomBox(win)

        if points > 0 and customBox then
            updateStatus(string.format("Points to spend: %d", points), Color3.fromRGB(52, 152, 219))

            -- Priority 1: Shadow Agility (Target 200)
            local agi = getStatRow(win, "Shadow Agility")
            if agi and not agi.isMax and agi.current < TARGET_AGILITY then
                local needed = TARGET_AGILITY - agi.current
                local toSpend = math.min(points, needed)
                if toSpend > 0 then
                    updateStatus(string.format("Adding %d to Agility (%d/%d)...", toSpend, agi.current, TARGET_AGILITY), Color3.fromRGB(46, 204, 113))
                    setCustomAmount(customBox, toSpend)
                    task.wait(0.1)
                    local freshAgi = getStatRow(win, "Shadow Agility")
                    if freshAgi and freshAgi.button then clickGui(freshAgi.button) end
                    task.wait(0.2)
                    points = getAvailablePoints(win)
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
                        task.wait(0.1)
                        local freshRch = getStatRow(win, "Shadow Reach")
                        if freshRch and freshRch.button then clickGui(freshRch.button) end
                        task.wait(0.2)
                        points = getAvailablePoints(win)
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
                        task.wait(0.1)
                        local freshExp = getStatRow(win, "Player Experience")
                        if freshExp and freshExp.button then clickGui(freshExp.button) end
                        task.wait(0.2)
                        points = getAvailablePoints(win)
                    end
                end
            end

            -- Overflow: Feed remaining points into Shadow Reach
            if points > 0 then
                local exp = getStatRow(win, "Player Experience")
                if exp and (exp.isMax or exp.current >= exp.max) then
                    local rch = getStatRow(win, "Shadow Reach")
                    if rch and not rch.isMax and rch.current < rch.max then
                        updateStatus(string.format("Exp MAX! Adding %d overflow to Reach...", points), Color3.fromRGB(155, 89, 182))
                        setCustomAmount(customBox, points)
                        task.wait(0.1)
                        local freshRch = getStatRow(win, "Shadow Reach")
                        if freshRch and freshRch.button then clickGui(freshRch.button) end
                        task.wait(0.2)
                    end
                end
            end
        else
            updateStatus("Active (Points: 0 | Monitoring)", Color3.fromRGB(230, 230, 230))
        end

        -- Clean up window
        if openedByScript then
            if originalPos and win:IsA("GuiObject") then
                win.Position = originalPos
            end
            for _, d in ipairs(win:GetDescendants()) do
                if d:IsA("GuiButton") and (d.Name == "Close" or (d:IsA("TextButton") and d.Text == "X")) then
                    clickGui(d)
                    break
                end
            end
        end
    end)

    if not success and err then
        warn("[Auto-Rebirth Error]: " .. tostring(err))
    end
    isProcessing = false
end

-- ====================================================================
-- CONTROL UI CREATION
-- ====================================================================

local function createUI()
    local guiParent = nil
    pcall(function()
        if typeof(gethui) == "function" then guiParent = gethui() end
    end)
    if not guiParent then
        local success = pcall(function() local f = Instance.new("Folder", CoreGui); f:Destroy() end)
        guiParent = success and CoreGui or playerGui
    end

    local existing = guiParent:FindFirstChild("AutoRebirthControlUI")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AutoRebirthControlUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = guiParent

    -- Main Container
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.fromOffset(265, 210)
    MainFrame.Position = UDim2.fromOffset(35, 150)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner", MainFrame)
    MainCorner.CornerRadius = UDim.new(0, 9)

    local MainStroke = Instance.new("UIStroke", MainFrame)
    MainStroke.Color = Color3.fromRGB(45, 95, 175)
    MainStroke.Thickness = 1.5

    -- Title Bar
    local TitleBar = Instance.new("Frame", MainFrame)
    TitleBar.Size = UDim2.new(1, 0, 0, 32)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 32, 50)
    TitleBar.BorderSizePixel = 0
    local TitleCorner = Instance.new("UICorner", TitleBar)
    TitleCorner.CornerRadius = UDim.new(0, 9)

    local TitleLabel = Instance.new("TextLabel", TitleBar)
    TitleLabel.Size = UDim2.new(1, -40, 1, 0)
    TitleLabel.Position = UDim2.fromOffset(10, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "⚡ Auto Rebirth & Stats"
    TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local CloseBtn = Instance.new("TextButton", TitleBar)
    CloseBtn.Size = UDim2.fromOffset(24, 24)
    CloseBtn.Position = UDim2.new(1, -28, 0, 4)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.TextSize = 12
    local CloseCorner = Instance.new("UICorner", CloseBtn)
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    -- Status Label
    local StatusLabel = Instance.new("TextLabel", MainFrame)
    StatusLabel.Size = UDim2.new(1, -20, 0, 24)
    StatusLabel.Position = UDim2.fromOffset(10, 38)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Font = Enum.Font.GothamMedium
    StatusLabel.Text = "Status: Initializing..."
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 11
    StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left

    local function updateStatusText(txt, color)
        StatusLabel.Text = "Status: " .. txt
        if color then StatusLabel.TextColor3 = color end
    end

    -- Master ON / OFF Toggle Button
    local ToggleBtn = Instance.new("TextButton", MainFrame)
    ToggleBtn.Size = UDim2.new(1, -20, 0, 34)
    ToggleBtn.Position = UDim2.fromOffset(10, 68)
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.TextSize = 13
    local ToggleCorner = Instance.new("UICorner", ToggleBtn)
    ToggleCorner.CornerRadius = UDim.new(0, 7)

    local function updateToggleBtnVisual()
        if AutoRebirthEnabled then
            ToggleBtn.Text = "AUTO REBIRTH: ACTIVE"
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
            ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
        else
            ToggleBtn.Text = "AUTO REBIRTH: PAUSED"
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
            ToggleBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
            updateStatusText("Paused", Color3.fromRGB(180, 180, 180))
        end
    end
    updateToggleBtnVisual()

    ToggleBtn.MouseButton1Click:Connect(function()
        AutoRebirthEnabled = not AutoRebirthEnabled
        updateToggleBtnVisual()
    end)

    -- Stealth Mode Toggle Button
    local StealthBtn = Instance.new("TextButton", MainFrame)
    StealthBtn.Size = UDim2.new(1, -20, 0, 26)
    StealthBtn.Position = UDim2.fromOffset(10, 108)
    StealthBtn.Font = Enum.Font.GothamSemibold
    StealthBtn.TextSize = 11
    local StealthCorner = Instance.new("UICorner", StealthBtn)
    StealthCorner.CornerRadius = UDim.new(0, 6)

    local function updateStealthBtnVisual()
        if StealthModeEnabled then
            StealthBtn.Text = "Stealth Mode: ON (Hidden UI)"
            StealthBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
            StealthBtn.TextColor3 = Color3.new(1, 1, 1)
        else
            StealthBtn.Text = "Stealth Mode: OFF (Visible UI)"
            StealthBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 95)
            StealthBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
    updateStealthBtnVisual()

    StealthBtn.MouseButton1Click:Connect(function()
        StealthModeEnabled = not StealthModeEnabled
        updateStealthBtnVisual()
    end)

    -- Manual Trigger Button
    local ManualBtn = Instance.new("TextButton", MainFrame)
    ManualBtn.Size = UDim2.new(1, -20, 0, 26)
    ManualBtn.Position = UDim2.fromOffset(10, 140)
    ManualBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
    ManualBtn.Font = Enum.Font.GothamBold
    ManualBtn.Text = "▶ Run Check Now"
    ManualBtn.TextColor3 = Color3.new(1, 1, 1)
    ManualBtn.TextSize = 11
    local ManualCorner = Instance.new("UICorner", ManualBtn)
    ManualCorner.CornerRadius = UDim.new(0, 6)

    ManualBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            runAutomationCycle(updateStatusText)
        end)
    end)

    -- Target Rules Summary
    local TargetLabel = Instance.new("TextLabel", MainFrame)
    TargetLabel.Size = UDim2.new(1, -20, 0, 20)
    TargetLabel.Position = UDim2.fromOffset(10, 178)
    TargetLabel.BackgroundTransparency = 1
    TargetLabel.Font = Enum.Font.Gotham
    TargetLabel.Text = "Agi: 200  |  Reach: 800  |  Exp: MAX"
    TargetLabel.TextColor3 = Color3.fromRGB(130, 150, 180)
    TargetLabel.TextSize = 10
    TargetLabel.TextXAlignment = Enum.TextXAlignment.Center

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
print("[Auto-Rebirth] V2 loaded successfully!")
