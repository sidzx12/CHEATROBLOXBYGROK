-- s¡dzx̌12 | Delta / any Luau executor
-- sideways menu + touch + reopen pill + fov + lock + silent + aimkill + aimfire + magnet + body aim + speed + jump + fly + esp + chams + autokill

if getgenv and getgenv().__sdzx12_unload then
    pcall(getgenv().__sdzx12_unload)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local CFG = {
    Aimbot = true,
    FOVEnabled = true,
    FOV = 150,
    FOVMin = 40,
    FOVMax = 600,
    AimPart = "head",       -- head | neck | body
    Silent = false,
    AimKill = false,
    AimFire = false,
    FireDelay = 0.3,
    FireMin = 0.1,
    FireMax = 1.0,
    Magnet = false,
    MagnetRadius = 90,
    MagnetMin = 20,
    MagnetMax = 300,
    BodyAim = false,
    Invisible = false,
    TeamCheck = true,
    NPCs = true,
    WallCheck = false,
    Speed = false,
    WalkSpeed = 16,
    WalkMin = 16,
    WalkMax = 200,
    Jump = false,
    JumpPower = 50,
    JumpMin = 50,
    JumpMax = 300,
    Fly = false,
    FlySpeed = 60,
    FlyMin = 10,
    FlyMax = 300,
    FlyKey = Enum.KeyCode.F,
    ESPBox = false,
    ESPLine = false,
    ESPName = false,
    ESPColor = "red",
    ESPRGB = false,
    ESPTarget = "enemies",
    Chams = false,
    ChamsColor = "yellow",
    ChamsRGB = false,
    ChamsTarget = "enemies",
    AutoKill = false,
    MenuKey = Enum.KeyCode.RightShift,
    ToggleKey = Enum.KeyCode.RightAlt,
}

local LP = Players.LocalPlayer
local BIND = "sdzx12_loop"
local alive = true
local conns = {}
local refreshers = {}
local targets = {}
local visList = {}
local lastScan = 0
local lastFire = 0
local lastTeleport = 0
local silentTarget = nil
local origWalk, origJump = 16, 50
local flying = false
local espCache = {}
local chamCache = {}
local lastRenderErr = nil

local CORNERS = {
    Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1),
    Vector3.new(-1, 1, -1),  Vector3.new(-1, 1, 1),
    Vector3.new(1, -1, -1),  Vector3.new(1, -1, 1),
    Vector3.new(1, 1, -1),   Vector3.new(1, 1, 1),
}

local COLOR_ORDER = { "red", "orange", "yellow", "green", "cyan", "blue", "magenta", "white" }
local COLORS = {
    red = Color3.fromRGB(255, 80, 80),
    orange = Color3.fromRGB(255, 150, 60),
    yellow = Color3.fromRGB(255, 230, 80),
    green = Color3.fromRGB(90, 255, 120),
    cyan = Color3.fromRGB(80, 230, 255),
    blue = Color3.fromRGB(90, 140, 255),
    magenta = Color3.fromRGB(255, 90, 230),
    white = Color3.fromRGB(255, 255, 255),
}
local NPC_PINK = Color3.fromRGB(255, 105, 180)
local VIS_TARGETS = { "enemies", "friends", "all" }

local function colorFor(kind, useRgb, presetName)
    if kind == "npc" then return NPC_PINK end
    if useRgb then
        return Color3.fromHSV((os.clock() * 0.4) % 1, 1, 1)
    end
    return COLORS[presetName] or COLORS.white
end

local function refreshAll()
    for _, f in ipairs(refreshers) do f() end
end

-- invisible
local function setInvisPart(d)
    if d:IsA("BasePart") then
        d.LocalTransparencyModifier = CFG.Invisible and 1 or 0
    end
end

