--!nonstrict
--[[=====================================================================
  MERGED SCRIPT
    [2] Silent-aim config        -> the getgenv() flags
    [5] Silent aim               -> contents of SCP_Roleplay/main.luau
                                    (target finder + aim UI + the hook)
    [6] DeepHat Player-Only ESP  -> Highlight + toggle button
    [7] Status panel             -> DEBUG_AIM = false removes it

  The decisive difference to the earlier merge: main.luau's LAST block is
  included here - the hookfunction() on the Controller's BulletHit. That
  hook is what redirects your shots onto the target. Without it the FOV
  circle and the tracers still appear (they come from UIs/silent_aim.luau)
  while every bullet keeps flying exactly where you aimed.

  Remote fetches: UIs/silent_aim.luau (the aim GUI) and optionally the
  author's live main.luau. NOTIFICATION_LIBRARY and Teams.luau are not
  fetched (see the flags in [2]).
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
-- [1] SERVICES / LOCALS
--=====================================================================
local RS: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Players: Players = cloneref(game:GetService("Players"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local UIS: UserInputService = cloneref(game:GetService("UserInputService"))

local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled

--=====================================================================
-- [2] CONFIG
--=====================================================================
getgenv().sneeky_silent_aim = true
getgenv().sneeky_fov_size = 300

-- true  = download the author's newest SCP_Roleplay/main.luau and run that
--         instead of the inlined copy (safer after a game update)
-- false = run the inlined copy, i.e. the file you sent
local PREFER_REMOTE_BUILD = false
local SILENT_AIM_URL = "https://sneekysscripts.uk/Scripts/SCP_Roleplay/main.luau"
local SILENT_AIM_UI_URL = "https://sneekysscripts.uk/Scripts/UIs/silent_aim.luau"

-- true  = also fetch Teams.luau, the author's team-alias table. That is what
--         the original main.luau uses, and it groups teams that only differ
--         by name/instance but are the same side.
-- false = plain Team comparison (your earlier choice)
local FETCH_TEAM_ALIASES = false

-- Status panel in section [7]
local DEBUG_AIM = true

--=====================================================================
-- [3] ERROR REPORTING  (notification-library fetch removed)
--=====================================================================
local function notifyError(msg: string)
    return warn(msg)
end

local function notifySuccess(msg: string)
    return print(msg)
end

--=====================================================================
-- [4] TEAM CHECK
--     teamlessIsSame keeps the two original behaviours apart: main.luau's
--     aim treats players without a Team as enemies, script #3's ESP read
--     nil == nil as "same side" and hid them.
--=====================================================================
local teamAliases = nil
if FETCH_TEAM_ALIASES then
    local ok, res = pcall(function()
        return loadstring(game:HttpGet("https://sneekysscripts.uk/Scripts/SCP_Roleplay/Teams.luau"))()
    end)
    if ok and type(res) == "table" then
        teamAliases = res
    else
        warn("[merged] Teams.luau unavailable, using plain Team comparison")
    end
end

local isSameTeam = function(player: Player, teamlessIsSame: boolean): boolean
    if not player or player == plr then return true end
    if player.Team and player.Team == plr.Team then return true end
    if teamAliases and player.Team and plr.Team then
        local mine, theirs = teamAliases[plr.Team.Name], teamAliases[player.Team.Name]
        if mine ~= nil and theirs ~= nil and mine == theirs then return true end
    end
    if player.Team == nil and plr.Team == nil then return teamlessIsSame end
    return false
end

--=====================================================================
-- [5] SILENT AIM  (contents of SCP_Roleplay/main.luau)
--=====================================================================
local AIM_DEBUG = {
    mode = "not started",
    hook = "not installed",
    calls = 0, hits = 0, lastTarget = "-",
    reasons = {},
    controller = false, bulletHit = false, uiLoaded = false,
}
local function dbgReason(reason: string)
    AIM_DEBUG.reasons[reason] = (AIM_DEBUG.reasons[reason] or 0) + 1
end

local getTarget

do
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = true

    local isVisible = function(part: BasePart, origin: Vector3): (boolean, Instance?)
        local char = plr.Character
        if not (char and part) then return false, nil end

        -- built without nil holes; the original passed possibly-nil folders in
        local filter: { Instance } = { char }
        local pathMods = workspace:FindFirstChild("RoleplayPathMods")
        local gunIgnore = workspace:FindFirstChild("Gun_Ignore")
        if pathMods then table.insert(filter, pathMods) end
        if gunIgnore then table.insert(filter, gunIgnore) end
        rp.FilterDescendantsInstances = filter

        local result: RaycastResult = workspace:Raycast(origin, part.Position - origin, rp)
        if not result then return true, nil end

        if result.Instance:IsDescendantOf(part.Parent) then
            return true, result.Instance
        end

        return false, result.Instance
    end

    getTarget = function(origin: Vector3?)
        if not getgenv().sneeky_silent_aim then return nil end
        AIM_DEBUG.calls += 1

        -- the hook passes the camera position; a nil origin would make
        -- `part.Position - origin` throw and silently kill every call
        origin = origin or (plr.Character and plr.Character:GetPivot().Position) or cam.CFrame.Position

        local cPart, cPlayer, cDistance = nil, nil, getgenv().sneeky_fov_size or 300

        for _, player: Player in next, Players:GetPlayers() do
            if player == plr then continue end
            if isSameTeam(player, false) then dbgReason("team"); continue end

            local char = player.Character
            if not char then dbgReason("nochar"); continue end
            if char:FindFirstChildOfClass("ForceField") then dbgReason("forcefield"); continue end
            if char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0 then dbgReason("dead"); continue end

            local tPart: BasePart = char:FindFirstChild("Head") or char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
            if not tPart then dbgReason("nopart"); continue end

            local pos, onScreen = cam:WorldToViewportPoint(tPart.Position)
            if not onScreen then dbgReason("offscreen"); continue end

            local v, nTPart = isVisible(tPart, origin)
            if not v then
                v, nTPart = isVisible(char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"), origin)
                if not v then dbgReason("blocked"); continue end
            end

            if nTPart then tPart = nTPart end

            local distance = (Vector2.new(pos.X, pos.Y) - (isMobile and Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2) or UIS:GetMouseLocation())).Magnitude
            if distance < cDistance then
                cPart = tPart
                cPlayer = player
                cDistance = distance
                dbgReason("accepted")
            else
                dbgReason("outoffov")
            end
        end

        if cPart then
            AIM_DEBUG.hits += 1
            AIM_DEBUG.lastTarget = ("%s (%s, %.0fpx)"):format(cPlayer.Name, cPart.Name, cDistance)
        end
        return cPart
    end

    -- The inlined build: exactly what SCP_Roleplay/main.luau does, including
    -- the BulletHit hook at the end that makes the shots actually connect.
    local runInlineBuild = function(): (boolean, string)
        if not (hookfunction and getsenv) then
            return false, executor .. " is missing " .. (not hookfunction and "hookfunction " or "") .. (not getsenv and "getsenv" or "")
        end

        local controller = plr.PlayerScripts:FindFirstChild("Controller")
        if not controller then return false, "Script needs updating" end
        AIM_DEBUG.controller = true

        -- the author walks getsenv(controller).BulletHit until it exists
        local bulletHit
        for _ = 1, 50 do
            local env = select(2, pcall(getsenv, controller))
            if type(env) == "table" and env.BulletHit then
                bulletHit = env.BulletHit
                break
            end
            task.wait()
        end
        if not bulletHit then return false, "Failed to retrieve function" end
        AIM_DEBUG.bulletHit = true

        -- 1) the aim GUI (FOV circle + tracers)
        local uiOk, uiErr = pcall(function()
            loadstring(game:HttpGet(SILENT_AIM_UI_URL))()(getgenv().sneeky_fov_size or 300, getTarget, true)
        end)
        if uiOk then
            AIM_DEBUG.uiLoaded = true
        else
            warn("[merged] silent aim UI failed to load: " .. tostring(uiErr))
        end

        -- 2) the aim itself: replace the hit data handed to BulletHit.
        --    old(self, hitData, ...) -> old(self, fakedHitData, ...)
        local hookOk, hookErr = pcall(function()
            local old
            old = clonefunction(hookfunction(bulletHit, newcclosure(function(_, hitData, ...)
                -- camera can be swapped on respawn, so read it per call
                local origin = (workspace.CurrentCamera or cam).CFrame.Position
                local c = getTarget(origin)
                if c then
                    return old(_, {
                        ["Instance"] = c,
                        ["Position"] = c.Position,
                        ["Normal"] = Vector3.new(0, 1, 0),
                        ["Material"] = c.Material,
                    }, ...)
                end
                return old(_, hitData, ...)
            end)))
            AIM_DEBUG.hook = old ~= nil and "installed on Controller.BulletHit" or "hookfunction returned nothing"
        end)
        if not hookOk then
            AIM_DEBUG.hook = "failed: " .. tostring(hookErr)
            return false, "hookfunction failed: " .. tostring(hookErr)
        end
        if AIM_DEBUG.hook ~= "installed on Controller.BulletHit" then
            return false, AIM_DEBUG.hook
        end

        return true, "inlined main.luau (hook installed)"
    end

    local initSilentAim = function()
        if PREFER_REMOTE_BUILD then
            local ok, err = pcall(function()
                loadstring(game:HttpGet(SILENT_AIM_URL))()
            end)
            if ok then
                AIM_DEBUG.mode = "main.luau (author build, remote)"
                AIM_DEBUG.hook = "handled by the author build"
                return
            end
            warn("[merged] " .. SILENT_AIM_URL .. " failed: " .. tostring(err) .. " - falling back to the inlined copy")
        end

        local ok, reason = runInlineBuild()
        if ok then
            AIM_DEBUG.mode = reason
        else
            AIM_DEBUG.mode = "FAILED - " .. reason
            notifyError("Silent aim did not load: " .. reason)
        end
    end

    local ok, res = pcall(initSilentAim)
    if not ok then
        AIM_DEBUG.mode = "FAILED - init error: " .. tostring(res)
        warn("[merged] silent aim init error, ESP will still run: " .. tostring(res))
    end

    if AIM_DEBUG.mode:find("inlined") then
        notifySuccess("Silent aim loaded (inlined main.luau, hook " .. AIM_DEBUG.hook .. ")")
    end
end

--=====================================================================
-- [6] PLAYER-ONLY ESP  (was script #3)
--=====================================================================
local Settings = {
    color = Color3.fromRGB(255, 50, 50),
    outline = Color3.fromRGB(0, 0, 0),
    team_check = true,
    enabled = false, -- master switch
    gui_visible = true,
}

local target_container
do
    local ok, res = pcall(function() return gethui and gethui() end)
    target_container = (ok and res) or game:GetService("CoreGui")
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeepHat_Player_ESP"
ScreenGui.Parent = target_container

local MainButton = Instance.new("TextButton")
MainButton.Size = UDim2.new(0, 150, 0, 50)
MainButton.Position = UDim2.new(0.5, -75, 0.1, 0)
MainButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
MainButton.Text = "ESP: OFF"
MainButton.TextColor3 = Color3.new(1, 1, 1)
MainButton.Font = Enum.Font.SourceSansBold
MainButton.TextSize = 20
MainButton.BorderSizePixel = 2
MainButton.Parent = ScreenGui
MainButton.Active = true
MainButton.Draggable = true

local tagFor = function(v: Player): string
    return "hx_p_" .. v.UserId
end

local clearESP = function(v: Player?)
    if v then
        local existing = target_container:FindFirstChild(tagFor(v))
        if existing then existing:Destroy() end
        return
    end
    for _, p in pairs(Players:GetPlayers()) do
        local existing = target_container:FindFirstChild(tagFor(p))
        if existing then existing:Destroy() end
    end
end

MainButton.MouseButton1Click:Connect(function()
    Settings.enabled = not Settings.enabled

    if Settings.enabled then
        MainButton.Text = "ESP: ON"
        MainButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    else
        MainButton.Text = "ESP: OFF"
        MainButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        clearESP() -- aggressive cleanup: wipe all ESP tags
    end
end)

-- hide interface with K
UIS.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.K then
        Settings.gui_visible = not Settings.gui_visible
        ScreenGui.Enabled = Settings.gui_visible
    end
end)

local get_color = function(v: Player): Color3
    if Settings.team_check and not isSameTeam(v, true) and v.Team then
        return v.Team.TeamColor.Color
    end
    return Settings.color
end

local apply_esp = function(v: Player)
    if not v:IsA("Player") or v == plr then return end
    if not v.Character or not v.Character:FindFirstChild("HumanoidRootPart") then return end
    if Settings.team_check and isSameTeam(v, true) then return end

    local tag = tagFor(v)
    if target_container:FindFirstChild(tag) then return end

    local h = Instance.new("Highlight")
    h.Name = tag
    h.Adornee = v.Character
    h.FillColor = get_color(v)
    h.OutlineColor = Settings.outline
    h.FillTransparency = 0.45
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = target_container
end

RunService.RenderStepped:Connect(function()
    if not Settings.enabled then return end

    for _, v in pairs(Players:GetPlayers()) do
        if v ~= plr then
            local existing = target_container:FindFirstChild(tagFor(v))
            local shouldShow = v.Character
                and v.Character:FindFirstChild("HumanoidRootPart") ~= nil
                and not (Settings.team_check and isSameTeam(v, true))

            if shouldShow then
                if not existing then
                    apply_esp(v)
                else
                    existing.FillColor = get_color(v) -- team / settings may have changed
                end
            elseif existing then
                existing:Destroy()
            end
        end
    end
end)

-- cleanup when a player leaves
Players.PlayerRemoving:Connect(clearESP)

--=====================================================================
-- [7] STATUS PANEL  (DEBUG_AIM = false removes all of this)
--     Line 2 = which silent-aim build is running, line 3 = is the hook in.
--     The counters only move while getTarget() is being called.
--=====================================================================
if DEBUG_AIM then
    local dbgGui = Instance.new("ScreenGui")
    dbgGui.Name = "SilentAim_Debug"
    dbgGui.ResetOnSpawn = false
    dbgGui.Parent = target_container

    local panel = Instance.new("TextLabel")
    panel.Size = UDim2.new(0, 560, 0, 330)
    panel.Position = UDim2.new(0, 8, 0, 8)
    panel.BackgroundColor3 = Color3.new(0, 0, 0)
    panel.BackgroundTransparency = 0.3
    panel.TextColor3 = Color3.fromRGB(90, 255, 140)
    panel.TextXAlignment = Enum.TextXAlignment.Left
    panel.TextYAlignment = Enum.TextYAlignment.Top
    panel.Font = Enum.Font.Code
    panel.TextSize = 13
    panel.Text = "collecting..."
    panel.Active = true
    panel.Draggable = true
    panel.Parent = dbgGui

    -- F3 hides the panel if it is in the way
    UIS.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.F3 then
            dbgGui.Enabled = not dbgGui.Enabled
        end
    end)

    local reasonOrder = { "team", "nochar", "forcefield", "dead", "nopart", "offscreen", "blocked", "outoffov", "accepted" }

    task.spawn(function()
        while dbgGui.Parent do
            local out = {
                "===== SILENT AIM STATUS (F3 hides, draggable) =====",
                ("build: %s"):format(AIM_DEBUG.mode),
                ("BulletHit hook: %s"):format(AIM_DEBUG.hook),
                ("aim flag=%s   fov=%s   executor=%s"):format(tostring(getgenv().sneeky_silent_aim), tostring(getgenv().sneeky_fov_size), executor),
                ("hookfunction=%s   getsenv=%s   controller=%s   bulletHit=%s   ui=%s"):format(tostring(hookfunction ~= nil), tostring(getsenv ~= nil), tostring(AIM_DEBUG.controller), tostring(AIM_DEBUG.bulletHit), tostring(AIM_DEBUG.uiLoaded)),
                ("getTarget: calls=%d   with a target=%d   last=%s"):format(AIM_DEBUG.calls, AIM_DEBUG.hits, AIM_DEBUG.lastTarget),
                "-- outcome per checked player --",
            }

            local parts = {}
            for _, k in ipairs(reasonOrder) do
                if AIM_DEBUG.reasons[k] then
                    table.insert(parts, ("%s=%d"):format(k, AIM_DEBUG.reasons[k]))
                end
            end
            table.insert(out, #parts > 0 and table.concat(parts, "  ") or "(nothing yet)")

            table.insert(out, "-- players, as the aim sees them (teamless counts as enemy) --")
            for _, p in next, Players:GetPlayers() do
                if p ~= plr then
                    table.insert(out, ("%s | team=%s | same team for aim=%s"):format(
                        p.Name,
                        p.Team and p.Team.Name or "NONE",
                        tostring(isSameTeam(p, false))
                    ))
                end
            end

            panel.Text = table.concat(out, "\n")
            task.wait(0.25)
        end
    end)
end

print("Merged: silent aim (main.luau) + DeepHat ESP loaded. Build: " .. AIM_DEBUG.mode)
