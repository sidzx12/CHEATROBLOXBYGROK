-- s¡dzx̌12 | Delta optimized | black-purple neon | touch friendly
if getgenv and getgenv().__sdzx12_unload then
    pcall(getgenv().__sdzx12_unload)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local CFG = {
    Aimbot = true,
    FOVEnabled = true,
    FOV = 150,
    AimPart = "head",
    Silent = false,
    AimKill = false,
    AimFire = false,
    FireDelay = 0.3,
    Magnet = false,
    MagnetRadius = 90,
    BodyAim = false,
    Invisible = false,
    TeamCheck = true,
    NPCs = true,
    WallCheck = false,
    Speed = false,
    WalkSpeed = 28,
    Jump = false,
    JumpPower = 80,
    Fly = false,
    FlySpeed = 60,
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
}

local LP = Players.LocalPlayer
local BIND = "sdzx12_loop"
local alive = true
local conns = {}
local targets, visList = {}, {}
local lastScan, lastFire, lastTeleport = 0, 0, 0
local silentTarget = nil
local origWalk, origJump = 16, 50
local flying = false
local espCache, chamCache = {}, {}

local COLOR_ORDER = {"red","orange","yellow","green","cyan","blue","magenta","white"}
local COLORS = {
    red=Color3.fromRGB(255,80,80), orange=Color3.fromRGB(255,150,60),
    yellow=Color3.fromRGB(255,230,80), green=Color3.fromRGB(90,255,120),
    cyan=Color3.fromRGB(80,230,255), blue=Color3.fromRGB(90,140,255),
    magenta=Color3.fromRGB(255,90,230), white=Color3.fromRGB(255,255,255)
}
local NPC_PINK = Color3.fromRGB(255,105,180)
local VIS_TARGETS = {"enemies","friends","all"}

local function colorFor(kind, useRgb, preset)
    if kind == "npc" then return NPC_PINK end
    if useRgb then return Color3.fromHSV((os.clock()*0.4)%1, 1, 1) end
    return COLORS[preset] or COLORS.white
end

local function rootOf(m)
    return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
end
local function torsoOf(m)
    return m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") or m:FindFirstChild("HumanoidRootPart")
end

local function aimPos(model)
    if CFG.BodyAim then
        local t = torsoOf(model)
        return t and t.Position
    end
    local head = model:FindFirstChild("Head")
    local torso = torsoOf(model)
    if CFG.AimPart == "head" and head then return head.Position end
    if CFG.AimPart == "neck" and head then return head.Position - Vector3.new(0, head.Size.Y*0.5, 0) end
    return (torso and torso.Position) or (head and head.Position)
end

local function isFriend(p)
    if LP.Team and p.Team == LP.Team then return true end
    local ok, r = pcall(function() return LP:IsFriendsWith(p.UserId) end)
    return ok and r
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
                local k = kindOf(m)
                if k then table.insert(visList, {hum=d, model=m, kind=k}) end
                if isEnemy(m) then table.insert(targets, {hum=d, model=m}) end
            end
        end
    end
end

local function visible(pos, model)
    if not CFG.WallCheck then return true end
    local cam = Workspace.CurrentCamera
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {cam, LP.Character}
    local ray = Workspace:Raycast(cam.CFrame.Position, pos - cam.CFrame.Position, params)
    if not ray then return true end
    return ray.Instance:IsDescendantOf(model)
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

-- silent hook
local oldNamecall
pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if not alive or not silentTarget or checkcaller() or self \~= Workspace then
            return oldNamecall(self, ...)
        end
        local method = getnamecallmethod()
        local args = table.pack(...)
        local cam = Workspace.CurrentCamera
        if method == "Raycast" then
            local origin, dir = args[1], args[2]
            if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" and (origin - cam.CFrame.Position).Magnitude < 20 then
                local toT = silentTarget - origin
                if toT.Magnitude > 0 then
                    args[2] = toT.Unit * dir.Magnitude
                    return oldNamecall(self, table.unpack(args, 1, args.n))
                end
            end
        end
        return oldNamecall(self, ...)
    end))
end)