local function applyInvis(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do setInvisPart(d) end
end

local function watchChar(char)
    applyInvis(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        origWalk = hum.WalkSpeed
        origJump = hum.JumpPower
    end
    table.insert(conns, char.DescendantAdded:Connect(setInvisPart))
end

if LP.Character then watchChar(LP.Character) end
table.insert(conns, LP.CharacterAdded:Connect(watchChar))

-- helpers
local function rootOf(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
end

local function torsoOf(model)
    return model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("HumanoidRootPart")
end

local function aimPos(model)
    if CFG.BodyAim then
        local torso = torsoOf(model)
        return torso and torso.Position or nil
    end
    local head = model:FindFirstChild("Head")
    local torso = torsoOf(model)
    if CFG.AimPart == "head" and head then
        return head.Position
    elseif CFG.AimPart == "neck" and head then
        return head.Position - Vector3.new(0, head.Size.Y * 0.5, 0)
    elseif torso then
        return torso.Position
    elseif head then
        return head.Position
    end
    return nil
end

local function isFriend(p)
    if LP.Team and p.Team == LP.Team then return true end
    local ok, res = pcall(function() return LP:IsFriendsWith(p.UserId) end)
    return ok and res
end

local function kindOf(model)
    local p = Players:GetPlayerFromCharacter(model)
    if not p then return "npc" end
    if p == LP then return nil end
    if isFriend(p) then return "friend" end
    return "enemy"
end

local function visAllowed(kind, setting)
    if setting == "all" then return true end
    if setting == "enemies" then return kind == "enemy" or kind == "npc" end
    return kind == "friend"
end

local function isEnemy(model)
    local p = Players:GetPlayerFromCharacter(model)
    if not p then return CFG.NPCs end
    if p == LP then return false end
    if CFG.TeamCheck and LP.Team and p.Team == LP.Team then return false end
    return true
end

local function scan()
    table.clear(targets)
    table.clear(visList)
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Humanoid") and d.Health > 0 then
            local m = d.Parent
            if m and m:IsA("Model") and m \~= LP.Character then
                local kind = kindOf(m)
                if kind then
                    table.insert(visList, { hum = d, model = m, kind = kind })
                end
                if isEnemy(m) then
                    table.insert(targets, { hum = d, model = m })
                end
            end
        end
    end
end

local function visible(pos, model)
    if not CFG.WallCheck then return true end
    local cam = Workspace.CurrentCamera
    local origin = cam.CFrame.Position
    local dir = pos - origin
    local ignore = { cam }
    if LP.Character then table.insert(ignore, LP.Character) end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    for _ = 1, 8 do
        params.FilterDescendantsInstances = ignore
        local ray = Workspace:Raycast(origin, dir, params)
        if not ray then return true end
        if ray.Instance:IsDescendantOf(model) then return true end
        if ray.Instance.CanCollide and ray.Instance.Transparency < 0.9 then
            return false
        end
        table.insert(ignore, ray.Instance)
    end
    return false
end

local function pickTarget()
    local cam = Workspace.CurrentCamera
    local center = cam.ViewportSize / 2
    local bestPos, bestModel, bestD = nil, nil, CFG.FOV
    for _, t in ipairs(targets) do
        if t.hum.Health > 0 and t.model.Parent then
            local pos = aimPos(t.model)
            if pos then
                local sp, on = cam:WorldToViewportPoint(pos)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestD and visible(pos, t.model) then
                        bestPos, bestModel, bestD = pos, t.model, d
                    end
                end
            end
        end
    end
    return bestPos, bestModel
end

local function pickMagnet()
    local cam = Workspace.CurrentCamera
    local center = cam.ViewportSize / 2
    local bestPos, bestD = nil, CFG.MagnetRadius
    for _, t in ipairs(targets) do
        if t.hum.Health > 0 and t.model.Parent then
            local pos = aimPos(t.model)
            if pos then
                local sp, on = cam:WorldToViewportPoint(pos)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestD and visible(pos, t.model) then
                        bestPos, bestD = pos, d
                    end
                end
            end
        end
    end
    return bestPos
end

-- silent aim hook
local oldNamecall
local okHook, errHook = pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if not alive or not silentTarget or checkcaller() or self \~= Workspace then
            return oldNamecall(self, ...)
        end
        local method = getnamecallmethod()
        local cam = Workspace.CurrentCamera
        local args = table.pack(...)
        if method == "Raycast" then
            local origin, dir = args[1], args[2]
            if typeof(origin) == "Vector3" and typeof(dir) == "Vector3"
                and (origin - cam.CFrame.Position).Magnitude < 20 then
                local toT = silentTarget - origin
                if toT.Magnitude > 0 then
                    args[2] = toT.Unit * dir.Magnitude
                    return oldNamecall(self, table.unpack(args, 1, args.n))
                end
            end
        elseif method == "FindPartOnRay"
            or method == "FindPartOnRayWithIgnoreList"
            or method == "FindPartOnRayWithWhitelist" then
            local ray = args[1]
            if typeof(ray) == "Ray" and (ray.Origin - cam.CFrame.Position).Magnitude < 20 then
                local toT = silentTarget - ray.Origin
                if toT.Magnitude > 0 then
                    args[1] = Ray.new(ray.Origin, toT.Unit * ray.Direction.Magnitude)
                    return oldNamecall(self, table.unpack(args, 1, args.n))
                end
            end
        end
        return oldNamecall(self, ...)
    end))
end)
if not okHook then
    warn("s¡dzx̌12: silent hook failed - " .. tostring(errHook))
