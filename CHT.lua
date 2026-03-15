--[[
╔═══════════════════════════════════════════════════════════════╗
║                  AIO MENU  v4  —  ULTRA EDITION               ║
║                                                               ║
║  ESP       │ Caixa • Vida • Nick • Distância • Tracer        ║
║  AIMBOT    │ FOV • WallCheck • TeamCheck • Smoothness        ║
║  SILENT    │ Silent Aim (desvio de projétil)                 ║
║  TRIGGER   │ Triggerbot com delay configurável               ║
║  MISC      │ Speed • BunnyHop • Noclip • Infinite Jump       ║
║  KEYBINDS  │ Tecla configurável para tudo                    ║
╚═══════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════════════════
--  SERVIÇOS
-- ═══════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse  = LP:GetMouse()

-- ═══════════════════════════════════════════════════
--  CONFIGURAÇÃO GLOBAL
-- ═══════════════════════════════════════════════════
local C = {
    -- ESP
    ESP           = false,
    ESP_Box       = true,
    ESP_Health    = true,
    ESP_Name      = true,
    ESP_Distance  = true,
    ESP_Tracer    = false,
    ESP_BoxColor  = Color3.fromRGB(255, 55, 55),
    ESP_MaxDist   = 1000,

    -- Aimbot
    Aimbot        = false,
    Aim_Smooth    = 10,      -- 1 = instantâneo, 100 = muito suave
    Aim_FOVRadius = 120,
    Aim_FOVShow   = true,
    Aim_TeamCheck = true,
    Aim_HitPart   = "Head",  -- "Head" ou "HumanoidRootPart"

    -- Silent Aim
    Silent        = false,
    Silent_Team   = true,

    -- Triggerbot
    Trigger       = false,
    Trigger_Delay = 80,      -- ms
    Trigger_Team  = true,

    -- Misc
    Speed         = false,
    WalkSpeed     = 60,
    BHop          = false,
    Noclip        = false,
    InfJump       = false,

    -- Keybinds
    KB_Menu       = Enum.KeyCode.Insert,
    KB_ESP        = Enum.KeyCode.T,
    KB_Aimbot     = Enum.KeyCode.G,
    KB_Silent     = Enum.KeyCode.H,
    KB_Trigger    = Enum.KeyCode.J,
    KB_Speed      = Enum.KeyCode.Y,
    KB_Noclip     = Enum.KeyCode.N,
    KB_InfJump    = Enum.KeyCode.B,
    KB_BHop       = Enum.KeyCode.V,
}

-- ═══════════════════════════════════════════════════
--  DRAWING FACTORY
-- ═══════════════════════════════════════════════════
local function D_Quad(col, filled, thick)
    local q = Drawing.new("Quad")
    q.Color = col; q.Filled = filled
    q.Thickness = thick or 1.5
    q.Transparency = 1; q.Visible = false
    return q
end
local function D_Line(col, thick)
    local l = Drawing.new("Line")
    l.Color = col; l.Thickness = thick or 1
    l.Transparency = 1; l.Visible = false
    return l
end
local function D_Text(col, sz)
    local t = Drawing.new("Text")
    t.Color = col; t.Size = sz or 12
    t.Font = Drawing.Fonts.UI
    t.Outline = true
    t.OutlineColor = Color3.new(0,0,0)
    t.Visible = false
    return t
end
local function D_Circle()
    local c = Drawing.new("Circle")
    c.Color = Color3.fromRGB(255,60,60)
    c.Filled = false; c.Thickness = 1.5
    c.Transparency = 1; c.Visible = false
    return c
end

-- ═══════════════════════════════════════════════════
--  ESP DATA
-- ═══════════════════════════════════════════════════
local ESPData = {}   -- [player] = { drawings... }

local function ESP_Create(plr)
    if ESPData[plr] then return end
    ESPData[plr] = {
        shadow   = D_Quad(Color3.new(0,0,0),           false, 3),
        box      = D_Quad(C.ESP_BoxColor,              false, 1.5),
        hpBg     = D_Quad(Color3.fromRGB(10,10,10),    true,  1),
        hpFill   = D_Quad(Color3.fromRGB(60,220,80),   true,  1),
        name     = D_Text(Color3.new(1,1,1),           13),
        dist     = D_Text(Color3.fromRGB(200,200,255), 11),
        tracer   = D_Line(C.ESP_BoxColor,              1),
    }
end

local function ESP_Remove(plr)
    if not ESPData[plr] then return end
    for _, d in pairs(ESPData[plr]) do pcall(function() d:Remove() end) end
    ESPData[plr] = nil
end

local function ESP_Hide(plr)
    if not ESPData[plr] then return end
    for _, d in pairs(ESPData[plr]) do pcall(function() d.Visible = false end) end
end

-- ═══════════════════════════════════════════════════
--  BOUNDING BOX
-- ═══════════════════════════════════════════════════
local function GetBox(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local p = hrp.Position
    local H, W = 3.1, 1.35
    local corners = {
        Vector3.new( W,  H,  W), Vector3.new(-W,  H,  W),
        Vector3.new( W,  H, -W), Vector3.new(-W,  H, -W),
        Vector3.new( W, -H,  W), Vector3.new(-W, -H,  W),
        Vector3.new( W, -H, -W), Vector3.new(-W, -H, -W),
    }
    local minX, minY =  1e9,  1e9
    local maxX, maxY = -1e9, -1e9
    for _, off in ipairs(corners) do
        local sp = Camera:WorldToViewportPoint(p + off)
        if sp.Z <= 0 then return nil end
        minX = math.min(minX, sp.X); minY = math.min(minY, sp.Y)
        maxX = math.max(maxX, sp.X); maxY = math.max(maxY, sp.Y)
    end
    local vp = Camera.ViewportSize
    if maxX < 0 or minX > vp.X or maxY < 0 or minY > vp.Y then return nil end
    return Vector2.new(minX,minY), Vector2.new(maxX,minY),
           Vector2.new(minX,maxY), Vector2.new(maxX,maxY)
end

-- ═══════════════════════════════════════════════════
--  WALLCHECK  (true = visível/livre)
-- ═══════════════════════════════════════════════════
local function WallCheck(targetPos)
    local myChar = LP.Character
    local origin = Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excl = {Camera}
    if myChar then table.insert(excl, myChar) end
    params.FilterDescendantsInstances = excl
    local res = Workspace:Raycast(origin, targetPos - origin, params)
    if not res then return true end
    local model = res.Instance:FindFirstAncestorOfClass("Model")
    if model then
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character == model then return true end
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════
--  BUSCAR MELHOR ALVO
-- ═══════════════════════════════════════════════════
local sc = Vector2.new(0, 0)

local function GetTarget(maxDist, wallcheck, teamcheck)
    local myTeam  = LP.Team
    local best    = nil
    local bestD   = maxDist + 1
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if teamcheck and plr.Team == myTeam then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if not onScreen or sp.Z <= 0 then continue end
        local d2 = (Vector2.new(sp.X, sp.Y) - sc).Magnitude
        if d2 > maxDist then continue end
        if wallcheck and not WallCheck(hrp.Position) then continue end
        if d2 < bestD then bestD = d2; best = plr end
    end
    return best
end

-- ═══════════════════════════════════════════════════
--  FOV CIRCLE
-- ═══════════════════════════════════════════════════
local FovCircle = D_Circle()

-- ═══════════════════════════════════════════════════
--  MISC — SPEED / BHOP / NOCLIP / INFJUMP
-- ═══════════════════════════════════════════════════
local SpeedConn  = nil
local NoclipConn = nil
local JumpConn   = nil
local BHopConn   = nil

local function SetSpeed(on)
    if SpeedConn then SpeedConn:Disconnect(); SpeedConn = nil end
    if not on then
        local c = LP.Character
        if c then local h = c:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = 16 end end
        return
    end
    SpeedConn = RunService.Heartbeat:Connect(function()
        local c = LP.Character
        if c then local h = c:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = C.WalkSpeed end end
    end)
end

local function SetNoclip(on)
    if NoclipConn then NoclipConn:Disconnect(); NoclipConn = nil end
    if not on then return end
    NoclipConn = RunService.Stepped:Connect(function()
        local c = LP.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end)
end

local function SetInfJump(on)
    if JumpConn then JumpConn:Disconnect(); JumpConn = nil end
    if not on then return end
    JumpConn = UserInputService.JumpRequest:Connect(function()
        local c = LP.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
end

local function SetBHop(on)
    if BHopConn then BHopConn:Disconnect(); BHopConn = nil end
    if not on then return end
    BHopConn = RunService.Heartbeat:Connect(function()
        local c = LP.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if h and hrp then
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                if h:GetState() == Enum.HumanoidStateType.Landed then
                    h:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════
--  TRIGGERBOT
-- ═══════════════════════════════════════════════════
local TriggerActive = false
local TriggerLast   = 0

local function TriggerCheck()
    if not C.Trigger then return end
    local myChar = LP.Character
    if not myChar then return end
    local cam = Camera.CFrame
    local unitRay = cam.LookVector
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {myChar, Camera}
    local res = Workspace:Raycast(cam.Position, unitRay * 1000, params)
    if not res then return end
    local model = res.Instance:FindFirstAncestorOfClass("Model")
    if not model then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        if C.Trigger_Team and plr.Team == LP.Team then continue end
        if plr.Character == model then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local now = tick() * 1000
                if now - TriggerLast >= C.Trigger_Delay then
                    TriggerLast = now
                    -- simular click
                    mouse1press()
                    task.delay(0.05, mouse1release)
                end
            end
            break
        end
    end
end

-- ═══════════════════════════════════════════════════
--  SILENT AIM
-- ═══════════════════════════════════════════════════
-- Hookeia o método FireServer para desviar a posição do projétil
local SilentHook = nil

local function EnableSilent(on)
    if not on then
        if SilentHook then
            -- restaurar original (executores suportam hookear via getrawmetatable)
            pcall(function()
                local mt = getrawmetatable(game)
                setreadonly(mt, false)
                mt.__index = SilentHook
                setreadonly(mt, true)
            end)
            SilentHook = nil
        end
        return
    end

    -- Método via FireServer hook (compatível com jogos que usam RemoteEvents para atirar)
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local orig = mt.__namecall
        SilentHook = orig
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if (method == "FireServer" or method == "InvokeServer") and C.Silent then
                local args = {...}
                local target = GetTarget(C.Aim_FOVRadius, true, C.Silent_Team)
                if target and target.Character then
                    local hitPart = target.Character:FindFirstChild(C.Aim_HitPart)
                    if hitPart then
                        for i, v in ipairs(args) do
                            if typeof(v) == "Vector3" then
                                args[i] = hitPart.Position
                            elseif typeof(v) == "Instance" and v:IsA("BasePart") then
                                args[i] = hitPart
                            end
                        end
                    end
                end
                return orig(self, table.unpack(args))
            end
            return orig(self, ...)
        end)
        setreadonly(mt, true)
    end)
end

-- ═══════════════════════════════════════════════════
--  RENDER LOOP PRINCIPAL
-- ═══════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    sc = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)

    -- FOV Circle
    FovCircle.Position = sc
    FovCircle.Radius   = C.Aim_FOVRadius
    FovCircle.Visible  = C.Aimbot and C.Aim_FOVShow

    local myTeam = LP.Team

    -- Melhor alvo para aimbot
    local aimbotTarget = nil
    local aimbotBestD  = C.Aim_FOVRadius + 1

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end

        local char = plr.Character
        local alive = false
        local hum   = nil

        if char then
            hum   = char:FindFirstChildOfClass("Humanoid")
            alive = hum ~= nil and hum.Health > 0
        end

        -- ── ESP ──────────────────────────────────
        if C.ESP then
            if not alive then
                ESP_Hide(plr)
            else
                ESP_Create(plr)
                local esp = ESPData[plr]
                local hrp = char:FindFirstChild("HumanoidRootPart")

                -- verificar distância máxima
                local dist3D = hrp and (Camera.CFrame.Position - hrp.Position).Magnitude or 9999
                if dist3D > C.ESP_MaxDist then
                    ESP_Hide(plr)
                else
                    local tl, tr, bl, br = GetBox(char)
                    if tl then
                        -- Caixa (shadow + principal)
                        if C.ESP_Box then
                            local off = Vector2.new(1,1)
                            esp.shadow.PointA=tl+off; esp.shadow.PointB=tr+off
                            esp.shadow.PointC=br+off; esp.shadow.PointD=bl+off
                            esp.shadow.Visible = true

                            esp.box.Color  = C.ESP_BoxColor
                            esp.box.PointA=tl; esp.box.PointB=tr
                            esp.box.PointC=br; esp.box.PointD=bl
                            esp.box.Visible = true
                        else
                            esp.shadow.Visible = false
                            esp.box.Visible    = false
                        end

                        -- Barra de vida
                        if C.ESP_Health then
                            local bW   = 4
                            local bX   = tl.X - bW - 3
                            local bH   = bl.Y - tl.Y
                            local pct  = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                            local top  = bl.Y - bH * pct
                            local hpColor
                            if pct > 0.6 then
                                hpColor = Color3.fromRGB(50, 220, 70)
                            elseif pct > 0.3 then
                                hpColor = Color3.fromRGB(230, 195, 40)
                            else
                                hpColor = Color3.fromRGB(230, 50, 50)
                            end
                            esp.hpBg.PointA=Vector2.new(bX,tl.Y); esp.hpBg.PointB=Vector2.new(bX+bW,tl.Y)
                            esp.hpBg.PointC=Vector2.new(bX+bW,bl.Y); esp.hpBg.PointD=Vector2.new(bX,bl.Y)
                            esp.hpBg.Visible = true
                            esp.hpFill.Color=hpColor
                            esp.hpFill.PointA=Vector2.new(bX,top);   esp.hpFill.PointB=Vector2.new(bX+bW,top)
                            esp.hpFill.PointC=Vector2.new(bX+bW,bl.Y); esp.hpFill.PointD=Vector2.new(bX,bl.Y)
                            esp.hpFill.Visible = true
                        else
                            esp.hpBg.Visible = false; esp.hpFill.Visible = false
                        end

                        -- Nome
                        local cx = (tl.X + tr.X) * 0.5
                        if C.ESP_Name then
                            local tag = plr.DisplayName
                            if C.ESP_Distance then
                                tag = tag .. "  [" .. math.floor(dist3D) .. "m]"
                            end
                            esp.name.Text     = tag
                            esp.name.Position = Vector2.new(cx, tl.Y - 16)
                            esp.name.Center   = true
                            esp.name.Visible  = true
                        else
                            esp.name.Visible = false
                        end
                        esp.dist.Visible = false -- já embutido no nome

                        -- Tracer (linha do centro da tela para os pés)
                        if C.ESP_Tracer then
                            esp.tracer.Color = C.ESP_BoxColor
                            esp.tracer.From  = Vector2.new(sc.X, Camera.ViewportSize.Y)
                            esp.tracer.To    = Vector2.new(cx, bl.Y)
                            esp.tracer.Visible = true
                        else
                            esp.tracer.Visible = false
                        end
                    else
                        ESP_Hide(plr)
                    end
                end
            end
        else
            ESP_Hide(plr)
        end

        -- ── Aimbot target search ──────────────────
        if C.Aimbot and alive then
            if C.Aim_TeamCheck and plr.Team == myTeam then continue end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if not onScreen or sp.Z <= 0 then continue end
            local d2 = (Vector2.new(sp.X, sp.Y) - sc).Magnitude
            if d2 > C.Aim_FOVRadius then continue end
            if not WallCheck(hrp.Position) then continue end
            if d2 < aimbotBestD then aimbotBestD = d2; aimbotTarget = plr end
        end
    end

    -- Aplicar Aimbot com suavização
    if C.Aimbot and aimbotTarget then
        local char = aimbotTarget.Character
        if char then
            local part = char:FindFirstChild(C.Aim_HitPart) or char:FindFirstChild("HumanoidRootPart")
            if part then
                local smooth = math.clamp(C.Aim_Smooth, 1, 100) / 100
                local targetCF = CFrame.new(Camera.CFrame.Position, part.Position)
                Camera.CFrame  = Camera.CFrame:Lerp(targetCF, 1 - smooth + 0.01)
            end
        end
    end

    -- Triggerbot
    TriggerCheck()
end)

-- Cleanup ESP
Players.PlayerRemoving:Connect(ESP_Remove)
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function() ESP_Hide(plr) end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LP then
        plr.CharacterAdded:Connect(function() ESP_Hide(plr) end)
    end
end

-- ═══════════════════════════════════════════════════════════════
--  ██████╗ ██╗   ██╗██╗
--  ██╔════╝ ██║   ██║██║
--  ██║  ███╗██║   ██║██║
--  ██║   ██║██║   ██║██║
--  ╚██████╔╝╚██████╔╝██║
-- ═══════════════════════════════════════════════════════════════
local ok, CoreGui = pcall(function() return game:GetService("CoreGui") end)
local GuiParent   = ok and CoreGui or LP:WaitForChild("PlayerGui")

local Screen = Instance.new("ScreenGui")
Screen.Name           = "AIO_v4"
Screen.ResetOnSpawn   = false
Screen.ZIndexBehavior = Enum.ZIndexBehavior.Global
Screen.IgnoreGuiInset = true
Screen.Parent         = GuiParent

-- ── Janela principal ───────────────────────────────
local Win = Instance.new("Frame", Screen)
Win.Name             = "Win"
Win.Size             = UDim2.fromOffset(310, 0)
Win.Position         = UDim2.fromOffset(80, 80)
Win.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
Win.BorderSizePixel  = 0
Win.AutomaticSize    = Enum.AutomaticSize.Y
Win.ClipsDescendants = false

Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 10)

