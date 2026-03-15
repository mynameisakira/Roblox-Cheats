-- ╔══════════════════════════════════════════════════╗
-- ║         ROBLOX LOCAL SCRIPT — AIO MENU v3        ║
-- ║   ESP | Aimbot FOV | Speed | Keybinds            ║
-- ╚══════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ══════════════════════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════════════════════
local Cfg = {
    ESP        = false,
    Aimbot     = false,
    Speed      = false,

    FOVRadius  = 120,
    FOVVisible = true,
    TeamCheck  = true,
    WalkSpeed  = 60,

    KB_ESP     = Enum.KeyCode.T,
    KB_Aimbot  = Enum.KeyCode.G,
    KB_Speed   = Enum.KeyCode.Y,
    KB_Menu    = Enum.KeyCode.Insert,
}

-- ══════════════════════════════════════════════════════
--  DRAWING UTILS
-- ══════════════════════════════════════════════════════
local function NewQuad(color, filled, thick)
    local q = Drawing.new("Quad")
    q.Color        = color
    q.Filled       = filled
    q.Thickness    = thick or 1.5
    q.Transparency = 1
    q.Visible      = false
    return q
end

local function NewText(color, size)
    local t = Drawing.new("Text")
    t.Color        = color
    t.Size         = size or 13
    t.Font         = Drawing.Fonts.UI
    t.Outline      = true
    t.OutlineColor = Color3.new(0,0,0)
    t.Visible      = false
    return t
end

local function NewCircle()
    local c = Drawing.new("Circle")
    c.Color        = Color3.fromRGB(255,60,60)
    c.Filled       = false
    c.Thickness    = 1.5
    c.Transparency = 1
    c.Visible      = false
    return c
end

-- ══════════════════════════════════════════════════════
--  ESP STORAGE
-- ══════════════════════════════════════════════════════
-- ESPData[player] = { box, boxShadow, hpBg, hpBar, lblName, lblHp }
local ESPData = {}

local function MakeESP(plr)
    if ESPData[plr] then return end
    ESPData[plr] = {
        boxShadow = NewQuad(Color3.new(0,0,0),             false, 3),
        box       = NewQuad(Color3.fromRGB(255,55,55),     false, 1.5),
        hpBg      = NewQuad(Color3.fromRGB(15,15,15),      true,  1),
        hpBar     = NewQuad(Color3.fromRGB(60,220,80),     true,  1),
        lblName   = NewText(Color3.fromRGB(255,255,255),   13),
        lblHp     = NewText(Color3.fromRGB(180,255,180),   11),
    }
end

local function DestroyESP(plr)
    if not ESPData[plr] then return end
    for _, d in pairs(ESPData[plr]) do
        pcall(function() d:Remove() end)
    end
    ESPData[plr] = nil
end

local function HideESP(plr)
    if not ESPData[plr] then return end
    for _, d in pairs(ESPData[plr]) do
        pcall(function() d.Visible = false end)
    end
end

