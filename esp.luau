--[[
    Cold War [VIETNAM] - ESP + clean
    Запустил - работает. Никаких биндов.
    Только рамки. Текста нет.

    loadstring(game:HttpGet("https://raw.githubusercontent.com/fieyhqwis/coldwar-esp/main/esp.luau"))()
]]

local STATE = STATE or {
    onCleanup = function() end,
    connect = function(sig, fn) return sig:Connect(fn) end,
}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local Lighting   = game:GetService("Lighting")
local lp         = Players.LocalPlayer

local CFG = {
    -- ESP
    showAll       = true,
    maxDistance   = 800,
    maxPlayers    = 20,
    screenMargin  = 0.05,
    minBoxHeight  = 8,
    boxThickness  = 1.2,
    cornerFrac    = 0.22,
    useTeamColor  = true,
    fallbackColor = Color3.fromRGB(255, 64, 64),

    -- производительность
    quality       = 1,      -- 1..21, 1 = минимум графики => пропадает трава и тени
    noShadows     = true,
    noFog         = true,
    noEffects     = true,
    stillWater    = true,
    restoreOnExit = false,  -- true = вернуть графику при выгрузке
}

--=========================================================
--  ГРАФИКА
--=========================================================
local saved = { effects = {}, atmosphere = nil, fogStart = 0, fogEnd = 0 }

if CFG.quality and setfflag then
    pcall(function() setfflag("DFIntDebugFRMQualityLevelOverride", CFG.quality) end)
end
pcall(function()
    local ugs = game:GetService("UserSettings"):GetService("UserGameSettings")
    ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
end)

if CFG.noShadows then
    saved.globalShadows = Lighting.GlobalShadows
    pcall(function() Lighting.GlobalShadows = false end)
end

if CFG.noEffects then
    for _, obj in ipairs(Lighting:GetChildren()) do
        local cls = obj.ClassName
        if cls == "BloomEffect" or cls == "BlurEffect" or cls == "SunRaysEffect"
            or cls == "ColorCorrectionEffect" or cls == "DepthOfFieldEffect"
            or cls == "Clouds" then
            saved.effects[obj] = obj.Enabled
            pcall(function() obj.Enabled = false end)
        end
    end
end

if CFG.noFog then
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then
        saved.atmosphere = atmo
        saved.atmoDensity = atmo.Density
        saved.atmoHaze = atmo.Haze
        saved.atmoGlare = atmo.Glare
        atmo.Density = 0
        atmo.Haze = 0
        atmo.Glare = 0
    end
    saved.fogStart = Lighting.FogStart
    saved.fogEnd = Lighting.FogEnd
    Lighting.FogStart = 0
    Lighting.FogEnd = 1e9
end

if CFG.stillWater then
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        saved.waveSize = terrain.WaterWaveSize
        saved.waveSpeed = terrain.WaterWaveSpeed
        saved.reflectance = terrain.WaterReflectance
        saved.transparency = terrain.WaterTransparency
        pcall(function()
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
        end)
    end
end

if CFG.restoreOnExit then
    STATE.onCleanup(function()
        if saved.globalShadows ~= nil then Lighting.GlobalShadows = saved.globalShadows end
        for obj, was in pairs(saved.effects) do
            if obj and obj.Parent then pcall(function() obj.Enabled = was end) end
        end
        local a = saved.atmosphere
        if a and a.Parent then
            a.Density = saved.atmoDensity
            a.Haze = saved.atmoHaze
            a.Glare = saved.atmoGlare
        end
        Lighting.FogStart = saved.fogStart
        Lighting.FogEnd = saved.fogEnd
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain and saved.waveSize then
            pcall(function()
                terrain.WaterWaveSize = saved.waveSize
                terrain.WaterWaveSpeed = saved.waveSpeed
                terrain.WaterReflectance = saved.reflectance
                terrain.WaterTransparency = saved.transparency
            end)
        end
    end)
end

--=========================================================
--  ЗУМ
--=========================================================
local ZOOM_MAX = 400
local function applyZoom()
    lp.CameraMinZoomDistance = 0.5
    if lp.CameraMaxZoomDistance < ZOOM_MAX then
        lp.CameraMaxZoomDistance = ZOOM_MAX
    end
end
applyZoom()

--=========================================================
--  DRAWING
--=========================================================
local pool = {}
local stats = { drawn = 0, cand = 0, pool = 0, sample = "", frames = 0 }
getgenv().ESP_STATS = stats

local function makeEntry()
    local e = {
        tl = Drawing.new("Line"), tr = Drawing.new("Line"),
        bl = Drawing.new("Line"), br = Drawing.new("Line"),
        t1 = Drawing.new("Line"), t2 = Drawing.new("Line"),
        b1 = Drawing.new("Line"), b2 = Drawing.new("Line"),
        label = "",
        _dead = false,
    }
    for _, l in next, e do
        if type(l) == "userdata" then
            l.Thickness = CFG.boxThickness
            l.Visible = false
        end
    end
    return e
end

local function release(e)
    for _, l in next, e do
        if type(l) == "userdata" then l.Visible = false end
    end
