--!nonstrict
--[[=====================================================================
  SCP: Roleplay - Silent Aim + Player ESP + Mod Menu
  =====================================================================

  Layout
    [0] Boot / executor compatibility
    [1] Services
    [2] Flags
    [3] Notifications (toasts + console)
    [4] UI library (window, tabs, toggle, slider, dropdown, color)
    [5] Helpers (visibility, bounding box, drawing)
    [6] State
    [7] Config (defaults) + save/load
    [8] Silent aim (target finder + BulletHit hook)  <- the part that hits
    [9] ESP (highlight + box + name + distance + healthbar)
   [10] Extra features (noclip, fullbright)
   [11] Menu build
   [12] Render and input loops
   [13] Start / unload

  Adding a new feature (template: noclip in [10]):
    1. add a default:      Config.Player.MyFeature = false
    2. write the setter:   local function setMyFeature(on) ... end
    3. bind a toggle (in [11]):
         local s = playerTab:Section("My section")
         s:Toggle{
             text = "My feature", path = "Player.MyFeature",
             keybind = "MyFeature", defaultKey = Enum.KeyCode.X,   -- optional
             onChanged = function(v) setMyFeature(v) end,
         }
    Saving/loading and the keybind come for free.
=====================================================================]]

--=====================================================================
-- [0] BOOT / EXECUTOR COMPAT
--=====================================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local cloneref = cloneref or function(i: Instance) return i end
local clonefunction = clonefunction or function(f: (...any) -> ...any) return f end
local newcclosure = newcclosure or clonefunction
local executor = identifyexecutor and identifyexecutor() or "Your executor"

--=====================================================================
-- [1] SERVICES / SMALL HELPERS
--=====================================================================
local Players: Players = cloneref(game:GetService("Players"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local UIS: UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService = cloneref(game:GetService("TweenService"))
local HttpService = cloneref(game:GetService("HttpService"))
local Lighting = cloneref(game:GetService("Lighting"))

local plr = Players.LocalPlayer
local startedAt = os.clock()

local function currentCam()
    return workspace.CurrentCamera
end

local function isMobile()
    return UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled
end

local function guiParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and typeof(hui) == "Instance" then return hui end
    end
    return game:GetService("CoreGui")
end

--=====================================================================
-- [2] FLAGS
--=====================================================================
-- true  = download the author's current SCP_Roleplay/main.luau instead of
--         the inlined copy (safer after a game update)
local PREFER_REMOTE_BUILD = false
local SILENT_AIM_URL = "https://sneekysscripts.uk/Scripts/SCP_Roleplay/main.luau"

-- true  = also load the author's own UI (it draws its own FOV circle and
--         tracers). Default false: this menu renders those itself.
local USE_AUTHOR_AIM_UI = false
local SILENT_AIM_UI_URL = "https://sneekysscripts.uk/Scripts/UIs/silent_aim.luau"

-- true  = also load Teams.luau (the author's team alias table)
local FETCH_TEAM_ALIASES = false

-- show the Debug tab in the menu
local DEBUG_AIM = true

local CONFIG_FILE = "scp_aim_esp_config.json"

-- Shown in the console, the title bar and the status line. If this does not
-- change after an update, your executor served a cached copy of the file.
local BUILD = "v2.3 (2026-09-30)"

--=====================================================================
-- [3] NOTIFICATIONS
--=====================================================================
local notifyHolder

local function toast(text: string, color: Color3?)
    local accentColor = color or Color3.fromRGB(88, 166, 255)
    print("[menu] " .. text)
    if not notifyHolder or not notifyHolder.Parent then return end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(258, 34)
    frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Parent = notifyHolder

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = frame

    local s = Instance.new("UIStroke")
    s.Color = accentColor
    s.Transparency = 1
    s.Parent = frame

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, -8)
    accent.Position = UDim2.fromOffset(4, 4)
    accent.BackgroundColor3 = accentColor
    accent.BorderSizePixel = 0
    accent.Parent = frame
    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(1, 0)
    ac.Parent = accent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -22, 1, 0)
    label.Position = UDim2.fromOffset(16, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(232, 236, 242)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.TextTransparency = 1
    label.Text = tostring(text)
    label.Parent = frame

    TweenService:Create(frame, TweenInfo.new(0.18), { BackgroundTransparency = 0.1 }):Play()
    TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
    TweenService:Create(s, TweenInfo.new(0.18), { Transparency = 0.35 }):Play()

    task.delay(4, function()
        if not frame.Parent then return end
        TweenService:Create(frame, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
        TweenService:Create(s, TweenInfo.new(0.25), { Transparency = 1 }):Play()
        task.wait(0.3)
        frame:Destroy()
    end)
end

--=====================================================================
-- [4] UI-LIBRARY
--=====================================================================
local Theme = {
    window = Color3.fromRGB(15, 17, 21),
    sidebar = Color3.fromRGB(11, 13, 16),
    panel = Color3.fromRGB(19, 22, 27),
    element = Color3.fromRGB(27, 30, 37),
    elementHover = Color3.fromRGB(35, 39, 47),
    text = Color3.fromRGB(233, 237, 243),
    dim = Color3.fromRGB(138, 146, 158),
    accent = Color3.fromRGB(88, 166, 255),
    success = Color3.fromRGB(84, 205, 130),
    danger = Color3.fromRGB(236, 96, 96),
    stroke = Color3.fromRGB(43, 47, 57),
}

-- Build an instance. The third argument is the PARENT (that is the calling
-- convention everywhere in this file): new("Frame", {...}, someParent).
local function new(class: string, props: { [string]: any }?, parent: Instance?)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function corner(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = parent
    return s
end

local function pad(parent: Instance, px: number)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, px)
    p.PaddingBottom = UDim.new(0, px)
    p.PaddingLeft = UDim.new(0, px)
    p.PaddingRight = UDim.new(0, px)
    p.Parent = parent
    return p
end

local function list(parent: Instance, gap: number)
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, gap)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

local function hover(inst: GuiObject, from: Color3, to: Color3)
    inst.MouseEnter:Connect(function()
        TweenService:Create(inst, TweenInfo.new(0.12), { BackgroundColor3 = to }):Play()
    end)
    inst.MouseLeave:Connect(function()
        TweenService:Create(inst, TweenInfo.new(0.12), { BackgroundColor3 = from }):Play()
    end)
end

local UI = {
    gui = nil,
    window = nil,
    binders = nil,      -- filled in [11]
    promptBind = nil,   -- element waiting for a key press
    refreshers = {},    -- reads Config and refreshes the visuals
}

function UI:RefreshAll()
    for _, fn in ipairs(self.refreshers) do
        pcall(fn)
    end
end

function UI:Window(spec)
    local screen = new("ScreenGui", {
        Name = "SCP_Menu",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
    })
    screen.Parent = guiParent()
    self.gui = screen

    local scale = Instance.new("UIScale")
    scale.Parent = screen

    local size = spec.size or UDim2.fromOffset(680, 450)
    local win = new("Frame", {
        Name = "Window",
        Size = size,
        Position = spec.position or UDim2.fromOffset(70, 110),
        BackgroundColor3 = Theme.window,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, screen)
    corner(win, 10)
    stroke(win, Theme.stroke, 1, 0.25)

    -- ------------------------------------------------------ title bar
    local bar = new("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Color3.fromRGB(18, 20, 25),
        BorderSizePixel = 0,
    }, win)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.stroke,
        BorderSizePixel = 0,
    }, bar)

    new("TextLabel", {
        Size = UDim2.new(0, 320, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = (spec.title or "Menu") .. (spec.version and ("   " .. spec.version) or ""),
    }, bar)

    local statusLabel = new("TextLabel", {
        Size = UDim2.new(0, 260, 1, 0),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -92, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.dim,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = spec.subtitle or "",
    }, bar)

    local collapseBtn = new("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, -64, 0, 6),
        BackgroundColor3 = Theme.element,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.dim,
        Text = "-",
        AutoButtonColor = false,
        ZIndex = 3,
    }, bar)
    corner(collapseBtn, 6)
    hover(collapseBtn, Theme.element, Theme.elementHover)

    local hideBtn = new("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, -34, 0, 6),
        BackgroundColor3 = Theme.element,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Theme.dim,
        Text = "x",
        AutoButtonColor = false,
        ZIndex = 3,
    }, bar)
    corner(hideBtn, 6)
    hover(hideBtn, Theme.element, Theme.danger)

    -- ---------------------------------------------------- sidebar/content
    local body = new("Frame", {
        Size = UDim2.new(1, 0, 1, -38),
        Position = UDim2.fromOffset(0, 38),
        BackgroundTransparency = 1,
    }, win)

    local sidebar = new("Frame", {
        Size = UDim2.new(0, 158, 1, 0),
        BackgroundColor3 = Theme.sidebar,
        BorderSizePixel = 0,
    }, body)
    local sidebarPad = Instance.new("UIPadding")
    sidebarPad.PaddingTop = UDim.new(0, 10)
    sidebarPad.PaddingLeft = UDim.new(0, 10)
    sidebarPad.PaddingRight = UDim.new(0, 10)
    sidebarPad.Parent = sidebar
    list(sidebar, 4)

    local content = new("Frame", {
        Size = UDim2.new(1, -158, 1, 0),
        Position = UDim2.fromOffset(158, 0),
        BackgroundTransparency = 1,
    }, body)

    local window = {
        gui = screen,
        frame = win,
        scale = scale,
        status = statusLabel,
        tabs = {},
        collapsed = false,
    }

    -- dragging via the title bar
    local dragging, dragStart, startPos = false, nil, nil
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = win.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    collapseBtn.MouseButton1Click:Connect(function()
        window.collapsed = not window.collapsed
        body.Visible = not window.collapsed
        win.Size = window.collapsed and UDim2.new(size.X.Scale, size.X.Offset, 0, 38) or size
        collapseBtn.Text = window.collapsed and "+" or "-"
    end)

    hideBtn.MouseButton1Click:Connect(function()
        screen.Enabled = false
        toast("Menu hidden - press " .. tostring(Config.Keybinds.MenuToggle.Name) .. " to show it again", Theme.accent)
    end)

    function window:SetScale(value: number)
        scale.Scale = value
    end

    function window:SetStatus(text: string)
        statusLabel.Text = text
    end

    function window:Tab(name: string)
        local button = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Theme.element,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = Theme.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "  " .. name,
            AutoButtonColor = false,
        }, sidebar)
        corner(button, 6)

        local page = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.stroke,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        }, content)
        local pagePad = Instance.new("UIPadding")
        pagePad.PaddingTop = UDim.new(0, 12)
        pagePad.PaddingBottom = UDim.new(0, 16)
        pagePad.PaddingLeft = UDim.new(0, 14)
        pagePad.PaddingRight = UDim.new(0, 14)
        pagePad.Parent = page
        local layout = list(page, 8)

        local tab = { page = page, button = button, order = 0, layout = layout }

        button.MouseButton1Click:Connect(function()
            for _, other in pairs(window.tabs) do
                other.page.Visible = false
                TweenService:Create(other.button, TweenInfo.new(0.12), { BackgroundTransparency = 1, TextColor3 = Theme.dim }):Play()
            end
            page.Visible = true
            TweenService:Create(button, TweenInfo.new(0.12), { BackgroundTransparency = 0.15, TextColor3 = Theme.text }):Play()
        end)

        table.insert(window.tabs, tab)
        if #window.tabs == 1 then
            page.Visible = true
            button.BackgroundTransparency = 0.15
            button.TextColor3 = Theme.text
        end

        function tab:Section(title: string)
            return UI:Section(self, title)
        end

        return tab
    end

    return window
