-- ╔══════════════════════════════════════════════╗
-- ║         ROBLOX LOCAL SCRIPT - MENU GUI        ║
-- ║   Highlights | Aimbot FOV | Speed             ║
-- ╚══════════════════════════════════════════════╝

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace      = game:GetService("Workspace")

local LocalPlayer   = Players.LocalPlayer
local Camera        = Workspace.CurrentCamera
local Mouse         = LocalPlayer:GetMouse()

-- ══════════════════════════════════════
--  ESTADO GLOBAL
-- ══════════════════════════════════════
local State = {
    Highlights   = false,
    Aimbot       = false,
    Speed        = false,
    Minimized    = false,

    -- FOV Config
    FOVRadius    = 120,
    FOVVisible   = true,
    TeamCheck    = true,

    -- Speed Config
    WalkSpeed    = 16,

    -- Internals
    HighlightObjects  = {},
    AimbotConnection  = nil,
    SpeedConnection   = nil,
    FOVCircle         = nil,
}

-- ══════════════════════════════════════
--  CRIAR GUI PRINCIPAL
-- ══════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name          = "AIO_Menu"
ScreenGui.ResetOnSpawn  = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent        = game:GetService("CoreGui")

-- ─── Janela principal ───────────────────────────────────────────────────────
local MainFrame = Instance.new("Frame")
MainFrame.Name            = "MainFrame"
MainFrame.Size            = UDim2.new(0, 300, 0, 370)
MainFrame.Position        = UDim2.new(0.5, -150, 0.5, -185)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent          = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color     = Color3.fromRGB(200, 50, 50)
UIStroke.Thickness = 1.5
UIStroke.Parent    = MainFrame

-- ─── Barra de título (arrasto) ──────────────────────────────────────────────
local TitleBar = Instance.new("Frame")
TitleBar.Name            = "TitleBar"
TitleBar.Size            = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex          = 5
TitleBar.Parent          = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent       = TitleBar

-- corta cantos inferiores do TitleBar
local TitleFix = Instance.new("Frame")
TitleFix.Size            = UDim2.new(1, 0, 0, 10)
TitleFix.Position        = UDim2.new(0, 0, 1, -10)
TitleFix.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
TitleFix.BorderSizePixel  = 0
TitleFix.ZIndex           = 5
TitleFix.Parent           = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text            = "⚡  AIO Menu"
TitleLabel.Size            = UDim2.new(1, -80, 1, 0)
TitleLabel.Position        = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize        = 15
TitleLabel.Font            = Enum.Font.GothamBold
TitleLabel.TextXAlignment  = Enum.TextXAlignment.Left
TitleLabel.ZIndex          = 6
TitleLabel.Parent          = TitleBar

-- ─── Botões Minimizar / Fechar ───────────────────────────────────────────────
local function makeTopBtn(symbol, posX, color)
    local btn = Instance.new("TextButton")
    btn.Size            = UDim2.new(0, 22, 0, 22)
    btn.Position        = UDim2.new(1, posX, 0.5, -11)
    btn.BackgroundColor3 = color
    btn.Text            = symbol
    btn.TextColor3      = Color3.fromRGB(255,255,255)
    btn.TextSize        = 13
    btn.Font            = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.ZIndex          = 7
    btn.Parent          = TitleBar
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,5)
    c.Parent = btn
    return btn
end

local MinBtn   = makeTopBtn("─", -52, Color3.fromRGB(60,60,70))
local CloseBtn = makeTopBtn("✕", -26, Color3.fromRGB(180,40,40))

-- ─── Área de conteúdo ────────────────────────────────────────────────────────
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Name            = "Content"
ContentFrame.Size            = UDim2.new(1, 0, 1, -36)
ContentFrame.Position        = UDim2.new(0, 0, 0, 36)
ContentFrame.BackgroundTransparency = 1
ContentFrame.BorderSizePixel = 0
ContentFrame.ScrollBarThickness = 4
ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(200,50,50)
ContentFrame.CanvasSize      = UDim2.new(0,0,0,0)
ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentFrame.Parent          = MainFrame

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingLeft   = UDim.new(0, 12)
UIPadding.PaddingRight  = UDim.new(0, 12)
UIPadding.PaddingTop    = UDim.new(0, 10)
UIPadding.PaddingBottom = UDim.new(0, 10)
UIPadding.Parent        = ContentFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding       = UDim.new(0, 8)
UIListLayout.SortOrder     = Enum.SortOrder.LayoutOrder
UIListLayout.Parent        = ContentFrame

