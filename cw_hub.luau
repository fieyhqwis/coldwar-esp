--[[
    Cold War [VIETNAM] - CW Hub
    ESP (только враги) + Silent Aim + погода/эффекты + Obsidian GUI

    loadstring(game:HttpGet("https://raw.githubusercontent.com/fieyhqwis/coldwar-esp/main/cw_hub.luau"))()
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

--=========================================================
--  НАСТРОЙКИ
--=========================================================
local Settings = {
    esp       = true,
    espColor  = Color3.fromRGB(255, 64, 64),
    espMax    = 40,
    arrows    = true,
    arrowSize = 11,
    showDist  = true,
    silent    = false,
    fov       = 160,
    showFov   = true,
    smooth    = false,
}

--=========================================================
--  МИР: СНЕГ, ТУМАН, ЭФФЕКТЫ, ТРАВА
--=========================================================
local weather = { emitters = {} }
local fx = { effects = {} }

-- Игра постоянно перезапускает погоду, поэтому чистим каждый кадр, а не по таймеру.
local function killWeather()
    local cam = Workspace.CurrentCamera
    if cam then
        local sky = cam:FindFirstChild("__WeatherSky")
        if sky then pcall(function() sky:Destroy() end) end
        local around = cam:FindFirstChild("__WeatherAround")
        if around then pcall(function() around:Destroy() end) end
    end
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Atmosphere") then
            if child.Density ~= 0 then child.Density = 0 end
            if child.Haze ~= 0 then child.Haze = 0 end
            if child.Glare ~= 0 then child.Glare = 0 end
        end
    end
end

local function killEffects()
    for _, obj in ipairs(Lighting:GetChildren()) do
        local cls = obj.ClassName
        if cls == "BloomEffect" or cls == "BlurEffect" or cls == "SunRaysEffect"
            or cls == "ColorCorrectionEffect" or cls == "DepthOfFieldEffect" then
            if fx.effects[obj] == nil then fx.effects[obj] = obj.Enabled end
            pcall(function() obj.Enabled = false end)
        end
    end
    if fx.shadows == nil then fx.shadows = Lighting.GlobalShadows end
    pcall(function() Lighting.GlobalShadows = false end)

    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then
        if not fx.atmo then
            fx.atmo = atmo
            fx.atmoDensity = atmo.Density
            fx.atmoHaze = atmo.Haze
            fx.atmoGlare = atmo.Glare
        end
        atmo.Density = 0
        atmo.Haze = 0
        atmo.Glare = 0
    end
    if not fx.fogStart then
        fx.fogStart = Lighting.FogStart
        fx.fogEnd = Lighting.FogEnd
    end
    Lighting.FogStart = 0
    Lighting.FogEnd = 1e9

    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        if fx.waveSize == nil then
            fx.waveSize = terrain.WaterWaveSize
            fx.waveSpeed = terrain.WaterWaveSpeed
            fx.reflectance = terrain.WaterReflectance
            fx.transparency = terrain.WaterTransparency
        end
        pcall(function()
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
        end)
    end
end

local function applyQuality()
    if setfflag then
        pcall(function() setfflag("DFIntDebugFRMQualityLevelOverride", 1) end)
    end
    pcall(function()
        local ugs = game:GetService("UserSettings"):GetService("UserGameSettings")
        ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)
end

applyQuality()
killEffects()
killWeather()

-- погода пересоздаётся при смене карты - держим под контролем
local lastWeather = 0
local lastZoom = 0

--=========================================================
--  ЗУМ
--=========================================================
local function applyZoom()
    lp.CameraMinZoomDistance = 0.5
    if lp.CameraMaxZoomDistance < 400 then
        lp.CameraMaxZoomDistance = 400
    end
end
applyZoom()

--=========================================================
--  DRAWING
--=========================================================
local objs = {}
local function track(o) objs[#objs + 1] = o return o end

STATE.onCleanup(function()
    for _, o in ipairs(objs) do pcall(function() o:Remove() end) end
    table.clear(objs)
    for e, was in pairs(weather.emitters) do
        if e and e.Parent then pcall(function() e.Enabled = was end) end
    end
    for e, was in pairs(fx.effects) do
        if e and e.Parent then pcall(function() e.Enabled = was end) end
    end
    if fx.atmo and fx.atmo.Parent then
        pcall(function()
            fx.atmo.Density = fx.atmoDensity
            fx.atmo.Haze = fx.atmoHaze
            fx.atmo.Glare = fx.atmoGlare
        end)
    end
    pcall(function()
        Lighting.FogStart = fx.fogStart or 0
        Lighting.FogEnd = fx.fogEnd or 100000
        Lighting.GlobalShadows = fx.shadows
    end)
    if getgenv().CW_UNHOOK then pcall(getgenv().CW_UNHOOK) end
end)

--=========================================================
--  ESP: РАМКИ + СТРЕЛКИ
--=========================================================
local pool = {}

local function makeEntry()
    local e = { lines = {}, label = "" }
    for i = 1, 8 do e.lines[i] = track(Drawing.new("Line")) end
    e.arrow = track(Drawing.new("Triangle"))
    e.text = track(Drawing.new("Text"))
    for _, l in ipairs(e.lines) do
        l.Thickness = 1.2
        l.Visible = false
    end
    e.arrow.Thickness = 1
    e.arrow.Filled = true
    e.arrow.Visible = false
    e.text.Center = true
    e.text.Outline = true
    e.text.Font = 2
    e.text.Size = 12
    e.text.Visible = false
    e.active = false
    return e
end

local function hideEntry(e)
    for _, l in ipairs(e.lines) do l.Visible = false end
    e.arrow.Visible = false
    e.text.Visible = false
    e.active = false
end

local function destroyEntry(e)
    for _, l in ipairs(e.lines) do pcall(function() l:Remove() end) end
    pcall(function() e.arrow:Remove() end)
    pcall(function() e.text:Remove() end)
end

local fovCircle = track(Drawing.new("Circle"))
fovCircle.Thickness = 1.5
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Transparency = 0.6
fovCircle.Visible = false

--=========================================================
--  SILENT AIM
--=========================================================
local silentState = { enabled = false, fov = 160 }

local function headPos(plr)
    local char = plr.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head.Position end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position + Vector3.new(0, 1.5, 0) end
    return nil
end

local function isEnemy(plr)
    if plr == lp then return false end
    local myTeam = lp.Team
    if not myTeam then return true end
    return plr.Team ~= myTeam
end

local function alive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function pickTarget(origin, lookDir)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local best, bestScore = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) and alive(plr) then
            local hp = headPos(plr)
            if hp then
                local sp = cam:WorldToViewportPoint(hp)
                if sp.Z > 0 then
                    local dx, dy = sp.X - vp.X / 2, sp.Y - vp.Y / 2
                    local screenDist = math.sqrt(dx * dx + dy * dy)
                    if screenDist <= silentState.fov then
                        local worldDist = (hp - origin).Magnitude
                        if worldDist < bestScore then
                            best, bestScore = { plr = plr, pos = hp }, worldDist
                        end
                    end
                end
            end
        end
    end
    return best
end

local function installSilentAim()
    local ok, err = pcall(function()
        local Ballistics = RS:WaitForChild("Shared"):WaitForChild("Ballistics")
        local PC = require(Ballistics:WaitForChild("ProjectileCaster"))
        if PC.__cwHooked then return end

        local original = PC.Fire
        PC.__cwOriginal = original

        PC.Fire = function(params)
            if silentState.enabled and type(params) == "table" and params.Origin and params.Direction then
                local target = pickTarget(params.Origin, params.Direction)
                if target then
                    local origin = params.Origin
                    local dest = target.pos
                    local delta = dest - origin
                    local dist = delta.Magnitude
                    if dist > 0.5 then
                        local dir = delta.Unit
                        local weapon = params.Weapon
                        local speed = weapon and weapon.MuzzleSpeed
                        local grav = weapon and weapon.Gravity
                        if type(speed) == "number" and speed > 1 and type(grav) == "number" and grav > 0 then
                            local t = dist / speed
                            local drop = 0.5 * grav * t * t
                            dir = (delta + Vector3.new(0, drop, 0)).Unit
                        end
                        params.Direction = dir
                    end
                end
            end
            return original(params)
        end
        PC.__cwHooked = true
        getgenv().CW_UNHOOK = function()
            if PC.__cwOriginal then
                PC.Fire = PC.__cwOriginal
                PC.__cwHooked = false
                PC.__cwOriginal = nil
            end
        end
    end)
    if not ok then
        warn("[CW] silent aim hook failed: " .. tostring(err))
    end
end

installSilentAim()

--=========================================================
--  ГЛАВНЫЙ ЦИКЛ
--=========================================================
local HEAD_OFF = Vector3.new(0, 2.0, 0)
local FEET_OFF = Vector3.new(0, 2.6, 0)
local candidates = {}
local used = {}
local accum = 0
local FRAME_DT = 1 / 60

local function drawBox(e, x, y, w, h, color)
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

local function drawArrow(e, cx, cy, ang, size, color)
    local tipX = cx + math.cos(ang) * size
    local tipY = cy + math.sin(ang) * size
    local baseX = cx + math.cos(ang) * (size * 0.35)
    local baseY = cy + math.sin(ang) * (size * 0.35)
    local px, py = -math.sin(ang), math.cos(ang)
    e.arrow.PointA = Vector2.new(tipX, tipY)
    e.arrow.PointB = Vector2.new(baseX + px * size * 0.55, baseY + py * size * 0.55)
    e.arrow.PointC = Vector2.new(baseX - px * size * 0.55, baseY - py * size * 0.55)
    e.arrow.Color = color
    e.arrow.Visible = true
end

local function loop(dt)
    accum = accum + dt
    if accum < FRAME_DT then return end
    accum = 0

    local cam = Workspace.CurrentCamera
    if not cam then return end
    local now = tick()

    if now - lastZoom > 1 then
        lastZoom = now
        applyZoom()
    end
    killWeather()

    local vp = cam.ViewportSize

    -- FOV круг
    fovCircle.Visible = Settings.silent and Settings.showFov
    if fovCircle.Visible then
        fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        fovCircle.Radius = silentState.fov
    end

    if not Settings.esp then
        for _, e in next, pool do hideEntry(e) end
        return
    end

    local eye = cam.CFrame.Position
    table.clear(candidates)

    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) and alive(plr) then
            local char = plr.Character
            local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
            if hrp then
                local pos = hrp.Position
                candidates[#candidates + 1] = { plr = plr, pos = pos, dist = (pos - eye).Magnitude }
            end
        end
    end

    if #candidates > Settings.espMax then
        table.sort(candidates, function(a, b) return a.dist < b.dist end)
        for i = #candidates, Settings.espMax + 1, -1 do candidates[i] = nil end
    end

    table.clear(used)

    for _, c in next, candidates do
        local e = pool[c.plr]
        if not e then
            e = makeEntry()
            pool[c.plr] = e
        end
        used[c.plr] = true

        local head = cam:WorldToViewportPoint(c.pos + HEAD_OFF)
        local feet = cam:WorldToViewportPoint(c.pos - FEET_OFF)
        local mid = cam:WorldToViewportPoint(c.pos)

        local onScreen = mid.Z > 0 and head.Z > 0
        local color = Settings.espColor

        if onScreen then
            local rawH = math.abs(head.Y - feet.Y)
            local h = math.max(rawH, 8)
            local w = h * 0.52
            local x = mid.X - w / 2
            local y = mid.Y - h / 2
            local inView = x + w > 0 and x < vp.X and y + h > 0 and y < vp.Y

            if inView then
                drawBox(e, x, y, w, h, color)
                e.arrow.Visible = false
                e.active = true
                if Settings.showDist then
                    e.text.Text = string.format("%dm", math.floor(c.dist))
                    e.text.Position = Vector2.new(x + w / 2, y + h + 2)
                    e.text.Color = color
                    e.text.Visible = true
                else
                    e.text.Visible = false
                end
            else
                onScreen = false
            end
        end

        if not onScreen then
            for i = 1, 8 do e.lines[i].Visible = false end
            e.text.Visible = false
            if Settings.arrows then
                local sp = cam:WorldToViewportPoint(c.pos)
                local cx, cy = vp.X / 2, vp.Y / 2
                local dx, dy = sp.X - cx, sp.Y - cy
                if sp.Z <= 0 then dx, dy = -dx, -dy end
                if math.abs(dx) < 1 and math.abs(dy) < 1 then dx, dy = 0, -1 end
                local ang = math.atan2(dy, dx)
                local r = math.min(vp.X, vp.Y) * 0.42
                local ax, ay = cx + math.cos(ang) * r, cy + math.sin(ang) * r
                ax = math.clamp(ax, 20, vp.X - 20)
                ay = math.clamp(ay, 20, vp.Y - 20)
                drawArrow(e, ax, ay, ang, Settings.arrowSize, color)
                e.active = true
            else
                e.arrow.Visible = false
                e.active = false
            end
        end
    end

    for plr, e in next, pool do
        if not used[plr] then hideEntry(e) end
        if not plr.Parent then
            destroyEntry(e)
            pool[plr] = nil
        end
    end
end

STATE.connect(RunService.Heartbeat, loop)

--=========================================================
--  GUI: OBSIDIAN
--=========================================================
local guiOk, guiErr = pcall(function()
    local Library = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()

    local Window = Library:CreateWindow({
        Title = "CW Hub",
        Footer = "cold war [vietnam]",
        Size = UDim2.fromOffset(620, 480),
        NotifySide = "Right",
        ShowCustomCursor = true,
        AutoShow = true,
    })

    Library:OnUnload(function()
        if getgenv().CW_LIBRARY == Library then
            getgenv().CW_LIBRARY = nil
        end
    end)
    STATE.onCleanup(function()
        pcall(function() Library:Unload() end)
    end)

    local Visual = Window:AddTab("Visuals", nil)
    local Combat = Window:AddTab("Combat", nil)

    local espGroup = Visual:AddLeftGroupbox("ESP")
    espGroup:AddToggle("EspOn", {
        Text = "ESP",
        Default = true,
        Callback = function(v) Settings.esp = v end,
    })
    espGroup:AddToggle("EspArrows", {
        Text = "Стрелки за спиной",
        Default = true,
        Callback = function(v) Settings.arrows = v end,
    })
    espGroup:AddSlider("EspMax", {
        Text = "Максимум целей",
        Min = 5, Max = 80, Default = 40, Rounding = 0,
        Callback = function(v) Settings.espMax = v end,
    })
    espGroup:AddToggle("EspDist", {
        Text = "Дистанция под рамкой",
        Default = true,
        Callback = function(v) Settings.showDist = v end,
    })
    espGroup:AddSlider("EspArrowSize", {
        Text = "Размер стрелки",
        Min = 5, Max = 30, Default = 11, Rounding = 0,
        Callback = function(v) Settings.arrowSize = v end,
    })
    espGroup:AddLabel("Цвет ESP"):AddColorPicker("EspColor", {
        Default = Color3.fromRGB(255, 64, 64),
        Title = "Цвет ESP",
        Callback = function(c) Settings.espColor = c end,
    })

    local aimGroup = Combat:AddRightGroupbox("Silent Aim")
    aimGroup:AddToggle("SilentOn", {
        Text = "Silent Aim",
        Default = false,
        Callback = function(v)
            Settings.silent = v
            silentState.enabled = v
        end,
    })
    aimGroup:AddSlider("SilentFov", {
        Text = "FOV",
        Min = 20, Max = 600, Default = 160, Rounding = 0, Suffix = "px",
        Callback = function(v)
            Settings.fov = v
            silentState.fov = v
        end,
    })
    aimGroup:AddToggle("FovCircle", {
        Text = "Круг FOV",
        Default = true,
        Callback = function(v) Settings.showFov = v end,
    })

    local worldGroup = Combat:AddLeftGroupbox("Мир")
    worldGroup:AddLabel("Снег, туман, эффекты, трава - выключены")
    worldGroup:AddButton({
        Text = "Переприменить",
        Func = function()
            applyQuality()
            killEffects()
            killWeather()
        end,
        DoubleClick = false,
    })

    Library:Notify({
        Title = "CW Hub",
        Description = "Загружен. RightShift - меню.",
        Time = 4,
    })
    getgenv().CW_LIBRARY = Library
end)

if not guiOk then
    warn("[CW] GUI failed: " .. tostring(guiErr))
end

print("[CW] loaded | esp=" .. tostring(Settings.esp) .. " | silent=" .. tostring(Settings.silent))