end

function UI:Section(tab, title: string)
    local order = tab.order
    tab.order += 2

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = Theme.accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = string.upper(title),
        LayoutOrder = order,
    }, tab.page)

    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = order + 1,
    }, tab.page)
    list(holder, 6)

    local section = { holder = holder, index = 0 }

    function section:next()
        self.index += 1
        return self.index
    end

    function section:Label(text: string, color: Color3?)
        return new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = color or Theme.dim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Text = text,
            LayoutOrder = self:next(),
        }, self.holder)
    end

    function section:Button(spec)
        local b = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.element,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = spec.color or Theme.text,
            Text = spec.text,
            AutoButtonColor = false,
            LayoutOrder = self:next(),
        }, self.holder)
        corner(b, 7)
        stroke(b, Theme.stroke, 1, 0.5)
        hover(b, Theme.element, Theme.elementHover)
        b.MouseButton1Click:Connect(function()
            local ok, err = pcall(spec.callback)
            if not ok then toast("Error: " .. tostring(err), Theme.danger) end
        end)
        return b
    end

    -- Toggle/Slider/Dropdown/Color come from [11] (they need Config)
    function section:Toggle(spec) return UI.binders.Toggle(self, spec) end
    function section:Slider(spec) return UI.binders.Slider(self, spec) end
    function section:Dropdown(spec) return UI.binders.Dropdown(self, spec) end
    function section:Color(spec) return UI.binders.Color(self, spec) end

    return section
end

--=====================================================================
-- [5] HELPERS
--=====================================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function refreshRayFilter()
    local filter: { Instance } = {}
    local char = plr.Character
    if char then table.insert(filter, char) end
    local pathMods = workspace:FindFirstChild("RoleplayPathMods")
    local gunIgnore = workspace:FindFirstChild("Gun_Ignore")
    if pathMods then table.insert(filter, pathMods) end
    if gunIgnore then table.insert(filter, gunIgnore) end
    rayParams.FilterDescendantsInstances = filter
end

local function isVisiblePart(part: BasePart?, origin: Vector3): (boolean, BasePart?)
    if not part then return false, nil end
    refreshRayFilter()
    local result = workspace:Raycast(origin, part.Position - origin, rayParams)
    if not result then return true, nil end
    if result.Instance:IsDescendantOf(part.Parent) then
        return true, result.Instance :: any
    end
    return false, result.Instance :: any
end

local function mousePoint(): Vector2
    if isMobile() then
        local cam = currentCam()
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    end
    return UIS:GetMouseLocation()
end

local function healthColor(frac: number): Color3
    local bad = Color3.fromRGB(236, 96, 96)
    local mid = Color3.fromRGB(236, 196, 96)
    local good = Color3.fromRGB(84, 205, 130)
    frac = math.clamp(frac, 0, 1)
    if frac >= 0.5 then
        return mid:Lerp(good, (frac - 0.5) * 2)
    end
    return bad:Lerp(mid, frac * 2)
end

-- 2D bounding box of a character (nil if it cannot be projected sanely).
-- Corners at or behind the near plane project to extreme coordinates, which
-- used to produce screen-high boxes and healthbars, so they are skipped and
-- the result is clamped to the viewport.
local function projectBox(model: Model)
    local cam = currentCam()
    local ok, cf, size = pcall(function()
        local boxCf, boxSize = model:GetBoundingBox()
        return boxCf, boxSize
    end)
    if not ok or typeof(cf) ~= "CFrame" then return nil end

    local viewW, viewH = cam.ViewportSize.X, cam.ViewportSize.Y
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local corners = 0
    for _, sx in ipairs({ -0.5, 0.5 }) do
        for _, sy in ipairs({ -0.5, 0.5 }) do
            for _, sz in ipairs({ -0.5, 0.5 }) do
                local world = cf * Vector3.new(sx * size.X, sy * size.Y, sz * size.Z)
                local sp, onScreen = cam:WorldToViewportPoint(world)
                if sp.Z > 1 and (onScreen or sp.Z > 0) then
                    corners += 1
                    minX = math.min(minX, sp.X)
                    minY = math.min(minY, sp.Y)
                    maxX = math.max(maxX, sp.X)
                    maxY = math.max(maxY, sp.Y)
                end
            end
        end
    end

    if corners < 2 then return nil end
    minX = math.max(minX, -viewW * 0.25)
    maxX = math.min(maxX, viewW * 1.25)
    minY = math.max(minY, -viewH * 0.25)
    maxY = math.min(maxY, viewH * 1.25)
    if maxX - minX < 2 or maxY - minY < 6 then return nil end
    return minX, minY, maxX, maxY
end

--=====================================================================
-- [6] STATE
--=====================================================================
local State = {
    bulletHit = nil,
    hookOriginal = nil,
    hookInstalled = false,
    aimKeyDown = false,
    espObjects = {},
    espGui = nil,
    fovFrame = nil,
    fovStroke = nil,
    infoLabel = nil,
    visualsGui = nil,
    connections = {},
    unloaded = false,
}

local function keepConnection(conn)
    table.insert(State.connections, conn)
    return conn
end

