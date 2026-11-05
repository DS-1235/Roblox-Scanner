-- ====================================================================
-- SOLO LEVELING / ANIME SHADOW: 100% BACKGROUND AUTO-REBIRTH & STAT SYSTEM (V15)
-- ====================================================================
-- 100% Windowless: Stats window NEVER opens, never flashes, never animates.
-- Uses direct memory signal execution (getconnections) to dispatch BridgeNet2.
-- ====================================================================

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Clean up any prior running UI instances
for _, name in ipairs({"NS_Rebirth", "AutoRebirthGui", "SoloRebirth_V13", "SoloRebirth_V14", "SoloRebirth_V15"}) do
    local old = playerGui:FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end

-- Allocation Targets
local TARGET_AGILITY = 200
local TARGET_REACH   = 800

-- Runtime Variables
local isRunning = true
local isProcessing = false
local rebirthCount = 0

-- --------------------------------------------------------------------
-- 1. TEXT CLEANING & MEMORY DISPATCH HELPERS
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

-- Executes a button's registered callback directly in Lua memory (Zero Screen Requirement)
local function fireButtonBackground(btn)
    if not btn then return false end
    local fired = false

    if typeof(getconnections) == "function" then
        pcall(function()
            for _, c in ipairs(getconnections(btn.Activated)) do
                if c.Function then
                    task.spawn(c.Function)
                    fired = true
                elseif c.Fire then
                    c:Fire()
                    fired = true
                end
            end
        end)
        pcall(function()
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                if c.Function then
                    task.spawn(c.Function)
                    fired = true
                elseif c.Fire then
                    c:Fire()
                    fired = true
                end
            end
        end)
    end

    if typeof(firesignal) == "function" and btn:IsA("GuiButton") then
        pcall(function() firesignal(btn.Activated); fired = true end)
        pcall(function() firesignal(btn.MouseButton1Click); fired = true end)
    end

    return fired
end

-- --------------------------------------------------------------------
-- 2. LOCATE STATS WINDOW DATA IN MEMORY (ACTIVE OR IN __DISABLE)
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
    if direct and direct.Name == "UI_Stats" and not direct:FindFirstAncestor("SoloRebirth_V15") then
        return direct
    end

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if not desc:FindFirstAncestor("SoloRebirth_V15") and desc:IsA("TextLabel") and desc.Text then
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

-- --------------------------------------------------------------------
-- 3. MAX LEVEL & CONFIRMATION DETECTORS
-- --------------------------------------------------------------------
local function isPlayerAtMaxLevel()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if not desc:FindFirstAncestor("SoloRebirth_V15") and desc:IsA("TextLabel") and desc.Text then
            local raw = desc.Text
            if string.find(raw, "%(MAX%)") or (string.find(string.upper(raw), "MAX") and string.find(string.upper(raw), "LEVEL")) then
                return true, raw
            end
        end
    end
    return false, nil
end

