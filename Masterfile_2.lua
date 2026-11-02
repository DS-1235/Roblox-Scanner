local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local DUNGEON_INTERVAL  = 0.6  -- Settle delay for menu stages
local COMBAT_INTERVAL   = 0.5  -- Interval for combat teleporting
local CLEAR_DELAY       = 2.0  -- Delay after room clear before going through door
local STEP_DISTANCE     = 90   -- Studs to jump forward into next room

local oldGui = playerGui:FindFirstChild("NS_MasterAutomation")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "NS_MasterAutomation"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(310, 360)
frame.Position = UDim2.new(0.5, -155, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true

-- Title & Close
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -35, 0, 30)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 13
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Dungeon QA, Combat & Door Master"

local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.fromOffset(25, 25)
closeBtn.Position = UDim2.new(1, -28, 0, 3)
closeBtn.Text = "X"
closeBtn.TextSize = 12
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.BorderSizePixel = 0

local masterBtn = Instance.new("TextButton", frame)
masterBtn.Size = UDim2.new(1, -20, 0, 32)
masterBtn.Position = UDim2.fromOffset(10, 30)
masterBtn.Text = "START ALL (Full Autonomous Loop)"
masterBtn.TextSize = 13
masterBtn.Font = Enum.Font.SourceSansBold
masterBtn.TextColor3 = Color3.new(1, 1, 1)
masterBtn.BackgroundColor3 = Color3.fromRGB(38, 140, 75)
masterBtn.BorderSizePixel = 0

-- UI Section Helper
local function createSection(yPos, titleText, color)
    local box = Instance.new("Frame", frame)
    box.Size = UDim2.new(1, -20, 0, 85)
    box.Position = UDim2.fromOffset(10, yPos)
    box.BackgroundColor3 = Color3.fromRGB(32, 38, 52)
    box.BorderSizePixel = 0

    local t = Instance.new("TextLabel", box)
    t.Size = UDim2.new(1, -85, 0, 20)
    t.Position = UDim2.fromOffset(6, 4)
    t.BackgroundTransparency = 1
    t.TextColor3 = color
    t.TextSize = 12
    t.Font = Enum.Font.SourceSansBold
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = titleText

    local btn = Instance.new("TextButton", box)
    btn.Size = UDim2.fromOffset(72, 22)
    btn.Position = UDim2.new(1, -78, 0, 4)
    btn.Text = "START"
    btn.TextSize = 11
    btn.Font = Enum.Font.SourceSansBold
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BackgroundColor3 = Color3.fromRGB(55, 65, 88)
    btn.BorderSizePixel = 0

    local stat = Instance.new("TextLabel", box)
    stat.Size = UDim2.new(1, -12, 0, 55)
    stat.Position = UDim2.fromOffset(6, 26)
    stat.BackgroundTransparency = 1
    stat.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    stat.TextSize = 11
    stat.TextWrapped = true
    stat.TextXAlignment = Enum.TextXAlignment.Left
    stat.TextYAlignment = Enum.TextYAlignment.Top
    stat.Text = "Status: Idle"

    return box, btn, stat
end

local _, dungeonToggle, dungeonStatus = createSection(68, "1. Dungeon Loop (Stages 1-3)", Color3.fromRGB(130, 200, 255))
local _, combatToggle, combatStatus   = createSection(160, "2. Combat Scanner (0.5s)", Color3.fromRGB(255, 150, 130))
local _, doorToggle, doorStatus       = createSection(252, "3. Door / Room Forwarder (2s)", Color3.fromRGB(140, 240, 180))

-- State
local alive = true
local dungeonActive = false
local combatActive = false
local doorActive = false
local dungeonBusy = false
local hadEnemiesInRoom = false
local clearTimerStart = nil
local forwardJumps = 0

-- Helpers
local function isVisible(obj)
    if not obj or not obj:IsDescendantOf(playerGui) then return false end
    local cur = obj
    while cur and cur ~= playerGui do
        if cur.Name == "__Disable" then return false end
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("LayerCollector") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0
end

local function clickButton(b)
    if not b then return end
    if typeof(firesignal) == "function" then
        pcall(function() firesignal(b.Activated) end)
        pcall(function() firesignal(b.MouseButton1Click) end)
    else
        local inset = GuiService:GetGuiInset()
        local cx = b.AbsolutePosition.X + (b.AbsoluteSize.X / 2)
        local cy = b.AbsolutePosition.Y + (b.AbsoluteSize.Y / 2) + inset.Y
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.wait(0.04)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end
end

