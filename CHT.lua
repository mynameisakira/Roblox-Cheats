-- ╔══════════════════════════════════════════════════╗
-- ║         ROBLOX LOCAL SCRIPT — AIO MENU v2        ║
-- ║   ESP | Aimbot FOV | Speed | Keybinds            ║
-- ╚══════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ══════════════════════════════════════════════════════
--  ESTADO GLOBAL
-- ══════════════════════════════════════════════════════
local State = {
    ESP       = false,
    Aimbot    = false,
    Speed     = false,
    Minimized = false,

    FOVRadius  = 120,
    FOVVisible = true,
    TeamCheck  = true,
    WalkSpeed  = 60,

    KB_ESP    = Enum.KeyCode.T,
    KB_Aimbot = Enum.KeyCode.G,
    KB_Speed  = Enum.KeyCode.Y,
    KB_Menu   = Enum.KeyCode.Insert,

    ESPObjects      = {},
    SpeedConnection = nil,
    FOVCircle       = nil,
    ToggleFns       = {},
}

-- ══════════════════════════════════════════════════════
--  DRAWING HELPERS
-- ══════════════════════════════════════════════════════
local function newText(color, size)
    local t = Drawing.new("Text")
    t.Color        = color or Color3.fromRGB(255,255,255)
    t.Size         = size or 13
    t.Font         = Drawing.Fonts.UI
    t.Outline      = true
    t.OutlineColor = Color3.fromRGB(0,0,0)
    t.Visible      = false
    return t
end

local function newQuad(color, filled, thickness)
    local q = Drawing.new("Quad")
    q.Color        = color or Color3.fromRGB(255,50,50)
    q.Filled       = filled or false
    q.Thickness    = thickness or 1.5
    q.Transparency = 1
    q.Visible      = false
    return q
end

-- ══════════════════════════════════════════════════════
--  ESP — criar / remover por player
-- ══════════════════════════════════════════════════════
local function createESP(plr)
    if State.ESPObjects[plr] then return end
    State.ESPObjects[plr] = {
        boxShadow = newQuad(Color3.fromRGB(0,0,0),        false, 3),
        box       = newQuad(Color3.fromRGB(255,50,50),    false, 1.5),
        healthBg  = newQuad(Color3.fromRGB(20,20,20),     true,  1),
        healthBar = newQuad(Color3.fromRGB(50,230,80),    true,  1),
        nameLbl   = newText(Color3.fromRGB(255,255,255),  13),
        hpLbl     = newText(Color3.fromRGB(180,255,180),  11),
    }
end

local function removeESP(plr)
    local obj = State.ESPObjects[plr]
    if not obj then return end
    for _, d in pairs(obj) do
        pcall(function() d:Remove() end)
    end
    State.ESPObjects[plr] = nil
end

-- Converte bounding box 3D do personagem → 4 cantos 2D na tela
local function getCharBox(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end

    local pos  = hrp.Position
    local halfH, halfW = 3.0, 1.5

    local corners3D = {
        pos + Vector3.new( halfW,  halfH,  halfW),
        pos + Vector3.new(-halfW,  halfH,  halfW),
        pos + Vector3.new( halfW,  halfH, -halfW),
        pos + Vector3.new(-halfW,  halfH, -halfW),
        pos + Vector3.new( halfW, -halfH,  halfW),
        pos + Vector3.new(-halfW, -halfH,  halfW),
        pos + Vector3.new( halfW, -halfH, -halfW),
        pos + Vector3.new(-halfW, -halfH, -halfW),
    }

    local minX, minY = math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge

    for _, c in ipairs(corners3D) do
        local sp, _ = Camera:WorldToViewportPoint(c)
        if sp.Z < 0 then return nil end
        if sp.X < minX then minX = sp.X end
        if sp.Y < minY then minY = sp.Y end
        if sp.X > maxX then maxX = sp.X end
        if sp.Y > maxY then maxY = sp.Y end
    end

    local vp = Camera.ViewportSize
    if maxX < 0 or minX > vp.X or maxY < 0 or minY > vp.Y then return nil end

    return Vector2.new(minX, minY), Vector2.new(maxX, minY),
           Vector2.new(minX, maxY), Vector2.new(maxX, maxY)
end

-- ══════════════════════════════════════════════════════
--  WALLCHECK
-- ══════════════════════════════════════════════════════
local function hasWall(targetPos)
    local myChar = LocalPlayer.Character
    local origin = Camera.CFrame.Position

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excl = {Camera}
    if myChar then table.insert(excl, myChar) end
    params.FilterDescendantsInstances = excl

    local result = Workspace:Raycast(origin, targetPos - origin, params)
    if not result then return false end

    -- Se bateu em algo, verifica se é um personagem de player
    local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
    if hitModel then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character == hitModel then
                return false -- bateu no alvo diretamente → sem parede
            end
        end
    end
    return true -- bateu em obstáculo → há parede
end

-- ══════════════════════════════════════════════════════
--  SPEED
-- ══════════════════════════════════════════════════════
local function applySpeed(on)
    if State.SpeedConnection then
        State.SpeedConnection:Disconnect()
        State.SpeedConnection = nil
    end
    if not on then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
        return
    end
    State.SpeedConnection = RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = State.WalkSpeed end
        end
    end)
