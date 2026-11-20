--[[
    s¡dzx̌12  |  Universal Shooter Cheat
    Optimized for Delta Executor (Mobile + PC)
    Works on most popular gun/shooter games
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Config
local Config = {
    Fly = false,
    FlySpeed = 60,
    Jump = false,
    JumpPower = 80,
    Run = false,
    RunSpeed = 28,
    Aimbot = false,
    AimbotSmooth = 0.18,
    AimFire = false,
    AimKill = false,
    AimSilent = false,
    AutoKill = false,
    FOV = 140,
    FOVVisible = true,
    ESP = false,
    ESPColor = Color3.fromRGB(255, 60, 60),
    Chams = false,
    ChamsColor = Color3.fromRGB(60, 255, 120),
    TeamCheck = true,
}

local Connections = {}
local BodyVelocity, BodyGyro
local FOVCircle
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "sdzx12_ESP"
pcall(function() ESPFolder.Parent = CoreGui end)

-- Utility
local function SafeCharacter()
    return LocalPlayer.Character
end

local function IsAlive(plr)
    local char = plr and plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hum and hrp and hum.Health > 0
end

local function IsEnemy(plr)
    if not Config.TeamCheck then return true end
    if LocalPlayer.Team and plr.Team then
        return LocalPlayer.Team \~= plr.Team
    end
    return true
end

local function GetClosestInFOV()
    local closest, shortest = nil, Config.FOV
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr \~= LocalPlayer and IsAlive(plr) and IsEnemy(plr) then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local screen, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    if dist < shortest then
                        shortest = dist
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

local function GetClosestPlayer()
    local closest, shortest = nil, math.huge
    local myHRP = SafeCharacter() and SafeCharacter():FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr \~= LocalPlayer and IsAlive(plr) and IsEnemy(plr) then
            local hrp = plr.Character.HumanoidRootPart
            local d = (hrp.Position - myHRP.Position).Magnitude
            if d < shortest then
                shortest = d
                closest = plr
            end
        end
    end
    return closest
end

-- Fly (Delta safe)
local function SetFly(state)
    Config.Fly = state
    local char = SafeCharacter()
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if Connections.Fly then
        Connections.Fly:Disconnect()
        Connections.Fly = nil
    end
    if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
    if BodyGyro then BodyGyro:Destroy() BodyGyro = nil end

    if state then
        BodyVelocity = Instance.new("BodyVelocity")
        BodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        BodyVelocity.Velocity = Vector3.zero
        BodyVelocity.Parent = hrp

        BodyGyro = Instance.new("BodyGyro")
        BodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        BodyGyro.P = 3000
        BodyGyro.Parent = hrp

        hum.PlatformStand = true

        Connections.Fly = RunService.Heartbeat:Connect(function()
            if not Config.Fly or not BodyVelocity or not BodyGyro then return end
            local camCF = Camera.CFrame
            local move = Vector3.zero

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                move -= Vector3.new(0,1,0)
            end

            if move.Magnitude > 0 then
                BodyVelocity.Velocity = move.Unit * Config.FlySpeed
            else
                BodyVelocity.Velocity = Vector3.zero
            end
            BodyGyro.CFrame = camCF
        end)
    else
        if hum then hum.PlatformStand = false end
    end
end

-- Jump & Run
local function ApplyMovement()
    local char = SafeCharacter()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if Config.Jump then
        hum.UseJumpPower = true
        hum.JumpPower = Config.JumpPower
    end
    if Config.Run then
        hum.WalkSpeed = Config.RunSpeed
    end
end

-- Aimbot
local function DoAimbot()
    if not Config.Aimbot then return end
    local target = GetClosestInFOV()
    if target and target.Character and target.Character:FindFirstChild("Head") then
        local headPos = target.Character.Head.Position
        local cam = Camera
        local goal = CFrame.new(cam.CFrame.Position, headPos)
        cam.CFrame = cam.CFrame:Lerp(goal, Config.AimbotSmooth)
    end
end

-- AimFire (try keep tool active / no reload feel)
local function DoAimFire()
    if not Config.AimFire then return end
    local char = SafeCharacter()
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function()
            tool:Activate()
        end)
    end
end

-- AimKill (auto look + activate)
local function DoAimKill()
    if not Config.AimKill then return end
    local target = GetClosestInFOV()
    if not target or not target.Character then return end
    local head = target.Character:FindFirstChild("Head")
    if not head then return end

    local oldCF = Camera.CFrame
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)

    local char = SafeCharacter()
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function() tool:Activate() end)
        end
    end
    task.wait()
    Camera.CFrame = oldCF