local WinStroke = Instance.new("UIStroke", Win)
WinStroke.Color     = Color3.fromRGB(180, 30, 30)
WinStroke.Thickness = 1.5

-- ── Gradiente no topo da janela ────────────────────
local topGrad = Instance.new("Frame", Win)
topGrad.Size            = UDim2.new(1, 0, 0, 3)
topGrad.BackgroundColor3 = Color3.fromRGB(230, 40, 40)
topGrad.BorderSizePixel = 0
topGrad.ZIndex          = 10

local tgCorner = Instance.new("UICorner", topGrad)
tgCorner.CornerRadius = UDim.new(0, 10)

local tgFix = Instance.new("Frame", topGrad)
tgFix.Size            = UDim2.new(1,0,0.5,0)
tgFix.Position        = UDim2.new(0,0,0.5,0)
tgFix.BackgroundColor3 = Color3.fromRGB(230,40,40)
tgFix.BorderSizePixel = 0

-- ── Título ─────────────────────────────────────────
local TitleBar = Instance.new("Frame", Win)
TitleBar.Size            = UDim2.new(1, 0, 0, 42)
TitleBar.Position        = UDim2.fromOffset(0, 3)
TitleBar.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex          = 5

local TitleLbl = Instance.new("TextLabel", TitleBar)
TitleLbl.Text           = "  ◈  AIO MENU  v4"
TitleLbl.Size           = UDim2.new(1, -70, 1, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextColor3     = Color3.fromRGB(235, 235, 245)
TitleLbl.TextSize       = 14
TitleLbl.Font           = Enum.Font.GothamBold
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.ZIndex         = 6

-- subtítulo animado
local SubLbl = Instance.new("TextLabel", TitleBar)
SubLbl.Text           = "ULTRA EDITION"
SubLbl.Size           = UDim2.new(1, -70, 0, 12)
SubLbl.Position       = UDim2.new(0, 20, 1, -13)
SubLbl.BackgroundTransparency = 1
SubLbl.TextColor3     = Color3.fromRGB(200, 40, 40)
SubLbl.TextSize       = 9
SubLbl.Font           = Enum.Font.GothamBold
SubLbl.TextXAlignment = Enum.TextXAlignment.Left
SubLbl.ZIndex         = 6

local function TopBtn(lbl, ox, col)
    local b = Instance.new("TextButton", TitleBar)
    b.Size            = UDim2.fromOffset(22, 22)
    b.Position        = UDim2.new(1, ox, 0.5, -11)
    b.BackgroundColor3 = col
    b.Text            = lbl
    b.TextColor3      = Color3.new(1,1,1)
    b.TextSize        = 11
    b.Font            = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.ZIndex          = 7
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local MinBtn   = TopBtn("─", -50, Color3.fromRGB(45,45,60))
local CloseBtn = TopBtn("✕", -24, Color3.fromRGB(155,28,28))

-- arrastar janela
do
    local drag, ds, dp
    TitleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag=true; ds=i.Position; dp=Win.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            Win.Position = UDim2.new(dp.X.Scale, dp.X.Offset+d.X, dp.Y.Scale, dp.Y.Offset+d.Y)
        end
    end)
