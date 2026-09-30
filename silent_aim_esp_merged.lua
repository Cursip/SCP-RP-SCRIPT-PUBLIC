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

  Credits - the merged-in parts are not ours:
    silent aim (BulletHit hook, target finder, aim UI): sneakygoober, "Silent Aim Keyless"
    player ESP (highlight, team colours):              goatd, "simple esp (team color)"
    sneekysscripts.uk only hosts/mirrors those files, it is not their author.
    Menu, options, player list, utility, movement, staff detector, camera assist
    and the config/preset system are from this repository.

  License
    Our own parts are MIT (see LICENSE). The merged-in parts are not covered by
    that license and stay with their authors (see THIRD-PARTY-NOTICES.md).
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
local TeleportService = cloneref(game:GetService("TeleportService"))
local ContextActionService = cloneref(game:GetService("ContextActionService"))

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
local BUILD = "v3.9 (2026-09-30)"

--=====================================================================
-- [3] NOTIFICATIONS
--=====================================================================
local notifyHolder
local SuppressToasts = false   -- set while a config/preset is being applied

local function toast(text: string, color: Color3?)
    local accentColor = color or Color3.fromRGB(88, 166, 255)
    print("[menu] " .. text)
    if SuppressToasts then return end
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
    keyActions = {},    -- [keybind name] = { text, fire } for the generic dispatch
    attachKeybind = nil -- hook filled in [11] (needs Config)
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
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "  " .. spec.text,
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
        -- actions get a key slot too (filled in [11], which needs Config)
        if UI.attachKeybind then
            UI.attachKeybind(b, spec)
        end
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

-- 2D box of a character, built from two projected points: the top of the head
-- and the feet. GetBoundingBox() was used before, but it includes tools and
-- accessories, which produced broken (huge or offset) boxes for some players.
local function projectPoint(world: Vector3): Vector2?
    -- only Z decides whether the point is usable: a point that is merely
    -- off-screen still projects to sane coordinates (the box is capped below)
    local sp = currentCam():WorldToViewportPoint(world)
    if sp.Z > 1 then
        return Vector2.new(sp.X, sp.Y)
    end
    return nil
end

local function projectBox(model: Model)
    local head = model:FindFirstChild("Head")
    local hrp = model:FindFirstChild("HumanoidRootPart")
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not (head and hrp and hum) then return nil end

    -- R15 reports HipHeight; R6 usually reports 0, then a fixed guess is fine
    local hipHeight = hum.HipHeight > 0 and hum.HipHeight or 2.5
    local topPoint = projectPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5, 0))
    local bottomPoint = projectPoint(hrp.Position - Vector3.new(0, hrp.Size.Y * 0.5 + hipHeight, 0))
    if not (topPoint and bottomPoint) then return nil end

    local viewW, viewH = currentCam().ViewportSize.X, currentCam().ViewportSize.Y
    -- cap the size: a player standing right at the camera would otherwise draw
    -- a box and healthbar larger than the screen
    local height = math.min(math.abs(bottomPoint.Y - topPoint.Y), viewH * 0.75)
    if height < 6 then return nil end

    local width = math.clamp(height * 0.55, 4, viewW * 0.5)
    local centreX = (topPoint.X + bottomPoint.X) * 0.5
    local minY = math.min(topPoint.Y, bottomPoint.Y)
    return centreX - width * 0.5, minY, centreX + width * 0.5, minY + height
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
    noclipLabel = nil,
    noclipSince = nil,
    visualsGui = nil,
    connections = {},
    unloaded = false,
}

local function keepConnection(conn)
    table.insert(State.connections, conn)
    return conn
end

-- forward declarations: filled in later sections, referenced by earlier ones
local isStaffMember      -- section [10d]
local setRemoveFog       -- section [10e]
local flyStep            -- section [10e], called from the bound render step
local zoomGuardStep      -- section [12], called from the bound render step

