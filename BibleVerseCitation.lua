-- I completely prompted, error handled, and tested this with perplexity AI as my IDE of sorts since I do not have access to my PC ivo been kinda forced to resort to AI helping farmulate my ideas 
-- This was well worth it and I love it I also take suggestions on discord my discord is defendchrist

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
    -- Correctly encode the reference for the URL
    local encodedReference = string.gsub(reference, " ", "+")
    local url = "https://bible-api.com/" .. encodedReference .. "?translation=kjv"
    print("[DEBUG] Fetching Bible verses from URL: " .. url)

    local success, response = pcall(function()
        return httpRequest({
            Url = url,
            Method = "GET",
        })
    end)

    if success and response.StatusCode == 200 then
        local decodedResponse = HttpService:JSONDecode(response.Body)
        if decodedResponse and decodedResponse.text then
            print("[DEBUG] Successfully fetched response from API")
            return decodedResponse.text
        else
            warn("[ERROR] Verse not found or invalid response format.")
            return "Verse not found."
        end
    else
        warn("[ERROR] Failed to fetch verses: " .. tostring(response))
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
    return chunks
end

-- Function to send messages in Roblox chat with intervals using TextChatService
local function sendChatMessages(messages)
    for i, message in ipairs(messages) do
        task.wait(MESSAGE_INTERVAL * (i - 1))
        print("[DEBUG] Sending message chunk: " .. message)

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
    print("[DEBUG] Message received from LocalPlayer: " .. message)

    if isValidBibleReference(message) then
        print("[DEBUG] Valid Bible reference detected: " .. message)

        local verseText = fetchBibleVerses(message)

        if verseText then
            local chunks = splitText(verseText, CHAT_LIMIT)
            sendChatMessages(chunks)
        else
            warn("[ERROR] Verse text is nil or empty!")
        end
    else
        print("[DEBUG] Message did not match a valid Bible reference pattern")
    end
end)

print("[DEBUG] Client-side script loaded successfully")