end

-- ── Status bar (mostra o que está ativo) ────────────
local StatusBar = Instance.new("Frame", Win)
StatusBar.Size            = UDim2.new(1, 0, 0, 22)
StatusBar.Position        = UDim2.fromOffset(0, 45)
StatusBar.BackgroundColor3 = Color3.fromRGB(18, 5, 5)
StatusBar.BorderSizePixel = 0

local StatusLbl = Instance.new("TextLabel", StatusBar)
StatusLbl.Size            = UDim2.new(1, -8, 1, 0)
StatusLbl.Position        = UDim2.fromOffset(8, 0)
StatusLbl.BackgroundTransparency = 1
StatusLbl.TextColor3      = Color3.fromRGB(180, 180, 190)
StatusLbl.TextSize        = 10
StatusLbl.Font            = Enum.Font.Gotham
StatusLbl.TextXAlignment  = Enum.TextXAlignment.Left

local function UpdateStatus()
    local parts = {}
    if C.ESP     then table.insert(parts, "◉ ESP") end
    if C.Aimbot  then table.insert(parts, "◉ AIM") end
    if C.Silent  then table.insert(parts, "◉ SILENT") end
    if C.Trigger then table.insert(parts, "◉ TRIGGER") end
    if C.Speed   then table.insert(parts, "◉ SPEED") end
    if C.Noclip  then table.insert(parts, "◉ NOCLIP") end
    if C.InfJump then table.insert(parts, "◉ INF JUMP") end
    if C.BHop    then table.insert(parts, "◉ BHOP") end
    if #parts == 0 then
        StatusLbl.Text      = "  Nenhuma opção ativa"
        StatusLbl.TextColor3 = Color3.fromRGB(100,100,115)
    else
        StatusLbl.Text      = "  " .. table.concat(parts, "   ")
        StatusLbl.TextColor3 = Color3.fromRGB(220, 80, 80)
    end
