local P = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local pl = P.LocalPlayer
local pg = pl:WaitForChild("PlayerGui")

-- -------------------------------------------------------------
-- Configuration
-- -------------------------------------------------------------
local ACTION_DELAY = 1.2  -- Settle delay for UI tween/slide animations

-- -------------------------------------------------------------
-- Clean up existing UI if re-running
-- -------------------------------------------------------------
local old = pg:FindFirstChild("NS")
if old then old:Destroy() end

local g = Instance.new("ScreenGui")
g.Name = "NS"
g.ResetOnSpawn = false
g.DisplayOrder = 100
g.Parent = pg

local f = Instance.new("Frame", g)
f.Size = UDim2.fromOffset(280, 140)
f.Position = UDim2.new(0.5, -140, 0.2, 0)
f.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true

local info = Instance.new("TextLabel", f)
info.Size = UDim2.new(1, -10, 0, 80)
info.Position = UDim2.fromOffset(5, 5)
info.BackgroundTransparency = 1
info.TextColor3 = Color3.new(1, 1, 1)
info.TextSize = 12
info.TextWrapped = true
info.Text = "QA Automation: Stages 1, 2 & 3 Ready\nClick START to begin."

local function btn(t, x, w)
    local b = Instance.new("TextButton", f)
    b.Size = UDim2.fromOffset(w, 32)
    b.Position = UDim2.fromOffset(x, 96)
    b.Text = t
    b.TextSize = 14
    b.BackgroundColor3 = Color3.fromRGB(45, 52, 70)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    return b
end

local start = btn("START", 5, 130)
local close = btn("CLOSE", 145, 130)

local active = false
local alive = true
local busy = false

-- Safe logging helper
local function log(msg)
    local text = tostring(msg)
    print("[QA-Automation] " .. text)
    if info and info.Parent then
        info.Text = text
    end
end

-- Checks if a GuiObject and all its ancestors are visible
local function isVisible(obj)
    if not obj or not obj:IsDescendantOf(pg) then return false end
    local cur = obj
    while cur and cur ~= pg do
        if cur.Name == "__Disable" then return false end
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("LayerCollector") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0
end

-- Safely triggers a UI button using firesignal or VirtualInputManager
local function clickButton(b)
    if not b then return end
    if typeof(firesignal) == "function" then
        pcall(function() firesignal(b.Activated) end)
        pcall(function() firesignal(b.MouseButton1Click) end)
        for _, child in ipairs(b:GetChildren()) do
            if child:IsA("GuiButton") or child:IsA("TextLabel") then
                pcall(function() firesignal(child.Activated) end)
            end
        end
    else
        local inset = GuiService:GetGuiInset()
        local cx = b.AbsolutePosition.X + (b.AbsoluteSize.X / 2)
        local cy = b.AbsolutePosition.Y + (b.AbsoluteSize.Y / 2) + inset.Y
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end
end

-- Finds pa_cols regardless of container layout variations
local function getPaCols()
    local menus = pg:FindFirstChild("Menus")
    local uiParty = menus and menus:FindFirstChild("UI_Party")
    if not uiParty then return nil end
    return uiParty:FindFirstChild("pa_cols", true)
end

-- Helper to find a button by matching text label or descendant pb_text
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

