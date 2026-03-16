--[[
╔══════════════════════════════════════════════════════════╗
║           MURDER MYSTERY 2  —  AIO Linoria               ║
║                                                          ║
║  ESP       │ Players • Role • Arma • Distância          ║
║  ROLES     │ Role Finder • Destacar Assassino/Xerife    ║
║  COINS     │ Coin ESP • Auto Collect                    ║
║  AIMBOT    │ FOV • WallCheck • TeamCheck • Smooth       ║
║  MISC      │ Speed • BHop • Noclip • InfJump • Fly      ║
║  KEYBINDS  │ Tudo configurável                          ║
╚══════════════════════════════════════════════════════════╝
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
    -- ESP
    ESP           = false,
    ESP_Box       = true,
    ESP_Health    = true,
    ESP_Name      = true,
    ESP_Role      = true,   -- mostra role (Innocente/Assassino/Xerife)
    ESP_Weapon    = true,   -- mostra arma equipada
    ESP_Distance  = true,
    ESP_Tracer    = false,

    -- Role Finder
    RoleFinder    = false,  -- destaca assassino e xerife no mundo

    -- Coin ESP
    CoinESP       = false,
    AutoCollect   = false,  -- teleporta até as coins automaticamente

    -- Aimbot
    Aimbot        = false,
    Aim_Smooth    = 10,
    Aim_FOVRadius = 120,
    Aim_FOVShow   = true,
    Aim_TeamCheck = false,  -- no MM2 geralmente queremos mirar em todos
    Aim_HitPart   = "Head",
    Aim_KnifeOnly = true,   -- só mira se você for assassino

    -- Misc
    Speed         = false, WalkSpeed  = 60,
    BHop          = false,
    Noclip        = false,
    InfJump       = false,
    Fly           = false, FlySpeed   = 50,

    -- Keybinds
    KB_Menu       = Enum.KeyCode.Insert,
    KB_ESP        = Enum.KeyCode.T,
    KB_RoleFinder = Enum.KeyCode.F,
    KB_CoinESP    = Enum.KeyCode.C,
    KB_Aimbot     = Enum.KeyCode.G,
    KB_Speed      = Enum.KeyCode.Y,
    KB_Noclip     = Enum.KeyCode.N,
    KB_InfJump    = Enum.KeyCode.B,
    KB_Fly        = Enum.KeyCode.X,
}

-- ══════════════════════════════════════════
--  MM2 — ROLE DETECTION
--  O jogo guarda as roles em valores dentro
--  do personagem ou em LocalScripts.
--  Tentamos várias abordagens para compatibilidade.
-- ══════════════════════════════════════════
local ROLE_COLORS = {
    murderer  = Color3.fromRGB(220, 50,  50),   -- vermelho
    sheriff   = Color3.fromRGB(50,  150, 255),  -- azul
    innocent  = Color3.fromRGB(100, 220, 100),  -- verde
    unknown   = Color3.fromRGB(180, 180, 180),  -- cinza
}

local function GetPlayerRole(plr)
    -- MM2 usa uma pasta "GameFolder" ou valores no player
    -- Tentativa 1: valor "role" direto no player
    local roleVal = plr:FindFirstChild("role") or plr:FindFirstChild("Role")
    if roleVal and roleVal:IsA("StringValue") then
        local r = roleVal.Value:lower()
        if r:find("murd") then return "murderer"
        elseif r:find("sher") then return "sheriff"
        else return "innocent" end
    end

    -- Tentativa 2: via Team
    if plr.Team then
        local tname = plr.Team.Name:lower()
        if tname:find("murd") then return "murderer"
        elseif tname:find("sher") then return "sheriff"
        elseif tname:find("inn")  then return "innocent" end
    end

    -- Tentativa 3: verificar se tem faca no personagem
    local char = plr.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                local n = item.Name:lower()
                if n:find("knife") or n:find("faca") then return "murderer" end
                if n:find("gun") or n:find("sheriff") then return "sheriff" end
            end
        end
        -- verificar backpack também
        local bp = plr:FindFirstChild("Backpack")
        if bp then
            for _, item in ipairs(bp:GetChildren()) do
                local n = item.Name:lower()
                if n:find("knife") or n:find("faca") then return "murderer" end
                if n:find("gun") or n:find("sheriff") then return "sheriff" end
            end
        end
    end

    return "unknown"
end

local function GetWeaponName(plr)
    local char = plr.Character
    if not char then return "" end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then return item.Name end
    end
    local bp = plr:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then return item.Name end
        end
    end
    return ""
end

-- ══════════════════════════════════════════
--  DRAWING FACTORY
-- ══════════════════════════════════════════
local function D_Quad(col, filled, thick)
    local q = Drawing.new("Quad")
    q.Color=col; q.Filled=filled; q.Thickness=thick or 1.5
    q.Transparency=1; q.Visible=false; return q
end
local function D_Text(col, sz)
    local t = Drawing.new("Text")
    t.Color=col; t.Size=sz or 12; t.Font=Drawing.Fonts.UI
    t.Outline=true; t.OutlineColor=Color3.new(0,0,0)
    t.Visible=false; return t
end
local function D_Line(col, thick)
    local l = Drawing.new("Line")
    l.Color=col; l.Thickness=thick or 1
    l.Transparency=1; l.Visible=false; return l
end
local function D_Circle()
    local c = Drawing.new("Circle")
    c.Color=Color3.fromRGB(100,180,255); c.Filled=false
    c.Thickness=1.5; c.Transparency=1; c.Visible=false; return c
end

-- ══════════════════════════════════════════
--  ESP DATA — players
-- ══════════════════════════════════════════
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
        _char   = char,
        shadow  = D_Quad(Color3.new(0,0,0),          false, 3),
        box     = D_Quad(Color3.fromRGB(255,255,255), false, 1.5),
        hpBg    = D_Quad(Color3.fromRGB(10,10,10),   true,  1),
        hpFill  = D_Quad(Color3.fromRGB(60,220,80),  true,  1),
        name    = D_Text(Color3.new(1,1,1),           13),
        roleTag = D_Text(Color3.new(1,1,1),           11),
        weapon  = D_Text(Color3.fromRGB(200,200,255), 10),
        tracer  = D_Line(Color3.fromRGB(255,255,255), 1),
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
        Vector3.new(W,H,W),   Vector3.new(-W,H,W),
        Vector3.new(W,H,-W),  Vector3.new(-W,H,-W),
        Vector3.new(W,-H,W),  Vector3.new(-W,-H,W),
        Vector3.new(W,-H,-W), Vector3.new(-W,-H,-W),
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
    return Vector2.new(mnX,mnY), Vector2.new(mxX,mnY),
           Vector2.new(mnX,mxY), Vector2.new(mxX,mxY)
end

-- ══════════════════════════════════════════
--  COIN ESP DATA
-- ══════════════════════════════════════════
local CoinESPData = {}  -- [part] = { dot, label }

local function D_Dot()
    local c = Drawing.new("Circle")
    c.Color=Color3.fromRGB(255,220,50); c.Filled=true
    c.Radius=5; c.Transparency=1; c.Visible=false; return c
end

local function RefreshCoins()
    -- limpar antigos
    for _, d in pairs(CoinESPData) do
        pcall(function() d.dot:Remove(); d.lbl:Remove() end)
    end
    CoinESPData = {}

    if not C.CoinESP then return end

    -- buscar coins/drops no workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if obj:IsA("BasePart") or obj:IsA("Model") then
            if n:find("coin") or n:find("drop") or n:find("shard") or n:find("crate") then
                local dot = D_Dot()
                local lbl = D_Text(Color3.fromRGB(255,220,50), 11)
                dot.Visible = true
                lbl.Visible = true
                CoinESPData[obj] = { dot=dot, lbl=lbl }
            end
        end
    end
end

-- ══════════════════════════════════════════
--  WALLCHECK
-- ══════════════════════════════════════════
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

-- ══════════════════════════════════════════
--  MISC FEATURES
-- ══════════════════════════════════════════
local SpeedConn, BHopConn, NoclipConn, JumpConn = nil,nil,nil,nil
local FlyConn, FlyBV, FlyBG                      = nil,nil,nil
local AutoCollectConn                             = nil

local function SetSpeed(on)
    if SpeedConn then SpeedConn:Disconnect(); SpeedConn=nil end
    if not on then
        local c=LP.Character; if not c then return end
        local h=c:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed=16 end; return
    end
    SpeedConn = RunService.Heartbeat:Connect(function()
        local c=LP.Character; if not c then return end
        local h=c:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed=C.WalkSpeed end
    end)
end

local function SetBHop(on)
    if BHopConn then BHopConn:Disconnect(); BHopConn=nil end
    if not on then return end
    BHopConn = RunService.Heartbeat:Connect(function()
        local c=LP.Character; if not c then return end
        local h=c:FindFirstChildOfClass("Humanoid")
        if h and UserInputService:IsKeyDown(Enum.KeyCode.Space) and h:GetState()==Enum.HumanoidStateType.Landed then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

local function SetNoclip(on)
    if NoclipConn then NoclipConn:Disconnect(); NoclipConn=nil end
    if not on then return end
    NoclipConn = RunService.Stepped:Connect(function()
        local c=LP.Character; if not c then return end
        for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=false end
        end
    end)
end

local function SetInfJump(on)
    if JumpConn then JumpConn:Disconnect(); JumpConn=nil end
    if not on then return end
    JumpConn = UserInputService.JumpRequest:Connect(function()
        local c=LP.Character; if not c then return end
        local h=c:FindFirstChildOfClass("Humanoid")
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

local function SetFly(on)
    if FlyConn then FlyConn:Disconnect(); FlyConn=nil end
    if FlyBV and FlyBV.Parent then FlyBV:Destroy() end
    if FlyBG and FlyBG.Parent then FlyBG:Destroy() end
    FlyBV,FlyBG=nil,nil
    if not on then
        local c=LP.Character; if not c then return end
        local h=c:FindFirstChildOfClass("Humanoid"); if h then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
        return
    end
    local c=LP.Character
    local hrp=c and c:FindFirstChild("HumanoidRootPart")
    local hum=c and c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    FlyBV=Instance.new("BodyVelocity",hrp); FlyBV.Velocity=Vector3.zero; FlyBV.MaxForce=Vector3.new(1e9,1e9,1e9)
    FlyBG=Instance.new("BodyGyro",hrp); FlyBG.MaxTorque=Vector3.new(1e9,1e9,1e9); FlyBG.P=9e4; FlyBG.D=1e3
    FlyConn=RunService.RenderStepped:Connect(function()
        local hrp2=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp2 or not FlyBV then return end
        local cf,vel=Camera.CFrame,Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel=vel+cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel=vel-cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel=vel-cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel=vel+cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel=vel+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel=vel-Vector3.new(0,1,0) end
        if vel.Magnitude>0 then vel=vel.Unit*C.FlySpeed end
        FlyBV.Velocity=vel; FlyBG.CFrame=cf
    end)
end

local function SetAutoCollect(on)
    if AutoCollectConn then AutoCollectConn:Disconnect(); AutoCollectConn=nil end
    if not on then return end
    AutoCollectConn = RunService.Heartbeat:Connect(function()
        local myHrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not myHrp then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local n=obj.Name:lower()
            if (n:find("coin") or n:find("drop") or n:find("shard")) and obj:IsA("BasePart") then
                local dist=(obj.Position-myHrp.Position).Magnitude
                if dist > 3 and dist < 150 then
                    myHrp.CFrame = CFrame.new(obj.Position + Vector3.new(0,3,0))
                    task.wait(0.1)
                    break
                end
            end
        end
    end)
end

-- ══════════════════════════════════════════
--  FOV CIRCLE
-- ══════════════════════════════════════════
local FovCircle = D_Circle()

-- ══════════════════════════════════════════
--  RENDER LOOP
-- ══════════════════════════════════════════
local sc = Vector2.new(0,0)

RunService.RenderStepped:Connect(function()
    sc = Vector2.new(Camera.ViewportSize.X*0.5, Camera.ViewportSize.Y*0.5)

    -- FOV circle
    FovCircle.Position = sc
    FovCircle.Radius   = C.Aim_FOVRadius
    FovCircle.Visible  = C.Aimbot and C.Aim_FOVShow

    local myTeam      = LP.Team
    local aimbotTarget = nil
    local aimbotBestD  = C.Aim_FOVRadius + 1

    -- ── PLAYER ESP + AIMBOT ─────────────────────
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end

        local char  = plr.Character
        local hum   = char and char:FindFirstChildOfClass("Humanoid")
        local alive = hum ~= nil and hum.Health > 0

        if C.ESP then
            if not alive or not char then
                ESP_Hide(plr)
            else
                local role     = GetPlayerRole(plr)
                local roleCol  = ROLE_COLORS[role]

                ESP_Create(plr, char)
                local esp  = ESPData[plr]
                local hrp  = char:FindFirstChild("HumanoidRootPart")
                local dist3D = hrp and math.floor((Camera.CFrame.Position-hrp.Position).Magnitude) or 9999

                local tl,tr,bl,br = GetBox(char)
                if tl then
                    -- box colorida pela role
                    local off=Vector2.new(1,1)
                    esp.shadow.PointA=tl+off; esp.shadow.PointB=tr+off
                    esp.shadow.PointC=br+off; esp.shadow.PointD=bl+off
                    esp.shadow.Visible = C.ESP_Box

                    esp.box.Color  = roleCol
                    esp.box.PointA=tl; esp.box.PointB=tr
                    esp.box.PointC=br; esp.box.PointD=bl
                    esp.box.Visible = C.ESP_Box

                    -- barra de vida
                    if C.ESP_Health then
                        local bW=4; local bX=tl.X-7
                        local pct=math.clamp(hum.Health/hum.MaxHealth,0,1)
                        local top=bl.Y-(bl.Y-tl.Y)*pct
                        local hpCol=pct>.6 and Color3.fromRGB(50,220,70) or pct>.3 and Color3.fromRGB(230,195,40) or Color3.fromRGB(230,50,50)
                        esp.hpBg.PointA=Vector2.new(bX,tl.Y); esp.hpBg.PointB=Vector2.new(bX+bW,tl.Y)
                        esp.hpBg.PointC=Vector2.new(bX+bW,bl.Y); esp.hpBg.PointD=Vector2.new(bX,bl.Y); esp.hpBg.Visible=true
                        esp.hpFill.Color=hpCol
                        esp.hpFill.PointA=Vector2.new(bX,top); esp.hpFill.PointB=Vector2.new(bX+bW,top)
                        esp.hpFill.PointC=Vector2.new(bX+bW,bl.Y); esp.hpFill.PointD=Vector2.new(bX,bl.Y); esp.hpFill.Visible=true
                    else
                        esp.hpBg.Visible=false; esp.hpFill.Visible=false
                    end

                    local cx=(tl.X+tr.X)*0.5

                    -- nome + distância
                    if C.ESP_Name then
                        local tag = plr.DisplayName
                        if C.ESP_Distance then tag=tag.."  ["..dist3D.."m]" end
                        esp.name.Text=tag; esp.name.Position=Vector2.new(cx,tl.Y-16)
                        esp.name.Center=true; esp.name.Visible=true
                    else esp.name.Visible=false end

                    -- role tag
                    if C.ESP_Role then
                        local roleNames={murderer="☠ ASSASSINO",sheriff="⭐ XERIFE",innocent="● INOCENTE",unknown="? DESCONHECIDO"}
                        esp.roleTag.Text=roleNames[role] or role
                        esp.roleTag.Color=roleCol
                        esp.roleTag.Position=Vector2.new(cx,tl.Y-28)
                        esp.roleTag.Center=true; esp.roleTag.Visible=true
                    else esp.roleTag.Visible=false end

                    -- arma
                    if C.ESP_Weapon then
                        local wep=GetWeaponName(plr)
                        if wep ~= "" then
                            esp.weapon.Text="🔪 "..wep
                            esp.weapon.Position=Vector2.new(cx,bl.Y+2)
                            esp.weapon.Center=true; esp.weapon.Visible=true
                        else esp.weapon.Visible=false end
                    else esp.weapon.Visible=false end

                    -- tracer
                    if C.ESP_Tracer then
                        esp.tracer.Color=roleCol
                        esp.tracer.From=Vector2.new(sc.X,Camera.ViewportSize.Y)
                        esp.tracer.To=Vector2.new(cx,bl.Y)
                        esp.tracer.Visible=true
                    else esp.tracer.Visible=false end
                else
                    ESP_Hide(plr)
                end
            end
        else
            ESP_Hide(plr)
        end

        -- ── AIMBOT ───────────────────────────────
        if C.Aimbot and alive and char then
            if C.Aim_TeamCheck and plr.Team == myTeam then continue end

            -- se KnifeOnly, só mira quando você for assassino
            if C.Aim_KnifeOnly then
                local myRole=GetPlayerRole(LP)
                if myRole ~= "murderer" then continue end
            end

            local hrp=char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            local sp,onScreen=Camera:WorldToViewportPoint(hrp.Position)
            if not onScreen or sp.Z<=0 then continue end
            local d2=(Vector2.new(sp.X,sp.Y)-sc).Magnitude
            if d2>C.Aim_FOVRadius then continue end
            if not WallCheck(hrp.Position) then continue end
            if d2<aimbotBestD then aimbotBestD=d2; aimbotTarget=plr end
        end
    end

    -- aplicar aimbot
    if C.Aimbot and aimbotTarget then
        local char=aimbotTarget.Character
        if char then
            local part=char:FindFirstChild(C.Aim_HitPart) or char:FindFirstChild("HumanoidRootPart")
            if part then
                local smooth=math.clamp(C.Aim_Smooth,1,100)/100
                Camera.CFrame=Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position,part.Position),1-smooth+0.01)
            end
        end
    end

    -- ── COIN ESP render ──────────────────────
    if C.CoinESP then
        for obj, d in pairs(CoinESPData) do
            if not obj or not obj.Parent then
                pcall(function() d.dot:Remove(); d.lbl:Remove() end)
                CoinESPData[obj]=nil
            else
                local pos = obj:IsA("BasePart") and obj.Position or (obj:FindFirstChild("HumanoidRootPart") and obj.HumanoidRootPart.Position)
                if pos then
                    local sp,onScreen=Camera:WorldToViewportPoint(pos)
                    if onScreen and sp.Z>0 then
                        d.dot.Position=Vector2.new(sp.X,sp.Y); d.dot.Visible=true
                        local dist=math.floor((Camera.CFrame.Position-pos).Magnitude)
                        d.lbl.Text=obj.Name.." ["..dist.."m]"
                        d.lbl.Position=Vector2.new(sp.X,sp.Y-14); d.lbl.Center=true; d.lbl.Visible=true
                    else
                        d.dot.Visible=false; d.lbl.Visible=false
                    end
                end
            end
        end
    else
        for _, d in pairs(CoinESPData) do
            pcall(function() d.dot.Visible=false; d.lbl.Visible=false end)
        end
    end
end)

-- atualizar coin ESP quando workspace muda
Workspace.DescendantAdded:Connect(function(obj)
    if not C.CoinESP then return end
    local n=obj.Name:lower()
    if (n:find("coin") or n:find("drop") or n:find("shard") or n:find("crate")) and obj:IsA("BasePart") then
        local dot=D_Dot(); local lbl=D_Text(Color3.fromRGB(255,220,50),11)
        dot.Visible=true; lbl.Visible=true
        CoinESPData[obj]={dot=dot,lbl=lbl}
    end
end)
Workspace.DescendantRemoving:Connect(function(obj)
    if CoinESPData[obj] then
        pcall(function() CoinESPData[obj].dot:Remove(); CoinESPData[obj].lbl:Remove() end)
        CoinESPData[obj]=nil
    end
end)

-- cleanup ESP players
Players.PlayerRemoving:Connect(ESP_Remove)
Players.PlayerAdded:Connect(function(p) p.CharacterRemoving:Connect(function() ESP_Hide(p) end) end)
for _,p in ipairs(Players:GetPlayers()) do
    if p~=LP then p.CharacterRemoving:Connect(function() ESP_Hide(p) end) end
end

-- ══════════════════════════════════════════
--  GUI — LINORIA STYLE
-- ══════════════════════════════════════════
local ACCENT  = Color3.fromRGB(100, 180, 255)
local BG      = Color3.fromRGB(25,  25,  30)
local BG2     = Color3.fromRGB(32,  32,  38)
local BG3     = Color3.fromRGB(20,  20,  25)
local TEXT    = Color3.fromRGB(240, 240, 245)
local SUBTEXT = Color3.fromRGB(150, 150, 165)
local BORDER  = Color3.fromRGB(50,  50,  62)

local ok, CoreGui = pcall(function() return game:GetService("CoreGui") end)
local Screen = Instance.new("ScreenGui")
Screen.Name="MM2_AIO"; Screen.ResetOnSpawn=false
Screen.ZIndexBehavior=Enum.ZIndexBehavior.Global
Screen.IgnoreGuiInset=true
Screen.Parent=ok and CoreGui or LP:WaitForChild("PlayerGui")

local Win=Instance.new("Frame",Screen)
Win.Name="Win"; Win.Size=UDim2.fromOffset(285,0)
Win.Position=UDim2.fromOffset(120,80)
Win.BackgroundColor3=BG; Win.BorderSizePixel=0
Win.AutomaticSize=Enum.AutomaticSize.Y
Win.ClipsDescendants=true
Instance.new("UICorner",Win).CornerRadius=UDim.new(0,8)
local wS=Instance.new("UIStroke",Win); wS.Color=BORDER; wS.Thickness=1

-- header
local Header=Instance.new("Frame",Win)
Header.Size=UDim2.new(1,0,0,50); Header.BackgroundColor3=BG3; Header.BorderSizePixel=0

local aLine=Instance.new("Frame",Header)
aLine.Size=UDim2.new(1,0,0,2); aLine.BackgroundColor3=ACCENT; aLine.BorderSizePixel=0

local hT=Instance.new("TextLabel",Header)
hT.Text="Murder Mystery 2"; hT.Size=UDim2.new(1,-80,0,26); hT.Position=UDim2.fromOffset(12,10)
hT.BackgroundTransparency=1; hT.TextColor3=TEXT; hT.TextSize=13; hT.Font=Enum.Font.GothamBold
hT.TextXAlignment=Enum.TextXAlignment.Left

local hS=Instance.new("TextLabel",Header)
hS.Text="AIO Menu  •  Linoria Style"; hS.Size=UDim2.new(1,-80,0,14); hS.Position=UDim2.fromOffset(12,30)
hS.BackgroundTransparency=1; hS.TextColor3=SUBTEXT; hS.TextSize=10; hS.Font=Enum.Font.Gotham
hS.TextXAlignment=Enum.TextXAlignment.Left

local function HBtn(sym,ox,col)
    local b=Instance.new("TextButton",Header)
    b.Size=UDim2.fromOffset(20,20); b.Position=UDim2.new(1,ox,0.5,-10)
    b.BackgroundColor3=col; b.Text=sym; b.TextColor3=TEXT
    b.TextSize=11; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,4); return b