end

-- ══════════════════════════════════════════════════════
--  RENDER LOOP — ESP + Aimbot
-- ══════════════════════════════════════════════════════
local screenCenter = Vector2.new(0, 0)

RunService.RenderStepped:Connect(function()
    screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    if State.FOVCircle then
        State.FOVCircle.Position = screenCenter
        State.FOVCircle.Radius   = State.FOVRadius
        State.FOVCircle.Visible  = State.FOVVisible and State.Aimbot
    end

    local myTeam = LocalPlayer.Team
    local aimbotTarget, aimbotClosest = nil, State.FOVRadius + 1

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local char = plr.Character
        if not char then continue end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            -- morto: esconder ESP
            local obj = State.ESPObjects[plr]
            if obj then for _, d in pairs(obj) do pcall(function() d.Visible = false end) end end
            continue
        end

        -- ── ESP ──────────────────────────────────────
        if State.ESP then
            if not State.ESPObjects[plr] then createESP(plr) end
            local obj = State.ESPObjects[plr]

            local tl, tr, bl, br = getCharBox(char)
            if tl then
                -- Sombra
                obj.boxShadow.PointA = tl + Vector2.new(1,1)
                obj.boxShadow.PointB = tr + Vector2.new(1,1)
                obj.boxShadow.PointC = br + Vector2.new(1,1)
                obj.boxShadow.PointD = bl + Vector2.new(1,1)
                obj.boxShadow.Visible = true

                -- Caixa
                obj.box.PointA  = tl
                obj.box.PointB  = tr
                obj.box.PointC  = br
                obj.box.PointD  = bl
                obj.box.Visible = true

                -- Barra de vida (lado esquerdo)
                local boxH  = bl.Y - tl.Y
                local barW  = 4
                local barX  = tl.X - barW - 3
                local hpPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)

                obj.healthBg.PointA = Vector2.new(barX,       tl.Y)
                obj.healthBg.PointB = Vector2.new(barX+barW,  tl.Y)
                obj.healthBg.PointC = Vector2.new(barX+barW,  bl.Y)
                obj.healthBg.PointD = Vector2.new(barX,       bl.Y)
                obj.healthBg.Visible = true

                local hpTop = bl.Y - boxH * hpPct
                local hpColor
                if hpPct > 0.6 then
                    hpColor = Color3.fromRGB(50,230,80)
                elseif hpPct > 0.3 then
                    hpColor = Color3.fromRGB(230,200,50)
                else
                    hpColor = Color3.fromRGB(230,50,50)
                end
                obj.healthBar.Color  = hpColor
                obj.healthBar.PointA = Vector2.new(barX,      hpTop)
                obj.healthBar.PointB = Vector2.new(barX+barW, hpTop)
                obj.healthBar.PointC = Vector2.new(barX+barW, bl.Y)
                obj.healthBar.PointD = Vector2.new(barX,      bl.Y)
                obj.healthBar.Visible = true

                -- Nome (acima)
                local cx = (tl.X + tr.X) / 2
                obj.nameLbl.Text     = plr.DisplayName
                obj.nameLbl.Position = Vector2.new(cx, tl.Y - 16)
                obj.nameLbl.Center   = true
                obj.nameLbl.Visible  = true

                -- HP numérico (abaixo)
                obj.hpLbl.Text     = math.floor(hum.Health).." HP"
                obj.hpLbl.Position = Vector2.new(cx, bl.Y + 2)
                obj.hpLbl.Center   = true
                obj.hpLbl.Visible  = true
            else
                for _, d in pairs(obj) do pcall(function() d.Visible = false end) end
            end
        else
            -- ESP desligado: garantir que fique invisível
            local obj = State.ESPObjects[plr]
            if obj then for _, d in pairs(obj) do pcall(function() d.Visible = false end) end end
        end

        -- ── Aimbot ───────────────────────────────────
        if State.Aimbot then
            if State.TeamCheck and plr.Team == myTeam then continue end

            local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if not onScreen or sp.Z < 0 then continue end

            local dist2D = Vector2.new(sp.X, sp.Y) - screenCenter
            if dist2D.Magnitude > State.FOVRadius then continue end

            if hasWall(hrp.Position) then continue end

            if dist2D.Magnitude < aimbotClosest then
                aimbotClosest = dist2D.Magnitude
                aimbotTarget  = plr
            end
        end
    end

    -- Aplicar aimbot
    if State.Aimbot and aimbotTarget then
        local char = aimbotTarget.Character
        local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
        if head then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
        end
    end
