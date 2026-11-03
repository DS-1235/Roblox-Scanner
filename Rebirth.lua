-- ====================================================================
-- AUTO REBIRTH & STAT ALLOCATION (V3 - REAL-TIME STATS & CLOSED-UI FIX)
-- ====================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- --------------------------------------------------------------------
-- Configuration Targets
-- --------------------------------------------------------------------
local TARGET_AGILITY = 200   -- Priority 1: 200 Shadow Agility
local TARGET_REACH   = 800   -- Priority 2: 800 Shadow Reach
local CHECK_INTERVAL = 2.0   -- Check frequency in seconds

-- System States
local AutoRebirthEnabled = true
local AutoCloseEnabled   = true
local isProcessing       = false

-- --------------------------------------------------------------------
-- Multi-Layer Safe Click Helper
-- --------------------------------------------------------------------
local function clickGui(btn)
    if not btn then return end

    -- Layer 1: firesignal
    pcall(function()
        if typeof(firesignal) == "function" then
            firesignal(btn.Activated)
            firesignal(btn.MouseButton1Click)
            firesignal(btn.MouseButton1Down)
            firesignal(btn.MouseButton1Up)
        end
    end)

    -- Layer 2: getconnections
    pcall(function()
        if typeof(getconnections) == "function" then
            for _, sig in ipairs({btn.Activated, btn.MouseButton1Click, btn.MouseButton1Down, btn.MouseButton1Up}) do
                for _, c in ipairs(getconnections(sig)) do
                    if c.Fire then c:Fire() elseif c.Function then c.Function() end
                end
            end
        end
    end)

    -- Layer 3: VirtualInputManager (Engine-level input)
    pcall(function()
        if btn.AbsoluteSize.X > 0 and btn.AbsolutePosition.X > 0 and btn.AbsolutePosition.Y > 0 then
            local inset = GuiService:GetGuiInset()
            local cx = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
            local cy = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2) + inset.Y
            local origMouse = UserInputService:GetMouseLocation()
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.03)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            VIM:SendMouseMoveEvent(origMouse.X, origMouse.Y, game)
        end
    end)
end

-- --------------------------------------------------------------------
-- Authentic TextBox Submission (Captures Focus, Sets Text, Submits Enter)
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
    task.wait(0.12)
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
-- Locate the Stats Window Frame
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
-- Locate the Hexagonal HUD 'Stats' Button
-- --------------------------------------------------------------------
local function getHudStatsButton()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Visible then
            local clean = string.upper(string.gsub(desc.Text, "<[^>]+>", ""))
            clean = string.gsub(clean, "%s+", "")
            if clean == "STATS" then
                if not isInsideStatsWindow(desc) then
                    local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                    if btn and btn.Visible and btn.AbsolutePosition.X > 0 and btn.AbsolutePosition.Y > 0 then
                        return btn
                    end
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
-- Locate the Add (+) Button (Far Right Only)
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
                    local hasLv, curLv, maxLv = false, 0, 3075
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
                                    maxLv = tonumber(mx) or 3075
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
-- Rebirth Detection & Confirmation
-- --------------------------------------------------------------------
local function findConfirmationYesButton()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Visible then
            local clean = string.upper(string.gsub(desc.Text, "[^%a]", ""))
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

        local yesBtn = nil
        for _ = 1, 6 do
            task.wait(0.3)
            yesBtn = findConfirmationYesButton()
            if yesBtn then break end
        end

        if yesBtn then
            updateStatus("Confirming YES...", Color3.fromRGB(46, 204, 113))
            clickGui(yesBtn)
            task.wait(0.4)

            local retryYes = findConfirmationYesButton()
            if retryYes then
                clickGui(retryYes)
                task.wait(0.4)
            end

            updateStatus("Rebirth Complete! Resetting...", Color3.fromRGB(46, 204, 113))
            task.wait(1.0)
            return true
        end
    end
    return false
end

-- --------------------------------------------------------------------
-- Forward References for UI
-- --------------------------------------------------------------------
local updateLiveStatsWidget = nil

