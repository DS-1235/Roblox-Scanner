-- ====================================================================
-- AUTO REBIRTH & STAT ALLOCATION WITH CONTROL UI
-- ====================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration Targets
local TARGET_AGILITY = 200   -- Target Lv 200 Shadow Agility
local TARGET_REACH   = 800   -- Target Lv 800 Shadow Reach
local CHECK_INTERVAL = 2.0   -- Loop interval in seconds

-- State Variables
local AutoRebirthEnabled = true
local StealthModeEnabled = true
local isProcessing = false

-- --------------------------------------------------------------------
-- Safe Headless Click Helper (Zero Mouse Movement)
-- --------------------------------------------------------------------
local function safeClick(btn)
    if not btn then return end
    pcall(function()
        if typeof(firesignal) == "function" then
            firesignal(btn.Activated)
            firesignal(btn.MouseButton1Click)
            firesignal(btn.MouseButton1Down)
            firesignal(btn.MouseButton1Up)
        end
    end)
    pcall(function()
        if typeof(getconnections) == "function" then
            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
            for _, c in ipairs(getconnections(btn.MouseButton1Down)) do c:Fire() end
            for _, c in ipairs(getconnections(btn.MouseButton1Up)) do c:Fire() end
        end
    end)
end

-- --------------------------------------------------------------------
-- Safe TextBox String Input Helper
-- --------------------------------------------------------------------
local function setCustomAmount(box, amount)
    if not box then return end
    box.Text = tostring(amount)
    pcall(function()
        if typeof(firesignal) == "function" then
            firesignal(box.FocusLost, true)
        end
    end)
    pcall(function()
        if typeof(getconnections) == "function" then
            for _, c in ipairs(getconnections(box.FocusLost)) do c:Fire(true) end
            for _, c in ipairs(getconnections(box:GetPropertyChangedSignal("Text"))) do c:Fire() end
        end
    end)
    task.wait(0.08)
end

-- --------------------------------------------------------------------
-- Find Stats Window by Content (Spend Your Points)
-- --------------------------------------------------------------------
local function findStatsWindow()
    local menus = playerGui:FindFirstChild("Menus") or playerGui:FindFirstChild("__Disable")
    if menus then
        for _, m in ipairs(menus:GetChildren()) do
            if string.find(string.lower(m.Name), "stat") then
                return m
            end
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
-- Find HUD 'Stats' Hex Button
-- --------------------------------------------------------------------
local function getHudStatsButton()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Visible then
            local clean = string.upper(string.gsub(desc.Text, "<[^>]+>", ""))
            clean = string.gsub(clean, "%s+", "")
            if clean == "STATS" then
                local p = desc.Parent
                local isInsideWindow = false
                while p and p ~= playerGui do
                    if p.Name and string.find(string.lower(p.Name), "stat") then
                        isInsideWindow = true; break
                    end
                    p = p.Parent
                end
                if not isInsideWindow then
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

    -- Primary: Read Diamond counter near "POINTS TO SPEND"
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
-- Find Custom Amount TextBox (near Talents/x1/x10/x100)
-- --------------------------------------------------------------------
local function getCustomBox(win)
    if not win then return nil end
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextBox") then
            return desc
        end
    end
    return nil
end