end)

-- ESP: remover ao sair/respawnar
Players.PlayerRemoving:Connect(function(plr) removeESP(plr) end)

local function hookCharAdded(plr)
    plr.CharacterAdded:Connect(function()
        removeESP(plr)
        task.wait(1)
        if State.ESP then createESP(plr) end
    end)
end
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then hookCharAdded(plr) end
end
Players.PlayerAdded:Connect(function(plr) hookCharAdded(plr) end)

-- ══════════════════════════════════════════════════════
--  GUI PRINCIPAL
-- ══════════════════════════════════════════════════════
local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
local guiParent = ok and coreGui or LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "AIO_Menu_v2"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = guiParent

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name             = "MainFrame"
MainFrame.Size             = UDim2.new(0, 320, 0, 0)
MainFrame.Position         = UDim2.new(0.5, -160, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
MainFrame.BorderSizePixel  = 0
MainFrame.AutomaticSize    = Enum.AutomaticSize.Y
MainFrame.ClipsDescendants = false

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local ms = Instance.new("UIStroke", MainFrame)
ms.Color     = Color3.fromRGB(200,40,40)
ms.Thickness = 1.5

-- TitleBar
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Size            = UDim2.new(1, 0, 0, 38)
TitleBar.BackgroundColor3 = Color3.fromRGB(185, 28, 28)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex          = 5
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local tbfix = Instance.new("Frame", TitleBar)
tbfix.Size             = UDim2.new(1,0,0,12)
tbfix.Position         = UDim2.new(0,0,1,-12)
tbfix.BackgroundColor3 = Color3.fromRGB(185,28,28)
tbfix.BorderSizePixel  = 0
tbfix.ZIndex           = 5

local TitleLbl = Instance.new("TextLabel", TitleBar)
TitleLbl.Text           = "⚡  AIO Menu  v2"
TitleLbl.Size           = UDim2.new(1,-82,1,0)
TitleLbl.Position       = UDim2.new(0,12,0,0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextColor3     = Color3.fromRGB(255,255,255)
TitleLbl.TextSize       = 14
TitleLbl.Font           = Enum.Font.GothamBold
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.ZIndex         = 6

local function topBtn(sym, ox, bg)
    local b = Instance.new("TextButton", TitleBar)
    b.Size            = UDim2.new(0,22,0,22)
    b.Position        = UDim2.new(1,ox,0.5,-11)
    b.BackgroundColor3 = bg
    b.Text            = sym
    b.TextColor3      = Color3.fromRGB(255,255,255)
    b.TextSize        = 12
    b.Font            = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.ZIndex          = 7
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
    return b
end
local MinBtn   = topBtn("─", -52, Color3.fromRGB(55,55,68))
local CloseBtn = topBtn("✕", -26, Color3.fromRGB(165,32,32))

-- TabBar
local TabBar = Instance.new("Frame", MainFrame)
TabBar.Size             = UDim2.new(1,0,0,34)
TabBar.Position         = UDim2.new(0,0,0,38)
TabBar.BackgroundColor3 = Color3.fromRGB(18,18,26)
TabBar.BorderSizePixel  = 0
TabBar.ZIndex           = 4

local tabLayout = Instance.new("UIListLayout", TabBar)
tabLayout.FillDirection       = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
tabLayout.Padding             = UDim.new(0,4)

local tabPages   = {}
local tabBtns    = {}
local activeTab  = nil

local function makeTab(name, icon)
    local btn = Instance.new("TextButton", TabBar)
    btn.Size            = UDim2.new(0,66,0,26)
    btn.BackgroundColor3 = Color3.fromRGB(28,28,38)
    btn.Text            = icon.." "..name
    btn.TextColor3      = Color3.fromRGB(165,165,180)
    btn.TextSize        = 11
    btn.Font            = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.ZIndex          = 5
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local page = Instance.new("Frame", MainFrame)
    page.Name           = name.."Page"
    page.Size           = UDim2.new(1,0,0,0)
    page.Position       = UDim2.new(0,0,0,72)
    page.BackgroundTransparency = 1
    page.AutomaticSize  = Enum.AutomaticSize.Y
    page.Visible        = false

    local ll = Instance.new("UIListLayout", page)
    ll.Padding   = UDim.new(0,6)
    ll.SortOrder = Enum.SortOrder.LayoutOrder

    local pp = Instance.new("UIPadding", page)
    pp.PaddingLeft   = UDim.new(0,10)
    pp.PaddingRight  = UDim.new(0,10)
    pp.PaddingTop    = UDim.new(0,8)
    pp.PaddingBottom = UDim.new(0,10)

    tabPages[name] = page
    tabBtns[name]  = btn

    btn.MouseButton1Click:Connect(function()
        if activeTab then
            tabPages[activeTab].Visible        = false
            tabBtns[activeTab].BackgroundColor3 = Color3.fromRGB(28,28,38)
            tabBtns[activeTab].TextColor3       = Color3.fromRGB(165,165,180)
        end
        activeTab              = name
        page.Visible           = true
        btn.BackgroundColor3   = Color3.fromRGB(200,35,35)
        btn.TextColor3         = Color3.fromRGB(255,255,255)
    end)

    return page
end

local pgESP      = makeTab("ESP",    "👁")
local pgAimbot   = makeTab("Aimbot", "🎯")
local pgSpeed    = makeTab("Speed",  "⚡")
local pgKeybinds = makeTab("Teclas", "⌨")

-- Ativa ESP por padrão
tabBtns["ESP"].BackgroundColor3 = Color3.fromRGB(200,35,35)
tabBtns["ESP"].TextColor3       = Color3.fromRGB(255,255,255)
tabPages["ESP"].Visible         = true
activeTab = "ESP"

-- ══════════════════════════════════════════════════════
--  COMPONENTES
-- ══════════════════════════════════════════════════════
local function makeSection(parent, text, order)
    local l = Instance.new("TextLabel", parent)
    l.Text        = text
    l.Size        = UDim2.new(1,0,0,18)
    l.BackgroundTransparency = 1
    l.TextColor3  = Color3.fromRGB(200,50,50)
    l.TextSize    = 11
    l.Font        = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
end

local function makeToggle(parent, label, order, init, onChange)
    local row = Instance.new("Frame", parent)
    row.Size            = UDim2.new(1,0,0,36)
    row.BackgroundColor3 = Color3.fromRGB(22,22,30)
    row.BorderSizePixel = 0
    row.LayoutOrder     = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)

    local lbl = Instance.new("TextLabel", row)
    lbl.Text        = label
    lbl.Size        = UDim2.new(1,-58,1,0)
    lbl.Position    = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3  = Color3.fromRGB(215,215,225)
    lbl.TextSize    = 12
    lbl.Font        = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", row)
    track.Size            = UDim2.new(0,40,0,20)
    track.Position        = UDim2.new(1,-48,0.5,-10)
    track.BackgroundColor3 = Color3.fromRGB(45,45,58)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0,10)

    local thumb = Instance.new("Frame", track)
    thumb.Size            = UDim2.new(0,16,0,16)
    thumb.Position        = UDim2.new(0,2,0.5,-8)
    thumb.BackgroundColor3 = Color3.fromRGB(120,120,135)
    thumb.BorderSizePixel = 0
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(0,8)

    local enabled = init or false
    local function set(val, silent)
        enabled = val
        if enabled then
            track.BackgroundColor3 = Color3.fromRGB(200,35,35)
            thumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
            thumb:TweenPosition(UDim2.new(0,22,0.5,-8),"Out","Quad",0.14,true)
        else
            track.BackgroundColor3 = Color3.fromRGB(45,45,58)
            thumb.BackgroundColor3 = Color3.fromRGB(120,120,135)
            thumb:TweenPosition(UDim2.new(0,2,0.5,-8),"Out","Quad",0.14,true)
        end
        if not silent and onChange then onChange(enabled) end
    end

    local cb = Instance.new("TextButton", row)
    cb.Size            = UDim2.new(1,0,1,0)
    cb.BackgroundTransparency = 1
    cb.Text            = ""
    cb.MouseButton1Click:Connect(function() set(not enabled) end)

    set(enabled, true)
    return set