end
UpdateStatus()

-- ── TabBar ─────────────────────────────────────────
local TabBar = Instance.new("Frame", Win)
TabBar.Size            = UDim2.new(1, 0, 0, 32)
TabBar.Position        = UDim2.fromOffset(0, 67)
TabBar.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
TabBar.BorderSizePixel = 0

-- linha separadora abaixo do tabbar
local tabLine = Instance.new("Frame", TabBar)
tabLine.Size            = UDim2.new(1, 0, 0, 1)
tabLine.Position        = UDim2.new(0, 0, 1, -1)
tabLine.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
tabLine.BorderSizePixel = 0

local TabLayout = Instance.new("UIListLayout", TabBar)
TabLayout.FillDirection       = Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
TabLayout.Padding             = UDim.new(0, 2)

-- ── PageHolder ─────────────────────────────────────
local PageHolder = Instance.new("Frame", Win)
PageHolder.Name             = "PageHolder"
PageHolder.Size             = UDim2.new(1, 0, 0, 0)
PageHolder.Position         = UDim2.fromOffset(0, 99)
PageHolder.AutomaticSize    = Enum.AutomaticSize.Y
PageHolder.BackgroundTransparency = 1
PageHolder.BorderSizePixel  = 0

local Pages   = {}
local TabBtns = {}
local CurTab  = nil