-- ══════════════════════════════════════════════════════
--  BOUNDING BOX 3D → 2D
-- ══════════════════════════════════════════════════════
local function GetBox(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local pos = hrp.Position
    local H, W = 3.1, 1.4

    local pts = {
        Vector3.new( W,  H,  W), Vector3.new(-W,  H,  W),
        Vector3.new( W,  H, -W), Vector3.new(-W,  H, -W),
        Vector3.new( W, -H,  W), Vector3.new(-W, -H,  W),
        Vector3.new( W, -H, -W), Vector3.new(-W, -H, -W),
    }

    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge

    for _, offset in ipairs(pts) do
        local sp = Camera:WorldToViewportPoint(pos + offset)
        if sp.Z <= 0 then return nil end
        if sp.X < minX then minX = sp.X end
        if sp.Y < minY then minY = sp.Y end
        if sp.X > maxX then maxX = sp.X end
        if sp.Y > maxY then maxY = sp.Y end
    end

    local vp = Camera.ViewportSize
    if maxX < 0 or minX > vp.X or maxY < 0 or minY > vp.Y then
        return nil
    end

    -- tl, tr, bl, br
    return Vector2.new(minX,minY), Vector2.new(maxX,minY),
           Vector2.new(minX,maxY), Vector2.new(maxX,maxY)
end

-- ══════════════════════════════════════════════════════
--  WALLCHECK
-- ══════════════════════════════════════════════════════
local function WallCheck(targetPos)
    local myChar = LocalPlayer.Character
    local origin = Camera.CFrame.Position

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excl = {Camera}
    if myChar then table.insert(excl, myChar) end
    params.FilterDescendantsInstances = excl

    local dir    = targetPos - origin
    local result = Workspace:Raycast(origin, dir, params)

    if not result then return true end -- sem obstáculo = visível

    -- verificar se bateu num personagem de player
    local inst = result.Instance
    local model = inst:FindFirstAncestorOfClass("Model")
    if model then
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character == model then
                return true -- bateu no alvo = visível
            end
        end
    end
    return false -- bateu em algo sólido = bloqueado
end

-- ══════════════════════════════════════════════════════
--  SPEED
-- ══════════════════════════════════════════════════════
local SpeedConn = nil
local function SetSpeed(on)
    if SpeedConn then SpeedConn:Disconnect() SpeedConn = nil end
    if not on then
        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = 16 end
        end
        return
    end
    SpeedConn = RunService.Heartbeat:Connect(function()
        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = Cfg.WalkSpeed end
        end
    end)
end

-- ══════════════════════════════════════════════════════
--  FOV CIRCLE
-- ══════════════════════════════════════════════════════
local FovCircle = NewCircle()

-- ══════════════════════════════════════════════════════
--  RENDER LOOP
-- ══════════════════════════════════════════════════════
local sc = Vector2.new(0,0) -- screen center

RunService.RenderStepped:Connect(function()
    sc = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)

    -- FOV circle
    FovCircle.Position = sc
    FovCircle.Radius   = Cfg.FOVRadius
    FovCircle.Visible  = Cfg.Aimbot and Cfg.FOVVisible

    local myTeam  = LocalPlayer.Team
    local bestPlr = nil
    local bestDst = Cfg.FOVRadius + 1

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local char = plr.Character

        -- ── Checar se está morto / sem personagem ──
        local alive = false
        local hum   = nil
        if char then
            hum   = char:FindFirstChildOfClass("Humanoid")
            alive = hum ~= nil and hum.Health > 0
        end

        if not char or not alive then
            HideESP(plr)
            continue
        end

        -- ── ESP ────────────────────────────────────
        if Cfg.ESP then
            MakeESP(plr)
            local esp = ESPData[plr]
            local tl, tr, bl, br = GetBox(char)

            if tl then
                local off = Vector2.new(1,1)
                esp.boxShadow.PointA = tl+off; esp.boxShadow.PointB = tr+off
                esp.boxShadow.PointC = br+off; esp.boxShadow.PointD = bl+off
                esp.boxShadow.Visible = true

                esp.box.PointA = tl; esp.box.PointB = tr
                esp.box.PointC = br; esp.box.PointD = bl
                esp.box.Visible = true

                -- barra de vida (esquerda)
                local bW   = 4
                local bX   = tl.X - bW - 3
                local bH   = bl.Y - tl.Y
                local pct  = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                local top  = bl.Y - bH * pct

                local hpColor
                if pct > 0.6 then
                    hpColor = Color3.fromRGB(50, 220, 70)
                elseif pct > 0.3 then
                    hpColor = Color3.fromRGB(230, 200, 40)
                else
                    hpColor = Color3.fromRGB(230, 50, 50)
                end

                esp.hpBg.PointA = Vector2.new(bX,    tl.Y); esp.hpBg.PointB = Vector2.new(bX+bW, tl.Y)
                esp.hpBg.PointC = Vector2.new(bX+bW, bl.Y); esp.hpBg.PointD = Vector2.new(bX,    bl.Y)
                esp.hpBg.Visible = true

                esp.hpBar.Color  = hpColor
                esp.hpBar.PointA = Vector2.new(bX,    top);  esp.hpBar.PointB = Vector2.new(bX+bW, top)
                esp.hpBar.PointC = Vector2.new(bX+bW, bl.Y); esp.hpBar.PointD = Vector2.new(bX,    bl.Y)
                esp.hpBar.Visible = true

                local cx = (tl.X + tr.X) * 0.5
                esp.lblName.Text     = plr.DisplayName
                esp.lblName.Position = Vector2.new(cx, tl.Y - 16)
                esp.lblName.Center   = true
                esp.lblName.Visible  = true

                esp.lblHp.Text     = math.floor(hum.Health) .. " HP"
                esp.lblHp.Position = Vector2.new(cx, bl.Y + 2)
                esp.lblHp.Center   = true
                esp.lblHp.Visible  = true
            else
                HideESP(plr)
            end
        else
            HideESP(plr)
        end

        -- ── Aimbot ─────────────────────────────────
        if Cfg.Aimbot then
            if Cfg.TeamCheck and plr.Team == myTeam then continue end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end

            local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if not onScreen or sp.Z <= 0 then continue end

            local dist = (Vector2.new(sp.X, sp.Y) - sc).Magnitude
            if dist > Cfg.FOVRadius then continue end

            if not WallCheck(hrp.Position) then continue end

            if dist < bestDst then
                bestDst = dist
                bestPlr = plr
            end
        end
    end

    -- aplicar aimbot
    if Cfg.Aimbot and bestPlr then
        local char = bestPlr.Character
        if char then
            local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
            if head then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
            end
        end
    end
end)

