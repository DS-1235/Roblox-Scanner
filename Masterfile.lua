local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- -------------------------------------------------------------
-- Speed & Interval Configuration
-- -------------------------------------------------------------
local DUNGEON_INTERVAL = 0.6  -- Reduced from 1.2s to 0.6s (action & settle delay)
local COMBAT_INTERVAL  = 0.5  -- Reduced from 1.0s to 0.5s (teleport scan interval)

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
-- Main Draggable Window
-- -------------------------------------------------------------
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(300, 275)
frame.Position = UDim2.new(0.5, -150, 0.25, 0)
frame.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true

-- Title Bar
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -35, 0, 30)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 13
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "QA & Combat Automation Master"

local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.fromOffset(25, 25)
closeBtn.Position = UDim2.new(1, -28, 0, 3)
closeBtn.Text = "X"
closeBtn.TextSize = 12
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.BorderSizePixel = 0

-- Master [START ALL] Button
local masterBtn = Instance.new("TextButton", frame)
masterBtn.Size = UDim2.new(1, -20, 0, 32)
masterBtn.Position = UDim2.fromOffset(10, 32)
masterBtn.Text = "START ALL (Dungeon + Combat)"
masterBtn.TextSize = 13
masterBtn.Font = Enum.Font.SourceSansBold
masterBtn.TextColor3 = Color3.new(1, 1, 1)
masterBtn.BackgroundColor3 = Color3.fromRGB(38, 140, 75)
masterBtn.BorderSizePixel = 0

-- -------------------------------------------------------------
-- Section 1: Dungeon Automation (Stages 1, 2 & 3)
-- -------------------------------------------------------------
local dungeonBox = Instance.new("Frame", frame)
dungeonBox.Size = UDim2.new(1, -20, 0, 92)
dungeonBox.Position = UDim2.fromOffset(10, 70)
dungeonBox.BackgroundColor3 = Color3.fromRGB(32, 38, 52)
dungeonBox.BorderSizePixel = 0

local dungeonTitle = Instance.new("TextLabel", dungeonBox)
dungeonTitle.Size = UDim2.new(1, -85, 0, 22)
dungeonTitle.Position = UDim2.fromOffset(6, 4)
dungeonTitle.BackgroundTransparency = 1
dungeonTitle.TextColor3 = Color3.fromRGB(130, 200, 255)
dungeonTitle.TextSize = 12
dungeonTitle.Font = Enum.Font.SourceSansBold
dungeonTitle.TextXAlignment = Enum.TextXAlignment.Left
dungeonTitle.Text = "Dungeon Loop (0.6s Delay)"

local dungeonToggle = Instance.new("TextButton", dungeonBox)
dungeonToggle.Size = UDim2.fromOffset(72, 22)
dungeonToggle.Position = UDim2.new(1, -78, 0, 4)
dungeonToggle.Text = "START"
dungeonToggle.TextSize = 11
dungeonToggle.Font = Enum.Font.SourceSansBold
dungeonToggle.TextColor3 = Color3.new(1, 1, 1)
dungeonToggle.BackgroundColor3 = Color3.fromRGB(55, 65, 88)
dungeonToggle.BorderSizePixel = 0

local dungeonStatus = Instance.new("TextLabel", dungeonBox)
dungeonStatus.Size = UDim2.new(1, -12, 0, 60)
dungeonStatus.Position = UDim2.fromOffset(6, 28)
dungeonStatus.BackgroundTransparency = 1
dungeonStatus.TextColor3 = Color3.new(0.9, 0.9, 0.9)
dungeonStatus.TextSize = 11
dungeonStatus.TextWrapped = true
dungeonStatus.TextXAlignment = Enum.TextXAlignment.Left
dungeonStatus.TextYAlignment = Enum.TextYAlignment.Top
dungeonStatus.Text = "Status: Idle\nStages: Gems -> Create Party -> Start"

-- -------------------------------------------------------------
-- Section 2: Combat Teleport / Enemy Scanner
-- -------------------------------------------------------------
local combatBox = Instance.new("Frame", frame)
combatBox.Size = UDim2.new(1, -20, 0, 92)
combatBox.Position = UDim2.fromOffset(10, 170)
combatBox.BackgroundColor3 = Color3.fromRGB(32, 38, 52)
combatBox.BorderSizePixel = 0

