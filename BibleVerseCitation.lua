-- Toggle debug mode (set to true to enable debug/error messages, false to disable)
local debugMode = false

-- Function to handle debug and error messages
local function debugPrint(message, isError)
    if debugMode then
        if isError then
            warn("[ERROR] " .. message) -- Use warn() for errors
        else
            print("[DEBUG] " .. message) -- Use print() for debug messages
        end
    end
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

-- Chat message character limit
local CHAT_LIMIT = 200
-- Time interval between sending messages (in seconds)
local MESSAGE_INTERVAL = 2

-- Detect supported HTTP request function
local httpRequest = syn and syn.request or http_request or request
if not httpRequest then
    error("HTTP request function not supported by this executor.")
end

-- Function to fetch Bible verse(s) using an HTTP request
local function fetchBibleVerses(reference)
    local encodedReference = string.gsub(reference, " ", "+")
    local url = "https://bible-api.com/" .. encodedReference .. "?translation=kjv"
    debugPrint("Fetching Bible verses from URL: " .. url)

    local success, response = pcall(function()
        return httpRequest({
            Url = url,
            Method = "GET",
        })
    end)

    if success and response.StatusCode == 200 then
        local decodedResponse = HttpService:JSONDecode(response.Body)
        if decodedResponse and decodedResponse.text then
            debugPrint("Successfully fetched response from API")
            return decodedResponse.text
        else
            debugPrint("Verse not found or invalid response format.", true)
            return "Verse not found."
        end
    else
        debugPrint("Failed to fetch verses: " .. tostring(response), true)
        return "Error fetching verses."
    end
end

-- Function to split text into smaller chunks for Roblox chat
local function splitText(text, limit)
    local chunks = {}
    while #text > limit do
        table.insert(chunks, string.sub(text, 1, limit))
        text = string.sub(text, limit + 1)
    end
    table.insert(chunks, text)
    debugPrint("Text successfully split into " .. #chunks .. " chunk(s)")
    return chunks
end

-- Function to send messages in Roblox chat with intervals using TextChatService
local function sendChatMessages(messages)
    for i, message in ipairs(messages) do
        task.wait(MESSAGE_INTERVAL * (i - 1))
        debugPrint("Sending message chunk: " .. message)

        local textChannel = TextChatService.TextChannels.RBXGeneral
        if textChannel then
            textChannel:SendAsync(message)
        else
            Players.LocalPlayer:Chat(message)
        end
    end
end

-- Function to check if the message is a valid Bible reference (including ranges)
local function isValidBibleReference(message)
    -- Match patterns like "1 John 3:16", "Genesis 1:1-2", etc.
    return string.match(message, "^%d?%s?%w+%s%d+:%d+[-,%d]*$") ~= nil
end

-- Listen for chat messages from the local player only
Players.LocalPlayer.Chatted:Connect(function(message)
    debugPrint("Message received from LocalPlayer: " .. message)

    if isValidBibleReference(message) then
        debugPrint("Valid Bible reference detected: " .. message)

        local verseText = fetchBibleVerses(message)

        if verseText then
            local chunks = splitText(verseText, CHAT_LIMIT)
            sendChatMessages(chunks)
        else
            debugPrint("Verse text is nil or empty!", true)
        end
    else
        debugPrint("Message did not match a valid Bible reference pattern")
    end
end)

debugPrint("Client-side script loaded successfully")
