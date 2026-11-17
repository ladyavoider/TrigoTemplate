local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local RunService       = game:GetService("RunService")
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera
local HUB_NAME   = "TrigoHub"
local TOGGLE_KEY = Enum.KeyCode.RightShift
local WIN_W, WIN_H, BAR_H, SBAR_H, SIDE_W = 520, 340, 42, 0, 134

local function guiParent()
    local ok, ui = pcall(function() return gethui() end)
    if ok and typeof(ui) == "Instance" then return ui end
    return playerGui
end

for _, root in ipairs({ playerGui, guiParent() }) do
    local old = root:FindFirstChild(HUB_NAME)
    if old then old:Destroy() end
end

local oldBlur = Lighting:FindFirstChild("TrigoBlur")
if oldBlur then oldBlur:Destroy() end

local Theme = {
    Red    = Color3.fromRGB(255, 90, 120),
    Blue   = Color3.fromRGB(92, 151, 255),
    BG     = Color3.fromRGB(9, 11, 20),
    Panel  = Color3.fromRGB(17, 19, 32),
    Panel2 = Color3.fromRGB(24, 27, 42),
    Dark   = Color3.fromRGB(11, 13, 23),
    Off    = Color3.fromRGB(70, 73, 108),
    Text   = Color3.fromRGB(245, 247, 255),
    Sub    = Color3.fromRGB(171, 181, 214),
    Stroke = Color3.fromRGB(103, 117, 178),
    Green  = Color3.fromRGB(72, 218, 160),
    Cyan   = Color3.fromRGB(92, 210, 255),
    Teal   = Color3.fromRGB(104, 255, 196),
    Amber  = Color3.fromRGB(255, 188, 90),
}

Theme.Glass = {
    Window = 0.08,
    Bar    = 0.18,
    Side   = 0.24,
    Status = 0.26,
    Card   = 0.18,
    Tile   = 0.14,
    Edge   = 0.34,
    Group  = 0.22,
    Inner  = 0.42,
}

Theme.inSec = function(page) return page.curSection ~= nil and page.curSection ~= "" end
local WHITE = Color3.new(1, 1, 1)
local ES, ED = Enum.EasingStyle, Enum.EasingDirection
local conns = {}

local function connect(signal, fn)
    local c = signal:Connect(fn)
    conns[#conns + 1] = c
    return c
end

local function tw(obj, props, t, style, dir)
    local tween = TweenService:Create(obj,
        TweenInfo.new(t or 0.35, style or ES.Quint, dir or ED.Out), props)
    tween:Play()
    return tween
end

local Perf = { loops = {}, onClose = {}, root = nil, auto = true, interval = 30, last = os.clock() }
function Perf.cfgDirty() end
local function loop(obj, props, t, style, reverse)
    local tween = TweenService:Create(obj,
        TweenInfo.new(t, style or ES.Linear, ED.InOut, -1, reverse or false),
        props)
    tween:Play()
    Perf.loops[#Perf.loops + 1] = { tween = tween, obj = obj }
    return tween
end

function Perf.setLoops(run)
    for i = #Perf.loops, 1, -1 do
        local e = Perf.loops[i]
        if not e.obj or not e.obj:IsDescendantOf(game) then
            table.remove(Perf.loops, i)
        elseif Perf.root and e.obj:IsDescendantOf(Perf.root) then
            pcall(function()
                if run then e.tween:Play() else e.tween:Pause() end
            end)
        end
    end
end

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end

local function corner(o, px) return new("UICorner", { CornerRadius = UDim.new(0, px or 10) }, o) end
local function round(o)      return new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, o) end
local function stroke(o, color, thick, transp)
    return new("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thick or 1,
        Transparency = transp or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
end

local function grad(o, c0, c1, rot)
    return new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 0 }, o)
end

local function bgLayer(parent, c0, c1, rot)
    local f = new("Frame", {
        Name = "BG",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, parent)
    grad(f, c0, c1, rot or 135)
    return f
end

local function rgbStroke(o, thick)
    local s = stroke(o, WHITE, thick or 2)
    local g = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Theme.Red),
            ColorSequenceKeypoint.new(0.5, Theme.Blue),
            ColorSequenceKeypoint.new(1,   Theme.Red),
        }),
    }, s)
    loop(g, { Rotation = 360 }, 4)
    return s, g
end

local function shimmerText(lbl)
    local g = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Theme.Red),
            ColorSequenceKeypoint.new(0.5, WHITE),
            ColorSequenceKeypoint.new(1,   Theme.Blue),
        }),
        Offset = Vector2.new(-0.6, 0),
    }, lbl)
    loop(g, { Offset = Vector2.new(0.6, 0) }, 2.2, ES.Sine, true)
    return g
end

local userScale, scaleBase = 1, 1
local anonymous = false
local function shownName()
    return anonymous and "Anonymous" or player.DisplayName
end

local visible, minimised, closing, ready = false, false, false, false
local PopScale
local function computeScale()
    local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local fitMax = math.min((vp.X - 20) / WIN_W, (vp.Y - 20) / WIN_H)
    local base = math.min(1, fitMax)
    scaleBase = math.clamp(base * userScale, 0.45, math.max(fitMax, 0.45))
end
computeScale()

local blur = new("BlurEffect", { Name = "TrigoBlur", Size = 0 }, Lighting)
local SG = new("ScreenGui", {
    Name = HUB_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent())

local function buildYinYang(parent, size)
    local root = new("Frame", {
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
    }, parent)
    local ring = new("Frame", {
        Size = UDim2.new(1, 8, 1, 8),
        Position = UDim2.fromOffset(-4, -4),
        BackgroundTransparency = 1,
    }, root)
    round(ring)
    rgbStroke(ring, 2)
    local base = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
    }, root)
    round(base)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,     Theme.Blue),
            ColorSequenceKeypoint.new(0.5,   Theme.Blue),
            ColorSequenceKeypoint.new(0.501, Theme.Red),
            ColorSequenceKeypoint.new(1,     Theme.Red),
        }),
    }, base)
    local top = new("Frame", {
        Size = UDim2.fromScale(0.5, 0.5),
        Position = UDim2.fromScale(0.25, 0),
        BackgroundColor3 = Theme.Blue,
        BorderSizePixel = 0,
    }, root)
    round(top)
    local bot = new("Frame", {
        Size = UDim2.fromScale(0.5, 0.5),
        Position = UDim2.fromScale(0.25, 0.5),
        BackgroundColor3 = Theme.Red,
        BorderSizePixel = 0,
    }, root)
    round(bot)
    local dotTop = new("Frame", {
        Size = UDim2.fromScale(0.15, 0.15),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.25),
        BackgroundColor3 = Theme.Red,
        BorderSizePixel = 0,
    }, root)
    round(dotTop)
    local dotBot = new("Frame", {
        Size = UDim2.fromScale(0.15, 0.15),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.75),
        BackgroundColor3 = Theme.Blue,
        BorderSizePixel = 0,
    }, root)
    round(dotBot)
    stroke(base, WHITE, math.max(1.5, size / 40), 0.25)
    loop(root, { Rotation = 360 }, 3.2)
    local breathe = new("UIScale", { Scale = 1 }, root)
    loop(breathe, { Scale = 1.08 }, 1.3, ES.Sine, true)
    return root
end

local ParticleBG = new("Frame", {
    Name = "ParticleBG",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = WHITE,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 1,
}, SG)
grad(ParticleBG, Color3.fromRGB(34, 6, 24), Color3.fromRGB(5, 10, 40), 45)
local pFade = new("NumberValue", { Value = 0 }, SG)
local shapes  = { "▲", "■", "●", "▶", "◆" }
local pColors = {
    Color3.fromRGB(240, 50, 80), Color3.fromRGB(60, 120, 255),
    Color3.fromRGB(190, 25, 55), Color3.fromRGB(80, 140, 255),
    Color3.fromRGB(255, 90, 110),
}
math.randomseed(tick())
local particles = {}
local function resetParticle(p, anywhere)
    p.x  = math.random()
    p.y  = anywhere and math.random() or (1.05 + math.random() * 0.1)
    p.vx = (math.random() - 0.5) * 0.02
    p.vy = -(0.03 + math.random() * 0.07)
    p.rot = math.random(0, 360)
    p.vr  = (math.random() - 0.5) * 90
    p.ph  = math.random() * 6.28
    p.base = 0.35 + math.random() * 0.45
end
for i = 1, 36 do
    local s = math.random(9, 20)
    local lbl = new("TextLabel", {
        Size = UDim2.fromOffset(s, s),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Text = shapes[math.random(1, #shapes)],
        TextColor3 = pColors[math.random(1, #pColors)],
        TextTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextScaled = true,
        ZIndex = 2,
    }, ParticleBG)
    local p = { obj = lbl }
    resetParticle(p, true)
    particles[i] = p
end

local clock = 0
local pConn = connect(RunService.Heartbeat, function(dt)
    clock += dt
    local f = pFade.Value
    for _, p in ipairs(particles) do
        p.y += p.vy * dt
        p.x += p.vx * dt + math.sin(clock * 0.8 + p.ph) * 0.0005
        p.rot += p.vr * dt
        if p.y < -0.08 then resetParticle(p, false) end
        local o = p.obj
        o.Position = UDim2.fromScale(p.x, p.y)
        o.Rotation = p.rot
        o.TextTransparency = 1 - p.base * f * (0.65 + 0.35 * math.sin(clock * 2 + p.ph))
    end
end)

local LC_W, LC_H = 300, 228
local LoadCard = new("CanvasGroup", {
    Name = "LoadCard",
    Size = UDim2.fromOffset(LC_W, LC_H),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = Theme.BG,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    Visible = false,
    ZIndex = 5,
}, SG)
corner(LoadCard, 20)
bgLayer(LoadCard, Color3.fromRGB(26, 8, 38), Color3.fromRGB(6, 16, 46), 135)
local loadScale = new("UIScale", { Scale = 0.7 }, LoadCard)
local loadOutline = new("Frame", {
    Size = UDim2.fromOffset(LC_W, LC_H),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundTransparency = 1,
    ZIndex = 6,
    Visible = false,
}, SG)
corner(loadOutline, 20)
local loadStroke = rgbStroke(loadOutline, 2)
loadStroke.Transparency = 1
local loadOutScale = new("UIScale", { Scale = 0.7 }, loadOutline)
local logo = buildYinYang(LoadCard, 70)
logo.AnchorPoint = Vector2.new(0.5, 0)
logo.Position = UDim2.new(0.5, 0, 0, 26)
local titleLbl = new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 36),
    Position = UDim2.fromOffset(0, 108),
    BackgroundTransparency = 1,
    Text = "Trigo Hub",
    Font = Enum.Font.GothamBlack,
    TextSize = 28,
    TextColor3 = WHITE,
}, LoadCard)
shimmerText(titleLbl)
new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.fromOffset(0, 143),
    BackgroundTransparency = 1,
    Text = "by EvaD",
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextColor3 = Theme.Sub,
}, LoadCard)
local pTrack = new("Frame", {
    Size = UDim2.fromOffset(220, 6),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 174),
    BackgroundColor3 = Color3.fromRGB(26, 24, 50),
    BorderSizePixel = 0,
}, LoadCard)
round(pTrack)
local pFill = new("Frame", {
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = WHITE,
    BorderSizePixel = 0,
}, pTrack)
round(pFill)
grad(pFill, Theme.Red, Theme.Blue, 0)
local statusLbl = new("TextLabel", {
    Size = UDim2.fromOffset(150, 16),
    Position = UDim2.fromOffset(40, 190),
    BackgroundTransparency = 1,
    Text = "Initializing...",
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextColor3 = Theme.Sub,
    TextXAlignment = Enum.TextXAlignment.Left,
}, LoadCard)
local pctLbl = new("TextLabel", {
    Size = UDim2.fromOffset(60, 16),
    Position = UDim2.new(1, -100, 0, 190),
    BackgroundTransparency = 1,
    Text = "0%",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = Theme.Text,
    TextXAlignment = Enum.TextXAlignment.Right,
}, LoadCard)
local progress = new("NumberValue", { Value = 0 }, SG)
connect(progress.Changed, function(v)
    pFill.Size = UDim2.fromScale(v, 1)
    pctLbl.Text = math.floor(v * 100 + 0.5) .. "%"
end)

local function setStatus(text)
    tw(statusLbl, { TextTransparency = 1 }, 0.12)
    task.wait(0.12)
    statusLbl.Text = text
    tw(statusLbl, { TextTransparency = 0 }, 0.2)
end

local Window = new("Frame", {
    Name = "Window",
    Size = UDim2.fromOffset(WIN_W, WIN_H),
    Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 10,
}, SG)
Perf.root = Window
local Scaler = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundTransparency = 1,
}, Window)
PopScale = new("UIScale", { Scale = scaleBase * 0.82 }, Scaler)
local Shadow = new("ImageLabel", {
    Size = UDim2.new(1, 50, 1, 50),
    Position = UDim2.fromOffset(-25, -25),
    BackgroundTransparency = 1,
    Image = "rbxassetid://6014261993",
    ImageColor3 = Color3.new(0, 0, 0),
    ImageTransparency = 1,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(49, 49, 450, 450),
    ZIndex = 1,
}, Scaler)
local Main = new("CanvasGroup", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Theme.BG,
    BorderSizePixel = 0,
    BackgroundTransparency = 1,
    GroupTransparency = 1,
    ZIndex = 2,
}, Scaler)
corner(Main, 18)
bgLayer(Main, Color3.fromRGB(21, 11, 31), Color3.fromRGB(7, 15, 35), 135).BackgroundTransparency = Theme.Glass.Window

do
    local bg = Main:FindFirstChild("BG")
    local g = bg and bg:FindFirstChildOfClass("UIGradient")
    if g then
        local palette = {
            { Color3.fromRGB(52, 18, 68), Color3.fromRGB(11, 24, 74) },
            { Color3.fromRGB(82, 16, 39), Color3.fromRGB(15, 21, 80) },
            { Color3.fromRGB(16, 54, 76), Color3.fromRGB(48, 15, 74) },
            { Color3.fromRGB(11, 64, 58), Color3.fromRGB(18, 23, 78) },
            { Color3.fromRGB(72, 22, 66), Color3.fromRGB(12, 42, 88) },
        }
        local PERIOD = 4
        local phase, acc = 0, 0
        connect(RunService.Heartbeat, function(dt)
            if not visible or minimised then return end
            if os.clock() < (Perf.animUntil or 0) then return end
            acc += dt
            if acc < 1 / 8 then return end
            phase += acc / PERIOD
            acc = 0
            local n = #palette
            local whole = math.floor(phase)
            local a = phase - whole
            a = a * a * (3 - 2 * a)
            local from = palette[whole % n + 1]
            local to = palette[(whole + 1) % n + 1]
            g.Color = ColorSequence.new(from[1]:Lerp(to[1], a), from[2]:Lerp(to[2], a))
            g.Rotation = (135 + phase * 12) % 360
        end)
    end
end

local Outline = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex = 3,
}, Scaler)
corner(Outline, 18)
local outlineStroke = rgbStroke(Outline, 2)
outlineStroke.Transparency = 1