local function NewTab(name, icon)
    local btn = Instance.new("TextButton", TabBar)
    btn.Size            = UDim2.fromOffset(54, 26)
    btn.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    btn.Text            = icon .. "\n" .. name
    btn.TextColor3      = Color3.fromRGB(140, 140, 158)
    btn.TextSize        = 9
    btn.Font            = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.LineHeight      = 1.1
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    -- indicador inferior ativo
    local ind = Instance.new("Frame", btn)
    ind.Size            = UDim2.new(0.7, 0, 0, 2)
    ind.Position        = UDim2.new(0.15, 0, 1, -2)
    ind.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
    ind.BorderSizePixel = 0
    ind.Visible         = false
    Instance.new("UICorner", ind).CornerRadius = UDim.new(0, 1)

    local page = Instance.new("Frame", PageHolder)
    page.Name            = name
    page.Size            = UDim2.new(1, 0, 0, 0)
    page.AutomaticSize   = Enum.AutomaticSize.Y
    page.BackgroundTransparency = 1
    page.Visible         = false
    page.BorderSizePixel = 0

    local ll = Instance.new("UIListLayout", page)
    ll.Padding   = UDim.new(0, 4)
    ll.SortOrder = Enum.SortOrder.LayoutOrder

    local pp = Instance.new("UIPadding", page)
    pp.PaddingLeft   = UDim.new(0, 8)
    pp.PaddingRight  = UDim.new(0, 8)
    pp.PaddingTop    = UDim.new(0, 6)
    pp.PaddingBottom = UDim.new(0, 8)

    Pages[name]   = page
    TabBtns[name] = { btn=btn, ind=ind }

    btn.MouseButton1Click:Connect(function()
        if CurTab then
            Pages[CurTab].Visible            = false
            TabBtns[CurTab].btn.TextColor3   = Color3.fromRGB(140,140,158)
            TabBtns[CurTab].ind.Visible      = false
        end
        CurTab            = name
        page.Visible      = true
        btn.TextColor3    = Color3.fromRGB(235,235,245)
        ind.Visible       = true
    end)
    return page
end

local PgESP   = NewTab("ESP",     "👁")
local PgAim   = NewTab("Aimbot",  "🎯")
local PgSil   = NewTab("Silent",  "🔇")
local PgMisc  = NewTab("Misc",    "⚙")
local PgKeys  = NewTab("Teclas",  "⌨")

-- ativa ESP por padrão
TabBtns["ESP"].btn.TextColor3  = Color3.fromRGB(235,235,245)
TabBtns["ESP"].ind.Visible     = true
Pages["ESP"].Visible           = true
CurTab = "ESP"

-- ═══════════════════════════════════════════════════
--  COMPONENTES DE UI
-- ═══════════════════════════════════════════════════
local SyncToggle = {}  -- [nome] = função set (para sincronizar com keybind)

local function Section(parent, text, order)
    local wrap = Instance.new("Frame", parent)
    wrap.Size            = UDim2.new(1, 0, 0, 20)
    wrap.BackgroundTransparency = 1
    wrap.LayoutOrder     = order

    local line = Instance.new("Frame", wrap)
    line.Size            = UDim2.new(1, -80, 0, 1)
    line.Position        = UDim2.new(0, 0, 0.5, 0)
    line.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    line.BorderSizePixel = 0

    local lbl = Instance.new("TextLabel", wrap)
    lbl.Text        = text
    lbl.Size        = UDim2.new(0, 80, 1, 0)
    lbl.Position    = UDim2.new(1, -82, 0, 0)
    lbl.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    lbl.TextColor3  = Color3.fromRGB(180, 35, 35)
    lbl.TextSize    = 10
    lbl.Font        = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Right
    lbl.BorderSizePixel = 0
end

local function Toggle(parent, lbl, order, init, cb)
    local row = Instance.new("Frame", parent)
    row.Size            = UDim2.new(1, 0, 0, 30)
    row.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    row.BorderSizePixel = 0
    row.LayoutOrder     = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel", row)
    label.Text        = lbl
    label.Size        = UDim2.new(1, -52, 1, 0)
    label.Position    = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.TextColor3  = Color3.fromRGB(205, 205, 215)
    label.TextSize    = 11
    label.Font        = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", row)
    track.Size            = UDim2.fromOffset(34, 16)
    track.Position        = UDim2.new(1, -42, 0.5, -8)
    track.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 8)

    local thumb = Instance.new("Frame", track)
    thumb.Size            = UDim2.fromOffset(12, 12)
    thumb.Position        = UDim2.new(0, 2, 0.5, -6)
    thumb.BackgroundColor3 = Color3.fromRGB(100, 100, 118)
    thumb.BorderSizePixel = 0
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 6)

    local on = init or false
    local function Set(val, silent)
        on = val
        if on then
            track.BackgroundColor3 = Color3.fromRGB(190, 30, 30)
            thumb.BackgroundColor3 = Color3.new(1, 1, 1)
            thumb:TweenPosition(UDim2.new(0,18,0.5,-6),"Out","Quad",0.11,true)
        else
            track.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
            thumb.BackgroundColor3 = Color3.fromRGB(100, 100, 118)
            thumb:TweenPosition(UDim2.new(0,2,0.5,-6),"Out","Quad",0.11,true)
        end
        if not silent and cb then cb(on) end
    end
    local click = Instance.new("TextButton", row)
    click.Size            = UDim2.new(1,0,1,0)
    click.BackgroundTransparency = 1
    click.Text            = ""
    click.MouseButton1Click:Connect(function() Set(not on) end)
    Set(on, true)
    return Set
