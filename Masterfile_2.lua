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
local STEP_DISTANCE     = 90   -- Fallback distance if room model isn't found

-- -------------------------------------------------------------
-- Clean up existing UI
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
local EXPANDED_HEIGHT = 490
local MINIMIZED_HEIGHT = 32

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(320, EXPANDED_HEIGHT)
frame.Position = UDim2.new(0.5, -160, 0.12, 0)
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
local _, roomToggle, roomStatus       = createSection(226, "3. Room Navigator (Center Teleport)", Color3.fromRGB(140, 240, 180))

-- -------------------------------------------------------------
-- Section 4: Live Delay Inputs & Diagnostic Tool
-- -------------------------------------------------------------
local settingsBox = Instance.new("Frame", frame)
settingsBox.Size = UDim2.new(1, -20, 0, 175)
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

local dungeonInput = createSettingInput(26, "Dungeon Menu Delay (s):", DUNGEON_INTERVAL)
local combatInput  = createSettingInput(52, "Combat Interval (s):", COMBAT_INTERVAL)
local doorInput    = createSettingInput(78, "Door Clear Delay (s):", CLEAR_DELAY)
local stepInput    = createSettingInput(104, "Fallback Step (studs):", STEP_DISTANCE)

local scanMapBtn = Instance.new("TextButton", settingsBox)
scanMapBtn.Size = UDim2.new(1, -12, 0, 26)
scanMapBtn.Position = UDim2.fromOffset(6, 138)
scanMapBtn.Text = "SCAN MAP STRUCTURE (Print to F9)"
scanMapBtn.TextSize = 11
scanMapBtn.Font = Enum.Font.SourceSansBold
scanMapBtn.TextColor3 = Color3.new(1, 1, 1)
scanMapBtn.BackgroundColor3 = Color3.fromRGB(50, 75, 110)
scanMapBtn.BorderSizePixel = 0

dungeonInput.FocusLost:Connect(function()
    local val = tonumber(dungeonInput.Text)
    if val and val > 0 then DUNGEON_INTERVAL = val else dungeonInput.Text = tostring(DUNGEON_INTERVAL) end
end)

combatInput.FocusLost:Connect(function()
    local val = tonumber(combatInput.Text)
    if val and val > 0 then COMBAT_INTERVAL = val else combatInput.Text = tostring(COMBAT_INTERVAL) end
end)

doorInput.FocusLost:Connect(function()
    local val = tonumber(doorInput.Text)
    if val and val >= 0 then CLEAR_DELAY = val else doorInput.Text = tostring(CLEAR_DELAY) end
end)