-- cleanup ao sair/respawnar
Players.PlayerRemoving:Connect(DestroyESP)
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        HideESP(plr)
    end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        plr.CharacterAdded:Connect(function()
            HideESP(plr)
        end)
    end
end

-- ══════════════════════════════════════════════════════
--  GUI
-- ══════════════════════════════════════════════════════
local ok, CoreGui = pcall(function() return game:GetService("CoreGui") end)
local GuiParent   = ok and CoreGui or LocalPlayer:WaitForChild("PlayerGui")

local Screen = Instance.new("ScreenGui")
Screen.Name           = "AIO_v3"
Screen.ResetOnSpawn   = false
Screen.ZIndexBehavior = Enum.ZIndexBehavior.Global
Screen.Parent         = GuiParent

-- janela principal
local Win = Instance.new("Frame", Screen)
Win.Name             = "Win"
Win.Size             = UDim2.fromOffset(300, 38) -- altura vai crescer com as abas
Win.Position         = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(-150, -190)
Win.BackgroundColor3 = Color3.fromRGB(12, 12, 17)
Win.BorderSizePixel  = 0
Win.ClipsDescendants = false

local wCorner = Instance.new("UICorner", Win)
wCorner.CornerRadius = UDim.new(0, 8)

local wStroke = Instance.new("UIStroke", Win)
wStroke.Color     = Color3.fromRGB(190, 35, 35)
wStroke.Thickness = 1.5

-- título
local Title = Instance.new("Frame", Win)
Title.Name            = "Title"
Title.Size            = UDim2.new(1, 0, 0, 38)
Title.BackgroundColor3 = Color3.fromRGB(180, 28, 28)
Title.BorderSizePixel = 0

local tCorner = Instance.new("UICorner", Title)
tCorner.CornerRadius = UDim.new(0, 8)

-- patch para tirar cantos arredondados embaixo do título
local tPatch = Instance.new("Frame", Title)
tPatch.Size            = UDim2.new(1, 0, 0.5, 0)
tPatch.Position        = UDim2.new(0, 0, 0.5, 0)
tPatch.BackgroundColor3 = Color3.fromRGB(180, 28, 28)
tPatch.BorderSizePixel = 0