local combatTitle = Instance.new("TextLabel", combatBox)
combatTitle.Size = UDim2.new(1, -85, 0, 22)
combatTitle.Position = UDim2.fromOffset(6, 4)
combatTitle.BackgroundTransparency = 1
combatTitle.TextColor3 = Color3.fromRGB(255, 150, 130)
combatTitle.TextSize = 12
combatTitle.Font = Enum.Font.SourceSansBold
combatTitle.TextXAlignment = Enum.TextXAlignment.Left
combatTitle.Text = "Combat Scanner (0.5s Interval)"

local combatToggle = Instance.new("TextButton", combatBox)
combatToggle.Size = UDim2.fromOffset(72, 22)
combatToggle.Position = UDim2.new(1, -78, 0, 4)
combatToggle.Text = "START"
combatToggle.TextSize = 11
combatToggle.Font = Enum.Font.SourceSansBold
combatToggle.TextColor3 = Color3.new(1, 1, 1)
combatToggle.BackgroundColor3 = Color3.fromRGB(55, 65, 88)
combatToggle.BorderSizePixel = 0

local combatStatus = Instance.new("TextLabel", combatBox)
combatStatus.Size = UDim2.new(1, -12, 0, 60)
combatStatus.Position = UDim2.fromOffset(6, 28)
combatStatus.BackgroundTransparency = 1
combatStatus.TextColor3 = Color3.new(0.9, 0.9, 0.9)
combatStatus.TextSize = 11
combatStatus.TextWrapped = true
combatStatus.TextXAlignment = Enum.TextXAlignment.Left
combatStatus.TextYAlignment = Enum.TextYAlignment.Top
combatStatus.Text = "Status: Idle\nAuto-teleports to nearest enemy hitbox"

-- -------------------------------------------------------------
-- State Variables
-- -------------------------------------------------------------
local alive = true
local dungeonActive = false
local combatActive = false
local dungeonBusy = false

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
                if cur:IsA("GuiButton") then
                    return cur
                end
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
-- Module 1: Dungeon Automation Step (0.6s delay)
-- -------------------------------------------------------------
local function stepDungeon()
    if dungeonBusy or not dungeonActive then return end
    dungeonBusy = true

    pcall(function()
        local paCols = getPaCols()
        if not paCols then
            dungeonStatus.Text = "Waiting for Party UI (pa_cols)..."
            return
        end

        local completed = paCols:FindFirstChild("completed")
        local listPane = paCols:FindFirstChild("list")
        local leaderPane = paCols:FindFirstChild("leader") or paCols:FindFirstChild("wave")

        -- Stage 1: Pay with Gems
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
                dungeonStatus.Text = "Stage 1: Found 'PAY WITH GEMS'\nSettling (" .. DUNGEON_INTERVAL .. "s)..."
                task.wait(DUNGEON_INTERVAL)
                if dungeonActive and isVisible(gemsBtn) then
                    dungeonStatus.Text = "Stage 1: Clicking 'PAY WITH GEMS'..."
                    clickButton(gemsBtn)
                    task.wait(DUNGEON_INTERVAL)
                end
            else
                dungeonStatus.Text = "Stage 1: Completed screen visible, locating Gems button..."
            end
            return
        end

        -- Stage 2: Create Party
        if listPane and isVisible(listPane) then
            local foot = listPane:FindFirstChild("pa_foot", true)
            local createBtn = foot and foot:FindFirstChild("btn", true)
            if not createBtn or not isVisible(createBtn) then
                createBtn = findButtonWithText(listPane, "CREATE PARTY")
            end

            if createBtn and isVisible(createBtn) then
                dungeonStatus.Text = "Stage 2: Found 'CREATE PARTY'\nSettling (" .. DUNGEON_INTERVAL .. "s)..."
                task.wait(DUNGEON_INTERVAL)
                if dungeonActive and isVisible(createBtn) then
                    dungeonStatus.Text = "Stage 2: Clicking 'CREATE PARTY'..."
                    clickButton(createBtn)
                    task.wait(DUNGEON_INTERVAL)
                end
            else
                dungeonStatus.Text = "Stage 2: Open Parties active, finding Create Party button..."
            end
            return
        end

        -- Stage 3: Start Dungeon Run
        if leaderPane and isVisible(leaderPane) then
            local paStart = leaderPane:FindFirstChild("pa_start", true)
            local paGo = paStart and paStart:FindFirstChild("pa_go", true)
            local startBtn = paGo and paGo:FindFirstChild("btn", true)

            if not startBtn or not isVisible(startBtn) then
                startBtn = findButtonWithText(leaderPane, "START")
            end

            if not startBtn or not isVisible(startBtn) then
                local menus = playerGui:FindFirstChild("Menus")
                local uiParty = menus and menus:FindFirstChild("UI_Party")
                if uiParty then
                    startBtn = uiParty:FindFirstChild("leader_go", true)
                end
            end

            if startBtn and isVisible(startBtn) then
                dungeonStatus.Text = "Stage 3: Found 'START'\nSettling (" .. DUNGEON_INTERVAL .. "s)..."
                task.wait(DUNGEON_INTERVAL)
                if dungeonActive and isVisible(startBtn) then
                    dungeonStatus.Text = "Stage 3: Clicking 'START'..."
                    clickButton(startBtn)
                    task.wait(DUNGEON_INTERVAL)
                    dungeonStatus.Text = "Dungeon launched!\nWaiting for next completion..."
                end
            else
                dungeonStatus.Text = "Stage 3: Your Party active, finding Start button..."
            end
            return
        end

        dungeonStatus.Text = "In Dungeon / Waiting for menu screens..."
    end)

    dungeonBusy = false
