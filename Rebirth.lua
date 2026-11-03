local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- -------------------------------------------------------------
-- Configuration
-- -------------------------------------------------------------
local TARGET_AGILITY = 200   -- First target: 200 Shadow Agility
local TARGET_REACH   = 800   -- Second target: 800 Shadow Reach
local CHECK_INTERVAL = 2.5   -- How often to check for rebirth / stat points (seconds)

-- -------------------------------------------------------------
-- Helper: Safe Headless Click (Zero Cursor Movement)
-- -------------------------------------------------------------
local function click(b)
    if not b or typeof(firesignal) ~= "function" then return end
    pcall(firesignal, b.Activated)
    pcall(firesignal, b.MouseButton1Click)
    pcall(firesignal, b.MouseButton1Up)
    for _, ch in ipairs(b:GetChildren()) do
        if ch:IsA("GuiButton") or ch:IsA("TextLabel") then
            pcall(firesignal, ch.Activated)
        end
    end
end

-- -------------------------------------------------------------
-- Helper: Find Stats Window (Handles Menus & __Disable)
-- -------------------------------------------------------------
local function getStatsWindow()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text == "Stats" then
            local parent = desc.Parent
            while parent and parent ~= playerGui do
                if parent:FindFirstChild("Talents", true) or parent:FindFirstChild("REBIRTH", true) or parent:FindFirstChild("Shadow Power", true) then
                    return parent
                end
                parent = parent.Parent
            end
        end
    end
    return nil
end

-- -------------------------------------------------------------
-- Helper: Ensure Stats UI is Accessible Invisibly
-- -------------------------------------------------------------
local function openStatsInvisibly()
    local win = getStatsWindow()
    if win and win.Visible then return win, false end

    -- Locate the hex "Stats" button on the HUD (Image 1)
    local hudStatsBtn = nil
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Visible then
            local clean = string.upper(string.gsub(desc.Text, "<[^>]+>", ""))
            if clean == "STATS" then
                local b = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                if b and b.Visible then
                    hudStatsBtn = b
                    break
                end
            end
        end
    end

    if hudStatsBtn then
        click(hudStatsBtn)
        task.wait(0.3)
        win = getStatsWindow()
        if win then
            -- Keep off-screen so the player never sees it
            if win:IsA("GuiObject") then
                win.Position = UDim2.fromOffset(-9999, -9999)
            end
            return win, true
        end
    end
    return win, false
end

local function closeStatsInvisibly()
    local win = getStatsWindow()
    if win then
        for _, desc in ipairs(win:GetDescendants()) do
            if desc:IsA("TextButton") and (desc.Text == "X" or string.find(string.lower(desc.Name), "close")) then
                click(desc)
                return
            end
        end
    end
end

-- -------------------------------------------------------------
-- Helper: Find Custom Amount TextBox (Near Talents Button)
-- -------------------------------------------------------------
local function getCustomAmountBox(win)
    if not win then return nil end
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextBox") then
            return desc
        end
    end
    return nil
end

local function setCustomAmount(box, amount)
    if not box then return end
    box.Text = tostring(amount)
    pcall(function() firesignal(box.FocusLost, true) end)
    task.wait(0.12)
end

-- -------------------------------------------------------------
-- Helper: Read Available Points To Spend
-- -------------------------------------------------------------
local function getPointsToSpend(win)
    if not win then return 0 end
    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and desc.Text ~= "" then
            local clean = string.upper(desc.Text)
            if string.find(clean, "POINTS TO SPEND") then
                local parent = desc.Parent
                if parent then
                    for _, sib in ipairs(parent:GetChildren()) do
                        if sib ~= desc and sib:IsA("TextLabel") and tonumber(sib.Text) then
                            return tonumber(sib.Text)
                        end
                    end
                    for _, child in ipairs(parent:GetDescendants()) do
                        if child ~= desc and child:IsA("TextLabel") and tonumber(child.Text) then
                            return tonumber(child.Text)
                        end
                    end
                end
            end
        end
    end
    return 0
end