local function getHumRoot()
    local char = LP.Character
    if not char then return nil, nil end
    return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function movementStep()
    local hum, root = getHumRoot()
    if not hum or hum.Health <= 0 then return end
    if CFG.Speed then hum.WalkSpeed = CFG.WalkSpeed end
    if CFG.Jump then hum.UseJumpPower = true hum.JumpPower = CFG.JumpPower end
    if CFG.Fly and flying and root then
        local move = hum.MoveDirection
        local vy = UIS:IsKeyDown(Enum.KeyCode.Space) and 1 or (UIS:IsKeyDown(Enum.KeyCode.LeftControl) and -1 or 0)
        root.AssemblyLinearVelocity = Vector3.new(move.X * CFG.FlySpeed, vy * CFG.FlySpeed, move.Z * CFG.FlySpeed)
    end
end
table.insert(conns, RunService.Heartbeat:Connect(function() pcall(movementStep) end))

local function nearestEnemy()
    local _, myRoot = getHumRoot()
    if not myRoot then return nil end
    local best, bestD = nil, math.huge
    for _, t in ipairs(targets) do
        local r = rootOf(t.model)
        if t.hum.Health > 0 and r then
            local d = (r.Position - myRoot.Position).Magnitude
            if d < bestD then best, bestD = t, d end
        end
    end
    return best
end

local function fireOnce(now)
    if now - lastFire < CFG.FireDelay then return end
    local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
    if tool then lastFire = now pcall(function() tool:Activate() end) end
end

local function teleportBehind(model, now)
    local char = LP.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local r = rootOf(model)
    if not (myRoot and r) then return nil end
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

-- ESP + Chams (simplified for stability)
local function destroyEsp(model)
    local e = espCache[model]
    if e then
        pcall(function() e.box:Remove() e.line:Remove() e.name:Remove() end)
        espCache[model] = nil
    end
end

local function destroyCham(model)
    local h = chamCache[model]
    if h then pcall(function() h:Destroy() end) chamCache[model] = nil end
end

local function updateVisuals(cam)
    local keepEsp, keepCham = {}, {}
    for _, v in ipairs(visList) do
        local m = v.model
        if CFG.Chams and visAllowed(v.kind, CFG.ChamsTarget) then
            keepCham[m] = true
            local h = chamCache[m]
            if not h then
                h = Instance.new("Highlight")
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.FillTransparency = 0.75
                h.OutlineTransparency = 0.2
                chamCache[m] = h
            end
            h.Adornee = m
            h.Parent = m
            h.FillColor = colorFor(v.kind, CFG.ChamsRGB, CFG.ChamsColor)
            h.OutlineColor = h.FillColor
        end
    end
    for m in pairs(espCache) do if not keepEsp[m] then destroyEsp(m) end end
    for m in pairs(chamCache) do if not keepCham[m] then destroyCham(m) end end
end

-- ================= UI =================
local gui = Instance.new("ScreenGui")
gui.Name = "sdzx12"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = gethui and gethui() or CoreGui end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

-- FOV Ring
local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromOffset(CFG.FOV*2, CFG.FOV*2)
ring.BackgroundTransparency = 1
ring.Parent = gui
Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
local ringStroke = Instance.new("UIStroke")
ringStroke.Thickness = 1.5
ringStroke.Color = Color3.fromRGB(180, 100, 255)
ringStroke.Parent = ring

-- Main Frame
local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(340, 380)
main.Position = UDim2.fromOffset(30, 100)
main.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local ms = Instance.new("UIStroke")
ms.Color = Color3.fromRGB(120, 60, 200)
ms.Thickness = 1.5
ms.Parent = main

-- Title
local title = Instance.new("TextButton")
title.Size = UDim2.new(1, -40, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(22, 18, 32)
title.BorderSizePixel = 0
title.AutoButtonColor = false
title.Text = "  s¡dzx̌12"
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(200, 150, 255)
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 12)

-- Close / Minimize
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(32, 32)
closeBtn.Position = UDim2.new(1, -36, 0, 2)
closeBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 60)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = main
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- Reopen Pill
local pill = Instance.new("TextButton")
pill.Size = UDim2.fromOffset(80, 28)
pill.Position = UDim2.fromOffset(12, 12)
pill.BackgroundColor3 = Color3.fromRGB(22, 18, 32)
pill.Text = "s¡dzx̌12"
pill.Font = Enum.Font.GothamBold
pill.TextSize = 13
pill.TextColor3 = Color3.fromRGB(200, 150, 255)
pill.Visible = false
pill.Parent = gui
Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 8)
local ps = Instance.new("UIStroke")
ps.Color = Color3.fromRGB(120, 60, 200)
ps.Thickness = 1
ps.Parent = pill