end

local function Slider(parent, lbl, order, minV, maxV, def, fmt, cb)
    local cont = Instance.new("Frame", parent)
    cont.Size            = UDim2.new(1, 0, 0, 46)
    cont.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    cont.BorderSizePixel = 0
    cont.LayoutOrder     = order
    Instance.new("UICorner", cont).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel", cont)
    label.Text        = lbl
    label.Size        = UDim2.new(0.62, 0, 0, 17)
    label.Position    = UDim2.fromOffset(9, 4)
    label.BackgroundTransparency = 1
    label.TextColor3  = Color3.fromRGB(205, 205, 215)
    label.TextSize    = 11
    label.Font        = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", cont)
    valLbl.Size        = UDim2.new(0.38, -9, 0, 17)
    valLbl.Position    = UDim2.new(0.62, 0, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.TextColor3  = Color3.fromRGB(200, 40, 40)
    valLbl.TextSize    = 11
    valLbl.Font        = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", cont)
    track.Size            = UDim2.new(1, -18, 0, 4)
    track.Position        = UDim2.new(0, 9, 0, 33)
    track.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 2)

    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = Color3.fromRGB(190, 32, 32)
    fill.BorderSizePixel  = 0
    fill.Size             = UDim2.new(0, 0, 1, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)

    local knob = Instance.new("Frame", fill)
    knob.Size            = UDim2.fromOffset(11, 11)
    knob.Position        = UDim2.new(1, -5, 0.5, -5)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 3
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 6)

    local cur = def
    local function SetVal(v, silent)
        v = math.clamp(math.floor(v + 0.5), minV, maxV)
        cur = v
        fill.Size   = UDim2.new((v-minV)/(maxV-minV), 0, 1, 0)
        valLbl.Text = string.format(fmt or "%g", v)
        if not silent and cb then cb(v) end
    end
    SetVal(def, true)

    local dragging = false
    local hb = Instance.new("TextButton", cont)
    hb.Size            = UDim2.new(1,0,0,18)
    hb.Position        = UDim2.new(0,0,0,26)
    hb.BackgroundTransparency = 1; hb.Text = ""; hb.ZIndex = 5
    hb.MouseButton1Down:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    RunService.RenderStepped:Connect(function()
        if not dragging then return end
        local mx = UserInputService:GetMouseLocation().X
        local tx = track.AbsolutePosition.X
        local tw = track.AbsoluteSize.X
        SetVal(minV + math.clamp((mx-tx)/tw, 0, 1)*(maxV-minV))
    end)
    return SetVal
end