-- --------------------------------------------------------------------
-- Main Automation Cycle
-- --------------------------------------------------------------------
local function runAutomationCycle(updateStatus)
    if isProcessing then return end
    isProcessing = true

    local success, err = pcall(function()
        local win = findStatsWindow()
        local openedByScript = false

        -- If the window is currently closed, locate HUD button and open it
        if not win or not win.Visible then
            local hudBtn = getHudStatsButton()
            if hudBtn then
                openedByScript = true
                updateStatus("Opening Stats window...", Color3.fromRGB(52, 152, 219))
                clickGui(hudBtn)
                task.wait(0.4)
                win = findStatsWindow()
            end
        end

        if not win or not win.Visible then
            updateStatus("Waiting for Stats HUD...", Color3.fromRGB(241, 196, 15))
            return
        end

        -- Refresh Live Stats Widget immediately with actual numbers
        if updateLiveStatsWidget then
            updateLiveStatsWidget(win)
        end

        -- 1. Rebirth Check
        local didRebirth = checkAndTriggerRebirth(win, updateStatus)
        if didRebirth then
            task.wait(0.8)
            if updateLiveStatsWidget then updateLiveStatsWidget(win) end
        end

        -- 2. Read Points & Custom TextBox
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
                    task.wait(0.1)
                    local freshAgi = getStatRow(win, "Shadow Agility")
                    if freshAgi and freshAgi.button then clickGui(freshAgi.button) end
                    task.wait(0.2)
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
                        task.wait(0.1)
                        local freshRch = getStatRow(win, "Shadow Reach")
                        if freshRch and freshRch.button then clickGui(freshRch.button) end
                        task.wait(0.2)
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
                        task.wait(0.1)
                        local freshExp = getStatRow(win, "Player Experience")
                        if freshExp and freshExp.button then clickGui(freshExp.button) end
                        task.wait(0.2)
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
                        updateStatus(string.format("Exp MAX! Adding %d overflow to Reach...", points), Color3.fromRGB(155, 89, 182))
                        setCustomAmount(customBox, points)
                        task.wait(0.1)
                        local freshRch = getStatRow(win, "Shadow Reach")
                        if freshRch and freshRch.button then clickGui(freshRch.button) end
                        task.wait(0.2)
                        if updateLiveStatsWidget then updateLiveStatsWidget(win) end
                    end
                end
            end
        else
            updateStatus("Active (Points: 0 | Monitoring)", Color3.fromRGB(230, 230, 230))
        end

        -- Clean up: Close window only if opened by script AND AutoClose is ON
        if openedByScript and AutoCloseEnabled then
            task.wait(0.15)
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
-- CONTROL UI CREATION (WITH LIVE STAT DASHBOARD)
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

    -- Main Container Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.fromOffset(275, 275)
    MainFrame.Position = UDim2.fromOffset(35, 140)
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
    StatusLabel.Size = UDim2.new(1, -20, 0, 22)
    StatusLabel.Position = UDim2.fromOffset(10, 36)
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

    -- Live Stats Dashboard Box
    local StatsCard = Instance.new("Frame", MainFrame)
    StatsCard.Size = UDim2.new(1, -20, 0, 72)
    StatsCard.Position = UDim2.fromOffset(10, 60)
    StatsCard.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
    local CardCorner = Instance.new("UICorner", StatsCard)
    CardCorner.CornerRadius = UDim.new(0, 6)
    local CardStroke = Instance.new("UIStroke", StatsCard)
    CardStroke.Color = Color3.fromRGB(35, 50, 75)
    CardStroke.Thickness = 1

    -- Row 1: Points & Agility
    local PointsText = Instance.new("TextLabel", StatsCard)
    PointsText.Size = UDim2.new(0.5, -8, 0, 16)
    PointsText.Position = UDim2.fromOffset(8, 4)
    PointsText.BackgroundTransparency = 1
    PointsText.Font = Enum.Font.GothamSemibold
    PointsText.Text = "Points: 0"
    PointsText.TextColor3 = Color3.fromRGB(241, 196, 15)
    PointsText.TextSize = 10
    PointsText.TextXAlignment = Enum.TextXAlignment.Left

    local AgiText = Instance.new("TextLabel", StatsCard)
    AgiText.Size = UDim2.new(0.5, -8, 0, 16)
    AgiText.Position = UDim2.new(0.5, 0, 0, 4)
    AgiText.BackgroundTransparency = 1
    AgiText.Font = Enum.Font.GothamSemibold
    AgiText.Text = "Agility: 0 / 200"
    AgiText.TextColor3 = Color3.fromRGB(46, 204, 113)
    AgiText.TextSize = 10
    AgiText.TextXAlignment = Enum.TextXAlignment.Left

    -- Row 2: Reach
    local ReachText = Instance.new("TextLabel", StatsCard)
    ReachText.Size = UDim2.new(1, -16, 0, 16)
    ReachText.Position = UDim2.fromOffset(8, 26)
    ReachText.BackgroundTransparency = 1
    ReachText.Font = Enum.Font.GothamSemibold
    ReachText.Text = "Reach: 0 / 800"
    ReachText.TextColor3 = Color3.fromRGB(52, 152, 219)
    ReachText.TextSize = 10
    ReachText.TextXAlignment = Enum.TextXAlignment.Left

    -- Row 3: Player Experience
    local ExpText = Instance.new("TextLabel", StatsCard)
    ExpText.Size = UDim2.new(1, -16, 0, 16)
    ExpText.Position = UDim2.fromOffset(8, 48)
    ExpText.BackgroundTransparency = 1
    ExpText.Font = Enum.Font.GothamBold
    ExpText.Text = "Player Exp: 0 / 3,075"
    ExpText.TextColor3 = Color3.fromRGB(230, 230, 230)
    ExpText.TextSize = 10
    ExpText.TextXAlignment = Enum.TextXAlignment.Left

    -- Live Stats Updater Implementation
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
            ToggleBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
            updateStatusText("Paused", Color3.fromRGB(180, 180, 180))
        end
    end
    updateToggleBtnVisual()

    ToggleBtn.MouseButton1Click:Connect(function()
        AutoRebirthEnabled = not AutoRebirthEnabled
        updateToggleBtnVisual()
    end)

    -- Auto-Close Window Toggle Button
    local AutoCloseBtn = Instance.new("TextButton", MainFrame)
    AutoCloseBtn.Size = UDim2.new(1, -20, 0, 26)
    AutoCloseBtn.Position = UDim2.fromOffset(10, 178)
    AutoCloseBtn.Font = Enum.Font.GothamSemibold
    AutoCloseBtn.TextSize = 11
    local AutoCloseCorner = Instance.new("UICorner", AutoCloseBtn)
    AutoCloseCorner.CornerRadius = UDim.new(0, 6)

    local function updateAutoCloseVisual()
        if AutoCloseEnabled then
            AutoCloseBtn.Text = "Auto-Close Window: ON"
            AutoCloseBtn.BackgroundColor3 = Color3.fromRGB(41, 128, 185)
            AutoCloseBtn.TextColor3 = Color3.new(1, 1, 1)
        else
            AutoCloseBtn.Text = "Auto-Close Window: OFF (Keep Open)"
            AutoCloseBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 95)
            AutoCloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
    updateAutoCloseVisual()

    AutoCloseBtn.MouseButton1Click:Connect(function()
        AutoCloseEnabled = not AutoCloseEnabled
        updateAutoCloseVisual()
    end)

    -- Manual Trigger Button
    local ManualBtn = Instance.new("TextButton", MainFrame)
    ManualBtn.Size = UDim2.new(1, -20, 0, 26)
    ManualBtn.Position = UDim2.fromOffset(10, 210)
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

    -- Rules Indicator Footer
    local FooterLabel = Instance.new("TextLabel", MainFrame)
    FooterLabel.Size = UDim2.new(1, -20, 0, 18)
    FooterLabel.Position = UDim2.fromOffset(10, 244)
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
print("[Auto-Rebirth] V3 loaded successfully!")