end

-- AimSilent (only when holding shoot / mouse1 or touch)
local function DoAimSilent()
    if not Config.AimSilent then return end
    local holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        or UserInputService:IsKeyDown(Enum.KeyCode.ButtonR2) -- controller

    if not holding then return end

    local target = GetClosestInFOV()
    if not target or not target.Character then return end
    local head = target.Character:FindFirstChild("Head")
    if not head then return end

    local oldCF = Camera.CFrame
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
    task.wait()
    Camera.CFrame = oldCF
end

-- AutoKill (teleport behind + kill attempt)
local function DoAutoKill()
    if not Config.AutoKill then return end
    local target = GetClosestPlayer()
    if not target or not target.Character then return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local myChar = SafeCharacter()
    if not tHRP or not myChar then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3)
    local hum = target.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.Health = 0
        end)
    end
end

-- Teleport
local function TeleportTo(input)
    local char = SafeCharacter()
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local targetPlr = Players:FindFirstChild(input)
    if targetPlr and IsAlive(targetPlr) then
        hrp.CFrame = targetPlr.Character.HumanoidRootPart.CFrame + Vector3.new(0, 4, 0)
        return
    end

    local x, y, z = string.match(input, "([^,]+),([^,]+),([^,]+)")
    if x and y and z then
        hrp.CFrame = CFrame.new(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
    end
end

-- FOV Circle (Drawing - Delta supports it)
local function CreateFOV()
    if FOVCircle then
        pcall(function() FOVCircle:Remove() end)
        FOVCircle = nil
    end
    local success, circle = pcall(function()
        return Drawing.new("Circle")
    end)
    if success and circle then
        FOVCircle = circle
        FOVCircle.Thickness = 1.5
        FOVCircle.NumSides = 48
        FOVCircle.Radius = Config.FOV
        FOVCircle.Filled = false
        FOVCircle.Color = Color3.fromRGB(255, 255, 255)
        FOVCircle.Transparency = 0.35
        FOVCircle.Visible = Config.FOVVisible
    end
end

local function UpdateFOV()
    if not FOVCircle then return end
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    FOVCircle.Radius = Config.FOV
    FOVCircle.Visible = Config.FOVVisible
end

-- ESP
local function ClearESP()
    for _, v in ipairs(ESPFolder:GetChildren()) do
        v:Destroy()
    end
end

local function MakeESP(plr)
    if not IsAlive(plr) or not IsEnemy(plr) then return end
    local char = plr.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = plr.Name
    bb.Adornee = hrp
    bb.Size = UDim2.new(0, 160, 0, 40)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = ESPFolder

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = plr.DisplayName or plr.Name
    nameLbl.TextColor3 = Config.ESPColor
    nameLbl.TextStrokeTransparency = 0.4
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.Parent = bb

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0.45, 0)
    distLbl.Position = UDim2.new(0, 0, 0.55, 0)
    distLbl.BackgroundTransparency = 1
    distLbl.TextColor3 = Config.ESPColor
    distLbl.TextStrokeTransparency = 0.4
    distLbl.Font = Enum.Font.Gotham
    distLbl.TextSize = 11
    distLbl.Parent = bb

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Box"
    box.Adornee = hrp
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Size = Vector3.new(3.5, 5.5, 2)
    box.Color3 = Config.ESPColor
    box.Transparency = 0.55
    box.Parent = ESPFolder

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not Config.ESP or not IsAlive(plr) then
            bb:Destroy()
            box:Destroy()
            if conn then conn:Disconnect() end
            return
        end
        local myHRP = SafeCharacter() and SafeCharacter():FindFirstChild("HumanoidRootPart")
        if myHRP then
            distLbl.Text = math.floor((hrp.Position - myHRP.Position).Magnitude) .. "m"
        end
        nameLbl.TextColor3 = Config.ESPColor
        distLbl.TextColor3 = Config.ESPColor
        box.Color3 = Config.ESPColor
    end)
end

local function RefreshESP()
    ClearESP()
    if not Config.ESP then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr \~= LocalPlayer then
            MakeESP(plr)
        end
    end
end

-- Chams (Highlight - works well on modern Roblox)
local function ClearChams()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            local h = plr.Character:FindFirstChild("sdzx12_Chams")
            if h then h:Destroy() end
        end
    end
end

