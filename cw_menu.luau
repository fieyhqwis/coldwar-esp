--[[
    CW Menu - Cold War [VIETNAM]
    ESP + Silent Aim + weather off + own native menu (no external libraries)
    RightShift = menu

    loadstring(game:HttpGet("https://raw.githubusercontent.com/fieyhqwis/coldwar-esp/main/cw_menu.luau"))()
]]

if getgenv().CW_CLEANUP then pcall(function() getgenv().CW_CLEANUP() end) end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Lighting   = game:GetService("Lighting")
local RS         = game:GetService("ReplicatedStorage")
local UIS        = game:GetService("UserInputService")
local lp         = Players.LocalPlayer

local CFG = {
    esp        = true,
    espMax     = 15,
    espMaxDist = 1500,
    espFont    = 13,
    showDist   = true,
    color      = Color3.fromRGB(255, 64, 64),
    colorVis   = Color3.fromRGB(60, 255, 120),

    silent     = true,
    fov        = 200,
    maxDist    = 900,
    teamCheck  = true,
    visCheck   = true,
    lead       = true,
    speedMult  = 2,

    weatherOff = true,
    tickHz     = 30,
}

--=========================================================
--  HELPERS
--=========================================================
local function teamKey(plr)
    local t = plr.Team
    if t then return "team:" .. t.Name end
    local tc = plr.TeamColor
    if tc then return "color:" .. tostring(tc) end
    return nil
end

local function isEnemy(plr)
    if plr == lp or plr.UserId == lp.UserId then return false end
    local a, b = teamKey(lp), teamKey(plr)
    if a == nil or b == nil then return true end
    return a ~= b
end

local function alive(plr)
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function partOf(char)
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if torso and torso:IsA("BasePart") then return torso end
    return char:FindFirstChild("HumanoidRootPart")
end

local visCache = {}
local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
visParams.IgnoreWater = true

