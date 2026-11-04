-- ====================================================================
-- ROBLOX UI DIAGNOSTIC INSPECTOR (READ-ONLY)
-- Scans HUD buttons, hierarchy paths, coordinates, and classes
-- ====================================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local logs = {}
local function log(str)
    table.insert(logs, str)
    print(str)
end

log("==================== [UI INSPECTOR START] ====================")
log("Player: " .. tostring(player.Name))

-- Helper: Get full hierarchy path
local function getFullPath(inst)
    local path = inst.Name
    local curr = inst.Parent
    while curr and curr ~= game do
        path = curr.Name .. "." .. path
        if curr == playerGui then break end
        curr = curr.Parent
    end
    return path
end

-- --------------------------------------------------------------------
-- 1. Scan for HUD Cluster Buttons (Stats, Daily, Inventory, etc.)
-- --------------------------------------------------------------------
log("\n--- [1. HUD HEXAGON CLUSTER BUTTONS] ---")
local targetKeywords = {
    "STAT", "DAILY", "INVENTORY", "QUEST", "SHOP",
    "DUNGEON", "WORLD", "EVENT", "WHEEL", "MENU", "SHADOW"
}

local foundItems = {}

for _, desc in ipairs(playerGui:GetDescendants()) do
    local isMatch = false
    local matchedWord = ""

    local nameUpper = string.upper(desc.Name)
    local textUpper = ""
    if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text then
        textUpper = string.upper(string.gsub(desc.Text, "<[^>]+>", ""))
    end

    for _, kw in ipairs(targetKeywords) do
        if string.find(nameUpper, kw) or string.find(textUpper, kw) then
            isMatch = true
            matchedWord = kw
            break
        end
    end

    if isMatch and desc:IsA("GuiObject") and desc.Visible then
        local txt = (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Text or ""
        local entry = string.format(
            "[%s] %s '%s' | Text: '%s' | Pos: (%.0f, %.0f) | Size: (%.0f, %.0f)\n   Path: %s",
            matchedWord,
            desc.ClassName,
            desc.Name,
            txt,
            desc.AbsolutePosition.X,
            desc.AbsolutePosition.Y,
            desc.AbsoluteSize.X,
            desc.AbsoluteSize.Y,
            getFullPath(desc)
        )
        table.insert(foundItems, entry)
    end
end

if #foundItems > 0 then
    for _, item in ipairs(foundItems) do
        log(item)
    end
else
    log("No direct matches found by keyword.")
end

-- --------------------------------------------------------------------
-- 2. Inspect Top-level Frames in ScreenGuis
-- --------------------------------------------------------------------
log("\n--- [2. SCREENGUIS & ACTIVE CONTAINERS] ---")
for _, gui in ipairs(playerGui:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Enabled then
        log(string.format("ScreenGui: %s", gui.Name))
        for _, child in ipairs(gui:GetChildren()) do
            if child:IsA("GuiObject") and child.Visible then
                log(string.format("   -> Frame: %s (%s) Pos: (%.0f, %.0f) Size: (%.0f, %.0f)",
                    child.Name, child.ClassName,
                    child.AbsolutePosition.X, child.AbsolutePosition.Y,
                    child.AbsoluteSize.X, child.AbsoluteSize.Y
                ))
            end
        end
    end
end

-- --------------------------------------------------------------------
-- 3. Check for Stats Window Specifically
-- --------------------------------------------------------------------
log("\n--- [3. STATS WINDOW CHECK] ---")
local foundStatsWin = false
for _, desc in ipairs(playerGui:GetDescendants()) do
    if desc:IsA("TextLabel") and desc.Text then
        local u = string.upper(desc.Text)
        if string.find(u, "SPEND YOUR POINTS") or string.find(u, "POINTS TO SPEND") then
            foundStatsWin = true
            local p = desc.Parent
            log(string.format("Stats Window Found: text '%s' inside %s (%s, Visible: %s)", desc.Text, p.Name, p.ClassName, tostring(p.Visible)))
            log("Path: " .. getFullPath(desc))
            break
        end
    end
end
if not foundStatsWin then
    log("Stats window is currently CLOSED on screen.")
end

log("\n==================== [INSPECTION COMPLETE] ====================")

local fullReport = table.concat(logs, "\n")

-- Auto-copy to clipboard
if typeof(setclipboard) == "function" then
    pcall(function()
        setclipboard(fullReport)
    end)
end

-- --------------------------------------------------------------------
-- 4. Create On-Screen Scrollable Display Window
-- --------------------------------------------------------------------
local oldGui = CoreGui:FindFirstChild("UIDiagnosticGui") or playerGui:FindFirstChild("UIDiagnosticGui")
if oldGui then oldGui:Destroy() end

local screen = Instance.new("ScreenGui")
screen.Name = "UIDiagnosticGui"
screen.ResetOnSpawn = false

pcall(function() screen.Parent = CoreGui end)
if screen.Parent ~= CoreGui then screen.Parent = playerGui end

local main = Instance.new("Frame", screen)
main.Size = UDim2.fromOffset(450, 360)
main.Position = UDim2.fromOffset(40, 100)
main.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
main.BorderSizePixel = 0
local corner = Instance.new("UICorner", main)
corner.CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(50, 70, 100)
stroke.Thickness = 1.5

-- Dragging
local dragging, dragStart, startPos = false, nil, nil
main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
    end
end)

-- Title
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -60, 0, 32)
title.Position = UDim2.fromOffset(12, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "🔍 UI Diagnostic Inspector"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

-- Close Button
local closeBtn = Instance.new("TextButton", main)
closeBtn.Size = UDim2.fromOffset(24, 24)
closeBtn.Position = UDim2.new(1, -32, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextSize = 11
local closeCorner = Instance.new("UICorner", closeBtn)
closeCorner.CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() screen:Destroy() end)

-- Copy Button
local copyBtn = Instance.new("TextButton", main)
copyBtn.Size = UDim2.new(1, -24, 0, 26)
copyBtn.Position = UDim2.fromOffset(12, 38)
copyBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.Text = "📋 Copy Full Report to Clipboard"
copyBtn.TextColor3 = Color3.new(1, 1, 1)
copyBtn.TextSize = 11
local copyCorner = Instance.new("UICorner", copyBtn)
copyCorner.CornerRadius = UDim.new(0, 6)

copyBtn.MouseButton1Click:Connect(function()
    if typeof(setclipboard) == "function" then
        setclipboard(fullReport)
        copyBtn.Text = "✅ Copied to Clipboard!"
        task.wait(1.5)
        copyBtn.Text = "📋 Copy Full Report to Clipboard"
    else
        copyBtn.Text = "Clipboard not supported (Use F9 console)"
    end
end)

-- Scrolling Text Box
local scroll = Instance.new("ScrollingFrame", main)
scroll.Size = UDim2.new(1, -24, 1, -78)
scroll.Position = UDim2.fromOffset(12, 70)
scroll.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
local scrollCorner = Instance.new("UICorner", scroll)
scrollCorner.CornerRadius = UDim.new(0, 6)
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(600, #logs * 28))

local reportText = Instance.new("TextBox", scroll)
reportText.Size = UDim2.new(1, -12, 1, 0)
reportText.Position = UDim2.fromOffset(6, 4)
reportText.BackgroundTransparency = 1
reportText.Font = Enum.Font.Code
reportText.Text = fullReport
reportText.TextColor3 = Color3.fromRGB(220, 230, 242)
reportText.TextSize = 10
reportText.TextXAlignment = Enum.TextXAlignment.Left
reportText.TextYAlignment = Enum.TextYAlignment.Top
reportText.ClearTextOnFocus = false
reportText.TextEditable = false