local function getPaCols()
    local menus = playerGui:FindFirstChild("Menus")
    local uiParty = menus and menus:FindFirstChild("UI_Party")
    return uiParty and uiParty:FindFirstChild("pa_cols", true)
end

local function findButtonWithText(container, matchText)
    if not container then return nil end
    local upperMatch = string.upper(matchText)
    for _, desc in ipairs(container:GetDescendants()) do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text and string.find(string.upper(desc.Text), upperMatch, 1, true) then
            local cur = desc
            while cur and cur ~= container do
                if cur:IsA("GuiButton") then return cur end
                cur = cur.Parent
            end
        end
    end
    return nil
end

local function getEnemiesFolder()
    local main = workspace:FindFirstChild("__Main")
    local enemies = main and main:FindFirstChild("__Enemies")
    return enemies and enemies:FindFirstChild("Client")
end

local function getAliveEnemyCount()
    local folder = getEnemiesFolder()
    if not folder then return 0 end
    local c = 0
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChild("HumanoidRootPart", true) and m:FindFirstChild("Hitbox", true) then
            c += 1
        end
    end
    return c
end

-- 1. Dungeon Loop Step
local function stepDungeon()
    if dungeonBusy or not dungeonActive then return end
    dungeonBusy = true
    pcall(function()
        local paCols = getPaCols()
        if not paCols then return end

        local completed = paCols:FindFirstChild("completed")
        local listPane = paCols:FindFirstChild("list")
        local leaderPane = paCols:FindFirstChild("leader") or paCols:FindFirstChild("wave")

        if completed and isVisible(completed) then
            local opts = completed:FindFirstChild("pa_opts", true)
            local gemsBtn = nil
            if opts then
                for _, opt in ipairs(opts:GetChildren()) do
                    local head = opt:FindFirstChild("NUI_Head", true)
                    if head and head:IsA("TextLabel") and string.find(string.upper(head.Text), "PAY WITH GEMS", 1, true) then
                        gemsBtn = opt:FindFirstChild("price_btn", true)
                        break
                    end
                end
            end
            if gemsBtn and isVisible(gemsBtn) then
                dungeonStatus.Text = "Stage 1: Paying with Gems..."
                task.wait(DUNGEON_INTERVAL)
                clickButton(gemsBtn)
                task.wait(DUNGEON_INTERVAL)
            end
            return
        end

        if listPane and isVisible(listPane) then
            local foot = listPane:FindFirstChild("pa_foot", true)
            local createBtn = (foot and foot:FindFirstChild("btn", true)) or findButtonWithText(listPane, "CREATE PARTY")
            if createBtn and isVisible(createBtn) then
                dungeonStatus.Text = "Stage 2: Creating Party..."
                task.wait(DUNGEON_INTERVAL)
                clickButton(createBtn)
                task.wait(DUNGEON_INTERVAL)
            end
            return
        end

        if leaderPane and isVisible(leaderPane) then
            local paStart = leaderPane:FindFirstChild("pa_start", true)
            local paGo = paStart and paStart:FindFirstChild("pa_go", true)
            local startBtn = (paGo and paGo:FindFirstChild("btn", true)) or findButtonWithText(leaderPane, "START")
            if startBtn and isVisible(startBtn) then
                dungeonStatus.Text = "Stage 3: Starting Dungeon..."
                task.wait(DUNGEON_INTERVAL)
                clickButton(startBtn)
                task.wait(DUNGEON_INTERVAL)
                dungeonStatus.Text = "Dungeon launched! In progress."
            end
            return
        end
        dungeonStatus.Text = "In Dungeon Run"
    end)
    dungeonBusy = false
end