--=====================================================================
-- [7] CONFIG
--=====================================================================
local Config = {
    Menu = {
        Visible = true,
        Scale = 1,
    },
    Aim = {
        Enabled = true,
        HoldToAim = false,
        FOV = 300,
        ShowFOV = true,
        FOVColor = Color3.fromRGB(88, 166, 255),
        TeamCheck = true,
        VisibleOnly = true,
        TargetPart = "Head",
        IgnoreForcefield = true,
        MaxDistance = 0,
        IgnoreRoles = true,
        RoleIgnoreList = { "researcher", "forscher", "research", "wissenschaftler" },
        TargetInfo = true,
        InfoColor = Color3.fromRGB(240, 240, 240),
    },
    ESP = {
        Enabled = false,
        TeamCheck = true,
        VisibleOnly = false,
        MaxDistance = 0,
        Highlight = true,
        ColorMode = "Team",
        FillColor = Color3.fromRGB(255, 60, 60),
        FillTransparency = 0.45,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        OutlineTransparency = 0,
        AlwaysOnTop = true,
        Box = true,
        BoxThickness = 1,
        BoxTransparency = 0.2,
        Name = true,
        NameColor = Color3.fromRGB(240, 240, 240),
        NameSize = 13,
        Distance = true,
        DistanceColor = Color3.fromRGB(200, 205, 215),
        DistanceSize = 12,
        HealthBar = true,
        HealthBarWidth = 3,
    },
    Player = {
        Noclip = false,
        Fullbright = false,
    },
    Keybinds = {
        MenuToggle = Enum.KeyCode.K,
        AimToggle = Enum.KeyCode.RightShift,
        ESPToggle = Enum.KeyCode.V,
        Noclip = Enum.KeyCode.N,
        Fullbright = Enum.KeyCode.B,
    },
}

local function getPath(path: string)
    local node = Config
    for part in string.gmatch(path, "[^%.]+") do
        node = node[part]
        if node == nil then return nil end
    end
    return node
end

local function setPath(path: string, value: any)
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do table.insert(parts, part) end
    if #parts == 0 then return end
    local node = Config
    for i = 1, #parts - 1 do
        node = node[parts[i]]
        if node == nil then return end
    end
    node[parts[#parts]] = value
end

local function serialize(value)
    local kind = type(value)
    if kind == "number" or kind == "string" or kind == "boolean" then return value end
    if typeof(value) == "Color3" then
        return { __color = { math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5) } }
    end
    if typeof(value) == "EnumItem" then
        return { __enum = tostring(value) }
    end
    if kind == "table" then
        local out = {}
        for k, v in pairs(value) do
            local encoded = serialize(v)
            if encoded ~= nil then out[k] = encoded end
        end
        return out
    end
    return nil
end

local function deserialize(value)
    if type(value) ~= "table" then return value end
    if value.__color then
        return Color3.fromRGB(value.__color[1], value.__color[2], value.__color[3])
    end
    if value.__enum then
        local enumType, enumName = string.match(value.__enum, "Enum%.([^%.]+)%.(.+)")
        if enumType and enumName and Enum[enumType] then
            local item = Enum[enumType][enumName]
            if item then return item end
        end
        return nil
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deserialize(v)
    end
    return out
end

local function saveConfig()
    if typeof(writefile) ~= "function" then
        toast("Executor has no file API (writefile)", Theme.danger)
        return
    end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(serialize(Config))
    end)
    if not ok then
        toast("Save failed: " .. tostring(encoded), Theme.danger)
        return
    end
    local wrote = pcall(writefile, CONFIG_FILE, encoded)
    if wrote then
        toast("Config saved: " .. CONFIG_FILE, Theme.success)
    else
        toast("Write failed", Theme.danger)
    end
end

local function loadConfig(silent: boolean?)
    if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
        if not silent then toast("Executor has no file API (readfile)", Theme.danger) end
        return false
    end
    local checked, exists = pcall(isfile, CONFIG_FILE)
    if not checked or not exists then
        if not silent then toast("No config found", Theme.danger) end
        return false
    end
    local ok, content = pcall(readfile, CONFIG_FILE)
    if not ok or type(content) ~= "string" then
        if not silent then toast("Config not readable", Theme.danger) end
        return false
    end
    local decodedOk, decoded = pcall(function()
        return deserialize(HttpService:JSONDecode(content))
    end)
    if not decodedOk or type(decoded) ~= "table" then
        if not silent then toast("Config is corrupted", Theme.danger) end
        return false
    end
    for group, values in pairs(decoded) do
        if type(Config[group]) == "table" and type(values) == "table" then
            for key, value in pairs(values) do
                if value ~= nil then Config[group][key] = value end
            end
        end
    end
    UI:RefreshAll()
    if not silent then toast("Config loaded", Theme.success) end
    return true
end

--=====================================================================
-- [8] SILENT AIM
--=====================================================================
local AIM_DEBUG = {
    mode = "not started yet",
    hook = "not installed",
    calls = 0,
    hits = 0,
    lastTarget = "-",
    reasons = {},
    controller = false,
    bulletHit = false,
    uiLoaded = false,
}

local function dbgReason(reason: string)
    AIM_DEBUG.reasons[reason] = (AIM_DEBUG.reasons[reason] or 0) + 1
end

local teamAliases = nil
if FETCH_TEAM_ALIASES then
    local ok, res = pcall(function()
        return loadstring(game:HttpGet("https://sneekysscripts.uk/Scripts/SCP_Roleplay/Teams.luau"))()
    end)
    if ok and type(res) == "table" then
        teamAliases = res
    else
        warn("[menu] Teams.luau unavailable, using a plain team comparison")
    end
end

local function isSameTeam(player: Player?, teamlessIsSame: boolean): boolean
    if not player or player == plr then return true end
    if player.Team and player.Team == plr.Team then return true end
    if teamAliases and player.Team and plr.Team then
        local mine, theirs = teamAliases[plr.Team.Name], teamAliases[player.Team.Name]
        if mine ~= nil and theirs ~= nil and mine == theirs then return true end
    end
    if player.Team == nil and plr.Team == nil then return teamlessIsSame end
    return false
end

