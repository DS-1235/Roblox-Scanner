local P = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local pl = P.LocalPlayer
local pg = pl:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("NS")
if old then old:Destroy() end

local g = Instance.new("ScreenGui", pg)
g.Name = "NS"
g.ResetOnSpawn = false
g.DisplayOrder = 100

local f = Instance.new("Frame", g)
f.Size = UDim2.fromOffset(280, 140)
f.Position = UDim2.new(0.5, -140, 0.2, 0)
f.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
f.Active = true
f.Draggable = true

local info = Instance.new("TextLabel", f)
info.Size = UDim2.new(1, -10, 0, 80)
info.Position = UDim2.fromOffset(5, 5)
info.BackgroundTransparency = 1
info.TextColor3 = Color3.new(1, 1, 1)
info.TextSize = 12
info.TextWrapped = true
info.Text = "QA Automation: Ready (Stages 1 & 2)"

local function btn(t, x, w)
	local b = Instance.new("TextButton", f)
	b.Size = UDim2.fromOffset(w, 32)
	b.Position = UDim2.fromOffset(x, 96)
	b.Text = t
	b.TextSize = 14
	return b
end

local start = btn("START", 5, 130)
local close = btn("CLOSE", 145, 130)

local active = false
local alive = true
local busy = false
local ACTION_DELAY = 1.2

local function log(msg)
	print("[QA-Automation] " + msg)
	info.Text = msg
end

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

local function clickButton(b)
	if typeof(firesignal) == "function" then
		pcall(function() firesignal(b.Activated) end)
		pcall(function() firesignal(b.MouseButton1Click) end)
	else
		local inset = GuiService:GetGuiInset()
		local cx = b.AbsolutePosition.X + (b.AbsoluteSize.X / 2)
		local cy = b.AbsolutePosition.Y + (b.AbsoluteSize.Y / 2) + inset.Y
		VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
		task.wait(0.05)
		VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
	end
end

local function getPaCols()
	local menus = pg:FindFirstChild("Menus")
	local uiParty = menus and menus:FindFirstChild("UI_Party")
	local root = uiParty and uiParty:FindFirstChild("Root")
	local fit = root and root:FindFirstChild("NUI_Fit")
	local win = fit and fit:FindFirstChild("window")
	local win3d = win and win:FindFirstChild("win_3d")
	local body = win3d and win3d:FindFirstChild("win_body")
	local pane = body and body:FindFirstChild("pane_body")
	return pane and pane:FindFirstChild("pa_cols")
end

local function runAutomationLoop()
	if busy then return end
	busy = true

	local paCols = getPaCols()
	if not paCols then
		log("Waiting for Party UI container...")
		busy = false
		return
	end

	local completed = paCols:FindFirstChild("completed")
	local listPane = paCols:FindFirstChild("list")
	local leaderPane = paCols:FindFirstChild("leader")

	-- Stage 3 Check (In case we are already on leader/party screen)
	if leaderPane and isVisible(leaderPane) then
		log("Stage 2 already passed! 'YOUR PARTY' screen is active.")
		busy = false
		return
	end

	-- Stage 2 Check: Open Parties screen is visible
	if listPane and isVisible(listPane) then
		local foot = listPane:FindFirstChild("pa_foot")
		local createBtn = foot and foot:FindFirstChild("btn")

		if createBtn and isVisible(createBtn) then
			log("Found 'CREATE PARTY' button. Clicking...")
			clickButton(createBtn)
			task.wait(ACTION_DELAY)
		else
			log("Open Parties visible, looking for Create Party button...")
		end

	-- Stage 1 Check: Dungeon Completed screen is visible
	elseif completed and isVisible(completed) then
		local opts = completed:FindFirstChild("pa_opts")
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
			log("Clicking 'PAY WITH GEMS'...")
			clickButton(gemsBtn)
			task.wait(ACTION_DELAY)
		else
			log("Completed screen active, locating Gems button...")
		end
	else
		log("Waiting for dungeon completion screen...")
	end

	busy = false
end

start.MouseButton1Click:Connect(function()
	active = not active
	start.Text = active and "STOP" or "START"
	if active then
		log("Automation started (Stage 1 & 2)")
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

task.spawn(function()
	while alive and g.Parent do
		task.wait(1)
		if alive and active and not busy then
			runAutomationLoop()
		end
	end
end)