local TitleLbl = Instance.new("TextLabel", Title)
TitleLbl.Text             = "⚡  AIO Menu  v3"
TitleLbl.Size             = UDim2.new(1, -80, 1, 0)
TitleLbl.Position         = UDim2.new(0, 10, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.TextColor3       = Color3.new(1,1,1)
TitleLbl.TextSize         = 13
TitleLbl.Font             = Enum.Font.GothamBold
TitleLbl.TextXAlignment   = Enum.TextXAlignment.Left
TitleLbl.ZIndex           = 3

local function TopBtn(lbl, ox, col)
    local b = Instance.new("TextButton", Title)
    b.Size            = UDim2.fromOffset(22, 22)
    b.Position        = UDim2.new(1, ox, 0.5, -11)
    b.BackgroundColor3 = col
    b.Text            = lbl
    b.TextColor3      = Color3.new(1,1,1)
    b.TextSize        = 12
    b.Font            = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.ZIndex          = 4
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    return b
end
local MinBtn   = TopBtn("─", -50, Color3.fromRGB(50,50,65))
local CloseBtn = TopBtn("✕", -24, Color3.fromRGB(160,30,30))

-- arrastar
do
    local drag, ds, dp
    Title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true; ds = i.Position; dp = Win.Position
        end
    end)
    Title.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            Win.Position = UDim2.new(dp.X.Scale, dp.X.Offset+d.X, dp.Y.Scale, dp.Y.Offset+d.Y)
        end
    end)
end

-- ── Tabs ───────────────────────────────────────────────
local TabHolder = Instance.new("Frame", Win)
TabHolder.Name            = "TabHolder"
TabHolder.Size            = UDim2.new(1, 0, 0, 30)
TabHolder.Position        = UDim2.fromOffset(0, 38)
TabHolder.BackgroundColor3 = Color3.fromRGB(17, 17, 24)
TabHolder.BorderSizePixel = 0

local tabList = Instance.new("UIListLayout", TabHolder)
tabList.FillDirection         = Enum.FillDirection.Horizontal
tabList.HorizontalAlignment   = Enum.HorizontalAlignment.Center
tabList.VerticalAlignment     = Enum.VerticalAlignment.Center
tabList.Padding               = UDim.new(0, 3)

-- container das páginas (logo abaixo dos tabs)
local PageHolder = Instance.new("Frame", Win)
PageHolder.Name             = "PageHolder"
PageHolder.Size             = UDim2.new(1, 0, 0, 0)
PageHolder.Position         = UDim2.fromOffset(0, 68)
PageHolder.AutomaticSize    = Enum.AutomaticSize.Y
PageHolder.BackgroundTransparency = 1
PageHolder.BorderSizePixel  = 0
PageHolder.ClipsDescendants = false

local Pages    = {}
local TabBtns  = {}
local CurTab   = nil

local function NewTab(name, icon)
    local btn = Instance.new("TextButton", TabHolder)
    btn.Size            = UDim2.fromOffset(62, 22)
    btn.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    btn.Text            = icon.." "..name
    btn.TextColor3      = Color3.fromRGB(160, 160, 175)
    btn.TextSize        = 10
    btn.Font            = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    local page = Instance.new("Frame", PageHolder)
    page.Name             = name
    page.Size             = UDim2.new(1, 0, 0, 0)
    page.AutomaticSize    = Enum.AutomaticSize.Y
    page.BackgroundTransparency = 1
    page.Visible          = false
    page.BorderSizePixel  = 0

    local ll = Instance.new("UIListLayout", page)
    ll.Padding   = UDim.new(0, 5)
    ll.SortOrder = Enum.SortOrder.LayoutOrder

    local pp = Instance.new("UIPadding", page)
    pp.PaddingLeft   = UDim.new(0, 8)
    pp.PaddingRight  = UDim.new(0, 8)
    pp.PaddingTop    = UDim.new(0, 6)
    pp.PaddingBottom = UDim.new(0, 8)

    Pages[name]   = page
    TabBtns[name] = btn

    btn.MouseButton1Click:Connect(function()
        if CurTab then
            Pages[CurTab].Visible         = false
            TabBtns[CurTab].BackgroundColor3 = Color3.fromRGB(26,26,36)
            TabBtns[CurTab].TextColor3       = Color3.fromRGB(160,160,175)
        end
        CurTab               = name
        page.Visible         = true
        btn.BackgroundColor3 = Color3.fromRGB(195,32,32)
        btn.TextColor3       = Color3.new(1,1,1)
    end)

    return page