end

-- movement
local function getHumRoot()
    local char = LP.Character
    if not char then return nil, nil end
    return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function movementStep()
    local hum, root = getHumRoot()
    if not hum or hum.Health <= 0 then return end
    if CFG.Speed then hum.WalkSpeed = CFG.WalkSpeed end
    if CFG.Jump then
        hum.UseJumpPower = true
        hum.JumpPower = CFG.JumpPower
    end
    if CFG.Fly and flying and root then
        local move = hum.MoveDirection
        local vy = 0
        if UIS:IsKeyDown(Enum.KeyCode.Space) then vy = 1
        elseif UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vy = -1 end
        root.AssemblyLinearVelocity = Vector3.new(
            move.X * CFG.FlySpeed,
            vy * CFG.FlySpeed,
            move.Z * CFG.FlySpeed
        )
    end
end

table.insert(conns, RunService.Heartbeat:Connect(function()
    local ok, err = pcall(movementStep)
    if not ok then warn("s¡dzx̌12 move: " .. tostring(err)) end
end))

local function nearestEnemy()
    local _, myRoot = getHumRoot()
    if not myRoot then return nil end
    local best, bestD = nil, math.huge
    for _, t in ipairs(targets) do
        local r = rootOf(t.model)
        if t.hum.Health > 0 and r and t.model.Parent then
            local d = (r.Position - myRoot.Position).Magnitude
            if d < bestD then best, bestD = t, d end
        end
    end
    return best
end

local function fireOnce(now)
    if now - lastFire < CFG.FireDelay then return end
    local char = LP.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return end
    lastFire = now
    pcall(function() tool:Activate() end)
end

local function teleportBehind(model, now)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and myRoot and hum.Health > 0) then return nil end
    local r = rootOf(model)
    if not r or not r.Parent then return nil end
    local goal = aimPos(model)
    if not goal then return nil end
    if now - lastTeleport > 0.2 and (r.Position - myRoot.Position).Magnitude > 4 then
        pcall(function()
            char:PivotTo(r.CFrame * CFrame.new(0, 0, 3))
            myRoot.AssemblyLinearVelocity = Vector3.zero
        end)
        lastTeleport = now
    end
    return goal
end

-- ESP
local function espFor(model)
    if not Drawing then return nil end
    local e = espCache[model]
    if e then return e end
    e = {
        box = Drawing.new("Square"),
        line = Drawing.new("Line"),
        name = Drawing.new("Text"),
        name2 = Drawing.new("Text"),
    }
    e.box.Thickness = 1
    e.box.Filled = false
    e.line.Thickness = 1
    e.name.Size = 14
    e.name.Center = true
    e.name.Outline = true
    e.name.Color = Color3.fromRGB(255, 255, 255)
    e.name2.Size = 14
    e.name2.Center = true
    e.name2.Outline = false
    e.name2.Color = Color3.fromRGB(255, 255, 255)
    espCache[model] = e
    return e
