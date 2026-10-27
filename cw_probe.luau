--[[
    CW Probe - finds what freezes the client.
    Writes a marker file after every step. If the game freezes,
    the last line in the file is the culprit.

    loadstring(game:HttpGet("https://raw.githubusercontent.com/fieyhqwis/coldwar-esp/main/cw_probe.luau"))()
]]

local FILE = "cw_probe.txt"
local lines = {}

local function mark(tag, extra)
    local t = os.date("%H:%M:%S")
    local msg = string.format("%s  %s %s", t, tag, extra or "")
    lines[#lines + 1] = msg
    pcall(function() writefile(FILE, table.concat(lines, "\n")) end)
    print("[probe] " .. msg)
end

pcall(function() writefile(FILE, "") end)
mark("START", "script began")

-- 1. basic services
task.wait(1)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local lp = Players.LocalPlayer
mark("STEP1", "services ok | players=" .. #Players:GetPlayers())

-- 2. Drawing availability
task.wait(1)
local okDraw, drawErr = pcall(function()
    local l = Drawing.new("Line")
    l.Visible = false
    l:Remove()
end)
mark("STEP2", "drawing=" .. tostring(okDraw) .. " err=" .. tostring(drawErr))
if not okDraw then
    mark("ABORT", "no Drawing")
    return
end

-- 3. create 20 boxes worth of objects (200 objects)
task.wait(2)
local made = 0
pcall(function()
    local keep = {}
    for i = 1, 20 do
        local e = {}
        for j = 1, 8 do
            local l = Drawing.new("Line")
            l.Thickness = 1.2
            l.Visible = false
            e[#e + 1] = l
        end
        local t = Drawing.new("Text")
        t.Visible = false
        e[#e + 1] = t
        keep[#keep + 1] = e
        made = made + #e
    end
    for _, e in ipairs(keep) do
        for _, o in ipairs(e) do pcall(function() o:Remove() end) end
    end
end)
mark("STEP3", "created/removed objects=" .. made)

-- 4. player scan + world scan
task.wait(2)
local okScan = pcall(function()
    local n = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr.Character
        if ch then
            local hrp = ch:FindFirstChild("HumanoidRootPart")
            if hrp then n = n + 1 end
        end
    end
    return n
end)
mark("STEP4", "scan ok=" .. tostring(okScan))

-- 5. raycast
task.wait(2)
local okRay = pcall(function()
    local cam = Workspace.CurrentCamera
    local p = cam.CFrame.Position + cam.CFrame.LookVector * 100
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { lp.Character }
    Workspace:Raycast(cam.CFrame.Position, p - cam.CFrame.Position, rp)
end)
mark("STEP5", "raycast ok=" .. tostring(okRay))

-- 6. lighting: effects only
task.wait(2)
pcall(function()
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("PostEffect") then e.Enabled = false end
    end
end)
mark("STEP6", "posteffects disabled")

-- 7. lighting: shadows (suspected)
task.wait(3)
pcall(function() Lighting.GlobalShadows = false end)
mark("STEP7", "globalshadows=false")

-- 8. fog
task.wait(2)
pcall(function()
    Lighting.FogStart = 0
    Lighting.FogEnd = 1e9
end)
mark("STEP8", "fog off")

-- 9. weather destroy
task.wait(3)
pcall(function()
    local cam = Workspace.CurrentCamera
    for _, n in ipairs({ "__WeatherSky", "__WeatherAround" }) do
        local p = cam:FindFirstChild(n)
        if p then p:Destroy() end
    end
end)
mark("STEP9", "weather destroyed")

-- 10. heartbeat loop, no drawing
task.wait(3)
local frames = 0
local conn
pcall(function()
    conn = RunService.Heartbeat:Connect(function()
        frames = frames + 1
    end)
end)
task.wait(3)
pcall(function() if conn then conn:Disconnect() end end)
mark("STEP10", "heartbeat frames in 3s=" .. frames)

-- 11. heartbeat loop WITH drawing
task.wait(2)
local line = Drawing.new("Line")
line.Thickness = 1
line.Visible = false
local draws = 0
local conn2
pcall(function()
    conn2 = RunService.Heartbeat:Connect(function()
        draws = draws + 1
        local vp = Workspace.CurrentCamera.ViewportSize
        line.From = Vector2.new(0, 0)
        line.To = Vector2.new(vp.X, vp.Y)
    end)
end)
task.wait(3)
pcall(function()
    if conn2 then conn2:Disconnect() end
    line:Remove()
end)
mark("STEP11", "draw ticks in 3s=" .. draws .. " (expect ~180)")

-- 12. projectile hook
task.wait(2)
local okHook, hookErr = pcall(function()
    local RS = game:GetService("ReplicatedStorage")
    local B = RS:WaitForChild("Shared", 8)
    local Ball = B and B:WaitForChild("Ballistics", 8)
    local PC = Ball and require(Ball:WaitForChild("ProjectileCaster"))
    if PC and not PC.__probeHooked then
        local orig = PC.Fire
        PC.Fire = function(p)
            return orig(p)
        end
        PC.__probeHooked = true
    end
end)
mark("STEP12", "hook=" .. tostring(okHook) .. " err=" .. tostring(hookErr))

task.wait(3)
mark("DONE", "everything survived | fps=" .. tostring(math.floor(1 / math.max(RunService.RenderStepped:Wait(), 1e-6))))