local function pickTargetPart(char: Model, origin: Vector3): BasePart?
    local mode = Config.Aim.TargetPart
    if mode == "HumanoidRootPart" then
        return char:FindFirstChild("HumanoidRootPart") :: any
    end
    if mode == "Nearest" then
        local best, bestDist = nil, math.huge
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("BasePart") then
                local dist = (child.Position - origin).Magnitude
                if dist < bestDist then
                    best, bestDist = child, dist
                end
            end
        end
        return best
    end
    return (char:FindFirstChild("Head") or char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")) :: any
end

-- Text labels the game puts on a character (role, rank, ...). Cached with weak
-- keys, because scanning every descendant on each aim call is wasteful.
local labelCache = setmetatable({}, { __mode = "k" })

local function characterLabels(player: Player, char: Model): { string }
    local entry = labelCache[char]
    local now = os.clock()
    if entry and (#entry.texts > 0 or now - entry.at < 3) then
        return entry.texts
    end
    local texts = {}
    for _, descendant in ipairs(char:GetDescendants()) do
        if descendant:IsA("TextLabel") then
            local text = descendant.Text
            -- skip the player's own name, so a player named "Researcher" is
            -- not mistaken for the role
            if type(text) == "string" and #text > 0 and text ~= player.Name and text ~= player.DisplayName then
                table.insert(texts, text)
            end
        end
    end
    labelCache[char] = { texts = texts, at = now }
    return texts
end

local function matchesRoleList(text: string?): boolean
    if type(text) ~= "string" or #text == 0 then return false end
    local lower = string.lower(text)
    for _, needle in ipairs(Config.Aim.RoleIgnoreList) do
        if type(needle) == "string" and #needle > 0 and string.find(lower, needle, 1, true) then
            return true
        end
    end
    return false
end

-- true = never aim at this player. Researchers are a role, not always a team,
-- so the team name, role attributes and the character's labels are checked.
local function isIgnoredRole(player: Player, char: Model?): boolean
    if not Config.Aim.IgnoreRoles then return false end
    if matchesRoleList(player.Team and player.Team.Name) then return true end
    for _, attribute in ipairs({ "Role", "RoleName", "Team", "Class", "Job" }) do
        local value = player:GetAttribute(attribute)
        if type(value) == "string" and matchesRoleList(value) then return true end
    end
    if char then
        for _, text in ipairs(characterLabels(player, char)) do
            if matchesRoleList(text) then return true end
        end
    end
    return false
end

-- Returns the target part or nil. forVisual = display only (not counted
-- in the stats and ignores "only while key is held").
local function findTarget(origin: Vector3?, forVisual: boolean?)
    local cfg = Config.Aim
    if not cfg.Enabled then return nil end
    if cfg.HoldToAim and not forVisual and not State.aimKeyDown then return nil end
    if not forVisual then AIM_DEBUG.calls += 1 end

    local cam = currentCam()
    origin = origin or (plr.Character and plr.Character:GetPivot().Position) or cam.CFrame.Position

    local best, bestPlayer, bestDist = nil, nil, cfg.FOV

    for _, player: Player in next, Players:GetPlayers() do
        if player ~= plr then
            if cfg.TeamCheck and isSameTeam(player, false) then
                dbgReason("team")
            else
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if isIgnoredRole(player, char) then
                    dbgReason("ignored role")
                elseif not (char and hum) then
                    dbgReason("no char")
                elseif hum.Health <= 0 then
                    dbgReason("dead")
                elseif cfg.IgnoreForcefield and char:FindFirstChildOfClass("ForceField") then
                    dbgReason("forcefield")
                else
                    local part = pickTargetPart(char, origin)
                    local hrp = char:FindFirstChild("HumanoidRootPart") or part
                    local dist3 = hrp and (cam.CFrame.Position - hrp.Position).Magnitude or 0
                    if not part then
                        dbgReason("no part")
                    elseif cfg.MaxDistance > 0 and dist3 > cfg.MaxDistance then
                        dbgReason("too far")
                    else
                        local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                        if not onScreen then
                            dbgReason("offscreen")
                        else
                            local visible, hitPart = true, nil
                            if cfg.VisibleOnly then
                                visible, hitPart = isVisiblePart(part, origin)
                                if not visible then
                                    local alt = char:FindFirstChild("HumanoidRootPart")
                                    if alt and alt ~= part then
                                        visible, hitPart = isVisiblePart(alt, origin)
                                    end
                                end
                            end
                            if cfg.VisibleOnly and not visible then
                                dbgReason("blocked")
                            else
                                if hitPart then part = hitPart end
                                local px = (Vector2.new(pos.X, pos.Y) - mousePoint()).Magnitude
                                if px < bestDist then
                                    best, bestPlayer, bestDist = part, player, px
                                    dbgReason("accepted")
                                else
                                    dbgReason("outside FOV")
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if best then
        AIM_DEBUG.hits += 1
        AIM_DEBUG.lastTarget = ("%s (%s, %.0fpx)"):format(bestPlayer.Name, best.Name, bestDist)
    end
    return best
end

local function syncAimGlobals()
    getgenv().sneeky_silent_aim = Config.Aim.Enabled
    getgenv().sneeky_fov_size = Config.Aim.FOV
end

-- Hook on Controller.BulletHit: swaps the hit data for the target.
-- Without this hook the UI only draws tracers and nothing ever gets hit.
local function installHook(): (boolean, string)
    AIM_DEBUG.hook = "not installed"

    if PREFER_REMOTE_BUILD then
        local ok = pcall(function()
            loadstring(game:HttpGet(SILENT_AIM_URL))()
        end)
        if ok then
            AIM_DEBUG.mode = "main.luau (author build, remote)"
            AIM_DEBUG.hook = "managed by the author build"
            return true, AIM_DEBUG.hook
        end
        warn("[menu] " .. SILENT_AIM_URL .. " failed, using the inlined code")
    end
    AIM_DEBUG.mode = "inlined (main.luau code + own menu)"

    local controller = plr.PlayerScripts:FindFirstChild("Controller")
    if not (hookfunction and getsenv and controller) then
        AIM_DEBUG.hook = "hookfunction/getsenv/Controller missing"
        return false, AIM_DEBUG.hook
    end
    AIM_DEBUG.controller = true

    local bulletHit
    for _ = 1, 50 do
        local env = select(2, pcall(getsenv, controller))
        if type(env) == "table" and env.BulletHit then
            bulletHit = env.BulletHit
            break
        end
        task.wait()
    end
    if not bulletHit then
        AIM_DEBUG.hook = "Controller.BulletHit not found"
        return false, AIM_DEBUG.hook
    end
    AIM_DEBUG.bulletHit = true
    State.bulletHit = bulletHit

    if USE_AUTHOR_AIM_UI then
        AIM_DEBUG.uiLoaded = pcall(function()
            loadstring(game:HttpGet(SILENT_AIM_UI_URL))()(Config.Aim.FOV, findTarget, true)
        end)
    end

    local ok, err = pcall(function()
        local old
        old = clonefunction(hookfunction(bulletHit, newcclosure(function(_, hitData, ...)
            local target = findTarget(currentCam().CFrame.Position)
            if target then
                return old(_, {
                    ["Instance"] = target,
                    ["Position"] = target.Position,
                    ["Normal"] = Vector3.new(0, 1, 0),
                    ["Material"] = target.Material,
                }, ...)
            end
            return old(_, hitData, ...)
        end)))
        State.hookOriginal = old
        State.hookInstalled = old ~= nil
    end)

    if not ok or not State.hookInstalled then
        AIM_DEBUG.hook = "failed: " .. tostring(err or "hookfunction returned nothing")
        return false, AIM_DEBUG.hook
    end

    AIM_DEBUG.hook = "installed on Controller.BulletHit"
    return true, AIM_DEBUG.hook
end

--=====================================================================
-- [9] ESP
--=====================================================================
local function espColor(p: Player, char: Model): Color3
    local cfg = Config.ESP
    if cfg.ColorMode == "Team" and p.Team then
        return p.Team.TeamColor.Color
    elseif cfg.ColorMode == "Health" then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MaxHealth > 0 then
            return healthColor(hum.Health / hum.MaxHealth)
        end
    elseif cfg.ColorMode == "Distance" then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dist = (currentCam().CFrame.Position - hrp.Position).Magnitude
            return healthColor(1 - dist / 300)
        end
    end
    return cfg.FillColor
end

local function createESPObjects(p: Player)
    local cfg = Config.ESP
    local parent = State.espGui or UI.gui
    local objects = {}

    local hl = Instance.new("Highlight")
    hl.Name = "esp_hl_" .. p.UserId
    hl.FillTransparency = cfg.FillTransparency
    hl.OutlineTransparency = cfg.OutlineTransparency
    hl.OutlineColor = cfg.OutlineColor
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = parent
    objects.highlight = hl

    local box = new("Frame", {
        Name = "esp_box_" .. p.UserId,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
    }, parent)
    objects.box = box
    objects.boxStroke = stroke(box, Color3.new(1, 1, 1), cfg.BoxThickness, cfg.BoxTransparency)

    objects.name = new("TextLabel", {
        Name = "esp_name_" .. p.UserId,
        Size = UDim2.new(0, 200, 0, 16),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = cfg.NameSize,
        TextColor3 = cfg.NameColor,
        TextStrokeTransparency = 0.4,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        Text = p.Name,
        Visible = false,
    }, parent)

    objects.dist = new("TextLabel", {
        Name = "esp_dist_" .. p.UserId,
        Size = UDim2.new(0, 200, 0, 14),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = cfg.DistanceSize,
        TextColor3 = cfg.DistanceColor,
        TextStrokeTransparency = 0.4,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        Text = "",
        Visible = false,
    }, parent)

    local hpBg = new("Frame", {
        Name = "esp_hpbg_" .. p.UserId,
        BackgroundColor3 = Color3.fromRGB(15, 15, 15),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Visible = false,
    }, parent)
    corner(hpBg, 2)
    local hpFill = new("Frame", {
        Name = "esp_hp_" .. p.UserId,
        Size = UDim2.new(1, 0, 1, 0),
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.success,
        BorderSizePixel = 0,
    }, hpBg)
    corner(hpFill, 2)
    objects.hpBg = hpBg
    objects.hpFill = hpFill

    return objects
end

local function destroyESPObjects(p: Player)
    local objects = State.espObjects[p]
    if not objects then return end
    for _, inst in pairs(objects) do
        if typeof(inst) == "Instance" then
            inst:Destroy()
        end
    end
    State.espObjects[p] = nil
end

local function clearESP()
    for p in pairs(State.espObjects) do
        destroyESPObjects(p)
    end
end

local function updateESP()
    local cfg = Config.ESP
    if not cfg.Enabled then
        if next(State.espObjects) then clearESP() end
        return
    end

    local cam = currentCam()
    for _, p in next, Players:GetPlayers() do
        if p ~= plr then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")

            local show, dist = false, 0
            if char and hum and hrp and hum.Health > 0 then
                dist = (cam.CFrame.Position - hrp.Position).Magnitude
                if not (cfg.TeamCheck and isSameTeam(p, true)) then
                    if cfg.MaxDistance <= 0 or dist <= cfg.MaxDistance then
                        if cfg.VisibleOnly then
                            show = isVisiblePart(char:FindFirstChild("Head") or hrp, cam.CFrame.Position)
                        else
                            show = true
                        end
                    end
                end
            end

            if show then
                local objects = State.espObjects[p]
                if not objects then
                    objects = createESPObjects(p)
                    State.espObjects[p] = objects
                end

                local color = espColor(p, char)

                objects.highlight.Enabled = cfg.Highlight
                objects.highlight.Adornee = char
                objects.highlight.FillColor = color
                objects.highlight.FillTransparency = cfg.FillTransparency
                objects.highlight.OutlineColor = cfg.OutlineColor
                objects.highlight.OutlineTransparency = cfg.OutlineTransparency
                objects.highlight.DepthMode = cfg.AlwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded

                -- must be a multiple assignment: projectBox returns four values
                local minX, minY, maxX, maxY = projectBox(char)
                if minX then
                    local w, h = maxX - minX, maxY - minY

                    objects.box.Visible = cfg.Box
                    objects.box.Position = UDim2.fromOffset(math.floor(minX), math.floor(minY))
                    objects.box.Size = UDim2.fromOffset(math.max(1, math.floor(w)), math.max(1, math.floor(h)))
                    objects.boxStroke.Color = color
                    objects.boxStroke.Thickness = cfg.BoxThickness
                    objects.boxStroke.Transparency = cfg.BoxTransparency

                    objects.name.Visible = cfg.Name
                    objects.name.Position = UDim2.fromOffset(math.floor(minX + w / 2 - 100), math.floor(minY - 16))
                    objects.name.Text = p.Name
                    objects.name.TextColor3 = cfg.NameColor
                    objects.name.TextSize = cfg.NameSize

                    objects.dist.Visible = cfg.Distance
                    objects.dist.Position = UDim2.fromOffset(math.floor(minX + w / 2 - 100), math.floor(maxY + 2))
                    objects.dist.Text = ("%d studs"):format(math.floor(dist))
                    objects.dist.TextColor3 = cfg.DistanceColor
                    objects.dist.TextSize = cfg.DistanceSize

                    if cfg.HealthBar and hum and hum.MaxHealth > 0 then
                        local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        objects.hpBg.Visible = true
                        objects.hpBg.Size = UDim2.fromOffset(cfg.HealthBarWidth, math.max(1, math.floor(h)))
                        objects.hpBg.Position = UDim2.fromOffset(math.floor(minX - cfg.HealthBarWidth - 3), math.floor(minY))
                        objects.hpFill.Size = UDim2.new(1, 0, frac, 0)
                        objects.hpFill.BackgroundColor3 = healthColor(frac)
                    else
                        objects.hpBg.Visible = false
                    end
                else
                    objects.box.Visible = false
                    objects.name.Visible = false
                    objects.dist.Visible = false
                    objects.hpBg.Visible = false
                end
            elseif State.espObjects[p] then
                destroyESPObjects(p)
            end
        end
    end
end

--=====================================================================
-- [10] EXTRA FEATURES  (template for new features)
--=====================================================================
local Noclip = { saved = nil }

local function noclipApply()
    local char = plr.Character
    if not char then return end
    Noclip.saved = Noclip.saved or {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then
            Noclip.saved[d] = true
            d.CanCollide = false
        end
    end
end

local function setNoclip(on: boolean)
    if on then
        noclipApply()
        toast("Noclip ON (may be detected by anti-cheat)", Theme.success)
    else
        if Noclip.saved then
            for part in pairs(Noclip.saved) do
                if typeof(part) == "Instance" and part.Parent then
                    part.CanCollide = true
                end
            end
        end
        Noclip.saved = nil
        toast("Noclip OFF", Theme.dim)
    end
end

local Fullbright = { saved = nil }

local function setFullbright(on: boolean)
    if on then
        if not Fullbright.saved then
            Fullbright.saved = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                GlobalShadows = Lighting.GlobalShadows,
                FogEnd = Lighting.FogEnd,
                ExposureCompensation = Lighting.ExposureCompensation,
            }
        end
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        toast("Fullbright ON", Theme.success)
    else
        if Fullbright.saved then
            for key, value in pairs(Fullbright.saved) do
                Lighting[key] = value
            end
        end
        Fullbright.saved = nil
        toast("Fullbright OFF", Theme.dim)
    end
end

--=====================================================================
-- [11] MENU BUILD
--=====================================================================
-- Visuals (FOV ring, target info, ESP, toasts) live in their own ScreenGui, so
-- hiding the menu with K does not hide them.
local visualsGui = new("ScreenGui", {
    Name = "SCP_Visuals",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 99,
}, guiParent())
State.visualsGui = visualsGui
State.espGui = visualsGui

notifyHolder = new("Frame", {
    Name = "Notifications",
    Size = UDim2.new(0, 262, 0, 400),
    Position = UDim2.new(1, -278, 0, 60),
    BackgroundTransparency = 1,
}, visualsGui)
list(notifyHolder, 6)

-- Load the config and install the aim BEFORE the menu is built, so that
-- hitting does not depend on the UI building without errors.
pcall(function()
    loadConfig(true)
end)
syncAimGlobals()
if Config.Aim.Enabled and not State.hookInstalled then
    local ok, reason = pcall(installHook)
    if not ok then AIM_DEBUG.hook = "Error: " .. tostring(reason) end
end

local window = UI:Window({
    title = "SCP:RP",
    subtitle = BUILD .. "  |  " .. executor .. "  |  " .. tostring(#Players:GetPlayers()) .. " players",
    version = BUILD,
    size = UDim2.fromOffset(680, 450),
    position = UDim2.fromOffset(70, 110),
})

-- ------------------------------------------------------- element binders
local function bindToggle(section, spec)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.element,
        BorderSizePixel = 0,
        LayoutOrder = section:next(),
    }, section.holder)
    corner(holder, 7)
    stroke(holder, Theme.stroke, 1, 0.5)

    new("TextLabel", {
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = spec.text,
    }, holder)

    local pill = new("Frame", {
        Size = UDim2.fromOffset(38, 20),
        Position = UDim2.new(1, -50, 0.5, -10),
        BackgroundColor3 = Theme.stroke,
        BorderSizePixel = 0,
    }, holder)
    corner(pill, 10)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(210, 214, 220),
        BorderSizePixel = 0,
    }, pill)
    corner(knob, 8)

    local keyBtn
    if spec.keybind then
        keyBtn = new("TextButton", {
            Size = UDim2.fromOffset(52, 20),
            Position = UDim2.new(1, -108, 0.5, -10),
            BackgroundColor3 = Theme.window,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = Theme.dim,
            Text = "-",
            AutoButtonColor = false,
            ZIndex = 3,
        }, holder)
        corner(keyBtn, 5)
        stroke(keyBtn, Theme.stroke, 1, 0.4)
    end

    local function draw()
        local on = getPath(spec.path) and true or false
        TweenService:Create(pill, TweenInfo.new(0.15), {
            BackgroundColor3 = on and Theme.accent or Theme.stroke,
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = on and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2),
        }):Play()
    end

    local function apply(value, fire)
        setPath(spec.path, value)
        draw()
        if fire and spec.onChanged then
            local ok, err = pcall(spec.onChanged, value)
            if not ok then toast("Error: " .. tostring(err), Theme.danger) end
        end
    end

    local clickRow = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 1,
    }, holder)
    clickRow.MouseButton1Click:Connect(function()
        apply(not getPath(spec.path), true)
    end)

    local function refreshKey()
        if keyBtn and spec.keybind then
            local key = Config.Keybinds[spec.keybind]
            keyBtn.Text = key and key.Name or "-"
        end
    end

    if keyBtn then
        keyBtn.MouseButton1Click:Connect(function()
            UI.promptBind = { keybind = spec.keybind, refresh = refreshKey }
            keyBtn.Text = "..."
        end)
    end

    table.insert(UI.refreshers, function()
        draw()
        refreshKey()
    end)
    draw()
    refreshKey()

    local element = {}
    function element:Set(value) apply(value, true) end
    function element:Get() return getPath(spec.path) end
    return element
