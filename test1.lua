local P = game:GetService("Players")
local pl = P.LocalPlayer
local pg = pl:WaitForChild("PlayerGui")

local old = pg:FindFirstChild("NS")
if old then old:Destroy() end

local g = Instance.new("ScreenGui", pg)
g.Name = "NS"
g.ResetOnSpawn = false
g.DisplayOrder = 100

local f = Instance.new("Frame", g)
f.Size = UDim2.fromOffset(320, 210)
f.Position = UDim2.new(0.5, -160, 0.2, 0)
f.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
f.Active = true
f.Draggable = true

local box = Instance.new("TextBox", f)
box.Size = UDim2.new(1, -10, 0, 160)
box.Position = UDim2.fromOffset(5, 5)
box.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
box.TextColor3 = Color3.new(1, 1, 1)
box.TextSize = 11
box.TextWrapped = true
box.MultiLine = true
box.TextEditable = false
box.ClearTextOnFocus = false
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Top
box.Text = "Click START, open menus, then Ctrl+A & Ctrl+C here"

local function btn(t, x, w)
	local b = Instance.new("TextButton", f)
	b.Size = UDim2.fromOffset(w, 32)
	b.Position = UDim2.fromOffset(x, 172)
	b.Text = t
	b.TextSize = 14
	return b
end

local start = btn("START", 5, 150)
local close = btn("CLOSE", 165, 150)

local active = false
local alive = true
local seen = {}
local logs = {}

local targets = {
	"DUNGEON COMPLETED", "PAY WITH GEMS", "1.60",
	"OPEN PARTIES", "CREATE PARTY", "YOUR PARTY", "START"
}

local function scan()
	local added = false
	for _, d in ipairs(pg:GetDescendants()) do
		if not d:IsDescendantOf(g) and (d:IsA("TextLabel") or d:IsA("TextButton")) then
			local txt = string.upper(d.Text or "")
			for _, m in ipairs(targets) do
				if string.find(txt, m, 1, true) then
					local p = d:GetFullName()
					if not seen[p] then
						seen[p] = true
						added = true
						table.insert(logs, "[" .. d.ClassName .. "] " .. d.Text .. " -> " .. p)
						local par = d.Parent and d.Parent.Parent or d.Parent
						if par then
							for _, sub in ipairs(par:GetDescendants()) do
								if sub:IsA("GuiButton") then
									table.insert(logs, "  BTN: " .. sub:GetFullName())
								end
							end
						end
					end
					break
				end
			end
		end
	end
	if added then
		box.Text = table.concat(logs, "\n")
	end
end

start.MouseButton1Click:Connect(function()
	active = not active
	start.Text = active and "STOP" or "START"
	if active then
		box.Text = "Scanning..."
		scan()
	end
end)

close.MouseButton1Click:Connect(function()
	alive = false
	active = false
	g:Destroy()
end)

task.spawn(function()
	while alive and g.Parent do
		task.wait(2)
		if alive and active then scan() end
	end
end)