local function findRebirthButton(statsRoot)
    local roots = { statsRoot, playerGui }
    for _, root in ipairs(roots) do
        if root then
            for _, desc in ipairs(root:GetDescendants()) do
                if not desc:FindFirstAncestor("SoloRebirth_V15") and not desc:FindFirstAncestor("Hud") then
                    local raw = (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text or ""
                    if cleanAlpha(raw) == "REBIRTH" then
                        local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                        if btn then return btn end
                    end
                end
            end
        end
    end
    return nil
end

local function findRebirthConfirmYesButton(statsRoot)
    local roots = { statsRoot, playerGui }
    for _, root in ipairs(roots) do
        if root then
            for _, desc in ipairs(root:GetDescendants()) do
                if not desc:FindFirstAncestor("SoloRebirth_V15") and not desc:FindFirstAncestor("Hud") then
                    local rawText = (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text or ""
                    local clean = cleanAlpha(rawText)

                    if clean == "YES" or clean == "CONFIRM" then
                        local container = desc.Parent
                        local isModal = false
                        for _ = 1, 6 do
                            if not container or container == playerGui then break end
                            for _, sib in ipairs(container:GetDescendants()) do
                                if (sib:IsA("TextLabel") or sib:IsA("TextButton")) and sib.Text then
                                    local sibClean = cleanAlpha(sib.Text)
                                    if string.find(sibClean, "REBIRTH") or sibClean == "NO" then
                                        isModal = true
                                        break
                                    end
                                end
                            end
                            if isModal then break end
                            container = container.Parent
                        end

                        if isModal then
                            local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                            if btn and not string.find(string.lower(btn.Name), "no") then
                                return btn
                            end
                            return desc
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- --------------------------------------------------------------------
-- 4. POINT READING & STAT ALLOCATION HELPERS
-- --------------------------------------------------------------------
local function getAvailablePoints(statsRoot)
    if not statsRoot then return 0 end
    for _, desc in ipairs(statsRoot:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text then
            local clean = cleanAlpha(desc.Text)
            if (string.find(clean, "POINTS") or string.find(clean, "SPEND")) and not string.find(clean, "EARNED") and not string.find(clean, "SPENT") then
                local s = string.gsub(desc.Text, "[,%s]", "")
                local num = tonumber(string.match(s, "(%d+)"))
                if num and num > 0 and num < 10000000 then return num end
            end
        end
    end

    for _, desc in ipairs(statsRoot:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text then
            local s = string.gsub(desc.Text, "[,%s]", "")
            local num = tonumber(string.match(s, "^(%d+)$"))
            if num and num > 0 and num < 10000000 then return num end
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
                task.wait(0.04)
            end
            return
        end
    end
end

local function getStatRow(statsRoot, statName)
    if not statsRoot then return nil end
    local targetClean = cleanAlpha(statName)

    for _, desc in ipairs(statsRoot:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text then
            local clean = cleanAlpha(desc.Text)
            if string.find(clean, targetClean, 1, true) then
                local row = desc.Parent
                while row and row ~= statsRoot and row.Parent ~= statsRoot do
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
                local isMax = string.find(cleanAlpha(rowText), "MAX") ~= nil

                local addBtn = nil
                for _, b in ipairs(row:GetDescendants()) do
                    if b:IsA("GuiButton") then
                        local bt = cleanUpper(b.Text)
                        local bn = string.lower(b.Name)
                        if string.find(bt, "+") or string.find(bn, "add") or string.find(bn, "upg") or bt == "MAX" then
                            addBtn = b
                            break
                        end
                    end
                end

                return {
                    current = tonumber(cur) or 0,
                    max = tonumber(mx) or 3225,
                    isMax = isMax or (tonumber(cur) ~= nil and tonumber(mx) ~= nil and tonumber(cur) >= tonumber(mx)),
                    button = addBtn
                }
            end
        end
    end
    return nil
end

-- --------------------------------------------------------------------
-- 5. REBIRTH WORKFLOW (100% SILENT & BACKGROUND)
-- --------------------------------------------------------------------
local function executeBackgroundRebirth(statsRoot, updateStatus)
    local yesBtn = findRebirthConfirmYesButton(statsRoot)

    if not yesBtn then
        local rebirthBtn = findRebirthButton(statsRoot)
        if not rebirthBtn then return false end

        updateStatus("Triggering REBIRTH in Background...", Color3.fromRGB(241, 196, 15))
        fireButtonBackground(rebirthBtn)

        for _ = 1, 10 do
            task.wait(0.1)
            yesBtn = findRebirthConfirmYesButton(statsRoot)
            if yesBtn then break end
        end
    end

    if yesBtn then
        updateStatus("Confirming YES in Background...", Color3.fromRGB(46, 204, 113))
        task.wait(0.1)
        fireButtonBackground(yesBtn)

        for _ = 1, 15 do
            task.wait(0.1)
            local atMax = isPlayerAtMaxLevel()
            local stillYes = findRebirthConfirmYesButton(statsRoot)
            if not atMax or not stillYes then
                rebirthCount = rebirthCount + 1
                updateStatus(string.format("Rebirth #%d Successful! (Level Reset)", rebirthCount), Color3.fromRGB(46, 204, 113))
                task.wait(0.4)
                return true
            end
        end
        return true
    end

    return false
end

-- --------------------------------------------------------------------
-- 6. CONTROL UI
-- --------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SoloRebirth_V15"
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
title.Text = "⚡ 100% Background Auto-Rebirth (V15)"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 34)
statusLabel.Position = UDim2.fromOffset(10, 32)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Initializing Background Monitor..."
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
-- 7. BACKGROUND AUTOMATION CYCLE (ZERO UI OPENING)
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

        -- 1. Execute Background Rebirth if at Max Level
        if atMax or findRebirthConfirmYesButton(statsRoot) then
            local rebirthed = executeBackgroundRebirth(statsRoot, updateStatus)
            if rebirthed then task.wait(0.4) end
        end

        -- 2. Read Points & Stat Levels in Memory
        local points = getAvailablePoints(statsRoot)
        local agi = getStatRow(statsRoot, "Shadow Agility")
        local rch = getStatRow(statsRoot, "Shadow Reach")
        local exp = getStatRow(statsRoot, "Player Experience")
        updateStatsReadout(points, agi, rch, exp)

        -- 3. Allocate Points in Background if available
        if points > 0 then
            local function spendOnStatBackground(statTitle, targetLevel)
                local row = getStatRow(statsRoot, statTitle)
                if not row or row.isMax or row.current >= targetLevel or not row.button then return end

                local needed = targetLevel - row.current
                local toSpend = math.min(points, needed)
                if toSpend <= 0 then return end

                updateStatus(string.format("Background Spending %d on %s...", toSpend, statTitle), Color3.fromRGB(46, 204, 113))
                setCustomAmountBackground(statsRoot, toSpend)

                local attempts = 0
                while points > 0 and needed > 0 and attempts < 15 do
                    local freshRow = getStatRow(statsRoot, statTitle)
                    if not freshRow or freshRow.isMax or not freshRow.button then break end

                    fireButtonBackground(freshRow.button)
                    task.wait(0.06)

                    local newPoints = getAvailablePoints(statsRoot)
                    if newPoints == points then break end
                    local spent = points - newPoints
                    needed = needed - spent
                    points = newPoints
                    attempts = attempts + 1
                end
                updateStatsReadout(points, getStatRow(statsRoot, "Shadow Agility"), getStatRow(statsRoot, "Shadow Reach"), getStatRow(statsRoot, "Player Experience"))
            end

            -- Priority 1: Shadow Agility -> 200
            spendOnStatBackground("Shadow Agility", TARGET_AGILITY)

            -- Priority 2: Shadow Reach -> 800
            spendOnStatBackground("Shadow Reach", TARGET_REACH)

            -- Priority 3: Player Experience -> MAX
            local freshExp = getStatRow(statsRoot, "Player Experience")
            if freshExp and not freshExp.isMax then
                spendOnStatBackground("Player Experience", freshExp.max)
            end

            -- Priority 4: Overflow into Shadow Reach
            freshExp = getStatRow(statsRoot, "Player Experience")
            if freshExp and freshExp.isMax and points > 0 then
                local freshRch = getStatRow(statsRoot, "Shadow Reach")
                if freshRch and not freshRch.isMax and freshRch.button then
                    updateStatus(string.format("Exp MAX! Overflowing %d to Reach...", points), Color3.fromRGB(155, 89, 182))
                    setCustomAmountBackground(statsRoot, points)
                    local attempts = 0
                    while points > 0 and attempts < 15 do
                        local r = getStatRow(statsRoot, "Shadow Reach")
                        if not r or r.isMax or not r.button then break end

                        fireButtonBackground(r.button)
                        task.wait(0.06)

                        local newPoints = getAvailablePoints(statsRoot)
                        if newPoints == points then break end
                        points = newPoints
                        attempts = attempts + 1
                    end
                end
            end
        else
            updateStatus("Active (Background Monitoring)", Color3.fromRGB(230, 230, 230))
        end
    end)

    if not success and err then
        warn("[BgRebirth Error]: " .. tostring(err))
    end
    isProcessing = false
end

-- --------------------------------------------------------------------
-- 8. BUTTON CONTROLS & MONITOR THREAD
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

-- Calm 1.5s background interval: No UI opening, no CPU spikes, zero tween glitching
task.spawn(function()
    while gui and gui.Parent do
        if isRunning then
            runBackgroundCycle()
        end
        task.wait(1.5)
    end
end)

print("[SoloRebirth V15] 100% Background Auto-Rebirth & Stat Allocation Initialized!")