end

local function bindSlider(section, spec)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Theme.element,
        BorderSizePixel = 0,
        LayoutOrder = section:next(),
    }, section.holder)
    corner(holder, 7)
    stroke(holder, Theme.stroke, 1, 0.5)

    new("TextLabel", {
        Size = UDim2.new(0.72, 0, 0, 18),
        Position = UDim2.fromOffset(12, 4),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = spec.text,
    }, holder)

    local valueLabel = new("TextLabel", {
        Size = UDim2.new(0.28, -12, 0, 18),
        Position = UDim2.new(0.72, 0, 0, 4),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.accent,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = "",
    }, holder)

    local track = new("Frame", {
        Size = UDim2.new(1, -24, 0, 8),
        Position = UDim2.fromOffset(12, 28),
        BackgroundColor3 = Theme.window,
        BorderSizePixel = 0,
        Active = true,
    }, holder)
    corner(track, 4)

    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
    }, track)
    corner(fill, 4)

    local dragging = false
    local decimals = spec.decimals or 0
    local step = spec.step or 1
    local span = math.max(0.0001, spec.max - spec.min)

    local function formatValue(value)
        local text
        if decimals > 0 then
            text = string.format("%." .. decimals .. "f", value)
        else
            text = tostring(math.floor(value + 0.5))
        end
        return text .. (spec.suffix or "")
    end

    local function draw(value)
        local frac = math.clamp((value - spec.min) / span, 0, 1)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        valueLabel.Text = formatValue(value)
    end

    local function commit(value, fire)
        value = math.clamp(value, spec.min, spec.max)
        value = math.floor(value / step + 0.5) * step
        setPath(spec.path, value)
        draw(value)
        if fire and spec.onChanged then
            local ok, err = pcall(spec.onChanged, value)
            if not ok then toast("Error: " .. tostring(err), Theme.danger) end
        end
    end

    local function valueFromX(mouseX: number)
        local frac = math.clamp((mouseX - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        return spec.min + frac * span
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            commit(valueFromX(input.Position.X), true)
        end
    end)
    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    keepConnection(UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            commit(valueFromX(input.Position.X), true)
        end
    end))

    table.insert(UI.refreshers, function()
        local value = getPath(spec.path)
        if type(value) == "number" then draw(value) end
    end)
    local initial = getPath(spec.path)
    if type(initial) == "number" then draw(initial) end

    local element = {}
    function element:Set(value) commit(value, true) end
    return element
