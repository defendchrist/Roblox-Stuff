-- Chaotic 3D Spherical Orbit Script (Emote-Friendly, No Falling, No Ground Clipping)

local config = {
    activationKey = Enum.KeyCode.E,
    orbitSpeed = 8,           -- Higher = faster orbit
    radius = 10,              -- Orbit radius
    verticalAmplitude = 5,    -- Max vertical swing
    smoothness = 0.45,        -- 0 = instant, 1 = no movement
    searchRadius = 60,        -- studs
    notify = true,
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

-- Variables
local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local isOrbiting = false
local targetPlayer = nil
local orbitConnection = nil
local elapsedTime = 0

-- Notification helper
local function notify(title, text)
    if config.notify then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = 3
            })
        end)
    end
end

-- Find player under mouse cursor
local function getPlayerUnderMouse()
    local hit = mouse.Hit
    if not hit then return nil end
    local hitPosition = hit.Position
    local closestPlayer, closestDistance = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (player.Character.HumanoidRootPart.Position - hitPosition).Magnitude
            if dist < closestDistance and dist < config.searchRadius then
                closestDistance = dist
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

-- Raycast downward to find ground Y at a position
local function getGroundY(pos)
    local rayOrigin = pos + Vector3.new(0, 5, 0)
    local rayDir = Vector3.new(0, -1000, 0)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(rayOrigin, rayDir, params)
    if result then
        return result.Position.Y
    end
    return -math.huge
end

-- Orbit update function
local function orbitUpdate(deltaTime)
    elapsedTime = elapsedTime + deltaTime * config.orbitSpeed
    -- Validate target
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        isOrbiting = false
        notify("Orbit stopped", "Target lost.")
        if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
        return
    end
    -- Validate self
    if not character or not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
        isOrbiting = false
        if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
        return
    end

    local targetHRP = targetPlayer.Character.HumanoidRootPart
    local targetPos = targetHRP.Position

    -- Chaotic spherical orbit: use two fast-changing angles
    local theta = elapsedTime
    local phi = math.sin(elapsedTime * 1.7) * math.pi -- swings up and down

    local x = math.cos(theta) * math.cos(phi) * config.radius
    local y = math.sin(phi) * config.verticalAmplitude
    local z = math.sin(theta) * math.cos(phi) * config.radius

    -- Never go below target's HRP Y (ground protection)
    local desiredY = math.max(targetPos.Y + y, targetPos.Y)

    -- Prevent going below ground
    local groundY = getGroundY(Vector3.new(targetPos.X + x, targetPos.Y + y, targetPos.Z + z))
    if desiredY < groundY + 2 then
        desiredY = groundY + 2
    end

    local orbitPosition = Vector3.new(
        targetPos.X + x,
        desiredY,
        targetPos.Z + z
    )

    -- Smooth movement
    local currentPosition = humanoidRootPart.Position
    local newPosition = currentPosition:Lerp(orbitPosition, config.smoothness)

    -- Set position and look at target horizontally (keep emote-friendly)
    humanoidRootPart.CFrame = CFrame.lookAt(newPosition, Vector3.new(targetPos.X, newPosition.Y, targetPos.Z))

    -- Do NOT set PlatformStand, Sit, or force Physics state (emotes work)
end

-- Toggle orbiting
local function toggleOrbit()
    if isOrbiting then
        -- Stop orbiting
        isOrbiting = false
        if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
        notify("Orbit stopped", "You are free to move again.")
    else
        targetPlayer = getPlayerUnderMouse()
        if targetPlayer then
            isOrbiting = true
            elapsedTime = 0
            orbitConnection = RunService.Heartbeat:Connect(orbitUpdate)
            notify("Chaotic Orbit", "Now orbiting: " .. targetPlayer.Name)
        else
            notify("No player found", "Hover mouse over a player and try again.")
        end
    end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == config.activationKey then
        toggleOrbit()
    end
end)

-- Character respawn handling
localPlayer.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")
    if isOrbiting then
        isOrbiting = false
        if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
    end
end)

print("Chaotic 3D Orbiter loaded! Hover mouse over a player and press E to orbit them.")