-- ══════════════════════════════════════
--  HELPERS DE UI
-- ══════════════════════════════════════
local function makeSectionLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Text            = text
    lbl.Size            = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3      = Color3.fromRGB(200, 50, 50)
    lbl.TextSize        = 12
    lbl.Font            = Enum.Font.GothamBold
    lbl.TextXAlignment  = Enum.TextXAlignment.Left
    lbl.LayoutOrder     = order
    lbl.Parent          = ContentFrame
    return lbl
end

local function makeToggle(labelText, order, callback)
    local row = Instance.new("Frame")
    row.Size            = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    row.BorderSizePixel = 0
    row.LayoutOrder     = order
    row.Parent          = ContentFrame
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0,7)
    rc.Parent       = row

    local lbl = Instance.new("TextLabel")
    lbl.Text        = labelText
    lbl.Size        = UDim2.new(1, -60, 1, 0)
    lbl.Position    = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3  = Color3.fromRGB(220, 220, 230)
    lbl.TextSize    = 13
    lbl.Font        = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent      = row

    -- pill switch
    local track = Instance.new("Frame")
    track.Size            = UDim2.new(0, 42, 0, 22)
    track.Position        = UDim2.new(1, -52, 0.5, -11)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    track.BorderSizePixel = 0
    track.Parent          = row
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0,11)
    tc.Parent       = track

    local thumb = Instance.new("Frame")
    thumb.Size            = UDim2.new(0, 18, 0, 18)
    thumb.Position        = UDim2.new(0, 2, 0.5, -9)
    thumb.BackgroundColor3 = Color3.fromRGB(130,130,145)
    thumb.BorderSizePixel = 0
    thumb.Parent          = track
    local thc = Instance.new("UICorner")
    thc.CornerRadius = UDim.new(0,9)
    thc.Parent       = thumb

    local enabled = false
    local function setToggle(val)
        enabled = val
        if enabled then
            track.BackgroundColor3 = Color3.fromRGB(200,40,40)
            thumb.BackgroundColor3 = Color3.fromRGB(255,255,255)
            thumb:TweenPosition(UDim2.new(0,22,0.5,-9), "Out", "Quad", 0.15, true)
        else
            track.BackgroundColor3 = Color3.fromRGB(50,50,60)
            thumb.BackgroundColor3 = Color3.fromRGB(130,130,145)
            thumb:TweenPosition(UDim2.new(0,2,0.5,-9), "Out", "Quad", 0.15, true)
        end
        if callback then callback(enabled) end
    end

    local btn = Instance.new("TextButton")
    btn.Size            = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text            = ""
    btn.Parent          = row
    btn.MouseButton1Click:Connect(function()
        setToggle(not enabled)
    end)

    return row, setToggle
end

