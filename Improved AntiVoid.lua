-- Universal Anti-Void Script (Clean, Robust, Efficient)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CONFIG = {
    voidMargin = 10,                 -- How far above the void to teleport you
    teleportYOffset = 5,             -- How high above the void to place you
    useSafetyPlatform = false,       -- Set true to use invisible platform under you
    platformSize = Vector3.new(20, 1, 20),
    platformTransparency = 1,        -- 1 = fully invisible
    platformColor = Color3.fromRGB(255, 255, 255),
    platformMaterial = Enum.Material.ForceField,
    log = true
}

local state = {
    originalDestroyHeight = Workspace.FallenPartsDestroyHeight,
    platform = nil,
    connections = {},
    running = false
}

local function log(msg)
    if CONFIG.log then print("[AntiVoid] " .. msg) end
end

local function createPlatform()
    if state.platform and state.platform.Parent then return state.platform end
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Size = CONFIG.platformSize
    p.Transparency = CONFIG.platformTransparency
    p.Color = CONFIG.platformColor
    p.Material = CONFIG.platformMaterial
    p.Name = "AntiVoidPlatform"
    p.Parent = Workspace
    state.platform = p
    return p
end

local function removePlatform()
    if state.platform and state.platform.Parent then
        state.platform:Destroy()
    end
    state.platform = nil
end

local function protectCharacter(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local voidY = Workspace.FallenPartsDestroyHeight + CONFIG.voidMargin
    if hrp.Position.Y <= voidY then
        local safeY = voidY + CONFIG.teleportYOffset
        hrp.Velocity = Vector3.zero
        char:PivotTo(CFrame.new(hrp.Position.X, safeY, hrp.Position.Z))
        log("Teleported above void!")
    end
    if CONFIG.useSafetyPlatform then
        local plat = createPlatform()
        plat.Position = Vector3.new(hrp.Position.X, voidY - plat.Size.Y/2, hrp.Position.Z)
    end
end

local function onStep()
    local lp = Players.LocalPlayer
    if not lp or not lp.Character then return end
    protectCharacter(lp.Character)
end

local function start()
    if state.running then return end
    state.running = true
    Workspace.FallenPartsDestroyHeight = state.originalDestroyHeight
    if CONFIG.useSafetyPlatform then createPlatform() end
    table.insert(state.connections, RunService.Heartbeat:Connect(onStep))
    local lp = Players.LocalPlayer
    table.insert(state.connections, lp.CharacterAdded:Connect(function(char)
        log("Character respawned, re-enabling anti-void.")
        task.wait(1)
        protectCharacter(char)
    end))
    log("Anti-void protection enabled.")
end

local function stop()
    if not state.running then return end
    for _,c in ipairs(state.connections) do
        if c and typeof(c)=="RBXScriptConnection" then c:Disconnect() end
    end
    state.connections = {}
    removePlatform()
    Workspace.FallenPartsDestroyHeight = state.originalDestroyHeight
    state.running = false
    log("Anti-void protection disabled.")
end

-- Auto-start for local player
start()

-- Expose controls
getgenv().StartAntiVoid = start
getgenv().StopAntiVoid = stop

return "Anti-void protection loaded."