end
local MinBtn  =HBtn("─",-46,Color3.fromRGB(50,50,62))
local CloseBtn=HBtn("✕",-22,Color3.fromRGB(200,60,60))

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

-- scroll content
local Scroll=Instance.new("ScrollingFrame",Win)
Scroll.Size=UDim2.new(1,0,0,0); Scroll.Position=UDim2.fromOffset(0,50)
Scroll.AutomaticSize=Enum.AutomaticSize.Y
Scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
Scroll.BackgroundTransparency=1; Scroll.BorderSizePixel=0
Scroll.ScrollBarThickness=3; Scroll.ScrollBarImageColor3=ACCENT
Scroll.CanvasSize=UDim2.new(0,0,0,0)

local CL=Instance.new("UIListLayout",Scroll); CL.Padding=UDim.new(0,0); CL.SortOrder=Enum.SortOrder.LayoutOrder
Instance.new("UIPadding",Scroll).PaddingBottom=UDim.new(0,8)

-- ── Linoria components ──────────────────────
local SyncFns={}
local sOrder=0
local iOrder=0

local function Section(title)
    sOrder=sOrder+1
    local wrap=Instance.new("Frame",Scroll)
    wrap.Name=title; wrap.Size=UDim2.new(1,0,0,0)
    wrap.AutomaticSize=Enum.AutomaticSize.Y
    wrap.BackgroundTransparency=1; wrap.BorderSizePixel=0; wrap.LayoutOrder=sOrder

    local sH=Instance.new("TextButton",wrap)
    sH.Size=UDim2.new(1,0,0,30); sH.BackgroundColor3=BG3
    sH.BorderSizePixel=0; sH.Text=""; sH.AutoButtonColor=false

    local sl=Instance.new("Frame",sH)
    sl.Size=UDim2.new(0,2,0.55,0); sl.Position=UDim2.new(0,0,0.225,0)
    sl.BackgroundColor3=ACCENT; sl.BorderSizePixel=0

    local sT=Instance.new("TextLabel",sH)
    sT.Text=title; sT.Size=UDim2.new(1,-36,1,0); sT.Position=UDim2.fromOffset(10,0)
    sT.BackgroundTransparency=1; sT.TextColor3=TEXT
    sT.TextSize=11; sT.Font=Enum.Font.GothamBold; sT.TextXAlignment=Enum.TextXAlignment.Left

    local arr=Instance.new("TextLabel",sH)
    arr.Text="▾"; arr.Size=UDim2.fromOffset(18,18); arr.Position=UDim2.new(1,-22,0.5,-9)
    arr.BackgroundTransparency=1; arr.TextColor3=SUBTEXT; arr.TextSize=12; arr.Font=Enum.Font.GothamBold

    local sep=Instance.new("Frame",wrap)
    sep.Size=UDim2.new(1,0,0,1); sep.Position=UDim2.fromOffset(0,30)
    sep.BackgroundColor3=BORDER; sep.BorderSizePixel=0

    local items=Instance.new("Frame",wrap)
    items.Name="Items"; items.Size=UDim2.new(1,0,0,0); items.Position=UDim2.fromOffset(0,31)
    items.AutomaticSize=Enum.AutomaticSize.Y
    items.BackgroundTransparency=1; items.BorderSizePixel=0
    local il=Instance.new("UIListLayout",items); il.Padding=UDim.new(0,1); il.SortOrder=Enum.SortOrder.LayoutOrder

    local collapsed=false
    sH.MouseButton1Click:Connect(function()
        collapsed=not collapsed
        items.Visible=not collapsed; sep.Visible=not collapsed
        arr.Text=collapsed and "▸" or "▾"
        arr.TextColor3=collapsed and ACCENT or SUBTEXT
    end)
    sH.MouseEnter:Connect(function() sH.BackgroundColor3=Color3.fromRGB(26,26,32) end)
    sH.MouseLeave:Connect(function() sH.BackgroundColor3=BG3 end)
    return items