Perf.Side = new("Frame", {
    Name = "Side",
    Size = UDim2.new(0, SIDE_W, 1, 0),
    BackgroundColor3 = Color3.fromRGB(9, 10, 20),
    BackgroundTransparency = Theme.Glass.Side,
    BorderSizePixel = 0,
    ZIndex = 2,
}, Main)

grad(new("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 0, BAR_H - 1),
    BackgroundColor3 = WHITE,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    ZIndex = 3,
}, Perf.Side), Theme.Red, Theme.Blue, 0)

new("Frame", {
    Name = "BrandDrag",
    Size = UDim2.new(1, 0, 0, BAR_H),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 2,
}, Perf.Side)

local TopBar = new("Frame", {
    Size = UDim2.new(1, -SIDE_W, 0, BAR_H),
    Position = UDim2.fromOffset(SIDE_W, 0),
    BackgroundColor3 = WHITE,
    BackgroundTransparency = Theme.Glass.Bar,
    BorderSizePixel = 0,
}, Main)
new("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(34, 11, 44)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(12, 16, 30)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(17, 29, 68)),
    }),
}, TopBar)

local miniLogo = buildYinYang(Perf.Side, 24)
miniLogo.Position = UDim2.fromOffset(10, 9)
local titleTxt = new("TextLabel", {
    Size = UDim2.new(1, -46, 0, 18),
    Position = UDim2.fromOffset(40, 5),
    BackgroundTransparency = 1,
    Text = "Trigo Hub",
    Font = Enum.Font.GothamBlack,
    TextSize = 15,
    TextColor3 = WHITE,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 4,
}, Perf.Side)
shimmerText(titleTxt)
new("TextLabel", {
    Size = UDim2.new(1, -46, 0, 12),
    Position = UDim2.fromOffset(40, 24),
    BackgroundTransparency = 1,
    Text = "by EvaD • v0.0.1",
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = Theme.Sub,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 4,
}, Perf.Side)
Perf.PageTitle = new("TextLabel", {
    Size = UDim2.new(1, -256, 1, 0),
    Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1,
    Text = "Home",
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextColor3 = WHITE,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 2,
}, TopBar)
local barLine = new("Frame", {
    Size = UDim2.new(1, -SIDE_W, 0, 1),
    Position = UDim2.new(0, SIDE_W, 0, BAR_H - 1),
    BackgroundColor3 = WHITE,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    ZIndex = 2,
}, Main)
grad(barLine, Theme.Red, Theme.Blue, 0)

local function winBtn(label, rightPad, baseColor, hoverColor)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.new(1, -rightPad, 0.5, -12),
        BackgroundColor3 = baseColor,
        AutoButtonColor = false,
        Text = label,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, TopBar)
    corner(b, 7)
    local sc = new("UIScale", { Scale = 1 }, b)
    connect(b.MouseEnter, function()
        tw(b, { BackgroundColor3 = hoverColor }, 0.18)
        tw(sc, { Scale = 1.12 }, 0.25, ES.Back)
    end)
    connect(b.MouseLeave, function()
        tw(b, { BackgroundColor3 = baseColor }, 0.18)
        tw(sc, { Scale = 1 }, 0.25, ES.Back)
    end)
    connect(b.MouseButton1Down, function() tw(sc, { Scale = 0.86 }, 0.1) end)
    connect(b.MouseButton1Up,   function() tw(sc, { Scale = 1.12 }, 0.2, ES.Back) end)
    return b
end

local SearchFrame = new("Frame", {
    Name = "SearchBar",
    Size = UDim2.fromOffset(150, 24),
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -76, 0, 11),
    BackgroundColor3 = Color3.fromRGB(12, 15, 24),
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    ZIndex = 6,
}, Main)
corner(SearchFrame, 8)
local SearchStroke = stroke(SearchFrame, Theme.Stroke, 1, 0.35)
new("TextLabel", {
    Size = UDim2.fromOffset(20, 24),
    Position = UDim2.fromOffset(6, 0),
    BackgroundTransparency = 1,
    Text = "🔍",
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextColor3 = Theme.Sub,
    ZIndex = 7,
}, SearchFrame)
local SearchBox = new("TextBox", {
    Size = UDim2.new(1, -52, 1, 0),
    Position = UDim2.fromOffset(26, 0),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = "Search features...",
    PlaceholderColor3 = Theme.Sub,
    ClearTextOnFocus = false,
    Font = Enum.Font.GothamMedium,
    TextSize = 14,
    TextColor3 = Theme.Text,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
}, SearchFrame)
local SearchClear = new("TextButton", {
    Size = UDim2.fromOffset(22, 24),
    Position = UDim2.new(1, -24, 0, 0),
    BackgroundTransparency = 1,
    Text = "X",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = Theme.Sub,
    Visible = false,
    ZIndex = 8,
}, SearchFrame)
connect(SearchBox.Focused, function() tw(SearchStroke, { Color = Theme.Red, Transparency = 0.05 }, 0.2) end)
connect(SearchBox.FocusLost, function() tw(SearchStroke, { Color = Theme.Stroke, Transparency = 0.35 }, 0.25) end)
local BtnClose = winBtn("X", 34, Color3.fromRGB(125, 20, 42), Color3.fromRGB(230, 50, 70))
local BtnMin   = winBtn("—", 64, Color3.fromRGB(20, 28, 86),  Color3.fromRGB(44, 86, 210))
local Body = new("CanvasGroup", {
    Size = UDim2.new(1, -SIDE_W, 1, -BAR_H),
    Position = UDim2.fromOffset(SIDE_W, BAR_H),
    BackgroundTransparency = 1,
}, Main)
Perf.SideBody = new("CanvasGroup", {
    Name = "SideBody",
    Size = UDim2.new(1, 0, 1, -BAR_H),
    Position = UDim2.fromOffset(0, BAR_H),
    BackgroundTransparency = 1,
    ZIndex = 3,
}, Perf.Side)
local Sidebar = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -SBAR_H),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = Theme.Red,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(),
}, Perf.SideBody)
local sideLine = new("Frame", {
    Size = UDim2.new(0, 1, 1, 0),
    Position = UDim2.fromOffset(SIDE_W - 1, 0),
    BackgroundColor3 = WHITE,
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    ZIndex = 6,
}, Main)
grad(sideLine, Theme.Red, Theme.Blue, 90)

local Content = new("Frame", {
    Size = UDim2.new(1, -20, 1, -16),
    Position = UDim2.fromOffset(10, 8),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, Body)

local Indicator = new("Frame", {
    Size = UDim2.new(1, -12, 0, 30),
    Position = UDim2.fromOffset(6, 8),
    BackgroundColor3 = WHITE,
    BorderSizePixel = 0,
    ZIndex = 1,
}, Sidebar)
corner(Indicator, 9)
grad(Indicator, Color3.fromRGB(185, 28, 58), Color3.fromRGB(38, 84, 210), 0)
local pill = new("Frame", {
    Size = UDim2.fromOffset(3, 14),
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 5, 0.5, 0),
    BackgroundColor3 = WHITE,
    BorderSizePixel = 0,
    ZIndex = 2,
}, Indicator)
round(pill)

Perf.glassFX = function()
    local kp = NumberSequenceKeypoint.new
    local layer = new("Frame", {
        Name = "GlassFX",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 500,
    }, Main)
    corner(layer, 16)
    local rim = stroke(layer, WHITE, 1.5, 0.2)
    new("UIGradient", {
        Rotation = 45,
        Transparency = NumberSequence.new({ kp(0, 0), kp(0.4, 0.7), kp(0.7, 0.9), kp(1, 0.35) }),
    }, rim)
end
Perf.glassFX()

local SBar = new("Frame", {
    Size = UDim2.new(1, -16, 0, SBAR_H - 14),
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 8, 1, -8),
    BackgroundColor3 = Theme.Panel2,
    BackgroundTransparency = Theme.Glass.Status,
    BorderSizePixel = 0,
    ZIndex = 3,
}, Perf.SideBody)
corner(SBar, 10)
stroke(SBar, Theme.Stroke, 1, 0.45)
SBar.Visible = false

do
    local av = new("ImageLabel", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.fromOffset(8, 8),
        BackgroundColor3 = Theme.Dark,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, SBar)
    round(av)
    local mask = new("TextLabel", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1,
        Text = "?",
        Font = Enum.Font.GothamBlack,
        TextSize = 14,
        TextColor3 = Theme.Sub,
        TextTransparency = 1,
        ZIndex = 5,
    }, SBar)
    Perf.footAvatar, Perf.footMask = av, mask
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(player.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
        if ok and av.Parent then av.Image = img end
    end)
end

local dot = new("Frame", {
    Size = UDim2.fromOffset(8, 8),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromOffset(33, 33),
    BackgroundColor3 = Theme.Green,
    BorderSizePixel = 0,
    ZIndex = 6,
}, SBar)
round(dot)
stroke(dot, Theme.Panel2, 2)
loop(dot, { BackgroundTransparency = 0.7 }, 1, ES.Sine, true)
local statusTxt = new("TextLabel", {
    Size = UDim2.new(1, -52, 0, 16),
    Position = UDim2.fromOffset(44, 7),
    BackgroundTransparency = 1,
    Text = shownName(),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = Theme.Text,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 4,
}, SBar)
local fpsLbl = new("TextLabel", {
    Size = UDim2.new(1, -52, 0, 14),
    Position = UDim2.fromOffset(44, 23),
    BackgroundTransparency = 1,
    Text = "Ready • -- FPS",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Theme.Sub,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 4,
}, SBar)

local live = {}
local StatsService = game:GetService("Stats")
local YELLOW = Color3.fromRGB(255, 200, 70)
local function pingMs()
    local ok, v = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and math.floor(v + 0.5) or nil
end
local frames, acc = 0, 0
connect(RunService.Heartbeat, function(dt)
    frames += 1
    acc += dt
    if acc >= 0.5 then
        local fps = math.floor(frames / acc + 0.5)
        frames, acc = 0, 0
        fpsLbl.Text = "Ready • " .. fps .. " FPS"
        if visible and live.update then live.update(fps, pingMs()) end
    end
end)
local function applyScale()
    computeScale()
    if visible then tw(PopScale, { Scale = scaleBase }, 0.3) end
end
if camera then connect(camera:GetPropertyChangedSignal("ViewportSize"), applyScale) end

local ToastHolder = new("Frame", {
    Size = UDim2.new(0, 230, 1, -24),
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -12, 0, 12),
    BackgroundTransparency = 1,
    ZIndex = 100,
}, SG)
new("UIListLayout", {
    Padding = UDim.new(0, 6),
    VerticalAlignment = Enum.VerticalAlignment.Top,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, ToastHolder)

local function notify(title, body, duration)
    duration = duration or 3
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
    }, ToastHolder)
    local toast = new("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.fromOffset(260, 0),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        GroupTransparency = 1,
    }, holder)
    corner(toast, 12)
    stroke(toast, Theme.Stroke, 1, 0.3)
    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 1, -16),
        Position = UDim2.fromOffset(8, 8),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
    }, toast)
    round(bar)
    grad(bar, Theme.Red, Theme.Blue, 90)
    new("TextLabel", {
        Size = UDim2.new(1, -28, 0, 16),
        Position = UDim2.fromOffset(20, 7),
        BackgroundTransparency = 1,
        Text = title,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, toast)
    new("TextLabel", {
        Size = UDim2.new(1, -28, 0, 18),
        Position = UDim2.fromOffset(20, 24),
        BackgroundTransparency = 1,
        Text = body or "",
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, toast)
    local timer = new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
    }, toast)
    grad(timer, Theme.Red, Theme.Blue, 0)
    tw(holder, { Size = UDim2.new(1, 0, 0, 50) }, 0.35)
    tw(toast, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, 0.5, ES.Back)
    tw(timer, { Size = UDim2.new(0, 0, 0, 2) }, duration, ES.Linear)
    task.delay(duration, function()
        tw(toast, { Position = UDim2.fromOffset(260, 0), GroupTransparency = 1 }, 0.4, ES.Quint, ED.In)
        task.wait(0.3)
        tw(holder, { Size = UDim2.new(1, 0, 0, 0) }, 0.3)
        task.wait(0.35)
        holder:Destroy()
    end)
end

local function ripple(el, x, y, accent)
    local s = PopScale.Scale
    local rel = (Vector2.new(x, y) - el.AbsolutePosition) / s
    local d = math.max(el.AbsoluteSize.X, el.AbsoluteSize.Y) / s * 2.4
    local r = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(rel.X, rel.Y),
        Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = accent or Theme.Red,
        BackgroundTransparency = 0.62,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, el)
    round(r)
    tw(r, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 }, 0.48, ES.Quint)
    task.delay(0.65, function() r:Destroy() end)
end

local function hoverable(el, st, hit, accent)
    local restEdge = st.Transparency
    connect(hit.MouseEnter, function()
        tw(el, { BackgroundColor3 = Theme.Panel2 }, 0.2)
        tw(st, { Color = accent or Theme.Red, Transparency = 0.2 }, 0.25)
    end)
    connect(hit.MouseLeave, function()
        tw(el, { BackgroundColor3 = Theme.Panel }, 0.25)
        tw(st, { Color = WHITE, Transparency = restEdge }, 0.25)
    end)
end