local function isVisible(plr, pos)
    local now = tick()
    local c = visCache[plr]
    if c and (now - c.t) < 0.12 then return c.v end
    local cam = Workspace.CurrentCamera
    local visible = false
    if cam then
        local ex = {}
        if lp.Character then ex[#ex + 1] = lp.Character end
        if plr.Character then ex[#ex + 1] = plr.Character end
        visParams.FilterDescendantsInstances = ex
        visible = Workspace:Raycast(cam.CFrame.Position, pos - cam.CFrame.Position, visParams) == nil
    end
    visCache[plr] = { v = visible, t = now }
    return visible
end

--=========================================================
--  WORLD
--=========================================================
local function killWeather()
    local cam = Workspace.CurrentCamera
    if cam then
        for _, n in ipairs({ "__WeatherSky", "__WeatherAround" }) do
            local p = cam:FindFirstChild(n)
            if p then
                for _, d in ipairs(p:GetDescendants()) do
                    if d:IsA("ParticleEmitter") then
                        if d.Enabled then d.Enabled = false end
                        if d.Rate ~= 0 then d.Rate = 0 end
                    end
                end
            end
        end
    end
    for _, ch in ipairs(Lighting:GetChildren()) do
        if ch:IsA("Atmosphere") then
            if ch.Density ~= 0 then ch.Density = 0 end
            if ch.Haze ~= 0 then ch.Haze = 0 end
            if ch.Glare ~= 0 then ch.Glare = 0 end
        end
    end
end

for _, e in ipairs(Lighting:GetChildren()) do
    if e:IsA("PostEffect") then pcall(function() e.Enabled = false end) end
end
Lighting.FogStart = 0
Lighting.FogEnd = 1e9

--=========================================================
--  DRAWING
--=========================================================
local objs = {}
local function track(o) objs[#objs + 1] = o return o end
local pool = {}

local function makeEntry()
    local e = { lines = {} }
    for i = 1, 8 do
        e.lines[i] = track(Drawing.new("Line"))
        e.lines[i].Thickness = 1.2
        e.lines[i].Visible = false
    end
    e.dist = track(Drawing.new("Text"))
    e.dist.Center = true
    e.dist.Outline = true
    e.dist.Font = 2
    e.dist.Visible = false
    return e
end

local function hideEntry(e)
    for i = 1, 8 do e.lines[i].Visible = false end
    e.dist.Visible = false
end

local function destroyEntry(e)
    for i = 1, 8 do pcall(function() e.lines[i]:Remove() end) end
    pcall(function() e.dist:Remove() end)
end

local fovCircle = track(Drawing.new("Circle"))
fovCircle.Thickness = 1.5
fovCircle.Transparency = 0.55
fovCircle.Color = Color3.new(1, 1, 1)
fovCircle.Visible = false

--=========================================================
--  SILENT AIM
--=========================================================
local SA = { enabled = CFG.silent, fov = CFG.fov }

local function pickTarget(origin)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local best, bestDist = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        local okTeam = (not CFG.teamCheck) or isEnemy(plr)
        if okTeam and alive(plr) then
            local ch = plr.Character
            local part = ch and partOf(ch)
            if part then
                local pos = part.Position
                local d = (pos - origin).Magnitude
                if d <= CFG.maxDist and d < bestDist then
                    local sp = cam:WorldToViewportPoint(pos)
                    if sp.Z > 0 then
                        local dx, dy = sp.X - vp.X / 2, sp.Y - vp.Y / 2
                        if math.sqrt(dx * dx + dy * dy) <= SA.fov then
                            if (not CFG.visCheck) or isVisible(plr, pos) then
                                local hrp = ch:FindFirstChild("HumanoidRootPart")
                                best = { pos = pos, vel = hrp and hrp.AssemblyLinearVelocity or Vector3.zero }
                                bestDist = d
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

pcall(function()
    local B = RS:WaitForChild("Shared", 10)
    local Ball = B and B:WaitForChild("Ballistics", 10)
    local PC = Ball and require(Ball:WaitForChild("ProjectileCaster"))
    if PC and not PC.__cwMenuHooked then
        local orig = PC.Fire
        PC.__cwMenuOrig = orig
        PC.Fire = function(params)
            if SA.enabled and type(params) == "table" and params.Origin and params.Weapon then
                local w = params.Weapon
                local speed = (w.MuzzleSpeed or 900) * CFG.speedMult
                local t = pickTarget(params.Origin)
                if t then
                    local aim = t.pos
                    if CFG.lead then
                        local flight = (aim - params.Origin).Magnitude / math.max(speed, 1)
                        aim = aim + t.vel * flight
                    end
                    local delta = aim - params.Origin
                    if delta.Magnitude > 0.1 then params.Direction = delta.Unit end
                    local nw = {}
                    for k, v in pairs(w) do nw[k] = v end
                    nw.Gravity = 0
                    nw.K = 0
                    if CFG.speedMult ~= 1 then nw.MuzzleSpeed = speed end
                    params.Weapon = nw
                    params.Spread = 0
                end
            end
            return orig(params)
        end
        PC.__cwMenuHooked = true
        getgenv().CW_MENU_UNHOOK = function()
            if PC.__cwMenuOrig then
                PC.Fire = PC.__cwMenuOrig
                PC.__cwMenuHooked = false
                PC.__cwMenuOrig = nil
            end
        end
    end
end)

--=========================================================
--  NATIVE MENU
--=========================================================
local gui, main, dragging = nil, nil, false

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
    return c
end

local function stroke(parent, color)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(60, 60, 70)
    s.Thickness = 1
    s.Parent = parent
    return s
end

local function makeButton(parent, text, x, y, w, h, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, h)
    b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = color or Color3.fromRGB(40, 40, 48)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 13
    b.Font = Enum.Font.GothamMedium
    b.AutoButtonColor = true
    b.Parent = parent
    corner(b, 5)
    return b
end

local refresh -- forward

local function buildMenu()
    local ok, err = pcall(function()
        gui = Instance.new("ScreenGui")
        gui.Name = "CW_MENU"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 999
        local okc = pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not okc then gui.Parent = lp:WaitForChild("PlayerGui") end

        main = Instance.new("Frame")
        main.Size = UDim2.fromOffset(300, 330)
        main.Position = UDim2.fromOffset(80, 120)
        main.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
        main.BorderSizePixel = 0
        main.Active = true
        main.Parent = gui
        corner(main, 8)
        stroke(main)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -30, 0, 30)
        title.Position = UDim2.fromOffset(10, 0)
        title.BackgroundTransparency = 1
        title.Text = "CW  |  cold war"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 14
        title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = main

        local close = makeButton(main, "x", 272, 5, 22, 22, Color3.fromRGB(60, 30, 30))
        close.MouseButton1Click:Connect(function() main.Visible = false end)

        -- drag
        local startPos, startMouse
        title.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                startPos = main.Position
                startMouse = input.Position
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local d = input.Position - startMouse
                main.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
            end
        end)
        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)

        local y = 38
        local function row(label)
            local l = Instance.new("TextLabel")
            l.Size = UDim2.fromOffset(160, 24)
            l.Position = UDim2.fromOffset(12, y)
            l.BackgroundTransparency = 1
            l.Text = label
            l.TextColor3 = Color3.fromRGB(200, 200, 210)
            l.TextSize = 13
            l.Font = Enum.Font.GothamMedium
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = main
            return l
        end

        -- ESP
        row("ESP")
        local espBtn = makeButton(main, "ON", 190, y, 44, 22)
        local distBtn = makeButton(main, tostring(CFG.espMaxDist), 240, y, 48, 22)
        y = y + 30

        -- Distance +/- handled by buttons
        local distMinus = makeButton(main, "-", 240, y, 20, 20)
        local distPlus = makeButton(main, "+", 268, y, 20, 20)
        local distLbl = row("distance")
        distLbl.Position = UDim2.fromOffset(12, y)
        y = y + 30

        -- Silent
        row("Silent Aim")
        local saBtn = makeButton(main, "ON", 190, y, 44, 22)
        y = y + 30

        -- FOV
        row("FOV")
        local fovLbl = makeButton(main, tostring(CFG.fov), 190, y, 44, 22, Color3.fromRGB(30, 30, 36))
        local fovMinus = makeButton(main, "-", 240, y, 20, 20)
        local fovPlus = makeButton(main, "+", 268, y, 20, 20)
        y = y + 30

        -- Speed
        row("Bullet speed x")
        local spdLbl = makeButton(main, tostring(CFG.speedMult), 190, y, 44, 22, Color3.fromRGB(30, 30, 36))
        local spdMinus = makeButton(main, "-", 240, y, 20, 20)
        local spdPlus = makeButton(main, "+", 268, y, 20, 20)
        y = y + 30

        -- Wall check
        row("Visible check")
        local wallBtn = makeButton(main, "ON", 190, y, 44, 22)
        y = y + 30

        -- Weather
        row("Weather off")
        local wBtn = makeButton(main, "ON", 190, y, 44, 22)
        y = y + 30

        local hint = Instance.new("TextLabel")
        hint.Size = UDim2.new(1, -20, 0, 20)
        hint.Position = UDim2.fromOffset(10, y + 6)
        hint.BackgroundTransparency = 1
        hint.Text = "RightShift - menu"
        hint.TextColor3 = Color3.fromRGB(120, 120, 135)
        hint.TextSize = 11
        hint.Font = Enum.Font.Gotham
        hint.TextXAlignment = Enum.TextXAlignment.Left
        hint.Parent = main

        refresh = function()
            espBtn.Text = CFG.esp and "ON" or "OFF"
            espBtn.BackgroundColor3 = CFG.esp and Color3.fromRGB(30, 70, 40) or Color3.fromRGB(60, 30, 30)
            saBtn.Text = SA.enabled and "ON" or "OFF"
            saBtn.BackgroundColor3 = SA.enabled and Color3.fromRGB(30, 70, 40) or Color3.fromRGB(60, 30, 30)
            wallBtn.Text = CFG.visCheck and "ON" or "OFF"
            wallBtn.BackgroundColor3 = CFG.visCheck and Color3.fromRGB(30, 70, 40) or Color3.fromRGB(60, 30, 30)
            wBtn.Text = CFG.weatherOff and "ON" or "OFF"
            wBtn.BackgroundColor3 = CFG.weatherOff and Color3.fromRGB(30, 70, 40) or Color3.fromRGB(60, 30, 30)
            distBtn.Text = tostring(CFG.espMaxDist)
            fovLbl.Text = tostring(CFG.fov)
            spdLbl.Text = tostring(CFG.speedMult)
            SA.fov = CFG.fov
        end

        espBtn.MouseButton1Click:Connect(function() CFG.esp = not CFG.esp refresh() end)
        saBtn.MouseButton1Click:Connect(function() SA.enabled = not SA.enabled refresh() end)
        wallBtn.MouseButton1Click:Connect(function() CFG.visCheck = not CFG.visCheck refresh() end)
        wBtn.MouseButton1Click:Connect(function() CFG.weatherOff = not CFG.weatherOff refresh() end)

        distMinus.MouseButton1Click:Connect(function()
            CFG.espMaxDist = math.max(100, CFG.espMaxDist - 200) refresh()
        end)
        distPlus.MouseButton1Click:Connect(function()
            CFG.espMaxDist = math.min(5000, CFG.espMaxDist + 200) refresh()
        end)
        fovMinus.MouseButton1Click:Connect(function()
            CFG.fov = math.max(20, CFG.fov - 20) refresh()
        end)
        fovPlus.MouseButton1Click:Connect(function()
            CFG.fov = math.min(800, CFG.fov + 20) refresh()
        end)
        spdMinus.MouseButton1Click:Connect(function()
            CFG.speedMult = math.max(1, CFG.speedMult - 1) refresh()
        end)
        spdPlus.MouseButton1Click:Connect(function()
            CFG.speedMult = math.min(10, CFG.speedMult + 1) refresh()
        end)

        refresh()
    end)
    if not ok then warn("[CW Menu] build failed: " .. tostring(err)) end