local function makeSlider(labelText, order, minVal, maxVal, defaultVal, fmt, callback)
    local container = Instance.new("Frame")
    container.Size            = UDim2.new(1, 0, 0, 54)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    container.BorderSizePixel = 0
    container.LayoutOrder     = order
    container.Parent          = ContentFrame
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0,7)
    cc.Parent       = container

    local lbl = Instance.new("TextLabel")
    lbl.Size        = UDim2.new(1, -10, 0, 22)
    lbl.Position    = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3  = Color3.fromRGB(220,220,230)
    lbl.TextSize    = 12
    lbl.Font        = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent      = container

    local valLbl = Instance.new("TextLabel")
    valLbl.Size        = UDim2.new(0, 60, 0, 22)
    valLbl.Position    = UDim2.new(1, -70, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.TextColor3  = Color3.fromRGB(200,50,50)
    valLbl.TextSize    = 12
    valLbl.Font        = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent      = container

    local track = Instance.new("Frame")
    track.Size            = UDim2.new(1, -20, 0, 6)
    track.Position        = UDim2.new(0, 10, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(50,50,65)
    track.BorderSizePixel = 0
    track.Parent          = container
    local trc = Instance.new("UICorner")
    trc.CornerRadius = UDim.new(0,3)
    trc.Parent       = track

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(200,40,40)
    fill.BorderSizePixel  = 0
    fill.Size             = UDim2.new(0,0,1,0)
    fill.Parent           = track
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0,3)
    fc.Parent       = fill

    local knob = Instance.new("Frame")
    knob.Size            = UDim2.new(0,14,0,14)
    knob.Position        = UDim2.new(0,-7,0.5,-7)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 2
    knob.Parent           = fill
    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(0,7)
    kc.Parent       = knob

    local currentValue = defaultVal
    local function setValue(v)
        v = math.clamp(v, minVal, maxVal)
        currentValue = v
        local pct = (v - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        lbl.Text  = labelText
        valLbl.Text = string.format(fmt or "%g", v)
        if callback then callback(v) end
    end
    setValue(defaultVal)

    local dragging = false
    local dragBtn = Instance.new("TextButton")
    dragBtn.Size            = UDim2.new(1, 0, 0, 20)
    dragBtn.Position        = UDim2.new(0, 0, 0, 28)
    dragBtn.BackgroundTransparency = 1
    dragBtn.Text            = ""
    dragBtn.ZIndex          = 5
    dragBtn.Parent          = container

    dragBtn.MouseButton1Down:Connect(function()
        dragging = true
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging then
            local mX    = UserInputService:GetMouseLocation().X
            local tAbs  = track.AbsolutePosition.X
            local tW    = track.AbsoluteSize.X
            local pct   = math.clamp((mX - tAbs) / tW, 0, 1)
            local rawV  = minVal + pct * (maxVal - minVal)
            setValue(math.floor(rawV + 0.5))
        end
    end)

    return container, setValue
end

-- ══════════════════════════════════════
--  CONSTRUIR LAYOUT
-- ══════════════════════════════════════

-- ── Seção 1: Highlights ─────────────────────────────────────────────────────
makeSectionLabel("▸  VISUAL", 1)

local _, setHighlights = makeToggle("Player Highlights (Vida + Nome)", 2, function(on)
    State.Highlights = on
    if on then
        -- adicionar highlights
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                if char then
                    if not State.HighlightObjects[plr] then
                        local h = Instance.new("Highlight")
                        h.FillColor         = Color3.fromRGB(200, 0, 0)
                        h.FillTransparency  = 0.5
                        h.OutlineColor      = Color3.fromRGB(255, 50, 50)
                        h.OutlineTransparency = 0
                        h.Adornee           = char
                        h.Parent            = char
                        State.HighlightObjects[plr] = h
                    end
                end
            end
        end
    else
        for plr, h in pairs(State.HighlightObjects) do
            if h and h.Parent then h:Destroy() end
        end
        State.HighlightObjects = {}
    end
end)

-- ── Seção 2: Aimbot ──────────────────────────────────────────────────────────
makeSectionLabel("▸  AIMBOT", 10)

local _, setAimbot = makeToggle("Aimbot FOV (WallCheck + TeamCheck)", 11, function(on)
    State.Aimbot = on
    if not on then
        if State.AimbotConnection then
            State.AimbotConnection:Disconnect()
            State.AimbotConnection = nil
        end
    end
end)

local _, setFOVVisible = makeToggle("Mostrar Círculo FOV", 12, function(on)
    State.FOVVisible = on
    if State.FOVCircle then
        State.FOVCircle.Visible = on
    end
end)
-- Inicia visível
task.defer(function() setFOVVisible(true) end)

local _, setTeamCheck = makeToggle("Team Check", 13, function(on)
    State.TeamCheck = on
end)
task.defer(function() setTeamCheck(true) end)

local _, setFOVRadius = makeSlider("Raio do FOV", 14, 30, 400, 120, "%g px", function(v)
    State.FOVRadius = v
    if State.FOVCircle then
        State.FOVCircle.Radius = v
    end
end)

-- ── Seção 3: Speed ────────────────────────────────────────────────────────────
makeSectionLabel("▸  SPEED", 20)

local _, setSpeed = makeToggle("Speed Hack", 21, function(on)
    State.Speed = on
    if not on then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
        if State.SpeedConnection then
            State.SpeedConnection:Disconnect()
            State.SpeedConnection = nil
        end
    else
        State.SpeedConnection = RunService.RenderStepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = State.WalkSpeed end
            end
        end)
    end
end)

local _, setWalkSpeed = makeSlider("Walk Speed", 22, 16, 250, 60, "%g", function(v)
    State.WalkSpeed = v
end)

-- ══════════════════════════════════════
--  FOV CIRCLE (Drawing)
-- ══════════════════════════════════════
local function createFOVCircle()
    local circle = Drawing.new("Circle")
    circle.Visible    = State.FOVVisible
    circle.Color      = Color3.fromRGB(255, 50, 50)
    circle.Filled     = false
    circle.Thickness  = 1.5
    circle.Transparency = 1
    circle.Radius     = State.FOVRadius
    circle.Position   = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    return circle
end

State.FOVCircle = createFOVCircle()

-- Mantém o círculo no centro
RunService.RenderStepped:Connect(function()
    if State.FOVCircle then
        State.FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        State.FOVCircle.Radius   = State.FOVRadius
        State.FOVCircle.Visible  = State.FOVVisible
    end
end)

-- ══════════════════════════════════════
--  HIGHLIGHTS — manter atualizado
-- ══════════════════════════════════════
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        if State.Highlights and plr ~= LocalPlayer then
            task.wait(0.5)
            if State.HighlightObjects[plr] then
                State.HighlightObjects[plr]:Destroy()
            end
            local h = Instance.new("Highlight")
            h.FillColor        = Color3.fromRGB(200, 0, 0)
            h.FillTransparency = 0.5
            h.OutlineColor     = Color3.fromRGB(255, 50, 50)
            h.Adornee          = char
            h.Parent           = char
            State.HighlightObjects[plr] = h
        end
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    if State.HighlightObjects[plr] then
        State.HighlightObjects[plr]:Destroy()
        State.HighlightObjects[plr] = nil
    end
end)

