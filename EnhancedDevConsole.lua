-- Roblox DevConsole click-to-copy injector with full persistence, instance replacement, and original color preservation

local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

-- Unique identifier for this script instance
local SCRIPT_ID = "ConsoleEnhancer_" .. tostring(math.random(100000, 999999))

-- Clean up any previous instance
local function stopOldInstance()
    local oldInstanceId = CoreGui:FindFirstChild("ConsoleEnhancerInstanceId")
    if oldInstanceId and oldInstanceId:IsA("StringValue") then
        if oldInstanceId.Value ~= SCRIPT_ID then
            oldInstanceId.Value = "STOP"
            task.wait(0.1)
        end
        oldInstanceId:Destroy()
    end
end

-- Create a new instance marker
local function setInstanceId()
    local instanceId = Instance.new("StringValue")
    instanceId.Name = "ConsoleEnhancerInstanceId"
    instanceId.Value = SCRIPT_ID
    instanceId.Parent = CoreGui
    return instanceId
end

-- Send a notification, safe and truncated
local function sendNotification(text)
    local truncated = text:sub(1, 50)
    if #text > 50 then truncated = truncated .. "..." end
    pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
        Title = "Copied!",
        Text = "Log copied: " .. truncated,
        Duration = 2
    })
end

-- Enhance a log item for click-to-copy
local function enhanceLog(logItem, processed)
    if processed[logItem] then return end
    local msg = logItem:FindFirstChild("msg")
    if msg and msg:IsA("TextLabel") then
        processed[logItem] = true
        local originalColor = msg.TextColor3
        msg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                pcall(setclipboard, msg.Text)
                sendNotification(msg.Text)
            end
        end)
        msg.MouseEnter:Connect(function()
            msg.TextColor3 = Color3.fromRGB(255, 0, 0)
        end)
        msg.MouseLeave:Connect(function()
            msg.TextColor3 = originalColor
        end)
        msg.Selectable = true
    end
end

-- Process all logs in ClientLog
local function processLogs(clientLog, processed)
    for _, item in ipairs(clientLog:GetChildren()) do
        if item:IsA("Frame") then
            enhanceLog(item, processed)
        end
    end
end

-- Find the ClientLog frame in DevConsole
local function findClientLog()
    local console = CoreGui:FindFirstChild("DevConsoleMaster")
    if not console then return nil end
    local window = console:FindFirstChild("DevConsoleWindow")
    if not window then return nil end
    local ui = window:FindFirstChild("DevConsoleUI")
    if not ui then return nil end
    local mainView = ui:FindFirstChild("MainView")
    if not mainView then return nil end
    return mainView:FindFirstChild("ClientLog")
end

-- Main monitor loop, event-driven where possible
local function monitorConsole(instanceId)
    local processed = {}
    local lastClientLog, connection = nil, nil

    while instanceId.Parent == CoreGui and instanceId.Value == SCRIPT_ID do
        local clientLog = findClientLog()
        if clientLog and clientLog ~= lastClientLog then
            processLogs(clientLog, processed)
            if connection then connection:Disconnect() end
            connection = clientLog.ChildAdded:Connect(function(child)
                if child:IsA("Frame") then
                    task.wait(0.01)
                    enhanceLog(child, processed)
                end
            end)
            lastClientLog = clientLog
        elseif clientLog then
            processLogs(clientLog, processed)
        else
            if connection then connection:Disconnect() end
            lastClientLog, connection = nil, nil
        end
        task.wait(1)
    end
    if connection then connection:Disconnect() end
end

-- Main execution
stopOldInstance()
local instanceId = setInstanceId()
task.spawn(function()
    local ok, err = pcall(function() monitorConsole(instanceId) end)
    if not ok then warn("Monitor error: " .. tostring(err)) end
end)
print("Console Enhancement activated - Instance ID: " .. SCRIPT_ID)
