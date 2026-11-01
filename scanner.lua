
local P=game:GetService("Players")
local pl=P.LocalPlayer
local pg=pl:WaitForChild("PlayerGui")

local old=pg:FindFirstChild("NS")
if old then old:Destroy() end

local g=Instance.new("ScreenGui",pg)
g.Name="NS"
g.ResetOnSpawn=false

local f=Instance.new("Frame",g)
f.Size=UDim2.fromOffset(260,125)
f.Position=UDim2.new(.5,-130,.3,0)
f.BackgroundColor3=Color3.fromRGB(30,35,48)
f.Active=true
f.Draggable=true

local function btn(t,x,w)
 local b=Instance.new("TextButton",f)
 b.Size=UDim2.fromOffset(w,32)
 b.Position=UDim2.fromOffset(x,82)
 b.Text=t
 b.TextSize=14
 return b
end

local info=Instance.new("TextLabel",f)
info.Size=UDim2.new(1,-10,0,65)
info.Position=UDim2.fromOffset(5,5)
info.BackgroundTransparency=1
info.TextColor3=Color3.new(1,1,1)
info.TextSize=13
info.TextWrapped=true
info.Text="Nearest candidate: Waiting"

local start=btn("START",5,120)
local close=btn("CLOSE",135,120)

local active=false
local alive=true

local function scan()
 local c=pl.Character
 local r=c and c:FindFirstChild("HumanoidRootPart")
 if not r then return end

 local best,dist=nil,math.huge

 for _,m in ipairs(workspace:GetDescendants()) do
  if m:IsA("Model") and m~=c
  and not P:GetPlayerFromCharacter(m) then
   local root=m:FindFirstChild("HumanoidRootPart",true)
   if root and root:IsA("BasePart") then
    local d=(r.Position-root.Position).Magnitude
    if d<dist then best,dist=m,d end
   end
  end
 end

 if best then
  info.Text="Candidate: "..best.Name..
  "\nDistance: "..math.floor(dist).." studs"
 else
  info.Text="No candidate found"
 end
end

start.MouseButton1Click:Connect(function()
 active=not active
 start.Text=active and "STOP" or "START"
 if active then scan() end
end)

close.MouseButton1Click:Connect(function()
 alive=false
 active=false
 g:Destroy()
end)

task.spawn(function()
 while alive and g.Parent do
  task.wait(4)
  if alive and active then scan() end
 end
end)