-- ══════════════════════════════════════
--  WALL CHECK HELPER
-- ══════════════════════════════════════
local function hasWall(origin, target)
    local rayDir = target - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, Workspace.CurrentCamera}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(origin, rayDir, raycastParams)
    if result then
        -- se o que bateu não for o personagem do alvo, há parede
        local hit = result.Instance
        local hitChar = hit:FindFirstAncestorOfClass("Model")
        return hitChar == nil
    end
    return false
end

-- ══════════════════════════════════════
--  AIMBOT LOOP
-- ══════════════════════════════════════
RunService.RenderStepped:Connect(function()
    if not State.Aimbot then return end

    local myChar  = LocalPlayer.Character
    if not myChar then return end
    local myRoot  = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myTeam  = LocalPlayer.Team

    local closestPlayer  = nil
    local closestDist    = State.FOVRadius + 1
    local screenCenter   = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if State.TeamCheck and plr.Team == myTeam then continue end

        local char = plr.Character
        if not char then continue end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then continue end

        -- check FOV (screen space)
        local screenPos, onScreen = Camera:WorldToScreenPoint(hrp.Position)
        if not onScreen then continue end

        local dist2D = Vector2.new(screenPos.X, screenPos.Y) - screenCenter
        if dist2D.Magnitude > State.FOVRadius then continue end

        -- wallcheck
        if hasWall(Camera.CFrame.Position, hrp.Position) then continue end

        if dist2D.Magnitude < closestDist then
            closestDist   = dist2D.Magnitude
            closestPlayer = plr
        end
    end

    if closestPlayer then
        local char = closestPlayer.Character
        local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
        if head then
            local targetCF = CFrame.new(Camera.CFrame.Position, head.Position)
            Camera.CFrame  = targetCF
        end
    end
end)

-- ══════════════════════════════════════
--  ARRASTAR JANELA
-- ══════════════════════════════════════
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = MainFrame.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ══════════════════════════════════════
--  MINIMIZAR / FECHAR
-- ══════════════════════════════════════
MinBtn.MouseButton1Click:Connect(function()
    State.Minimized = not State.Minimized
    if State.Minimized then
        ContentFrame.Visible = false
        MainFrame:TweenSize(UDim2.new(0, 300, 0, 36), "Out", "Quad", 0.2, true)
        MinBtn.Text = "□"
    else
        ContentFrame.Visible = true
        MainFrame:TweenSize(UDim2.new(0, 300, 0, 370), "Out", "Quad", 0.2, true)
        MinBtn.Text = "─"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    if State.FOVCircle then State.FOVCircle:Remove() end
    ScreenGui:Destroy()
end)

-- ══════════════════════════════════════
--  TECLA DE ATALHO: INSERT para mostrar/ocultar
-- ══════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        ScreenGui.Enabled = not ScreenGui.Enabled
    end
end)

print("[AIO Menu] Carregado! Pressione INSERT para mostrar/ocultar.")