end

local function bindDropdown(section, spec)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Theme.element,
        BorderSizePixel = 0,
        LayoutOrder = section:next(),
    }, section.holder)
    corner(holder, 7)
    stroke(holder, Theme.stroke, 1, 0.5)

    new("TextLabel", {
        Size = UDim2.new(0.55, 0, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = spec.text,
    }, holder)

    local valueLabel = new("TextLabel", {
        Size = UDim2.new(0.45, -12, 1, 0),
        Position = UDim2.new(0.55, 0, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Theme.accent,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = "",
    }, holder)

    local popup, backdrop
    local function closePopup()
        if popup then popup:Destroy(); popup = nil end
        if backdrop then backdrop:Destroy(); backdrop = nil end
    end

    local button = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
    }, holder)

    button.MouseButton1Click:Connect(function()
        if popup then
            closePopup()
            return
        end

        backdrop = new("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 40,
        }, UI.gui)
        backdrop.MouseButton1Click:Connect(closePopup)

        popup = new("Frame", {
            Size = UDim2.fromOffset(math.max(120, holder.AbsoluteSize.X), #spec.options * 24 + 8),
            Position = UDim2.fromOffset(holder.AbsolutePosition.X, holder.AbsolutePosition.Y + holder.AbsoluteSize.Y + 4),
            BackgroundColor3 = Theme.panel,
            BorderSizePixel = 0,
            ZIndex = 41,
        }, UI.gui)
        corner(popup, 7)
        stroke(popup, Theme.stroke, 1, 0.2)
        list(popup, 2)
        pad(popup, 4)

        for _, option in ipairs(spec.options) do
            local item = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundColor3 = Theme.element,
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = getPath(spec.path) == option and Theme.accent or Theme.text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "  " .. tostring(option),
                AutoButtonColor = false,
                ZIndex = 42,
            }, popup)
            corner(item, 5)
            hover(item, Theme.element, Theme.elementHover)
            item.MouseButton1Click:Connect(function()
                setPath(spec.path, option)
                valueLabel.Text = tostring(option)
                if spec.onChanged then
                    local ok, err = pcall(spec.onChanged, option)
                    if not ok then toast("Error: " .. tostring(err), Theme.danger) end
                end
                closePopup()
            end)
        end
    end)

    local function refresh()
        local value = getPath(spec.path)
        valueLabel.Text = tostring(value)
    end
    table.insert(UI.refreshers, refresh)
    refresh()

    local element = {}
    function element:Set(value)
        setPath(spec.path, value)
        refresh()
        if spec.onChanged then pcall(spec.onChanged, value) end
    end
    return element
end

local function bindColor(section, spec)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Theme.element,
        BorderSizePixel = 0,
        LayoutOrder = section:next(),
    }, section.holder)
    corner(holder, 7)
    stroke(holder, Theme.stroke, 1, 0.5)

    new("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = spec.text,
    }, holder)

    local swatch = new("TextButton", {
        Size = UDim2.fromOffset(52, 18),
        Position = UDim2.new(1, -64, 0.5, -9),
        BackgroundColor3 = getPath(spec.path) or Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
    }, holder)
    corner(swatch, 5)
    stroke(swatch, Theme.stroke, 1, 0.3)

    local popup, backdrop
    local function closePopup()
        if popup then popup:Destroy(); popup = nil end
        if backdrop then backdrop:Destroy(); backdrop = nil end
    end

    swatch.MouseButton1Click:Connect(function()
        if popup then
            closePopup()
            return
        end

        backdrop = new("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 40,
        }, UI.gui)
        backdrop.MouseButton1Click:Connect(closePopup)

        popup = new("Frame", {
            Size = UDim2.fromOffset(220, 132),
            Position = UDim2.fromOffset(
                math.max(4, holder.AbsolutePosition.X - 160),
                holder.AbsolutePosition.Y + holder.AbsoluteSize.Y + 4
            ),
            BackgroundColor3 = Theme.panel,
            BorderSizePixel = 0,
            ZIndex = 41,
        }, UI.gui)
        corner(popup, 8)
        stroke(popup, Theme.stroke, 1, 0.2)

        local current = getPath(spec.path) or Color3.new(1, 1, 1)

        local preview = new("Frame", {
            Size = UDim2.new(1, -20, 0, 22),
            Position = UDim2.fromOffset(10, 10),
            BackgroundColor3 = current,
            BorderSizePixel = 0,
            ZIndex = 42,
        }, popup)
        corner(preview, 6)

        local function applyColor()
            setPath(spec.path, current)
            swatch.BackgroundColor3 = current
            preview.BackgroundColor3 = current
            if spec.onChanged then
                local ok, err = pcall(spec.onChanged, current)
                if not ok then toast("Error: " .. tostring(err), Theme.danger) end
            end
        end

        local channels = { "R", "G", "B" }
        for index, channel in ipairs(channels) do
            local startFrac = (channel == "R" and current.R) or (channel == "G" and current.G) or current.B

            local trackHolder = new("Frame", {
                Size = UDim2.new(1, -20, 0, 22),
                Position = UDim2.fromOffset(10, 40 + (index - 1) * 26),
                BackgroundTransparency = 1,
                ZIndex = 42,
            }, popup)

            new("TextLabel", {
                Size = UDim2.fromOffset(14, 22),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                TextColor3 = Theme.dim,
                Text = channel,
                ZIndex = 43,
            }, trackHolder)

            local track = new("Frame", {
                Size = UDim2.new(1, -20, 0, 8),
                Position = UDim2.fromOffset(18, 7),
                BackgroundColor3 = Theme.window,
                BorderSizePixel = 0,
                Active = true,
                ZIndex = 43,
            }, trackHolder)
            corner(track, 4)

            local fill = new("Frame", {
                Size = UDim2.new(startFrac, 0, 1, 0),
                BackgroundColor3 = Theme.accent,
                BorderSizePixel = 0,
                ZIndex = 44,
            }, track)
            corner(fill, 4)

            local dragging = false
            local function setFromX(mouseX)
                local frac = math.clamp((mouseX - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
                local value = math.floor(frac * 255 + 0.5)
                local r = math.floor(current.R * 255 + 0.5)
                local g = math.floor(current.G * 255 + 0.5)
                local b = math.floor(current.B * 255 + 0.5)
                if channel == "R" then
                    current = Color3.fromRGB(value, g, b)
                elseif channel == "G" then
                    current = Color3.fromRGB(r, value, b)
                else
                    current = Color3.fromRGB(r, g, value)
                end
                fill.Size = UDim2.new(frac, 0, 1, 0)
                applyColor()
            end

            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    setFromX(input.Position.X)
                end
            end)
            track.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            keepConnection(UIS.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    setFromX(input.Position.X)
                end
            end))
        end
    end)

    table.insert(UI.refreshers, function()
        local color = getPath(spec.path)
        if typeof(color) == "Color3" then swatch.BackgroundColor3 = color end
    end)

    local element = {}
    function element:Set(value)
        setPath(spec.path, value)
        swatch.BackgroundColor3 = value
        if spec.onChanged then pcall(spec.onChanged, value) end
    end
    return element