local Search = { active = false }
local function tagRow(holder, page, text)
    local prev = holder:GetAttribute("STxt")
    holder:SetAttribute("STxt", prev and (prev .. " " .. tostring(text)) or tostring(text))
    holder:SetAttribute("SSec", page.curSection or "")
    holder:SetAttribute("SN", (holder:GetAttribute("SN") or 0) + 1)
    if not prev and page.curOrd then holder:SetAttribute("SOrd", page.curOrd) end
    if not prev then
        page.rows = page.rows or {}
        page.rows[#page.rows + 1] = holder
    end
end

local function row(page, height, plain, isHead)
    page.buttonRow = nil
    local inCard = (not isHead) and Theme.inSec(page)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        LayoutOrder = #page.items + 1,
    }, page.scroll)
    if inCard then holder:SetAttribute("InCard", true) end
    local el = new("CanvasGroup", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = plain and 1 or (inCard and Theme.Glass.Inner or Theme.Glass.Card),
        BorderSizePixel = 0,
    }, holder)
    local st
    if not plain then
        corner(el, inCard and 8 or 10)
        local edge = new("Frame", {
            Size = UDim2.new(1, -2, 1, -2),
            Position = UDim2.fromOffset(1, 1),
            BackgroundTransparency = 1,
            ZIndex = 9,
        }, el)
        corner(edge, inCard and 7 or 9)
        st = stroke(edge, WHITE, 1, inCard and 0.86 or Theme.Glass.Edge)
        new("UIGradient", {
            Rotation = 45,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.5, 0.55),
                NumberSequenceKeypoint.new(1, 0.15),
            }),
        }, st)
    end
    page.items[#page.items + 1] = el
    return holder, el, st
end

local function Section(page, text)
    text = tostring(text)
    page.curSection = text
    local sh, el = row(page, 34, true, true)
    sh:SetAttribute("SHead", text)
    page.secHeads = page.secHeads or {}
    page.secHeads[text] = sh
    page.collapsed = page.collapsed or {}
    page.secUI = page.secUI or {}
    local chip = new("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(7, 7),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, el)
    corner(chip, 6)
    grad(chip, Theme.Red, Theme.Blue, 45)
    local chipScale = new("UIScale", { Scale = 1 }, chip)
    local gem = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(6, 6),
        Rotation = 45,
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, chip)
    corner(gem, 2)
    local title = new("TextLabel", {
        Size = UDim2.new(1, -78, 1, 0),
        Position = UDim2.fromOffset(33, 0),
        BackgroundTransparency = 1,
        Text = string.upper(text),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    }, el)
    local badge = new("Frame", {
        Size = UDim2.fromOffset(18, 14),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -24, 0.5, 0),
        BackgroundColor3 = Theme.Dark,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2,
    }, el)
    round(badge)
    stroke(badge, Theme.Stroke, 1, 0.55)
    local badgeTxt = new("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "0",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Theme.Sub,
        ZIndex = 3,
    }, badge)
    local chev = new("TextLabel", {
        Size = UDim2.fromOffset(16, 34),
        Position = UDim2.new(1, -22, 0, 0),
        BackgroundTransparency = 1,
        Text = "v",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Theme.Sub,
        ZIndex = 2,
    }, el)
    local line = new("Frame", {
        Size = UDim2.new(1, -16, 0, 1),
        Position = UDim2.new(0, 8, 1, -1),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, el)
    grad(line, Theme.Red, Theme.Blue, 0)
    local hit = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
    }, el)
    connect(hit.MouseEnter, function()
        tw(gem, { Rotation = 135 }, 0.4, ES.Quint)
        tw(chipScale, { Scale = 1.1 }, 0.25, ES.Back)
        tw(chev, { TextColor3 = Theme.Text }, 0.15)
    end)
    connect(hit.MouseLeave, function()
        tw(gem, { Rotation = 45 }, 0.4, ES.Quint)
        tw(chipScale, { Scale = 1 }, 0.25, ES.Back)
        tw(chev, { TextColor3 = Theme.Sub }, 0.2)
    end)
    connect(hit.MouseButton1Down, function() tw(chipScale, { Scale = 0.88 }, 0.1, ES.Quint) end)
    connect(hit.MouseButton1Up, function() tw(chipScale, { Scale = 1 }, 0.25, ES.Back) end)
    connect(hit.MouseButton1Click, function()
        local f = page.secToggle and page.secToggle[text]
        if f then f() end
    end)
    page.secUI[text] = { chev = chev, title = title, badge = badge, badgeTxt = badgeTxt, line = line }
end

local function Label(page, text)
    local _, el = row(page, 36)
    new("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Sub,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, el)
end

local function Button(page, text, callback)
    local sec = Theme.inSec(page)
    local BTN_H = sec and 42 or 44
    local pair = page.buttonRow
    if not pair or pair.count >= 1 then
        local holder, el = row(page, BTN_H, true)
        pair = { holder = holder, el = el, count = 0, tiles = {} }
        page.buttonRow = pair
    end
    local el = pair.el
    pair.count += 1
    tagRow(pair.holder, page, text)
    local slot = pair.count
    local tile = new("Frame", {
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Theme.Panel2,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, el)
    corner(tile, 10)
    local tileStroke = stroke(tile, Theme.Stroke, 1, 0.5)
    local base = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(30, 26, 62),
        BackgroundTransparency = Theme.Glass.Tile,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, tile)
    corner(base, 10)
    local glow = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Red,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, tile)
    corner(glow, 10)
    new("Frame", {
        Size = UDim2.new(1, -20, 0, 1),
        Position = UDim2.fromOffset(10, 1),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, tile)
    local bar = new("Frame", {
        Size = UDim2.new(0, 4, 1, -14),
        Position = UDim2.fromOffset(8, 7),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, tile)
    corner(bar, 2)
    grad(bar, Theme.Red, Theme.Blue, 90)
    local label = new("TextLabel", {
        Size = UDim2.new(1, -46, 1, 0),
        Position = UDim2.fromOffset(20, 0),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = WHITE,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    }, tile)
    local icon = new("TextLabel", {
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.new(1, -28, 0.5, -10),
        BackgroundTransparency = 1,
        Text = "→",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Theme.Sub,
        ZIndex = 6,
    }, tile)
    local iconX = -28
    local hit = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 8,
    }, tile)
    local pressScale = new("UIScale", { Scale = 1 }, tile)
    pair.tiles[slot] = tile
    if slot == 1 then
        tile.Size = UDim2.new(1, -4, 1, -4)
        tile.Position = UDim2.fromOffset(2, 2)
    else
        local first = pair.tiles[1]
        first.Size = UDim2.new(0.5, -6, 1, -4)
        first.Position = UDim2.fromOffset(2, 2)
        tile.Size = UDim2.new(0.5, -6, 1, -4)
        tile.Position = UDim2.new(0.5, 4, 0, 2)
    end
    local token = 0
    connect(hit.MouseEnter, function()
        tw(glow, { BackgroundTransparency = 0.8 }, 0.18)
        tw(tileStroke, { Color = Theme.Red, Transparency = 0.1 }, 0.16)
        tw(icon, { Position = UDim2.new(1, iconX + 4, 0.5, -10), TextColor3 = Theme.Red }, 0.16)
        tw(bar, { Size = UDim2.new(0, 4, 1, -10), Position = UDim2.fromOffset(8, 5) }, 0.16)
    end)
    connect(hit.MouseLeave, function()
        tw(glow, { BackgroundTransparency = 1 }, 0.22)
        tw(tileStroke, { Color = Theme.Stroke, Transparency = 0.5 }, 0.2)
        tw(icon, { Position = UDim2.new(1, iconX, 0.5, -10), TextColor3 = Theme.Sub }, 0.2)
        tw(bar, { Size = UDim2.new(0, 4, 1, -14), Position = UDim2.fromOffset(8, 8) }, 0.2)
        tw(pressScale, { Scale = 1 }, 0.14, ES.Quint)
    end)
    connect(hit.MouseButton1Down, function(x, y)
        pcall(ripple, tile, x, y)
        tw(glow, { BackgroundTransparency = 0.55 }, 0.08)
        tw(pressScale, { Scale = 0.95 }, 0.09, ES.Quint)
    end)
    connect(hit.MouseButton1Up, function()
        tw(glow, { BackgroundTransparency = 0.8 }, 0.18)
        tw(pressScale, { Scale = 1 }, 0.22, ES.Back)
        if game:GetService("UserInputService").TouchEnabled then
            task.delay(0.2, function()
                tw(glow, { BackgroundTransparency = 1 }, 0.22)
                tw(tileStroke, { Color = Theme.Stroke, Transparency = 0.5 }, 0.2)
                tw(icon, { Position = UDim2.new(1, iconX, 0.5, -10), TextColor3 = Theme.Sub }, 0.2)
                tw(bar, { Size = UDim2.new(0, 4, 1, -14), Position = UDim2.fromOffset(8, 8) }, 0.2)
            end)
        end
    end)
    connect(hit.MouseButton1Click, function()
        pcall(callback)
        token += 1
        local my = token
        icon.Text = "✓"
        icon.TextColor3 = Theme.Green
        task.delay(0.7, function()
            if my == token then
                icon.Text = "→"
                icon.TextColor3 = Theme.Sub
            end
        end)
    end)
end

local function TextInput(page, text, default, placeholder, callback)
    local sec = false
    local holder, el, st = row(page, sec and 56 or 42)
    tagRow(holder, page, text)
    new("TextLabel", {
        Size = sec and UDim2.new(1, -18, 0, 16) or UDim2.new(0.42, -8, 1, 0),
        Position = sec and UDim2.fromOffset(9, 5) or UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.GothamMedium,
        TextSize = sec and 12 or 13,
        TextColor3 = Theme.Text,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    }, el)
    local field = new("TextBox", {
        Size = sec and UDim2.new(1, -18, 0, 26) or UDim2.new(0.58, -22, 0, 28),
        Position = sec and UDim2.fromOffset(9, 24) or UDim2.new(0.42, 0, 0.5, -14),
        BackgroundColor3 = Theme.Panel2,
        BorderSizePixel = 0,
        Text = tostring(default or ""),
        PlaceholderText = tostring(placeholder or "Enter value"),
        PlaceholderColor3 = Theme.Sub,
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
    }, el)
    corner(field, 7)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, field)
    connect(field.FocusLost, function()
        local ok, err = pcall(callback, field.Text)
        if not ok then notify(text, "Error: " .. tostring(err):sub(1, 65), 3) end
    end)
    return field
end

local VisibleToggles = {}
local function Toggle(page, text, default, callback)
    local sec = Theme.inSec(page)
    local holder, el, st = row(page, sec and 42 or 40)
    tagRow(holder, page, text)
    local trkW, trkH, knobS = 40, 22, 16
    if sec then trkW, trkH, knobS = 36, 20, 14 end
    local pad = sec and 9 or 12
    new("TextLabel", {
        Size = UDim2.new(1, sec and -(pad + trkW + 14) or -64, 1, 0),
        Position = UDim2.fromOffset(pad, 0),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = sec and 12 or 13,
        TextColor3 = Theme.Text,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    }, el)
    local track = new("Frame", {
        Size = UDim2.fromOffset(trkW, trkH),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, sec and -8 or -10, 0.5, 0),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, el)
    round(track)
    grad(track, Theme.Red, Theme.Blue, 0)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(knobS, knobS),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, track)
    round(knob)
    local knobScale = new("UIScale", { Scale = 1 }, knob)
    local hit = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 4,
    }, el)
    local state = default and true or false
    local function render(animate)
        local t = animate and 0.35 or 0
        tw(track, { BackgroundColor3 = state and WHITE or Theme.Off }, t)
        tw(knob, { Position = state and UDim2.new(1, -(knobS + 3), 0.5, 0) or UDim2.new(0, 3, 0.5, 0) },
            t, ES.Back)
    end
    render(false)
    hoverable(el, st, hit)
    connect(hit.MouseButton1Down, function() tw(knobScale, { Scale = 1.25 }, 0.12) end)
    connect(hit.MouseButton1Up, function() tw(knobScale, { Scale = 1 }, 0.2, ES.Back) end)
    connect(hit.MouseButton1Click, function()
        state = not state
        render(true)
        pcall(callback, state)
        if TweenEvaluate then pcall(TweenEvaluate, not state) end
        Perf.cfgDirty()
    end)
    local api = {
        Set = function(v) state = v and true or false render(true) pcall(callback, state) if TweenEvaluate then pcall(TweenEvaluate, not state) end Perf.cfgDirty() end,
        Get = function() return state end,
    }
    VisibleToggles[text] = api
    return api
end

