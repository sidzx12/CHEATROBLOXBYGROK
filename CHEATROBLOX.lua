--[[
    s¡dzx̌12  |  Roblox Cheat
    Language: Luau (Roblox)
    Target: Any game that uses default Humanoid + Camera (most shooters / fps / combat games)
    Run in: Synapse X / Script-Ware / Krnl / Fluxus / Wave / Solara
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

--// Config
local Config = {
    Fly = false,
    FlySpeed = 50,
    Jump = false,
    JumpPower = 50,
    Run = false,
    RunSpeed = 16,
    Aimbot = false,
    AimbotSmooth = 0.15,
    AimFire = false,
    AimKill = false,
    AimSilent = false,
    AutoKill = false,
    FOV = 120,
    FOVVisible = true,
    ESP = false,
    ESPColor = Color3.fromRGB(255, 50, 50),
    Chams = false,
    ChamsColor = Color3.fromRGB(50, 255, 100),
    TeamCheck = true,
    SilentAimKey = Enum.UserInputType.MouseButton1,
}

--// State
local Connections = {}
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "s¡dzx̌12_ESP"
ESPFolder.Parent = CoreGui

local BodyVelocity, BodyGyro
local FOVCircle
local AimTarget = nil

--// Utility
local function IsAlive(plr)
    return plr and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0
        and plr.Character:FindFirstChild("HumanoidRootPart")
end

local function IsEnemy(plr)
    if not Config.TeamCheck then return true end
    if LocalPlayer.Team and plr.Team then
        return LocalPlayer.Team \~= plr.Team
    end
    return true
end

local function GetClosestToCenter(fov)
    local closest, dist = nil, fov or Config.FOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr \~= LocalPlayer and IsAlive(plr) and IsEnemy(plr) then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if d < dist then
                        dist = d
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

local function GetClosestPlayer()
    local closest, dist = nil, math.huge
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr \~= LocalPlayer and IsAlive(plr) and IsEnemy(plr) then
            local hrp = plr.Character.HumanoidRootPart
            local d = (hrp.Position - root.Position).Magnitude
            if d < dist then
                dist = d
                closest = plr
            end
        end
    end
    return closest
end

--// Fly
local function ToggleFly(state)
    Config.Fly = state
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    if state then
        BodyVelocity = Instance.new("BodyVelocity")
        BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        BodyVelocity.Velocity = Vector3.zero
        BodyVelocity.Parent = hrp

        BodyGyro = Instance.new("BodyGyro")
        BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        BodyGyro.P = 9e4
        BodyGyro.Parent = hrp

        hum.PlatformStand = true

        Connections.Fly = RunService.RenderStepped:Connect(function()
            if not Config.Fly or not BodyVelocity or not BodyGyro then return end
            local cam = Workspace.CurrentCamera
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
            BodyVelocity.Velocity = dir.Unit * Config.FlySpeed
            if dir.Magnitude < 0.1 then BodyVelocity.Velocity = Vector3.zero end
            BodyGyro.CFrame = cam.CFrame
        end)
    else
        if Connections.Fly then Connections.Fly:Disconnect() Connections.Fly = nil end
        if BodyVelocity then BodyVelocity:Destroy() BodyVelocity = nil end
        if BodyGyro then BodyGyro:Destroy() BodyGyro = nil end
        if hum then hum.PlatformStand = false end
    end
end

--// Jump / Run
local function ApplyJumpRun()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    if Config.Jump then
        hum.JumpPower = Config.JumpPower
        hum.UseJumpPower = true
    else
        hum.JumpPower = 50
    end
    if Config.Run then
        hum.WalkSpeed = Config.RunSpeed
    else
        hum.WalkSpeed = 16
    end
end

--// Aimbot (chase head)
local function DoAimbot()
    if not Config.Aimbot then return end
    local target = GetClosestToCenter(Config.FOV)
    if target and target.Character and target.Character:FindFirstChild("Head") then
        local head = target.Character.Head
        local cam = Workspace.CurrentCamera
        local goal = CFrame.new(cam.CFrame.Position, head.Position)
        cam.CFrame = cam.CFrame:Lerp(goal, Config.AimbotSmooth)
    end
end

--// AimFire (no reload / infinite ammo style - best effort)
local function DoAimFire()
    if not Config.AimFire then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local ammo = tool:FindFirstChild("Ammo") or tool:FindFirstChild("ammo") or tool:FindFirstChild("Clip")
            if ammo and ammo:IsA("NumberValue") or ammo:IsA("IntValue") then
                ammo.Value = 999
            end
            pcall(function()
                tool:Activate()
            end)
        end
    end
end

--// AimKill (auto shoot + silent style)
local function DoAimKill()
    if not Config.AimKill then return end
    local target = GetClosestToCenter(Config.FOV)
    if target and target.Character and target.Character:FindFirstChild("Head") then
        local head = target.Character.Head
        -- silent aim: set camera briefly then fire
        local old = Camera.CFrame
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
        mouse1click() -- many executors provide this
        task.wait()
        Camera.CFrame = old
    end
end

--// AimSilent (same as AimKill but only when shoot button held)
local function DoAimSilent()
    if not Config.AimSilent then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end
    local target = GetClosestToCenter(Config.FOV)
    if target and target.Character and target.Character:FindFirstChild("Head") then
        local head = target.Character.Head
        local old = Camera.CFrame
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
        task.wait()
        Camera.CFrame = old
    end
end

--// AutoKill
local function DoAutoKill()
    if not Config.AutoKill then return end
    local target = GetClosestPlayer()
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2)
            -- force damage if possible
            local hum = target.Character:FindFirstChild("Humanoid")
            if hum then
                pcall(function()
                    hum.Health = 0
                end)
            end
        end
    end
end

--// Teleport
local function TeleportTo(input)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    -- try player name first
    local targetPlr = Players:FindFirstChild(input)
    if targetPlr and IsAlive(targetPlr) then
        hrp.CFrame = targetPlr.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
        return
    end

    -- try coordinates "x,y,z"
    local x, y, z = input:match("([^,]+),([^,]+),([^,]+)")
    if x and y and z then
        hrp.CFrame = CFrame.new(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
    end
end

--// FOV Circle
local function UpdateFOVCircle()
    if not FOVCircle then
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness = 1.5
        FOVCircle.NumSides = 64
        FOVCircle.Radius = Config.FOV
        FOVCircle.Filled = false
        FOVCircle.Visible = Config.FOVVisible
        FOVCircle.Color = Color3.fromRGB(255, 255, 255)
        FOVCircle.Transparency = 0.3
    end
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Radius = Config.FOV
    FOVCircle.Visible = Config.FOVVisible
end

--// ESP
local function ClearESP()
    for _, v in ipairs(ESPFolder:GetChildren()) do
        v:Destroy()
    end
end

local function CreateESP(plr)
    if not IsAlive(plr) or not IsEnemy(plr) then return end
    local char = plr.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = plr.Name
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = ESPFolder

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = plr.Name
    nameLabel.TextColor3 = Config.ESPColor
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Config.ESPColor
    distLabel.TextStrokeTransparency = 0.5
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 12
    distLabel.Parent = billboard

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Box"
    box.Adornee = hrp
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Size = Vector3.new(4, 6, 2)
    box.Color3 = Config.ESPColor
    box.Transparency = 0.6
    box.Parent = ESPFolder

    Connections["ESP_" .. plr.Name] = RunService.RenderStepped:Connect(function()
        if not IsAlive(plr) or not Config.ESP then
            billboard:Destroy()
            box:Destroy()
            if Connections["ESP_" .. plr.Name] then
                Connections["ESP_" .. plr.Name]:Disconnect()
            end
            return
        end
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            local d = math.floor((hrp.Position - myRoot.Position).Magnitude)
            distLabel.Text = d .. "m"
        end
        box.Color3 = Config.ESPColor
        nameLabel.TextColor3 = Config.ESPColor
        distLabel.TextColor3 = Config.ESPColor
    end)
end

local function RefreshESP()
    ClearESP()
    if not Config.ESP then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr \~= LocalPlayer then
            CreateESP(plr)
        end
    end
end

--// Chams (Highlight for friends)
local function ClearChams()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            local h = plr.Character:FindFirstChild("s¡dzx̌12_Chams")
            if h then h:Destroy() end
        end
    end
end

local function ApplyChams()
    ClearChams()
    if not Config.Chams then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr \~= LocalPlayer and IsAlive(plr) and not IsEnemy(plr) then
            local highlight = Instance.new("Highlight")
            highlight.Name = "s¡dzx̌12_Chams"
            highlight.Adornee = plr.Character
            highlight.FillColor = Config.ChamsColor
            highlight.OutlineColor = Config.ChamsColor
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = plr.Character
        end
    end
end

--// Main loop
Connections.Main = RunService.RenderStepped:Connect(function()
    ApplyJumpRun()
    DoAimbot()
    DoAimFire()
    DoAimKill()
    DoAimSilent()
    DoAutoKill()
    UpdateFOVCircle()
end)

-- Character respawn handler
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Config.Fly then ToggleFly(true) end
    ApplyJumpRun()
    RefreshESP()
    ApplyChams()
end)

Players.PlayerAdded:Connect(function()
    task.wait(1)
    RefreshESP()
    ApplyChams()
end)

Players.PlayerRemoving:Connect(function(plr)
    local esp = ESPFolder:FindFirstChild(plr.Name)
    if esp then esp:Destroy() end
end)

--// ===================== UI =====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "s¡dzx̌12"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 520, 0, 380)
Main.Position = UDim2.new(0.5, -260, 0.5, -190)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui
Main.Active = true
Main.Draggable = true

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = Main

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(80, 40, 140)
UIStroke.Thickness = 1.5
UIStroke.Parent = Main

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 22, 40)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = TitleBar

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 12)
TitleFix.Position = UDim2.new(0, 0, 1, -12)
TitleFix.BackgroundColor3 = Color3.fromRGB(28, 22, 40)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "s¡dzx̌12"
Title.TextColor3 = Color3.fromRGB(200, 160, 255)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -38, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 60)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.Parent = TitleBar
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    for _, c in pairs(Connections) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    if FOVCircle then FOVCircle:Remove() end
    ClearESP()
    ClearChams()
    ToggleFly(false)