end

local function makeSlider(parent, label, order, minV, maxV, defV, fmt, onChange)
    local cont = Instance.new("Frame", parent)
    cont.Size            = UDim2.new(1,0,0,52)
    cont.BackgroundColor3 = Color3.fromRGB(22,22,30)
    cont.BorderSizePixel = 0
    cont.LayoutOrder     = order
    Instance.new("UICorner", cont).CornerRadius = UDim.new(0,7)

    local lbl = Instance.new("TextLabel", cont)
    lbl.Size        = UDim2.new(1,-12,0,20)
    lbl.Position    = UDim2.new(0,10,0,4)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3  = Color3.fromRGB(215,215,225)
    lbl.TextSize    = 12
    lbl.Font        = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", cont)
    valLbl.Size        = UDim2.new(0,70,0,20)
    valLbl.Position    = UDim2.new(1,-78,0,4)
    valLbl.BackgroundTransparency = 1
    valLbl.TextColor3  = Color3.fromRGB(200,50,50)
    valLbl.TextSize    = 12
    valLbl.Font        = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", cont)
    track.Size            = UDim2.new(1,-20,0,5)
    track.Position        = UDim2.new(0,10,0,36)
    track.BackgroundColor3 = Color3.fromRGB(45,45,58)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0,3)

    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = Color3.fromRGB(200,40,40)
    fill.BorderSizePixel  = 0
    fill.Size             = UDim2.new(0,0,1,0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,3)

    local knob = Instance.new("Frame", fill)
    knob.Size            = UDim2.new(0,13,0,13)
    knob.Position        = UDim2.new(1,-6,0.5,-6)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 3
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0,7)

    local current = defV
    local function setValue(v, silent)
        v = math.clamp(math.floor(v + 0.5), minV, maxV)
        current = v
        local pct = (v - minV) / (maxV - minV)
        fill.Size   = UDim2.new(pct, 0, 1, 0)
        lbl.Text    = label
        valLbl.Text = string.format(fmt or "%g", v)
        if not silent and onChange then onChange(v) end
    end
    setValue(defV, true)

    local dragging = false
    local da = Instance.new("TextButton", cont)
    da.Size            = UDim2.new(1,0,0,24)
    da.Position        = UDim2.new(0,0,0,27)
    da.BackgroundTransparency = 1
    da.Text            = ""
    da.ZIndex          = 5
    da.MouseButton1Down:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    RunService.RenderStepped:Connect(function()
        if not dragging then return end
        local mX  = UserInputService:GetMouseLocation().X
        local tAbs = track.AbsolutePosition.X
        local tW   = track.AbsoluteSize.X
        setValue(minV + math.clamp((mX-tAbs)/tW,0,1)*(maxV-minV))
    end)

    return setValue