end

UI.binders = { Toggle = bindToggle, Slider = bindSlider, Dropdown = bindDropdown, Color = bindColor }

-- ------------------------------------------------------ silent aim tab
local function onAimEnabledChanged(value)
    syncAimGlobals()
    if value and not State.hookInstalled then
        local ok, reason = pcall(installHook)
        if not ok then
            AIM_DEBUG.hook = "Error: " .. tostring(reason)
            toast("Hook installation failed: " .. tostring(reason), Theme.danger)
        else
            toast("Hook: " .. AIM_DEBUG.hook, Theme.success)
        end
    end
end

local menuOk, menuErr = pcall(function()
    local aimTab = window:Tab("Silent Aim")
    do
        local s = aimTab:Section("Targeting")
        s:Toggle({
            text = "Silent aim enabled", path = "Aim.Enabled", keybind = "AimToggle",
            onChanged = onAimEnabledChanged,
        })
        s:Toggle({ text = "Only while key is held", path = "Aim.HoldToAim" })
        s:Slider({ text = "FOV (radius)", path = "Aim.FOV", min = 20, max = 1200, step = 10, suffix = " px",
            onChanged = syncAimGlobals })
        s:Slider({ text = "Max distance (0 = ignore)", path = "Aim.MaxDistance", min = 0, max = 2000, step = 25, suffix = " studs" })
        s:Toggle({ text = "Team check", path = "Aim.TeamCheck" })
        s:Toggle({ text = "Visible targets only", path = "Aim.VisibleOnly" })
        s:Toggle({ text = "Ignore ForceField", path = "Aim.IgnoreForcefield" })
        s:Toggle({ text = "Never target researchers", path = "Aim.IgnoreRoles" })
        s:Label("Role words: " .. table.concat(Config.Aim.RoleIgnoreList, ", "))
        s:Dropdown({ text = "Target part", path = "Aim.TargetPart", options = { "Head", "HumanoidRootPart", "Nearest" } })

        local v = aimTab:Section("Visuals")
        v:Toggle({ text = "FOV circle", path = "Aim.ShowFOV" })
        v:Color({ text = "FOV color", path = "Aim.FOVColor" })
        v:Toggle({ text = "Target info at the crosshair", path = "Aim.TargetInfo" })
        v:Color({ text = "Info color", path = "Aim.InfoColor" })
    end

    local espTab = window:Tab("ESP")
    do
        local s = espTab:Section("General")
        s:Toggle({ text = "ESP enabled", path = "ESP.Enabled", keybind = "ESPToggle" })
        s:Toggle({ text = "Team check", path = "ESP.TeamCheck" })
        s:Toggle({ text = "Visible players only", path = "ESP.VisibleOnly" })
        s:Slider({ text = "Max distance (0 = ignore)", path = "ESP.MaxDistance", min = 0, max = 3000, step = 50, suffix = " studs" })

        local c = espTab:Section("Chams (Highlight)")
        c:Toggle({ text = "Highlight", path = "ESP.Highlight" })
        c:Dropdown({ text = "Color by", path = "ESP.ColorMode", options = { "Static", "Team", "Health", "Distance" } })
        c:Color({ text = "Fill color (static)", path = "ESP.FillColor" })
        c:Slider({ text = "Fill transparency", path = "ESP.FillTransparency", min = 0, max = 1, step = 0.05, decimals = 2 })
        c:Color({ text = "Outline color", path = "ESP.OutlineColor" })
        c:Slider({ text = "Outline transparency", path = "ESP.OutlineTransparency", min = 0, max = 1, step = 0.05, decimals = 2 })
        c:Toggle({ text = "Always visible through walls", path = "ESP.AlwaysOnTop" })

        local b = espTab:Section("2D elements")
        b:Toggle({ text = "Box", path = "ESP.Box" })
        b:Slider({ text = "Box thickness", path = "ESP.BoxThickness", min = 1, max = 5, step = 1, suffix = " px" })
        b:Slider({ text = "Box transparency", path = "ESP.BoxTransparency", min = 0, max = 1, step = 0.05, decimals = 2 })
        b:Toggle({ text = "Name", path = "ESP.Name" })
        b:Color({ text = "Name color", path = "ESP.NameColor" })
        b:Slider({ text = "Name size", path = "ESP.NameSize", min = 8, max = 22, step = 1 })
        b:Toggle({ text = "Distance", path = "ESP.Distance" })
        b:Color({ text = "Distance color", path = "ESP.DistanceColor" })
        b:Slider({ text = "Distance size", path = "ESP.DistanceSize", min = 8, max = 22, step = 1 })
        b:Toggle({ text = "Healthbar", path = "ESP.HealthBar" })
        b:Slider({ text = "Healthbar width", path = "ESP.HealthBarWidth", min = 1, max = 8, step = 1, suffix = " px" })
    end

    local playerTab = window:Tab("Player")
    do
        local s = playerTab:Section("Movement")
        s:Toggle({
            text = "Noclip", path = "Player.Noclip", keybind = "Noclip",
            onChanged = function(value) setNoclip(value) end,
        })
        s:Label("Template: add new features as a section + toggle (see the header comment).")

        local w = playerTab:Section("World")
        w:Toggle({
            text = "Fullbright", path = "Player.Fullbright", keybind = "Fullbright",
            onChanged = function(value) setFullbright(value) end,
        })
    end

    local settingsTab = window:Tab("Settings")
    do
        local m = settingsTab:Section("Menu")
        m:Toggle({ text = "Menu visible", path = "Menu.Visible", keybind = "MenuToggle", onChanged = function(value)
            UI.gui.Enabled = value
        end })
        m:Slider({ text = "UI scale", path = "Menu.Scale", min = 0.7, max = 1.4, step = 0.05, decimals = 2,
            onChanged = function(value) window:SetScale(value) end })

        local c = settingsTab:Section("Config")
        c:Label("Saves all options to " .. CONFIG_FILE .. " (requires writefile).")
        c:Button({ text = "Save config", callback = saveConfig })
        c:Button({ text = "Load config", callback = function() loadConfig(false) end })
        c:Button({ text = "Delete config", color = Theme.danger, callback = function()
            if typeof(delfile) == "function" then
                pcall(delfile, CONFIG_FILE)
                toast("Config deleted", Theme.danger)
            else
                toast("Executor has no delfile", Theme.danger)
            end
        end })

        local u = settingsTab:Section("Script")
        u:Label("Build: " .. AIM_DEBUG.mode)
        u:Button({ text = "Re-centre menu", callback = function()
            window.frame.Position = UDim2.fromOffset(70, 110)
        end })
        u:Button({ text = "Unload (remove everything)", color = Theme.danger, callback = function()
            if _G.__scpUnload then _G.__scpUnload() end
        end })
    end

    if DEBUG_AIM then
        local debugTab = window:Tab("Debug")
        local s = debugTab:Section("Silent Aim")
        debugTab.labels = {
            mode = s:Label("Build: " .. AIM_DEBUG.mode),
            hook = s:Label("Hook: " .. AIM_DEBUG.hook),
            env = s:Label(""),
            calls = s:Label(""),
            last = s:Label(""),
            reasons = s:Label(""),
            players = s:Label(""),
        }
    end
end)

if not menuOk then
    warn("[menu] UI build failed: " .. tostring(menuErr))
end

--=====================================================================
-- [12] RENDER AND INPUT LOOPS
--=====================================================================
local function ensureAimVisuals()
    if State.fovFrame then return end
    local parent = State.visualsGui or UI.gui or guiParent()

    local fov = new("Frame", {
        Name = "FOV",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
    }, parent)
    corner(fov, 999)
    State.fovStroke = stroke(fov, Theme.accent, 1.5, 0)
    State.fovFrame = fov

    State.infoLabel = new("TextLabel", {
        Name = "TargetInfo",
        Size = UDim2.fromOffset(260, 16),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Theme.text,
        TextStrokeTransparency = 0.35,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        Text = "",
        Visible = false,
    }, parent)
end

