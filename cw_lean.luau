--[[
    CW Lean - Cold War [VIETNAM]
    No GUI. No downloads. No external libraries.
    ESP + Silent Aim + weather off.

    loadstring(game:HttpGet("https://raw.githubusercontent.com/fieyhqwis/coldwar-esp/main/cw_lean.luau"))()
]]

local STATE = STATE or {
    onCleanup = function() end,
    connect = function(sig, fn) return sig:Connect(fn) end,
}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Lighting   = game:GetService("Lighting")
local RS         = game:GetService("ReplicatedStorage")
local lp         = Players.LocalPlayer

local CFG = {
    esp          = true,
    espMax       = 15,
    espMaxDist   = 1500,
    espFont      = 13,
    color        = Color3.fromRGB(255, 64, 64),
    colorVisible = Color3.fromRGB(60, 255, 120),
    showBox      = true,
    showDist     = true,

    silent       = true,
    fov          = 200,
    maxDist      = 900,
    hitPart      = "Head",
    teamCheck    = true,
    visCheck     = true,
    lead         = true,
    speedMult    = 2,
    hitchance    = 100,

    tickHz       = 30,
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

local function partOf(char, mode)
    local names
    if mode == "Torso" then
        names = { "Torso", "UpperTorso", "HumanoidRootPart" }
    elseif mode == "Random" then
        names = { "Head", "Torso", "UpperTorso", "HumanoidRootPart" }
        local n = names[math.random(1, #names)]
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    else
        names = { "Head" }
    end
    for _, n in ipairs(names) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
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
--  WEATHER OFF (2x per second)
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

local function killEffects()
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("PostEffect") then
            pcall(function() e.Enabled = false end)
        end
    end
    Lighting.FogStart = 0
    Lighting.FogEnd = 1e9
end

killEffects()

--=========================================================
--  DRAWING
--=========================================================
local objs = {}
local function track(o) objs[#objs + 1] = o return o end

local pool = {}

local function makeEntry()
    local e = { lines = {}, hasDist = false }
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

local previewDone = false

STATE.onCleanup(function()
    for _, o in ipairs(objs) do pcall(function() o:Remove() end) end
    table.clear(objs)
    if getgenv().CW_LEAN_UNHOOK then pcall(getgenv().CW_LEAN_UNHOOK) end
end)

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
            local part = ch and partOf(ch, CFG.hitPart)
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
                                best = {
                                    pos = pos,
                                    vel = hrp and hrp.AssemblyLinearVelocity or Vector3.zero,
                                }
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
    local B = RS:WaitForChild("Shared"):WaitForChild("Ballistics", 10)
    local PC = require(B:WaitForChild("ProjectileCaster"))
    if PC.__leanHooked then return end
    local orig = PC.Fire
    PC.__leanOrig = orig
    PC.Fire = function(params)
        if SA.enabled and type(params) == "table" and params.Origin and params.Weapon then
            if math.random(1, 100) <= CFG.hitchance then
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
        end
        return orig(params)
    end
    PC.__leanHooked = true
    getgenv().CW_LEAN_UNHOOK = function()
        if PC.__leanOrig then
            PC.Fire = PC.__leanOrig
            PC.__leanHooked = false
            PC.__leanOrig = nil
        end
    end
end)

--=========================================================
--  LOOP
--=========================================================
local HEAD_OFF = Vector3.new(0, 2.0, 0)
local FEET_OFF = Vector3.new(0, 2.6, 0)
local candidates = {}
local used = {}
local accum = 0
local FRAME_DT = 1 / CFG.tickHz
local lastWeather = 0

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

STATE.connect(RunService.Heartbeat, function(dt)
    accum = accum + dt
    if accum < FRAME_DT then return end
    accum = 0

    local cam = Workspace.CurrentCamera
    if not cam then return end
    local now = tick()

    if (now - lastWeather) > 0.5 then
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
                local visible = isVisible(c.plr, c.pos + HEAD_OFF)
                local color = visible and CFG.colorVisible or CFG.color

                if CFG.showBox then
                    drawCorners(e, x, y, w, h, color)
                else
                    for i = 1, 8 do e.lines[i].Visible = false end
                end

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

    if not previewDone then
        previewDone = true
        print("[CW Lean] loaded | esp=" .. tostring(CFG.esp) .. " | silent=" .. tostring(SA.enabled))
    end
end)