end

local function destroyEsp(model)
    local e = espCache[model]
    if not e then return end
    pcall(function()
        e.box:Remove()
        e.line:Remove()
        e.name:Remove()
        e.name2:Remove()
    end)
    espCache[model] = nil
end

local function updateCham(model, col)
    local h = chamCache[model]
    if not h then
        h = Instance.new("Highlight")
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.78
        h.OutlineTransparency = 0.25
        chamCache[model] = h
    end
    h.Adornee = model
    h.Parent = model
    h.Enabled = true
    h.FillColor = col
    h.OutlineColor = col
end

local function destroyCham(model)
    local h = chamCache[model]
    if h then pcall(function() h:Destroy() end) end
    chamCache[model] = nil
end

local function screenBox(m, cam)
    local okBB, cf, size = pcall(m.GetBoundingBox, m)
    if not okBB or not cf or not size then return nil end
    local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, s in ipairs(CORNERS) do
        local p = cf * Vector3.new(s.X * hx, s.Y * hy, s.Z * hz)
        local sp = cam:WorldToViewportPoint(p)
        if sp.Z <= 0 then return nil end
        minX = math.min(minX, sp.X)
        minY = math.min(minY, sp.Y)
        maxX = math.max(maxX, sp.X)
        maxY = math.max(maxY, sp.Y)
    end
    return minX, minY, maxX, maxY
end

local function updateVisuals(cam)
    local espAny = CFG.ESPBox or CFG.ESPLine or CFG.ESPName
    local keepEsp, keepCham = {}, {}
    for _, v in ipairs(visList) do
        local m = v.model
        if CFG.Chams and visAllowed(v.kind, CFG.ChamsTarget) then
            keepCham[m] = true
            pcall(updateCham, m, colorFor(v.kind, CFG.ChamsRGB, CFG.ChamsColor))
        end
        if Drawing and espAny and visAllowed(v.kind, CFG.ESPTarget)
            and v.hum.Health > 0 and m.Parent then
            local minX, minY, maxX, maxY = screenBox(m, cam)
            if minX then
                keepEsp[m] = true
                local e = espFor(m)
                local col = colorFor(v.kind, CFG.ESPRGB, CFG.ESPColor)
                local midX = (minX + maxX) / 2
                e.box.Visible = CFG.ESPBox
                e.box.Color = col
                e.box.Position = Vector2.new(minX, minY)
                e.box.Size = Vector2.new(maxX - minX, maxY - minY)
                e.line.Visible = CFG.ESPLine
                e.line.Color = col
                e.line.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                e.line.To = Vector2.new(midX, maxY)
                local p = Players:GetPlayerFromCharacter(m)
                local okPiv, piv = pcall(function() return m:GetPivot().Position end)
                local dist = okPiv and math.floor((cam.CFrame.Position - piv).Magnitude) or 0
                local text = (p and p.Name or m.Name) .. " [" .. dist .. "]"
                local namePos = Vector2.new(midX, minY - 16)
                e.name.Visible = CFG.ESPName
                e.name.Text = text
                e.name.Color = col
                e.name.Position = namePos
                e.name2.Visible = CFG.ESPName
                e.name2.Text = text
                e.name2.Color = col
                e.name2.Position = namePos + Vector2.new(1, 0)
            end
        end
    end
    for m in pairs(espCache) do
        if not keepEsp[m] then destroyEsp(m) end
    end
    for m in pairs(chamCache) do
        if not keepCham[m] then destroyCham(m) end
    end
end

-- ================= UI =================
local gui = Instance.new("ScreenGui")
gui.Name = "sdzx12_menu"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
local okParent = pcall(function()
    gui.Parent = (gethui and gethui()) or CoreGui
end)
if not okParent or not gui.Parent then
    gui.Parent = LP:WaitForChild("PlayerGui")
