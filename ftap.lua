--[[
 _____ _____ ___  ____
|  ___|_   _|   \|  _ \
| |_    | | | |) | |_) |
|  _|   | | |  _/|  __/
|_|    |_| |_|  |_|

  Fling Things and People — Linoria Style
  All features preserved from AIO v4
]]

-- ══════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ══════════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════════
local C = {
    SuperStrength  = false, StrengthMult  = 500,
    FlingAura      = false, AuraRadius    = 20,
    AutoFling      = false,
    AntiGrab       = false,
    Fly            = false, FlySpeed      = 50,
    Noclip         = false,
    InfJump        = false,
    Speed          = false, WalkSpeed     = 60,
    BHop           = false,
    ESP            = false,

    KB_Menu        = Enum.KeyCode.Insert,
    KB_SuperStr    = Enum.KeyCode.Q,
    KB_FlingAura   = Enum.KeyCode.E,
    KB_AntiGrab    = Enum.KeyCode.R,
    KB_Fly         = Enum.KeyCode.X,
    KB_Noclip      = Enum.KeyCode.N,
    KB_InfJump     = Enum.KeyCode.B,
    KB_Speed       = Enum.KeyCode.Y,
    KB_ESP         = Enum.KeyCode.T,
}

-- ══════════════════════════════════════════
--  DRAWING — ESP
-- ══════════════════════════════════════════
local function D_Quad(col, filled, thick)
    local q = Drawing.new("Quad")
    q.Color = col; q.Filled = filled; q.Thickness = thick or 1.5
    q.Transparency = 1; q.Visible = false; return q
end
local function D_Text(col, sz)
    local t = Drawing.new("Text")
    t.Color = col; t.Size = sz or 12; t.Font = Drawing.Fonts.UI
    t.Outline = true; t.OutlineColor = Color3.new(0,0,0)
    t.Visible = false; return t
end

local ESPData = {}
local function ESP_Create(plr, char)
    if ESPData[plr] and ESPData[plr]._char == char then return end
    if ESPData[plr] then
        for k, d in pairs(ESPData[plr]) do
            if k ~= "_char" then pcall(function() d:Remove() end) end
        end
        ESPData[plr] = nil
    end
    ESPData[plr] = {
        _char  = char,
        shadow = D_Quad(Color3.new(0,0,0),         false, 3),
        box    = D_Quad(Color3.fromRGB(100,180,255),false, 1.5),
        hpBg   = D_Quad(Color3.fromRGB(10,10,10),  true,  1),
        hpFill = D_Quad(Color3.fromRGB(60,220,80), true,  1),
        name   = D_Text(Color3.new(1,1,1),         13),
    }
end
local function ESP_Remove(plr)
    if not ESPData[plr] then return end
    for k, d in pairs(ESPData[plr]) do
        if k ~= "_char" then pcall(function() d:Remove() end) end
    end
    ESPData[plr] = nil
end
local function ESP_Hide(plr)
    if not ESPData[plr] then return end
    for k, d in pairs(ESPData[plr]) do
        if k ~= "_char" then pcall(function() d.Visible = false end) end
    end
end
local function GetBox(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local p = hrp.Position
    local H, W = 3.1, 1.35
    local pts = {
        Vector3.new(W,H,W),Vector3.new(-W,H,W),Vector3.new(W,H,-W),Vector3.new(-W,H,-W),
        Vector3.new(W,-H,W),Vector3.new(-W,-H,W),Vector3.new(W,-H,-W),Vector3.new(-W,-H,-W),
    }
    local mnX,mnY,mxX,mxY = 1e9,1e9,-1e9,-1e9
    for _,o in ipairs(pts) do
        local sp = Camera:WorldToViewportPoint(p+o)
        if sp.Z <= 0 then return nil end
        mnX=math.min(mnX,sp.X); mnY=math.min(mnY,sp.Y)
        mxX=math.max(mxX,sp.X); mxY=math.max(mxY,sp.Y)
    end
    local vp = Camera.ViewportSize
    if mxX<0 or mnX>vp.X or mxY<0 or mnY>vp.Y then return nil end
    return Vector2.new(mnX,mnY),Vector2.new(mxX,mnY),Vector2.new(mnX,mxY),Vector2.new(mxX,mxY)
end

-- ══════════════════════════════════════════
--  GAMEPLAY FEATURES
-- ══════════════════════════════════════════
local function FlingPlayer(char, force)
    local hrp   = char:FindFirstChild("HumanoidRootPart")
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not myHrp then return end
    local dir = (hrp.Position - myHrp.Position).Unit
    local bv  = Instance.new("BodyVelocity")
    bv.Velocity = (dir + Vector3.new(0,0.5,0)).Unit * force
    bv.MaxForce = Vector3.new(1e9,1e9,1e9)
    bv.Parent   = hrp
    game:GetService("Debris"):AddItem(bv, 0.2)
end

local StrConn, AuraConn, AntiGrabConn = nil, nil, nil
local FlyConn, FlyBV, FlyBG           = nil, nil, nil
local NoclipConn, JumpConn            = nil, nil
local SpeedConn, BHopConn             = nil, nil

local function SetSuperStrength(on)
    if StrConn then StrConn:Disconnect(); StrConn = nil end
    if not on then return end
    StrConn = Workspace.DescendantAdded:Connect(function(inst)
        task.defer(function()
            if not inst.Parent then return end
            if inst:IsA("BodyVelocity") then
                inst.Velocity  = inst.Velocity * C.StrengthMult
                inst.MaxForce  = Vector3.new(1e9,1e9,1e9)
            elseif inst:IsA("LinearVelocity") then
                inst.VectorVelocity = inst.VectorVelocity * C.StrengthMult
                inst.MaxForce = 1e9
            elseif inst:IsA("VectorForce") then
                inst.Force = inst.Force * C.StrengthMult
            end
        end)
    end)
end

local function SetFlingAura(on)
    if AuraConn then AuraConn:Disconnect(); AuraConn = nil end
    if not on then return end
    AuraConn = RunService.Heartbeat:Connect(function()
        local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not myHrp then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LP then continue end
            local char = plr.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - myHrp.Position).Magnitude <= C.AuraRadius then
                FlingPlayer(char, 500)
            end
        end
    end)