local function Dropdown(parent, lbl, order, opts, def, cb)
    local cont = Instance.new("Frame", parent)
    cont.Size            = UDim2.new(1, 0, 0, 30)
    cont.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    cont.BorderSizePixel = 0
    cont.LayoutOrder     = order
    cont.ClipsDescendants = false
    Instance.new("UICorner", cont).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel", cont)
    label.Text        = lbl
    label.Size        = UDim2.new(0.55, 0, 1, 0)
    label.Position    = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.TextColor3  = Color3.fromRGB(205, 205, 215)
    label.TextSize    = 11
    label.Font        = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left

    local selBtn = Instance.new("TextButton", cont)
    selBtn.Size            = UDim2.new(0.43, 0, 0, 22)
    selBtn.Position        = UDim2.new(0.56, 0, 0.5, -11)
    selBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    selBtn.Text            = def .. "  ▾"
    selBtn.TextColor3      = Color3.fromRGB(200, 40, 40)
    selBtn.TextSize        = 10
    selBtn.Font            = Enum.Font.GothamBold
    selBtn.BorderSizePixel = 0
    Instance.new("UICorner", selBtn).CornerRadius = UDim.new(0, 5)

    local dropdown = Instance.new("Frame", cont)
    dropdown.Size            = UDim2.new(0.43, 0, 0, #opts * 22)
    dropdown.Position        = UDim2.new(0.56, 0, 1, 2)
    dropdown.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    dropdown.BorderSizePixel = 0
    dropdown.Visible         = false
    dropdown.ZIndex          = 20
    Instance.new("UICorner", dropdown).CornerRadius = UDim.new(0, 5)
    Instance.new("UIStroke", dropdown).Color = Color3.fromRGB(55,55,75)

    local ddLayout = Instance.new("UIListLayout", dropdown)
    ddLayout.SortOrder = Enum.SortOrder.LayoutOrder

    for i, opt in ipairs(opts) do
        local ob = Instance.new("TextButton", dropdown)
        ob.Size            = UDim2.new(1, 0, 0, 22)
        ob.BackgroundTransparency = 1
        ob.Text            = opt
        ob.TextColor3      = Color3.fromRGB(200, 200, 210)
        ob.TextSize        = 10
        ob.Font            = Enum.Font.Gotham
        ob.BorderSizePixel = 0
        ob.ZIndex          = 21
        ob.LayoutOrder     = i
        ob.MouseButton1Click:Connect(function()
            selBtn.Text     = opt .. "  ▾"
            dropdown.Visible = false
            if cb then cb(opt) end
        end)
        ob.MouseEnter:Connect(function() ob.TextColor3 = Color3.fromRGB(230,60,60) end)
        ob.MouseLeave:Connect(function() ob.TextColor3 = Color3.fromRGB(200,200,210) end)
    end

    local open = false
    selBtn.MouseButton1Click:Connect(function()
        open = not open
        dropdown.Visible = open
    end)

    return selBtn
end

-- ═══════════════════════════════════════════════════
--  ABA ESP
-- ═══════════════════════════════════════════════════
Section(PgESP, "VISUAL", 1)

SyncToggle["ESP"] = Toggle(PgESP, "ESP  (Caixa + Vida + Nick)", 2, false, function(on)
    C.ESP = on; UpdateStatus()
    if not on then for _, p in ipairs(Players:GetPlayers()) do ESP_Hide(p) end end
end)
Toggle(PgESP, "Caixa", 3, true, function(on) C.ESP_Box = on end)
Toggle(PgESP, "Barra de Vida", 4, true, function(on) C.ESP_Health = on end)
Toggle(PgESP, "Nome + Distância", 5, true, function(on) C.ESP_Name = on end)
Toggle(PgESP, "Tracer  (linha dos pés)", 6, false, function(on) C.ESP_Tracer = on end)

Section(PgESP, "CONFIG", 7)
Slider(PgESP, "Distância Máxima", 8, 50, 2000, 1000, "%gm", function(v) C.ESP_MaxDist = v end)

-- ═══════════════════════════════════════════════════
--  ABA AIMBOT
-- ═══════════════════════════════════════════════════
Section(PgAim, "AIMBOT", 1)

SyncToggle["Aimbot"] = Toggle(PgAim, "Aimbot  (WallCheck ativo)", 2, false, function(on)
    C.Aimbot = on; UpdateStatus()
end)
Toggle(PgAim, "Mostrar Círculo FOV", 3, true, function(on) C.Aim_FOVShow = on end)
Toggle(PgAim, "Team Check", 4, true, function(on) C.Aim_TeamCheck = on end)

Section(PgAim, "CONFIG", 5)
Slider(PgAim, "Raio do FOV", 6, 30, 500, 120, "%g px", function(v) C.Aim_FOVRadius = v end)
Slider(PgAim, "Suavização  (Smooth)", 7, 1, 95, 10, "%g", function(v) C.Aim_Smooth = v end)
Dropdown(PgAim, "Mirar em", 8, {"Head","HumanoidRootPart"}, "Head", function(v) C.Aim_HitPart = v end)

Section(PgAim, "TRIGGERBOT", 9)
SyncToggle["Trigger"] = Toggle(PgAim, "Triggerbot  (auto click)", 10, false, function(on)
    C.Trigger = on; UpdateStatus()
end)
Toggle(PgAim, "Team Check  (Trigger)", 11, true, function(on) C.Trigger_Team = on end)
Slider(PgAim, "Delay  (ms)", 12, 10, 500, 80, "%g ms", function(v) C.Trigger_Delay = v end)

-- ═══════════════════════════════════════════════════
--  ABA SILENT
-- ═══════════════════════════════════════════════════
Section(PgSil, "SILENT AIM", 1)

SyncToggle["Silent"] = Toggle(PgSil, "Silent Aim  (hook FireServer)", 2, false, function(on)
    C.Silent = on; UpdateStatus()
    EnableSilent(on)
end)
Toggle(PgSil, "Team Check  (Silent)", 3, true, function(on) C.Silent_Team = on end)

local silInfo = Instance.new("TextLabel", PgSil)
silInfo.Text        = "⚠  O Silent Aim redireciona\nprojéteis para o alvo dentro do\nFOV sem mover sua câmera."
silInfo.Size        = UDim2.new(1, 0, 0, 46)
silInfo.BackgroundColor3 = Color3.fromRGB(30,12,12)
silInfo.TextColor3  = Color3.fromRGB(200,160,100)
silInfo.TextSize    = 10
silInfo.Font        = Enum.Font.Gotham
silInfo.TextWrapped = true
silInfo.TextXAlignment = Enum.TextXAlignment.Left
silInfo.BorderSizePixel = 0
silInfo.LayoutOrder = 4
local sc2 = Instance.new("UIPadding", silInfo)
sc2.PaddingLeft = UDim.new(0,8)
Instance.new("UICorner", silInfo).CornerRadius = UDim.new(0,6)

-- ═══════════════════════════════════════════════════
--  ABA MISC
-- ═══════════════════════════════════════════════════
Section(PgMisc, "MOVIMENTO", 1)

SyncToggle["Speed"] = Toggle(PgMisc, "Speed Hack", 2, false, function(on)
    C.Speed = on; UpdateStatus(); SetSpeed(on)
end)
Slider(PgMisc, "Walk Speed", 3, 16, 350, 60, "%g", function(v) C.WalkSpeed = v end)

SyncToggle["BHop"] = Toggle(PgMisc, "Bunny Hop  (segurar SPACE)", 4, false, function(on)
    C.BHop = on; UpdateStatus(); SetBHop(on)
end)

Section(PgMisc, "PLAYER", 5)

SyncToggle["Noclip"] = Toggle(PgMisc, "Noclip  (atravessar paredes)", 6, false, function(on)
    C.Noclip = on; UpdateStatus(); SetNoclip(on)
end)
SyncToggle["InfJump"] = Toggle(PgMisc, "Infinite Jump", 7, false, function(on)
    C.InfJump = on; UpdateStatus(); SetInfJump(on)
end)

-- ═══════════════════════════════════════════════════
--  ABA KEYBINDS
-- ═══════════════════════════════════════════════════
Section(PgKeys, "CONFIGURAR TECLAS", 1)

local KbDefs = {
    { id="KB_Menu",    label="Abrir/Fechar Menu" },
    { id="KB_ESP",     label="ESP"               },
    { id="KB_Aimbot",  label="Aimbot"            },
    { id="KB_Silent",  label="Silent Aim"        },
    { id="KB_Trigger", label="Triggerbot"        },
    { id="KB_Speed",   label="Speed Hack"        },
    { id="KB_Noclip",  label="Noclip"            },
    { id="KB_InfJump", label="Infinite Jump"     },
    { id="KB_BHop",    label="Bunny Hop"         },
}

local KbBtns      = {}
local KbListening = nil

for i, d in ipairs(KbDefs) do
    local row = Instance.new("Frame", PgKeys)
    row.Size            = UDim2.new(1, 0, 0, 28)
    row.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    row.BorderSizePixel = 0
    row.LayoutOrder     = i + 1
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Text        = d.label
    lbl.Size        = UDim2.new(1, -105, 1, 0)
    lbl.Position    = UDim2.fromOffset(10, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3  = Color3.fromRGB(205, 205, 215)
    lbl.TextSize    = 11
    lbl.Font        = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", row)
    btn.Size            = UDim2.fromOffset(88, 20)
    btn.Position        = UDim2.new(1, -96, 0.5, -10)
    btn.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
    btn.TextColor3      = Color3.fromRGB(195, 40, 40)
    btn.TextSize        = 10
    btn.Font            = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local function Refresh()
        btn.Text = "[ " .. C[d.id].Name .. " ]"
    end
    Refresh()

    btn.MouseButton1Click:Connect(function()
        if KbListening == d.id then
            KbListening          = nil
            btn.BackgroundColor3 = Color3.fromRGB(26,26,38)
            Refresh()
        else
            for _, kb in pairs(KbBtns) do
                kb.btn.BackgroundColor3 = Color3.fromRGB(26,26,38)
                kb.refresh()
            end
            KbListening          = d.id
            btn.Text             = " pressione... "
            btn.BackgroundColor3 = Color3.fromRGB(140,22,22)
        end
    end)
    KbBtns[d.id] = { btn=btn, refresh=Refresh }
end

local hint = Instance.new("TextLabel", PgKeys)
hint.Text        = "Clique no botão → pressione a tecla desejada  •  ESC cancela"
hint.Size        = UDim2.new(1, 0, 0, 24)
hint.BackgroundTransparency = 1
hint.TextColor3  = Color3.fromRGB(90, 90, 110)
hint.TextSize    = 9
hint.Font        = Enum.Font.Gotham
hint.TextWrapped = true
hint.LayoutOrder = 99

-- ═══════════════════════════════════════════════════
--  INPUT
-- ═══════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local kc = input.KeyCode

    -- capturar keybind
    if KbListening then
        if kc == Enum.KeyCode.Escape then
            for _, kb in pairs(KbBtns) do
                kb.btn.BackgroundColor3 = Color3.fromRGB(26,26,38)
                kb.refresh()
            end
        else
            C[KbListening] = kc
            if KbBtns[KbListening] then
                KbBtns[KbListening].btn.BackgroundColor3 = Color3.fromRGB(26,26,38)
                KbBtns[KbListening].refresh()
            end
        end
        KbListening = nil
        return
    end

    if gp then return end

    local function FireToggle(cfgKey, syncKey, extra)
        local v = not C[cfgKey]
        C[cfgKey] = v
        UpdateStatus()
        if SyncToggle[syncKey] then SyncToggle[syncKey](v) end
        if extra then extra(v) end
    end

    if     kc == C.KB_Menu    then Screen.Enabled = not Screen.Enabled
    elseif kc == C.KB_ESP     then FireToggle("ESP",    "ESP")
    elseif kc == C.KB_Aimbot  then FireToggle("Aimbot", "Aimbot")
    elseif kc == C.KB_Silent  then FireToggle("Silent", "Silent", EnableSilent)
    elseif kc == C.KB_Trigger then FireToggle("Trigger","Trigger")
    elseif kc == C.KB_Speed   then FireToggle("Speed",  "Speed",  SetSpeed)
    elseif kc == C.KB_Noclip  then FireToggle("Noclip", "Noclip", SetNoclip)
    elseif kc == C.KB_InfJump then FireToggle("InfJump","InfJump",SetInfJump)
    elseif kc == C.KB_BHop    then FireToggle("BHop",   "BHop",   SetBHop)
    end
end)

-- ═══════════════════════════════════════════════════
--  MINIMIZAR / FECHAR
-- ═══════════════════════════════════════════════════
local minimized = false

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    local tween = TweenService:Create(Win, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = minimized
            and UDim2.fromOffset(310, 45)
            or  UDim2.fromOffset(310, 0)
    })
    TabBar.Visible     = not minimized
    StatusBar.Visible  = not minimized
    PageHolder.Visible = not minimized
    if not minimized then Win.AutomaticSize = Enum.AutomaticSize.Y end
    tween:Play()
    tween.Completed:Connect(function()
        if minimized then Win.AutomaticSize = Enum.AutomaticSize.None end
    end)
    MinBtn.Text = minimized and "□" or "─"