end

-- FOV ring
local ringGui = Instance.new("ScreenGui")
ringGui.Name = "sdzx12_fov"
ringGui.IgnoreGuiInset = true
ringGui.ResetOnSpawn = false
ringGui.DisplayOrder = 998
ringGui.Parent = gui.Parent

local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromOffset(CFG.FOV * 2, CFG.FOV * 2)
ring.BackgroundTransparency = 1
ring.Parent = ringGui
Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 1.5
stroke.Color = Color3.fromRGB(180, 140, 255)
stroke.Parent = ring

local frame = Instance.new("Frame")
frame.Name = "main"
frame.Size = UDim2.fromOffset(310, 310)
frame.Position = UDim2.fromOffset(40, 110)
frame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
frame.BorderSizePixel = 0
frame.Visible = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(90, 55, 160)
mainStroke.Thickness = 1.2
mainStroke.Parent = frame

local title = Instance.new("TextButton")
title.Size = UDim2.new(1, -32, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
title.BorderSizePixel = 0
title.AutoButtonColor = false
title.Text = "  s¡dzx̌12"
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(200, 160, 255)
title.Parent = frame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

local pointerPos = UIS:GetMouseLocation()
local pointerDown = false
local dragging = false
local dragOffset = Vector2.new(0, 0)
local activeSlider = nil

local function inTitle(p)
    local a, s = title.AbsolutePosition, title.AbsoluteSize
    return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
end

local function beginDrag()
    if inTitle(pointerPos) then
        dragging = true
        dragOffset = pointerPos - frame.AbsolutePosition
    end
end

table.insert(conns, UIS.TouchStarted:Connect(function(touch)
    pointerPos = Vector2.new(touch.Position.X, touch.Position.Y)
    pointerDown = true
    beginDrag()
end))
table.insert(conns, UIS.TouchMoved:Connect(function(touch)
    pointerPos = Vector2.new(touch.Position.X, touch.Position.Y)
end))
table.insert(conns, UIS.TouchEnded:Connect(function()
    pointerDown = false
end))
table.insert(conns, UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        pointerPos = Vector2.new(input.Position.X, input.Position.Y)
    end
end))
table.insert(conns, UIS.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        pointerPos = Vector2.new(input.Position.X, input.Position.Y)
        beginDrag()
    end
end))

table.insert(conns, RunService.RenderStepped:Connect(function()
    local held = pointerDown or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    if dragging then
        if held then
            local vs = Workspace.CurrentCamera.ViewportSize
            local np = pointerPos - dragOffset
            local x = math.clamp(np.X, 0, math.max(0, vs.X - frame.AbsoluteSize.X))
            local y = math.clamp(np.Y, 0, math.max(0, vs.Y - frame.AbsoluteSize.Y))
            frame.Position = UDim2.fromOffset(x, y)
        else
            dragging = false
        end
    end
    if activeSlider then
        if held then activeSlider(pointerPos.X) else activeSlider = nil end
    end
end))

local pill = Instance.new("TextButton")
pill.Size = UDim2.fromOffset(72, 26)
pill.Position = UDim2.fromOffset(12, 12)
pill.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
pill.BorderSizePixel = 0
pill.Text = "s¡dzx̌12"
pill.Font = Enum.Font.GothamBold
pill.TextSize = 13
pill.TextColor3 = Color3.fromRGB(200, 160, 255)
pill.Visible = false
pill.Parent = gui
Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 8)

local function setMenu(v)
    frame.Visible = v
    pill.Visible = not v
end

local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.fromOffset(30, 30)
hideBtn.Position = UDim2.new(1, -30, 0, 0)
hideBtn.BackgroundColor3 = Color3.fromRGB(160, 45, 60)
hideBtn.BorderSizePixel = 0
hideBtn.Text = "×"
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 16
hideBtn.TextColor3 = Color3.new(1,1,1)
hideBtn.Parent = frame
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 8)
hideBtn.MouseButton1Click:Connect(function() setMenu(false) end)
pill.MouseButton1Click:Connect(function() setMenu(true) end)