end

local function DoGrabAll()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(myHrp.Position + Vector3.new(math.random(-3,3),2,math.random(-3,3)))
            task.wait(0.05)
            FlingPlayer(char, 800)
        end
    end
end

local function DoPositionGrab()
    local myHrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    local best, bestD = nil, 100
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local d = (hrp.Position - myHrp.Position).Magnitude
            if d < bestD then bestD = d; best = plr end
        end
    end
    if best and best.Character then
        local hrp = best.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = myHrp.CFrame * CFrame.new(0,0,-2)
            task.wait(0.05)
            FlingPlayer(best.Character, 1000)
        end
    end
end

-- nomes de joints nativos do personagem — nunca remover
local SAFE_JOINTS = {
    RootJoint=true, Neck=true, Left_Shoulder=true, Right_Shoulder=true,
    Left_Hip=true,  Right_Hip=true, ["Left Shoulder"]=true, ["Right Shoulder"]=true,
    ["Left Hip"]=true, ["Right Hip"]=true,
}

local function SetAntiGrab(on)
    if AntiGrabConn then AntiGrabConn:Disconnect(); AntiGrabConn = nil end
    if not on then return end
    AntiGrabConn = RunService.Heartbeat:Connect(function()
        local char = LP.Character
        if not char then return end

        -- varre TODO o personagem, não só o HRP
        for _, inst in ipairs(char:GetDescendants()) do
            if SAFE_JOINTS[inst.Name] then continue end

            local remove = false

            -- constraints físicas usadas pelo FTAP para travar o player
            if inst:IsA("WeldConstraint")       then remove = true end
            if inst:IsA("Weld")                 then remove = true end
            if inst:IsA("RigidConstraint")      then remove = true end
            if inst:IsA("BallSocketConstraint") then remove = true end
            if inst:IsA("HingeConstraint")      then remove = true end
            if inst:IsA("NoCollisionConstraint")then remove = true end

            -- AlignPosition / AlignOrientation — principal método do FTAP
            if inst:IsA("AlignPosition")        then remove = true end
            if inst:IsA("AlignOrientation")     then remove = true end

            -- forças externas aplicadas ao HRP
            if inst:IsA("BodyVelocity")         then remove = true end
            if inst:IsA("BodyForce")            then remove = true end
            if inst:IsA("BodyPosition")         then remove = true end
            if inst:IsA("BodyAngularVelocity")  then remove = true end
            if inst:IsA("LinearVelocity")       then remove = true end
            if inst:IsA("AngularVelocity")      then remove = true end
            if inst:IsA("VectorForce")          then remove = true end

            if remove then pcall(function() inst:Destroy() end) end
        end

        -- garante que o HRP nunca fica ancorado por outro script
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = false end
    end)
end