end

-- -------------------------------------------------------------
-- Module 2: Combat Teleport Step (0.5s interval)
-- -------------------------------------------------------------
local function stepCombat()
    if not combatActive then return end

    local char = player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then
        combatStatus.Text = "Waiting for player character..."
        return
    end

    local enemiesFolder = getEnemiesFolder()
    if not enemiesFolder then
        combatStatus.Text = "Waiting for enemies container\n(__Main.__Enemies.Client)..."
        return
    end

    local nearestRoot = nil
    local nearestDist = math.huge
    local nearestModel = nil
    local count = 0

    for _, model in ipairs(enemiesFolder:GetChildren()) do
        if model:IsA("Model") then
            local root = model:FindFirstChild("HumanoidRootPart", true)
            local hitbox = model:FindFirstChild("Hitbox", true)

            if root and root:IsA("BasePart") and hitbox and hitbox:IsA("BasePart") then
                count += 1
                local dist = (myRoot.Position - root.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestRoot = root
                    nearestModel = model
                end
            end
        end
    end

    if nearestRoot and nearestModel then
        local destination = nearestRoot.Position + nearestRoot.CFrame.LookVector * 5 + Vector3.new(0, 2, 0)
        char:PivotTo(CFrame.lookAt(destination, nearestRoot.Position))
        combatStatus.Text = string.format("Target: %s (Alive: %d)\nDistance: %.2f studs", nearestModel.Name, count, nearestDist)
    else
        combatStatus.Text = string.format("No targets found (Enemies: %d)", count)
    end
end

-- -------------------------------------------------------------
-- Button Handlers & Master Toggle
-- -------------------------------------------------------------
local function setDungeonState(state)
    dungeonActive = state
    dungeonToggle.Text = dungeonActive and "STOP" or "START"
    dungeonToggle.BackgroundColor3 = dungeonActive and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(55, 65, 88)
    if not dungeonActive then
        dungeonStatus.Text = "Status: Paused"
    end
end

local function setCombatState(state)
    combatActive = state
    combatToggle.Text = combatActive and "STOP" or "START"
    combatToggle.BackgroundColor3 = combatActive and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(55, 65, 88)
    if not combatActive then
        combatStatus.Text = "Status: Paused"
    end
end

dungeonToggle.MouseButton1Click:Connect(function()
    setDungeonState(not dungeonActive)
    if dungeonActive then task.spawn(stepDungeon) end
end)

combatToggle.MouseButton1Click:Connect(function()
    setCombatState(not combatActive)
    if combatActive then task.spawn(stepCombat) end
end)

masterBtn.MouseButton1Click:Connect(function()
    local targetState = not (dungeonActive and combatActive)
    setDungeonState(targetState)
    setCombatState(targetState)
    masterBtn.Text = targetState and "STOP ALL" or "START ALL (Dungeon + Combat)"
    masterBtn.BackgroundColor3 = targetState and Color3.fromRGB(180, 45, 45) or Color3.fromRGB(38, 140, 75)
    if targetState then
        task.spawn(stepDungeon)
        task.spawn(stepCombat)
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    alive = false
    dungeonActive = false
    combatActive = false
    gui:Destroy()
end)

-- -------------------------------------------------------------
-- Background Automation Loops (Updated Frequencies)
-- -------------------------------------------------------------
task.spawn(function()
    while alive and gui.Parent do
        task.wait(DUNGEON_INTERVAL) -- Checks menu transitions every 0.6 seconds
        if alive and dungeonActive and not dungeonBusy then
            stepDungeon()
        end
    end
end)

task.spawn(function()
    while alive and gui.Parent do
        task.wait(COMBAT_INTERVAL) -- Scans and teleports every 0.5 seconds
        if alive and combatActive then
            stepCombat()
        end
    end
end)