end

local PgESP   = NewTab("ESP",    "👁")
local PgAim   = NewTab("Aimbot", "🎯")
local PgSpd   = NewTab("Speed",  "⚡")
local PgKeys  = NewTab("Teclas", "⌨")

-- ativa ESP por padrão
TabBtns["ESP"].BackgroundColor3 = Color3.fromRGB(195,32,32)
TabBtns["ESP"].TextColor3       = Color3.new(1,1,1)
Pages["ESP"].Visible            = true
CurTab = "ESP"

-- ── Componentes de UI ──────────────────────────────────

-- referências externas dos toggles para sincronizar com keybind
local ToggleSyncFns = {}

local function Section(parent, text, order)
    local l = Instance.new("TextLabel", parent)
    l.Text        = "  "..text
    l.Size        = UDim2.new(1, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.TextColor3  = Color3.fromRGB(195, 45, 45)
    l.TextSize    = 10
    l.Font        = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = order
end

local function Toggle(parent, text, order, init, cb)
    local row = Instance.new("Frame", parent)
    row.Size            = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    row.BorderSizePixel = 0
    row.LayoutOrder     = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Text        = text
    lbl.Size        = UDim2.new(1, -52, 1, 0)
    lbl.Position    = UDim2.fromOffset(8, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3  = Color3.fromRGB(210, 210, 220)
    lbl.TextSize    = 11
    lbl.Font        = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", row)
    track.Size            = UDim2.fromOffset(36, 18)
    track.Position        = UDim2.new(1, -44, 0.5, -9)
    track.BackgroundColor3 = Color3.fromRGB(42, 42, 55)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 9)

    local thumb = Instance.new("Frame", track)
    thumb.Size            = UDim2.fromOffset(14, 14)
    thumb.Position        = UDim2.new(0, 2, 0.5, -7)
    thumb.BackgroundColor3 = Color3.fromRGB(110, 110, 128)
    thumb.BorderSizePixel = 0
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 7)

    local on = init or false

    local function Set(val, silent)
        on = val
        if on then
            track.BackgroundColor3 = Color3.fromRGB(195, 32, 32)
            thumb.BackgroundColor3 = Color3.new(1,1,1)
            thumb:TweenPosition(UDim2.new(0,20,0.5,-7), "Out","Quad",0.12, true)
        else
            track.BackgroundColor3 = Color3.fromRGB(42, 42, 55)
            thumb.BackgroundColor3 = Color3.fromRGB(110, 110, 128)
            thumb:TweenPosition(UDim2.new(0,2,0.5,-7), "Out","Quad",0.12, true)
        end
        if not silent and cb then cb(on) end
    end

    local click = Instance.new("TextButton", row)
    click.Size            = UDim2.new(1, 0, 1, 0)
    click.BackgroundTransparency = 1
    click.Text            = ""
    click.MouseButton1Click:Connect(function() Set(not on) end)

    Set(on, true)
    return Set
end