-- 2. Combat Scanner Step
local function stepCombat()
    if not combatActive then return end
    local char = player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local folder = getEnemiesFolder()
    if not myRoot or not folder then return end

    local nearestRoot, nearestDist, nearestModel, count = nil, math.huge, nil, 0
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") then
            local r = m:FindFirstChild("HumanoidRootPart", true)
            local h = m:FindFirstChild("Hitbox", true)
            if r and r:IsA("BasePart") and h and h:IsA("BasePart") then
                count += 1
                local d = (myRoot.Position - r.Position).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearestRoot = r
                    nearestModel = m
                end
            end
        end
    end

    if nearestRoot and nearestModel then
        local dest = nearestRoot.Position + nearestRoot.CFrame.LookVector * 5 + Vector3.new(0, 2, 0)
        char:PivotTo(CFrame.lookAt(dest, nearestRoot.Position))
        combatStatus.Text = string.format("Target: %s (Alive: %d)\nDist: %.1f studs", nearestModel.Name, count, nearestDist)
    else
        combatStatus.Text = string.format("No targets found (Alive: %d)", count)
    end
end

-- 3. Door Forwarder Step
local function stepDoor()
    if not doorActive then return end
    local char = player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local count = getAliveEnemyCount()
    if count > 0 then
        hadEnemiesInRoom = true
        clearTimerStart = nil
        doorStatus.Text = string.format("Fighting (Door Closed)\nEnemies alive: %d", count)
    else
        if hadEnemiesInRoom then
            if not clearTimerStart then clearTimerStart = tick() end
            local rem = math.max(0, CLEAR_DELAY - (tick() - clearTimerStart))
            if rem > 0 then
                doorStatus.Text = string.format("Room Clear! Door Opening...\nMoving in: %.1fs", rem)
            else
                doorStatus.Text = "Teleporting through door..."
                char:PivotTo(myRoot.CFrame + (myRoot.CFrame.LookVector * STEP_DISTANCE) + Vector3.new(0, 2, 0))
                forwardJumps += 1
                hadEnemiesInRoom = false
                clearTimerStart = nil
                doorStatus.Text = string.format("Jumped to Next Room (#%d)", forwardJumps)
                task.wait(1.0)
            end
        else
            doorStatus.Text = string.format("Searching for room/enemies...\nJumps taken: %d", forwardJumps)
            if not clearTimerStart then clearTimerStart = tick() end
            if (tick() - clearTimerStart) >= (CLEAR_DELAY + 0.5) then
                char:PivotTo(myRoot.CFrame + (myRoot.CFrame.LookVector * STEP_DISTANCE) + Vector3.new(0, 2, 0))
                forwardJumps += 1
                clearTimerStart = nil
                doorStatus.Text = string.format("Stepped Forward (#%d)", forwardJumps)
                task.wait(1.0)
            end
        end
    end
end

-- UI Toggle Handlers
local function updateToggles()
    dungeonToggle.Text = dungeonActive and "STOP" or "START"
    dungeonToggle.BackgroundColor3 = dungeonActive and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(55, 65, 88)
    combatToggle.Text = combatActive and "STOP" or "START"
    combatToggle.BackgroundColor3 = combatActive and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(55, 65, 88)
    doorToggle.Text = doorActive and "STOP" or "START"
    doorToggle.BackgroundColor3 = doorActive and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(55, 65, 88)

    local allOn = dungeonActive and combatActive and doorActive
    masterBtn.Text = allOn and "STOP ALL" or "START ALL (Full Autonomous Loop)"
    masterBtn.BackgroundColor3 = allOn and Color3.fromRGB(180, 45, 45) or Color3.fromRGB(38, 140, 75)
end

dungeonToggle.MouseButton1Click:Connect(function() dungeonActive = not dungeonActive; updateToggles() end)
combatToggle.MouseButton1Click:Connect(function() combatActive = not combatActive; updateToggles() end)
doorToggle.MouseButton1Click:Connect(function() doorActive = not doorActive; updateToggles() end)

masterBtn.MouseButton1Click:Connect(function()
    local target = not (dungeonActive and combatActive and doorActive)
    dungeonActive, combatActive, doorActive = target, target, target
    updateToggles()
end)

closeBtn.MouseButton1Click:Connect(function()
    alive = false
    gui:Destroy()
end)

-- Background Loops
task.spawn(function()
    while alive and gui.Parent do
        task.wait(DUNGEON_INTERVAL)
        if alive and dungeonActive then stepDungeon() end
    end
end)

task.spawn(function()
    while alive and gui.Parent do
        task.wait(COMBAT_INTERVAL)
        if alive and combatActive then stepCombat() end
    end
end)

task.spawn(function()
    while alive and gui.Parent do
        task.wait(0.25)
        if alive and doorActive then stepDoor() end
    end
end)