stepInput.FocusLost:Connect(function()
    local val = tonumber(stepInput.Text)
    if val and val > 0 then STEP_DISTANCE = val else stepInput.Text = tostring(STEP_DISTANCE) end
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

local lastEnteredRoom = 0  -- Tracks the last room your character physically teleported to
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
-- Shared Helpers & HUD Parser
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

-- Reads ROOM 5 / 8 and Enemies left 3 / 7 directly from game HUD
local function getDungeonHUDInfo()
    local roomNum, totalRooms = nil, nil
    local enemiesLeft, enemiesTotal = nil, nil

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text and desc.Text ~= "" then
            local clean = string.gsub(desc.Text, "<[^>]+>", "")
            local upper = string.upper(clean)

            -- Parse "ROOM 5 / 8"
            if not roomNum and string.find(upper, "ROOM") then
                local cur, tot = string.match(clean, "(%d+)%s*/%s*(%d+)")
                if cur and tot then
                    roomNum = tonumber(cur)
                    totalRooms = tonumber(tot)
                end
            end

            -- Parse "Enemies left 3 / 7"
            if enemiesLeft == nil and string.find(upper, "ENEMIES LEFT") then
                local left, tot = string.match(clean, "(%d+)%s*/%s*(%d+)")
                if left then
                    enemiesLeft = tonumber(left)
                    enemiesTotal = tonumber(tot)
                else
                    local parent = desc.Parent
                    if parent then
                        for _, sib in ipairs(parent:GetChildren()) do
                            if sib ~= desc and sib:IsA("TextLabel") and sib.Text then
                                local sClean = string.gsub(sib.Text, "<[^>]+>", "")
                                local sLeft, sTot = string.match(sClean, "(%d+)%s*/%s*(%d+)")
                                if sLeft then
                                    enemiesLeft = tonumber(sLeft)
                                    enemiesTotal = tonumber(sTot)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        if roomNum and enemiesLeft ~= nil then break end
    end

    return roomNum, totalRooms, enemiesLeft, enemiesTotal
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

-- -------------------------------------------------------------
-- Room Model & Center Coordinate Resolver
-- -------------------------------------------------------------
local function findRoomModel(roomNum, totalRooms)
    if not roomNum then return nil end
    local searchNames = {
        "room" .. roomNum,
        "room " .. roomNum,
        "room_" .. roomNum,
        "floor" .. roomNum,
        "stage" .. roomNum,
        tostring(roomNum)
    }

    local containers = {}
    local main = workspace:FindFirstChild("__Main")
    if main then
        table.insert(containers, main)
        for _, ch in ipairs(main:GetChildren()) do
            if ch:IsA("Folder") or ch:IsA("Model") then
                table.insert(containers, ch)
            end
        end
    end
    for _, name in ipairs({"Rooms", "__Rooms", "Map", "__Map", "Dungeon", "Stages", "Floors"}) do
        local c = workspace:FindFirstChild(name)
        if c then table.insert(containers, c) end
    end
    table.insert(containers, workspace)

    for _, container in ipairs(containers) do
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") or child:IsA("Folder") then
                local lowerName = string.lower(child.Name)
                for _, sName in ipairs(searchNames) do
                    if lowerName == sName or string.find(lowerName, "^" .. sName .. "$") then
                        return child
                    end
                end
            end
        end
    end

    -- Check by ordered child index if container has matching count (e.g. 8 rooms)
    for _, container in ipairs(containers) do
        local children = container:GetChildren()
        if totalRooms and #children == totalRooms then
            if children[roomNum] and (children[roomNum]:IsA("Model") or children[roomNum]:IsA("Folder")) then
                return children[roomNum]
            end
        end
    end

    return nil
end

local function getRoomCenterCFrame(roomModel)
    if not roomModel then return nil end

    -- 1. Explicit Anchor part if present
    local anchorNames = {"Center", "Spawn", "Entrance", "Door", "Start", "Checkpoint"}
    for _, name in ipairs(anchorNames) do
        local anchor = roomModel:FindFirstChild(name, true)
        if anchor and anchor:IsA("BasePart") then
            return anchor.CFrame + Vector3.new(0, 3.5, 0)
        end
    end

    if roomModel:IsA("Model") and roomModel.PrimaryPart then
        return roomModel.PrimaryPart.CFrame + Vector3.new(0, 3.5, 0)
    end

    -- 2. Model:GetBoundingBox() gives mathematical center of the entire room
    if roomModel:IsA("Model") then
        local cf, size = roomModel:GetBoundingBox()
        local floorY = cf.Position.Y - (size.Y / 2) + 3.5
        return CFrame.new(cf.Position.X, floorY, cf.Position.Z)
    end

    -- 3. If folder, find largest BasePart (floor plate)
    local largestPart = nil
    local largestArea = 0
    for _, desc in ipairs(roomModel:GetDescendants()) do
        if desc:IsA("BasePart") then
            local area = desc.Size.X * desc.Size.Z
            if area > largestArea then
                largestArea = area
                largestPart = desc
            end
        end
    end
    if largestPart then
        return largestPart.CFrame + Vector3.new(0, (largestPart.Size.Y / 2) + 3.5, 0)
    end

    return nil
end

-- Tries target room, or intermediate room if distant room is streamed out
local function resolveRoomTarget(targetRoomNum, totalRooms)
    local model = findRoomModel(targetRoomNum, totalRooms)
    if model then
        local cf = getRoomCenterCFrame(model)
        if cf then return cf, targetRoomNum end
    end

    -- If target room is not streamed in yet, hop forward through intermediate rooms
    for intermediate = targetRoomNum - 1, 1, -1 do
        local interModel = findRoomModel(intermediate, totalRooms)
        if interModel then
            local cf = getRoomCenterCFrame(interModel)
            if cf then return cf, intermediate end
        end
    end

    return nil, nil
end

-- Diagnostic Map Scanner
scanMapBtn.MouseButton1Click:Connect(function()
    print("=================== MAP & ROOMS SCAN ===================")
    local roomNum, totalRooms, enemiesLeft, enemiesTotal = getDungeonHUDInfo()
    print(string.format("[HUD Status] Room: %s/%s | Enemies: %s/%s", 
        tostring(roomNum), tostring(totalRooms), tostring(enemiesLeft), tostring(enemiesTotal)))

    local main = workspace:FindFirstChild("__Main")
    if main then
        print("[workspace.__Main Children]:")
        for _, ch in ipairs(main:GetChildren()) do
            print("  - " .. ch.Name .. " (" .. ch.ClassName .. ") [Children: " .. #ch:GetChildren() .. "]")
            if ch:IsA("Folder") or ch:IsA("Model") then
                for _, sub in ipairs(ch:GetChildren()) do
                    print("      * " .. sub.Name .. " (" .. sub.ClassName .. ")")
                end
            end
        end
    else
        print("[Notice] workspace.__Main not found")
    end
    print("========================================================")
end)

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
            lastEnteredRoom = 0 -- Reset room tracker for next run
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
-- Module 3: Active Room Sync & Center Teleport
-- -------------------------------------------------------------
local function stepRoom()
    if not roomActive then return end
    local char = player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local roomNum, totalRooms, enemiesLeft, enemiesTotal = getDungeonHUDInfo()
    if not roomNum then
        roomStatus.Text = "Waiting for Dungeon HUD..."
        return
    end

    local curRoomText = tostring(roomNum) .. "/" .. tostring(totalRooms or 8)

    -- ---------------------------------------------------------
    -- Condition A: Catch-Up (You are left behind in an older room)
    -- ---------------------------------------------------------
    if lastEnteredRoom ~= roomNum then
        -- HUD has already advanced to roomNum, but you haven't arrived there yet
        roomStatus.Text = string.format("Advancing to Room %d Center...", roomNum)
        local targetCenter, foundNum = resolveRoomTarget(roomNum, totalRooms)

        if targetCenter then
            char:PivotTo(targetCenter)
            lastEnteredRoom = foundNum
            roomStatus.Text = string.format("Teleported to Room %d Center!", foundNum)
            task.wait(0.6)
            return
        else
            -- If model not found, step forward toward it
            char:PivotTo(myRoot.CFrame + (myRoot.CFrame.LookVector * STEP_DISTANCE) + Vector3.new(0, 2, 0))
            lastEnteredRoom = roomNum
            roomStatus.Text = string.format("Stepped toward Room %d", roomNum)
            task.wait(0.6)
            return
        end
    end

    -- ---------------------------------------------------------
    -- Condition B: Inside the Active Room
    -- ---------------------------------------------------------
    -- Default enemiesLeft if not read yet
    if enemiesLeft == nil then
        local folder = getEnemiesFolder()
        enemiesLeft = (folder and #folder:GetChildren()) or 1
    end

    if enemiesLeft > 0 then
        -- Currently fighting inside this room
        clearTimerStart = nil
        roomStatus.Text = string.format("Room %s: Fighting (%d left)\nDoor is closed.", curRoomText, enemiesLeft)
    else
        -- 0 enemies left in this room
        if totalRooms and roomNum >= totalRooms then
            roomStatus.Text = string.format("Boss Room %s Cleared!\nWaiting for Completion Menu...", curRoomText)
            clearTimerStart = nil
            return
        end

        if not clearTimerStart then clearTimerStart = tick() end
        local remaining = math.max(0, CLEAR_DELAY - (tick() - clearTimerStart))

        if remaining > 0 then
            roomStatus.Text = string.format("Room %s Cleared! Door Open!\nMoving in: %.1fs", curRoomText, remaining)
        else
            -- 2s delay elapsed: Target the next room
            local nextRoomNum = roomNum + 1
            roomStatus.Text = string.format("Moving to Room %d Center...", nextRoomNum)

            local targetCenter, foundNum = resolveRoomTarget(nextRoomNum, totalRooms)
            if targetCenter then
                char:PivotTo(targetCenter)
                lastEnteredRoom = foundNum
                roomStatus.Text = string.format("Teleported to Room %d Center!", foundNum)
            else
                char:PivotTo(myRoot.CFrame + (myRoot.CFrame.LookVector * STEP_DISTANCE) + Vector3.new(0, 2, 0))
                lastEnteredRoom = nextRoomNum
                roomStatus.Text = string.format("Stepped toward Room %d", nextRoomNum)
            end

            clearTimerStart = nil
            task.wait(1.0)
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
        task.wait(0.2)
        if alive and roomActive then stepRoom() end
    end
end)