local body = Instance.new("ScrollingFrame")
body.Position = UDim2.new(0, 0, 0, 34)
body.Size = UDim2.new(1, 0, 1, -38)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 3
body.ScrollingDirection = Enum.ScrollingDirection.X
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.X
body.Parent = frame

local strip = Instance.new("UIListLayout")
strip.FillDirection = Enum.FillDirection.Horizontal
strip.Padding = UDim.new(0, 6)
strip.SortOrder = Enum.SortOrder.LayoutOrder
strip.Parent = body

local stripPad = Instance.new("UIPadding")
stripPad.PaddingLeft = UDim.new(0, 6)
stripPad.PaddingRight = UDim.new(0, 6)
stripPad.Parent = body

local curCol = nil

local function newCol(name)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(0, 145, 1, 0)
    c.BackgroundTransparency = 1
    c.Parent = body
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 4)
    l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = c
    local h = Instance.new("TextLabel")
    h.Size = UDim2.new(1, -8, 0, 16)
    h.BackgroundTransparency = 1
    h.Text = name
    h.Font = Enum.Font.GothamBold
    h.TextSize = 12
    h.TextXAlignment = Enum.TextXAlignment.Left
    h.TextColor3 = Color3.fromRGB(160, 140, 220)
    h.Parent = c
    curCol = c
end

local function mkBtn(text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -8, 0, 26)
    b.BackgroundColor3 = Color3.fromRGB(32, 30, 44)
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.fromRGB(230, 225, 245)
    b.Font = Enum.Font.Gotham
    b.TextSize = 12
    b.Text = text
    b.Parent = curCol
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local function toggleRow(label, get, set)
    local b = mkBtn("")
    local function refresh()
        b.Text = label .. ": " .. (get() and "ON" or "OFF")
        b.BackgroundColor3 = get() and Color3.fromRGB(70, 45, 130) or Color3.fromRGB(32, 30, 44)
    end
    b.MouseButton1Click:Connect(function()
        set(not get())
        refreshAll()
    end)
    table.insert(refreshers, refresh)
    refresh()
end