local function Slider(parent, text, order, minV, maxV, def, fmt, cb)
    local cont = Instance.new("Frame", parent)
    cont.Size            = UDim2.new(1, 0, 0, 48)
    cont.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    cont.BorderSizePixel = 0
    cont.LayoutOrder     = order
    Instance.new("UICorner", cont).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", cont)
    lbl.Text        = text
    lbl.Size        = UDim2.new(0.6, 0, 0, 18)
    lbl.Position    = UDim2.fromOffset(8, 4)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3  = Color3.fromRGB(210, 210, 220)
    lbl.TextSize    = 11
    lbl.Font        = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local val = Instance.new("TextLabel", cont)
    val.Size        = UDim2.new(0.4, -8, 0, 18)
    val.Position    = UDim2.new(0.6, 0, 0, 4)
    val.BackgroundTransparency = 1
    val.TextColor3  = Color3.fromRGB(195, 45, 45)
    val.TextSize    = 11
    val.Font        = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", cont)
    track.Size            = UDim2.new(1, -16, 0, 4)
    track.Position        = UDim2.new(0, 8, 0, 34)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 54)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 2)

    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = Color3.fromRGB(195, 35, 35)
    fill.BorderSizePixel  = 0
    fill.Size             = UDim2.new(0, 0, 1, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)

    local knob = Instance.new("Frame", fill)
    knob.Size            = UDim2.fromOffset(12, 12)
    knob.Position        = UDim2.new(1, -6, 0.5, -6)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 3
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 6)

    local cur = def
    local function SetVal(v, silent)
        v = math.clamp(math.floor(v + 0.5), minV, maxV)
        cur = v
        fill.Size  = UDim2.new((v - minV) / (maxV - minV), 0, 1, 0)
        val.Text   = string.format(fmt or "%g", v)
        if not silent and cb then cb(v) end
    end
    SetVal(def, true)

    local dragging = false
    local hitbox = Instance.new("TextButton", cont)
    hitbox.Size            = UDim2.new(1, 0, 0, 20)
    hitbox.Position        = UDim2.new(0, 0, 0, 26)
    hitbox.BackgroundTransparency = 1
    hitbox.Text            = ""
    hitbox.ZIndex          = 5
    hitbox.MouseButton1Down:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    RunService.RenderStepped:Connect(function()
        if not dragging then return end
        local mx = UserInputService:GetMouseLocation().X
        local tx = track.AbsolutePosition.X
        local tw = track.AbsoluteSize.X
        SetVal(minV + math.clamp((mx - tx) / tw, 0, 1) * (maxV - minV))
    end)
end

-- ══════════════════════════════════════════════════════
--  PREENCHER ABAS
-- ══════════════════════════════════════════════════════

-- ESP
Section(PgESP, "ESP", 1)
ToggleSyncFns["ESP"] = Toggle(PgESP, "ESP  (Caixa + Vida + Nome)", 2, false, function(on)
    Cfg.ESP = on
    if not on then
        for _, plr in ipairs(Players:GetPlayers()) do HideESP(plr) end
    end
end)

-- Aimbot
Section(PgAim, "AIMBOT", 1)
ToggleSyncFns["Aimbot"] = Toggle(PgAim, "Aimbot  (WallCheck + TeamCheck)", 2, false, function(on)
    Cfg.Aimbot = on
end)
Toggle(PgAim, "Mostrar Círculo FOV", 3, true, function(on)
    Cfg.FOVVisible = on
end)
Toggle(PgAim, "Team Check", 4, true, function(on)
    Cfg.TeamCheck = on
end)
Section(PgAim, "FOV", 5)
Slider(PgAim, "Raio do FOV", 6, 30, 450, 120, "%g px", function(v)
    Cfg.FOVRadius = v
end)

-- Speed
Section(PgSpd, "SPEED", 1)
ToggleSyncFns["Speed"] = Toggle(PgSpd, "Speed Hack", 2, false, function(on)
    Cfg.Speed = on
    SetSpeed(on)
end)
Section(PgSpd, "CONFIGURAÇÃO", 3)
Slider(PgSpd, "Walk Speed", 4, 16, 300, 60, "%g", function(v)
    Cfg.WalkSpeed = v
end)

-- Keybinds
Section(PgKeys, "CONFIGURAR TECLAS", 1)

local kbDefs = {
    { id="KB_ESP",    label="ESP"              },
    { id="KB_Aimbot", label="Aimbot"           },
    { id="KB_Speed",  label="Speed Hack"       },
    { id="KB_Menu",   label="Abrir/Fechar Menu"},
}

local KbBtns      = {}
local KbListening = nil