end

local function Toggle(parent,label,init,cb)
    iOrder=iOrder+1
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,32); row.BackgroundColor3=BG2
    row.BorderSizePixel=0; row.LayoutOrder=iOrder

    local hl=Instance.new("Frame",row); hl.Size=UDim2.new(1,0,1,0)
    hl.BackgroundColor3=Color3.new(1,1,1); hl.BackgroundTransparency=1; hl.BorderSizePixel=0

    local lbl=Instance.new("TextLabel",row)
    lbl.Text=label; lbl.Size=UDim2.new(1,-58,1,0); lbl.Position=UDim2.fromOffset(12,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=SUBTEXT
    lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left

    local track=Instance.new("Frame",row)
    track.Size=UDim2.fromOffset(32,16); track.Position=UDim2.new(1,-42,0.5,-8)
    track.BackgroundColor3=Color3.fromRGB(50,50,65); track.BorderSizePixel=0
    Instance.new("UICorner",track).CornerRadius=UDim.new(0,8)

    local dot=Instance.new("Frame",track)
    dot.Size=UDim2.fromOffset(12,12); dot.Position=UDim2.new(0,2,0.5,-6)
    dot.BackgroundColor3=Color3.fromRGB(90,90,110); dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(0,6)

    local on=init or false
    local function Set(val,silent)
        on=val
        if on then
            track.BackgroundColor3=ACCENT; dot.BackgroundColor3=Color3.new(1,1,1)
            dot:TweenPosition(UDim2.new(0,18,0.5,-6),"Out","Quad",0.12,true)
            lbl.TextColor3=TEXT
        else
            track.BackgroundColor3=Color3.fromRGB(50,50,65); dot.BackgroundColor3=Color3.fromRGB(90,90,110)
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
    Set(on,true); return Set
end

local function Slider(parent,label,minV,maxV,def,fmt,cb)
    iOrder=iOrder+1
    local cont=Instance.new("Frame",parent)
    cont.Size=UDim2.new(1,0,0,42); cont.BackgroundColor3=BG2
    cont.BorderSizePixel=0; cont.LayoutOrder=iOrder

    local lbl=Instance.new("TextLabel",cont)
    lbl.Text=label; lbl.Size=UDim2.new(0.65,0,0,17); lbl.Position=UDim2.fromOffset(12,3)
    lbl.BackgroundTransparency=1; lbl.TextColor3=SUBTEXT; lbl.TextSize=10; lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Left

    local vL=Instance.new("TextLabel",cont)
    vL.Size=UDim2.new(0.35,-12,0,17); vL.Position=UDim2.new(0.65,0,0,3)
    vL.BackgroundTransparency=1; vL.TextColor3=ACCENT; vL.TextSize=10; vL.Font=Enum.Font.GothamBold
    vL.TextXAlignment=Enum.TextXAlignment.Right

    local tBg=Instance.new("Frame",cont)
    tBg.Size=UDim2.new(1,-24,0,4); tBg.Position=UDim2.new(0,12,0,29)
    tBg.BackgroundColor3=Color3.fromRGB(45,45,58); tBg.BorderSizePixel=0
    Instance.new("UICorner",tBg).CornerRadius=UDim.new(0,2)

    local fill=Instance.new("Frame",tBg)
    fill.BackgroundColor3=ACCENT; fill.BorderSizePixel=0; fill.Size=UDim2.new(0,0,1,0)
    Instance.new("UICorner",fill).CornerRadius=UDim.new(0,2)

    local knob=Instance.new("Frame",fill)
    knob.Size=UDim2.fromOffset(10,10); knob.Position=UDim2.new(1,-5,0.5,-5)
    knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; knob.ZIndex=3
    Instance.new("UICorner",knob).CornerRadius=UDim.new(0,5)

    local function SV(v,silent)
        v=math.clamp(math.floor(v+0.5),minV,maxV)
        fill.Size=UDim2.new((v-minV)/(maxV-minV),0,1,0)
        vL.Text=string.format(fmt or "%g",v)
        if not silent and cb then cb(v) end
    end
    SV(def,true)
    local drag=false
    local hb=Instance.new("TextButton",cont)
    hb.Size=UDim2.new(1,0,0,14); hb.Position=UDim2.new(0,0,0,26)
    hb.BackgroundTransparency=1; hb.Text=""; hb.ZIndex=5
    hb.MouseButton1Down:Connect(function() drag=true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    RunService.RenderStepped:Connect(function()
        if not drag then return end
        local mx=UserInputService:GetMouseLocation().X
        SV(minV+math.clamp((mx-tBg.AbsolutePosition.X)/tBg.AbsoluteSize.X,0,1)*(maxV-minV))
    end)
end

local function Divider(parent)
    iOrder=iOrder+1
    local d=Instance.new("Frame",parent)
    d.Size=UDim2.new(1,0,0,1); d.BackgroundColor3=BORDER
    d.BorderSizePixel=0; d.LayoutOrder=iOrder
end

local function Button(parent,label,cb)
    iOrder=iOrder+1
    local btn=Instance.new("TextButton",parent)
    btn.Size=UDim2.new(1,0,0,30); btn.BackgroundColor3=BG2
    btn.Text=""; btn.BorderSizePixel=0; btn.LayoutOrder=iOrder
    local lbl=Instance.new("TextLabel",btn)
    lbl.Text="▶  "..label; lbl.Size=UDim2.new(1,-12,1,0); lbl.Position=UDim2.fromOffset(12,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=ACCENT
    lbl.TextSize=11; lbl.Font=Enum.Font.GothamBold; lbl.TextXAlignment=Enum.TextXAlignment.Left
    btn.MouseButton1Click:Connect(cb)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3=Color3.fromRGB(36,36,46) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3=BG2 end)
end

local function KbRow(parent,label,cfgKey)
    iOrder=iOrder+1
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,30); row.BackgroundColor3=BG2
    row.BorderSizePixel=0; row.LayoutOrder=iOrder

    local lbl=Instance.new("TextLabel",row)
    lbl.Text=label; lbl.Size=UDim2.new(1,-108,1,0); lbl.Position=UDim2.fromOffset(12,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=SUBTEXT
    lbl.TextSize=11; lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left

    local kb=Instance.new("TextButton",row)
    kb.Size=UDim2.fromOffset(90,20); kb.Position=UDim2.new(1,-96,0.5,-10)
    kb.BackgroundColor3=BG3; kb.BorderSizePixel=0
    kb.TextSize=10; kb.Font=Enum.Font.GothamBold; kb.TextColor3=ACCENT
    Instance.new("UICorner",kb).CornerRadius=UDim.new(0,4)
    local ks=Instance.new("UIStroke",kb); ks.Color=BORDER; ks.Thickness=1

    local listening=false
    local function Refresh() kb.Text="[ "..(C[cfgKey] and C[cfgKey].Name or "?").." ]" end
    Refresh()

    kb.MouseButton1Click:Connect(function()
        if listening then listening=false; Refresh(); kb.BackgroundColor3=BG3; ks.Color=BORDER
        else listening=true; kb.Text="..."; kb.BackgroundColor3=Color3.fromRGB(20,40,65); ks.Color=ACCENT end
    end)
    UserInputService.InputBegan:Connect(function(inp)
        if not listening then return end
        if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
        if inp.KeyCode==Enum.KeyCode.Escape then
            listening=false; Refresh(); kb.BackgroundColor3=BG3; ks.Color=BORDER
        else
            C[cfgKey]=inp.KeyCode; listening=false; Refresh(); kb.BackgroundColor3=BG3; ks.Color=BORDER
        end
    end)
end

-- ══════════════════════════════════════════
--  MONTAR SEÇÕES
-- ══════════════════════════════════════════

-- ESP
local sESP=Section("ESP")
SyncFns["ESP"]=Toggle(sESP,"ESP  (Caixa + Vida + Nick + Role)",false,function(on)
    C.ESP=on
    if not on then for _,p in ipairs(Players:GetPlayers()) do ESP_Hide(p) end end
end)
Toggle(sESP,"Caixa  (colorida pela role)",true,function(on) C.ESP_Box=on end)
Toggle(sESP,"Barra de Vida",true,function(on) C.ESP_Health=on end)
Toggle(sESP,"Nome + Distância",true,function(on) C.ESP_Name=on; C.ESP_Distance=on end)
Toggle(sESP,"Role Tag  (☠ Assassino / ⭐ Xerife)",true,function(on) C.ESP_Role=on end)
Toggle(sESP,"Arma Equipada",true,function(on) C.ESP_Weapon=on end)
Toggle(sESP,"Tracer  (linha dos pés)",false,function(on) C.ESP_Tracer=on end)

-- COINS
local sCoins=Section("COINS & DROPS")
SyncFns["CoinESP"]=Toggle(sCoins,"Coin ESP  (ver moedas/drops no chão)",false,function(on)
    C.CoinESP=on; RefreshCoins()
end)
SyncFns["AutoCollect"]=Toggle(sCoins,"Auto Collect  (coleta automático)",false,function(on)
    C.AutoCollect=on; SetAutoCollect(on)
end)
Button(sCoins,"Refresh Coins  (atualizar lista)", RefreshCoins)

-- AIMBOT
local sAim=Section("AIMBOT")
SyncFns["Aimbot"]=Toggle(sAim,"Aimbot  (WallCheck ativo)",false,function(on) C.Aimbot=on end)
Toggle(sAim,"Mostrar Círculo FOV",true,function(on) C.Aim_FOVShow=on end)
Toggle(sAim,"Só quando Assassino  (Knife Only)",true,function(on) C.Aim_KnifeOnly=on end)
Toggle(sAim,"Team Check",false,function(on) C.Aim_TeamCheck=on end)
Divider(sAim)
Slider(sAim,"Raio do FOV",30,500,120,"%g px",function(v) C.Aim_FOVRadius=v end)
Slider(sAim,"Suavização  (Smooth)",1,95,10,"%g",function(v) C.Aim_Smooth=v end)

-- MISC
local sMisc=Section("MISC")
SyncFns["Speed"]=Toggle(sMisc,"Speed Hack",false,function(on) C.Speed=on; SetSpeed(on) end)
Slider(sMisc,"Walk Speed",16,350,60,"%g",function(v) C.WalkSpeed=v end)
Divider(sMisc)
SyncFns["Fly"]=Toggle(sMisc,"Fly  (WASD + Space/Shift)",false,function(on) C.Fly=on; SetFly(on) end)
Slider(sMisc,"Velocidade de Voo",10,300,50,"%g",function(v) C.FlySpeed=v end)
Divider(sMisc)
SyncFns["BHop"]=Toggle(sMisc,"Bunny Hop  (segure SPACE)",false,function(on) C.BHop=on; SetBHop(on) end)
SyncFns["Noclip"]=Toggle(sMisc,"Noclip  (atravessa paredes)",false,function(on) C.Noclip=on; SetNoclip(on) end)
SyncFns["InfJump"]=Toggle(sMisc,"Infinite Jump",false,function(on) C.InfJump=on; SetInfJump(on) end)

-- KEYBINDS
local sKeys=Section("KEYBINDS")
local kbList={
    {"Abrir/Fechar Menu","KB_Menu"},
    {"ESP",             "KB_ESP"},
    {"Coin ESP",        "KB_CoinESP"},
    {"Aimbot",          "KB_Aimbot"},
    {"Speed Hack",      "KB_Speed"},
    {"Fly",             "KB_Fly"},
    {"Noclip",          "KB_Noclip"},
    {"Infinite Jump",   "KB_InfJump"},
}
for _,kb in ipairs(kbList) do KbRow(sKeys,kb[1],kb[2]) end

-- ══════════════════════════════════════════
--  INPUT GLOBAL
-- ══════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input,gp)
    if input.UserInputType~=Enum.UserInputType.Keyboard then return end
    if gp then return end
    local kc=input.KeyCode
    if kc==C.KB_Menu then Screen.Enabled=not Screen.Enabled; return end

    local map={
        {C.KB_ESP,        "ESP",        "ESP",        nil},
        {C.KB_CoinESP,    "CoinESP",    "CoinESP",    function(v) RefreshCoins() end},
        {C.KB_Aimbot,     "Aimbot",     "Aimbot",     nil},
        {C.KB_Speed,      "Speed",      "Speed",      SetSpeed},
        {C.KB_Fly,        "Fly",        "Fly",        SetFly},
        {C.KB_Noclip,     "Noclip",     "Noclip",     SetNoclip},
        {C.KB_InfJump,    "InfJump",    "InfJump",    SetInfJump},
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
    if minimized then Win.Size=UDim2.fromOffset(285,50) end
    MinBtn.Text=minimized and "□" or "─"
end)

CloseBtn.MouseButton1Click:Connect(function()
    pcall(function()
        for _,p in ipairs(Players:GetPlayers()) do ESP_Remove(p) end
        for _,d in pairs(CoinESPData) do pcall(function() d.dot:Remove(); d.lbl:Remove() end) end
        pcall(function() FovCircle:Remove() end)
        SetSpeed(false); SetFly(false); SetNoclip(false); SetInfJump(false); SetBHop(false); SetAutoCollect(false)
        Screen:Destroy()
    end)
end)

print("[MM2 AIO] Carregado! INSERT para abrir/fechar.")
print("  Legenda ESP: ☠ Vermelho = Assassino | ⭐ Azul = Xerife | ● Verde = Inocente")
