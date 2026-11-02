local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- -------------------------------------------------------------
-- Default Timing & Settings (Editable live from UI)
-- -------------------------------------------------------------
local DUNGEON_INTERVAL  = 0.6  -- Settle delay for menu clicks (Stages 1-3)
local COMBAT_INTERVAL   = 0.5  -- Scan interval for enemy teleporting
local CLEAR_DELAY       = 2.0  -- Delay after room clear before moving to next room
local STEP_DISTANCE     = 90   -- Fallback jump distance if no room model is found

-- -------------------------------------------------------------
-- Clean up existing Master UI
-- -------------------------------------------------------------
local oldGui = playerGui:FindFirstChild("NS_MasterAutomation")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "NS_MasterAutomation"
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = playerGui

-- -------------------------------------------------------------
-- Main Draggable Window (Supports Minimize)
-- -------------------------------------------------------------
local EXPANDED_HEIGHT = 465
local MINIMIZED_HEIGHT = 32

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(320, EXPANDED_HEIGHT)
frame.Position = UDim2.new(0.5, -160, 0.15, 0)
frame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.Active = true
frame.Draggable = true

-- Title Bar
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -65, 0, 30)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 13
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "QA, Combat & Room Master"

-- Minimize Button [-] / [+]
local minBtn = Instance.new("TextButton", frame)
minBtn.Size = UDim2.fromOffset(24, 24)
minBtn.Position = UDim2.new(1, -55, 0, 3)
minBtn.Text = "-"
minBtn.TextSize = 14
minBtn.Font = Enum.Font.SourceSansBold
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 95)
minBtn.BorderSizePixel = 0

-- Close Button [X]
local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.fromOffset(24, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 3)
closeBtn.Text = "X"
closeBtn.TextSize = 12
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.BorderSizePixel = 0

-- Master [START ALL] Button
local masterBtn = Instance.new("TextButton", frame)
masterBtn.Size = UDim2.new(1, -20, 0, 30)
masterBtn.Position = UDim2.fromOffset(10, 34)
masterBtn.Text = "START ALL (Autonomous Loop)"
masterBtn.TextSize = 12
masterBtn.Font = Enum.Font.SourceSansBold
masterBtn.TextColor3 = Color3.new(1, 1, 1)
masterBtn.BackgroundColor3 = Color3.fromRGB(38, 140, 75)
masterBtn.BorderSizePixel = 0

-- Helper to create module sections
local function createSection(yPos, titleText, color)
    local box = Instance.new("Frame", frame)
    box.Size = UDim2.new(1, -20, 0, 75)
    box.Position = UDim2.fromOffset(10, yPos)
    box.BackgroundColor3 = Color3.fromRGB(32, 38, 52)
    box.BorderSizePixel = 0

    local t = Instance.new("TextLabel", box)
    t.Size = UDim2.new(1, -85, 0, 20)
    t.Position = UDim2.fromOffset(6, 4)
    t.BackgroundTransparency = 1
    t.TextColor3 = color
    t.TextSize = 11
    t.Font = Enum.Font.SourceSansBold
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = titleText

    local btn = Instance.new("TextButton", box)
    btn.Size = UDim2.fromOffset(72, 20)
    btn.Position = UDim2.new(1, -78, 0, 4)
    btn.Text = "START"
    btn.TextSize = 11
    btn.Font = Enum.Font.SourceSansBold
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BackgroundColor3 = Color3.fromRGB(55, 65, 88)
    btn.BorderSizePixel = 0

    local stat = Instance.new("TextLabel", box)
    stat.Size = UDim2.new(1, -12, 0, 48)
    stat.Position = UDim2.fromOffset(6, 24)
    stat.BackgroundTransparency = 1
    stat.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    stat.TextSize = 10
    stat.TextWrapped = true
    stat.TextXAlignment = Enum.TextXAlignment.Left
    stat.TextYAlignment = Enum.TextYAlignment.Top
    stat.Text = "Status: Idle"

    return box, btn, stat