local function KbRow(parent, def, order)
    local row = Instance.new("Frame", parent)
    row.Size            = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    row.BorderSizePixel = 0
    row.LayoutOrder     = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", row)
    lbl.Text        = def.label
    lbl.Size        = UDim2.new(1, -105, 1, 0)
    lbl.Position    = UDim2.fromOffset(8, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3  = Color3.fromRGB(210, 210, 220)
    lbl.TextSize    = 11
    lbl.Font        = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", row)
    btn.Size            = UDim2.fromOffset(88, 22)
    btn.Position        = UDim2.new(1, -96, 0.5, -11)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    btn.TextColor3      = Color3.fromRGB(195, 45, 45)
    btn.TextSize        = 10
    btn.Font            = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

    local function Refresh()
        btn.Text = "[ " .. Cfg[def.id].Name .. " ]"
    end
    Refresh()

    btn.MouseButton1Click:Connect(function()
        if KbListening == def.id then
            KbListening         = nil
            btn.BackgroundColor3 = Color3.fromRGB(30,30,42)
            Refresh()
        else
            -- resetar todos
            for _, b in pairs(KbBtns) do
                b.btn.BackgroundColor3 = Color3.fromRGB(30,30,42)
                b.refresh()
            end
            KbListening          = def.id
            btn.Text             = " pressione... "
            btn.BackgroundColor3 = Color3.fromRGB(145,25,25)
        end
    end)

    KbBtns[def.id] = { btn=btn, refresh=Refresh }
end

for i, d in ipairs(kbDefs) do
    KbRow(PgKeys, d, i + 1)
end

local hint = Instance.new("TextLabel", PgKeys)
hint.Text        = "Clique no botão → pressione a tecla\nESC cancela"
hint.Size        = UDim2.new(1, 0, 0, 28)
hint.BackgroundTransparency = 1
hint.TextColor3  = Color3.fromRGB(110, 110, 130)
hint.TextSize    = 10
hint.Font        = Enum.Font.Gotham
hint.TextWrapped = true
hint.LayoutOrder = 99

-- ══════════════════════════════════════════════════════
--  INPUT — KEYBINDS
-- ══════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local kc = input.KeyCode

    -- capturar nova tecla
    if KbListening then
        if kc == Enum.KeyCode.Escape then
            KbListening = nil
            for _, b in pairs(KbBtns) do
                b.btn.BackgroundColor3 = Color3.fromRGB(30,30,42)
                b.refresh()
            end
        else
            Cfg[KbListening] = kc
            if KbBtns[KbListening] then
                KbBtns[KbListening].btn.BackgroundColor3 = Color3.fromRGB(30,30,42)
                KbBtns[KbListening].refresh()
            end
            KbListening = nil
        end
        return
    end

    if gp then return end

    if kc == Cfg.KB_Menu then
        Screen.Enabled = not Screen.Enabled

    elseif kc == Cfg.KB_ESP then
        local v = not Cfg.ESP
        Cfg.ESP = v
        if ToggleSyncFns["ESP"] then ToggleSyncFns["ESP"](v) end

    elseif kc == Cfg.KB_Aimbot then
        local v = not Cfg.Aimbot
        Cfg.Aimbot = v
        if ToggleSyncFns["Aimbot"] then ToggleSyncFns["Aimbot"](v) end

    elseif kc == Cfg.KB_Speed then
        local v = not Cfg.Speed
        Cfg.Speed = v
        SetSpeed(v)
        if ToggleSyncFns["Speed"] then ToggleSyncFns["Speed"](v) end
    end
end)

-- ══════════════════════════════════════════════════════
--  MINIMIZAR / FECHAR
-- ══════════════════════════════════════════════════════
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TabHolder.Visible  = not minimized
    PageHolder.Visible = not minimized
    MinBtn.Text        = minimized and "□" or "─"
    if minimized then
        Win.Size = UDim2.fromOffset(300, 38)
    else
        Win.AutomaticSize = Enum.AutomaticSize.Y
        Win.Size = UDim2.fromOffset(300, 0)
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    pcall(function() FovCircle:Remove() end)
    for _, plr in ipairs(Players:GetPlayers()) do DestroyESP(plr) end
    Screen:Destroy()
end)

-- AutomaticSize na janela principal
Win.AutomaticSize = Enum.AutomaticSize.Y
Win.Size          = UDim2.fromOffset(300, 0)

print("[AIO v3] ✔ Carregado!")
print("  ESP    → " .. Cfg.KB_ESP.Name)
print("  Aimbot → " .. Cfg.KB_Aimbot.Name)
print("  Speed  → " .. Cfg.KB_Speed.Name)
print("  Menu   → " .. Cfg.KB_Menu.Name)