local function setMenu(v)
    main.Visible = v
    pill.Visible = not v
end
closeBtn.MouseButton1Click:Connect(function() setMenu(false) end)
pill.MouseButton1Click:Connect(function() setMenu(true) end)

-- Drag
local drag, dragStart, startPos
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag = true
        dragStart = input.Position
        startPos = main.Position
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag = false
    end
end)
UIS.InputChanged:Connect(function(input)
    if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Tabs
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 34)
tabBar.Position = UDim2.new(0, 8, 0, 42)
tabBar.BackgroundTransparency = 1
tabBar.Parent = main

local tabs = {"AIM", "VISUALS", "MOVE", "SETTINGS"}
local pages = {}
local currentTab = "AIM"

local function makeTab(name, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.24, 0, 1, 0)
    b.Position = UDim2.new(x, 0, 0, 0)
    b.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
    b.Text = name
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextColor3 = Color3.fromRGB(180, 170, 210)
    b.Parent = tabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -16, 1, -90)
content.Position = UDim2.new(0, 8, 0, 82)
content.BackgroundTransparency = 1
content.Parent = main

for i, name in ipairs(tabs) do
    local btn = makeTab(name, (i-1)*0.25)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.Visible = (name == "AIM")
    page.CanvasSize = UDim2.new(0, 0, 0, 500)
    page.Parent = content
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 6)
    list.Parent = page
    pages[name] = {btn=btn, page=page}
    btn.MouseButton1Click:Connect(function()
        for n, p in pairs(pages) do
            p.page.Visible = false
            p.btn.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
            p.btn.TextColor3 = Color3.fromRGB(180, 170, 210)
        end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(90, 50, 160)
        btn.TextColor3 = Color3.new(1,1,1)
        currentTab = name
    end)
end
pages["AIM"].btn.BackgroundColor3 = Color3.fromRGB(90, 50, 160)
pages["AIM"].btn.TextColor3 = Color3.new(1,1,1)

local function addToggle(parent, text, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 34)
    f.BackgroundColor3 = Color3.fromRGB(22, 20, 32)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(220, 210, 240)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(44, 22)
    btn.Position = UDim2.new(1, -52, 0.5, -11)
    btn.BackgroundColor3 = default and Color3.fromRGB(100, 60, 180) or Color3.fromRGB(45, 42, 58)
    btn.Text = ""
    btn.Parent = f
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    local circle = Instance.new("Frame")
    circle.Size = UDim2.fromOffset(16, 16)
    circle.Position = default and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    circle.BackgroundColor3 = Color3.new(1,1,1)
    circle.Parent = btn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = state and Color3.fromRGB(100, 60, 180) or Color3.fromRGB(45, 42, 58)}):Play()
        TweenService:Create(circle, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}):Play()
        callback(state)
    end)
end

local function addSlider(parent, text, min, max, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 50)
    f.BackgroundColor3 = Color3.fromRGB(22, 20, 32)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = text .. ": " .. default
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(220, 210, 240)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 6)
    bar.Position = UDim2.new(0, 12, 0, 32)
    bar.BackgroundColor3 = Color3.fromRGB(40, 36, 55)
    bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(130, 80, 220)
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local holding = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            holding = true
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            holding = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if holding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max-min)*rel)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            lbl.Text = text .. ": " .. val
            callback(val)
        end
    end)
end

-- AIM Tab
addToggle(pages.AIM.page, "Aimbot", true, function(v) CFG.Aimbot = v end)
addToggle(pages.AIM.page, "FOV Circle", true, function(v) CFG.FOVEnabled = v ring.Visible = v end)
addSlider(pages.AIM.page, "FOV Size", 40, 400, 150, function(v) CFG.FOV = v end)
addToggle(pages.AIM.page, "Silent Aim", false, function(v) CFG.Silent = v end)
addToggle(pages.AIM.page, "AimKill", false, function(v) CFG.AimKill = v end)
addToggle(pages.AIM.page, "AimFire", false, function(v) CFG.AimFire = v end)
addSlider(pages.AIM.page, "Fire Delay", 0.1, 1, 0.3, function(v) CFG.FireDelay = v end)
addToggle(pages.AIM.page, "Magnet", false, function(v) CFG.Magnet = v end)
addSlider(pages.AIM.page, "Magnet Radius", 20, 300, 90, function(v) CFG.MagnetRadius = v end)
addToggle(pages.AIM.page, "Body Aim", false, function(v) CFG.BodyAim = v end)