end

local _, dungeonToggle, dungeonStatus = createSection(68, "1. Dungeon Loop (Stages 1-3)", Color3.fromRGB(130, 200, 255))
local _, combatToggle, combatStatus   = createSection(147, "2. Combat Scanner", Color3.fromRGB(255, 150, 130))
local _, roomToggle, roomStatus       = createSection(226, "3. Next Room Navigator (Sol. 1)", Color3.fromRGB(140, 240, 180))

-- -------------------------------------------------------------
-- Section 4: Live Delay Inputs
-- -------------------------------------------------------------
local settingsBox = Instance.new("Frame", frame)
settingsBox.Size = UDim2.new(1, -20, 0, 150)
settingsBox.Position = UDim2.fromOffset(10, 305)
settingsBox.BackgroundColor3 = Color3.fromRGB(28, 33, 46)
settingsBox.BorderSizePixel = 0

local setHeader = Instance.new("TextLabel", settingsBox)
setHeader.Size = UDim2.new(1, -10, 0, 20)
setHeader.Position = UDim2.fromOffset(6, 4)
setHeader.BackgroundTransparency = 1
setHeader.TextColor3 = Color3.fromRGB(255, 215, 0)
setHeader.TextSize = 11
setHeader.Font = Enum.Font.SourceSansBold
setHeader.TextXAlignment = Enum.TextXAlignment.Left
setHeader.Text = "Timing & Delays (Click to Edit)"

local function createSettingInput(yPos, labelText, defaultVal)
    local lbl = Instance.new("TextLabel", settingsBox)
    lbl.Size = UDim2.new(1, -80, 0, 22)
    lbl.Position = UDim2.fromOffset(6, yPos)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(0.85, 0.85, 0.85)
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = labelText

    local box = Instance.new("TextBox", settingsBox)
    box.Size = UDim2.fromOffset(65, 22)
    box.Position = UDim2.new(1, -72, 0, yPos)
    box.Text = tostring(defaultVal)
    box.TextSize = 11
    box.Font = Enum.Font.SourceSansBold
    box.TextColor3 = Color3.new(1, 1, 1)
    box.BackgroundColor3 = Color3.fromRGB(45, 52, 70)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false

    return box
end

local dungeonInput = createSettingInput(28, "Dungeon Menu Delay (s):", DUNGEON_INTERVAL)
local combatInput  = createSettingInput(56, "Combat Interval (s):", COMBAT_INTERVAL)
local doorInput    = createSettingInput(84, "Door Clear Delay (s):", CLEAR_DELAY)
local stepInput    = createSettingInput(112, "Fallback Step (studs):", STEP_DISTANCE)

-- Hook up live input changes
dungeonInput.FocusLost:Connect(function()
    local val = tonumber(dungeonInput.Text)
    if val and val > 0 then
        DUNGEON_INTERVAL = val
    else
        dungeonInput.Text = tostring(DUNGEON_INTERVAL)
    end
end)

combatInput.FocusLost:Connect(function()
    local val = tonumber(combatInput.Text)
    if val and val > 0 then
        COMBAT_INTERVAL = val
    else
        combatInput.Text = tostring(COMBAT_INTERVAL)
    end
end)

doorInput.FocusLost:Connect(function()
    local val = tonumber(doorInput.Text)
    if val and val >= 0 then
        CLEAR_DELAY = val
    else
        doorInput.Text = tostring(CLEAR_DELAY)
    end
end)

stepInput.FocusLost:Connect(function()
    local val = tonumber(stepInput.Text)
    if val and val > 0 then
        STEP_DISTANCE = val
    else
        stepInput.Text = tostring(STEP_DISTANCE)
    end
end)

-- -------------------------------------------------------------
-- State Variables
-- -------------------------------------------------------------
local alive = true
local isMinimized = false
local dungeonActive = false
local combatActive = false
local roomActive = false
local dungeonBusy = false

local currentRoomIndex = 1
local hadEnemiesInRoom = false
local clearTimerStart = nil