end

-- ══════════════════════════════════════════════════════
--  ABA ESP
-- ══════════════════════════════════════════════════════
makeSection(pgESP, "  OPÇÕES DE ESP", 1)

State.ToggleFns["ESP"] = makeToggle(pgESP, "ESP  (Caixas + Vida + Nome)", 2, false, function(on)
    State.ESP = on
    if not on then
        for _, obj in pairs(State.ESPObjects) do
            for _, d in pairs(obj) do pcall(function() d.Visible = false end) end
        end
    end
end)

-- ══════════════════════════════════════════════════════
--  ABA AIMBOT
-- ══════════════════════════════════════════════════════
makeSection(pgAimbot, "  OPÇÕES DE AIMBOT", 1)

State.ToggleFns["Aimbot"] = makeToggle(pgAimbot, "Aimbot  (WallCheck ativo)", 2, false, function(on)
    State.Aimbot = on
end)

makeToggle(pgAimbot, "Mostrar Círculo FOV", 3, true, function(on)
    State.FOVVisible = on
end)

makeToggle(pgAimbot, "Team Check  (ignorar aliados)", 4, true, function(on)
    State.TeamCheck = on
end)

makeSection(pgAimbot, "  CONFIGURAÇÃO DO FOV", 5)

makeSlider(pgAimbot, "Raio do FOV", 6, 30, 450, 120, "%g px", function(v)
    State.FOVRadius = v
end)