local VisibleSliders = {}
local SliderDrag = { input = nil, release = nil }
local function Slider(page, text, min, max, default, step, suffix, callback)
    local sec = Theme.inSec(page)
    local M = sec and 9 or 12
    local holder, el, st = row(page, 54)
    tagRow(holder, page, text)
    new("TextLabel", {
        Size = UDim2.new(1, sec and -(M + 76) or -110, 0, 20),
        Position = UDim2.fromOffset(M, 6),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = sec and 12 or 13,
        TextColor3 = Theme.Text,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    }, el)
    local valLbl = new("TextBox", {
        Size = UDim2.fromOffset(sec and 66 or 84, 22),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -M, 0, 4),
        BackgroundColor3 = Theme.BG,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "",
        ClearTextOnFocus = false,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Theme.Cyan,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 6,
    }, el)
    corner(valLbl, 6)
    local valStroke = stroke(valLbl, Theme.Cyan, 1, 0.75)
    local TM = M + 14
    local track = new("Frame", {
        Size = UDim2.new(1, -2 * TM, 0, 8),
        Position = UDim2.fromOffset(TM, 36),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, el)
    round(track)
    local fill = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, track)
    round(fill)
    grad(fill, Theme.Cyan, Theme.Teal, 0)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, track)
    round(knob)
    stroke(knob, Theme.Cyan, 3)
    local hit = new("TextButton", {
        Size = UDim2.new(1, -2 * TM, 0, 30),
        Position = UDim2.fromOffset(TM, 26),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
    }, el)
    local value = default
    local function fmt(v)
        return (step < 1 and string.format("%.2f", v) or tostring(v)) .. (suffix or "")
    end
    local function apply(v, animate)
        value = v
        local a = (v - min) / (max - min)
        local t = animate and 0.12 or 0
        tw(fill, { Size = UDim2.fromScale(a, 1) }, t, ES.Sine)
        tw(knob, { Position = UDim2.new(a, 0, 0.5, 0) }, t, ES.Sine)
        valLbl.Text = fmt(v)
    end
    apply(default, false)
    connect(valLbl.Focused, function()
        valLbl.Text = tostring(value)
        tw(valStroke, { Transparency = 0.15 }, 0.15)
        pcall(function()
            valLbl.SelectionStart = 1
            valLbl.CursorPosition = #valLbl.Text + 1
        end)
    end)
    connect(valLbl.FocusLost, function()
        tw(valStroke, { Transparency = 0.75 }, 0.2)
        local raw = (valLbl.Text:gsub(",", "."))
        local n = tonumber(raw:match("-?%d*%.?%d+"))
        if n then
            n = math.clamp(n, min, max)
            n = math.floor(n / step + 0.5) * step
            n = tonumber(string.format("%.3f", math.clamp(n, min, max)))
            if n ~= value then
                apply(n, true)
                pcall(callback, n)
                Perf.cfgDirty()
                return
            end
        end
        valLbl.Text = fmt(value)
    end)
    local function setFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = min + (max - min) * rel
        v = math.floor(v / step + 0.5) * step
        v = tonumber(string.format("%.3f", math.clamp(v, min, max)))
        if v ~= value then
            apply(v, true)
            pcall(callback, v)
            Perf.cfgDirty()
        end
    end
    local dragging, myInput = false, nil
    local function releaseDrag()
        if not dragging then return end
        dragging, myInput = false, nil
        if SliderDrag.release == releaseDrag then SliderDrag.input, SliderDrag.release = nil, nil end
        page.scroll.ScrollingEnabled = true
        tw(knob, { Size = UDim2.fromOffset(16, 16) }, 0.25, ES.Back)
    end
    hoverable(el, st, hit, Theme.Cyan)
    connect(hit.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if dragging then return end
            local cur = SliderDrag.input
            if cur then
                local ps = cur.UserInputState
                if ps ~= Enum.UserInputState.End and ps ~= Enum.UserInputState.Cancel then return end
                if SliderDrag.release then pcall(SliderDrag.release) end
                SliderDrag.input, SliderDrag.release = nil, nil
            end
            dragging, myInput = true, i
            SliderDrag.input, SliderDrag.release = i, releaseDrag
            page.scroll.ScrollingEnabled = false
            tw(knob, { Size = UDim2.fromOffset(22, 22) }, 0.2, ES.Back)
            setFromX(i.Position.X)
        end
    end)
    connect(UserInputService.InputChanged, function(i)
        if not dragging then return end
        if i == myInput or (myInput.UserInputType == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseMovement) then
            setFromX(i.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if not dragging then return end
        if i == myInput or (myInput.UserInputType == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseButton1) then
            releaseDrag()
        end
    end)
    local api = { Set = function(v) apply(v, true) pcall(callback, v) Perf.cfgDirty() end, Get = function() return value end }
    VisibleSliders[text] = api
    return api
end

local function Dropdown(page, text, options, default, callback, multi, emptyText)
    local COL, OH, GAP, PADV = 42, 30, 3, 4
    local PILL_H = 28
    Perf.VisibleDropdowns = Perf.VisibleDropdowns or {}
    local cfgKey = text
    do
        local n = 1
        while Perf.VisibleDropdowns[cfgKey] do
            n += 1
            cfgKey = text .. " #" .. n
        end
    end
    local pending, pendingMulti
    local MAX_VISIBLE = multi and 7 or 6
    local holder, el, st = row(page, COL)
    local restEdge = st.Transparency
    tagRow(holder, page, text)
    local selected = (not multi) and (default or options[1]) or nil
    local picked = {}
    if multi then
        if type(default) == "table" then
            for k, v in pairs(default) do
                if type(k) == "number" then picked[v] = true
                elseif v then picked[k] = true end
            end
        elseif default ~= nil then
            picked[default] = true
        end
    end
    local function isOn(opt)
        if multi then return picked[opt] == true end
        return opt == selected
    end
    local function summary()
        if not multi then
            if #options == 0 then return emptyText or "None" end
            return tostring(selected or "Select")
        end
        local names = {}
        for _, opt in ipairs(options) do
            if picked[opt] then names[#names + 1] = tostring(opt) end
        end
        return #names > 0 and table.concat(names, ", ") or "None"
    end
    local function calcPillW()
        local w = 96
        pcall(function()
            local TS = game:GetService("TextService")
            for _, o in ipairs(options) do
                local sz = TS:GetTextSize(tostring(o), 12, Enum.Font.GothamBold, Vector2.new(1000, 40))
                w = math.max(w, sz.X + (multi and 52 or 40))
            end
        end)
        return math.clamp(w, 96, multi and 190 or 170)
    end
    local pillW = calcPillW()
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -(pillW + 30), 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Theme.Text,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    }, el)
    local pill = new("Frame", {
        Size = UDim2.fromOffset(pillW, PILL_H),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        BackgroundColor3 = Theme.BG,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, el)
    corner(pill, 7)
    local pillStroke = stroke(pill, Theme.Amber, 1, 0.55)
    local valLbl = new("TextLabel", {
        Size = UDim2.new(1, -28, 1, 0),
        Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1,
        Text = summary(),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Theme.Amber,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, pill)
    local arrow = new("TextLabel", {
        Size = UDim2.fromOffset(16, PILL_H),
        Position = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1,
        Text = "▾",
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextColor3 = Theme.Amber,
        ZIndex = 3,
    }, pill)
    local head = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 7,
    }, el)
    local blocker = new("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 40,
    }, Scaler)
    local popup = new("Frame", {
        Size = UDim2.fromOffset(pillW, 0),
        BackgroundColor3 = Theme.Dark,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 41,
    }, Scaler)
    corner(popup, 9)
    local popStroke = stroke(popup, Theme.Amber, 1, 1)
    local list = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollBarImageColor3 = Theme.Amber,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        ZIndex = 42,
    }, popup)
    new("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    new("UIPadding", {
        PaddingTop = UDim.new(0, PADV), PaddingBottom = UDim.new(0, PADV),
        PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
    }, list)

    local SH = 32
    local query = ""
    local shown = options
    local function applyFilter()
        local q = query:lower()
        if q == "" then shown = options return end
        shown = {}
        for _, o in ipairs(options) do
            if tostring(o):lower():find(q, 1, true) then shown[#shown + 1] = o end
        end
    end
    local searchBox = new("TextBox", {
        Size = UDim2.new(1, -8, 0, SH - 6),
        Position = UDim2.fromOffset(4, 4),
        BackgroundColor3 = Theme.BG,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = "",
        PlaceholderText = "Search...",
        PlaceholderColor3 = Theme.Sub,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 44,
    }, popup)
    corner(searchBox, 6)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6) }, searchBox)
    local function fullListH()
        local m = math.min(math.max(#shown, 1), MAX_VISIBLE)
        return m * OH + (m - 1) * GAP + PADV * 2
    end
    local function canvasH()
        local n = math.max(#shown, 1)
        return n * OH + (n - 1) * GAP + PADV * 2
    end

    local buildOptions
    local open = false
    local openTok = 0
    local setOpen
    local myCloser = function() if open then setOpen(false) end end
    local openUp = false
    local trackConn
    local function stopTrack()
        if trackConn then trackConn:Disconnect() trackConn = nil end
    end
    local function startTrack()
        stopTrack()
        trackConn = RunService.RenderStepped:Connect(function()
            if not popup.Parent or not pill.Parent then stopTrack() return end
            local s = PopScale.Scale
            local rel = (pill.AbsolutePosition - Scaler.AbsolutePosition) / s
            popup.Position = UDim2.fromOffset(rel.X, openUp and (rel.Y - 4) or (rel.Y + PILL_H + 4))
        end)
    end
    local function layoutPopup()
        local s = PopScale.Scale
        local rel = (pill.AbsolutePosition - Scaler.AbsolutePosition) / s
        local pw, ph = pillW, PILL_H
        local limitH = Scaler.AbsoluteSize.Y / s
        local want = fullListH()
        local below = limitH - (rel.Y + ph + 4) - 6
        local above = rel.Y - 4 - 6
        local up = want > below and above > below
        local avail = up and above or below
        local h = math.min(want, math.max(avail - SH, OH + PADV * 2))
        openUp = up
        popup.AnchorPoint = Vector2.new(0, up and 1 or 0)
        popup.Position = UDim2.fromOffset(rel.X, up and (rel.Y - 4) or (rel.Y + ph + 4))
        list.AnchorPoint = Vector2.new(0, 0)
        list.Position = UDim2.fromOffset(0, SH)
        list.Size = UDim2.new(1, 0, 0, h)
        list.ScrollBarThickness = (canvasH() > h) and 3 or 0
        return pw, h + SH
    end

    setOpen = function(o)
        if o == open then return end
        openTok += 1
        local tok = openTok
        if o then
            local prev = page.closeDD
            if prev and prev ~= myCloser then pcall(prev) end
            page.closeDD = myCloser
            if query ~= "" or searchBox.Text ~= "" then
                query = ""
                searchBox.Text = ""
                applyFilter()
                buildOptions()
            end
            local pw, h = layoutPopup()
            open = true
            blocker.Visible = true
            popup.Size = UDim2.fromOffset(pw, 0)
            popup.BackgroundTransparency = 0.4
            popup.Visible = true
            startTrack()
            list.CanvasPosition = Vector2.new(0, 0)
            if not multi and selected then
                local idx = table.find(shown, selected)
                if idx then
                    local maxY = math.max(0, canvasH() - (h - SH))
                    list.CanvasPosition = Vector2.new(0, math.clamp((idx - 1) * (OH + GAP) - OH, 0, maxY))
                end
            end
            tw(popup, { Size = UDim2.fromOffset(pw, h), BackgroundTransparency = 0.04 }, 0.26, ES.Quint)
            tw(popStroke, { Transparency = 0.35 }, 0.2)
            tw(arrow, { Rotation = 180 }, 0.28, ES.Quint)
            tw(pillStroke, { Transparency = 0.1 }, 0.2)
            tw(st, { Color = Theme.Amber, Transparency = 0.15 }, 0.22)
        else
            open = false
            blocker.Visible = false
            if page.closeDD == myCloser then page.closeDD = nil end
            tw(popup, { Size = UDim2.fromOffset(pillW, 0), BackgroundTransparency = 0.4 }, 0.16, ES.Quad)
            tw(popStroke, { Transparency = 1 }, 0.12)
            tw(arrow, { Rotation = 0 }, 0.25, ES.Quint)
            tw(pillStroke, { Transparency = 0.55 }, 0.25)
            tw(st, { Color = WHITE, Transparency = restEdge }, 0.28)
            task.delay(0.18, function()
                if openTok == tok and popup.Parent then popup.Visible = false stopTrack() end
            end)
        end
    end

    local selectedButton, selectedStroke = nil, nil
    local ON_BG = Color3.fromRGB(78, 56, 12)
    buildOptions = function()
        for _, ch in ipairs(list:GetChildren()) do
            if ch:IsA("GuiObject") then ch:Destroy() end
        end
        selectedButton, selectedStroke = nil, nil
        list.CanvasSize = UDim2.fromOffset(0, canvasH())
        if #shown == 0 then
            new("TextLabel", {
                Size = UDim2.new(1, 0, 0, OH),
                BackgroundTransparency = 1,
                Text = (#options == 0) and (emptyText or "None") or "No results",
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextColor3 = Theme.Sub,
                ZIndex = 43,
            }, list)
            return
        end
        for i, opt in ipairs(shown) do
            local b = new("TextButton", {
                Size = UDim2.new(1, 0, 0, OH),
                LayoutOrder = i,
                BackgroundColor3 = isOn(opt) and ON_BG or Theme.Panel,
                AutoButtonColor = false,
                Text = (multi and (isOn(opt) and "[x]  " or "[  ]  ") or "") .. tostring(opt),
                Font = Enum.Font.GothamMedium,
                TextSize = 13,
                TextColor3 = Theme.Text,
                TextXAlignment = multi and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
                TextTruncate = Enum.TextTruncate.AtEnd,
                BorderSizePixel = 0,
                ZIndex = 43,
            }, list)
            if multi then new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6) }, b) end
            corner(b, 7)
            local optionStroke = stroke(b, isOn(opt) and Theme.Amber or Theme.Stroke, 1,
                isOn(opt) and 0.15 or 0.75)
            if isOn(opt) and not multi then selectedButton = b selectedStroke = optionStroke end
            connect(b.MouseButton1Down, function()
                tw(b, { BackgroundColor3 = Color3.fromRGB(104, 74, 14) }, 0.08)
            end)
            connect(b.MouseButton1Up, function()
                tw(b, { BackgroundColor3 = isOn(opt) and ON_BG or Theme.Panel2 }, 0.12)
            end)
            connect(b.MouseEnter, function()
                if not isOn(opt) then tw(b, { BackgroundColor3 = Theme.Panel2 }, 0.12) end
            end)
            connect(b.MouseLeave, function()
                if not isOn(opt) then tw(b, { BackgroundColor3 = Theme.Panel }, 0.12) end
            end)
            connect(b.MouseButton1Click, function()
                if multi then
                    picked[opt] = (not picked[opt]) or nil
                    local on = picked[opt] == true
                    b.Text = (on and "[x]  " or "[  ]  ") .. tostring(opt)
                    tw(b, { BackgroundColor3 = on and ON_BG or Theme.Panel }, 0.14, ES.Quint)
                    tw(optionStroke, { Color = on and Theme.Amber or Theme.Stroke,
                                       Transparency = on and 0.15 or 0.75 }, 0.14)
                    valLbl.Text = summary()
                    local out = {}
                    for k in pairs(picked) do out[k] = true end
                    pendingMulti = nil
                    pcall(callback, out)
                    Perf.cfgDirty()
                    return
                end
                if selectedButton and selectedButton ~= b then
                    tw(selectedButton, { BackgroundColor3 = Theme.Panel }, 0.1)
                    if selectedStroke then tw(selectedStroke, { Color = Theme.Stroke, Transparency = 0.75 }, 0.1) end
                end
                selected = opt
                selectedButton = b
                selectedStroke = optionStroke
                tw(b, { BackgroundColor3 = ON_BG }, 0.14, ES.Quint)
                tw(optionStroke, { Color = Theme.Amber, Transparency = 0.15 }, 0.14)
                valLbl.Text = summary()
                setOpen(false)
                pending = nil
                pcall(callback, opt)
                Perf.cfgDirty()
            end)
        end
    end
    buildOptions()
    connect(searchBox:GetPropertyChangedSignal("Text"), function()
        query = searchBox.Text
        applyFilter()
        list.CanvasPosition = Vector2.new(0, 0)
        buildOptions()
        if open then
            local pw, h = layoutPopup()
            popup.Size = UDim2.fromOffset(pw, h)
        end
    end)

    local api = {}
    function api.SetOptions(newOptions)
        if open then setOpen(false) end
        options = newOptions
        if multi then
            for k in pairs(picked) do
                if not table.find(options, k) then picked[k] = nil end
            end
            if pendingMulti then
                local added, all = false, true
                for k in pairs(pendingMulti) do
                    if table.find(options, k) then
                        if not picked[k] then picked[k] = true added = true end
                    else
                        all = false
                    end
                end
                if all then pendingMulti = nil end
                if added then
                    local out = {}
                    for k in pairs(picked) do out[k] = true end
                    task.defer(function() pcall(callback, out) end)
                end
            end
        elseif #options == 0 then
            selected = nil
        elseif pending ~= nil and table.find(options, pending) then
            selected = pending
            pending = nil
            task.defer(function() pcall(callback, selected) end)
        elseif not table.find(options, selected) then
            selected = options[1]
            task.defer(function() pcall(callback, selected) end)
        end
        query = ""
        searchBox.Text = ""
        applyFilter()
        pillW = calcPillW()
        pill.Size = UDim2.fromOffset(pillW, PILL_H)
        lbl.Size = UDim2.new(1, -(pillW + 30), 1, 0)
        list.CanvasPosition = Vector2.new(0, 0)
        buildOptions()
        valLbl.Text = summary()
    end
    function api.Get() return multi and picked or selected end
    function api.Set(v)
        if multi then
            local want = {}
            if type(v) == "table" then
                for k, val in pairs(v) do
                    if type(k) == "number" then want[val] = true elseif val then want[k] = true end
                end
            end
            local any = false
            for _, o in ipairs(options) do
                if want[o] then picked[o] = true any = true end
            end
            for k in pairs(want) do
                if not table.find(options, k) then pendingMulti = want break end
            end
            buildOptions()
            valLbl.Text = summary()
            if any then
                local out = {}
                for k in pairs(picked) do out[k] = true end
                pcall(callback, out)
            end
        elseif v ~= nil then
            if table.find(options, v) then
                selected = v
                pending = nil
                buildOptions()
                valLbl.Text = summary()
                pcall(callback, v)
            else
                pending = v
            end
        end
    end
    Perf.VisibleDropdowns[cfgKey] = api
    hoverable(el, st, head, Theme.Amber)
    local pressScale = new("UIScale", { Scale = 1 }, el)
    connect(head.MouseButton1Down, function(x, y)
        ripple(el, x, y, Theme.Amber)
        tw(pressScale, { Scale = 0.985 }, 0.08)
    end)
    connect(head.MouseButton1Up, function() tw(pressScale, { Scale = 1 }, 0.2, ES.Back) end)
    connect(head.MouseButton1Click, function() setOpen(not open) end)
    connect(blocker.MouseButton1Click, function() setOpen(false) end)
    pcall(function()
        connect(page.scroll:GetPropertyChangedSignal("CanvasPosition"), function()
            if open then setOpen(false) end
        end)
        connect(page.group:GetPropertyChangedSignal("Visible"), function()
            if open and not page.group.Visible then setOpen(false) end
        end)
        connect(Window:GetPropertyChangedSignal("Visible"), function()
            if open and not Window.Visible then setOpen(false) end
        end)
    end)
    holder.Destroying:Connect(function()
        stopTrack()
        pcall(function() popup:Destroy() end)
        pcall(function() blocker:Destroy() end)
    end)
    return api
end

local tabs, activeTab = {}, nil
local function makePage(name)
    local group = new("CanvasGroup", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
    }, Content)
    local scroll = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Red,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Always,
    }, group)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
    new("UIPadding", {
        PaddingRight = UDim.new(0, 7),
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 8),
    }, scroll)
    local page = { name = name, group = group, scroll = scroll, items = {}, rows = {}, token = 0, hasShown = false }
    function page.show()
        page.token += 1
        local tok = page.token
        group.Visible = true
        group.GroupTransparency = 0
        if not page.hasShown then
            page.hasShown = true
            if page.cardList then
                for i, c in ipairs(page.cardList) do
                    c.card.BackgroundTransparency = 1
                    c.st.Transparency = 1
                    task.delay(math.min(i - 1, 7) * 0.035, function()
                        if c.card.Parent then
                            tw(c.card, { BackgroundTransparency = Theme.Glass.Group }, 0.32)
                            tw(c.st, { Transparency = Theme.Glass.Edge }, 0.32)
                        end
                    end)
                end
            end
            for i, el in ipairs(page.items) do
                if i <= 8 then
                    el.GroupTransparency = 1
                    el.Position = UDim2.fromOffset(0, 8)
                    task.delay((i - 1) * 0.025, function()
                        if page.token == tok then
                            tw(el, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.22, ES.Quint)
                        end
                    end)
                end
            end
        else
            if page.cardList then
                for _, c in ipairs(page.cardList) do
                    c.card.BackgroundTransparency = Theme.Glass.Group
                    c.st.Transparency = Theme.Glass.Edge
                end
            end
            for _, el in ipairs(page.items) do
                el.GroupTransparency = 0
                el.Position = UDim2.fromOffset(0, 0)
            end
        end
    end
    function page.hide()
        page.token += 1
        local tok = page.token
        tw(group, { GroupTransparency = 1 }, 0.12)
        task.delay(0.13, function()
            if page.token == tok then group.Visible = false end
        end)
    end
    return page