local function SetFly(on)
    if FlyConn then FlyConn:Disconnect(); FlyConn = nil end
    if FlyBV and FlyBV.Parent then FlyBV:Destroy() end
    if FlyBG and FlyBG.Parent then FlyBG:Destroy() end
    FlyBV, FlyBG = nil, nil
    if not on then
        local c = LP.Character
        if c then local h = c:FindFirstChildOfClass("Humanoid"); if h then h:ChangeState(Enum.HumanoidStateType.GettingUp) end end
        return
    end
    local c   = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    FlyBV = Instance.new("BodyVelocity", hrp); FlyBV.Velocity = Vector3.zero; FlyBV.MaxForce = Vector3.new(1e9,1e9,1e9)
    FlyBG = Instance.new("BodyGyro", hrp); FlyBG.MaxTorque = Vector3.new(1e9,1e9,1e9); FlyBG.P = 9e4; FlyBG.D = 1e3
    FlyConn = RunService.RenderStepped:Connect(function()
        local hrp2 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp2 or not FlyBV then return end
        local cf, vel = Camera.CFrame, Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel = vel + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel = vel - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel = vel - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel = vel + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0,1,0) end
        if vel.Magnitude > 0 then vel = vel.Unit * C.FlySpeed end
        FlyBV.Velocity = vel; FlyBG.CFrame = cf
    end)
end