-- VISUALS Tab
addToggle(pages.VISUALS.page, "ESP Box", false, function(v) CFG.ESPBox = v end)
addToggle(pages.VISUALS.page, "ESP Line", false, function(v) CFG.ESPLine = v end)
addToggle(pages.VISUALS.page, "ESP Name", false, function(v) CFG.ESPName = v end)
addToggle(pages.VISUALS.page, "ESP RGB", false, function(v) CFG.ESPRGB = v end)
addToggle(pages.VISUALS.page, "Chams", false, function(v) CFG.Chams = v end)
addToggle(pages.VISUALS.page, "Chams RGB", false, function(v) CFG.ChamsRGB = v end)
addToggle(pages.VISUALS.page, "Invisible", false, function(v)
    CFG.Invisible = v
    if LP.Character then
        for _, d in ipairs(LP.Character:GetDescendants()) do
            if d:IsA("BasePart") then d.LocalTransparencyModifier = v and 1 or 0 end
        end
    end
end)

-- MOVE Tab
addToggle(pages.MOVE.page, "Speed", false, function(v) CFG.Speed = v end)
addSlider(pages.MOVE.page, "Walk Speed", 16, 150, 28, function(v) CFG.WalkSpeed = v end)
addToggle(pages.MOVE.page, "Jump Boost", false, function(v) CFG.Jump = v end)
addSlider(pages.MOVE.page, "Jump Power", 50, 300, 80, function(v) CFG.JumpPower = v end)
addToggle(pages.MOVE.page, "Fly", false, function(v) CFG.Fly = v if not v then flying = false end end)
addSlider(pages.MOVE.page, "Fly Speed", 20, 200, 60, function(v) CFG.FlySpeed = v end)

-- SETTINGS Tab
addToggle(pages.SETTINGS.page, "Team Check", true, function(v) CFG.TeamCheck = v end)
addToggle(pages.SETTINGS.page, "Target NPCs", true, function(v) CFG.NPCs = v end)
addToggle(pages.SETTINGS.page, "Wall Check", false, function(v) CFG.WallCheck = v end)
addToggle(pages.SETTINGS.page, "AutoKill", false, function(v) CFG.AutoKill = v end)

-- Main Loop
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Last.Value, function()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local now = os.clock()
    if now - lastScan > 0.25 then scan() lastScan = now end
    ring.Size = UDim2.fromOffset(CFG.FOV*2, CFG.FOV*2)
    ring.Visible = CFG.FOVEnabled

    if CFG.AutoKill then
        local t = nearestEnemy()
        if t then
            local goal = teleportBehind(t.model, now)
            if goal then
                cam.CFrame = CFrame.lookAt(cam.CFrame.Position, goal)
                fireOnce(now)
                silentTarget = goal
            end
        end
        return
    end

    if CFG.AimFire then
        local _, model = pickTarget()
        if model then
            local goal = teleportBehind(model, now)
            if goal then fireOnce(now) end
        end
        silentTarget = nil
        return
    end

    if CFG.Magnet and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        silentTarget = pickMagnet()
        return
    end

    local tgt = (CFG.Aimbot and CFG.FOVEnabled) and pickTarget() or nil
    local silentOn = tgt and (CFG.AimKill or (CFG.Silent and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)))
    silentTarget = silentOn and tgt or nil
    if tgt and not silentOn then
        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, tgt)
    end

    pcall(updateVisuals, cam)
end)

-- Keys
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setMenu(not main.Visible)
    elseif input.KeyCode == Enum.KeyCode.F and CFG.Fly then
        flying = not flying
    end
end)

-- Cleanup
if getgenv then
    getgenv().__sdzx12_unload = function()
        alive = false
        silentTarget = nil
        flying = false
        RunService:UnbindFromRenderStep(BIND)
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for m in pairs(espCache) do destroyEsp(m) end
        for m in pairs(chamCache) do destroyCham(m) end
        gui:Destroy()
    end
end

print("[s¡dzx̌12] loaded | RightShift = menu | F = fly")