local function ApplyChams()
    ClearChams()
    if not Config.Chams then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr \~= LocalPlayer and IsAlive(plr) and not IsEnemy(plr) then
            local hl = Instance.new("Highlight")
            hl.Name = "sdzx12_Chams"
            hl.Adornee = plr.Character
            hl.FillColor = Config.ChamsColor
            hl.OutlineColor = Config.ChamsColor
            hl.FillTransparency = 0.45
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = plr.Character
        end
    end
end

-- Main loop
Connections.Main = RunService.Heartbeat:Connect(function()
    ApplyMovement()
    DoAimbot()
    DoAimFire()
    if Config.AimKill then DoAimKill() end
    DoAimSilent()
    if Config.AutoKill then DoAutoKill() end
    UpdateFOV()
end)

-- Respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.2)
    if Config.Fly then SetFly(true) end
    ApplyMovement()
    RefreshESP()
    ApplyChams()
end)

Players.PlayerAdded:Connect(function()
    task.wait(1)
    if Config.ESP then RefreshESP() end
    if Config.Chams then ApplyChams() end
end)

-- ================= UI =================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "sdzx12"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 480, 0, 360)
Main.Position = UDim2.new(0.5, -240, 0.5, -180)
Main.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = Main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 50, 160)
stroke.Thickness = 1.4
stroke.Parent = Main

-- Title
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(26, 22, 38)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main
local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 10)
tc.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "s¡dzx̌12"
Title.TextColor3 = Color3.fromRGB(195, 155, 255)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 30, 0, 30)
Close.Position = UDim2.new(1, -36, 0, 5)
Close.BackgroundColor3 = Color3.fromRGB(170, 45, 55)
Close.Text = "X"
Close.TextColor3 = Color3.white
Close.Font = Enum.Font.GothamBold
Close.TextSize = 14
Close.Parent = TitleBar
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 7)
cc.Parent = Close

Close.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    for _, c in pairs(Connections) do
        if typeof(c) == "RBXScriptConnection" then pcall(function() c:Disconnect() end) end
    end
    if FOVCircle then pcall(function() FOVCircle:Remove() end) end
    ClearESP()
    ClearChams()
    SetFly(false)
end)

-- Tabs
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(0, 115, 1, -40)
TabBar.Position = UDim2.new(0, 0, 0, 40)
TabBar.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -115, 1, -40)
Content.Position = UDim2.new(0, 115, 0, 40)
Content.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
Content.BorderSizePixel = 0
Content.Parent = Main

local Pages = {}
local function MakeTab(name, y)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 34)
    btn.Position = UDim2.new(0, 5, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(30, 26, 42)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(175, 165, 195)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = TabBar
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 7)
    bc.Parent = btn

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -12, 1, -12)
    page.Position = UDim2.new(0, 6, 0, 6)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 520)
    page.Parent = Content

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 7)
    list.Parent = page

    Pages[name] = {btn = btn, page = page}

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do
            p.page.Visible = false
            p.btn.BackgroundColor3 = Color3.fromRGB(30, 26, 42)
            p.btn.TextColor3 = Color3.fromRGB(175, 165, 195)
        end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(85, 50, 150)
        btn.TextColor3 = Color3.white
    end)

    return page
end

local function Toggle(parent, text, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -6, 0, 34)
    f.BackgroundColor3 = Color3.fromRGB(26, 24, 36)
    f.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -55, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 210, 235)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 40, 0, 20)
    btn.Position = UDim2.new(1, -48, 0.5, -10)
    btn.BackgroundColor3 = default and Color3.fromRGB(95, 55, 175) or Color3.fromRGB(48, 46, 58)
    btn.Text = ""
    btn.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = btn

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 14, 0, 14)
    circle.Position = default and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    circle.BackgroundColor3 = Color3.white
    circle.Parent = btn
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(1, 0)
    cc.Parent = circle

    local on = default
    btn.MouseButton1Click:Connect(function()
        on = not on
        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundColor3 = on and Color3.fromRGB(95, 55, 175) or Color3.fromRGB(48, 46, 58)
        }):Play()
        TweenService:Create(circle, TweenInfo.new(0.12), {
            Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        }):Play()
        cb(on)
    end)
end

local function Slider(parent, text, min, max, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -6, 0, 52)
    f.BackgroundColor3 = Color3.fromRGB(26, 24, 36)
    f.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = text .. ": " .. default
    lbl.TextColor3 = Color3.fromRGB(220, 210, 235)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 5)
    bar.Position = UDim2.new(0, 10, 0, 32)
    bar.BackgroundColor3 = Color3.fromRGB(40, 38, 52)
    bar.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(115, 70, 195)
    fill.Parent = bar
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = fill

    local holding = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            holding = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            holding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if holding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max - min) * rel)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            lbl.Text = text .. ": " .. val
            cb(val)
        end
    end)