-- -------------------------------------------------------------
-- Minimize / Restore Toggle
-- -------------------------------------------------------------
minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        minBtn.Text = "+"
        frame.Size = UDim2.fromOffset(320, MINIMIZED_HEIGHT)
    else
        minBtn.Text = "-"
        frame.Size = UDim2.fromOffset(320, EXPANDED_HEIGHT)
    end
end)

-- -------------------------------------------------------------
-- Shared Helpers
-- -------------------------------------------------------------
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
        for _, ch in ipairs(b:GetChildren()) do
            if ch:IsA("GuiButton") or ch:IsA("TextLabel") then
                pcall(function() firesignal(ch.Activated) end)
            end
        end
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

-- -------------------------------------------------------------
-- Solution 1: Room Model & Anchor Resolver
-- -------------------------------------------------------------
local function getRoomsContainer()
    local main = workspace:FindFirstChild("__Main")
    if main then
        local r = main:FindFirstChild("__Rooms") or main:FindFirstChild("Rooms") or main:FindFirstChild("__Map") or main:FindFirstChild("Map") or main:FindFirstChild("Floors")
        if r then return r end
    end
    return workspace:FindFirstChild("Rooms") or workspace:FindFirstChild("Map") or workspace:FindFirstChild("Dungeon")
end

local function findRoomModel(index)
    local container = getRoomsContainer()
    local searchNames = {
        "Room" .. index,
        "Room " .. index,
        "Room_" .. index,
        "Floor" .. index,
        "Floor " .. index,
        "Stage" .. index,
        tostring(index)
    }

    if container then
        for _, name in ipairs(searchNames) do
            local found = container:FindFirstChild(name)
            if found and found:IsA("Model") then return found end
        end
        -- Fallback: check by child index if sorted
        local children = container:GetChildren()
        if children[index] and children[index]:IsA("Model") then
            return children[index]
        end
    end

    -- Check direct workspace models
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            for _, name in ipairs(searchNames) do
                if obj.Name == name then return obj end
            end
        end
    end
    return nil
end