-- Main automation loop
local function runAutomationLoop()
    if busy or not active then return end
    busy = true

    -- Guarded inside pcall to guarantee busy resets even if state changes unexpectedly
    local ok, err = pcall(function()
        local paCols = getPaCols()
        if not paCols then
            log("Waiting for Party UI container...")
            return
        end

        local completed = paCols:FindFirstChild("completed")
        local listPane = paCols:FindFirstChild("list")
        -- Supports both standard dungeon leader and wave/endless mode
        local leaderPane = paCols:FindFirstChild("leader") or paCols:FindFirstChild("wave")

        -- -------------------------------------------------------------
        -- STAGE 1: Dungeon Completed Screen -> Click "PAY WITH GEMS"
        -- -------------------------------------------------------------
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
                log("Stage 1: Found 'PAY WITH GEMS'.\nWaiting " .. ACTION_DELAY .. "s to settle...")
                task.wait(ACTION_DELAY)
                if active and isVisible(gemsBtn) then
                    log("Stage 1: Clicking 'PAY WITH GEMS'...")
                    clickButton(gemsBtn)
                    task.wait(ACTION_DELAY)
                end
            else
                log("Stage 1: Completed screen active, locating Gems button...")
            end
            return
        end

        -- -------------------------------------------------------------
        -- STAGE 2: Open Parties Screen -> Click "CREATE PARTY"
        -- -------------------------------------------------------------
        if listPane and isVisible(listPane) then
            local foot = listPane:FindFirstChild("pa_foot", true)
            local createBtn = foot and foot:FindFirstChild("btn", true)

            if not createBtn or not isVisible(createBtn) then
                createBtn = findButtonWithText(listPane, "CREATE PARTY")
            end

            if createBtn and isVisible(createBtn) then
                log("Stage 2: Found 'CREATE PARTY'.\nWaiting " .. ACTION_DELAY .. "s to settle...")
                task.wait(ACTION_DELAY)
                if active and isVisible(createBtn) then
                    log("Stage 2: Clicking 'CREATE PARTY'...")
                    clickButton(createBtn)
                    task.wait(ACTION_DELAY)
                end
            else
                log("Stage 2: Open Parties active, locating CREATE PARTY button...")
            end
            return
        end

        -- -------------------------------------------------------------
        -- STAGE 3: Your Party Screen -> Click "START"
        -- -------------------------------------------------------------
        if leaderPane and isVisible(leaderPane) then
            local paStart = leaderPane:FindFirstChild("pa_start", true)
            local paGo = paStart and paStart:FindFirstChild("pa_go", true)
            local startBtn = paGo and paGo:FindFirstChild("btn", true)

            -- Fallback 1: locate by matching 'START' text inside leader pane
            if not startBtn or not isVisible(startBtn) then
                startBtn = findButtonWithText(leaderPane, "START")
            end

            -- Fallback 2: look for Root.NUI_Looks.leader_go (from screen scan)
            if not startBtn or not isVisible(startBtn) then
                local menus = pg:FindFirstChild("Menus")
                local uiParty = menus and menus:FindFirstChild("UI_Party")
                if uiParty then
                    startBtn = uiParty:FindFirstChild("leader_go", true)
                end
            end

            if startBtn and isVisible(startBtn) then
                log("Stage 3: Found 'START' button.\nWaiting " .. ACTION_DELAY .. "s to settle...")
                task.wait(ACTION_DELAY)
                if active and isVisible(startBtn) then
                    log("Stage 3: Clicking 'START' to begin dungeon...")
                    clickButton(startBtn)
                    task.wait(ACTION_DELAY)
                    log("Dungeon launched! Waiting for next completion...")
                end
            else
                log("Stage 3: Your Party active, locating START button...")
            end
            return
        end

        log("Waiting for Dungeon Completion or Party screens...")
    end)

    if not ok then
        warn("[QA-Automation Error] " .. tostring(err))
        log("Error: " .. tostring(err))
    end

    busy = false
end

-- -------------------------------------------------------------
-- Event Listeners
-- -------------------------------------------------------------
start.MouseButton1Click:Connect(function()
    active = not active
    start.Text = active and "STOP" or "START"
    if active then
        log("Automation started (Stages 1, 2 & 3)")
        task.spawn(runAutomationLoop)
    else
        log("Automation paused")
    end
end)

close.MouseButton1Click:Connect(function()
    alive = false
    active = false
    g:Destroy()
end)

-- Background loop ticking every second while active
task.spawn(function()
    while alive and g.Parent do
        task.wait(1)
        if alive and active and not busy then
            runAutomationLoop()
        end
    end
end)