local function updateAimVisuals()
    local cfg = Config.Aim
    if not State.visualsGui then return end
    ensureAimVisuals()
    local active = cfg.Enabled and not USE_AUTHOR_AIM_UI

    if active and cfg.ShowFOV then
        local point = mousePoint()
        State.fovFrame.Visible = true
        State.fovFrame.Size = UDim2.fromOffset(cfg.FOV * 2, cfg.FOV * 2)
        State.fovFrame.Position = UDim2.fromOffset(math.floor(point.X - cfg.FOV), math.floor(point.Y - cfg.FOV))
        State.fovStroke.Color = cfg.FOVColor
    else
        State.fovFrame.Visible = false
    end

    local target, targetPlayer
    if active and cfg.TargetInfo then
        target = findTarget(currentCam().CFrame.Position, true)
        if target then
            targetPlayer = Players:GetPlayerFromCharacter(target.Parent :: any)
        end
    end

    if active and cfg.TargetInfo and target and targetPlayer then
        local char = targetPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local dist = (currentCam().CFrame.Position - target.Position).Magnitude
        local point = mousePoint()
        State.infoLabel.Visible = true
        State.infoLabel.TextColor3 = cfg.InfoColor
        State.infoLabel.Text = ("%s  |  %d HP  |  %d studs"):format(
            targetPlayer.Name,
            hum and math.floor(hum.Health) or 0,
            math.floor(dist)
        )
        State.infoLabel.Position = UDim2.fromOffset(math.floor(point.X - 130), math.floor(point.Y + 24))
    else
        State.infoLabel.Visible = false
    end
end

local function updateDebugTab()
    if not DEBUG_AIM then return end
    for _, tab in ipairs(window.tabs) do
        if tab.labels then
            local labels = tab.labels
            labels.mode.Text = "Build: " .. AIM_DEBUG.mode
            labels.hook.Text = "Hook: " .. AIM_DEBUG.hook
            labels.env.Text = ("hookfunction=%s  getsenv=%s  controller=%s  bulletHit=%s  author-UI=%s"):format(
                tostring(hookfunction ~= nil), tostring(getsenv ~= nil),
                tostring(AIM_DEBUG.controller), tostring(AIM_DEBUG.bulletHit), tostring(AIM_DEBUG.uiLoaded)
            )
            labels.calls.Text = ("getTarget: calls=%d  with target=%d"):format(AIM_DEBUG.calls, AIM_DEBUG.hits)
            labels.last.Text = "Last target: " .. AIM_DEBUG.lastTarget
            local parts = {}
            for reason, count in pairs(AIM_DEBUG.reasons) do
                table.insert(parts, ("%s=%d"):format(reason, count))
            end
            labels.reasons.Text = "Reasons: " .. (#parts > 0 and table.concat(parts, "  ") or "-")
            local lines = {}
            for _, p in next, Players:GetPlayers() do
                if p ~= plr then
                    local sample = ""
                    local pchar = p.Character
                    if pchar then
                        local texts = characterLabels(p, pchar)
                        if #texts > 0 then sample = " role=\"" .. string.sub(texts[1], 1, 24) .. "\"" end
                    end
                    table.insert(lines, ("%s [%s] same=%s ignored=%s%s"):format(p.Name, p.Team and p.Team.Name or "NONE", tostring(isSameTeam(p, false)), tostring(isIgnoredRole(p, pchar)), sample))
                end
            end
            labels.players.Text = "Players:\n" .. table.concat(lines, "\n")
        end
    end
end

local frameCounter = 0
local lastRenderError = 0
keepConnection(RunService.RenderStepped:Connect(function()
    if State.unloaded then return end

    local ok, err = pcall(function()
        updateAimVisuals()
        updateESP()
    end)
    if not ok then
        -- throttle: a per-frame error would otherwise flood the console
        if os.clock() - lastRenderError > 2 then
            lastRenderError = os.clock()
            warn("[menu] render error: " .. tostring(err))
        end
    end

    frameCounter += 1
    if frameCounter % 20 == 0 then
        pcall(function()
            window:SetStatus(("%s  |  %s  |  %d players  |  %.0fs"):format(BUILD, executor, #Players:GetPlayers(), os.clock() - startedAt))
            updateDebugTab()
        end)
    end

    if Config.Player.Noclip then
        pcall(noclipApply)
    end
end))

local lastKeyPress = {}

keepConnection(UIS.InputBegan:Connect(function(input, processed)
    if processed then return end

    -- keybind capture
    if UI.promptBind then
        local bind = UI.promptBind
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Config.Keybinds[bind.keybind] = input.KeyCode
            UI.promptBind = nil
            if bind.refresh then bind.refresh() end
            toast("Key set: " .. input.KeyCode.Name, Theme.accent)
        else
            UI.promptBind = nil
            if bind.refresh then bind.refresh() end
        end
        return
    end

    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local key = input.KeyCode

    -- Hold-to-aim has to keep working while the key stays down. It is
    -- idempotent, so repeated events do not matter.
    if key == Config.Keybinds.AimToggle and Config.Aim.HoldToAim then
        State.aimKeyDown = true
        if not State.hookInstalled then pcall(installHook) end
        return
    end

    -- Repeat guard: ignore the same key firing again within 250 ms (OS key
    -- repeat). Timestamp based on purpose, so a key can never get stuck
    -- "down" if an InputEnded event is ever missed (alt-tab while holding).
    local now = os.clock()
    if lastKeyPress[key] and now - lastKeyPress[key] < 0.25 then return end
    lastKeyPress[key] = now

    if key == Config.Keybinds.MenuToggle then
        Config.Menu.Visible = not UI.gui.Enabled
        UI.gui.Enabled = Config.Menu.Visible
        UI:RefreshAll()

    elseif key == Config.Keybinds.AimToggle then
        local value = not Config.Aim.Enabled
        setPath("Aim.Enabled", value)
        UI:RefreshAll()
        onAimEnabledChanged(value)
        toast("Silent Aim " .. (value and "ON" or "OFF"), value and Theme.success or Theme.dim)

    elseif key == Config.Keybinds.ESPToggle then
        local value = not Config.ESP.Enabled
        setPath("ESP.Enabled", value)
        UI:RefreshAll()
        toast("ESP " .. (value and "ON" or "OFF"), value and Theme.success or Theme.dim)

    elseif key == Config.Keybinds.Noclip then
        local value = not Config.Player.Noclip
        setPath("Player.Noclip", value)
        UI:RefreshAll()
        pcall(setNoclip, value)

    elseif key == Config.Keybinds.Fullbright then
        local value = not Config.Player.Fullbright
        setPath("Player.Fullbright", value)
        UI:RefreshAll()
        pcall(setFullbright, value)
    end
end))

keepConnection(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.Keybinds.AimToggle then
        State.aimKeyDown = false
    end
end))

keepConnection(Players.PlayerRemoving:Connect(function(p)
    destroyESPObjects(p)
end))

keepConnection(plr.CharacterAdded:Connect(function()
    Noclip.saved = nil
    if Config.Player.Noclip then
        task.wait(1)
        pcall(noclipApply)
    end
    if Config.Player.Fullbright then
        pcall(setFullbright, true)
    end
end))

--=====================================================================
-- [13] START / UNLOAD
--=====================================================================
do
    syncAimGlobals()
    window:SetScale(Config.Menu.Scale)
    UI.gui.Enabled = Config.Menu.Visible

    if Config.Player.Noclip then pcall(setNoclip, true) end
    if Config.Player.Fullbright then pcall(setFullbright, true) end

    -- the hook was already installed in [11]; this is just a safety net
    if Config.Aim.Enabled and not State.hookInstalled then
        local ok, reason = pcall(installHook)
        if not ok then
            AIM_DEBUG.hook = "Error: " .. tostring(reason)
        end
    end

    UI:RefreshAll()

    _G.__scpUnload = function()
        State.unloaded = true
        for _, conn in ipairs(State.connections) do
            pcall(function() conn:Disconnect() end)
        end
        clearESP()
        pcall(setNoclip, false)
        pcall(setFullbright, false)
        if State.hookInstalled and State.bulletHit and restorefunction then
            pcall(restorefunction, State.bulletHit)
        end
        if UI.gui then UI.gui:Destroy() end
        if State.visualsGui then State.visualsGui:Destroy() end
        _G.__scpUnload = nil
        warn("[menu] unloaded")
    end

    toast("Silent Aim " .. (Config.Aim.Enabled and "ON" or "OFF") .. "  |  Hook: " .. AIM_DEBUG.hook,
        AIM_DEBUG.hook == "installed on Controller.BulletHit" and Theme.success or Theme.danger)
    toast("Keys: K menu, RightShift aim, V ESP, N noclip, B fullbright", Theme.accent)

    print(("[menu] %s loaded | executor=%s | aim-build=%s | hook=%s")
        :format(BUILD, executor, AIM_DEBUG.mode, AIM_DEBUG.hook))
end