end

local keyConn = UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if main then main.Visible = not main.Visible end
    end
end)

buildMenu()

--=========================================================
--  LOOP
--=========================================================
local HEAD_OFF = Vector3.new(0, 2.0, 0)
local FEET_OFF = Vector3.new(0, 2.6, 0)
local candidates = {}
local used = {}
local accum = 0
local running = true
local lastWeather = 0
local FRAME_DT = 1 / CFG.tickHz

local function drawCorners(e, x, y, w, h, color)
    local cx = h * 0.22
    local x2, y2 = x + w, y + h
    local L = e.lines
    L[1].From, L[1].To = Vector2.new(x, y), Vector2.new(x + cx, y)
    L[2].From, L[2].To = Vector2.new(x, y), Vector2.new(x, y + cx)
    L[3].From, L[3].To = Vector2.new(x2, y), Vector2.new(x2 - cx, y)
    L[4].From, L[4].To = Vector2.new(x2, y), Vector2.new(x2, y + cx)
    L[5].From, L[5].To = Vector2.new(x, y2), Vector2.new(x + cx, y2)
    L[6].From, L[6].To = Vector2.new(x, y2), Vector2.new(x, y2 - cx)
    L[7].From, L[7].To = Vector2.new(x2, y2), Vector2.new(x2 - cx, y2)
    L[8].From, L[8].To = Vector2.new(x2, y2), Vector2.new(x2, y2 - cx)
    for i = 1, 8 do
        L[i].Color = color
        L[i].Visible = true
    end