local function cycleRow(label, opts, get, set)
    local b = mkBtn("")
    local function refresh()
        b.Text = label .. ": " .. get()
    end
    b.MouseButton1Click:Connect(function()
        local idx = 1
        for i, v in ipairs(opts) do
            if v == get() then idx = i end
        end
        set(opts[idx % #opts + 1])
        refreshAll()
    end)
    table.insert(refreshers, refresh)
    refresh()
end

local function sliderRow(label, get, set, min, max, step, fmt)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -8, 0, 36)
    f.BackgroundTransparency = 1
    f.Parent = curCol
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Color3.fromRGB(230, 225, 245)
    lbl.Parent = f
    local track = Instance.new("TextButton")
    track.Position = UDim2.new(0, 0, 0, 22)
    track.Size = UDim2.new(1, 0, 0, 8)
    track.BackgroundColor3 = Color3.fromRGB(45, 42, 58)
    track.BorderSizePixel = 0
    track.AutoButtonColor = false
    track.Text = ""
    track.Parent = f
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(120, 80, 210)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local function refresh()
        local v = get()
        lbl.Text = label .. " " .. fmt(v)
        fill.Size = UDim2.new(math.clamp((v - min) / (max - min), 0, 1), 0, 1, 0)
    end
    local function setFromX(x)
        local r = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = min + r * (max - min)
        v = math.floor(v / step + 0.5) * step
        set(math.clamp(v, min, max))
        refreshAll()
    end
    track.MouseButton1Down:Connect(function()
        activeSlider = setFromX
        setFromX(pointerPos.X)
    end)
    table.insert(refreshers, refresh)
    refresh()
end

local function fmtInt(v) return tostring(math.floor(v)) end
local function fmtSec(v) return string.format("%.2f", v) end

-- columns
newCol("AIM")
toggleRow("Aimbot", function() return CFG.Aimbot end, function(v) CFG.Aimbot = v end)
toggleRow("FOV Circle", function() return CFG.FOVEnabled end, function(v) CFG.FOVEnabled = v end)
sliderRow("FOV", function() return CFG.FOV end, function(v) CFG.FOV = v end, CFG.FOVMin, CFG.FOVMax, 10, fmtInt)
cycleRow("Aim Part", { "head", "neck", "body" }, function() return CFG.AimPart end, function(v) CFG.AimPart = v end)
toggleRow("Silent", function() return CFG.Silent end, function(v) CFG.Silent = v end)
toggleRow("AimKill", function() return CFG.AimKill end, function(v) CFG.AimKill = v end)
toggleRow("AimFire", function() return CFG.AimFire end, function(v) CFG.AimFire = v end)
sliderRow("Fire Delay", function() return CFG.FireDelay end, function(v) CFG.FireDelay = v end, CFG.FireMin, CFG.FireMax, 0.05, fmtSec)

newCol("MAGNET")
toggleRow("Magnet", function() return CFG.Magnet end, function(v) CFG.Magnet = v end)
sliderRow("Radius", function() return CFG.MagnetRadius end, function(v) CFG.MagnetRadius = v end, CFG.MagnetMin, CFG.MagnetMax, 10, fmtInt)
toggleRow("Body Aim", function() return CFG.BodyAim end, function(v) CFG.BodyAim = v end)

newCol("ESP")
toggleRow("Invisible", function() return CFG.Invisible end, function(v)
    CFG.Invisible = v
    applyInvis(LP.Character)
end)
cycleRow("Target", VIS_TARGETS, function() return CFG.ESPTarget end, function(v) CFG.ESPTarget = v end)
toggleRow("Box", function() return CFG.ESPBox end, function(v) CFG.ESPBox = v end)
toggleRow("Line", function() return CFG.ESPLine end, function(v) CFG.ESPLine = v end)
toggleRow("Name", function() return CFG.ESPName end, function(v) CFG.ESPName = v end)
cycleRow("Color", COLOR_ORDER, function() return CFG.ESPColor end, function(v) CFG.ESPColor = v end)
toggleRow("RGB", function() return CFG.ESPRGB end, function(v) CFG.ESPRGB = v end)

newCol("CHAMS")
toggleRow("Chams", function() return CFG.Chams end, function(v) CFG.Chams = v end)
cycleRow("Target", VIS_TARGETS, function() return CFG.ChamsTarget end, function(v) CFG.ChamsTarget = v end)
cycleRow("Color", COLOR_ORDER, function() return CFG.ChamsColor end, function(v) CFG.ChamsColor = v end)
toggleRow("RGB", function() return CFG.ChamsRGB end, function(v) CFG.ChamsRGB = v end)

newCol("KILL")
toggleRow("AutoKill", function() return CFG.AutoKill end, function(v) CFG.AutoKill = v end)

newCol("MOVE")
toggleRow("Speed", function() return CFG.Speed end, function(v)
    CFG.Speed = v
    if not v then
        local hum = getHumRoot()
        if hum then hum.WalkSpeed = origWalk end
    end
end)
sliderRow("Walk", function() return CFG.WalkSpeed end, function(v) CFG.WalkSpeed = v end, CFG.WalkMin, CFG.WalkMax, 2, fmtInt)
toggleRow("Jump", function() return CFG.Jump end, function(v)
    CFG.Jump = v
    if not v then
        local hum = getHumRoot()
        if hum then hum.JumpPower = origJump end
    end
end)
sliderRow("Jump", function() return CFG.JumpPower end, function(v) CFG.JumpPower = v end, CFG.JumpMin, CFG.JumpMax, 5, fmtInt)
toggleRow("Fly", function() return CFG.Fly end, function(v)
    CFG.Fly = v
    if not v then flying = false end
end)
do
    local b = mkBtn("")
    local function refresh()
        b.Text = "Fly [F]: " .. (flying and "ON" or "OFF")
        b.BackgroundColor3 = flying and Color3.fromRGB(70, 45, 130) or Color3.fromRGB(32, 30, 44)
    end
    b.MouseButton1Click:Connect(function()
        if CFG.Fly then flying = not flying end
        refreshAll()
    end)
    table.insert(refreshers, refresh)
    refresh()
end
sliderRow("Fly Speed", function() return CFG.FlySpeed end, function(v) CFG.FlySpeed = v end, CFG.FlyMin, CFG.FlyMax, 5, fmtInt)

-- keys
table.insert(conns, UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CFG.ToggleKey then
        CFG.Aimbot = not CFG.Aimbot
        refreshAll()
    elseif input.KeyCode == CFG.MenuKey then
        setMenu(not frame.Visible)
    elseif input.KeyCode == CFG.FlyKey then
        if CFG.Fly then
            flying = not flying
            refreshAll()
        end
    end
end))