-- -------------------------------------------------------------
-- Helper: Find Stat Row, Current Level, Max, and "+" Button
-- -------------------------------------------------------------
local function getStatRowInfo(win, statName)
    if not win then return nil, 0, 2850, false end
    local upperTarget = string.upper(statName)

    for _, desc in ipairs(win:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and string.find(string.upper(desc.Text), upperTarget, 1, true) then
            local row = desc.Parent
            local depth = 0
            while row and row ~= win and depth < 5 do
                local curLv, maxLv = 0, 2850
                local addBtn = nil
                local isMax = false

                for _, child in ipairs(row:GetDescendants()) do
                    -- Parse "Lv 200 / 2,850"
                    if child:IsA("TextLabel") and child.Text and string.find(string.upper(child.Text), "LV") then
                        local clean = string.gsub(child.Text, ",", "")
                        local cur, mx = string.match(clean, "(%d+)%s*/%s*(%d+)")
                        if cur and mx then
                            curLv = tonumber(cur)
                            maxLv = tonumber(mx)
                        end
                    end

                    -- Locate the green Add/Max Button on the right
                    if child:IsA("GuiButton") and child.Visible then
                        addBtn = child
                    elseif child:IsA("TextLabel") and child.Text then
                        if string.find(string.upper(child.Text), "MAX") then
                            isMax = true
                        end
                    end
                end

                if addBtn then
                    return addBtn, curLv, maxLv, isMax
                end

                row = row.Parent
                depth += 1
            end
        end
    end
    return nil, 0, 2850, false
end

-- -------------------------------------------------------------
-- Helper: Check & Trigger Rebirth
-- -------------------------------------------------------------
local function checkAndTriggerRebirth(win)
    if not win then return false end
    for _, desc in ipairs(win:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and desc.Visible then
            if string.upper(desc.Text) == "REBIRTH" then
                local b = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                if b and b.Visible and b.AbsoluteSize.X > 0 then
                    print("[Auto-Rebirth] Max level reached! Clicking REBIRTH...")
                    click(b)
                    task.wait(0.4)

                    -- Check for confirmation popup
                    for _, p in ipairs(playerGui:GetDescendants()) do
                        if (p:IsA("TextLabel") or p:IsA("TextButton")) and p.Text and p.Visible then
                            local u = string.upper(p.Text)
                            if u == "YES" or u == "CONFIRM" or u == "REBIRTH" or u == "OK" then
                                local cb = p:IsA("GuiButton") and p or p:FindFirstAncestorWhichIsA("GuiButton")
                                if cb and cb.Visible then
                                    click(cb)
                                    print("[Auto-Rebirth] Confirmed Rebirth popup!")
                                    task.wait(0.6)
                                    return true
                                end
                            end
                        end
                    end
                    return true
                end
            end
        end
    end
    return false
end

-- -------------------------------------------------------------
-- Main Automation Loop
-- -------------------------------------------------------------
task.spawn(function()
    print("[Auto-Rebirth] System initialized. Running invisibly in background...")

    while true do
        task.wait(CHECK_INTERVAL)

        pcall(function()
            local win, openedByScript = openStatsInvisibly()
            if not win then return end

            -- 1. Check if Rebirth is ready (Max Level reached)
            local rebirthed = checkAndTriggerRebirth(win)
            if rebirthed then
                task.wait(0.8) -- Settle after rebirth reset
            end

            -- 2. Read available Stat Points
            local points = getPointsToSpend(win)
            local customBox = getCustomAmountBox(win)

            if points > 0 and customBox then
                print(string.format("[Auto-Stats] Points to spend: %d", points))

                -- Priority 1: Shadow Agility (Target 200)
                local agiBtn, agiCur, agiMax, agiIsMax = getStatRowInfo(win, "Shadow Agility")
                if agiBtn and not agiIsMax and agiCur < TARGET_AGILITY then
                    local needed = TARGET_AGILITY - agiCur
                    local toSpend = math.min(points, needed)
                    if toSpend > 0 then
                        print(string.format("[Auto-Stats] Adding %d to Shadow Agility (Current: %d/%d)...", toSpend, agiCur, TARGET_AGILITY))
                        setCustomAmount(customBox, toSpend)
                        click(agiBtn)
                        task.wait(0.2)
                        points = points - toSpend
                    end
                end

                -- Priority 2: Shadow Reach (Target 800)
                if points > 0 then
                    local rchBtn, rchCur, rchMax, rchIsMax = getStatRowInfo(win, "Shadow Reach")
                    if rchBtn and not rchIsMax and rchCur < TARGET_REACH then
                        local needed = TARGET_REACH - rchCur
                        local toSpend = math.min(points, needed)
                        if toSpend > 0 then
                            print(string.format("[Auto-Stats] Adding %d to Shadow Reach (Current: %d/%d)...", toSpend, rchCur, TARGET_REACH))
                            setCustomAmount(customBox, toSpend)
                            click(rchBtn)
                            task.wait(0.2)
                            points = points - toSpend
                        end
                    end
                end

                -- Priority 3: Player Experience (Target MAX: 2,850)
                if points > 0 then
                    local expBtn, expCur, expMax, expIsMax = getStatRowInfo(win, "Player Experience")
                    if expBtn and not expIsMax and expCur < expMax then
                        local needed = expMax - expCur
                        local toSpend = math.min(points, needed)
                        if toSpend > 0 then
                            print(string.format("[Auto-Stats] Adding %d to Player Experience (Current: %d/%d)...", toSpend, expCur, expMax))
                            setCustomAmount(customBox, toSpend)
                            click(expBtn)
                            task.wait(0.2)
                            points = points - toSpend
                        end
                    end
                end

                -- Overflow: If Player Experience is MAX and points remain, feed into Shadow Reach
                if points > 0 then
                    local rchBtn, rchCur, rchMax, rchIsMax = getStatRowInfo(win, "Shadow Reach")
                    if rchBtn and not rchIsMax and rchCur < rchMax then
                        print(string.format("[Auto-Stats] Player Exp is MAX! Feeding remaining %d points into Shadow Reach...", points))
                        setCustomAmount(customBox, points)
                        click(rchBtn)
                        task.wait(0.2)
                    end
                end
            end

            -- 3. Clean up and close invisible window
            if openedByScript then
                closeStatsInvisibly()
            end
        end)
    end
end)
