-- Toggle debug mode (set to true to enable debug/error messages, false to disable)
local debugMode = true

-- Function to handle debug and error messages
local function debugPrint(message, isError)
    if debugMode then
        (isError and warn or print)("[" .. (isError and "ERROR" or "DEBUG") .. "] " .. message)
    end
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

-- Constants
local CHAT_LIMIT = 200
local MESSAGE_INTERVAL = 2
local HTTP_URL = "https://bible-api.com/"

-- Detect supported HTTP request function
local httpRequest = syn and syn.request or http_request or request
if not httpRequest then error("HTTP request function not supported by this executor.") end

-- Function to fetch Bible verse(s) using an HTTP request
local function fetchBibleVerses(reference)
    local url = HTTP_URL .. string.gsub(reference, " ", "+") .. "?translation=kjv"
    debugPrint("Fetching Bible verses from URL: " .. url)
    
    local success, response = pcall(function()
        return httpRequest({ Url = url, Method = "GET" })
    end)

    if success and response and response.StatusCode == 200 then
        local decoded = HttpService:JSONDecode(response.Body)
        return decoded and decoded.text or "Verse not found."
    end
    debugPrint("Failed to fetch verses", true)
    return "Error fetching verses."
end

-- Function to split text into smaller chunks for Roblox chat
local function splitText(text)
    local chunks, len = {}, #text
    for i = 1, len, CHAT_LIMIT do
        table.insert(chunks, text:sub(i, i + CHAT_LIMIT - 1))
    end
    return chunks
end

-- Function to send messages in Roblox chat with intervals
local function sendChatMessages(messages)
    local textChannel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
    for i, message in ipairs(messages) do
        task.delay(MESSAGE_INTERVAL * (i - 1), function()
            debugPrint("Sending message chunk: " .. message)
            pcall(function()
                if textChannel then
                    textChannel:SendAsync(message)
                else
                    Players.LocalPlayer:Chat(message)
                end
            end)
        end)
    end
end

-- Nicene Creed text
local niceneCreedText = [[I believe in one God, Father Almighty, Creator of heaven and earth, and of all things visible and invisible.

And in one Lord Jesus Christ, the only-begotten Son of God, begotten of the Father before all ages; Light of Light, true God of true God, begotten, not created, of one essence with the Father through Whom all things were made. Who for us men and for our salvation came down from heaven and was incarnate of the Holy Spirit and the Virgin Mary and became man. He was crucified for us under Pontius Pilate, and suffered and was buried; And He rose on the third day, according to the Scriptures. He ascended into heaven and is seated at the right hand of the Father; And He will come again with glory to judge the living and dead. His kingdom shall have no end.

And in the Holy Spirit, the Lord, the Creator of life, Who proceeds from the Father, Who together with the Father and the Son is worshipped and glorified, Who spoke through the prophets.

In one, holy, catholic, and apostolic Church.

I confess one baptism for the forgiveness of sins.

I look for the resurrection of the dead, and the life of the age to come.

Amen.]]

-- Function to check if a message is a valid Bible reference
local function isValidBibleReference(message)
    return message:lower():match("^%d?%s?%w+%s%d+:%d+[-,%d]*$") ~= nil
end

-- Listen for chat messages from the local player
Players.LocalPlayer.Chatted:Connect(function(message)
    debugPrint("Message received: " .. message)
    if message == "The Nicene Creed" then
        sendChatMessages(splitText(niceneCreedText))
    elseif isValidBibleReference(message) then
        sendChatMessages(splitText(fetchBibleVerses(message)))
    else
        debugPrint("Unrecognized message")
    end
end)

debugPrint("Client-side script loaded successfully")