-- combat loop
local function autoKillStep(now)
    local t = nearestEnemy()
    if not t then return nil end
    local goal = teleportBehind(t.model, now)
    if goal then fireOnce(now) end
    return goal
end

local function renderStep()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local now = os.clock()
    if now - lastScan > 0.2 then
        scan()
        lastScan = now
    end
    ring.Size = UDim2.fromOffset(CFG.FOV * 2, CFG.FOV * 2)
    ring.Visible = CFG.FOVEnabled

    if CFG.AutoKill then
        local ok, res = pcall(autoKillStep, now)
        if ok and res then
            if (res - cam.CFrame.Position).Magnitude > 0.1 then
                cam.CFrame = CFrame.lookAt(cam.CFrame.Position, res)
            end
            silentTarget = res
            return
        elseif not ok then
            warn("s¡dzx̌12 autokill: " .. tostring(res))
        end
    end

    if CFG.AimFire and CFG.FOVEnabled then
        local _, tgtModel = pickTarget()
        if tgtModel then
            local ok, res = pcall(teleportBehind, tgtModel, now)
            if ok and res then fireOnce(now) end
        end
        silentTarget = nil
        return
    end

    if CFG.Magnet then
        if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            silentTarget = pickMagnet()
        else
            silentTarget = nil
        end
        return
    end

    local tgt = nil
    if CFG.Aimbot and CFG.FOVEnabled then
        tgt = pickTarget()
    end

    local silentOn = tgt \~= nil and (CFG.AimKill
        or (CFG.Silent and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)))
    silentTarget = silentOn and tgt or nil

    if tgt and not silentOn then
        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, tgt)
    end
end

local function runVisuals()
    local cam = Workspace.CurrentCamera
    if cam then
        pcall(updateVisuals, cam)
    end
end

RunService:BindToRenderStep(BIND, Enum.RenderPriority.Last.Value, function()
    local ok, err = xpcall(renderStep, debug.traceback)
    if not ok and err \~= lastRenderErr then
        lastRenderErr = err
        warn("s¡dzx̌12 render: " .. tostring(err))
    end
    runVisuals()
end)

-- unload
if getgenv then
    getgenv().__sdzx12_unload = function()
        alive = false
        silentTarget = nil
        activeSlider = nil
        dragging = false
        flying = false
        RunService:UnbindFromRenderStep(BIND)
        for _, c in ipairs(conns) do c:Disconnect() end
        for m in pairs(espCache) do destroyEsp(m) end
        for m in pairs(chamCache) do destroyCham(m) end
        CFG.Invisible = false
        CFG.Fly = false
        CFG.Speed = false
        CFG.Jump = false
        CFG.AutoKill = false
        CFG.AimFire = false
        CFG.Magnet = false
        CFG.BodyAim = false
        CFG.Chams = false
        applyInvis(LP.Character)
        local hum = getHumRoot()
        if hum then
            hum.WalkSpeed = origWalk
            hum.JumpPower = origJump
        end
        gui:Destroy()
        ringGui:Destroy()
    end
end

refreshAll()
print("[s¡dzx̌12] loaded | RightShift = menu | RightAlt = toggle aimbot | F = fly")
