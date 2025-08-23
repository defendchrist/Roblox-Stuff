-- Flashback Rewind Script (Enhanced & Optimized Version)

-- Clean up previous instance
if getgenv().FlashbackControl then
    pcall(function()
        getgenv().FlashbackControl.Stop()
    end)
end

-- SETTINGS
local settings = {
    Keybind = "C",           -- Key to hold for rewinding
    Speed = 1,               -- Rewind speed (frames per step)
    FlashbackLength = 95,    -- Max rewind time in seconds
    AutoStart = true,        -- Start automatically
    RenderStepPriority = 1,  -- Lower = higher priority
    RewindDelay = 0.15,      -- Delay between rewinds (lower = faster)
    NotificationDuration = { Normal = 5, Warning = 6, Error = 7 },
    PrintInstructions = true,
    Debug = false,           -- Set true for debug prints
}

-- SERVICES
local uis = cloneref and cloneref(game:GetService("UserInputService")) or game:GetService("UserInputService")
local runService = cloneref and cloneref(game:GetService("RunService")) or game:GetService("RunService")
local players = cloneref and cloneref(game:GetService("Players")) or game:GetService("Players")
local player = players.LocalPlayer

-- NOTIFY FUNCTION
if not getgenv().notify then
    getgenv().notify = function(title, message, duration)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = title,
                Text = message,
                Duration = duration,
            })
        end)
    end
end

local function debugPrint(...)
    if settings.Debug then print("[Flashback]", ...) end
end

-- STATE
local frames = {}
local flashbackActive = false
local connections = {}

-- HELPERS
local function getCharacterReferences()
    local character = player.Character
    if not character then return nil, nil, nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return nil, nil, nil end
    return character, humanoid, root
end

local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

-- FRAME CAPTURE
local function advanceFrame()
    local _, humanoid, root = getCharacterReferences()
    if not humanoid or not root then return end
    if #frames > clamp(settings.FlashbackLength * 60, 60, 6000) then
        table.remove(frames, 1)
    end
    frames[#frames+1] = {
        root.CFrame,
        root.Velocity,
        humanoid:GetState(),
        humanoid.PlatformStand
    }
end

-- REWIND
local function revertFrame()
    local _, humanoid, root = getCharacterReferences()
    if not humanoid or not root then return end
    if #frames == 0 then advanceFrame() return end
    for _ = 1, clamp(settings.Speed, 1, 10) do
        if #frames == 0 then break end
        table.remove(frames)
    end
    local last = frames[#frames]
    if not last then return end
    root.CFrame = last[1]
    task.wait(settings.RewindDelay)
    root.Velocity = -last[2]
    humanoid:ChangeState(last[3])
    humanoid.PlatformStand = last[4]
end

-- RENDERSTEP HANDLER
local function onRenderStep()
    local key = Enum.KeyCode[string.upper(settings.Keybind)]
    if not key or typeof(key) ~= "EnumItem" then
        getgenv().notify("Invalid Key!", "KeyCode is invalid, try another one", settings.NotificationDuration.Error)
        getgenv().FlashbackControl.Stop()
        return
    end
    if uis:IsKeyDown(key) then
        revertFrame()
    else
        advanceFrame()
    end
end

-- CLEANUP
local function cleanupConnections()
    for _, conn in ipairs(connections) do
        if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
        end
    end
    connections = {}
end

-- STOP
local function stopFlashback()
    if flashbackActive then
        pcall(function()
            runService:UnbindFromRenderStep("FlashbackStep")
            cleanupConnections()
            frames = {}
            flashbackActive = false
        end)
        getgenv().notify("Flashback Disabled", "Successfully unloaded flashback script", settings.NotificationDuration.Normal)
        debugPrint("Stopped.")
        return true
    else
        getgenv().notify("Error", "Flashback Rewind is not running.", settings.NotificationDuration.Normal)
        return false
    end
end

-- START
local function startFlashback()
    if flashbackActive then
        getgenv().notify("Failed", "Flashback Rewind is already running!", settings.NotificationDuration.Error)
        return false
    end
    local key = Enum.KeyCode[string.upper(settings.Keybind)]
    if not key then
        getgenv().notify("Invalid Key!", "KeyCode is invalid, try another one", settings.NotificationDuration.Warning)
        return false
    end
    cleanupConnections()
    frames = {}
    -- Character respawn handler
    table.insert(connections, player.CharacterAdded:Connect(function()
        frames = {}
        debugPrint("Character respawned, frames reset.")
    end))
    -- Bind renderstep
    runService:BindToRenderStep("FlashbackStep", clamp(settings.RenderStepPriority, 1, 200), onRenderStep)
    flashbackActive = true
    getgenv().notify("Flashback Enabled", "Hold " .. settings.Keybind .. " to rewind", settings.NotificationDuration.Normal)
    debugPrint("Started.")
    return true
end

-- SETTINGS UPDATE
local function updateSettings(newSettings)
    for k, v in pairs(newSettings) do
        if settings[k] ~= nil then
            settings[k] = v
        end
    end
    if flashbackActive then
        stopFlashback()
        startFlashback()
    end
    getgenv().notify("Settings Updated", "Flashback settings have been updated", settings.NotificationDuration.Normal)
end

-- API
getgenv().FlashbackControl = {
    Start = startFlashback,
    Stop = stopFlashback,
    UpdateSettings = updateSettings,
    GetSettings = function() return settings end
}

-- INSTRUCTIONS
if settings.PrintInstructions then
    print("Flashback Rewind Loaded!")
    print("Current Settings:")
    for k, v in pairs(settings) do
        if type(v) ~= "table" then print("- " .. k .. ": " .. tostring(v)) end
    end
    print("To update settings: getgenv().FlashbackControl.UpdateSettings({Keybind = \"X\", Speed = 2.5})")
    print("To stop: getgenv().FlashbackControl.Stop()")
    print("To start: getgenv().FlashbackControl.Start()")
    print("To get current settings: getgenv().FlashbackControl.GetSettings()")
end

-- AUTOSTART
if settings.AutoStart then
    startFlashback()
end