end)

-- Tabs
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(0, 130, 1, -42)
TabBar.Position = UDim2.new(0, 0, 0, 42)
TabBar.BackgroundColor3 = Color3.fromRGB(22, 20, 30)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -130, 1, -42)
Content.Position = UDim2.new(0, 130, 0, 42)
Content.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Content.BorderSizePixel = 0
Content.Parent = Main

local Tabs = {}
local CurrentTab = nil

local function CreateTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 0, 36)
    btn.Position = UDim2.new(0, 6, 0, 10 + (#Tabs * 42))
    btn.BackgroundColor3 = Color3.fromRGB(32, 28, 45)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(180, 170, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = TabBar
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -16, 1, -16)
    page.Position = UDim2.new(0, 8, 0, 8)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Color3.fromRGB(120, 80, 200)
    page.Visible = false
    page.CanvasSize = UDim2.new(0, 0, 0, 600)
    page.Parent = Content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = page

    table.insert(Tabs, {btn = btn, page = page, name = name})

    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(Tabs) do
            t.page.Visible = false
            t.btn.BackgroundColor3 = Color3.fromRGB(32, 28, 45)
            t.btn.TextColor3 = Color3.fromRGB(180, 170, 200)
        end
        page.Visible = true
        btn.BackgroundColor3 = Color3.fromRGB(80, 50, 140)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        CurrentTab = name
    end)

    return page
end

local function AddToggle(parent, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(28, 26, 38)
    frame.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 210, 240)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 44, 0, 22)
    toggle.Position = UDim2.new(1, -52, 0.5, -11)
    toggle.BackgroundColor3 = default and Color3.fromRGB(100, 60, 180) or Color3.fromRGB(50, 48, 60)
    toggle.Text = ""
    toggle.Parent = frame
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1, 0)
    tc.Parent = toggle

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 16, 0, 16)
    circle.Position = default and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.Parent = toggle
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(1, 0)
    cc.Parent = circle

    local state = default
    toggle.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(toggle, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(100, 60, 180) or Color3.fromRGB(50, 48, 60)
        }):Play()
        TweenService:Create(circle, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
        callback(state)
    end)