-- ══════════════════════════════════════════════════════
--  ABA SPEED
-- ══════════════════════════════════════════════════════
makeSection(pgSpeed, "  OPÇÕES DE SPEED", 1)

State.ToggleFns["Speed"] = makeToggle(pgSpeed, "Speed Hack", 2, false, function(on)
    State.Speed = on
    applySpeed(on)
end)

makeSection(pgSpeed, "  CONFIGURAÇÃO", 3)

makeSlider(pgSpeed, "Walk Speed", 4, 16, 300, 60, "%g", function(v)
    State.WalkSpeed = v
end)

-- ══════════════════════════════════════════════════════
--  ABA KEYBINDS
-- ══════════════════════════════════════════════════════
makeSection(pgKeybinds, "  CONFIGURAR TECLAS", 1)

local kbData = {
    { name="ESP",    label="ESP",              key="KB_ESP"    },
    { name="Aimbot", label="Aimbot",            key="KB_Aimbot" },
    { name="Speed",  label="Speed Hack",        key="KB_Speed"  },
    { name="Menu",   label="Abrir/Fechar Menu", key="KB_Menu"   },
}

local kbBtnRefs   = {}
local listeningFor = nil

local function makeKBRow(parent, data, order)
    local row = Instance.new("Frame", parent)
    row.Size            = UDim2.new(1,0,0,36)
    row.BackgroundColor3 = Color3.fromRGB(22,22,30)
    row.BorderSizePixel = 0
    row.LayoutOrder     = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)

    local lbl = Instance.new("TextLabel", row)
    lbl.Text        = data.label
    lbl.Size        = UDim2.new(1,-110,1,0)
    lbl.Position    = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3  = Color3.fromRGB(215,215,225)
    lbl.TextSize    = 12
    lbl.Font        = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", row)
    btn.Size            = UDim2.new(0,90,0,24)
    btn.Position        = UDim2.new(1,-98,0.5,-12)
    btn.BackgroundColor3 = Color3.fromRGB(32,32,45)
    btn.TextColor3      = Color3.fromRGB(200,50,50)
    btn.TextSize        = 11
    btn.Font            = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local function refreshLbl()
        btn.Text = "[ "..State[data.key].Name.." ]"
    end
    refreshLbl()

    btn.MouseButton1Click:Connect(function()
        if listeningFor == data.name then
            listeningFor         = nil
            btn.BackgroundColor3 = Color3.fromRGB(32,32,45)
            refreshLbl()
        else
            -- cancelar qualquer outro
            for n, b in pairs(kbBtnRefs) do
                b.BackgroundColor3 = Color3.fromRGB(32,32,45)
                for _, d2 in ipairs(kbData) do
                    if d2.name == n then b.Text = "[ "..State[d2.key].Name.." ]" break end
                end
            end
            listeningFor         = data.name
            btn.Text             = "  pressione...  "
            btn.BackgroundColor3 = Color3.fromRGB(155,28,28)
        end
    end)

    kbBtnRefs[data.name] = btn
    return refreshLbl
end

local kbRefresh = {}
for i, d in ipairs(kbData) do
    kbRefresh[d.name] = makeKBRow(pgKeybinds, d, i+1)