end

local function switchTab(name)
    local wasSearching = Search.active
    if wasSearching then Search.exit(true) end
    if activeTab == name and not wasSearching then return end
    local prev = activeTab
    activeTab = name
    local tab = tabs[name]
    tw(Indicator, { Position = UDim2.fromOffset(6, tab.y) }, 0.28, ES.Quint)
    if Perf.PageTitle then Perf.PageTitle.Text = name end
    for n, t in pairs(tabs) do
        tw(t.btn, { TextColor3 = n == name and WHITE or Theme.Sub }, 0.16)
        t.btn.Font = n == name and Enum.Font.GothamBold or Enum.Font.GothamSemibold
    end
    if prev then tabs[prev].page.hide() end
    tab.page.show()
end

local tabDefs = {
    { name = "Home",      icon = "🏠" },
    { name = "Test",      icon = "🧪" },
    { divider = true },
    { name = "Settings",  icon = "🔧" },
    { name = "Interface", icon = "🎨" },
}

local tabY = 8
for _, def in ipairs(tabDefs) do
    if def.divider then
        local line = new("Frame", {
            Size = UDim2.new(1, -24, 0, 1),
            Position = UDim2.fromOffset(12, tabY + 6),
            BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, Sidebar)
        grad(line, Theme.Red, Theme.Blue, 0)
        tabY += 14
    else
        local y = tabY
        tabY += 34
        local b = new("TextButton", {
            Size = UDim2.new(1, -12, 0, 30),
            Position = UDim2.fromOffset(6, y),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = def.name,
            Font = Enum.Font.GothamSemibold,
            TextSize = 13,
            TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2,
        }, Sidebar)
        new("UIPadding", { PaddingLeft = UDim.new(0, 20) }, b)
        local ic = new("TextLabel", {
            Size = UDim2.fromOffset(22, 30),
            Position = UDim2.fromOffset(14, y),
            BackgroundTransparency = 1,
            Text = "",
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextColor3 = WHITE,
            TextTransparency = 0.45,
            ZIndex = 3,
        }, Sidebar)
        connect(b.MouseEnter, function()
            if activeTab ~= def.name then
                tw(b, { TextColor3 = Theme.Text }, 0.15)
                tw(ic, { TextTransparency = 0.1 }, 0.15)
            end
        end)
        connect(b.MouseLeave, function()
            if activeTab ~= def.name then
                tw(b, { TextColor3 = Theme.Sub }, 0.2)
                tw(ic, { TextTransparency = 0.45 }, 0.2)
            end
        end)
        local page = makePage(def.name)
        tabs[def.name] = { btn = b, icon = ic, page = page, y = y }
        connect(b.MouseButton1Click, function() switchTab(def.name) end)
    end
end
Sidebar.CanvasSize = UDim2.fromOffset(0, tabY + 8)

-- SEARCH SYSTEM REMAINED UNCHANGED FROM ORIGINAL

do
    local MAX_RESULTS = 80
    local searchPage = makePage("Search")
    Search.page = searchPage
    local moved, tags = {}, {}
    local header = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, searchPage.scroll)
    local function restoreRows()
        for _, m in ipairs(moved) do
            if m.holder and m.holder.Parent then
                m.holder.LayoutOrder = m.order
                local tgt = (m.parent and m.parent.Parent) and m.parent or (m.pg and m.pg.scroll)
                if tgt then m.holder.Parent = tgt end
                local cg = m.holder:FindFirstChildOfClass("CanvasGroup")
                if cg and m.holder:GetAttribute("InCard") and cg.BackgroundTransparency < 1 then
                    cg.BackgroundTransparency = Theme.Glass.Inner
                end
            end
        end
        table.clear(moved)
        for _, t in ipairs(tags) do t:Destroy() end
        table.clear(tags)
    end
    local function runSearch(q)
        restoreRows()
        local terms = {}
        for w in string.lower(q):gmatch("%S+") do terms[#terms + 1] = w end
        local hits, seq = {}, 0
        for _, def in ipairs(tabDefs) do
            local tab = def.name and tabs[def.name]
            if tab then
                local pg = tab.page
                for _, holder in ipairs(pg.rows) do
                    if holder:IsDescendantOf(pg.scroll) then
                        seq += 1
                        local label = string.lower(holder:GetAttribute("STxt") or "")
                        local sec = string.lower(holder:GetAttribute("SSec") or "")
                        local hay = label .. " " .. sec .. " " .. string.lower(def.name)
                        local ok, inLabel = true, true
                        for _, w in ipairs(terms) do
                            if not hay:find(w, 1, true) then ok = false break end
                            if not label:find(w, 1, true) then inLabel = false end
                        end
                        if ok then
                            hits[#hits + 1] = { holder = holder, pg = pg, tab = def.name,
                                                sec = holder:GetAttribute("SSec") or "",
                                                score = inLabel and 1 or 2, seq = seq }
                        end
                    end
                end
            end
        end
        table.sort(hits, function(a, b)
            if a.score ~= b.score then return a.score < b.score end
            return a.seq < b.seq
        end)
        local shown = math.min(#hits, MAX_RESULTS)
        for i = 1, shown do
            local h = hits[i]
            local crumb = h.sec ~= "" and (h.tab .. "  >  " .. h.sec) or h.tab
            tags[#tags + 1] = new("TextLabel", {
                Size = UDim2.new(1, 0, 0, 14),
                BackgroundTransparency = 1,
                LayoutOrder = i * 2,
                Text = string.upper(crumb),
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextColor3 = Theme.Red,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, searchPage.scroll)
            moved[#moved + 1] = { holder = h.holder, parent = h.holder.Parent, order = h.holder.LayoutOrder, pg = h.pg }
            do
                local cg = h.holder:FindFirstChildOfClass("CanvasGroup")
                if cg then
                    cg.GroupTransparency = 0
                    if h.holder:GetAttribute("InCard") and cg.BackgroundTransparency < 1 then
                        cg.BackgroundTransparency = Theme.Glass.Card
                    end
                end
            end
            h.holder.LayoutOrder = i * 2 + 1
            h.holder.Parent = searchPage.scroll
        end
        if #hits == 0 then
            header.Text = 'No features found for "' .. q .. '"'
        elseif #hits > shown then
            header.Text = "Showing " .. shown .. " of " .. #hits .. ' results for "' .. q .. '"'
        else
            header.Text = #hits .. (#hits == 1 and " result" or " results") .. ' for "' .. q .. '"'
        end
        searchPage.scroll.CanvasPosition = Vector2.new(0, 0)
    end
    function Search.exit(noShow)
        if not Search.active then return end
        Search.active = false
        if Perf.PageTitle and activeTab then Perf.PageTitle.Text = activeTab end
        searchPage.hide()
        restoreRows()
        SearchBox.Text = ""
        if not noShow and activeTab then tabs[activeTab].page.show() end
    end
    function Search.refresh()
        if Search.active then
            local q = SearchBox.Text:match("^%s*(.-)%s*$")
            if q ~= "" then runSearch(q) end
        end
    end
    local tok = 0
    connect(SearchBox:GetPropertyChangedSignal("Text"), function()
        SearchClear.Visible = SearchBox.Text ~= ""
        tok += 1
        local mine = tok
        task.delay(0.12, function()
            if mine ~= tok then return end
            local q = SearchBox.Text:match("^%s*(.-)%s*$")
            if q == "" then
                if Search.active then Search.exit() end
                return
            end
            if not Search.active then
                Search.active = true
                if Perf.PageTitle then Perf.PageTitle.Text = "Search" end
                if activeTab then tabs[activeTab].page.hide() end
                searchPage.show()
            end
            runSearch(q)
        end)
    end)
    connect(SearchClear.MouseButton1Click, function()
        SearchBox.Text = ""
        if Search.active then Search.exit() end
    end)
end

local blurOn = true
Perf.BLUR = game:GetService("UserInputService").TouchEnabled and 12 or 20
function Perf.blurApply(on)
    on = on and blurOn
    pcall(function()
        if not blur.Parent then
            blur = new("BlurEffect", { Name = "TrigoBlur", Size = 0 }, Lighting)
        elseif blur.Parent ~= Lighting then
            blur.Parent = Lighting
        end
        blur.Enabled = true
    end)
end
task.spawn(function()
    while SG.Parent and not closing do
        if visible and blurOn then
            pcall(function()
                if not blur.Parent then blur = new("BlurEffect", { Name = "TrigoBlur", Size = Perf.BLUR }, Lighting) end
                if not blur.Enabled then blur.Enabled = true end
            end)
        end
        task.wait(1)
    end
end)

local animToken = 0
local function showUI()
    visible = true
    animToken += 1
    Perf.setLoops(true)
    computeScale()
    blur.Enabled = true
    Perf.blurApply(blurOn)
    Window.Visible = true
    PopScale.Scale = scaleBase * 0.88
    Main.GroupTransparency = 1
    Perf.animUntil = os.clock() + 0.7
    tw(PopScale, { Scale = scaleBase }, 0.45, ES.Quint)
    tw(Main, { GroupTransparency = 0 }, 0.25)
    tw(Shadow, { ImageTransparency = 0.45 }, 0.6)
    tw(outlineStroke, { Transparency = 0.1 }, 0.5)
    if blurOn then tw(blur, { Size = Perf.BLUR }, 0.4) end
    if Search.active and Search.page then Search.page.show()
    elseif activeTab then tabs[activeTab].page.show() end
end

local function hideUI()
    visible = false
    animToken += 1
    local tok = animToken
    tw(PopScale, { Scale = scaleBase * 0.86 }, 0.35, ES.Quint, ED.In)
    tw(Main, { GroupTransparency = 1 }, 0.3)
    tw(Shadow, { ImageTransparency = 1 }, 0.3)
    tw(outlineStroke, { Transparency = 1 }, 0.3)
    tw(blur, { Size = 0 }, 0.4)
    Perf.blurApply(false)
    task.delay(0.38, function()
        if tok == animToken then
            Window.Visible = false
            Perf.setLoops(false)
        end
    end)
end

Perf.slashIntro = true
Perf.intro = function()
    local ANGLE   = 35
    local SWEEP   = 0.20
    local WIPE    = 0.75
    local MAX_SPARKS = 150
    local rad    = math.rad(ANGLE)
    local dir    = Vector2.new(math.cos(rad), math.sin(rad))
    local screen = SG.AbsoluteSize
    if screen.X < 50 or screen.Y < 50 then
        screen = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
    end
    local diag   = screen.Magnitude
    local center = Window.AbsolutePosition + Window.AbsoluteSize / 2
    if Window.AbsoluteSize.X < 10 then center = screen / 2 end
    local kp      = NumberSequenceKeypoint.new
    local palette = {
        Theme.Red, Theme.Blue, WHITE,
        Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 170, 255),
    }
    local FX, dim, cover, edgeGlow, edgeCore
    local sparks, sparkConn = {}, nil
    local finished = false
    local function startSparks()
        if sparkConn then return end
        sparkConn = RunService.Heartbeat:Connect(function(dt)
            for i = #sparks, 1, -1 do
                local p = sparks[i]
                p.life += dt
                if p.life >= p.max or not p.o.Parent then
                    pcall(function() p.o:Destroy() end)
                    table.remove(sparks, i)
                else
                    p.vy += 900 * dt
                    p.vx *= (1 - 2.2 * dt)
                    p.vy *= (1 - 1.2 * dt)
                    p.x += p.vx * dt
                    p.y += p.vy * dt
                    local a = p.life / p.max
                    p.o.Position = UDim2.fromOffset(p.x, p.y)
                    p.o.Rotation = math.deg(math.atan2(p.vy, p.vx))
                    p.o.Size = UDim2.fromOffset(p.len * (1 - a * 0.6), p.th)
                    p.o.BackgroundTransparency = a * a
                end
            end
            if #sparks == 0 and sparkConn then
                sparkConn:Disconnect()
                sparkConn = nil
            end
        end)
    end
    local function emit(x, y, count, speed, spread, baseDir)
        for _ = 1, count do
            if #sparks >= MAX_SPARKS then return end
            local ang = baseDir and (baseDir + (math.random() - 0.5) * spread) or (math.random() * math.pi * 2)
            local sp  = speed * (0.35 + math.random() * 0.9)
            local len = math.random(7, 18)
            local th  = math.random(2, 3)
            local f = new("Frame", {
                Size = UDim2.fromOffset(len, th),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(x, y),
                BackgroundColor3 = palette[math.random(1, #palette)],
                BorderSizePixel = 0,
                Rotation = math.deg(ang),
                ZIndex = 20,
            }, FX)
            round(f)
            sparks[#sparks + 1] = {
                o = f, x = x, y = y, len = len, th = th,
                vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
                life = 0, max = 0.45 + math.random() * 0.6,
            }
        end
        startSparks()
    end
    local function mkSeq(f, knots)
        local ts = { 0 }
        for _, t in ipairs(knots) do
            if t > 0.0001 and t < 0.9999 then ts[#ts + 1] = t end
        end
        ts[#ts + 1] = 1
        local pts = {}
        for i, t in ipairs(ts) do
            pts[i] = kp(t, math.clamp(f(t), 0, 1))
        end
        return NumberSequence.new(pts)
    end
    local function band(e, w, peak)
        return mkSeq(function(t)
            return 1 - (1 - peak) * math.max(0, 1 - math.abs(t - e) / w)
        end, { e - w, e, e + w })
    end
    local function reveal(e)
        return mkSeq(function(t)
            return 1 - math.clamp((t - e + 0.006) / 0.012, 0, 1)
        end, { e - 0.006, e + 0.006 })
    end
    local function openAndWipe()
        cover = new("Frame", {
            Name = "SlashCover",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.Dark,
            BorderSizePixel = 0,
            Active = true,
            ZIndex = 900,
        }, Main)
        local coverG = new("UIGradient", { Rotation = 45, Transparency = reveal(-0.12) }, cover)
        edgeGlow = new("Frame", {
            Name = "SlashEdgeGlow",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.Red,
            BorderSizePixel = 0,
            ZIndex = 901,
        }, Main)
        local glowG = new("UIGradient", { Rotation = 45, Transparency = band(-0.12, 0.07, 0.4) }, edgeGlow)
        edgeCore = new("Frame", {
            Name = "SlashEdgeCore",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            ZIndex = 902,
        }, Main)
        local coreG = new("UIGradient", { Rotation = 45, Transparency = band(-0.12, 0.012, 0) }, edgeCore)
        visible = true
        animToken += 1
        Perf.setLoops(true)
        computeScale()
        blur.Enabled = true
        Perf.blurApply(blurOn)
        Scaler.Position = UDim2.new(0.5, -dir.X * 56, 0.5, -dir.Y * 56)
        Main.GroupTransparency = 1
        Window.Visible = true
        PopScale.Scale = scaleBase * 0.88
        Perf.animUntil = os.clock() + 1.0
        tw(Main, { GroupTransparency = 0 }, 0.08)
        tw(PopScale, { Scale = scaleBase }, 0.8, ES.Back)
        tw(Scaler, { Position = UDim2.fromScale(0.5, 0.5) }, 0.7, ES.Quint)
        tw(Shadow, { ImageTransparency = 0.45 }, 0.6)
        tw(outlineStroke, { Transparency = 0.1 }, 0.5)
        if blurOn then tw(blur, { Size = Perf.BLUR }, 0.4) end
        task.delay(0.22, function()
            if not visible then return end
            if Search.active and Search.page then Search.page.show()
            elseif activeTab then tabs[activeTab].page.show() end
        end)
        local t0 = os.clock()
        while true do
            local a = math.clamp((os.clock() - t0) / WIPE, 0, 1)
            local e = -0.12 + 1.24 * TweenService:GetValue(a, ES.Quad, ED.Out)
            coverG.Transparency = reveal(e)
            glowG.Transparency  = band(e, 0.07, 0.4)
            coreG.Transparency  = band(e, 0.012, 0)
            edgeGlow.BackgroundColor3 = Theme.Red:Lerp(Theme.Blue, math.clamp(e, 0, 1))
            local ap, asz = Main.AbsolutePosition, Main.AbsoluteSize
            local u0, u1 = math.max(0, 2 * e - 1), math.min(1, 2 * e)
            if u1 > u0 and asz.X > 0 then
                local u = u0 + math.random() * (u1 - u0)
                local v = 2 * e - u
                local side = (math.random() < 0.5) and -1 or 1
                emit(ap.X + u * asz.X, ap.Y + v * asz.Y, 2, 300, 1.3, rad + side * math.pi * 0.5)
            end
            if a >= 1 then break end
            RunService.Heartbeat:Wait()
        end
        cover:Destroy(); cover = nil
        edgeGlow:Destroy(); edgeGlow = nil
        edgeCore:Destroy(); edgeCore = nil
    end
    local function impact()
        task.spawn(function()
            local ok, err = pcall(openAndWipe)
            if not ok then do end end
            finished = true
        end)
    end
    local function cleanup()
        if sparkConn then sparkConn:Disconnect(); sparkConn = nil end
        if cover then pcall(function() cover:Destroy() end) end
        if edgeGlow then pcall(function() edgeGlow:Destroy() end) end
        if edgeCore then pcall(function() edgeCore:Destroy() end) end
        if FX then pcall(function() FX:Destroy() end) end
        if dim then
            local d = dim
            tw(d, { BackgroundTransparency = 1 }, 0.35)
            task.delay(0.4, function() d:Destroy() end)
        end
        Scaler.Rotation = 0
    end
    local function run()
        dim = new("Frame", {
            Name = "SlashDim",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 4,
        }, SG)
        FX = new("Frame", {
            Name = "SlashFX",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            ZIndex = 60,
        }, SG)
        tw(dim, { BackgroundTransparency = 0.5 }, 0.15)
        task.wait(0.18)
        task.wait(0.1)
        impact()
        local limit = os.clock() + 3
        while not finished and os.clock() < limit do task.wait() end
        tw(dim, { BackgroundTransparency = 1 }, 0.4)
        limit = os.clock() + 1.5
        while #sparks > 0 and os.clock() < limit do task.wait(0.05) end
    end
    local ok, err = pcall(run)
    cleanup()
    if not ok then do end end
    return ok
end

Perf.openIntro = function()
    if Perf.slashIntro then
        if not Perf.intro() then showUI() end
    else
        showUI()
    end
end

local function setMinimised(m)
    minimised = m
    tw(Window, { Size = UDim2.fromOffset(WIN_W, m and BAR_H or WIN_H) }, 0.55, ES.Quint)
    tw(Body, { GroupTransparency = m and 1 or 0 }, m and 0.25 or 0.5)
    tw(Perf.SideBody, { GroupTransparency = m and 1 or 0 }, m and 0.25 or 0.5)
    BtnMin.Text = m and "+" or "—"
end

local function makeDraggable(target, handle, onClick)
    local dragging, startInput, startPos, moved = false, nil, nil, false
    connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            startInput, startPos = input.Position, target.Position
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    c:Disconnect()
                    if onClick and not moved then onClick() end
                end
            end)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            if d.Magnitude > 5 then moved = true end
            if moved or not onClick then
                tw(target, { Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y) }, 0.09, ES.Sine)
            end
        end
    end)
end

makeDraggable(Window, TopBar)
makeDraggable(Window, Perf.Side:FindFirstChild("BrandDrag"))

local TogHolder = new("Frame", {
    Size = UDim2.fromOffset(46, 46),
    Position = UDim2.new(0, 12, 0.5, -23),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 250,
}, SG)
local TogBtn = new("TextButton", {
    Size = UDim2.fromScale(1, 1),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundTransparency = 1,
    AutoButtonColor = false,
    Text = "",
    BorderSizePixel = 0,
}, TogHolder)
local togBG = new("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Theme.BG,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    ZIndex = 1,
}, TogBtn)
round(togBG)
local togGlow = stroke(togBG, Theme.Stroke, 1, 0.4)
local togLogo = buildYinYang(TogBtn, 34)
togLogo.AnchorPoint = Vector2.new(0.5, 0.5)
togLogo.Position = UDim2.fromScale(0.5, 0.5)
togLogo.ZIndex = 2
local togScale = new("UIScale", { Scale = 0 }, TogBtn)
connect(TogBtn.MouseEnter, function()
    tw(togScale, { Scale = 1.1 }, 0.25, ES.Back)
    tw(togGlow, { Color = Theme.Red, Transparency = 0.05 }, 0.25)
end)
connect(TogBtn.MouseLeave, function()
    tw(togScale, { Scale = 1 }, 0.25, ES.Back)
    tw(togGlow, { Color = Theme.Stroke, Transparency = 0.4 }, 0.3)
end)

local function toggleUI()
    if not ready or closing then return end
    tw(togScale, { Scale = 0.78 }, 0.1)
    task.delay(0.1, function() tw(togScale, { Scale = 1 }, 0.5, ES.Back) end)
    if visible then hideUI() else showUI() end
end
makeDraggable(TogHolder, TogBtn, toggleUI)
connect(UserInputService.InputBegan, function(input, gp)
    if gp then return end
    if input.KeyCode == TOGGLE_KEY then toggleUI() end
end)
connect(BtnMin.MouseButton1Click, function() setMinimised(not minimised) end)

local function shutdownNow()
    pcall(function() for _, fn in ipairs(Perf.onClose) do pcall(fn) end end)
    pcall(function() for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end end)
    pcall(function() SG:Destroy() end)
    pcall(Perf.blurApply, false)
    pcall(function() blur:Destroy() end)
end
pcall(function()
    game:GetService("Players").PlayerRemoving:Connect(function(pl)
        if pl == player then shutdownNow() end
    end)
end)

local function destroyUI()
    if closing then return end
    closing = true
    for _, fn in ipairs(Perf.onClose) do pcall(fn) end
    hideUI()
    tw(togScale, { Scale = 0 }, 0.35, ES.Back, ED.In)
    task.delay(0.55, function()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        SG:Destroy()
        blur:Destroy()
    end)
end

local confirmOpen = false
local function askClose()
    if closing or confirmOpen then return end
    confirmOpen = true
    local Dim = new("TextButton", {
        Name = "CloseConfirm",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 200,
    }, Main)
    tw(Dim, { BackgroundTransparency = 0.45 }, 0.2)
    local Box = new("Frame", {
        Size = UDim2.fromOffset(250, 112),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        ZIndex = 201,
    }, Dim)
    corner(Box, 12)
    stroke(Box, Theme.Stroke, 1, 0.1)
    local boxScale = new("UIScale", { Scale = 0.8 }, Box)
    tw(boxScale, { Scale = 1 }, 0.3, ES.Back)
    new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 24),
        Position = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        Text = "Are you sure?",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Theme.Text,
        ZIndex = 202,
    }, Box)
    new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 18),
        Position = UDim2.fromOffset(12, 38),
        BackgroundTransparency = 1,
        Text = "This will close and unload Trigo Hub.",
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Sub,
        ZIndex = 202,
    }, Box)
    local function popBtn(text, x, color, hover)
        local b = new("TextButton", {
            Size = UDim2.new(0.5, -18, 0, 30),
            Position = UDim2.new(x, x == 0 and 12 or 6, 1, -42),
            BackgroundColor3 = color,
            AutoButtonColor = false,
            Text = text,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = WHITE,
            BorderSizePixel = 0,
            ZIndex = 203,
        }, Box)
        corner(b, 8)
        connect(b.MouseEnter, function() tw(b, { BackgroundColor3 = hover }, 0.15) end)
        connect(b.MouseLeave, function() tw(b, { BackgroundColor3 = color }, 0.15) end)
        return b
    end
    local BtnCancel = popBtn("Cancel", 0, Theme.Blue, Color3.fromRGB(90, 145, 255))
    local BtnSure   = popBtn("Sure", 0.5, Theme.Red, Color3.fromRGB(255, 85, 110))
    local function dismiss()
        confirmOpen = false
        tw(boxScale, { Scale = 0.8 }, 0.15)
        tw(Dim, { BackgroundTransparency = 1 }, 0.15)
        task.delay(0.17, function() Dim:Destroy() end)
    end
    connect(BtnCancel.MouseButton1Click, dismiss)
    connect(BtnSure.MouseButton1Click, function()
        confirmOpen = false
        Dim:Destroy()
        destroyUI()
    end)