end

local function AddSlider(parent, text, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 56)
    frame.BackgroundColor3 = Color3.fromRGB(28, 26, 38)
    frame.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 22)
    label.Position = UDim2.new(0, 12, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. default
    label.TextColor3 = Color3.fromRGB(220, 210, 240)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 6)
    bar.Position = UDim2.new(0, 12, 0, 34)
    bar.BackgroundColor3 = Color3.fromRGB(40, 38, 55)
    bar.Parent = frame
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(120, 70, 200)
    fill.Parent = bar
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = fill

    local sliding = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max - min) * rel)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            label.Text = text .. ": " .. val
            callback(val)
        end
    end)
end

local function AddButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(70, 45, 130)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn
    btn.MouseButton1Click:Connect(callback)
end

local function AddTextBox(parent, placeholder, callback)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -8, 0, 34)
    box.BackgroundColor3 = Color3.fromRGB(28, 26, 38)
    box.PlaceholderText = placeholder
    box.Text = ""
    box.TextColor3 = Color3.fromRGB(220, 210, 240)
    box.PlaceholderColor3 = Color3.fromRGB(120, 110, 140)
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = box
    box.FocusLost:Connect(function(enter)
        if enter then callback(box.Text) end
    end)
end

-- Create tabs
local CombatPage = CreateTab("Combat")
local MovePage = CreateTab("Movement")
local VisualPage = CreateTab("Visuals")
local MiscPage = CreateTab("Misc")