end

local function destroy(e)
    for _, l in next, e do
        if type(l) == "userdata" then pcall(function() l:Remove() end) end
    end
end

STATE.onCleanup(function()
    for _, e in next, pool do destroy(e) end
    table.clear(pool)
end)

--=========================================================
--  HELPERS
--=========================================================
local function teamColorOf(plr)
    if CFG.useTeamColor and plr.Team then
        local ok, col = pcall(function() return plr.Team.TeamColor.Color end)
        if ok and col then return col end
    end
    return CFG.fallbackColor
end

local function rootPos(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    local torso = char:FindFirstChild("Torso")
    if torso then return torso.Position end
    return nil
end

--=========================================================
--  LOOP
--=========================================================
local HEAD_OFF = Vector3.new(0, 2.0, 0)
local FEET_OFF = Vector3.new(0, 2.6, 0)
local candidates = {}
local used = {}
local accum = 0
local FRAME_DT = 1 / 60
local lastZoom = 0

local function drawBox(e, x, y, w, h, color)
    local cx = h * CFG.cornerFrac
    local x2, y2 = x + w, y + h
    e.tl.From, e.tl.To = Vector2.new(x, y), Vector2.new(x + cx, y)
    e.t2.From, e.t2.To = Vector2.new(x, y), Vector2.new(x, y + cx)
    e.tr.From, e.tr.To = Vector2.new(x2, y), Vector2.new(x2 - cx, y)
    e.t1.From, e.t1.To = Vector2.new(x2, y), Vector2.new(x2, y + cx)
    e.bl.From, e.bl.To = Vector2.new(x, y2), Vector2.new(x + cx, y2)
    e.b2.From, e.b2.To = Vector2.new(x, y2), Vector2.new(x, y2 - cx)
    e.br.From, e.br.To = Vector2.new(x2, y2), Vector2.new(x2 - cx, y2)
    e.b1.From, e.b1.To = Vector2.new(x2, y2), Vector2.new(x2, y2 - cx)
    for _, l in next, e do
        if type(l) == "userdata" then
            l.Color = color
            l.Visible = true
        end
    end
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

    local vp = cam.ViewportSize
    local mx, my = vp.X * CFG.screenMargin, vp.Y * CFG.screenMargin
    local eye = cam.CFrame.Position

    table.clear(candidates)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.UserId ~= lp.UserId then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local pos = rootPos(char)
                    if pos then
                        local isEnemy = (lp.Team == nil) or (plr.Team ~= lp.Team)
                        if CFG.showAll or isEnemy then
                            local d = (pos - eye).Magnitude
                            if d <= CFG.maxDistance then
                                candidates[#candidates + 1] = { plr = plr, pos = pos, dist = d }
                            end
                        end
                    end
                end
            end
        end
    end

    if #candidates > CFG.maxPlayers then
        table.sort(candidates, function(a, b) return a.dist < b.dist end)
        for i = #candidates, CFG.maxPlayers + 1, -1 do candidates[i] = nil end
    end

    table.clear(used)
    local drawn = 0

    for _, c in next, candidates do
        local head = cam:WorldToViewportPoint(c.pos + HEAD_OFF)
        local feet = cam:WorldToViewportPoint(c.pos - FEET_OFF)
        local mid = cam:WorldToViewportPoint(c.pos)

        if mid.Z > 0 and head.Z > 0 and feet.Z > 0 then
            local h = math.abs(head.Y - feet.Y)
            if h >= CFG.minBoxHeight then
                local w = h * 0.52
                local x = mid.X - w / 2
                local y = mid.Y - h / 2

                if x + w > mx and x < vp.X - mx and y + h > my and y < vp.Y - my then
                    local e = pool[c.plr]
                    if not e then
                        e = makeEntry()
                        pool[c.plr] = e
                    end
                    used[c.plr] = true
                    drawBox(e, x, y, w, h, teamColorOf(c.plr))
                    drawn = drawn + 1
                    if drawn == 1 then
                        stats.sample = string.format("%s @ %.0f,%.0f %.0fx%.0f", c.plr.Name, x, y, w, h)
                    end
                elseif pool[c.plr] then
                    used[c.plr] = true
                    release(pool[c.plr])
                end
            elseif pool[c.plr] then
                used[c.plr] = true
                release(pool[c.plr])
            end
        elseif pool[c.plr] then
            used[c.plr] = true
            release(pool[c.plr])
        end
    end

    for plr, e in next, pool do
        if not used[plr] then release(e) end
        if not plr.Parent then
            destroy(e)
            pool[plr] = nil
        end
    end

    stats.drawn = drawn
    stats.cand = #candidates
    stats.frames = stats.frames + 1
    local n = 0
    for _ in next, pool do n = n + 1 end
    stats.pool = n
end

STATE.connect(RunService.Heartbeat, loop)

print(string.format("[ESP] %d игроков | range=%dm | quality=%d | fog=off | fx=off | zoom=%d",
    #Players:GetPlayers(), CFG.maxDistance, CFG.quality or 0, ZOOM_MAX))