--=====================================================================
-- [7] CONFIG
--=====================================================================
local Config = {
    Menu = {
        Visible = true,
        Scale = 1,
        BlockCameraZoom = true,
    },
    Aim = {
        Enabled = true,
        Mode = "Silent (BulletHit)",
        Smoothness = 0.25,
        AutoFire = false,
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
        Prediction = 0.15,
        Hitbox = false,
        HitboxSize = 6,
        HitboxTransparency = 1,
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
        ShowRole = true,
        Distance = true,
        DistanceColor = Color3.fromRGB(200, 205, 215),
        DistanceSize = 12,
        HealthBar = true,
        HealthBarWidth = 3,
        ShowHealth = true,
        ShowWeapon = false,
    },
    Player = {
        Noclip = false,
        NoclipHold = true,
        NoclipMaxSeconds = 15,
        Fullbright = false,
    },
    Movement = {
        AntiRagdoll = false,
        InfiniteJump = false,
        Bunnyhop = false,
        JumpPower = 0,
        WalkSpeed = 0,
        Fly = false,
        FlySpeed = 60,
    },
    Misc = {
        RemoveFog = false,
        Watermark = true,
    },
    Utility = {
        AntiAFK = false,
        FpsBoost = false,
        CameraFOV = 0,
    },
    List = {
        Enabled = false,
        ShowRole = true,
        DimIgnored = true,
    },
    Profile = {
        Slot = "Slot 1",
        AutoLoad = false,
    },
    -- Staff detection. Group 5479038 is "SCP | Roleplay Community" (the official
    -- game group, verified via the Roblox API). Its roles: 1 = Member/Roleplayer
    -- (normal players), 247 = Hydray (custom role), 248 = Trial Moderator,
    -- 249 = Game Moderator, 250 = Senior Moderator, 251 = Head Moderator,
    -- 252 = Developer, 253 = Project Manager, 254 = Coordinator,
    -- 255 = Administrator. So staff starts at 248.
    Staff = {
        Enabled = true,
        GroupId = 5479038,
        MinRank = 248,
        -- the group check is exact, the label scan is a guess: it stays off
        -- until you turn it on, and it only matches whole words
        UseLabelScan = false,
        Keywords = { "moderator", "admin", "staff", "owner", "developer" },
        KnownNames = {},
        IgnoreNames = {},
        Notify = true,
        Panic = false,
        LeaveOnStaff = false,
    },
    Keybinds = {
        MenuToggle = Enum.KeyCode.K,
        AimToggle = Enum.KeyCode.RightShift,
        ESPToggle = Enum.KeyCode.V,
        Noclip = Enum.KeyCode.N,
        Fullbright = Enum.KeyCode.B,
        Unload = Enum.KeyCode.Delete,
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

-- filled in section [10b]; loadConfig applies it after merging a file
local applyAllFeatures

local function saveConfig(file: string?)
    file = file or CONFIG_FILE
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
    local wrote = pcall(writefile, file, encoded)
    if wrote then
        toast("Config saved: " .. file, Theme.success)
    else
        toast("Write failed", Theme.danger)
    end
end

local function loadConfig(silent: boolean?, file: string?)
    file = file or CONFIG_FILE
    if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
        if not silent then toast("Executor has no file API (readfile)", Theme.danger) end
        return false
    end
    local checked, exists = pcall(isfile, file)
    if not checked or not exists then
        if not silent then toast("No config found: " .. file, Theme.danger) end
        return false
    end
    local ok, content = pcall(readfile, file)
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
    if applyAllFeatures then applyAllFeatures(true) end
    if not silent then toast("Config loaded: " .. file, Theme.success) end
    return true
end

-- Presets are just extra config files (scp_aim_esp_slot1.json, ...). The
-- working config remembers which slot to load automatically at start.
local function profileFile(): string
    local slot = tostring((Config.Profile and Config.Profile.Slot) or "Slot 1")
    local slug = string.gsub(slot, "%s+", "")
    return "scp_aim_esp_" .. string.lower(slug) .. ".json"
end

local function saveProfile()
    saveConfig(profileFile())
end

local function loadProfile(silent: boolean?)
    return loadConfig(silent, profileFile())
end

-- The FOV circle and the target selection are always measured from the middle
-- of the screen, where the crosshair is. Measuring from the mouse made the
-- circle follow the free cursor in third person and jump to the middle in first
-- person, where the cursor is locked - so it is fixed to the centre now.
local function aimOrigin(): Vector2
    local cam = currentCam()
    return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
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

-- Best guess at the role text the game shows above the head (used by the ESP
-- name tag and the player list). Pure numbers (health) are skipped.
local function roleText(player: Player, char: Model?): string?
    if not char then return nil end
    for _, text in ipairs(characterLabels(player, char)) do
        if #text >= 2 and #text <= 40 and not string.match(text, "^%d+$") and not string.match(text, "^%d+%s*HP$") then
            return text
        end
    end
    return nil
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

-- Researchers are a role, not always a team, so the team name, the role
-- attributes and the label the game shows as the role are checked.
-- Which source matched, or nil. Kept separate from isIgnoredRole so the Debug
-- tab can say why someone was skipped instead of leaving it a guess.
local function ignoredReason(player: Player, char: Model?): string?
    if not Config.Aim.IgnoreRoles then return nil end
    if matchesRoleList(player.Team and player.Team.Name) then
        return "team " .. tostring(player.Team and player.Team.Name)
    end
    for _, attribute in ipairs({ "Role", "RoleName", "Team", "Class", "Job" }) do
        local value = player:GetAttribute(attribute)
        if type(value) == "string" and matchesRoleList(value) then
            return ("attr %s=\"%s\""):format(attribute, value)
        end
    end
    if char then
        -- only the label the game shows as the role, not every TextLabel in the
        -- character (items and tags in there caused wrong skips)
        local role = roleText(player, char)
        if matchesRoleList(role) then
            return ("role \"%s\""):format(tostring(role))
        end
    end
    return nil
end

-- true = never aim at this player
local function isIgnoredRole(player: Player, char: Model?): boolean
    return ignoredReason(player, char) ~= nil
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
                                local px = (Vector2.new(pos.X, pos.Y) - aimOrigin()).Magnitude
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

    if Config.Aim.Mode ~= "Silent (BulletHit)" then
        AIM_DEBUG.mode = "camera assist"
        AIM_DEBUG.hook = "not needed (camera assist)"
        return true, AIM_DEBUG.hook
    end

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
                -- No prediction here on purpose: the game decides the hit from
                -- the Instance field we send, so the shot lands on the selected
                -- part no matter what. Position is only the impact point, and
                -- leading it would just move that point off the target.
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
        Size = UDim2.new(0, 240, 0, 18),
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
                -- a box smaller than this means the player is far away; the
                -- labels would only pile up at the horizon
                if minX and (maxY - minY) >= 16 then
                    local w, h = maxX - minX, maxY - minY

                    objects.box.Visible = cfg.Box
                    objects.box.Position = UDim2.fromOffset(math.floor(minX), math.floor(minY))
                    objects.box.Size = UDim2.fromOffset(math.max(1, math.floor(w)), math.max(1, math.floor(h)))
                    objects.boxStroke.Color = color
                    objects.boxStroke.Thickness = cfg.BoxThickness
                    objects.boxStroke.Transparency = cfg.BoxTransparency

                    local role = cfg.ShowRole and roleText(p, char) or nil
                    local staff = isStaffMember and isStaffMember(p) or false
                    local nameHeight = role and 32 or 16
                    local display = (staff and "[STAFF] " or "") .. p.Name
                    objects.name.Visible = cfg.Name
                    objects.name.Size = UDim2.fromOffset(240, nameHeight)
                    objects.name.Position = UDim2.fromOffset(math.floor(minX + w / 2 - 120), math.floor(minY - nameHeight))
                    objects.name.Text = role and (display .. "\n" .. role) or display
                    objects.name.TextColor3 = staff and Theme.danger or cfg.NameColor
                    objects.name.TextSize = cfg.NameSize

                    local hpText = ""
                    if cfg.ShowHealth and hum and hum.MaxHealth > 0 then
                        hpText = ("  |  %d HP"):format(math.floor(hum.Health))
                    end
                    local weaponText = ""
                    if cfg.ShowWeapon then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool then
                            weaponText = "  |  " .. tool.Name
                        end
                    end
                    objects.dist.Visible = cfg.Distance
                    objects.dist.Position = UDim2.fromOffset(math.floor(minX + w / 2 - 100), math.floor(maxY + 2))
                    objects.dist.Text = ("%d studs"):format(math.floor(dist)) .. hpText .. weaponText
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
-- [9b] PLAYER LIST (own window inside the visuals GUI, so K keeps it)
--=====================================================================
local List = { frame = nil, canvas = nil, title = nil, rows = {} }

local function ensurePlayerList()
    if List.frame then return end
    local parent = State.visualsGui or UI.gui
    if not parent then return end

    local frame = new("Frame", {
        Name = "PlayerList",
        Size = UDim2.fromOffset(258, 306),
        Position = UDim2.new(0, 8, 1, -314),
        BackgroundColor3 = Theme.window,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Visible = false,
    }, parent)
    corner(frame, 8)
    stroke(frame, Theme.stroke, 1, 0.2)

    local bar = new("Frame", {
        Name = "Bar",
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = Color3.fromRGB(18, 20, 25),
        BorderSizePixel = 0,
    }, frame)
    corner(bar, 8)

    List.title = new("TextLabel", {
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Players",
    }, bar)

    local canvas = new("ScrollingFrame", {
        Size = UDim2.new(1, -8, 1, -30),
        Position = UDim2.fromOffset(4, 26),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.stroke,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, frame)
    list(canvas, 2)
    List.canvas = canvas
    List.frame = frame

    local dragging, startInput, startPos = false, nil, nil
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, input.Position, frame.Position
        end
    end)
    keepConnection(UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startInput
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    keepConnection(UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function listRow(index: number)
    local row = List.rows[index]
    if row then return row end
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Theme.element,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        LayoutOrder = index,
    }, List.canvas)
    corner(frame, 5)
    row = {
        frame = frame,
        name = new("TextLabel", {
            Size = UDim2.new(1, -12, 0, 15),
            Position = UDim2.fromOffset(6, 1),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = Theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "",
        }, frame),
        info = new("TextLabel", {
            Size = UDim2.new(1, -12, 0, 13),
            Position = UDim2.fromOffset(6, 15),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = Theme.accent,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "",
        }, frame),
    }
    List.rows[index] = row
    return row
end

local function updatePlayerList()
    if not Config.List.Enabled then
        if List.frame then List.frame.Visible = false end
        return
    end
    ensurePlayerList()
    if not List.frame then return end
    List.frame.Visible = true

    local cam = currentCam()
    local entries = {}
    for _, p in next, Players:GetPlayers() do
        if p ~= plr then
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            table.insert(entries, {
                player = p,
                hp = hum and math.floor(hum.Health) or nil,
                dist = hrp and (cam.CFrame.Position - hrp.Position).Magnitude or nil,
                role = char and roleText(p, char) or nil,
                ignored = isIgnoredRole(p, char),
                staff = isStaffMember and isStaffMember(p) or false,
            })
        end
    end
    table.sort(entries, function(a, b)
        return (a.dist or math.huge) < (b.dist or math.huge)
    end)

    List.title.Text = ("Players - %d"):format(#entries)
    for index, entry in ipairs(entries) do
        local row = listRow(index)
        row.frame.Visible = true
        local p = entry.player
        local dimmed = Config.List.DimIgnored and entry.ignored
        row.name.Text = (entry.staff and "[STAFF] " or "") .. p.Name
        row.name.TextColor3 = entry.staff and Theme.danger or (dimmed and Theme.dim or Theme.text)

        local parts = {}
        if Config.List.ShowRole and entry.role then table.insert(parts, entry.role) end
        table.insert(parts, p.Team and p.Team.Name or "no team")
        if entry.hp then table.insert(parts, entry.hp .. " HP") end
        if entry.dist then table.insert(parts, ("%d studs"):format(entry.dist)) end
        if entry.ignored then table.insert(parts, "ignored") end
        if entry.staff then table.insert(parts, "STAFF") end
        row.info.Text = table.concat(parts, "  |  ")
        row.info.TextColor3 = entry.staff and Theme.danger or (dimmed and Theme.dim or Theme.accent)
    end
    for index = #entries + 1, #List.rows do
        List.rows[index].frame.Visible = false
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

-- Noclip. Only parts that actually had collisions are touched and all of them
-- are restored on release. Holding the key is the default so it cannot be left
-- on by accident; toggle mode switches itself off after NoclipMaxSeconds, and
-- a config never turns it on by itself.
local function setNoclip(on: boolean)
    if on then
        if Config.Player.Noclip then return end
        Config.Player.Noclip = true
        State.noclipSince = os.clock()
        noclipApply()
        toast("Noclip ON - use it briefly and out of sight", Theme.danger)
    else
        if not Config.Player.Noclip and not Noclip.saved then return end
        Config.Player.Noclip = false
        State.noclipSince = nil
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
-- [10b] UTILITY (anti-AFK, FPS boost) + SERVER STATS
--=====================================================================
local Stats = { fps = 0, frames = 0, fpsAt = os.clock(), ping = nil }

local function getPing(): number?
    local ok, value = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and type(value) == "number" then
        return math.floor(value)
    end
    return nil
end

-- Anti-AFK: the handler is installed once and only checks the flag, so the
-- toggle is instant and nothing has to be re-bound.
do
    local okVu, virtualUser = pcall(function()
        return cloneref(game:GetService("VirtualUser"))
    end)
    if okVu and virtualUser then
        keepConnection(plr.Idled:Connect(function()
            if not Config.Utility.AntiAFK then return end
            pcall(function()
                virtualUser:CaptureController()
                virtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                virtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        end))
    else
        warn("[menu] VirtualUser unavailable, anti-AFK disabled")
    end
end

-- FPS boost: post effects off, optionally every particle emitter off. The scan
-- over workspace runs in chunks so it cannot freeze the game.
local Fps = { effects = nil, emitters = nil, scanning = false, shadows = nil }

local function boostScanEmitters()
    if Fps.scanning or not Config.Utility.FpsBoost then return end
    Fps.scanning = true
    task.spawn(function()
        Fps.emitters = Fps.emitters or {}
        local seen = 0
        for _, inst in ipairs(workspace:GetDescendants()) do
            if not Config.Utility.FpsBoost then break end
            seen += 1
            if inst:IsA("ParticleEmitter") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") or inst:IsA("Trail") or inst:IsA("Beam") then
                if inst.Enabled then
                    Fps.emitters[inst] = true
                    inst.Enabled = false
                end
            end
            if seen % 2000 == 0 then
                task.wait()
            end
        end
        Fps.scanning = false
    end)
end

local function setFpsBoost(on: boolean)
    if on then
        if not Fps.effects then
            Fps.effects = {}
            for _, inst in ipairs(Lighting:GetChildren()) do
                if inst:IsA("PostEffect") then
                    Fps.effects[inst] = inst.Enabled
                    inst.Enabled = false
                end
            end
        end
        if not Config.Player.Fullbright then
            if Fps.shadows == nil then
                Fps.shadows = Lighting.GlobalShadows
            end
            Lighting.GlobalShadows = false
        end
        boostScanEmitters()
        toast("FPS boost on", Theme.success)
    else
        if Fps.effects then
            for inst, wasEnabled in pairs(Fps.effects) do
                if inst.Parent then inst.Enabled = wasEnabled end
            end
            Fps.effects = nil
        end
        if Fps.emitters then
            for inst in pairs(Fps.emitters) do
                if inst.Parent then inst.Enabled = true end
            end
            Fps.emitters = nil
        end
        if Fps.shadows ~= nil then
            if not Config.Player.Fullbright then
                Lighting.GlobalShadows = Fps.shadows
            end
            Fps.shadows = nil
        end
        toast("FPS boost off", Theme.dim)
    end
end

local statsLabels = nil

-- Applies everything that has a side effect. Used at start and after a config
-- or preset is loaded, so a loaded file takes effect immediately.
applyAllFeatures = function(quiet: boolean?)
    -- a config must never switch noclip on by itself
    local noclipWasOn = Config.Player.Noclip
    Config.Player.Noclip = false

    SuppressToasts = quiet == true
    local ok, err = pcall(function()
        syncAimGlobals()
        setFullbright(Config.Player.Fullbright)
        setFpsBoost(Config.Utility.FpsBoost)
        if Config.Misc.RemoveFog then
            setRemoveFog(true)
        else
            setRemoveFog(false)
        end
        if Config.Aim.Enabled and Config.Aim.Mode == "Silent (BulletHit)" and not State.hookInstalled then
            installHook()
        end
    end)
    SuppressToasts = false

    if noclipWasOn then
        toast("Noclip in that file stays off - hold " .. Config.Keybinds.Noclip.Name .. " to use it", Theme.danger)
    end
    if not ok then
        warn("[menu] applying settings failed: " .. tostring(err))
    end
end

local function updateStatsLabels()
    if not statsLabels then return end
    statsLabels.players.Text = ("Players: %d"):format(#Players:GetPlayers())
    statsLabels.ping.Text = ("Ping: %s ms"):format(Stats.ping and tostring(Stats.ping) or "?")
    statsLabels.fps.Text = ("FPS: %d"):format(Stats.fps)
    statsLabels.uptime.Text = ("Server uptime: %d min"):format(math.floor(workspace.DistributedGameTime / 60))
    statsLabels.job.Text = ("Job: %s"):format(game.JobId)
end

--=====================================================================
-- [10c] CAMERA ASSIST + AUTO FIRE + CAMERA FOV (works in any game)
--=====================================================================
-- Camera assist only turns your own camera, so it is not tied to SCP:RP. It is
-- bound after the game's camera scripts so our CFrame wins for that frame.
local function cameraAssistStep(dt: number)
    local cam = currentCam()
    if Config.Utility.CameraFOV > 0 then
        cam.FieldOfView = Config.Utility.CameraFOV
    end

    local cfg = Config.Aim
    if not cfg.Enabled or cfg.Mode ~= "Camera assist" then return end
    if cfg.HoldToAim and not State.aimKeyDown then return end

    local target = findTarget(cam.CFrame.Position, true)
    if not target then return end
    local aimAt = target.Position + (target.AssemblyLinearVelocity or Vector3.zero) * cfg.Prediction
    local delta = aimAt - cam.CFrame.Position
    if delta.Magnitude < 1 then return end

    local goal = CFrame.lookAt(cam.CFrame.Position, aimAt)
    local alpha = 1 - (1 - math.clamp(cfg.Smoothness, 0.02, 1)) ^ (dt * 60)
    cam.CFrame = cam.CFrame:Lerp(goal, alpha)
end

local function autoFireStep()
    local cfg = Config.Aim
    if not (cfg.Enabled and cfg.AutoFire) then return end
    if cfg.HoldToAim and not State.aimKeyDown then return end
    if typeof(mouse1click) ~= "function" then return end

    local cam = currentCam()
    local target = findTarget(cam.CFrame.Position, true)
    if not target then return end
    local pos, onScreen = cam:WorldToViewportPoint(target.Position)
    if not onScreen then return end
    local centre = aimOrigin()
    if (Vector2.new(pos.X, pos.Y) - centre).Magnitude > 12 then return end
    pcall(mouse1click)
end

pcall(function()
    RunService:UnbindFromRenderStep("ScpAimStep")
end)
pcall(function()
    RunService:BindToRenderStep("ScpAimStep", Enum.RenderPriority.Camera.Value + 1, function(dt)
        cameraAssistStep(dt)
        autoFireStep()
        if flyStep then flyStep() end
        if zoomGuardStep then zoomGuardStep() end
    end)
end)

-- Switching backends: the SCP-RP hook is restored when camera assist takes
-- over and installed again when silent aim comes back.
local function onAimModeChanged(value: string)
    if value == "Camera assist" then
        if State.hookInstalled and State.bulletHit and restorefunction then
            pcall(restorefunction, State.bulletHit)
        end
        State.hookInstalled = false
        AIM_DEBUG.hook = "restored (camera assist active)"
        toast("Camera assist active - your camera turns to the target", Theme.accent)
    elseif Config.Aim.Enabled and not State.hookInstalled then
        local ok, reason = pcall(installHook)
        toast("Hook: " .. tostring(reason), ok and Theme.success or Theme.danger)
    end
end

local function rejoinServer()
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, plr)
    end)
    toast(ok and "Rejoining this server..." or "Rejoin failed", ok and Theme.success or Theme.danger)
end

local function serverHop()
    local ok, body = pcall(function()
        return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100")
    end)
    if not ok or type(body) ~= "string" then
        toast("Server list unavailable", Theme.danger)
        return
    end
    local ids = {}
    for id in string.gmatch(body, '"id":"(%x[%x%-]+)"') do
        if id ~= game.JobId then
            table.insert(ids, id)
        end
    end
    if #ids == 0 then
        toast("No other server found", Theme.danger)
        return
    end
    local pick = ids[math.random(1, #ids)]
    local teleported = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, pick, plr)
    end)
    toast(teleported and "Hopping to another server..." or "Hop failed", teleported and Theme.success or Theme.danger)
end

--=====================================================================
-- [10d] STAFF DETECTOR + PANIC MODE + HITBOX EXPANDER
--=====================================================================
local StaffState = { present = false, names = {}, result = {} }

-- Whole-word match only: with a plain substring search "admin" also matched
-- "Administration" and flagged normal players. Off by default for that reason.
local function labelKeyword(player: Player): string?
    if not Config.Staff.UseLabelScan then return nil end
    local char = player.Character
    if not char then return nil end
    for _, text in ipairs(characterLabels(player, char)) do
        local lower = string.lower(text)
        for _, word in ipairs(Config.Staff.Keywords) do
            if type(word) == "string" and #word > 0 then
                local plain = string.lower(word)
                local escaped = string.gsub(plain, "(%W)", "%%%1")
                if string.find(lower, "%f[%a]" .. escaped .. "%f[%A]") then
                    return word .. " in \"" .. text .. "\""
                end
            end
        end
    end
    return nil
end

-- Full check (may yield, so it only runs from the staff coroutine below).
-- Returns whether the player is staff and why, so a false positive can be
-- diagnosed from the toast instead of guessed at.
local function evaluateStaff(player: Player): (boolean, string?)
    for _, name in ipairs(Config.Staff.IgnoreNames) do
        if type(name) == "string" and name == player.Name then
            return false, "in IgnoreNames"
        end
    end
    for _, name in ipairs(Config.Staff.KnownNames) do
        if type(name) == "string" and name == player.Name then
            return true, "in KnownNames"
        end
    end

    local keyword = labelKeyword(player)
    if keyword then
        return true, "label " .. keyword
    end

    local ok, rank = pcall(function()
        return player:GetRankInGroup(Config.Staff.GroupId)
    end)
    if ok and type(rank) == "number" and rank >= Config.Staff.MinRank then
        return true, "group rank " .. tostring(rank)
    end
    return false, nil
end

-- Cheap, render-safe read: the cached verdict, otherwise only the label check.
isStaffMember = function(player: Player): boolean
    if not Config.Staff.Enabled then return false end
    local cached = StaffState.result[player]
    if cached ~= nil then return cached end
    return labelKeyword(player) ~= nil
end

local function refreshStaff()
    if not Config.Staff.Enabled then
        StaffState.present = false
        StaffState.names = {}
        table.clear(StaffState.result)
        return
    end

    local names, reasons = {}, {}
    for _, p in next, Players:GetPlayers() do
        if p ~= plr then
            local staff, reason = evaluateStaff(p)
            StaffState.result[p] = staff
            if staff then
                table.insert(names, p.Name)
                reasons[p.Name] = reason
            end
        end
    end

    local wasPresent = StaffState.present
    StaffState.present = #names > 0
    StaffState.names = names

    if StaffState.present and not wasPresent then
        if Config.Staff.Notify then
            local parts = {}
            for _, n in ipairs(names) do
                parts[#parts + 1] = n .. " (" .. tostring(reasons[n] or "?") .. ")"
            end
            toast("STAFF in server: " .. table.concat(parts, ", "), Theme.danger)
        end
        if Config.Staff.LeaveOnStaff then
            toast("Anti-moderator: unloading and leaving the server", Theme.danger)
            if _G.__scpUnload then _G.__scpUnload() end
            pcall(function()
                TeleportService:Teleport(game.PlaceId)
            end)
            return
        end
    end

    -- Panic mode: switch the risky features off while staff is around
    if Config.Staff.Panic then
        if StaffState.present then
            if Config.Aim.Enabled or Config.Player.Noclip or Config.ESP.Enabled then
                setPath("Aim.Enabled", false)
                setPath("ESP.Enabled", false)
                syncAimGlobals()
                pcall(setNoclip, false)
                UI:RefreshAll()
                toast("Panic mode: staff present, aim/ESP/noclip switched off", Theme.danger)
            end
        elseif wasPresent and Config.Staff.Notify then
            toast("Staff left - features stay off until you enable them again", Theme.accent)
        end
    end
end

-- own coroutine: GetRankInGroup can yield and must not run in the render path
task.spawn(function()
    while not State.unloaded do
        pcall(refreshStaff)
        task.wait(2)
    end
end)

-- Hitbox expander: enlarges the head of other players locally (useful in games
-- that hit-test on the client).
local Hitbox = { original = setmetatable({}, { __mode = "k" }) }

local function updateHitbox()
    local cfg = Config.Aim
    if not cfg.Hitbox then
        for part, saved in pairs(Hitbox.original) do
            if typeof(part) == "Instance" and part.Parent then
                part.Size = saved.size
                part.Transparency = saved.transparency
            end
        end
        table.clear(Hitbox.original)
        return
    end

    for _, p in next, Players:GetPlayers() do
        if p ~= plr and not isSameTeam(p, true) then
            local char = p.Character
            local head = char and char:FindFirstChild("Head")
            if head and head:IsA("BasePart") then
                if not Hitbox.original[head] then
                    Hitbox.original[head] = { size = head.Size, transparency = head.Transparency }
                end
                head.Size = Vector3.new(cfg.HitboxSize, cfg.HitboxSize, cfg.HitboxSize)
                head.Transparency = cfg.HitboxTransparency
            end
        end
    end
end

--=====================================================================
-- [10e] MOVEMENT (off by default, these are the most checked features)
--=====================================================================
local function applyMovement()
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if Config.Movement.WalkSpeed > 0 then
        hum.WalkSpeed = Config.Movement.WalkSpeed
    end
    if Config.Movement.JumpPower > 0 then
        hum.UseJumpPower = true
        hum.JumpPower = Config.Movement.JumpPower
    end
end

flyStep = function()
    if not Config.Movement.Fly then return end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cam = currentCam()
    local move = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then move += cam.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then move -= cam.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then move += cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then move -= cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0, 1, 0) end

    if move.Magnitude > 0 then
        move = move.Unit
    end
    hrp.Velocity = move * Config.Movement.FlySpeed
end

-- per character, because anti-ragdoll and bunnyhop have to follow respawns
local function bindCharacter(char: Model)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    keepConnection(hum.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Ragdoll or newState == Enum.HumanoidStateType.FallingDown then
            if Config.Movement.AntiRagdoll then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end
        elseif newState == Enum.HumanoidStateType.Landed and Config.Movement.Bunnyhop then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end))
end

-- infinite jump: answer every jump request, also in mid air
keepConnection(UIS.JumpRequest:Connect(function()
    if not Config.Movement.InfiniteJump then return end
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
end))

local Fog = { saved = nil }

setRemoveFog = function(on: boolean)
    if on then
        if not Fog.saved then
            Fog.saved = { fogEnd = Lighting.FogEnd, fogStart = Lighting.FogStart, atmosphere = {} }
            for _, inst in ipairs(Lighting:GetChildren()) do
                if inst:IsA("Atmosphere") then
                    Fog.saved.atmosphere[inst] = { density = inst.Density, haze = inst.Haze }
                end
            end
        end
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
        for inst in pairs(Fog.saved.atmosphere) do
            if inst.Parent then
                inst.Density = 0
                inst.Haze = 0
            end
        end
        toast("Fog removed", Theme.success)
    elseif Fog.saved then
        Lighting.FogEnd = Fog.saved.fogEnd
        Lighting.FogStart = Fog.saved.fogStart
        for inst, values in pairs(Fog.saved.atmosphere) do
            if inst.Parent then
                inst.Density = values.density
                inst.Haze = values.haze
            end
        end
        Fog.saved = nil
        toast("Fog restored", Theme.dim)
    end
end

if plr.Character then
    task.spawn(function()
        if plr.Character:WaitForChild("Humanoid", 5) then
            bindCharacter(plr.Character)
        end
    end)
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
if Config.Profile.AutoLoad then
    pcall(function()
        loadProfile(true)
    end)
end
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

-- ------------------------------------------------------- keybinds
-- Every toggle and every button gets a key slot. Nothing is bound in advance:
-- the badge shows "-" until you click it and press a key. Backspace clears a
-- binding again.
local function keyNameFor(path: string?): string
    return "Toggle_" .. string.gsub(path or "unknown", "[^%w]", "_")
end

UI.attachKeybind = function(button: TextButton, spec)
    local name = spec.keybind or ("Btn_" .. string.gsub(spec.text or "action", "[^%w]", ""))
    local badge = new("TextButton", {
        Size = UDim2.fromOffset(52, 20),
        Position = UDim2.new(1, -60, 0.5, -10),
        BackgroundColor3 = Theme.window,
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = Theme.dim,
        Text = "-",
        AutoButtonColor = false,
        ZIndex = 3,
    }, button)
    corner(badge, 5)
    stroke(badge, Theme.stroke, 1, 0.4)

    local function refreshKey()
        local key = Config.Keybinds[name]
        badge.Text = key and key.Name or "-"
    end

    badge.MouseButton1Click:Connect(function()
        UI.promptBind = { keybind = name, refresh = refreshKey }
        badge.Text = "..."
    end)

    table.insert(UI.refreshers, refreshKey)
    refreshKey()

    UI.keyActions[name] = {
        text = spec.text,
        fire = function()
            local ok, err = pcall(spec.callback)
            if not ok then toast("Error: " .. tostring(err), Theme.danger) end
        end,
    }
end

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

    -- every toggle gets a key slot: unbound ("-") until you set one
    local keyName = spec.keybind or keyNameFor(spec.path)
    local keyBtn = new("TextButton", {
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
        local key = Config.Keybinds[keyName]
        keyBtn.Text = key and key.Name or "-"
    end

    keyBtn.MouseButton1Click:Connect(function()
        UI.promptBind = { keybind = keyName, refresh = refreshKey }
        keyBtn.Text = "..."
    end)

    UI.keyActions[keyName] = {
        text = spec.text,
        fire = function() apply(not getPath(spec.path), true) end,
    }

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
        s:Dropdown({ text = "Aim mode", path = "Aim.Mode", options = { "Silent (BulletHit)", "Camera assist" }, onChanged = onAimModeChanged })
        s:Slider({ text = "Camera assist smoothness", path = "Aim.Smoothness", min = 0.05, max = 1, step = 0.05, decimals = 2 })
        s:Slider({ text = "Prediction (camera assist only)", path = "Aim.Prediction", min = 0, max = 0.5, step = 0.05, decimals = 2 })
        s:Label("Only used by camera assist, to lead a moving target. Silent aim always hits the part it picks - the game takes the hit from the Instance field, so the impact position cannot change the outcome.")
        s:Toggle({ text = "Hitbox expander", path = "Aim.Hitbox" })
        s:Slider({ text = "Hitbox size", path = "Aim.HitboxSize", min = 2, max = 20, step = 1 })
        s:Slider({ text = "Hitbox transparency", path = "Aim.HitboxTransparency", min = 0, max = 1, step = 0.1, decimals = 1 })
        s:Toggle({ text = "Auto fire when on target (risky)", path = "Aim.AutoFire" })
        s:Label("Silent = SCP:RP only (hooks Controller.BulletHit). Camera assist = works in any game, it turns your own camera.")

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
        b:Toggle({ text = "Show role in name tag", path = "ESP.ShowRole" })
        b:Toggle({ text = "Distance", path = "ESP.Distance" })
        b:Color({ text = "Distance color", path = "ESP.DistanceColor" })
        b:Slider({ text = "Distance size", path = "ESP.DistanceSize", min = 8, max = 22, step = 1 })
        b:Toggle({ text = "Healthbar", path = "ESP.HealthBar" })
        b:Slider({ text = "Healthbar width", path = "ESP.HealthBarWidth", min = 1, max = 8, step = 1, suffix = " px" })
        b:Toggle({ text = "Show HP number", path = "ESP.ShowHealth" })
        b:Toggle({ text = "Show weapon name", path = "ESP.ShowWeapon" })

        local plist = espTab:Section("Player list")
        plist:Toggle({ text = "Player list window", path = "List.Enabled" })
        plist:Toggle({ text = "Show role", path = "List.ShowRole" })
        plist:Toggle({ text = "Dim ignored players", path = "List.DimIgnored" })
        plist:Label("Bottom left by default, drag it by its title bar. Stays visible while the menu is hidden.")
    end

    local playerTab = window:Tab("Player")
    do
        local s = playerTab:Section("Movement")
        s:Toggle({
            text = "Noclip (key: " .. Config.Keybinds.Noclip.Name .. ")", path = "Player.Noclip", keybind = "Noclip",
            onChanged = function(value) setNoclip(value) end,
        })
        s:Toggle({ text = "Hold key for noclip (safer)", path = "Player.NoclipHold" })
        s:Slider({ text = "Noclip auto-off in toggle mode", path = "Player.NoclipMaxSeconds", min = 5, max = 120, step = 5, suffix = " s" })
        s:Button({ text = "Force noclip off", color = Theme.danger, callback = function() setNoclip(false) end })
        s:Label("Noclip is never switched on by a config or preset. The indicator shows while it is active.")
        s:Label("Template: add new features as a section + toggle (see the header comment).")

        local w = playerTab:Section("World")
        w:Toggle({
            text = "Fullbright", path = "Player.Fullbright", keybind = "Fullbright",
            onChanged = function(value) setFullbright(value) end,
        })

        local ut = playerTab:Section("Utility")
        ut:Toggle({ text = "Anti-AFK", path = "Utility.AntiAFK" })
        ut:Toggle({ text = "FPS boost (effects + particles)", path = "Utility.FpsBoost", onChanged = setFpsBoost })
        ut:Label("FPS boost turns post effects and particle emitters off; all of it is restored when disabled.")
        ut:Slider({ text = "Camera FOV (0 = game default)", path = "Utility.CameraFOV", min = 0, max = 120, step = 5 })
        ut:Toggle({ text = "Remove fog and atmosphere", path = "Misc.RemoveFog", onChanged = setRemoveFog })
        ut:Button({ text = "Rejoin this server", callback = rejoinServer })
        ut:Button({ text = "Server hop (different server)", callback = serverHop })

        local mv = playerTab:Section("Movement (risky)")
        mv:Toggle({ text = "Anti-ragdoll", path = "Movement.AntiRagdoll" })
        mv:Toggle({ text = "Infinite jump", path = "Movement.InfiniteJump" })
        mv:Toggle({ text = "Bunnyhop (auto jump on landing)", path = "Movement.Bunnyhop" })
        mv:Slider({ text = "Jump height (0 = game default)", path = "Movement.JumpPower", min = 0, max = 300, step = 5 })
        mv:Slider({ text = "Walkspeed (0 = game default)", path = "Movement.WalkSpeed", min = 0, max = 200, step = 5 })
        mv:Toggle({ text = "Fly (WASD, Space up, Ctrl down)", path = "Movement.Fly" })
        mv:Slider({ text = "Fly speed", path = "Movement.FlySpeed", min = 10, max = 300, step = 10 })
        mv:Label("These are the features this game checks most (walk speed, flight). Everything here is off by default.")
    end

    local safetyTab = window:Tab("Safety")
    do
        local s = safetyTab:Section("Staff detector")
        s:Toggle({ text = "Staff detector", path = "Staff.Enabled" })
        s:Toggle({ text = "Notify when staff is in the server", path = "Staff.Notify" })
        s:Toggle({ text = "Panic mode: switch aim/ESP/noclip off while staff is present", path = "Staff.Panic" })
        s:Toggle({ text = "Anti-moderator: unload and leave when staff joins", path = "Staff.LeaveOnStaff" })
        s:Slider({ text = "Minimum staff rank", path = "Staff.MinRank", min = 0, max = 255, step = 1 })
        s:Toggle({ text = "Also scan role labels for staff words (guesswork)", path = "Staff.UseLabelScan" })
        s:Label("Group: SCP | Roleplay Community (" .. tostring(Config.Staff.GroupId) .. "). Staff ranks there start at 248 (Trial Moderator); Game/Senior/Head Moderator are 249-251, Developer to Administrator 252-255. Normal members are rank 1, so they are never flagged.")
        s:Label("Only whole words count in the label scan - \"Administration\" no longer matches \"admin\". The message says why someone was flagged, so a wrong hit is visible. Config.Staff.KnownNames counts as staff, Config.Staff.IgnoreNames never does.")
        s:Label("Keywords for the label scan: " .. table.concat(Config.Staff.Keywords, ", "))
        s:Label("Detected staff is marked [STAFF] in red in the ESP and in the player list, so you can see who is watching.")
    end

    local settingsTab = window:Tab("Settings")
    do
        local m = settingsTab:Section("Menu")
        m:Toggle({ text = "Menu visible", path = "Menu.Visible", keybind = "MenuToggle", onChanged = function(value)
            UI.gui.Enabled = value
        end })
        m:Slider({ text = "UI scale", path = "Menu.Scale", min = 0.7, max = 1.4, step = 0.05, decimals = 2,
            onChanged = function(value) window:SetScale(value) end })
        m:Toggle({ text = "Watermark HUD", path = "Misc.Watermark" })
        m:Toggle({ text = "Wheel while the menu is open does not zoom the camera", path = "Menu.BlockCameraZoom" })
        m:Label("While the menu is open the wheel scrolls the menu and the character stays put. The binding only exists while the menu is open, so zoom behaves exactly as before once it is closed.")

        local pr = settingsTab:Section("Presets")
        pr:Dropdown({ text = "Slot", path = "Profile.Slot", options = { "Slot 1", "Slot 2", "Slot 3" } })
        pr:Toggle({ text = "Auto-load this slot at start", path = "Profile.AutoLoad" })
        pr:Button({ text = "Save current settings to slot", callback = saveProfile })
        pr:Button({ text = "Load slot", callback = function() loadProfile(false) end })
        pr:Label("Presets are extra config files (scp_aim_esp_slot1.json ...). The working config below is loaded at start and remembers which slot to auto-load.")

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

        local sv = settingsTab:Section("Server")
        statsLabels = {
            players = sv:Label("Players: ..."),
            ping = sv:Label("Ping: ..."),
            fps = sv:Label("FPS: ..."),
            uptime = sv:Label("Server uptime: ..."),
            job = sv:Label("Job: ..."),
        }

        local u = settingsTab:Section("Script")
        u:Label("Build: " .. AIM_DEBUG.mode)
        u:Label("Unload removes menu, FOV ring, ESP and toasts, restores the aim hook and turns noclip/fullbright off. Key: " .. Config.Keybinds.Unload.Name)
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

-- While the menu is open the wheel belongs to the menu. The action is bound
-- when the menu opens and unbound again when it closes, so with the menu closed
-- nothing of ours sits in the input path at all - that is also why the earlier
-- attempt (a permanent binding that guessed where the pointer was) could make
-- the zoom feel wrong outside. No coordinate math is involved any more.
local wheelBound = false

local function setWheelSink(on: boolean)
    if on == wheelBound then return end
    wheelBound = on
    if on then
        pcall(function()
            ContextActionService:BindActionAtPriority(
                "ScpMenuWheel",
                function(_, inputState)
                    if inputState == Enum.UserInputState.Change then
                        return Enum.ContextActionResult.Sink
                    end
                    return Enum.ContextActionResult.Pass
                end,
                false,
                math.huge,
                Enum.UserInputType.MouseWheel
            )
        end)
    else
        pcall(function()
            ContextActionService:UnbindAction("ScpMenuWheel")
        end)
    end
end

local function menuOpen(): boolean
    return UI.gui ~= nil and UI.gui.Enabled == true
end

local function updateWheelSink()
    setWheelSink(Config.Menu.BlockCameraZoom and menuOpen())
end

-- Camera.Focus is not usable here: SCP:RP's camera does not update it, so the
-- first version pinned 200 studs (distance to a stale focus) and the guard never
-- saw a change. The character's head is the reference instead.
local function camReference(): BasePart?
    local char = plr.Character
    if not char then return nil end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function camDistance(): number?
    local ref = camReference()
    if not ref then return nil end
    return (currentCam().CFrame.Position - ref.Position).Magnitude
end

-- Last resort that works no matter how the game stores its zoom: remember the
-- distance from the head, and if a wheel tick happens while the menu is open,
-- put the camera back to the distance it had before that tick. Only wheel ticks
-- are corrected, so collision and normal camera movement stay untouched.
local ZoomGuard = { distance = nil, restoreTo = nil, blocked = 0 }

local function zoomGuardArm()
    if Config.Menu.BlockCameraZoom and menuOpen() and ZoomGuard.distance then
        ZoomGuard.restoreTo = ZoomGuard.distance
    end
end

zoomGuardStep = function()
    local ref = camReference()
    if not ref then return end
    local cam = currentCam()
    local offset = cam.CFrame.Position - ref.Position
    local distance = offset.Magnitude
    if distance < 0.01 then return end

    local want = ZoomGuard.restoreTo
    ZoomGuard.restoreTo = nil
    if want and want > 0.5 and math.abs(distance - want) > 0.05 then
        local newPos = ref.Position + offset.Unit * want
        cam.CFrame = CFrame.lookAt(newPos, newPos + cam.CFrame.LookVector)
        distance = want
        ZoomGuard.blocked += 1
    end
    ZoomGuard.distance = distance
end

-- Sinking the wheel only helps in games whose camera listens to the action
-- system; SCP:RP does not. So the zoom is also pinned where it is actually
-- stored: while the menu is open, min and max zoom distance are set to the
-- distance the camera had when it opened. The camera module clamps its zoom to
-- that range every frame, so the wheel cannot move it - and camera collision
-- keeps working, because that shortens the camera without changing the zoom.
local ZoomPin = { active = false, min = nil, max = nil, distance = nil }

local function updateZoomPin()
    local want = Config.Menu.BlockCameraZoom and menuOpen()
    if not want then
        if ZoomPin.active then
            ZoomPin.active = false
            pcall(function()
                plr.CameraMinZoomDistance = ZoomPin.min
                plr.CameraMaxZoomDistance = ZoomPin.max
            end)
        end
        return
    end

    if not ZoomPin.active then
        local measured = camDistance()
        -- implausible reading (loading, teleport, stale reference): leave the
        -- properties alone instead of pinning nonsense
        if not measured or measured < 0.5 or measured > 100 then return end
        ZoomPin.min = plr.CameraMinZoomDistance
        ZoomPin.max = plr.CameraMaxZoomDistance
        ZoomPin.distance = measured
        ZoomPin.active = true
    end

    local pin = ZoomPin.distance
    if type(ZoomPin.max) == "number" then pin = math.min(pin, ZoomPin.max) end
    if type(ZoomPin.min) == "number" then pin = math.max(pin, ZoomPin.min) end

    pcall(function()
        plr.CameraMaxZoomDistance = pin
        plr.CameraMinZoomDistance = pin
    end)
end
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

    -- visible while noclip is active, so it cannot be forgotten
    State.noclipLabel = new("TextLabel", {
        Name = "NoclipIndicator",
        Size = UDim2.fromOffset(140, 18),
        Position = UDim2.new(0.5, -70, 1, -48),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.danger,
        TextStrokeTransparency = 0.3,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        Text = "NOCLIP ACTIVE",
        Visible = false,
    }, parent)

    State.watermark = new("TextLabel", {
        Name = "Watermark",
        Size = UDim2.fromOffset(360, 16),
        Position = UDim2.fromOffset(8, 4),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Theme.dim,
        TextStrokeTransparency = 0.4,
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
        local point = aimOrigin()
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
        local point = aimOrigin()
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
            local zoomNow = camDistance()
            labels.calls.Text = ("getTarget: calls=%d  with target=%d  |  menu open=%s  wheel sink=%s  zoom pin=%s  zoom now=%s  zoom blocked=%d"):format(
                AIM_DEBUG.calls, AIM_DEBUG.hits,
                tostring(menuOpen()), tostring(wheelBound),
                ZoomPin.active and ("%.1f"):format(ZoomPin.distance or 0) or "off",
                zoomNow and ("%.1f"):format(zoomNow) or "?",
                ZoomGuard.blocked
            )
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
                    table.insert(lines, ("%s [%s] same=%s ignored=%s%s"):format(p.Name, p.Team and p.Team.Name or "NONE", tostring(isSameTeam(p, false)), tostring(ignoredReason(p, pchar)), sample))
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

    -- fps counter for the server info panel
    Stats.frames += 1
    local nowClock = os.clock()
    if nowClock - Stats.fpsAt >= 1 then
        Stats.fps = math.floor(Stats.frames / (nowClock - Stats.fpsAt))
        Stats.frames = 0
        Stats.fpsAt = nowClock
    end

    frameCounter += 1
    -- binds the wheel block while the menu is open and releases it when it
    -- closes; a no-op unless that state actually changed
    updateWheelSink()
    updateZoomPin()
    if frameCounter % 20 == 0 then
        pcall(function()
            Stats.ping = getPing()
            window:SetStatus(("%s  |  %d players  |  %s ms  |  %d fps"):format(
                BUILD, #Players:GetPlayers(), Stats.ping and tostring(Stats.ping) or "?", Stats.fps))
            updateDebugTab()
            updatePlayerList()
            updateStatsLabels()
            updateHitbox()
            applyMovement()

            if State.watermark then
                State.watermark.Visible = Config.Misc.Watermark
                if Config.Misc.Watermark then
                    State.watermark.Text = ("%s  |  %d fps  |  %d players  |  %s"):format(BUILD, Stats.fps, #Players:GetPlayers(), executor)
                end
            end

            -- noclip safety: indicator while active and an automatic off in
            -- toggle mode, so it cannot stay on unnoticed
            if State.noclipLabel then
                State.noclipLabel.Visible = Config.Player.Noclip
            end
            if Config.Player.Noclip and not Config.Player.NoclipHold and State.noclipSince
                and (os.clock() - State.noclipSince) > Config.Player.NoclipMaxSeconds then
                setNoclip(false)
                UI:RefreshAll()
                toast("Noclip switched off automatically (time limit)", Theme.danger)
            end
        end)
    end

    -- pick up particle emitters that spawned later (chunked scan)
    if frameCounter % 1200 == 0 and Config.Utility.FpsBoost then
        boostScanEmitters()
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
            if input.KeyCode == Enum.KeyCode.Backspace then
                Config.Keybinds[bind.keybind] = nil
                toast("Key cleared", Theme.dim)
            else
                Config.Keybinds[bind.keybind] = input.KeyCode
                toast("Key set: " .. input.KeyCode.Name, Theme.accent)
            end
            UI.promptBind = nil
            if bind.refresh then bind.refresh() end
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

    if key == Config.Keybinds.Unload then
        if _G.__scpUnload then _G.__scpUnload() end
        return
    end

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

    elseif key == Config.Keybinds.Noclip then
        if Config.Player.NoclipHold then
            pcall(setNoclip, true)
        else
            pcall(setNoclip, not Config.Player.Noclip)
        end
        UI:RefreshAll()
    end

    -- Everything else goes through the keybind registry, so every toggle and
    -- every button you bound works. The four reserved keys above either are not
    -- a plain toggle (menu, unload) or have hold behaviour (aim, noclip).
    if key == Config.Keybinds.MenuToggle or key == Config.Keybinds.Unload
        or key == Config.Keybinds.AimToggle or key == Config.Keybinds.Noclip then
        return
    end

    for name, action in pairs(UI.keyActions) do
        local bound = Config.Keybinds[name]
        if bound and bound == key then
            action.fire()
            UI:RefreshAll()
            toast(action.text, Theme.accent)
        end
    end
end))

-- a wheel tick while the menu is open arms the zoom guard for this frame
keepConnection(UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        zoomGuardArm()
    end
end))

keepConnection(UIS.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode == Config.Keybinds.AimToggle then
        State.aimKeyDown = false
    elseif input.KeyCode == Config.Keybinds.Noclip and Config.Player.NoclipHold then
        pcall(setNoclip, false)
        UI:RefreshAll()
    end
end))

keepConnection(Players.PlayerRemoving:Connect(function(p)
    destroyESPObjects(p)
end))

keepConnection(plr.CharacterAdded:Connect(function(char)
    Noclip.saved = nil
    pcall(bindCharacter, char)
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
    if Config.Utility.FpsBoost then pcall(setFpsBoost, true) end

    -- the hook was already installed in [11]; this is just a safety net
    if Config.Aim.Enabled and not State.hookInstalled then
        local ok, reason = pcall(installHook)
        if not ok then
            AIM_DEBUG.hook = "Error: " .. tostring(reason)
        end
    end

    UI:RefreshAll()

    _G.__scpUnload = function()
        if State.unloaded then return end
        State.unloaded = true

        -- stop aiming even if the author's build installed its own hook
        getgenv().sneeky_silent_aim = false

        for _, conn in ipairs(State.connections) do
            pcall(function() conn:Disconnect() end)
        end
        State.connections = {}

        clearESP()
        Config.Aim.Hitbox = false
        pcall(updateHitbox)
        pcall(setRemoveFog, false)
        pcall(setNoclip, false)
        pcall(setFullbright, false)
        pcall(setFpsBoost, false)

        if State.hookInstalled and State.bulletHit and restorefunction then
            pcall(restorefunction, State.bulletHit)
        end
        pcall(function()
            RunService:UnbindFromRenderStep("ScpAimStep")
        end)
        pcall(function()
            ContextActionService:UnbindAction("ScpMenuWheel")
        end)
        if ZoomPin.active then
            ZoomPin.active = false
            pcall(function()
                plr.CameraMinZoomDistance = ZoomPin.min
                plr.CameraMaxZoomDistance = ZoomPin.max
            end)
        end
        if UI.gui then UI.gui:Destroy() end
        if State.visualsGui then State.visualsGui:Destroy() end
        UI.gui = nil
        State.visualsGui = nil
        _G.__scpUnload = nil
        print("[menu] unloaded - run the loader again to start over")
    end

    toast("Silent Aim " .. (Config.Aim.Enabled and "ON" or "OFF") .. "  |  Hook: " .. AIM_DEBUG.hook,
        AIM_DEBUG.hook == "installed on Controller.BulletHit" and Theme.success or Theme.danger)
    toast("Keys: K menu, RightShift aim, V ESP, N noclip, B fullbright", Theme.accent)

    print(("[menu] %s loaded | executor=%s | aim-build=%s | hook=%s")
        :format(BUILD, executor, AIM_DEBUG.mode, AIM_DEBUG.hook))
end