local function SetNoclip(on)
    if NoclipConn then NoclipConn:Disconnect(); NoclipConn = nil end
    if not on then return end
    NoclipConn = RunService.Stepped:Connect(function()
        local c = LP.Character; if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end

local function SetInfJump(on)
    if JumpConn then JumpConn:Disconnect(); JumpConn = nil end
    if not on then return end
    JumpConn = UserInputService.JumpRequest:Connect(function()
        local c = LP.Character; if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

local function SetSpeed(on)
    if SpeedConn then SpeedConn:Disconnect(); SpeedConn = nil end
    if not on then
        local c = LP.Character; if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = 16 end
        return
    end
    SpeedConn = RunService.Heartbeat:Connect(function()
        local c = LP.Character; if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed = C.WalkSpeed end
    end)
end

local function SetBHop(on)
    if BHopConn then BHopConn:Disconnect(); BHopConn = nil end
    if not on then return end
    BHopConn = RunService.Heartbeat:Connect(function()
        local c = LP.Character; if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        if h and UserInputService:IsKeyDown(Enum.KeyCode.Space) and h:GetState() == Enum.HumanoidStateType.Landed then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

-- Render loop ESP
local sc = Vector2.new(0,0)
RunService.RenderStepped:Connect(function()
    sc = Vector2.new(Camera.ViewportSize.X*0.5, Camera.ViewportSize.Y*0.5)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char  = plr.Character
        local hum   = char and char:FindFirstChildOfClass("Humanoid")
        local alive = hum ~= nil and hum.Health > 0
        if C.ESP and alive and char then
            ESP_Create(plr, char)
            local esp = ESPData[plr]
            local tl,tr,bl,br = GetBox(char)
            if tl then
                local off = Vector2.new(1,1)
                esp.shadow.PointA=tl+off; esp.shadow.PointB=tr+off; esp.shadow.PointC=br+off; esp.shadow.PointD=bl+off; esp.shadow.Visible=true
                esp.box.PointA=tl; esp.box.PointB=tr; esp.box.PointC=br; esp.box.PointD=bl; esp.box.Visible=true
                local bW,bX = 4, tl.X-7
                local pct   = math.clamp(hum.Health/hum.MaxHealth,0,1)
                local top   = bl.Y-(bl.Y-tl.Y)*pct
                local hpCol = pct>.6 and Color3.fromRGB(50,220,70) or pct>.3 and Color3.fromRGB(230,195,40) or Color3.fromRGB(230,50,50)
                esp.hpBg.PointA=Vector2.new(bX,tl.Y); esp.hpBg.PointB=Vector2.new(bX+bW,tl.Y); esp.hpBg.PointC=Vector2.new(bX+bW,bl.Y); esp.hpBg.PointD=Vector2.new(bX,bl.Y); esp.hpBg.Visible=true
                esp.hpFill.Color=hpCol; esp.hpFill.PointA=Vector2.new(bX,top); esp.hpFill.PointB=Vector2.new(bX+bW,top); esp.hpFill.PointC=Vector2.new(bX+bW,bl.Y); esp.hpFill.PointD=Vector2.new(bX,bl.Y); esp.hpFill.Visible=true
                local hrp2 = char:FindFirstChild("HumanoidRootPart")
                local dist = hrp2 and math.floor((Camera.CFrame.Position-hrp2.Position).Magnitude) or 0
                esp.name.Text=(plr.DisplayName).."  ["..dist.."m]"; esp.name.Position=Vector2.new((tl.X+tr.X)*0.5,tl.Y-16); esp.name.Center=true; esp.name.Visible=true
            else ESP_Hide(plr) end
        else ESP_Hide(plr) end
    end
end)

Players.PlayerRemoving:Connect(ESP_Remove)
Players.PlayerAdded:Connect(function(p) p.CharacterRemoving:Connect(function() ESP_Hide(p) end) end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then p.CharacterRemoving:Connect(function() ESP_Hide(p) end) end
end

-- ══════════════════════════════════════════
--  LINORIA-STYLE GUI
--
--  Layout:
--  ┌─────────────────────────────┐
--  │  Título  •  subtitle        │  ← header fixo
--  ├─────────────────────────────┤
--  │  [▼] FLING                  │  ← seção dobrável
--  │    ○ Super Strength  [off]  │
--  │    ○ Fling Aura      [off]  │
--  │    ─── Força: ████── 500   │
--  │  [▼] GRAB                   │
--  │  ...                        │
--  └─────────────────────────────┘
-- ══════════════════════════════════════════
local ACCENT  = Color3.fromRGB(100, 180, 255)  -- azul claro — cor de destaque
local BG      = Color3.fromRGB(25,  25,  30)   -- fundo da janela
local BG2     = Color3.fromRGB(32,  32,  38)   -- fundo dos items
local BG3     = Color3.fromRGB(20,  20,  25)   -- fundo das seções
local TEXT    = Color3.fromRGB(240, 240, 245)  -- texto principal
local SUBTEXT = Color3.fromRGB(150, 150, 165)  -- texto secundário
local BORDER  = Color3.fromRGB(50,  50,  62)   -- bordas

local ok, CoreGui = pcall(function() return game:GetService("CoreGui") end)
local Screen = Instance.new("ScreenGui")
Screen.Name="FTAP_Linoria"; Screen.ResetOnSpawn=false
Screen.ZIndexBehavior=Enum.ZIndexBehavior.Global
Screen.IgnoreGuiInset=true
Screen.Parent = ok and CoreGui or LP:WaitForChild("PlayerGui")

-- ── Janela ──────────────────────────────────────────
local Win = Instance.new("Frame", Screen)
Win.Name="Win"; Win.Size=UDim2.fromOffset(280, 0)
Win.Position=UDim2.fromOffset(120, 80)
Win.BackgroundColor3=BG; Win.BorderSizePixel=0
Win.AutomaticSize=Enum.AutomaticSize.Y
Win.ClipsDescendants=true
Instance.new("UICorner",Win).CornerRadius=UDim.new(0,8)
local wStroke=Instance.new("UIStroke",Win); wStroke.Color=BORDER; wStroke.Thickness=1

-- ── Header ──────────────────────────────────────────
local Header=Instance.new("Frame",Win)
Header.Size=UDim2.new(1,0,0,48); Header.BackgroundColor3=BG3; Header.BorderSizePixel=0

-- linha accent no topo
local accentLine=Instance.new("Frame",Header)
accentLine.Size=UDim2.new(1,0,0,2); accentLine.BackgroundColor3=ACCENT; accentLine.BorderSizePixel=0

local hTitle=Instance.new("TextLabel",Header)
hTitle.Text="Fling Things & People"; hTitle.Size=UDim2.new(1,-80,0,26)
hTitle.Position=UDim2.fromOffset(12,10); hTitle.BackgroundTransparency=1
hTitle.TextColor3=TEXT; hTitle.TextSize=13; hTitle.Font=Enum.Font.GothamBold
hTitle.TextXAlignment=Enum.TextXAlignment.Left

local hSub=Instance.new("TextLabel",Header)
hSub.Text="AIO Menu  •  by you"; hSub.Size=UDim2.new(1,-80,0,14)
hSub.Position=UDim2.fromOffset(12,28); hSub.BackgroundTransparency=1
hSub.TextColor3=SUBTEXT; hSub.TextSize=10; hSub.Font=Enum.Font.Gotham
hSub.TextXAlignment=Enum.TextXAlignment.Left

-- botões header
local function HBtn(sym, ox, col)
    local b=Instance.new("TextButton",Header)
    b.Size=UDim2.fromOffset(20,20); b.Position=UDim2.new(1,ox,0.5,-10)
    b.BackgroundColor3=col; b.Text=sym; b.TextColor3=TEXT
    b.TextSize=11; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,4); return b
end
local MinBtn   = HBtn("─",-46, Color3.fromRGB(50,50,62))
local CloseBtn = HBtn("✕",-22, Color3.fromRGB(200,60,60))

-- arrastar
do
    local drag,ds,dp
    Header.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true;ds=i.Position;dp=Win.Position end
    end)
    Header.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds
            Win.Position=UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y)
        end
    end)
end

-- ── ScrollFrame (conteúdo) ───────────────────────────
local Scroll=Instance.new("ScrollingFrame",Win)
Scroll.Size=UDim2.new(1,0,0,0); Scroll.Position=UDim2.fromOffset(0,48)
Scroll.AutomaticSize=Enum.AutomaticSize.Y
Scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
Scroll.BackgroundTransparency=1; Scroll.BorderSizePixel=0
Scroll.ScrollBarThickness=3; Scroll.ScrollBarImageColor3=ACCENT
Scroll.CanvasSize=UDim2.new(0,0,0,0)