local function getRoomTargetCFrame(roomModel)
    if not roomModel then return nil end
    local anchorNames = {"Entrance", "Spawn", "Start", "Door", "Center", "Checkpoint"}
    for _, name in ipairs(anchorNames) do
        local anchor = roomModel:FindFirstChild(name, true)
        if anchor and anchor:IsA("BasePart") then
            return anchor.CFrame + Vector3.new(0, 3, 0)
        end
    end
    if roomModel.PrimaryPart then
        return roomModel.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
    end
    for _, desc in ipairs(roomModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            return desc.CFrame + Vector3.new(0, 3, 0)
        end
    end
    return nil
end

-- -------------------------------------------------------------
-- Module 1: Dungeon Loop (Stages 1-3)
-- -------------------------------------------------------------
local function stepDungeon()
    if dungeonBusy or not dungeonActive then return end
    dungeonBusy = true

    pcall(function()
        local paCols = getPaCols()
        if not paCols then return end

        local completed = paCols:FindFirstChild("completed")
        local listPane = paCols:FindFirstChild("list")
        local leaderPane = paCols:FindFirstChild("leader") or paCols:FindFirstChild("wave")

        -- Stage 1: Pay with Gems
        if completed and isVisible(completed) then
            currentRoomIndex = 1 -- Reset room count for next run
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

        -- Stage 2: Create Party
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

        -- Stage 3: Start Party
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

-- -------------------------------------------------------------
-- Module 2: Combat Teleport Step
-- -------------------------------------------------------------
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

-- -------------------------------------------------------------
-- Module 3: Solution 1 Room / Anchor Navigator
-- -------------------------------------------------------------
local function stepRoom()
    if not roomActive then return end
    local char = player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local count = getAliveEnemyCount()
    if count > 0 then
        hadEnemiesInRoom = true
        clearTimerStart = nil
        roomStatus.Text = string.format("Fighting Room %d\nEnemies alive: %d (Door Closed)", currentRoomIndex, count)
    else
        if hadEnemiesInRoom then
            if not clearTimerStart then clearTimerStart = tick() end
            local rem = math.max(0, CLEAR_DELAY - (tick() - clearTimerStart))
            if rem > 0 then
                roomStatus.Text = string.format("Room %d Cleared! Door Opening...\nMoving in: %.1fs", currentRoomIndex, rem)
            else
                roomStatus.Text = "Navigating to Next Room..."
                local nextIndex = currentRoomIndex + 1
                local nextRoomModel = findRoomModel(nextIndex)
                local targetCFrame = getRoomTargetCFrame(nextRoomModel)

                if targetCFrame then
                    -- Direct Room Anchor Teleport (Zig-Zag proof)
                    char:PivotTo(targetCFrame)
                    currentRoomIndex = nextIndex
                    roomStatus.Text = string.format("Teleported to Room %d (Anchor)", currentRoomIndex)
                else
                    -- Fallback: Step forward through doorway
                    char:PivotTo(myRoot.CFrame + (myRoot.CFrame.LookVector * STEP_DISTANCE) + Vector3.new(0, 2, 0))
                    currentRoomIndex = nextIndex
                    roomStatus.Text = string.format("Stepped forward to Room %d", currentRoomIndex)
                end

                hadEnemiesInRoom = false
                clearTimerStart = nil
                task.wait(1.0)
            end
        else
            roomStatus.Text = string.format("Waiting in Room %d / Streaming...", currentRoomIndex)
            if not clearTimerStart then clearTimerStart = tick() end
            if (tick() - clearTimerStart) >= (CLEAR_DELAY + 1.0) then
                -- Scout step if standing empty for too long
                local nextRoomModel = findRoomModel(currentRoomIndex + 1)
                local targetCFrame = getRoomTargetCFrame(nextRoomModel)
                if targetCFrame then
                    char:PivotTo(targetCFrame)
                    currentRoomIndex += 1
                else
                    char:PivotTo(myRoot.CFrame + (myRoot.CFrame.LookVector * STEP_DISTANCE) + Vector3.new(0, 2, 0))
                end
                clearTimerStart = nil
                task.wait(1.0)
            end
        end
    end
end

-- -------------------------------------------------------------
-- Toggle Sync
-- -------------------------------------------------------------
local function updateToggles()
    dungeonToggle.Text = dungeonActive and "STOP" or "START"
    dungeonToggle.BackgroundColor3 = dungeonActive and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(55, 65, 88)
    combatToggle.Text = combatActive and "STOP" or "START"
    combatToggle.BackgroundColor3 = combatActive and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(55, 65, 88)
    roomToggle.Text = roomActive and "STOP" or "START"
    roomToggle.BackgroundColor3 = roomActive and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(55, 65, 88)

    local allOn = dungeonActive and combatActive and roomActive
    masterBtn.Text = allOn and "STOP ALL" or "START ALL (Autonomous Loop)"
    masterBtn.BackgroundColor3 = allOn and Color3.fromRGB(180, 45, 45) or Color3.fromRGB(38, 140, 75)
end

dungeonToggle.MouseButton1Click:Connect(function() dungeonActive = not dungeonActive; updateToggles() end)
combatToggle.MouseButton1Click:Connect(function() combatActive = not combatActive; updateToggles() end)
roomToggle.MouseButton1Click:Connect(function() roomActive = not roomActive; updateToggles() end)

masterBtn.MouseButton1Click:Connect(function()
    local target = not (dungeonActive and combatActive and roomActive)
    dungeonActive, combatActive, roomActive = target, target, target
    updateToggles()
end)

closeBtn.MouseButton1Click:Connect(function()
    alive = false
    gui:Destroy()
end)

-- -------------------------------------------------------------
-- Background Automation Loops
-- -------------------------------------------------------------
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
        if alive and roomActive then stepRoom() end
    end
end)