end
connect(BtnClose.MouseButton1Click, askClose)

-- HOME TAB

do
    local p = tabs.Home.page
    local _, card = row(p, 84)
    local avatarFrame = new("Frame", {
        Size = UDim2.fromOffset(64, 64),
        Position = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Theme.Panel2,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, card)
    round(avatarFrame)
    rgbStroke(avatarFrame, 2)
    local avatarImg = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, avatarFrame)
    round(avatarImg)
    local avatarMask = new("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "?",
        Font = Enum.Font.GothamBlack,
        TextSize = 30,
        TextColor3 = Theme.Sub,
        TextTransparency = 1,
        ZIndex = 4,
    }, avatarFrame)
    local onlineDot = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.85, 0.85),
        BackgroundColor3 = Theme.Green,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, avatarFrame)
    round(onlineDot)
    stroke(onlineDot, Theme.Panel, 2)
    loop(onlineDot, { BackgroundTransparency = 0.45 }, 1, ES.Sine, true)
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(player.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if ok then avatarImg.Image = img end
    end)
    local nameLbl = new("TextLabel", {
        Size = UDim2.new(1, -196, 0, 20),
        Position = UDim2.fromOffset(84, 12),
        BackgroundTransparency = 1,
        Text = shownName(),
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    }, card)
    local userLbl = new("TextLabel", {
        Size = UDim2.new(1, -196, 0, 14),
        Position = UDim2.fromOffset(84, 33),
        BackgroundTransparency = 1,
        Text = "@" .. player.Name,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    }, card)
    pcall(function()
        local ORANGE = Color3.fromRGB(255, 170, 60)
        local function executorName()
            local ok, n = pcall(function() return identifyexecutor() end)
            if ok and type(n) == "string" and n ~= "" then return n end
            ok, n = pcall(function() return getexecutorname() end)
            if ok and type(n) == "string" and n ~= "" then return n end
            return nil
        end
        local function missingCount()
            local ok, n = pcall(function()
                if type(FPS) == "table" and type(FPS.MissingCaps) == "function" then
                    return #FPS.MissingCaps()
                end
                local names = {
                    "getrawmetatable", "setreadonly", "newcclosure", "getnamecallmethod",
                    "getconnections", "getsenv", "getupvalues", "getgc", "getfenv",
                    "cloneref", "setfpscap", "writefile", "readfile", "isfile",
                    "fireproximityprompt", "queue_on_teleport", "hookfunction",
                }
                local env = _G
                if type(getgenv) == "function" then
                    local okEnv, g = pcall(getgenv)
                    if okEnv and type(g) == "table" then env = g end
                end
                local miss = 0
                for _, key in ipairs(names) do
                    if type(env[key]) ~= "function" and type(_G[key]) ~= "function" then
                        miss += 1
                    end
                end
                return miss
            end)
            if ok and type(n) == "number" then return n end
            return 0
        end
        local exName = executorName()
        local nMiss = missingCount()
        local color, verdict
        if not exName then
            exName = "Unknown Executor"
            color, verdict = Theme.Red, "unverified"
        elseif nMiss == 0 then
            color, verdict = Theme.Green, "fully compatible"
        elseif nMiss <= 4 then
            color, verdict = ORANGE, "partly compatible"
        else
            color, verdict = Theme.Red, "not compatible"
        end
        local label = exName
        local TEXT_PAD = 16 + 8
        local textW = game:GetService("TextService"):GetTextSize(
            label, 11, Enum.Font.GothamBold, Vector2.new(math.huge, 18)
        ).X
        local chipW = math.min(math.ceil(textW) + TEXT_PAD, 120)
        local chip = new("Frame", {
            Size = UDim2.fromOffset(chipW, 16),
            Position = UDim2.fromOffset(84, 52),
            BackgroundColor3 = Theme.Panel2,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, card)
        corner(chip, 8)
        stroke(chip, color, 1, 0.5)
        local dot = new("Frame", {
            Size = UDim2.fromOffset(6, 6),
            Position = UDim2.fromOffset(6, 5),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            ZIndex = 3,
        }, chip)
        round(dot)
        loop(dot, { BackgroundTransparency = 0.5 }, 1.1, ES.Sine, true)
        new("TextLabel", {
            Size = UDim2.new(1, -TEXT_PAD, 1, 0),
            Position = UDim2.fromOffset(16, 0),
            BackgroundTransparency = 1,
            Text = label,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = color,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 3,
        }, chip)
    end)
    local timeLbl = new("TextLabel", {
        Size = UDim2.fromOffset(104, 20),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 22),
        BackgroundTransparency = 1,
        Text = (os.date("%I:%M:%S %p"):gsub("^0", "")),
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 2,
    }, card)
    local dateLbl = new("TextLabel", {
        Size = UDim2.fromOffset(104, 14),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 44),
        BackgroundTransparency = 1,
        Text = os.date("%a, %b %d"),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 2,
    }, card)
    local rowW  = WIN_W - SIDE_W - 20 - 7
    local cardW = rowW - 4
    local GW, GH = math.floor(rowW * 0.36) - 5 - 16, 20
    local function maxOf(t)
        local m = 0
        for _, v in ipairs(t) do if v > m then m = v end end
        return m
    end
    local function makeGraph(parent, topFn, colorFn)
        local N, SUB = 20, 3
        local STEP = GW / N
        local SLIDE = 0.5
        local box = new("Frame", {
            Size = UDim2.fromOffset(GW, GH),
            Position = UDim2.fromOffset(8, 36),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            ZIndex = 3,
        }, parent)
        for g = 0, 2 do
            new("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.new(0, 0, g / 2, g == 2 and -1 or 0),
                BackgroundColor3 = WHITE,
                BackgroundTransparency = 0.9,
                BorderSizePixel = 0,
                ZIndex = 3,
            }, box)
        end
        local layer = new("Frame", {
            Size = UDim2.fromOffset(GW, GH),
            Position = UDim2.fromOffset(STEP, 0),
            BackgroundTransparency = 1,
            ZIndex = 4,
        }, box)
        local M = N + 2
        local data, seeded = {}, false
        for i = 1, M do data[i] = 0 end
        local segs = {}
        for i = 1, (M - 1) * SUB do
            segs[i] = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(4, 2),
                Position = UDim2.fromOffset(0, GH),
                BackgroundColor3 = Theme.Green,
                BorderSizePixel = 0,
                ZIndex = 4,
            }, layer)
            round(segs[i])
        end
        local head = new("Frame", {
            Size = UDim2.fromOffset(6, 6),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(GW - 3, GH),
            BackgroundColor3 = WHITE,
            BorderSizePixel = 0,
            ZIndex = 5,
        }, layer)
        round(head)
        local function clampY(y) return math.clamp(y, 1, GH - 1) end
        local graph = {}
        function graph.push(v)
            if not seeded then
                seeded = true
                for i = 1, M do data[i] = v end
            end
            table.remove(data, 1)
            data[M] = v
            local top = topFn(data)
            local pts = {}
            for i = 1, M do
                pts[i] = Vector2.new((i - 2) * STEP,
                    GH - 2 - math.clamp(data[i] / top, 0, 1) * (GH - 4))
            end
            local curve = {}
            for i = 1, M - 1 do
                local p0 = pts[math.max(i - 1, 1)]
                local p1, p2 = pts[i], pts[i + 1]
                local p3 = pts[math.min(i + 2, M)]
                for k = 0, SUB - 1 do
                    local t = k / SUB
                    local t2, t3 = t * t, t * t * t
                    local pt = 0.5 * ((2 * p1) + (p2 - p0) * t
                        + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                        + (3 * p1 - p0 - 3 * p2 + p3) * t3)
                    curve[#curve + 1] = Vector2.new(pt.X, clampY(pt.Y))
                end
            end
            curve[#curve + 1] = pts[M]
            for i = 1, #segs do
                local a, b = curve[i], curve[i + 1]
                local d = b - a
                local mid = (a + b) / 2
                local seg = segs[i]
                seg.Position = UDim2.fromOffset(mid.X, mid.Y)
                seg.Size = UDim2.fromOffset(d.Magnitude + 1.5, 2)
                seg.Rotation = math.deg(math.atan2(d.Y, d.X))
                seg.BackgroundColor3 = colorFn(data[math.min(M, math.floor((i - 1) / SUB) + 2)])
            end
            head.Position = UDim2.fromOffset(GW - 3, pts[M].Y)
            layer.Position = UDim2.fromOffset(STEP, 0)
            tw(layer, { Position = UDim2.fromOffset(0, 0) }, SLIDE, ES.Linear)
        end
        function graph.avg()
            local sum = 0
            for i = 2, M do sum += data[i] end
            return math.floor(sum / (M - 1) + 0.5)
        end
        return graph
    end
    local function fpsColor(v) return v >= 50 and Theme.Green or (v >= 30 and YELLOW or Theme.Red) end
    local function pingColor(v) return v < 90 and Theme.Green or (v < 180 and YELLOW or Theme.Red) end
    local statRowEl
    do
        local _, el = row(p, 64, true)
        statRowEl = el
    end
    local CARD_X = { 0, 0.36, 0.72 }
    local CARD_W = { 0.36, 0.36, 0.28 }
    local function statCard(idx, title)
        local c = new("Frame", {
            Size = UDim2.new(CARD_W[idx], -5, 1, -4),
            Position = UDim2.new(CARD_X[idx], idx == 1 and 2 or 3, 0, 2),
            BackgroundColor3 = Theme.Panel,
            BackgroundTransparency = Theme.Glass.Card,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, statRowEl)
        corner(c, 10)
        stroke(c, Theme.Stroke, 1, 0.45)
        new("TextLabel", {
            Size = UDim2.new(1, -12, 0, 12),
            Position = UDim2.fromOffset(8, 4),
            BackgroundTransparency = 1,
            Text = title,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
        }, c)
        local val = new("TextLabel", {
            Size = UDim2.new(1, -16, 0, 18),
            Position = UDim2.fromOffset(8, 15),
            BackgroundTransparency = 1,
            Text = "--",
            Font = Enum.Font.GothamBold,
            TextSize = 15,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
        }, c)
        local avg = new("TextLabel", {
            Size = UDim2.fromOffset(56, 12),
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 5),
            BackgroundTransparency = 1,
            Text = "",
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 3,
        }, c)
        return c, val, avg
    end
    local fpsCard, fpsVal, fpsAvg = statCard(1, "FPS")
    local pingCard, pingVal, pingAvg = statCard(2, "PING")
    local srvCard, srvVal = statCard(3, "SERVER TIME")
    local srvSub = new("TextLabel", {
        Size = UDim2.new(1, -16, 0, 14),
        Position = UDim2.fromOffset(8, 36),
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, srvCard)
    local fpsGraph = makeGraph(fpsCard,
        function(d) return math.max(60, math.ceil(maxOf(d) / 30) * 30) end, fpsColor)
    local pingGraph = makeGraph(pingCard,
        function(d) return math.max(100, math.ceil(maxOf(d) / 50) * 50) end, pingColor)
    live.update = function(fps, ping)
        fpsVal.Text = tostring(fps)
        tw(fpsVal, { TextColor3 = fpsColor(fps) }, 0.3)
        fpsGraph.push(fps)
        fpsAvg.Text = "avg " .. fpsGraph.avg()
        if ping then
            pingVal.Text = ping .. " ms"
            tw(pingVal, { TextColor3 = pingColor(ping) }, 0.3)
            pingGraph.push(ping)
            pingAvg.Text = "avg " .. pingGraph.avg()
        else
            pingVal.Text = "--"
        end
        timeLbl.Text = (os.date("%I:%M:%S %p"):gsub("^0", ""))
        dateLbl.Text = os.date("%a, %b %d")
        pcall(function()
            srvVal.Text = os.date("!%H:%M:%S", math.floor(workspace:GetServerTimeNow()))
            local up = math.max(0, math.floor(workspace.DistributedGameTime))
            if up >= 3600 then
                srvSub.Text = string.format("up %dh %02dm", up // 3600, (up % 3600) // 60)
            else
                srvSub.Text = string.format("up %dm %02ds", up // 60, up % 60)
            end
        end)
    end
    local anonToken = 0
    local function applyAnon(on)
        anonymous = on
        anonToken += 1
        local tok = anonToken
        tw(avatarImg, { ImageTransparency = on and 1 or 0 }, 0.4)
        tw(avatarMask, { TextTransparency = on and 0 or 1 }, 0.4)
        if Perf.footAvatar then tw(Perf.footAvatar, { ImageTransparency = on and 1 or 0 }, 0.4) end
        if Perf.footMask then tw(Perf.footMask, { TextTransparency = on and 0 or 1 }, 0.4) end
        local texts = { nameLbl, userLbl, statusTxt }
        for _, l in ipairs(texts) do tw(l, { TextTransparency = 1 }, 0.15) end
        task.delay(0.17, function()
            if tok ~= anonToken then return end
            nameLbl.Text = shownName()
            userLbl.Text = on and "@hidden" or ("@" .. player.Name)
            statusTxt.Text = shownName()
            for _, l in ipairs(texts) do tw(l, { TextTransparency = 0 }, 0.25) end
        end)
    end
    Toggle(p, "Anonymous Mode", false, function(v)
        applyAnon(v)
        notify("Anonymous Mode", v and "Name and avatar hidden" or "Name and avatar visible", 2)
    end)
end

-- Remaining file continues unchanged from the original source with the same behaviors.

local Layout = { PLACE = {} }
Layout.ORDER = {}
function Layout.regroup(name, page)
    local items = {}
    for _, ch in ipairs(page.scroll:GetChildren()) do
        if ch:IsA("Frame") then items[#items + 1] = ch end
    end
    table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    local rank = {}
    for i, n in ipairs(Layout.ORDER[name] or {}) do rank[n] = i end
    local entries, first, lastKey = {}, {}, ""
    for i, h in ipairs(items) do
        local head = h:GetAttribute("SHead")
        local key = head or (h:GetAttribute("STxt") and (h:GetAttribute("SSec") or "")) or lastKey
        lastKey = key
        if first[key] == nil then first[key] = i end
        entries[i] = { h = h, key = key, i = i, head = head ~= nil,
                       ord = h:GetAttribute("SOrd") or (1000 + i) }
    end
    local function groupRank(e)
        if e.key == "" then return 0 end
        return rank[e.key] or (100 + first[e.key])
    end
    table.sort(entries, function(a, b)
        local ra, rb = groupRank(a), groupRank(b)
        if ra ~= rb then return ra < rb end
        if a.head ~= b.head then return a.head end
        if a.ord ~= b.ord then return a.ord < b.ord end
        return a.i < b.i
    end)
    for i, e in ipairs(entries) do e.h.LayoutOrder = i end
end
function Layout.flatten(page)
    if not page.cols then return end
    for _, c in ipairs(page.cardList or {}) do
        for _, ch in ipairs(c.body:GetChildren()) do
            if ch:IsA("Frame") then ch.Parent = page.scroll end
        end
        c.head.Parent = page.scroll
        if c.outside then c.card:Destroy() end
    end
    page.cols:Destroy()
    page.cols, page.cardList, page.secToggle = nil, nil, nil
    if page.fillConn then pcall(function() page.fillConn:Disconnect() end) page.fillConn = nil end
end
function Layout.columnize(page)
    local items = {}
    for _, ch in ipairs(page.scroll:GetChildren()) do
        if ch:IsA("Frame") then items[#items + 1] = ch end
    end
    table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    local lead, groups, cur = 0, {}, nil
    for _, h in ipairs(items) do
        local head = h:GetAttribute("SHead")
        if head then
            cur = { name = head, head = h, rows = {} }
            groups[#groups + 1] = cur
        elseif cur then
            cur.rows[#cur.rows + 1] = h
        else
            lead += 1
        end
    end
    if #groups == 0 then return end
    local fullSet, fillSet = page.fullSections or {}, page.fillSections or {}
    local function isOutside(g) return fullSet[g.name] or fillSet[g.name] end
    local firstCol, nBefore, nCols = nil, 0, 0
    for gi, g in ipairs(groups) do
        if isOutside(g) then
            if not firstCol then nBefore += 1 end
        else
            nCols += 1
            firstCol = firstCol or gi
        end
    end
    local cols = new("Frame", {
        Name = "Cols",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = lead + nBefore + 1,
    }, nCols > 0 and page.scroll or nil)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 1), PaddingRight = UDim.new(0, 1),
        PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1),
    }, cols)
    local colF, colH = {}, { 0, 0 }
    for i = 1, 1 do
        local c = new("Frame", {
            Name = "ColL",
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        }, cols)
        new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, c)
        colF[i] = c
    end
    page.cols, page.cardList, page.secToggle = cols, {}, {}
    page.collapsed = page.collapsed or {}
    for gi, g in ipairs(groups) do
        local est = 40
        for _, h in ipairs(g.rows) do est += h.Size.Y.Offset + 5 end
        local outside = isOutside(g)
        local isFill = fillSet[g.name]
        local ci = 1
        if not outside then colH[ci] += est + 8 end
        local cardOrder = gi
        local cardParent = colF[ci]
        if outside then
            cardParent = page.scroll
            if firstCol and gi > firstCol then cardOrder = lead + nBefore + 1 + gi
            else cardOrder = lead + gi end
        end
        local card = new("Frame", {
            Name = "Card",
            Size = isFill and UDim2.new(1, 0, 1, -6) or UDim2.new(1, 0, 0, 0),
            AutomaticSize = isFill and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Panel,
            BackgroundTransparency = Theme.Glass.Group,
            BorderSizePixel = 0,
            LayoutOrder = cardOrder,
        }, cardParent)
        corner(card, 12)
        if #groups == 1 and not outside then
            local minH = new("UISizeConstraint", { MinSize = Vector2.new(0, 0) }, card)
            local function fit()
                local lead = 0
                for _, ch in ipairs(page.scroll:GetChildren()) do
                    if ch:IsA("GuiObject") and ch ~= cols and ch.Visible then lead += ch.AbsoluteSize.Y + 6 end
                end
                minH.MinSize = Vector2.new(0, math.max(0, page.scroll.AbsoluteWindowSize.Y - 12 - lead))
            end
            page.fillConn = connect(page.scroll:GetPropertyChangedSignal("AbsoluteWindowSize"), fit)
            task.defer(fit)
        end
        local cst = stroke(card, WHITE, 1, Theme.Glass.Edge)
        new("UIGradient", {
            Rotation = 45,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.5, 0.55),
                NumberSequenceKeypoint.new(1, 0.15),
            }),
        }, cst)
        new("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, card)
        g.head.Parent = card
        local body = new("Frame", {
            Name = "Body",
            Size = isFill and UDim2.new(1, 0, 1, -34) or UDim2.new(1, 0, 0, 0),
            AutomaticSize = isFill and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            LayoutOrder = 1000000000,
        }, card)
        new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, body)
        new("UIPadding", {
            PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8),
        }, body)
        local n = 0
        for _, h in ipairs(g.rows) do
            n += h:GetAttribute("SN") or 0
            h.Parent = body
        end
        page.cardList[#page.cardList + 1] = { card = card, st = cst, head = g.head, body = body, name = g.name, outside = outside }
        local ui = page.secUI and page.secUI[g.name]
        if ui then
            ui.badgeTxt.Text = tostring(n)
            ui.badge.Visible = n > 0
        end
        local function fullH()
            local h, cnt = 0, 0
            for _, ch in ipairs(body:GetChildren()) do
                if ch:IsA("Frame") then h += ch.Size.Y.Offset cnt += 1 end
            end
            return h + math.max(cnt - 1, 0) * 5 + 10
        end
        local token = 0
        local function setCollapsed(c, animate)
            page.collapsed[g.name] = c or nil
            token += 1
            local my = token
            local t = animate and 0.3 or 0
            if ui then
                tw(ui.chev, { Rotation = c and -90 or 0 }, animate and 0.28 or 0, ES.Quint)
                tw(ui.title, { TextColor3 = c and Theme.Sub or Theme.Text }, t)
                tw(ui.line, { BackgroundTransparency = c and 1 or 0.6 }, t)
            end
            local cgs = {}
            for _, h in ipairs(g.rows) do
                local cg = h:FindFirstChildOfClass("CanvasGroup")
                if cg then cgs[#cgs + 1] = cg end
            end
            if c then
                if animate then
                    body.AutomaticSize = Enum.AutomaticSize.None
                    body.Size = UDim2.new(1, 0, 0, fullH())
                    for _, cg in ipairs(cgs) do tw(cg, { GroupTransparency = 1 }, 0.16) end
                    tw(body, { Size = UDim2.new(1, 0, 0, 0) }, 0.3, ES.Quint)
                    task.delay(0.32, function()
                        if token == my then body.Visible = false end
                    end)
                else
                    body.AutomaticSize = Enum.AutomaticSize.None
                    body.Size = UDim2.new(1, 0, 0, 0)
                    body.Visible = false
                end
            else
                body.Visible = true
                if animate then
                    body.AutomaticSize = Enum.AutomaticSize.None
                    for i, cg in ipairs(cgs) do
                        cg.GroupTransparency = 1
                        task.delay(0.05 + math.min(i - 1, 6) * 0.025, function()
                            if token == my then tw(cg, { GroupTransparency = 0 }, 0.25) end
                        end)
                    end
                    tw(body, { Size = UDim2.new(1, 0, 0, fullH()) }, 0.34, ES.Quint)
                    task.delay(0.36, function()
                        if token ~= my then return end
                        body.AutomaticSize = Enum.AutomaticSize.Y
                        body.Size = UDim2.new(1, 0, 0, 0)
                    end)
                else
                    for _, cg in ipairs(cgs) do cg.GroupTransparency = 0 end
                    body.AutomaticSize = Enum.AutomaticSize.Y
                    body.Size = UDim2.new(1, 0, 0, 0)
                end
            end
        end
        if isFill then
            page.secToggle[g.name] = function() end
        else
            page.secToggle[g.name] = function() setCollapsed(not page.collapsed[g.name], true) end
            if page.collapsed[g.name] then setCollapsed(true, false) end
        end
    end
end
function Layout.build(name, page)
    pcall(Layout.flatten, page)
    pcall(Layout.regroup, name, page)
    local ok, err = pcall(Layout.columnize, page)
    if not ok then do end end
end

do
    local p = tabs["Interface"].page
    Section(p, "Interface")
    Toggle(p, "Background Blur", true, function(v)
        blurOn = v
        if visible then
            Perf.blurApply(v)
            tw(blur, { Size = v and Perf.BLUR or 0 }, 0.4)
        end
    end)
    Slider(p, "UI Size", 70, 130, 100, 5, "%", function(v)
        userScale = v / 100
        applyScale()
    end)
    local GLASS_BASE = {}
    for k, v in pairs(Theme.Glass) do if k ~= "Edge" then GLASS_BASE[k] = v end end
    local glassPct, appliedPct, glassPending = 0, 0, false
    local function glassOf(base, pct) return math.clamp(base + (0.92 - base) * pct / 100, 0, 0.95) end
    local function applyGlass()
        for k, b in pairs(GLASS_BASE) do Theme.Glass[k] = glassOf(b, glassPct) end
        for _, o in ipairs(SG:GetDescendants()) do
            if o:IsA("GuiObject") then
                local base = o:GetAttribute("GBase")
                if base == nil then
                    local bt = o.BackgroundTransparency
                    if bt > 0 and bt < 0.95 then
                        for _, b in pairs(GLASS_BASE) do
                            if math.abs(bt - glassOf(b, appliedPct)) < 0.0015 then base = b break end
                        end
                        if base ~= nil then o:SetAttribute("GBase", base) end
                    end
                end
                if base ~= nil then o.BackgroundTransparency = glassOf(base, glassPct) end
            end
        end
        appliedPct = glassPct
    end
    Slider(p, "UI Transparency", 0, 90, 0, 5, "%", function(v)
        glassPct = v
        if glassPending then return end
        glassPending = true
        task.delay(0.08, function()
            glassPending = false
            pcall(applyGlass)
        end)
    end)
    Label(p, "Tap the yin yang button to show / hide. Drag the title bar to move the hub.")
end

do
    local p = tabs["Settings"].page
    local HttpService = game:GetService("HttpService")
    local CONFIG_FILE = "TrigoHub_Config.json"
    local function collectConfig()
        local cfg = { toggles = {}, sliders = {}, dropdowns = {} }
        for name, t in pairs(VisibleToggles) do
            local ok, v = pcall(t.Get)
            if ok then cfg.toggles[name] = v end
        end
        for name, sl in pairs(VisibleSliders) do
            local ok, v = pcall(sl.Get)
            if ok then cfg.sliders[name] = v end
        end
        for name, d in pairs(Perf.VisibleDropdowns or {}) do
            local ok, v = pcall(d.Get)
            if ok and v ~= nil then
                if type(v) == "table" then
                    local list = {}
                    for k in pairs(v) do list[#list + 1] = k end
                    cfg.dropdowns[name] = list
                else
                    cfg.dropdowns[name] = v
                end
            end
        end
        return cfg
    end
    Perf.cfgReady = false
    local saveToken = 0
    function Perf.cfgDirty()
        if not Perf.cfgReady or type(writefile) ~= "function" then return end
        saveToken += 1
        local my = saveToken
        task.delay(1.5, function()
            if my ~= saveToken then return end
            pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(collectConfig())) end)
        end)
    end
    function Perf.autoLoadConfig()
        pcall(function()
            if type(readfile) == "function" and type(isfile) == "function" and isfile(CONFIG_FILE) then
                local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
                if type(data) == "table" then
                    for name, v in pairs(data.toggles or {}) do
                        local t = VisibleToggles[name]
                        if t and type(v) == "boolean" and t.Get() ~= v then pcall(t.Set, v) end
                    end
                    for name, v in pairs(data.sliders or {}) do
                        local sl = VisibleSliders[name]
                        if sl and type(v) == "number" and sl.Get() ~= v then pcall(sl.Set, v) end
                    end
                    for name, v in pairs(data.dropdowns or {}) do
                        local d = (Perf.VisibleDropdowns or {})[name]
                        if d then pcall(d.Set, v) end
                    end
                end
            end
        end)
        Perf.cfgReady = true
    end
    local UI_ONLY = { ["Anonymous Mode"] = true, ["Background Blur"] = true, ["Auto Rejoin"] = true }
    local function stopAll()
        local stopped = 0
        for name, t in pairs(VisibleToggles) do
            if not UI_ONLY[name] then
                local ok, v = pcall(t.Get)
                if ok and v then
                    pcall(t.Set, false)
                    stopped += 1
                end
            end
        end
        notify("Stop All", stopped .. " toggle(s) switched off", 3)
    end
    local function missingCaps()
        local names = {
            "getrawmetatable", "setreadonly", "newcclosure", "getnamecallmethod",
            "getconnections", "getsenv", "getupvalues", "getgc", "getfenv",
            "cloneref", "setfpscap", "writefile", "readfile", "isfile",
            "fireproximityprompt", "queue_on_teleport", "hookfunction",
        }
        local env = _G
        if type(getgenv) == "function" then
            local okEnv, g = pcall(getgenv)
            if okEnv and type(g) == "table" then env = g end
        end
        local miss = {}
        for _, key in ipairs(names) do
            if type(env[key]) ~= "function" and type(_G[key]) ~= "function" then
                miss[#miss + 1] = key
            end
        end
        return miss
    end
    local TeleportService = game:GetService("TeleportService")
    local rejoinConn
    local function setAutoRejoin(on)
        if on and not rejoinConn then
            pcall(function()
                rejoinConn = game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
                    if child.Name == "ErrorPrompt" and getgenv().TrigoAutoRejoin then
                        task.wait(1)
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
                        end)
                    end
                end)
            end)
        elseif not on and rejoinConn then
            pcall(function() rejoinConn:Disconnect() end)
            rejoinConn = nil
        end
    end
    Section(p, "Panic")
    Button(p, "Stop All", stopAll)
    Label(p, "Turns off every running feature instantly.")
    Section(p, "Reconnect")
    Toggle(p, "Auto Rejoin", false, function(v)
        getgenv().TrigoAutoRejoin = v
        setAutoRejoin(v)
    end)
    Section(p, "Compatibility")
    Button(p, "Executor Check", function()
        local miss = missingCaps()
        if #miss == 0 then
            notify("Executor Check", "All required functions are available", 4)
        else
            notify("Executor Check", "Missing: " .. table.concat(miss, ", "), 6)
        end
    end)
    Label(p, "Shows which executor functions this script needs but yours lacks.")