end

local conn = RunService.Heartbeat:Connect(function(dt)
    if not running then return end
    accum = accum + dt
    if accum < FRAME_DT then return end
    accum = 0

    local cam = Workspace.CurrentCamera
    if not cam then return end
    local now = tick()

    if CFG.weatherOff and (now - lastWeather) > 0.5 then
        lastWeather = now
        killWeather()
    end

    local vp = cam.ViewportSize
    fovCircle.Visible = SA.enabled
    if SA.enabled then
        fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        fovCircle.Radius = SA.fov
    end

    if not CFG.esp then
        for _, e in pairs(pool) do hideEntry(e) end
        return
    end

    local eye = cam.CFrame.Position
    table.clear(candidates)

    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) and alive(plr) then
            local ch = plr.Character
            local hrp = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso"))
            if hrp then
                local pos = hrp.Position
                local d = (pos - eye).Magnitude
                if d <= CFG.espMaxDist then
                    candidates[#candidates + 1] = { plr = plr, pos = pos, dist = d }
                end
            end
        end
    end

    if #candidates > CFG.espMax then
        table.sort(candidates, function(a, b) return a.dist < b.dist end)
        for i = #candidates, CFG.espMax + 1, -1 do candidates[i] = nil end
    end

    table.clear(used)

    for _, c in ipairs(candidates) do
        local e = pool[c.plr]
        if not e then
            e = makeEntry()
            pool[c.plr] = e
        end
        used[c.plr] = true

        local head = cam:WorldToViewportPoint(c.pos + HEAD_OFF)
        local feet = cam:WorldToViewportPoint(c.pos - FEET_OFF)
        local mid = cam:WorldToViewportPoint(c.pos)

        if mid.Z > 0 and head.Z > 0 then
            local h = math.max(math.abs(head.Y - feet.Y), 8)
            local w = h * 0.52
            local x = mid.X - w / 2
            local y = mid.Y - h / 2

            if x + w > 0 and x < vp.X and y + h > 0 and y < vp.Y then
                local color = isVisible(c.plr, c.pos + HEAD_OFF) and CFG.colorVis or CFG.color
                drawCorners(e, x, y, w, h, color)
                if CFG.showDist then
                    e.dist.Text = string.format("%dm", math.floor(c.dist))
                    e.dist.Size = CFG.espFont
                    e.dist.Color = color
                    e.dist.Position = Vector2.new(x + w / 2, y + h + 2)
                    e.dist.Visible = true
                else
                    e.dist.Visible = false
                end
            else
                hideEntry(e)
            end
        else
            hideEntry(e)
        end
    end

    for plr, e in pairs(pool) do
        if not used[plr] then hideEntry(e) end
        if not plr.Parent then
            destroyEntry(e)
            pool[plr] = nil
        end
    end
end)

getgenv().CW_CLEANUP = function()
    running = false
    if conn then pcall(function() conn:Disconnect() end) conn = nil end
    if keyConn then pcall(function() keyConn:Disconnect() end) keyConn = nil end
    for _, e in pairs(pool) do destroyEntry(e) end
    table.clear(pool)
    for _, o in ipairs(objs) do pcall(function() o:Remove() end) end
    table.clear(objs)
    if gui then pcall(function() gui:Destroy() end) gui = nil end
    if getgenv().CW_MENU_UNHOOK then pcall(getgenv().CW_MENU_UNHOOK) end
    print("[CW Menu] cleaned")
end

print("[CW Menu] loaded | RightShift = menu")