end

local infoLbl = Instance.new("TextLabel", pgKeybinds)
infoLbl.Text        = "Clique no botão → pressione a tecla desejada\nESC cancela"
infoLbl.Size        = UDim2.new(1,0,0,32)
infoLbl.BackgroundTransparency = 1
infoLbl.TextColor3  = Color3.fromRGB(130,130,150)
infoLbl.TextSize    = 11
infoLbl.Font        = Enum.Font.Gotham
infoLbl.TextWrapped = true
infoLbl.LayoutOrder = 10

-- ══════════════════════════════════════════════════════
--  CAPTURA DE TECLAS
-- ══════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local kc = input.KeyCode

    -- Capturar keybind
    if listeningFor then
        if kc == Enum.KeyCode.Escape then
            listeningFor = nil
            for n, b in pairs(kbBtnRefs) do
                b.BackgroundColor3 = Color3.fromRGB(32,32,45)
                for _, d2 in ipairs(kbData) do
                    if d2.name == n then b.Text = "[ "..State[d2.key].Name.." ]" break end
                end
            end
        else
            for _, d in ipairs(kbData) do
                if d.name == listeningFor then
                    State[d.key] = kc
                    kbBtnRefs[d.name].Text             = "[ "..kc.Name.." ]"
                    kbBtnRefs[d.name].BackgroundColor3 = Color3.fromRGB(32,32,45)
                    break
                end
            end
            listeningFor = nil
        end
        return
    end

    if gp then return end

    -- Atalhos normais
    if kc == State.KB_Menu then
        ScreenGui.Enabled = not ScreenGui.Enabled

    elseif kc == State.KB_ESP then
        local v = not State.ESP
        State.ESP = v
        if State.ToggleFns["ESP"] then State.ToggleFns["ESP"](v) end

    elseif kc == State.KB_Aimbot then
        local v = not State.Aimbot
        State.Aimbot = v
        if State.ToggleFns["Aimbot"] then State.ToggleFns["Aimbot"](v) end

    elseif kc == State.KB_Speed then
        local v = not State.Speed
        State.Speed = v
        applySpeed(v)
        if State.ToggleFns["Speed"] then State.ToggleFns["Speed"](v) end
    end
end)

-- ══════════════════════════════════════════════════════
--  FOV CIRCLE
-- ══════════════════════════════════════════════════════
local fovCircle       = Drawing.new("Circle")
fovCircle.Color       = Color3.fromRGB(255,50,50)
fovCircle.Filled      = false
fovCircle.Thickness   = 1.5
fovCircle.Transparency = 1
fovCircle.Radius      = State.FOVRadius
fovCircle.Position    = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
fovCircle.Visible     = false
State.FOVCircle       = fovCircle

-- ══════════════════════════════════════════════════════
--  ARRASTAR JANELA
-- ══════════════════════════════════════════════════════
do
    local drag, dStart, dPos
    TitleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            drag   = true
            dStart = inp.Position
            dPos   = MainFrame.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if drag and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dStart
            MainFrame.Position = UDim2.new(dPos.X.Scale, dPos.X.Offset+d.X, dPos.Y.Scale, dPos.Y.Offset+d.Y)
        end
    end)
end

-- ══════════════════════════════════════════════════════
--  MINIMIZAR / FECHAR
-- ══════════════════════════════════════════════════════
MinBtn.MouseButton1Click:Connect(function()
    State.Minimized = not State.Minimized
    for name, page in pairs(tabPages) do
        page.Visible = not State.Minimized and name == activeTab
    end
    TabBar.Visible = not State.Minimized
    MinBtn.Text    = State.Minimized and "□" or "─"
end)

CloseBtn.MouseButton1Click:Connect(function()
    pcall(function() fovCircle:Remove() end)
    for _, plr in ipairs(Players:GetPlayers()) do removeESP(plr) end
    ScreenGui:Destroy()
end)

print("[AIO v2] Pronto!")
print("  ESP    → "..State.KB_ESP.Name)
print("  Aimbot → "..State.KB_Aimbot.Name)
print("  Speed  → "..State.KB_Speed.Name)
print("  Menu   → "..State.KB_Menu.Name)
print("  Aba 'Teclas' para reconfigurar.")