end

do
    local p = tabs["Test"].page
    local function show(v)
        if type(v) == "table" then
            local out = {}
            for k, x in pairs(v) do
                if type(k) == "number" then out[#out + 1] = tostring(x)
                elseif x then out[#out + 1] = tostring(k) end
            end
            return #out > 0 and table.concat(out, ", ") or "None"
        end
        return tostring(v)
    end
    Section(p, "Toggles")
    Toggle(p, "Example Toggle", false, function(v)
        notify("Example Toggle", v and "On" or "Off", 2)
    end)
    Toggle(p, "Toggle Default On", true, function(v)
        notify("Toggle Default On", v and "On" or "Off", 2)
    end)
    Section(p, "Buttons")
    Button(p, "Example Button", function()
        notify("Example Button", "Clicked", 2)
    end)
    Button(p, "Second Button", function()
        notify("Second Button", "Clicked", 2)
    end)
    Section(p, "Sliders")
    Slider(p, "Example Slider", 0, 100, 50, 1, "", function(v)
        notify("Example Slider", "Value: " .. show(v), 2)
    end)
    Slider(p, "Percent Slider", 0, 100, 25, 5, "%", function(v)
        notify("Percent Slider", "Value: " .. show(v) .. "%", 2)
    end)
    Section(p, "Dropdowns")
    Dropdown(p, "Example Dropdown", { "Option 1", "Option 2", "Option 3", "Option 4" }, "Option 1", function(v)
        notify("Example Dropdown", "Selected: " .. show(v), 2)
    end)
    Dropdown(p, "Multi Dropdown", { "Choice A", "Choice B", "Choice C", "Choice D" }, {}, function(v)
        notify("Multi Dropdown", "Selected: " .. show(v), 2)
    end, true)
    Section(p, "Inputs")
    TextInput(p, "Example Input", "", "Type here...", function(v)
        notify("Example Input", "Text: " .. show(v), 2)
    end)
    Label(p, "This is an example label.")
end
pcall(Search.refresh)
for name, tab in pairs(tabs) do Layout.build(name, tab.page) end
switchTab("Home")
task.spawn(Perf.autoLoadConfig)

local loadSteps = {
    { text = "Loading Trigo Hub...", pct = 0.15 },
    { text = "Connecting to server...", pct = 0.35 },
    { text = "Fetching modules...", pct = 0.58 },
    { text = "Building interface...", pct = 0.78 },
    { text = "Applying theme...", pct = 0.92 },
    { text = "Ready!", pct = 1.00 },
}
local SHOW_LOADING = false

task.spawn(function()
    while SG.Parent and not closing do
        if ready then
            TogHolder.Visible = true
            if togScale.Scale < 0.05 then tw(togScale, { Scale = 1 }, 0.4, ES.Back) end
            local ap, sz = TogHolder.AbsolutePosition, SG.AbsoluteSize
            if ap.X < -10 or ap.Y < -10 or ap.X > sz.X - 36 or ap.Y > sz.Y - 36 then
                TogHolder.Position = UDim2.new(0, 12, 0.5, -23)
            end
        end
        task.wait(1)
    end
end)

task.spawn(function()
    if not SHOW_LOADING then
        LoadCard:Destroy()
        loadOutline:Destroy()
        blur.Size = 0
        ParticleBG.BackgroundTransparency = 1
        TogHolder.Visible = true
        togScale.Scale = 1
        ready = true
        Perf.openIntro()
        task.wait(0.5)
        notify("Welcome, " .. shownName(), "Tap the yin yang to show / hide the hub", 4)
        pConn:Disconnect()
        ParticleBG:Destroy()
        return
    end
    tw(blur, { Size = 22 }, 0.9)
    tw(ParticleBG, { BackgroundTransparency = 0.12 }, 0.9)
    tw(pFade, { Value = 1 }, 1.4, ES.Sine)
    task.wait(0.4)
    LoadCard.Visible = true
    loadOutline.Visible = true
    tw(loadScale, { Scale = 1 }, 0.75, ES.Back)
    tw(loadOutScale, { Scale = 1 }, 0.75, ES.Back)
    tw(LoadCard, { GroupTransparency = 0 }, 0.45)
    tw(loadStroke, { Transparency = 0.1 }, 0.6)
    task.wait(0.6)
    for _, s in ipairs(loadSteps) do
        task.spawn(setStatus, s.text)
        tw(progress, { Value = s.pct }, 0.6, ES.Quart)
        task.wait(0.62)
    end
    task.wait(0.3)
    tw(loadScale, { Scale = 0.8 }, 0.45, ES.Quint, ED.In)
    tw(loadOutScale, { Scale = 0.8 }, 0.45, ES.Quint, ED.In)
    tw(LoadCard, { GroupTransparency = 1 }, 0.4)
    tw(loadStroke, { Transparency = 1 }, 0.35)
    task.wait(0.45)
    LoadCard:Destroy()
    loadOutline:Destroy()
    tw(ParticleBG, { BackgroundTransparency = 1 }, 0.7)
    tw(pFade, { Value = 0 }, 0.7)
    tw(blur, { Size = 0 }, 0.8)
    task.wait(0.5)
    TogHolder.Visible = true
    tw(togScale, { Scale = 1 }, 0.6, ES.Back)
    task.wait(0.25)
    ready = true
    Perf.openIntro()
    task.wait(0.5)
    notify("Welcome, " .. shownName(), "Tap the yin yang to show / hide the hub", 4)
    task.wait(0.4)
    pConn:Disconnect()
    ParticleBG:Destroy()
end)