-- Combat
AddToggle(CombatPage, "Aimbot (Chase Head)", false, function(v) Config.Aimbot = v end)
AddToggle(CombatPage, "AimFire (No Reload)", false, function(v) Config.AimFire = v end)
AddToggle(CombatPage, "AimKill (Auto Shoot FOV)", false, function(v) Config.AimKill = v end)
AddToggle(CombatPage, "AimSilent (Hold Shoot)", false, function(v) Config.AimSilent = v end)
AddToggle(CombatPage, "AutoKill (Everyone)", false, function(v) Config.AutoKill = v end)
AddSlider(CombatPage, "FOV", 20, 400, 120, function(v) Config.FOV = v end)
AddToggle(CombatPage, "Show FOV Circle", true, function(v) Config.FOVVisible = v end)
AddToggle(CombatPage, "Team Check", true, function(v) Config.TeamCheck = v end)

-- Movement
AddToggle(MovePage, "Fly", false, function(v) ToggleFly(v) end)
AddSlider(MovePage, "Fly Speed", 10, 200, 50, function(v) Config.FlySpeed = v end)
AddToggle(MovePage, "Jump", false, function(v) Config.Jump = v ApplyJumpRun() end)
AddSlider(MovePage, "Jump Power", 1, 9999, 50, function(v) Config.JumpPower = v ApplyJumpRun() end)
AddToggle(MovePage, "Run", false, function(v) Config.Run = v ApplyJumpRun() end)
AddSlider(MovePage, "Run Speed", 1, 9999, 16, function(v) Config.RunSpeed = v ApplyJumpRun() end)

-- Visuals
AddToggle(VisualPage, "ESP (Enemies)", false, function(v) Config.ESP = v RefreshESP() end)
AddToggle(VisualPage, "Chams (Friends)", false, function(v) Config.Chams = v ApplyChams() end)

-- color pickers simplified as buttons for common colors
local function AddColorRow(parent, label, isESP)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 36)
    frame.BackgroundColor3 = Color3.fromRGB(28, 26, 38)
    frame.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(220, 210, 240)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local colors = {
        {Color3.fromRGB(255, 50, 50), "R"},
        {Color3.fromRGB(50, 255, 100), "G"},
        {Color3.fromRGB(50, 150, 255), "B"},
        {Color3.fromRGB(255, 220, 50), "Y"},
        {Color3.fromRGB(200, 100, 255), "P"},
    }
    for i, col in ipairs(colors) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 28, 0, 22)
        b.Position = UDim2.new(0, 140 + (i-1)*34, 0.5, -11)
        b.BackgroundColor3 = col[1]
        b.Text = ""
        b.Parent = frame
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 6)
        bc.Parent = b
        b.MouseButton1Click:Connect(function()
            if isESP then
                Config.ESPColor = col[1]
                RefreshESP()
            else
                Config.ChamsColor = col[1]
                ApplyChams()
            end
        end)
    end
end

AddColorRow(VisualPage, "ESP Color", true)
AddColorRow(VisualPage, "Chams Color", false)

-- Misc
AddTextBox(MiscPage, "Teleport: Username or x,y,z", function(txt)
    TeleportTo(txt)
end)
AddButton(MiscPage, "Teleport to Mouse", function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hit = Mouse.Hit
        if hit then
            char.HumanoidRootPart.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0))
        end
    end
end)

-- open first tab
Tabs[1].btn.BackgroundColor3 = Color3.fromRGB(80, 50, 140)
Tabs[1].btn.TextColor3 = Color3.fromRGB(255, 255, 255)
Tabs[1].page.Visible = true

-- keybind to toggle ui
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end)

print("[s¡dzx̌12] loaded | RightShift = toggle UI")
