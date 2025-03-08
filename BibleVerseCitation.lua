-- Toggle debug mode (set to true to enable debug/error messages, false to disable)
local debugMode = true

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

        -- Attempt to use TextChatService if available
        local textChannel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if textChannel then
            pcall(function()
                textChannel:SendAsync(message)
            end)
        else
            -- Fallback to Players.LocalPlayer:Chat()
            pcall(function()
                Players.LocalPlayer:Chat(message)
            end)
        end
    end
end

-- Nicene Creed text (to be sent in chunks when triggered)
local niceneCreedText = [[
I believe in one God, Father Almighty, Creator of heaven and earth, and of all things visible and invisible.

And in one Lord Jesus Christ, the only-begotten Son of God, begotten of the Father before all ages; Light of Light, true God of true God, begotten, not created, of one essence with the Father through Whom all things were made. Who for us men and for our salvation came down from heaven and was incarnate of the Holy Spirit and the Virgin Mary and became man. He was crucified for us under Pontius Pilate, and suffered and was buried; And He rose on the third day, according to the Scriptures. He ascended into heaven and is seated at the right hand of the Father; And He will come again with glory to judge the living and dead. His kingdom shall have no end.

And in the Holy Spirit, the Lord, the Creator of life, Who proceeds from the Father, Who together with the Father and the Son is worshipped and glorified, Who spoke through the prophets.

In one, holy, catholic, and apostolic Church.

I confess one baptism for the forgiveness of sins.

I look for the resurrection of the dead, and the life of the age to come.

Amen.
]]

-- Function to check if a message is a valid Bible reference (including ranges), case-insensitive
local function isValidBibleReference(message)
    -- Convert message to lowercase for case-insensitive matching
    local lowerMessage = string.lower(message)

    -- Match patterns like "1 john 3:16", "genesis 1:1-2", etc.
    return string.match(lowerMessage, "^%d?%s?%w+%s%d+:%d+[-,%d]*$") ~= nil
end

-- Listen for chat messages from the local player only
Players.LocalPlayer.Chatted:Connect(function(message)
    debugPrint("Message received from LocalPlayer: " .. message)

    if message == "The Nicene Creed" then -- Trigger phrase for sending Nicene Creed
        debugPrint("Trigger phrase detected: Sending Nicene Creed")
        
        local chunks = splitText(niceneCreedText, CHAT_LIMIT)
        sendChatMessages(chunks)

    elseif isValidBibleReference(message) then -- Check if it's a valid Bible reference (case-insensitive)
        debugPrint("Valid Bible reference detected: " .. message)

        local verseText = fetchBibleVerses(message)

        if verseText then
            local chunks = splitText(verseText, CHAT_LIMIT)
            sendChatMessages(chunks)
        else
            debugPrint("Verse text is nil or empty!", true)
        end

    else -- Handle other cases where neither condition matches
        debugPrint("Message did not match any trigger or valid reference pattern")
    end
end)

debugPrint("Client-side script loaded successfully")