-- --------------------------------------------------------------------
-- Extract Stat Row Info (Button, Current Lv, Max Lv, IsMax)
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
                    local addBtn = nil
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
                        if child:IsA("GuiButton") and child.Visible then
                            addBtn = child
                            if child:IsA("TextButton") and string.find(string.upper(child.Text), "MAX") then
                                isMax = true
                            end
                        end
                    end

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
-- Rebirth Detection & Confirmation
-- --------------------------------------------------------------------
local function checkAndTriggerRebirth(win)
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
        safeClick(rebirthBtn)
        task.wait(0.35)

        for _, d in ipairs(playerGui:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text and d.Visible then
                local u = string.upper(string.gsub(d.Text, "%s+", ""))
                if u == "YES" or u == "CONFIRM" or u == "REBIRTH" or u == "OK" then
                    local cb = d:IsA("GuiButton") and d or d:FindFirstAncestorWhichIsA("GuiButton")
                    if cb and cb.Visible then
                        safeClick(cb)
                        task.wait(0.5)
                        return true
                    end
                end
            end
        end
        return true
    end
    return false
end

-- --------------------------------------------------------------------
-- Main Allocation & Rebirth Execution Cycle
-- --------------------------------------------------------------------
local function runAutomationCycle(updateStatus)
    if isProcessing then return end
    isProcessing = true

    local success, err = pcall(function()
        local win = findStatsWindow()
        local hudBtn = getHudStatsButton()
        local openedByScript = false
        local originalPos = nil

        -- Open window headlessly if closed
        if (not win or not win.Visible) and hudBtn then
            openedByScript = true
            safeClick(hudBtn)
            task.wait(0.3)
            win = findStatsWindow()
        end

        if not win then
            updateStatus("Waiting for Stats UI...", Color3.fromRGB(241, 196, 15))
            return
        end

        -- Keep off-screen if Stealth Mode is ON
        if openedByScript and StealthModeEnabled and win:IsA("GuiObject") then
            originalPos = win.Position
            win.Position = UDim2.fromOffset(-9999, -9999)
        end

        -- 1. Check & Trigger Rebirth if Max Level reached
        local didRebirth = checkAndTriggerRebirth(win)
        if didRebirth then
            updateStatus("Rebirth Executed! Confirming...", Color3.fromRGB(46, 204, 113))
            task.wait(0.8)
        end

        -- 2. Read Points & Custom TextBox
        local points = getAvailablePoints(win)
        local customBox = getCustomBox(win)

        if points > 0 and customBox then
            updateStatus(string.format("Points to spend: %d", points), Color3.fromRGB(52, 152, 219))

            -- Priority 1: Shadow Agility (Target: 200)
            local agi = getStatRow(win, "Shadow Agility")
            if agi and not agi.isMax and agi.current < TARGET_AGILITY then
                local needed = TARGET_AGILITY - agi.current
                local toSpend = math.min(points, needed)
                if toSpend > 0 then
                    updateStatus(string.format("Adding %d to Agility (%d/%d)...", toSpend, agi.current, TARGET_AGILITY), Color3.fromRGB(46, 204, 113))
                    setCustomAmount(customBox, toSpend)
                    safeClick(agi.button)
                    task.wait(0.18)
                    points = points - toSpend
                end
            end

            -- Priority 2: Shadow Reach (Target: 800)
            if points > 0 then
                local rch = getStatRow(win, "Shadow Reach")
                if rch and not rch.isMax and rch.current < TARGET_REACH then
                    local needed = TARGET_REACH - rch.current
                    local toSpend = math.min(points, needed)
                    if toSpend > 0 then
                        updateStatus(string.format("Adding %d to Reach (%d/%d)...", toSpend, rch.current, TARGET_REACH), Color3.fromRGB(46, 204, 113))
                        setCustomAmount(customBox, toSpend)
                        safeClick(rch.button)
                        task.wait(0.18)
                        points = points - toSpend
                    end
                end
            end

            -- Priority 3: Player Experience (Target: MAX)
            if points > 0 then
                local exp = getStatRow(win, "Player Experience")
                if exp and not exp.isMax and exp.current < exp.max then
                    local needed = exp.max - exp.current
                    local toSpend = math.min(points, needed)
                    if toSpend > 0 then
                        updateStatus(string.format("Adding %d to Player Exp (%d/%d)...", toSpend, exp.current, exp.max), Color3.fromRGB(46, 204, 113))
                        setCustomAmount(customBox, toSpend)
                        safeClick(exp.button)
                        task.wait(0.18)
                        points = points - toSpend
                    end
                end
            end

            -- Overflow: If Player Exp is MAX, add remaining points into Shadow Reach
            if points > 0 then
                local exp = getStatRow(win, "Player Experience")
                if exp and (exp.isMax or exp.current >= exp.max) then
                    local rch = getStatRow(win, "Shadow Reach")
                    if rch and not rch.isMax and rch.current < rch.max then
                        updateStatus(string.format("Exp MAX! Dumping %d overflow to Reach...", points), Color3.fromRGB(155, 89, 182))
                        setCustomAmount(customBox, points)
                        safeClick(rch.button)
                        task.wait(0.18)
                    end
                end
            end
        else
            updateStatus("Active (Monitoring Level & Stats)", Color3.fromRGB(230, 230, 230))
        end

        -- Clean up window
        if openedByScript then
            if originalPos and win:IsA("GuiObject") then
                win.Position = originalPos
            end
            for _, d in ipairs(win:GetDescendants()) do
                if d:IsA("GuiButton") and (d.Name == "Close" or (d:IsA("TextButton") and d.Text == "X")) then
                    safeClick(d)
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
    MainFrame.Size = UDim2.fromOffset(260, 205)
    MainFrame.Position = UDim2.fromOffset(40, 160)
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

    -- Header
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

    -- Toggle Button (Master ON / OFF)
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

    -- Stealth Mode Button (Window Hide/Show)
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

    -- Target Rules Summary Line
    local TargetLabel = Instance.new("TextLabel", MainFrame)
    TargetLabel.Size = UDim2.new(1, -20, 0, 20)
    TargetLabel.Position = UDim2.fromOffset(10, 175)
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

-- Launch the System
createUI()
print("[Auto-Rebirth] System & UI loaded successfully!")