local ContentLayout=Instance.new("UIListLayout",Scroll)
ContentLayout.Padding=UDim.new(0,0); ContentLayout.SortOrder=Enum.SortOrder.LayoutOrder

local ContentPad=Instance.new("UIPadding",Scroll)
ContentPad.PaddingBottom=UDim.new(0,8)

-- ══════════════════════════════════════════
--  LINORIA UI LIBRARY (local)
-- ══════════════════════════════════════════
local SyncFns = {}  -- [key] -> Set(bool) para sincronizar com keybind

-- cria seção dobrável
local sectionOrder = 0
local function Section(title)
    sectionOrder = sectionOrder + 1

    local wrap=Instance.new("Frame",Scroll)
    wrap.Name=title; wrap.Size=UDim2.new(1,0,0,0)
    wrap.AutomaticSize=Enum.AutomaticSize.Y
    wrap.BackgroundTransparency=1; wrap.BorderSizePixel=0
    wrap.LayoutOrder=sectionOrder

    -- header da seção
    local sHead=Instance.new("TextButton",wrap)
    sHead.Size=UDim2.new(1,0,0,32); sHead.BackgroundColor3=BG3
    sHead.BorderSizePixel=0; sHead.Text=""; sHead.AutoButtonColor=false

    -- linha accent esquerda
    local sideLine=Instance.new("Frame",sHead)
    sideLine.Size=UDim2.new(0,2,0.6,0); sideLine.Position=UDim2.new(0,0,0.2,0)
    sideLine.BackgroundColor3=ACCENT; sideLine.BorderSizePixel=0

    local sTitle=Instance.new("TextLabel",sHead)
    sTitle.Text=title; sTitle.Size=UDim2.new(1,-40,1,0); sTitle.Position=UDim2.fromOffset(12,0)
    sTitle.BackgroundTransparency=1; sTitle.TextColor3=TEXT
    sTitle.TextSize=11; sTitle.Font=Enum.Font.GothamBold
    sTitle.TextXAlignment=Enum.TextXAlignment.Left

    local arrow=Instance.new("TextLabel",sHead)
    arrow.Text="▾"; arrow.Size=UDim2.fromOffset(20,20); arrow.Position=UDim2.new(1,-24,0.5,-10)
    arrow.BackgroundTransparency=1; arrow.TextColor3=SUBTEXT
    arrow.TextSize=12; arrow.Font=Enum.Font.GothamBold

    -- separador
    local sep=Instance.new("Frame",wrap)
    sep.Size=UDim2.new(1,0,0,1); sep.Position=UDim2.fromOffset(0,32)
    sep.BackgroundColor3=BORDER; sep.BorderSizePixel=0

    -- container dos items
    local items=Instance.new("Frame",wrap)
    items.Name="Items"; items.Size=UDim2.new(1,0,0,0)
    items.Position=UDim2.fromOffset(0,33)
    items.AutomaticSize=Enum.AutomaticSize.Y
    items.BackgroundTransparency=1; items.BorderSizePixel=0

    local iLayout=Instance.new("UIListLayout",items)
    iLayout.Padding=UDim.new(0,1); iLayout.SortOrder=Enum.SortOrder.LayoutOrder

    -- colapsar/expandir
    local collapsed=false
    sHead.MouseButton1Click:Connect(function()
        collapsed=not collapsed
        items.Visible=not collapsed
        sep.Visible=not collapsed
        arrow.Text=collapsed and "▸" or "▾"
        arrow.TextColor3=collapsed and ACCENT or SUBTEXT
    end)

    -- hover
    sHead.MouseEnter:Connect(function() sHead.BackgroundColor3=Color3.fromRGB(28,28,34) end)
    sHead.MouseLeave:Connect(function() sHead.BackgroundColor3=BG3 end)

    return items
end