end)

CloseBtn.MouseButton1Click:Connect(function()
    -- limpar tudo
    pcall(function() FovCircle:Remove() end)
    for _, p in ipairs(Players:GetPlayers()) do ESP_Remove(p) end
    SetSpeed(false); SetNoclip(false); SetInfJump(false); SetBHop(false)
    EnableSilent(false)
    Screen:Destroy()
end)

-- AutomaticSize na janela
Win.AutomaticSize = Enum.AutomaticSize.Y
Win.Size          = UDim2.fromOffset(310, 0)

-- ═══════════════════════════════════════════════════
--  PRINT DE CONFIRMAÇÃO
-- ═══════════════════════════════════════════════════
print("╔══════════════════════════════╗")
print("║   AIO Menu v4  ULTRA EDITION ║")
print("╠══════════════════════════════╣")
print("║  ESP      → " .. C.KB_ESP.Name)
print("║  Aimbot   → " .. C.KB_Aimbot.Name)
print("║  Silent   → " .. C.KB_Silent.Name)
print("║  Trigger  → " .. C.KB_Trigger.Name)
print("║  Speed    → " .. C.KB_Speed.Name)
print("║  Noclip   → " .. C.KB_Noclip.Name)
print("║  InfJump  → " .. C.KB_InfJump.Name)
print("║  BHop     → " .. C.KB_BHop.Name)
print("║  Menu     → " .. C.KB_Menu.Name)
print("╚══════════════════════════════╝")
