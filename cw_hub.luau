--[[
    CW Hub - Cold War [VIETNAM]
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
local UIS        = game:GetService("UserInputService")
local lp         = Players.LocalPlayer

--=========================================================
--  CONFIG
--=========================================================
local C = {
    -- silent aim
    saEnabled = false, saDrawFov = true, saFov = 200, saMaxDist = 900,
    saHitPart = "Head", saTeamCheck = true, saVisCheck = true, saAutoShoot = false,
    saLead = true, saNoDrop = true, saSpeedMult = 1, saHitChance = 100,

    -- aimbot
    abEnabled = false, abFov = 150, abSmooth = 0.25, abHitPart = "Head",
    abTeamCheck = true, abWallCheck = true,

    -- triggerbot
    tbEnabled = false, tbFov = 40, tbHitPart = "Head", tbDelay = 0.05,

    -- ragebot
    rbEnabled = false, rbMaxDist = 1200, rbHitPart = "Head", rbTeamCheck = true,
    rbVisCheck = false, rbHitchance = 100, rbFireRate = 0.1, rbNoEffects = false,

    -- weapon
    wInfiniteAmmo = false, wNoRecoil = false, wRecoilScale = 0,
    wNoSpread = true, wRpm = false, wRpmMult = 1,

    -- hitbox
    hbEnabled = false, hbSize = 2,

    -- esp
    espEnabled = true, espBox = true, espName = true, espDisplayName = false,
    espTeam = false, espDistance = true, espWeapon = false, espHealthBar = true,
    espHealthText = false, espMaxDist = 1200, espFont = 13, espMax = 25,
    espColor = Color3.fromRGB(255, 64, 64), espVisColor = Color3.fromRGB(60, 255, 120),
    espTeamFilter = true,

    -- chams
    chamsEnabled = false, chamsOutline = true, chamsThroughWalls = true,
    chamsMaterial = "ForceField", chamsColor = Color3.fromRGB(255, 90, 90),
    chamsFill = 0.5, chamsOutlineColor = Color3.fromRGB(255, 255, 255),
    chamsUseTeam = false, chamsTransparency = 0.4,

    -- world esp
    weEnabled = false, weBox = true, weName = true, weDistance = true,
    weMaxDist = 900, weFont = 12, weColor = Color3.fromRGB(255, 200, 80),

    -- camera
    camThird = false, camDist = 12, camFov = false, camFovValue = 70,
    camFullbright = false, camNoFog = true,

    -- hud / tracers
    crosshair = false, crossSize = 6, crossGap = 4, crossThick = 1,
    crossColor = Color3.fromRGB(255, 255, 255),
    tracers = false, tracerLife = 1.5, tracerColor = Color3.fromRGB(255, 80, 80),

    -- lighting
    lUse = false, lAmbient = Color3.new(0, 0, 0), lOutdoor = Color3.new(0, 0, 0),
    lShiftTop = Color3.new(0, 0, 0), lShiftBottom = Color3.new(0, 0, 0),
    lFogColor = Color3.fromRGB(192, 192, 192), lFogEnd = 100000, lFogStart = 0,
    lSpecular = 0, lDiffuse = 0, lExposure = 0, lShadowSoft = 0.2,
    lBrightness = 2, lClockTime = 14, lGlobalShadows = false,

    -- atmosphere
    atUse = false, atColor = Color3.fromRGB(199, 199, 199), atDecay = Color3.new(0.5, 0.6, 0.7),
    atDensity = 0, atOffset = 0, atGlare = 0, atHaze = 0,

    -- effects
    fxUse = false, fxTint = Color3.new(1, 1, 1), fxBrightness = 0, fxContrast = 0,
    fxSaturation = 0, fxBloomOn = false, fxBloomIntensity = 0.5, fxBloomSize = 24,
    fxBloomThreshold = 1, fxBlurOn = false, fxBlurSize = 0,

    -- weather / skybox
    weatherOn = false, weatherType = "Snow", weatherRate = 0,
    skyboxOn = false, skyboxChoice = "Default",

    -- misc
    antiAfk = true, noSuppression = true, noFogGlobal = true,
    quality = 1,
}

--=========================================================
--  WORLD CONTROL
--=========================================================
local saved = { effects = {}, atmo = nil, fogStart = 0, fogEnd = 0 }

local function killWeather()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    for _, n in ipairs({ "__WeatherSky", "__WeatherAround" }) do
        local p = cam:FindFirstChild(n)
        if p then pcall(function() p:Destroy() end) end
    end
    for _, ch in ipairs(Lighting:GetChildren()) do
        if ch:IsA("Atmosphere") then
            if ch.Density ~= 0 then ch.Density = 0 end
            if ch.Haze ~= 0 then ch.Haze = 0 end
            if ch.Glare ~= 0 then ch.Glare = 0 end
        end
    end
end

local function applyQuality()
    if setfflag then pcall(function() setfflag("DFIntDebugFRMQualityLevelOverride", C.quality) end) end
    pcall(function()
        local ugs = game:GetService("UserSettings"):GetService("UserGameSettings")
        ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)
end

local lastSigL, lastSigA, lastSigF

local function applyLighting()
    local sig = table.concat({
        tostring(C.lUse), tostring(C.lAmbient), tostring(C.lOutdoor),
        tostring(C.lFogEnd), tostring(C.lBrightness), tostring(C.lClockTime),
        tostring(C.camFullbright), tostring(C.camNoFog), tostring(C.noFogGlobal),
    }, "|")
    if sig == lastSigL then return end
    lastSigL = sig
    if C.lUse then
        Lighting.Ambient = C.lAmbient
        Lighting.OutdoorAmbient = C.lOutdoor
        Lighting.ColorShift_Top = C.lShiftTop
        Lighting.ColorShift_Bottom = C.lShiftBottom
        Lighting.FogColor = C.lFogColor
        Lighting.FogEnd = C.lFogEnd
        Lighting.FogStart = C.lFogStart
        Lighting.Brightness = C.lBrightness
        Lighting.ClockTime = C.lClockTime
        Lighting.GlobalShadows = C.lGlobalShadows
        pcall(function() Lighting.EnvironmentSpecularScale = C.lSpecular end)
        pcall(function() Lighting.EnvironmentDiffuseScale = C.lDiffuse end)
        pcall(function() Lighting.ExposureCompensation = C.lExposure end)
        pcall(function() Lighting.ShadowSoftness = C.lShadowSoft end)
    end
    if C.camNoFog or C.noFogGlobal then
        Lighting.FogStart = 0
        Lighting.FogEnd = 1e9
    end
    if C.camFullbright then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness = 3
    end
end

local function applyAtmosphere()
    local sig = table.concat({
        tostring(C.atUse), tostring(C.atDensity), tostring(C.atHaze),
        tostring(C.atGlare), tostring(C.atOffset),
    }, "|")
    if sig == lastSigA then return end
    lastSigA = sig
    local a = Lighting:FindFirstChildOfClass("Atmosphere")
    if not a then return end
    if not saved.atmo then
        saved.atmo = a
        saved.atmoDensity = a.Density
        saved.atmoHaze = a.Haze
        saved.atmoGlare = a.Glare
    end
    if C.atUse then
        a.Color = C.atColor
        a.Decay = C.atDecay
        a.Density = C.atDensity
        a.Offset = C.atOffset
        a.Glare = C.atGlare
        a.Haze = C.atHaze
    else
        a.Density = 0
        a.Haze = 0
        a.Glare = 0
    end
end

local function applyEffects()
    local sig = table.concat({
        tostring(C.fxUse), tostring(C.fxTint), tostring(C.fxBrightness),
        tostring(C.fxContrast), tostring(C.fxSaturation), tostring(C.fxBloomOn),
        tostring(C.fxBloomIntensity), tostring(C.fxBlurOn), tostring(C.fxBlurSize),
    }, "|")
    if sig == lastSigF then return end
    lastSigF = sig
    local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "CW_CC"
        cc.Parent = Lighting
    end
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "CW_Bloom"
        bloom.Parent = Lighting
    end
    local blur = Lighting:FindFirstChildOfClass("BlurEffect")
    if not blur then
        blur = Instance.new("BlurEffect")
        blur.Name = "CW_Blur"
        blur.Parent = Lighting
    end

    if C.fxUse then
        cc.Enabled = true
        cc.TintColor = C.fxTint
        cc.Brightness = C.fxBrightness
        cc.Contrast = C.fxContrast
        cc.Saturation = C.fxSaturation
        bloom.Enabled = C.fxBloomOn
        bloom.Intensity = C.fxBloomIntensity
        bloom.Size = C.fxBloomSize
        bloom.Threshold = C.fxBloomThreshold
        blur.Enabled = C.fxBlurOn
        blur.Size = C.fxBlurSize
    else
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") and e.Name ~= "CW_CC" and e.Name ~= "CW_Bloom" and e.Name ~= "CW_Blur" then
                if saved.effects[e] == nil then saved.effects[e] = e.Enabled end
                e.Enabled = false
            end
        end
        cc.Enabled = false
        bloom.Enabled = false
        blur.Enabled = false
    end
end

local function applySkybox()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not C.skyboxOn or not sky then return end
    local id = C.skyboxChoice
    if id == "Default" then
        for _, p in ipairs({ "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }) do
            pcall(function() sky[p] = "rbxasset://sky/" .. p:sub(8):lower() .. ".jpg" end)
        end
    end
end

killWeather()
applyQuality()
applyLighting()
applyAtmosphere()
applyEffects()

--=========================================================
--  ZOOM
--=========================================================
local function applyZoom()
    if C.camThird then
        lp.CameraMinZoomDistance = 0.5
        lp.CameraMaxZoomDistance = math.max(C.camDist, 5)
    else
        lp.CameraMaxZoomDistance = 400
    end
end
applyZoom()

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

local PART_MAP = {
    Head = { "Head" },
    Torso = { "Torso", "UpperTorso", "HumanoidRootPart" },
    Random = { "Head", "Torso", "UpperTorso", "HumanoidRootPart" },
}

local function hitPartOf(char, mode)
    local list = PART_MAP[mode] or PART_MAP.Head
    if mode == "Random" then
        local p = list[math.random(1, #list)]
        local inst = char:FindFirstChild(p)
        if inst and inst:IsA("BasePart") then return inst end
    end
    for _, n in ipairs(list) do
        local inst = char:FindFirstChild(n)
        if inst and inst:IsA("BasePart") then return inst end
    end
    return nil
end

local visCache = {}
local VIS_TTL = 0.12
local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
visParams.IgnoreWater = true

local function isVisible(plr, worldPos)
    local now = tick()
    local c = visCache[plr]
    if c and (now - c.t) < VIS_TTL then return c.v end
    local visible = false
    local cam = Workspace.CurrentCamera
    if cam then
        local ex = {}
        if lp.Character then ex[#ex + 1] = lp.Character end
        if plr.Character then ex[#ex + 1] = plr.Character end
        visParams.FilterDescendantsInstances = ex
        visible = Workspace:Raycast(cam.CFrame.Position, worldPos - cam.CFrame.Position, visParams) == nil
    end
    visCache[plr] = { v = visible, t = now }
    return visible
end

--=========================================================
--  DRAWING POOL
--=========================================================
local objs = {}
local function track(o) objs[#objs + 1] = o return o end

local espPool = {}

local function makeESP()
    local e = { lines = {} }
    for i = 1, 8 do e.lines[i] = track(Drawing.new("Line")) end
    e.name = track(Drawing.new("Text"))
    e.dname = track(Drawing.new("Text"))
    e.team = track(Drawing.new("Text"))
    e.dist = track(Drawing.new("Text"))
    e.weapon = track(Drawing.new("Text"))
    e.hp = track(Drawing.new("Text"))
    e.hpBg = track(Drawing.new("Square"))
    e.hpFill = track(Drawing.new("Square"))
    e.arrow = track(Drawing.new("Triangle"))
    for _, l in ipairs(e.lines) do l.Thickness = 1.2 l.Visible = false end
    for _, t in ipairs({ e.name, e.dname, e.team, e.dist, e.weapon, e.hp }) do
        t.Center = true t.Outline = true t.Font = 2 t.Visible = false
    end
    e.hpBg.Filled = true e.hpBg.Thickness = 0 e.hpBg.Visible = false
    e.hpFill.Filled = true e.hpFill.Thickness = 0 e.hpFill.Visible = false
    e.arrow.Filled = true e.arrow.Visible = false
    return e
end

local function hideESP(e)
    for _, l in ipairs(e.lines) do l.Visible = false end
    for _, t in ipairs({ e.name, e.dname, e.team, e.dist, e.weapon, e.hp }) do t.Visible = false end
    e.hpBg.Visible = false
    e.hpFill.Visible = false
    e.arrow.Visible = false
end

local function destroyESP(e)
    for _, l in ipairs(e.lines) do pcall(function() l:Remove() end) end
    for _, t in ipairs({ e.name, e.dname, e.team, e.dist, e.weapon, e.hp }) do pcall(function() t:Remove() end) end
    pcall(function() e.hpBg:Remove() end)
    pcall(function() e.hpFill:Remove() end)
    pcall(function() e.arrow:Remove() end)
end

local fovCircle = track(Drawing.new("Circle"))
fovCircle.Thickness = 1.5
fovCircle.Color = Color3.new(1, 1, 1)
fovCircle.Transparency = 0.5
fovCircle.Visible = false

local crossLines = {}
for i = 1, 4 do
    local l = track(Drawing.new("Line"))
    l.Thickness = 1
    l.Visible = false
    crossLines[i] = l
end

local tracerPool = {}
local function getTracer()
    for _, t in ipairs(tracerPool) do
        if not t.busy then return t end
    end
    local t = { line = track(Drawing.new("Line")), busy = false, born = 0 }
    t.line.Thickness = 1.5
    t.line.Visible = false
    tracerPool[#tracerPool + 1] = t
    return t
end

local worldObjs = {}
local worldPool = {}
local chams = {}

STATE.onCleanup(function()
    for _, o in ipairs(objs) do pcall(function() o:Remove() end) end
    table.clear(objs)
    if saved.atmo and saved.atmo.Parent then
        pcall(function()
            saved.atmo.Density = saved.atmoDensity
            saved.atmo.Haze = saved.atmoHaze
            saved.atmo.Glare = saved.atmoGlare
        end)
    end
    pcall(function()
        Lighting.FogStart = saved.fogStart
        Lighting.FogEnd = saved.fogEnd
    end)
    if getgenv().CW_UNHOOK then pcall(getgenv().CW_UNHOOK) end
    for _, h in pairs(chams) do pcall(function() h:Destroy() end) end
end)

--=========================================================
--  SILENT AIM
--=========================================================
local saState = { enabled = false, fov = 200, maxDist = 900 }

local function targetFor(origin, mode, fovPx, maxDist, teamCheck, visCheck, hitPart)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local best, bestDist = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        local okTeam = (not teamCheck) or isEnemy(plr)
        if okTeam and alive(plr) then
            local ch = plr.Character
            local part = ch and hitPartOf(ch, hitPart)
            if part then
                local pos = part.Position
                local d = (pos - origin).Magnitude
                if d <= maxDist and d < bestDist then
                    local sp = cam:WorldToViewportPoint(pos)
                    local inFov = false
                    if sp.Z > 0 then
                        local dx, dy = sp.X - vp.X / 2, sp.Y - vp.Y / 2
                        inFov = math.sqrt(dx * dx + dy * dy) <= fovPx
                    end
                    if inFov then
                        local okWall = (not visCheck) or isVisible(plr, pos)
                        if okWall then
                            local hrp = ch:FindFirstChild("HumanoidRootPart")
                            best = {
                                plr = plr, pos = pos,
                                vel = hrp and hrp.AssemblyLinearVelocity or Vector3.zero,
                            }
                            bestDist = d
                        end
                    end
                end
            end
        end
    end
    return best, bestDist
end

local function installHook()
    local ok, err = pcall(function()
        local B = RS:WaitForChild("Shared"):WaitForChild("Ballistics")
        local PC = require(B:WaitForChild("ProjectileCaster"))
        if PC.__cwHooked then return end
        local orig = PC.Fire
        PC.__cwOrig = orig
        PC.Fire = function(params)
            local active = C.saEnabled or C.rbEnabled
            if active and type(params) == "table" and params.Origin and params.Weapon then
                local rage = C.rbEnabled
                local maxDist = rage and C.rbMaxDist or C.saMaxDist
                local teamCheck = rage and C.rbTeamCheck or C.saTeamCheck
                local visCheck = rage and C.rbVisCheck or C.saVisCheck
                local hitPart = rage and C.rbHitPart or C.saHitPart
                local hitchance = rage and C.rbHitchance or C.saHitChance
                local fovPx = rage and 800 or saState.fov
                if math.random(1, 100) <= hitchance then
                    local w = params.Weapon
                    local baseSpeed = w.MuzzleSpeed or 900
                    local speed = baseSpeed * (C.saSpeedMult or 1)
                    local t = targetFor(params.Origin, nil, fovPx, maxDist,
                        teamCheck, visCheck, hitPart)
                    if t then
                        local aim = t.pos
                        if C.saLead then
                            local flight = (aim - params.Origin).Magnitude / math.max(speed, 1)
                            aim = aim + t.vel * flight
                        end
                        local delta = aim - params.Origin
                        if delta.Magnitude > 0.1 then
                            params.Direction = delta.Unit
                        end
                        local nw = {}
                        for k, v in pairs(w) do nw[k] = v end
                        if C.saNoDrop then
                            nw.Gravity = 0
                            nw.K = 0
                        end
                        if C.saSpeedMult ~= 1 then nw.MuzzleSpeed = speed end
                        params.Weapon = nw
                        params.Spread = 0
                    end
                end
            end
            return orig(params)
        end
        PC.__cwHooked = true
        getgenv().CW_UNHOOK = function()
            if PC.__cwOrig then
                PC.Fire = PC.__cwOrig
                PC.__cwHooked = false
                PC.__cwOrig = nil
            end
        end
    end)
    if not ok then warn("[CW] hook: " .. tostring(err)) end
end
installHook()

--=========================================================
--  CHAMS
--=========================================================
local function updateChams()
    for plr, h in pairs(chams) do
        if not plr.Parent or not plr.Character or not C.chamsEnabled then
            pcall(function() h:Destroy() end)
            chams[plr] = nil
        end
    end
    if not C.chamsEnabled then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character and ((not C.espTeamFilter) or isEnemy(plr)) then
            local h = chams[plr]
            if not h then
                h = Instance.new("Highlight")
                h.Name = "CW_Cham"
                h.Parent = plr.Character
                chams[plr] = h
            end
            h.Adornee = plr.Character
            h.FillColor = C.chamsUseTeam and (plr.Team and plr.Team.TeamColor.Color or C.chamsColor) or C.chamsColor
            h.OutlineColor = C.chamsOutlineColor
            h.FillTransparency = C.chamsFill
            h.OutlineTransparency = C.chamsOutline and 0 or 1
            h.DepthMode = C.chamsThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop
                or Enum.HighlightDepthMode.Occluded
        end
    end
end

--=========================================================
--  HITBOX
--=========================================================
local origSizes = {}
local function updateHitbox()
    for plr, data in pairs(origSizes) do
        if not plr.Parent or not C.hbEnabled then
            for part, size in pairs(data) do
                if part.Parent then pcall(function() part.Size = size end) end
            end
            origSizes[plr] = nil
        end
    end
    if not C.hbEnabled then return end

    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr.Character
        if plr ~= lp and ch and alive(plr) then
            local head = ch:FindFirstChild("Head")
            if head and head:IsA("BasePart") and not origSizes[plr] then
                local store = {}
                store[head] = head.Size
                pcall(function() head.Size = head.Size * C.hbSize end)
                origSizes[plr] = store
            end
        end
    end
end

--=========================================================
--  WORLD ESP
--=========================================================
local function worldCandidates()
    local out = {}
    local root = Workspace:FindFirstChild("Vehicles")
    if root then
        for _, m in ipairs(root:GetChildren()) do
            if m:IsA("Model") then
                local pp = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
                if pp then out[#out + 1] = { obj = m, pos = pp.Position, name = m.Name } end
            end
        end
    end
    return out
end

--=========================================================
--  MAIN LOOP
--=========================================================
local HEAD_OFF = Vector3.new(0, 2.0, 0)
local FEET_OFF = Vector3.new(0, 2.6, 0)
local candidates = {}
local used = {}
local accum = 0
local FRAME_DT = 1 / 60
local lastZoom, lastWeather, lastSlow, lastAfk = 0, 0, 0, 0

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

local function loop(dt)
    accum = accum + dt
    if accum < FRAME_DT then return end
    accum = 0

    local cam = Workspace.CurrentCamera
    if not cam then return end
    local now = tick()

    if now - lastZoom > 1 then lastZoom = now applyZoom() end
    if not C.weatherOn then killWeather() end
    if now - lastSlow > 0.5 then
        lastSlow = now
        applyLighting()
        applyAtmosphere()
        applyEffects()
        applySkybox()
        updateChams()
        updateHitbox()
    end

    if C.camFov then cam.FieldOfView = C.camFovValue end

    -- FOV circle
    local showFov = (C.saEnabled and C.saDrawFov) or C.abEnabled or C.tbEnabled
    local fovRadius = C.saEnabled and saState.fov or (C.abEnabled and C.abFov or C.tbFov)
    fovCircle.Visible = showFov and fovRadius ~= nil
    if fovCircle.Visible then
        local vp = cam.ViewportSize
        fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        fovCircle.Radius = fovRadius
    end

    local vp = cam.ViewportSize

    -- crosshair
    if C.crosshair then
        local cx, cy = vp.X / 2, vp.Y / 2
        local g, s = C.crossGap, C.crossSize
        crossLines[1].From, crossLines[1].To = Vector2.new(cx - g - s, cy), Vector2.new(cx - g, cy)
        crossLines[2].From, crossLines[2].To = Vector2.new(cx + g, cy), Vector2.new(cx + g + s, cy)
        crossLines[3].From, crossLines[3].To = Vector2.new(cx, cy - g - s), Vector2.new(cx, cy - g)
        crossLines[4].From, crossLines[4].To = Vector2.new(cx, cy + g), Vector2.new(cx, cy + g + s)
        for i = 1, 4 do
            crossLines[i].Color = C.crossColor
            crossLines[i].Thickness = C.crossThick
            crossLines[i].Visible = true
        end
    else
        for i = 1, 4 do crossLines[i].Visible = false end
    end

    -- tracers lifetime
    for _, tr in ipairs(tracerPool) do
        if tr.busy and (now - tr.born) > C.tracerLife then
            tr.busy = false
            tr.line.Visible = false
        end
    end

    -- world esp
    if C.weEnabled then
        local eyeW = cam.CFrame.Position
        local seenWorld = {}
        for _, o in ipairs(worldCandidates()) do
            local d = (o.pos - eyeW).Magnitude
            if d <= C.weMaxDist then
                local sp = cam:WorldToViewportPoint(o.pos)
                if sp.Z > 0 then
                    local ent = worldPool[o.obj]
                    if not ent then
                        ent = { lines = {}, text = track(Drawing.new("Text")) }
                        for i = 1, 4 do
                            ent.lines[i] = track(Drawing.new("Line"))
                            ent.lines[i].Thickness = 1
                        end
                        ent.text.Center = true
                        ent.text.Outline = true
                        ent.text.Font = 2
                        worldPool[o.obj] = ent
                    end
                    seenWorld[o.obj] = true
                    local s = math.clamp(1400 / d, 12, 90)
                    local x, y = sp.X - s / 2, sp.Y - s / 2
                    ent.lines[1].From, ent.lines[1].To = Vector2.new(x, y), Vector2.new(x + s, y)
                    ent.lines[2].From, ent.lines[2].To = Vector2.new(x + s, y), Vector2.new(x + s, y + s)
                    ent.lines[3].From, ent.lines[3].To = Vector2.new(x + s, y + s), Vector2.new(x, y + s)
                    ent.lines[4].From, ent.lines[4].To = Vector2.new(x, y + s), Vector2.new(x, y)
                    for i = 1, 4 do
                        ent.lines[i].Color = C.weColor
                        ent.lines[i].Visible = true
                    end
                    ent.text.Text = o.name .. "  " .. math.floor(d) .. "m"
                    ent.text.Size = C.weFont
                    ent.text.Color = C.weColor
                    ent.text.Position = Vector2.new(sp.X, y - 4)
                    ent.text.Visible = true
                end
            end
        end
        for obj, ent in pairs(worldPool) do
            if not seenWorld[obj] then
                for i = 1, 4 do ent.lines[i].Visible = false end
                ent.text.Visible = false
            end
        end
    else
        for _, ent in pairs(worldPool) do
            for i = 1, 4 do ent.lines[i].Visible = false end
            ent.text.Visible = false
        end
    end

    -- anti afk
    if C.antiAfk and (now - lastAfk) > 1 then
        lastAfk = now
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end

    -- ESP
    if not C.espEnabled then
        for _, e in pairs(espPool) do hideESP(e) end
        return
    end

    local eye = cam.CFrame.Position
    table.clear(candidates)

    for _, plr in ipairs(Players:GetPlayers()) do
        if (not C.espTeamFilter or isEnemy(plr)) and alive(plr) then
            local ch = plr.Character
            local hrp = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso"))
            if hrp then
                local pos = hrp.Position
                local d = (pos - eye).Magnitude
                if d <= C.espMaxDist then
                    candidates[#candidates + 1] = {
                        plr = plr, pos = pos, dist = d,
                        visible = isVisible(plr, pos + HEAD_OFF),
                    }
                end
            end
        end
    end

    if #candidates > C.espMax then
        table.sort(candidates, function(a, b) return a.dist < b.dist end)
        for i = #candidates, C.espMax + 1, -1 do candidates[i] = nil end
    end

    table.clear(used)

    for _, c in ipairs(candidates) do
        local e = espPool[c.plr]
        if not e then
            e = makeESP()
            espPool[c.plr] = e
        end
        used[c.plr] = true

        local head = cam:WorldToViewportPoint(c.pos + HEAD_OFF)
        local feet = cam:WorldToViewportPoint(c.pos - FEET_OFF)
        local mid = cam:WorldToViewportPoint(c.pos)
        local color = c.visible and C.espVisColor or C.espColor

        if mid.Z > 0 and head.Z > 0 then
            local rawH = math.abs(head.Y - feet.Y)
            local h = math.max(rawH, 8)
            local w = h * 0.52
            local x = mid.X - w / 2
            local y = mid.Y - h / 2

            if x + w > 0 and x < vp.X and y + h > 0 and y < vp.Y then
                if C.espBox then drawCorners(e, x, y, w, h, color) else
                    for i = 1, 8 do e.lines[i].Visible = false end
                end

                local fs = C.espFont
                local line = y - 6
                local function put(t, text, yy)
                    if text then
                        t.Text = text
                        t.Size = fs
                        t.Color = color
                        t.Position = Vector2.new(x + w / 2, yy)
                        t.Visible = true
                        return yy - (fs + 2)
                    end
                    t.Visible = false
                    return yy
                end

                if C.espName then line = put(e.name, c.plr.Name, line) else e.name.Visible = false end
                if C.espDisplayName then line = put(e.dname, c.plr.DisplayName, line) else e.dname.Visible = false end
                if C.espTeam and c.plr.Team then line = put(e.team, c.plr.Team.Name, line) else e.team.Visible = false end
                if C.espDistance then line = put(e.dist, string.format("%dm", math.floor(c.dist)), line) else e.dist.Visible = false end
                if C.espWeapon then
                    local tool = c.plr.Character and c.plr.Character:FindFirstChildOfClass("Tool")
                    line = put(e.weapon, tool and tool.Name or "", line)
                else
                    e.weapon.Visible = false
                end

                local hum = c.plr.Character and c.plr.Character:FindFirstChildOfClass("Humanoid")
                if C.espHealthBar and hum and hum.MaxHealth > 1 then
                    local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    local bx = x + w + 5
                    e.hpBg.Size = Vector2.new(3, h)
                    e.hpBg.Position = Vector2.new(bx, y)
                    e.hpBg.Color = Color3.fromRGB(20, 20, 20)
                    e.hpBg.Visible = true
                    local fh = math.max(1, h * frac)
                    e.hpFill.Size = Vector2.new(3, fh)
                    e.hpFill.Position = Vector2.new(bx, y + (h - fh))
                    e.hpFill.Color = frac > 0.6 and Color3.fromRGB(70, 220, 90)
                        or (frac > 0.3 and Color3.fromRGB(240, 200, 50) or Color3.fromRGB(230, 60, 60))
                    e.hpFill.Visible = true
                else
                    e.hpBg.Visible = false
                    e.hpFill.Visible = false
                end

                if C.espHealthText and hum then
                    e.hp.Text = string.format("%d", math.floor(hum.Health))
                    e.hp.Size = fs
                    e.hp.Color = color
                    e.hp.Position = Vector2.new(x + w / 2, y + h + 2)
                    e.hp.Visible = true
                else
                    e.hp.Visible = false
                end

                e.arrow.Visible = false

                if C.tracers then
                    local tr = getTracer()
                    if not tr.busy then
                        tr.busy = true
                        tr.born = now
                        tr.line.From = Vector2.new(vp.X / 2, vp.Y)
                        tr.line.To = Vector2.new(mid.X, mid.Y)
                        tr.line.Color = C.tracerColor
                        tr.line.Visible = true
                    end
                end
            else
                hideESP(e)
                if C.saEnabled or C.abEnabled then
                    -- offscreen arrow for aim targets
                end
            end
        else
            hideESP(e)
        end
    end

    for plr, e in pairs(espPool) do
        if not used[plr] then hideESP(e) end
        if not plr.Parent then
            destroyESP(e)
            espPool[plr] = nil
        end
    end
end

STATE.connect(RunService.Heartbeat, loop)

--=========================================================
--  TRIGGERBOT
--=========================================================
local lastTrigger = 0
STATE.connect(RunService.Heartbeat, function()
    if not C.tbEnabled then return end
    local now = tick()
    if now - lastTrigger < C.tbDelay then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) and alive(plr) then
            local part = hitPartOf(plr.Character, C.tbHitPart)
            if part then
                local sp = cam:WorldToViewportPoint(part.Position)
                if sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= C.tbFov then
                        lastTrigger = now
                        pcall(mouse1click)
                        break
                    end
                end
            end
        end
    end
end)

--=========================================================
--  AIMBOT (camera)
--=========================================================
STATE.connect(RunService.Heartbeat, function(dt)
    if not C.abEnabled then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local target = targetFor(cam.CFrame.Position, nil, C.abFov, 1200,
        C.abTeamCheck, C.abWallCheck, C.abHitPart)
    if not target then return end
    local goal = CFrame.new(cam.CFrame.Position, target.pos)
    local alpha = math.clamp(1 - C.abSmooth, 0.05, 1)
    cam.CFrame = cam.CFrame:Lerp(goal, alpha)
end)

--=========================================================
--  AUTOSHOOT
--=========================================================
STATE.connect(RunService.Heartbeat, function()
    if not (C.saEnabled and C.saAutoShoot) then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local t = targetFor(cam.CFrame.Position, nil, saState.fov, C.saMaxDist,
        C.saTeamCheck, C.saVisCheck, C.saHitPart)
    if t then pcall(mouse1click) end
end)

--=========================================================
--  GUI
--=========================================================
local guiOk, guiErr = pcall(function()
    local Library = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()

    local Window = Library:CreateWindow({
        Title = "CW Hub",
        Footer = "cold war [vietnam]",
        Size = UDim2.fromOffset(680, 520),
        NotifySide = "Right",
        ShowCustomCursor = true,
        AutoShow = true,
    })

    STATE.onCleanup(function() pcall(function() Library:Unload() end) end)

    local Combat = Window:AddTab("Combat", "swords")
    local Visuals = Window:AddTab("Visuals", "eye")
    local WorldTab = Window:AddTab("World", "globe")
    local Misc = Window:AddTab("Misc", "wrench")

    ---------------------------------------------------------------
    -- SILENT AIM
    ---------------------------------------------------------------
    local saG = Combat:AddGroupbox({ Side = "Left", Name = "Silent Aim", IconName = "crosshair" })
    saG:AddToggle("saEnabled", { Text = "Enabled", Default = false, Callback = function(v) C.saEnabled = v end })
    saG:AddToggle("saDrawFov", { Text = "Draw FOV", Default = true, Callback = function(v) C.saDrawFov = v end })
    saG:AddSlider("saFov", { Text = "FOV", Min = 20, Max = 800, Default = 200, Rounding = 0,
        Callback = function(v) C.saFov = v saState.fov = v end })
    saG:AddSlider("saMaxDist", { Text = "Max Distance", Min = 50, Max = 3000, Default = 900, Rounding = 0,
        Callback = function(v) C.saMaxDist = v end })
    saG:AddDropdown("saHitPart", { Values = { "Head", "Torso", "Random" }, Default = "Head",
        Text = "Hit Parts", Callback = function(v) C.saHitPart = v end })
    saG:AddToggle("saTeamCheck", { Text = "Team Check", Default = true, Callback = function(v) C.saTeamCheck = v end })
    saG:AddToggle("saVisCheck", { Text = "Visible Check", Default = true, Callback = function(v) C.saVisCheck = v end })
    saG:AddToggle("saAutoShoot", { Text = "Autoshoot", Default = false, Callback = function(v) C.saAutoShoot = v end })
    saG:AddToggle("saLead", { Text = "Lead Prediction", Default = true, Callback = function(v) C.saLead = v end })
    saG:AddSlider("saSpeed", { Text = "Bullet Speed x", Min = 1, Max = 10, Default = 1, Rounding = 1,
        Callback = function(v) C.saSpeedMult = v end })
    saG:AddSlider("saHitchance", { Text = "Hitchance", Min = 1, Max = 100, Default = 100, Rounding = 0,
        Callback = function(v) C.saHitChance = v end })

    ---------------------------------------------------------------
    -- AIMBOT
    ---------------------------------------------------------------
    local abG = Combat:AddGroupbox({ Side = "Left", Name = "Aimbot", IconName = "mouse-pointer" })
    abG:AddToggle("abEnabled", { Text = "Enabled", Default = false, Callback = function(v) C.abEnabled = v end })
    abG:AddSlider("abFov", { Text = "FOV", Min = 20, Max = 800, Default = 150, Rounding = 0,
        Callback = function(v) C.abFov = v end })
    abG:AddSlider("abSmooth", { Text = "Smoothing", Min = 0, Max = 1, Default = 0.25, Rounding = 2,
        Callback = function(v) C.abSmooth = v end })
    abG:AddDropdown("abHitPart", { Values = { "Head", "Torso", "Random" }, Default = "Head",
        Text = "Hit Part", Callback = function(v) C.abHitPart = v end })
    abG:AddToggle("abTeamCheck", { Text = "Team Check", Default = true, Callback = function(v) C.abTeamCheck = v end })
    abG:AddToggle("abWallCheck", { Text = "Wall Check", Default = true, Callback = function(v) C.abWallCheck = v end })

    ---------------------------------------------------------------
    -- TRIGGERBOT
    ---------------------------------------------------------------
    local tbG = Combat:AddGroupbox({ Side = "Right", Name = "Triggerbot", IconName = "zap" })
    tbG:AddToggle("tbEnabled", { Text = "Enabled", Default = false, Callback = function(v) C.tbEnabled = v end })
    tbG:AddSlider("tbFov", { Text = "FOV", Min = 5, Max = 300, Default = 40, Rounding = 0,
        Callback = function(v) C.tbFov = v end })
    tbG:AddDropdown("tbHitPart", { Values = { "Head", "Torso", "Random" }, Default = "Head",
        Text = "Hit Parts", Callback = function(v) C.tbHitPart = v end })
    tbG:AddSlider("tbDelay", { Text = "Delay", Min = 0, Max = 1, Default = 0.05, Rounding = 2,
        Callback = function(v) C.tbDelay = v end })

    ---------------------------------------------------------------
    -- RAGEBOT
    ---------------------------------------------------------------
    local rbG = Combat:AddGroupbox({ Side = "Right", Name = "Ragebot", IconName = "flame" })
    rbG:AddLabel("Uses Silent Aim engine with its own limits")
    rbG:AddToggle("rbEnabled", { Text = "Enabled", Default = false, Callback = function(v) C.rbEnabled = v end })
    rbG:AddSlider("rbMaxDist", { Text = "Max Distance", Min = 50, Max = 3000, Default = 1200, Rounding = 0,
        Callback = function(v) C.rbMaxDist = v end })
    rbG:AddDropdown("rbHitPart", { Values = { "Head", "Torso", "Random" }, Default = "Head",
        Text = "Hit Parts", Callback = function(v) C.rbHitPart = v end })
    rbG:AddToggle("rbTeamCheck", { Text = "Team Check", Default = true, Callback = function(v) C.rbTeamCheck = v end })
    rbG:AddToggle("rbVisCheck", { Text = "Visible Check", Default = false, Callback = function(v) C.rbVisCheck = v end })
    rbG:AddSlider("rbHitchance", { Text = "Hitchance", Min = 1, Max = 100, Default = 100, Rounding = 0,
        Callback = function(v) C.rbHitchance = v end })
    rbG:AddSlider("rbFireRate", { Text = "Fire Rate", Min = 0.02, Max = 1, Default = 0.1, Rounding = 2,
        Callback = function(v) C.rbFireRate = v end })
    rbG:AddLabel("No Effects / Tank / Vehicle Distance - not implemented")

    ---------------------------------------------------------------
    -- WEAPON
    ---------------------------------------------------------------
    local wG = Combat:AddGroupbox({ Side = "Right", Name = "Weapon", IconName = "target" })
    wG:AddToggle("wNoSpread", { Text = "No Spread", Default = true, Callback = function(v) C.wNoSpread = v end })
    wG:AddToggle("wNoRecoil", { Text = "No Recoil", Default = false, Callback = function(v) C.wNoRecoil = v end })
    wG:AddSlider("wRecoilScale", { Text = "Recoil Scale", Min = 0, Max = 1, Default = 0, Rounding = 2,
        Callback = function(v) C.wRecoilScale = v end })
    wG:AddToggle("wInfiniteAmmo", { Text = "Infinite Ammo (client)", Default = false,
        Callback = function(v) C.wInfiniteAmmo = v end })
    wG:AddSlider("wRpmMult", { Text = "RPM Multiplier", Min = 1, Max = 5, Default = 1, Rounding = 1,
        Callback = function(v) C.wRpmMult = v end })
    wG:AddLabel("RPM / ammo are server-side - client flag only")

    ---------------------------------------------------------------
    -- HITBOX
    ---------------------------------------------------------------
    local hbG = Combat:AddGroupbox({ Side = "Right", Name = "Hitbox Expander", IconName = "box" })
    hbG:AddToggle("hbEnabled", { Text = "Enabled", Default = false, Callback = function(v) C.hbEnabled = v end })
    hbG:AddSlider("hbSize", { Text = "Size", Min = 1, Max = 10, Default = 2, Rounding = 1,
        Callback = function(v) C.hbSize = v end })
    hbG:AddLabel("Client-side only")

    ---------------------------------------------------------------
    -- ESP
    ---------------------------------------------------------------
    local eG = Visuals:AddGroupbox({ Side = "Left", Name = "ESP", IconName = "eye" })
    eG:AddToggle("espEnabled", { Text = "Enabled", Default = true, Callback = function(v) C.espEnabled = v end })
    eG:AddToggle("espTeams", { Text = "Teams (enemies only)", Default = true, Callback = function(v) C.espTeamFilter = v end })
    eG:AddToggle("espBox", { Text = "Box", Default = true, Callback = function(v) C.espBox = v end })
    eG:AddToggle("espName", { Text = "Name", Default = true, Callback = function(v) C.espName = v end })
    eG:AddToggle("espDisplayName", { Text = "Display Name", Default = false, Callback = function(v) C.espDisplayName = v end })
    eG:AddToggle("espTeam", { Text = "Team", Default = false, Callback = function(v) C.espTeam = v end })
    eG:AddToggle("espDistance", { Text = "Distance", Default = true, Callback = function(v) C.espDistance = v end })
    eG:AddToggle("espWeapon", { Text = "Weapon", Default = false, Callback = function(v) C.espWeapon = v end })
    eG:AddToggle("espHealthBar", { Text = "Healthbar", Default = true, Callback = function(v) C.espHealthBar = v end })
    eG:AddToggle("espHealthText", { Text = "Health Text", Default = false, Callback = function(v) C.espHealthText = v end })
    eG:AddSlider("espMaxDist", { Text = "Max Distance", Min = 100, Max = 5000, Default = 1500, Rounding = 0,
        Callback = function(v) C.espMaxDist = v end })
    eG:AddSlider("espFont", { Text = "Font Size", Min = 8, Max = 24, Default = 13, Rounding = 0,
        Callback = function(v) C.espFont = v end })
    eG:AddSlider("espMax", { Text = "Max Targets", Min = 5, Max = 80, Default = 40, Rounding = 0,
        Callback = function(v) C.espMax = v end })
    eG:AddLabel("ESP Color"):AddColorPicker("espColor", { Default = Color3.fromRGB(255, 64, 64),
        Title = "ESP Color", Callback = function(c) C.espColor = c end })
    eG:AddLabel("Visible Color"):AddColorPicker("espVisColor", { Default = Color3.fromRGB(60, 255, 120),
        Title = "Visible Color", Callback = function(c) C.espVisColor = c end })

    ---------------------------------------------------------------
    -- CHAMS
    ---------------------------------------------------------------
    local cG = Visuals:AddGroupbox({ Side = "Left", Name = "ESP Chams", IconName = "layers" })
    cG:AddToggle("chamsEnabled", { Text = "Enabled", Default = false, Callback = function(v) C.chamsEnabled = v end })
    cG:AddToggle("chamsOutline", { Text = "Outline", Default = true, Callback = function(v) C.chamsOutline = v end })
    cG:AddToggle("chamsThroughWalls", { Text = "Through Walls", Default = true, Callback = function(v) C.chamsThroughWalls = v end })
    cG:AddToggle("chamsUseTeam", { Text = "Use Team Color", Default = false, Callback = function(v) C.chamsUseTeam = v end })
    cG:AddSlider("chamsFill", { Text = "Fill", Min = 0, Max = 1, Default = 0.5, Rounding = 2,
        Callback = function(v) C.chamsFill = v end })
    cG:AddLabel("Chams Color"):AddColorPicker("chamsColor", { Default = Color3.fromRGB(255, 90, 90),
        Title = "Fill Color", Callback = function(c) C.chamsColor = c end })
    cG:AddLabel("Outline Color"):AddColorPicker("chamsOutlineColor", { Default = Color3.new(1, 1, 1),
        Title = "Outline Color", Callback = function(c) C.chamsOutlineColor = c end })

    ---------------------------------------------------------------
    -- TRACERS
    ---------------------------------------------------------------
    local tG = Visuals:AddGroupbox({ Side = "Right", Name = "Tracers", IconName = "activity" })
    tG:AddToggle("tracers", { Text = "Enabled", Default = false, Callback = function(v) C.tracers = v end })
    tG:AddSlider("tracerLife", { Text = "Lifetime", Min = 0.1, Max = 5, Default = 1.5, Rounding = 1,
        Callback = function(v) C.tracerLife = v end })
    tG:AddLabel("Tracer Color"):AddColorPicker("tracerColor", { Default = Color3.fromRGB(255, 80, 80),
        Title = "Tracer Color", Callback = function(c) C.tracerColor = c end })

    ---------------------------------------------------------------
    -- WORLD ESP
    ---------------------------------------------------------------
    local wg = Visuals:AddGroupbox({ Side = "Right", Name = "World ESP", IconName = "map" })
    wg:AddLabel("Vehicles folder only - other categories not implemented")
    wg:AddToggle("weEnabled", { Text = "Enabled", Default = false, Callback = function(v) C.weEnabled = v end })
    wg:AddSlider("weMaxDist", { Text = "Max Distance", Min = 50, Max = 3000, Default = 900, Rounding = 0,
        Callback = function(v) C.weMaxDist = v end })
    wg:AddSlider("weFont", { Text = "Font Size", Min = 8, Max = 24, Default = 12, Rounding = 0,
        Callback = function(v) C.weFont = v end })

    ---------------------------------------------------------------
    -- CAMERA
    ---------------------------------------------------------------
    local camG = WorldTab:AddGroupbox({ Side = "Left", Name = "Camera", IconName = "video" })
    camG:AddToggle("camThird", { Text = "Third Person", Default = false, Callback = function(v) C.camThird = v end })
    camG:AddSlider("camDist", { Text = "Distance", Min = 5, Max = 400, Default = 12, Rounding = 0,
        Callback = function(v) C.camDist = v end })
    camG:AddToggle("camFov", { Text = "Camera FOV", Default = false, Callback = function(v) C.camFov = v end })
    camG:AddSlider("camFovValue", { Text = "FOV Value", Min = 30, Max = 120, Default = 70, Rounding = 0,
        Callback = function(v) C.camFovValue = v end })
    camG:AddToggle("camFullbright", { Text = "Fullbright", Default = false, Callback = function(v) C.camFullbright = v end })
    camG:AddToggle("camNoFog", { Text = "No Fog", Default = true, Callback = function(v) C.camNoFog = v end })
    camG:AddLabel("Viewmodel offsets - not implemented")

    ---------------------------------------------------------------
    -- LIGHTING
    ---------------------------------------------------------------
    local lG = WorldTab:AddGroupbox({ Side = "Left", Name = "Lighting", IconName = "sun" })
    lG:AddToggle("lUse", { Text = "Enabled", Default = false, Callback = function(v) C.lUse = v end })
    lG:AddSlider("lBrightness", { Text = "Brightness", Min = 0, Max = 5, Default = 2, Rounding = 1,
        Callback = function(v) C.lBrightness = v end })
    lG:AddSlider("lClockTime", { Text = "ClockTime", Min = 0, Max = 24, Default = 14, Rounding = 1,
        Callback = function(v) C.lClockTime = v end })
    lG:AddSlider("lFogEnd", { Text = "FogEnd", Min = 0, Max = 1000000, Default = 100000, Rounding = 0,
        Callback = function(v) C.lFogEnd = v end })
    lG:AddToggle("lGlobalShadows", { Text = "GlobalShadows", Default = false, Callback = function(v) C.lGlobalShadows = v end })

    ---------------------------------------------------------------
    -- ATMOSPHERE
    ---------------------------------------------------------------
    local aG = WorldTab:AddGroupbox({ Side = "Right", Name = "Atmosphere", IconName = "cloud" })
    aG:AddToggle("atUse", { Text = "Enabled", Default = false, Callback = function(v) C.atUse = v end })
    aG:AddSlider("atDensity", { Text = "Density", Min = 0, Max = 1, Default = 0, Rounding = 2,
        Callback = function(v) C.atDensity = v end })
    aG:AddSlider("atHaze", { Text = "Haze", Min = 0, Max = 10, Default = 0, Rounding = 2,
        Callback = function(v) C.atHaze = v end })
    aG:AddSlider("atGlare", { Text = "Glare", Min = 0, Max = 5, Default = 0, Rounding = 2,
        Callback = function(v) C.atGlare = v end })
    aG:AddSlider("atOffset", { Text = "Offset", Min = -1, Max = 1, Default = 0, Rounding = 2,
        Callback = function(v) C.atOffset = v end })

    ---------------------------------------------------------------
    -- EFFECTS
    ---------------------------------------------------------------
    local fG = WorldTab:AddGroupbox({ Side = "Right", Name = "Effects", IconName = "sparkles" })
    fG:AddToggle("fxUse", { Text = "Color Correction", Default = false, Callback = function(v) C.fxUse = v end })
    fG:AddSlider("fxBrightness", { Text = "Brightness", Min = -1, Max = 1, Default = 0, Rounding = 2,
        Callback = function(v) C.fxBrightness = v end })
    fG:AddSlider("fxContrast", { Text = "Contrast", Min = -1, Max = 1, Default = 0, Rounding = 2,
        Callback = function(v) C.fxContrast = v end })
    fG:AddSlider("fxSaturation", { Text = "Saturation", Min = -1, Max = 1, Default = 0, Rounding = 2,
        Callback = function(v) C.fxSaturation = v end })
    fG:AddToggle("fxBloomOn", { Text = "Bloom", Default = false, Callback = function(v) C.fxBloomOn = v end })
    fG:AddSlider("fxBloomIntensity", { Text = "Intensity", Min = 0, Max = 2, Default = 0.5, Rounding = 2,
        Callback = function(v) C.fxBloomIntensity = v end })
    fG:AddToggle("fxBlurOn", { Text = "Motion Blur", Default = false, Callback = function(v) C.fxBlurOn = v end })
    fG:AddSlider("fxBlurSize", { Text = "Blur Amount", Min = 0, Max = 56, Default = 0, Rounding = 0,
        Callback = function(v) C.fxBlurSize = v end })

    ---------------------------------------------------------------
    -- WEATHER / SKYBOX
    ---------------------------------------------------------------
    local wtG = WorldTab:AddGroupbox({ Side = "Left", Name = "Weather / Skybox", IconName = "cloud-snow" })
    wtG:AddToggle("weatherOn", { Text = "Weather Enabled", Default = false,
        Callback = function(v) C.weatherOn = v end })
    wtG:AddLabel("Weather off = snow and mist permanently removed")
    wtG:AddToggle("skyboxOn", { Text = "Skybox Enabled", Default = false, Callback = function(v) C.skyboxOn = v end })
    wtG:AddDropdown("skyboxChoice", { Values = { "Default", "Keep" }, Default = "Keep",
        Text = "Selected", Callback = function(v) C.skyboxChoice = v end })

    ---------------------------------------------------------------
    -- HUD
    ---------------------------------------------------------------
    local hG = Visuals:AddGroupbox({ Side = "Left", Name = "HUD", IconName = "crosshair" })
    hG:AddToggle("crosshair", { Text = "Custom Crosshair", Default = false, Callback = function(v) C.crosshair = v end })
    hG:AddSlider("crossSize", { Text = "Size", Min = 2, Max = 20, Default = 6, Rounding = 0,
        Callback = function(v) C.crossSize = v end })
    hG:AddSlider("crossGap", { Text = "Gap", Min = 0, Max = 20, Default = 4, Rounding = 0,
        Callback = function(v) C.crossGap = v end })
    hG:AddSlider("crossThick", { Text = "Thickness", Min = 1, Max = 4, Default = 1, Rounding = 0,
        Callback = function(v) C.crossThick = v end })
    hG:AddLabel("Crosshair Color"):AddColorPicker("crossColor", { Default = Color3.new(1, 1, 1),
        Title = "Crosshair Color", Callback = function(c) C.crossColor = c end })
    hG:AddLabel("Hitmarkers / Bullet Impacts / Grenade Prediction - not implemented")

    ---------------------------------------------------------------
    -- MISC
    ---------------------------------------------------------------
    local mG = Misc:AddGroupbox({ Side = "Left", Name = "Utility", IconName = "settings" })
    mG:AddToggle("antiAfk", { Text = "Anti AFK", Default = true, Callback = function(v) C.antiAfk = v end })
    mG:AddToggle("noSuppression", { Text = "No Suppression / Flash", Default = true,
        Callback = function(v) C.noSuppression = v end })
    mG:AddButton({ Text = "Reapply World", Func = function()
        applyQuality() applyLighting() applyAtmosphere() applyEffects() killWeather()
        Library:Notify({ Title = "CW Hub", Description = "World reapplied", Time = 2 })
    end, DoubleClick = false })
    mG:AddButton({ Text = "Unload", Func = function() Library:Unload() end, DoubleClick = false })

    local sG = Misc:AddGroupbox({ Side = "Right", Name = "Sounds", IconName = "volume-2" })
    sG:AddLabel("Hitsound / Killsound - not implemented")

    local chG = Misc:AddGroupbox({ Side = "Right", Name = "Character", IconName = "user" })
    chG:AddLabel("No Fall Damage / No Shock / Limb Heal - server side, not implemented")

    Library:Notify({ Title = "CW Hub", Description = "Loaded. RightShift opens the menu.", Time = 4 })
    getgenv().CW_LIBRARY = Library
end)

if not guiOk then warn("[CW] GUI failed: " .. tostring(guiErr)) end

print("[CW] loaded | esp=" .. tostring(C.espEnabled) .. " | silent=" .. tostring(C.saEnabled))