-- toggle (linha com switch pill)
local itemOrder=0
local function Toggle(parent, label, init, cb)
    itemOrder=itemOrder+1
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,34); row.BackgroundColor3=BG2
    row.BorderSizePixel=0; row.LayoutOrder=itemOrder

    -- hover highlight
    local hl=Instance.new("Frame",row)
    hl.Size=UDim2.new(1,0,1,0); hl.BackgroundColor3=Color3.fromRGB(255,255,255)
    hl.BackgroundTransparency=1; hl.BorderSizePixel=0

    local lbl=Instance.new("TextLabel",row)
    lbl.Text=label; lbl.Size=UDim2.new(1,-60,1,0); lbl.Position=UDim2.fromOffset(14,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=TEXT
    lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left

    -- pill switch
    local track=Instance.new("Frame",row)
    track.Size=UDim2.fromOffset(32,16); track.Position=UDim2.new(1,-44,0.5,-8)
    track.BackgroundColor3=Color3.fromRGB(50,50,65); track.BorderSizePixel=0
    Instance.new("UICorner",track).CornerRadius=UDim.new(0,8)

    local dot=Instance.new("Frame",track)
    dot.Size=UDim2.fromOffset(12,12); dot.Position=UDim2.new(0,2,0.5,-6)
    dot.BackgroundColor3=Color3.fromRGB(90,90,110); dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(0,6)

    local on=init or false
    local function Set(val, silent)
        on=val
        if on then
            track.BackgroundColor3=ACCENT
            dot.BackgroundColor3=Color3.new(1,1,1)
            dot:TweenPosition(UDim2.new(0,18,0.5,-6),"Out","Quad",0.12,true)
            lbl.TextColor3=TEXT
        else
            track.BackgroundColor3=Color3.fromRGB(50,50,65)
            dot.BackgroundColor3=Color3.fromRGB(90,90,110)
            dot:TweenPosition(UDim2.new(0,2,0.5,-6),"Out","Quad",0.12,true)
            lbl.TextColor3=SUBTEXT
        end
        if not silent and cb then cb(on) end
    end
    local click=Instance.new("TextButton",row)
    click.Size=UDim2.new(1,0,1,0); click.BackgroundTransparency=1; click.Text=""
    click.MouseButton1Click:Connect(function() Set(not on) end)
    click.MouseEnter:Connect(function() hl.BackgroundTransparency=0.96 end)
    click.MouseLeave:Connect(function() hl.BackgroundTransparency=1 end)
    Set(on,true)
    return Set
end

-- slider
local function Slider(parent, label, minV, maxV, def, fmt, cb)
    itemOrder=itemOrder+1
    local cont=Instance.new("Frame",parent)
    cont.Size=UDim2.new(1,0,0,44); cont.BackgroundColor3=BG2
    cont.BorderSizePixel=0; cont.LayoutOrder=itemOrder

    local lbl=Instance.new("TextLabel",cont)
    lbl.Text=label; lbl.Size=UDim2.new(0.65,0,0,18); lbl.Position=UDim2.fromOffset(14,4)
    lbl.BackgroundTransparency=1; lbl.TextColor3=SUBTEXT
    lbl.TextSize=10; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left

    local vLbl=Instance.new("TextLabel",cont)
    vLbl.Size=UDim2.new(0.35,-14,0,18); vLbl.Position=UDim2.new(0.65,0,0,4)
    vLbl.BackgroundTransparency=1; vLbl.TextColor3=ACCENT
    vLbl.TextSize=10; vLbl.Font=Enum.Font.GothamBold; vLbl.TextXAlignment=Enum.TextXAlignment.Right

    local trackBg=Instance.new("Frame",cont)
    trackBg.Size=UDim2.new(1,-28,0,4); trackBg.Position=UDim2.new(0,14,0,30)
    trackBg.BackgroundColor3=Color3.fromRGB(45,45,58); trackBg.BorderSizePixel=0
    Instance.new("UICorner",trackBg).CornerRadius=UDim.new(0,2)

    local fill=Instance.new("Frame",trackBg)
    fill.BackgroundColor3=ACCENT; fill.BorderSizePixel=0; fill.Size=UDim2.new(0,0,1,0)
    Instance.new("UICorner",fill).CornerRadius=UDim.new(0,2)

    local knob=Instance.new("Frame",fill)
    knob.Size=UDim2.fromOffset(10,10); knob.Position=UDim2.new(1,-5,0.5,-5)
    knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; knob.ZIndex=3
    Instance.new("UICorner",knob).CornerRadius=UDim.new(0,5)

    local function SV(v, silent)
        v=math.clamp(math.floor(v+0.5),minV,maxV)
        fill.Size=UDim2.new((v-minV)/(maxV-minV),0,1,0)
        vLbl.Text=string.format(fmt or "%g",v)
        if not silent and cb then cb(v) end
    end
    SV(def,true)
    local drag=false
    local hb=Instance.new("TextButton",cont)
    hb.Size=UDim2.new(1,0,0,16); hb.Position=UDim2.new(0,0,0,26)
    hb.BackgroundTransparency=1; hb.Text=""; hb.ZIndex=5
    hb.MouseButton1Down:Connect(function() drag=true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    RunService.RenderStepped:Connect(function()
        if not drag then return end
        local mx=UserInputService:GetMouseLocation().X
        SV(minV+math.clamp((mx-trackBg.AbsolutePosition.X)/trackBg.AbsoluteSize.X,0,1)*(maxV-minV))
    end)
end

-- botão de ação
local function Button(parent, label, cb)
    itemOrder=itemOrder+1
    local btn=Instance.new("TextButton",parent)
    btn.Size=UDim2.new(1,0,0,32); btn.BackgroundColor3=BG2
    btn.Text=""; btn.BorderSizePixel=0; btn.LayoutOrder=itemOrder
    local lbl=Instance.new("TextLabel",btn)
    lbl.Text="▶  "..label; lbl.Size=UDim2.new(1,-14,1,0); lbl.Position=UDim2.fromOffset(14,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=ACCENT
    lbl.TextSize=11; lbl.Font=Enum.Font.GothamBold; lbl.TextXAlignment=Enum.TextXAlignment.Left
    btn.MouseButton1Click:Connect(cb)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3=Color3.fromRGB(36,36,46) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3=BG2 end)
end

-- keybind row
local function KeybindRow(parent, label, cfgKey)
    itemOrder=itemOrder+1
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,32); row.BackgroundColor3=BG2
    row.BorderSizePixel=0; row.LayoutOrder=itemOrder

    local lbl=Instance.new("TextLabel",row)
    lbl.Text=label; lbl.Size=UDim2.new(1,-110,1,0); lbl.Position=UDim2.fromOffset(14,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=SUBTEXT
    lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left

    local kbtn=Instance.new("TextButton",row)
    kbtn.Size=UDim2.fromOffset(90,22); kbtn.Position=UDim2.new(1,-98,0.5,-11)
    kbtn.BackgroundColor3=BG3; kbtn.BorderSizePixel=0
    kbtn.TextSize=10; kbtn.Font=Enum.Font.GothamBold
    kbtn.TextColor3=ACCENT
    Instance.new("UICorner",kbtn).CornerRadius=UDim.new(0,4)
    local kbStroke=Instance.new("UIStroke",kbtn); kbStroke.Color=BORDER; kbStroke.Thickness=1

    local listening=false
    local function Refresh() kbtn.Text="[ "..(C[cfgKey] and C[cfgKey].Name or "?").." ]" end
    Refresh()

    kbtn.MouseButton1Click:Connect(function()
        if listening then
            listening=false; Refresh(); kbtn.BackgroundColor3=BG3; kbStroke.Color=BORDER
        else
            listening=true; kbtn.Text="..."; kbtn.BackgroundColor3=Color3.fromRGB(20,40,65); kbStroke.Color=ACCENT
        end
    end)

    UserInputService.InputBegan:Connect(function(inp, gp)
        if not listening then return end
        if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
        if inp.KeyCode==Enum.KeyCode.Escape then
            listening=false; Refresh(); kbtn.BackgroundColor3=BG3; kbStroke.Color=BORDER
        else
            C[cfgKey]=inp.KeyCode
            listening=false; Refresh(); kbtn.BackgroundColor3=BG3; kbStroke.Color=BORDER
        end
    end)
end

-- divisor entre items
local function Divider(parent)
    itemOrder=itemOrder+1
    local d=Instance.new("Frame",parent)
    d.Size=UDim2.new(1,0,0,1); d.BackgroundColor3=BORDER
    d.BorderSizePixel=0; d.LayoutOrder=itemOrder
end

-- ══════════════════════════════════════════
--  MONTAR O MENU
-- ══════════════════════════════════════════

-- ── FLING ───────────────────────────────
local sFling = Section("FLING")

SyncFns["SuperStr"] = Toggle(sFling,"Super Strength  (multiplica força)",false,function(on)
    C.SuperStrength=on; SetSuperStrength(on)
end)
Slider(sFling,"Multiplicador de Força",10,2000,500,"%gx",function(v) C.StrengthMult=v end)
Divider(sFling)

SyncFns["FlingAura"] = Toggle(sFling,"Fling Aura  (lança quem chegar perto)",false,function(on)
    C.FlingAura=on; SetFlingAura(on)
end)
Slider(sFling,"Raio da Aura",5,100,20,"%g st",function(v) C.AuraRadius=v end)
Divider(sFling)

SyncFns["AutoFling"] = Toggle(sFling,"Auto Fling  (lança todos em loop)",false,function(on)
    C.AutoFling=on
end)

-- ── GRAB ────────────────────────────────
local sGrab = Section("GRAB")

SyncFns["AntiGrab"] = Toggle(sGrab,"Anti Grab  (impede ser agarrado)",false,function(on)
    C.AntiGrab=on; SetAntiGrab(on)
end)
Divider(sGrab)
Button(sGrab,"Grab All  (puxa e lança todos)", DoGrabAll)
Button(sGrab,"Position Grab  (puxa o mais próximo)", DoPositionGrab)

-- ── MOVEMENT ────────────────────────────
local sMove = Section("MOVEMENT")

SyncFns["Fly"] = Toggle(sMove,"Fly  (WASD + Space/Shift)",false,function(on)
    C.Fly=on; SetFly(on)
end)
Slider(sMove,"Velocidade de Voo",10,300,50,"%g",function(v) C.FlySpeed=v end)
Divider(sMove)

SyncFns["Speed"] = Toggle(sMove,"Speed Hack",false,function(on)
    C.Speed=on; SetSpeed(on)
end)
Slider(sMove,"Walk Speed",16,350,60,"%g",function(v) C.WalkSpeed=v end)
Divider(sMove)

SyncFns["BHop"]    = Toggle(sMove,"Bunny Hop  (segure SPACE)",false,function(on) C.BHop=on; SetBHop(on) end)
SyncFns["Noclip"]  = Toggle(sMove,"Noclip  (atravessa paredes)",false,function(on) C.Noclip=on; SetNoclip(on) end)
SyncFns["InfJump"] = Toggle(sMove,"Infinite Jump",false,function(on) C.InfJump=on; SetInfJump(on) end)

-- ── VISUAL ──────────────────────────────
local sVis = Section("VISUAL")

SyncFns["ESP"] = Toggle(sVis,"ESP  (Caixa + Vida + Nick + Dist)",false,function(on)
    C.ESP=on
    if not on then for _,p in ipairs(Players:GetPlayers()) do ESP_Hide(p) end end
end)

-- ── KEYBINDS ────────────────────────────
local sKeys = Section("KEYBINDS")

local kbList = {
    {"Abrir/Fechar Menu",  "KB_Menu"},
    {"Super Strength",     "KB_SuperStr"},
    {"Fling Aura",         "KB_FlingAura"},
    {"Anti Grab",          "KB_AntiGrab"},
    {"Fly",                "KB_Fly"},
    {"Noclip",             "KB_Noclip"},
    {"Infinite Jump",      "KB_InfJump"},
    {"Speed Hack",         "KB_Speed"},
    {"ESP",                "KB_ESP"},
}
for _, kb in ipairs(kbList) do
    KeybindRow(sKeys, kb[1], kb[2])
end

-- ── Auto Fling loop ─────────────────────
local afLast=0
RunService.Heartbeat:Connect(function()
    if not C.AutoFling then return end
    local now=tick()
    if now-afLast < 0.3 then return end
    afLast=now
    local myHrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr==LP then continue end
        local char=plr.Character; if not char then continue end
        FlingPlayer(char, C.StrengthMult*2)
    end
end)

-- ══════════════════════════════════════════
--  KEYBIND GLOBAL (abrir/fechar + features)
-- ══════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType~=Enum.UserInputType.Keyboard then return end
    if gp then return end
    local kc=input.KeyCode

    if kc==C.KB_Menu then Screen.Enabled=not Screen.Enabled; return end

    local map={
        {C.KB_SuperStr,  "SuperStrength","SuperStr",  SetSuperStrength},
        {C.KB_FlingAura, "FlingAura",    "FlingAura", SetFlingAura},
        {C.KB_AntiGrab,  "AntiGrab",     "AntiGrab",  SetAntiGrab},
        {C.KB_Fly,       "Fly",          "Fly",       SetFly},
        {C.KB_Noclip,    "Noclip",       "Noclip",    SetNoclip},
        {C.KB_InfJump,   "InfJump",      "InfJump",   SetInfJump},
        {C.KB_Speed,     "Speed",        "Speed",     SetSpeed},
        {C.KB_ESP,       "ESP",          "ESP",       nil},
    }
    for _,m in ipairs(map) do
        if kc==m[1] then
            local v=not C[m[2]]; C[m[2]]=v
            if SyncFns[m[3]] then SyncFns[m[3]](v) end
            if m[4] then m[4](v) end
        end
    end
end)

-- ══════════════════════════════════════════
--  MINIMIZAR / FECHAR
-- ══════════════════════════════════════════
local minimized=false
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    Scroll.Visible=not minimized
    Win.AutomaticSize=minimized and Enum.AutomaticSize.None or Enum.AutomaticSize.Y
    if minimized then Win.Size=UDim2.fromOffset(280,48) end
    MinBtn.Text=minimized and "□" or "─"
end)

CloseBtn.MouseButton1Click:Connect(function()
    pcall(function()
        for _,p in ipairs(Players:GetPlayers()) do ESP_Remove(p) end
        SetSuperStrength(false); SetFlingAura(false); SetAntiGrab(false)
        SetFly(false); SetNoclip(false); SetInfJump(false); SetSpeed(false); SetBHop(false)
        Screen:Destroy()
    end)
end)

print("[FTAP Linoria] Carregado! INSERT para abrir/fechar.")