end

local function Btn(parent, text, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -6, 0, 32)
    b.BackgroundColor3 = Color3.fromRGB(70, 45, 130)
    b.Text = text
    b.TextColor3 = Color3.white
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = b
    b.MouseButton1Click:Connect(cb)
end

local function TextBox(parent, placeholder, cb)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -6, 0, 32)
    box.BackgroundColor3 = Color3.fromRGB(26, 24, 36)
    box.PlaceholderText = placeholder
    box.Text = ""
    box.TextColor3 = Color3.fromRGB(220, 210, 235)
    box.PlaceholderColor3 = Color3.fromRGB(120, 110, 140)
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = box
    box.FocusLost:Connect(function(enter)
        if enter and box.Text \~= "" then cb(box.Text) end
    end)
end

-- Pages
local Combat = MakeTab("Combat", 12)
local Move = MakeTab("Movement", 52)
local Visual = MakeTab("Visuals", 92)
local Misc = MakeTab("Misc", 132)

-- Combat
Toggle(Combat, "Aimbot (Head)", false, function(v) Config.Aimbot = v end)
Toggle(Combat, "AimFire (Spam Shot)", false, function(v) Config.AimFire = v end)
Toggle(Combat, "AimKill (Auto in FOV)", false, function(v) Config.AimKill = v end)
Toggle(Combat, "AimSilent (Hold Shoot)", false, function(v) Config.AimSilent = v end)
Toggle(Combat, "AutoKill", false, function(v) Config.AutoKill = v end)
Slider(Combat, "FOV Size", 40, 400, 140, function(v) Config.FOV = v end)
Toggle(Combat, "Show FOV Circle", true, function(v) Config.FOVVisible = v end)
Toggle(Combat, "Team Check", true, function(v) Config.TeamCheck = v end)

-- Movement
Toggle(Move, "Fly", false, function(v) SetFly(v) end)
Slider(Move, "Fly Speed", 20, 200, 60, function(v) Config.FlySpeed = v end)
Toggle(Move, "Jump Boost", false, function(v) Config.Jump = v ApplyMovement() end)
Slider(Move, "Jump Power", 50, 500, 80, function(v) Config.JumpPower = v ApplyMovement() end)
Toggle(Move, "Run Boost", false, function(v) Config.Run = v ApplyMovement() end)
Slider(Move, "Run Speed", 16, 150, 28, function(v) Config.RunSpeed = v ApplyMovement() end)

-- Visuals
Toggle(Visual, "ESP (Enemies)", false, function(v) Config.ESP = v RefreshESP() end)
Toggle(Visual, "Chams (Team)", false, function(v) Config.Chams = v ApplyChams() end)

local function ColorRow(parent, label, isESP)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -6, 0, 34)
    f.BackgroundColor3 = Color3.fromRGB(26, 24, 36)
    f.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.35, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220, 210, 235)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local cols = {
        Color3.fromRGB(255, 60, 60),
        Color3.fromRGB(60, 255, 100),
        Color3.fromRGB(60, 140, 255),
        Color3.fromRGB(255, 220, 50),
        Color3.fromRGB(200, 90, 255),
    }
    for i, col in ipairs(cols) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 24, 0, 20)
        b.Position = UDim2.new(0, 130 + (i-1)*30, 0.5, -10)
        b.BackgroundColor3 = col
        b.Text = ""
        b.Parent = f
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 5)
        bc.Parent = b
        b.MouseButton1Click:Connect(function()
            if isESP then
                Config.ESPColor = col
                RefreshESP()
            else
                Config.ChamsColor = col
                ApplyChams()
            end
        end)
    end
end

ColorRow(Visual, "ESP Color", true)
ColorRow(Visual, "Chams Color", false)

-- Misc
TextBox(Misc, "TP Username or x,y,z", function(t) TeleportTo(t) end)
Btn(Misc, "Teleport to Mouse", function()
    local char = SafeCharacter()
    if char and char:FindFirstChild("HumanoidRootPart") and Mouse.Hit then
        char.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 4, 0))
    end
end)

-- Open first tab
Pages["Combat"].btn.BackgroundColor3 = Color3.fromRGB(85, 50, 150)
Pages["Combat"].btn.TextColor3 = Color3.white
Pages["Combat"].page.Visible = true

-- Create FOV
CreateFOV()

-- Toggle UI
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.F4 then
        Main.Visible = not Main.Visible
    end
end)

print("[s¡dzx̌12] Loaded | RightShift / F4 = Toggle UI")
