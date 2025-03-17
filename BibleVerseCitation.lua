-- Toggle debug mode (set to true to enable debug/error messages, false to disable)
local debugMode = true

-- Constants
local CHAT_LIMIT = 200
local MESSAGE_INTERVAL = 1
local BIBLE_VERSION = "en-dra" -- Change this to switch versions
local BASE_URL = "https://cdn.jsdelivr.net/gh/wldeh/bible-api/bibles/"
local CACHE_FILE = "verseCache.json" -- File to store verse cache

-- Prevent duplicate execution by removing old script instance
if getgenv().BibleScript then
    getgenv().BibleScript:Disconnect()
    getgenv().BibleScript = nil
end

-- Dictionary of phrases and their corresponding text files
local phraseToFile = {
    ["The Nicene Creed"] = "TheNiceneCreed.txt",
    ["The Lords Prayer"] = "TheLordsPrayer.txt",
    ["A Prayer for All Times"] = "aPrayerForAllTimes.txt",
    -- Add more entries as needed
}

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

-- Function to handle debug and error messages
local function debugPrint(message, isError)
    if debugMode then
        (isError and warn or print)("[" .. (isError and "ERROR" or "DEBUG") .. "] " .. message)
    end
end

-- Detect supported HTTP request function
local httpRequest = syn and syn.request or http_request or request or http.request
if not httpRequest then
    error("HTTP request function not supported by this executor.")
    return
end

-- Cache for fetched verses to reduce API calls
local verseCache = {}
local cacheDirty = false -- Flag to track if cache needs saving

-- Function to save verse cache to file
local function saveCacheToFile()
    if not cacheDirty then return end
    
    -- Create a structured format for the cache
    local cacheData = {
        version = 1, -- Cache version for future upgrades
        lastUpdated = os.time(),
        verses = {}
    }
    
    -- Organize verses by book, chapter, and verse
    local organizedCache = {}
    for cacheKey, verseText in pairs(verseCache) do
        local version, book, chapter, verse = cacheKey:match("(.-)_(.-)_(.-)_(.-)")
        
        if version and book and chapter and verse then
            organizedCache[version] = organizedCache[version] or {}
            organizedCache[version][book] = organizedCache[version][book] or {}
            organizedCache[version][book][chapter] = organizedCache[version][book][chapter] or {}
            organizedCache[version][book][chapter][verse] = verseText
        end
    end
    
    cacheData.verses = organizedCache
    
    -- Save to file
    local success, errorMsg = pcall(function()
        writefile(CACHE_FILE, HttpService:JSONEncode(cacheData))
    end)
    
    if success then
        debugPrint("Cache saved successfully to " .. CACHE_FILE)
        cacheDirty = false
    else
        debugPrint("Failed to save cache: " .. (errorMsg or "Unknown error"), true)
    end
end

-- Function to load verse cache from file
local function loadCacheFromFile()
    -- First check if the file exists
    local success, fileExists = pcall(function()
        return isfile(CACHE_FILE)
    end)
    
    if not success or not fileExists then
        debugPrint("No cache file exists yet", false)
        return false
    end
    
    -- Try to read the file
    local success, fileContent = pcall(function()
        return readfile(CACHE_FILE)
    end)
    
    if not success or not fileContent then
        debugPrint("Failed to read cache file", true)
        return false
    end
    
    -- Try to decode the JSON
    local success, decoded = pcall(function()
        return HttpService:JSONDecode(fileContent)
    end)
    
    if not success or not decoded then
        debugPrint("Failed to parse cache JSON: " .. (decoded or "Invalid format"), true)
        -- If file exists but is corrupted, back it up and create a new one
        pcall(function()
            writefile(CACHE_FILE .. ".backup", fileContent)
            writefile(CACHE_FILE, HttpService:JSONEncode({
                version = 1,
                lastUpdated = os.time(),
                verses = {}
            }))
        end)
        return false
    end
    
    -- Convert the organized structure back to flat cache
    if decoded.verses then
        local cacheCount = 0
        for version, books in pairs(decoded.verses) do
            for book, chapters in pairs(books) do
                for chapter, verses in pairs(chapters) do
                    for verse, text in pairs(verses) do
                        local cacheKey = string.format("%s_%s_%s_%s", version, book, chapter, verse)
                        verseCache[cacheKey] = text
                        cacheCount = cacheCount + 1
                    end
                end
            end
        end
        
        debugPrint("Loaded " .. cacheCount .. " verses from cache file")
        return true
    end
    
    debugPrint("Invalid cache format", true)
    return false
end

-- Function to create a cache key for verses
local function createCacheKey(version, book, chapter, verse)
    return string.format("%s_%s_%s_%s", version, book, chapter, verse)
end

-- Function to fetch a single Bible verse with caching
local function fetchSingleVerse(version, book, chapter, verse)
    local cacheKey = createCacheKey(version, book, chapter, verse)
    
    -- Check cache first
    if verseCache[cacheKey] then
        debugPrint("Using cached verse: " .. cacheKey)
        return verseCache[cacheKey]
    end
    
    local url = string.format("%s%s/books/%s/chapters/%s/verses/%s.json", BASE_URL, version, book, chapter, verse)
    debugPrint("Fetching verse from URL: " .. url)
    
    local success, response = pcall(function()
        return httpRequest({ Url = url, Method = "GET" })
    end)
    
    if success and response and response.StatusCode == 200 then
        local decoded = HttpService:JSONDecode(response.Body)
        local verseText = decoded and decoded.text or "Verse not found."
        
        -- Cache the result
        verseCache[cacheKey] = verseText
        cacheDirty = true
        
        -- Save cache periodically
        if math.random(1, 10) == 1 then -- 10% chance to save cache on each fetch
            saveCacheToFile()
        end
        
        return verseText
    else
        debugPrint("Failed to fetch verse: " .. verse, true)
        return "Error fetching verse " .. verse .. "."
    end
end

-- Function to fetch an entire chapter when needed
local function fetchEntireChapter(version, book, chapter)
    local url = string.format("%s%s/books/%s/chapters/%s.json", BASE_URL, version, book, chapter)
    debugPrint("Fetching entire chapter from URL: " .. url)
    
    local success, response = pcall(function()
        return httpRequest({ Url = url, Method = "GET" })
    end)
    
    if success and response and response.StatusCode == 200 then
        local decoded = HttpService:JSONDecode(response.Body)
        if decoded and decoded.verses then
            -- Cache all verses in this chapter
            for verseNum, verseData in pairs(decoded.verses) do
                local cacheKey = createCacheKey(version, book, chapter, verseNum)
                verseCache[cacheKey] = verseData.text
                cacheDirty = true
            end
            
            -- Save cache after fetching an entire chapter
            saveCacheToFile()
            
            return decoded.verses
        end
    end
    
    debugPrint("Failed to fetch chapter: " .. book .. " " .. chapter, true)
    return nil
end

-- Function to fetch Bible verses (with optimized fetching)
local function fetchBibleVerses(book, chapter, verses)
    local collectedVerses = ""
    local verseList = {}
    local ranges = {}
    
    -- Parse verses into individual numbers and ranges
    for range in verses:gmatch("[%d,-]+") do
        if range:match("-") then
            local start, finish = range:match("(%d+)-(%d+)")
            if start and finish then
                table.insert(ranges, {tonumber(start), tonumber(finish)})
            end
        else
            for verse in range:gmatch("%d+") do
                table.insert(verseList, tonumber(verse))
            end
        end
    end
    
    -- Add all verses from ranges
    for _, range in ipairs(ranges) do
        local start, finish = range[1], range[2]
        if finish - start > 5 then
            -- If the range is large, fetch entire chapter instead
            local chapterVerses = fetchEntireChapter(BIBLE_VERSION, book, chapter)
            if chapterVerses then
                for i = start, finish do
                    if chapterVerses[tostring(i)] then
                        table.insert(verseList, i)
                    end
                end
            else
                -- Fallback to individual verse fetching
                for i = start, finish do
                    table.insert(verseList, i)
                end
            end
        else
            -- Small range, add individual verses
            for i = start, finish do
                table.insert(verseList, i)
            end
        end
    end
    
    -- Sort verse numbers for sequential reading
    table.sort(verseList)
    
    -- Fetch each verse (without adding verse numbers)
    for _, verse in ipairs(verseList) do
        local verseText = fetchSingleVerse(BIBLE_VERSION, book, chapter, verse)
        -- Append verse text without verse number prefix
        collectedVerses = collectedVerses .. verseText .. " "
    end
    
    return collectedVerses
end

-- Function to smartly split text into smaller chunks for Roblox chat
local function splitText(text)
    local chunks = {}
    
    -- If text is already short enough, return it as is
    if #text <= CHAT_LIMIT then
        return {text}
    end
    
    -- Try to split at sentence boundaries
    local currentChunk = ""
    for sentence in text:gmatch("([^.!?]+[.!?])") do
        sentence = sentence:gsub("^%s+", "")  -- Remove leading spaces
        
        if #currentChunk + #sentence > CHAT_LIMIT then
            if #currentChunk > 0 then
                table.insert(chunks, currentChunk)
            end
            
            -- If a single sentence is too long, split it
            if #sentence > CHAT_LIMIT then
                for i = 1, #sentence, CHAT_LIMIT do
                    table.insert(chunks, sentence:sub(i, i + CHAT_LIMIT - 1))
                end
            else
                currentChunk = sentence
            end
        else
            currentChunk = currentChunk .. sentence
        end
    end
    
    -- Add any remaining text
    if #currentChunk > 0 then
        table.insert(chunks, currentChunk)
    end
    
    -- Fallback to character-based splitting if no chunks were created
    if #chunks == 0 then
        for i = 1, #text, CHAT_LIMIT do
            table.insert(chunks, text:sub(i, i + CHAT_LIMIT - 1))
        end
    end
    
    return chunks
end

-- Function to send messages in Roblox chat with intervals
local function sendChatMessages(messages)
    -- Detect the appropriate chat system
    local textChannel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
    local localPlayer = Players.LocalPlayer
    
    if not localPlayer then
        debugPrint("LocalPlayer not found", true)
        return
    end
    
    -- Queue messages for sending
    for i, message in ipairs(messages) do
        task.delay(MESSAGE_INTERVAL * (i - 1), function()
            debugPrint("Sending message chunk " .. i .. "/" .. #messages)
            pcall(function()
                if textChannel then
                    textChannel:SendAsync(message)
                else
                    localPlayer:Chat(message)
                end
            end)
        end)
    end
end

-- Function to check if a message is a valid Bible reference
local function parseReference(message)
    -- Enhanced regex for Bible references
    local book, chapter, verses = message:match("([%w%s]+)%s+(%d+):([%d,-]+)")
    
    if book and chapter and verses then
        return {
            book = book:lower():gsub("%s+", ""),
            chapter = chapter,
            verses = verses
        }
    end
    
    return nil
end

-- Function to send text file content as chat message
local function sendTextFileContent(fileName)
    -- Check if file exists first
    local fileExists = pcall(function() return isfile(fileName) end)
    if not fileExists then
        debugPrint("File does not exist: " .. fileName, true)
        return false
    end

    local success, file = pcall(readfile, fileName)
    if success and file then
        sendChatMessages(splitText(file))
        return true
    else
        debugPrint("Failed to read file: " .. fileName, true)
        return false
    end
end

-- Function to process a chat message
local function processChatMessage(message)
    debugPrint("Processing message: " .. message)
    
    -- Check for specific phrases first
    for phrase, fileName in pairs(phraseToFile) do
        if message:lower():find(phrase:lower()) then
            debugPrint("Matched phrase: " .. phrase)
            return sendTextFileContent(fileName)
        end
    end
    
    -- Check for Bible references
    local reference = parseReference(message)
    if reference then
        debugPrint("Found Bible reference: " .. reference.book .. " " .. reference.chapter .. ":" .. reference.verses)
        local verses = fetchBibleVerses(reference.book, reference.chapter, reference.verses)
        if verses and #verses > 0 then
            sendChatMessages(splitText(verses))
            return true
        end
    end
    
    return false
end

-- Function to get cache statistics
local function getCacheStats()
    local versions = {}
    local books = {}
    local totalVerses = 0
    
    for cacheKey in pairs(verseCache) do
        local version, book = cacheKey:match("(.-)_(.-)_")
        if version and book then
            versions[version] = (versions[version] or 0) + 1
            books[book] = (books[book] or 0) + 1
            totalVerses = totalVerses + 1
        end
    end
    
    -- Sort books by number of verses
    local sortedBooks = {}
    for book, count in pairs(books) do
        table.insert(sortedBooks, {name = book, count = count})
    end
    
    table.sort(sortedBooks, function(a, b) return a.count > b.count end)
    
    return {
        totalVerses = totalVerses,
        uniqueVersions = #versions,
        uniqueBooks = #books,
        versions = versions,
        books = books,
        topBooks = sortedBooks
    }
end

-- Handle special commands
local function handleSpecialCommands(message)
    if message:lower() == "!biblesavecache" then
        saveCacheToFile()
        local stats = getCacheStats()
        return "Cache saved with " .. stats.totalVerses .. " verses from " .. stats.uniqueBooks .. " books"
    elseif message:lower() == "!biblecachestats" then
        local stats = getCacheStats()
        local bookList = ""
        local count = 0
        for _, bookData in ipairs(stats.topBooks) do
            bookList = bookList .. bookData.name .. "(" .. bookData.count .. "), "
            count = count + 1
            if count >= 5 then 
                bookList = bookList .. "..."
                break
            end
        end
        return "Cache stats: " .. stats.totalVerses .. " total verses from " .. stats.uniqueBooks .. " books. Top books: " .. bookList
    elseif message:lower() == "!bibleclearcache" then
        verseCache = {}
        cacheDirty = true
        saveCacheToFile()
        return "Bible verse cache cleared"
    elseif message:lower() == "!biblefixcache" then
        -- Create a new empty cache file
        pcall(function()
            writefile(CACHE_FILE, HttpService:JSONEncode({
                version = 1,
                lastUpdated = os.time(),
                verses = {}
            }))
        end)
        verseCache = {}
        cacheDirty = false
        return "Bible verse cache file has been reset"
    end
    
    return nil
end

-- Function to check if cache file exists and is valid
local function validateCacheFile()
    -- Check if file exists
    local exists = pcall(function() return isfile(CACHE_FILE) end)
    if not exists then
        debugPrint("Cache file doesn't exist, creating new one")
        writefile(CACHE_FILE, HttpService:JSONEncode({
            version = 1,
            lastUpdated = os.time(),
            verses = {}
        }))
        return true
    end
    
    -- Check if file is valid JSON
    local valid, content = pcall(function() 
        local data = readfile(CACHE_FILE)
        return HttpService:JSONDecode(data) ~= nil, data
    end)
    
    if not valid then
        debugPrint("Cache file is corrupted, creating backup and new file", true)
        pcall(function()
            writefile(CACHE_FILE .. ".backup", content or "")
            writefile(CACHE_FILE, HttpService:JSONEncode({
                version = 1,
                lastUpdated = os.time(),
                verses = {}
            }))
        end)
    end
    
    return valid
end

-- Function to manage the verse cache
local function setupCacheManagement()
    -- First validate the cache file
    validateCacheFile()
    
    -- Then try to load the cache
    local success = pcall(function()
        loadCacheFromFile()
    end)
    
    if not success then
        debugPrint("Failed to load cache, using empty cache", true)
        verseCache = {}
    end
    
    -- Setup periodic cache saving
    task.spawn(function()
        while true do
            task.wait(300) -- Save every 5 minutes if dirty
            if cacheDirty then
                saveCacheToFile()
            end
        end
    end)
    
    -- Setup cache cleanup (limit size)
    task.spawn(function()
        while true do
            task.wait(1800) -- Check every 30 minutes
            
            local stats = getCacheStats()
            debugPrint("Cache stats: " .. stats.totalVerses .. " verses from " .. stats.uniqueBooks .. " books")
            
            -- If cache is too large (more than 5000 verses), trim it
            if stats.totalVerses > 5000 then
                local toRemove = stats.totalVerses - 5000
                local removed = 0
                
                -- Start removing random entries
                for cacheKey in pairs(verseCache) do
                    verseCache[cacheKey] = nil
                    removed = removed + 1
                    if removed >= toRemove then break end
                    if removed % 100 == 0 then task.wait() end
                end
                
                debugPrint("Trimmed cache: removed " .. removed .. " entries")
                cacheDirty = true
                saveCacheToFile()
            end
        end
    end)
end

-- Main initialization
local function initialize()
    -- Verify the player is available
    local localPlayer = Players.LocalPlayer
    if not localPlayer then
        debugPrint("Waiting for LocalPlayer...", true)
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        localPlayer = Players.LocalPlayer
    end
    
    -- Setup cache management with error handling
    pcall(function()
        setupCacheManagement()
    end)
    
    -- Listen for chat messages
    getgenv().BibleScript = localPlayer.Chatted:Connect(function(message)
        -- Check for special commands first
        local commandResponse = handleSpecialCommands(message)
        if commandResponse then
            -- Send command response as a chat message
            sendChatMessages({commandResponse})
            return
        end
        
        -- Process normal message
        processChatMessage(message)
    end)
    
    debugPrint("Bible Citation script loaded successfully")
    
    -- Show initial cache statistics
    pcall(function()
        local stats = getCacheStats()
        debugPrint("Loaded with " .. stats.totalVerses .. " verses in cache")
    end)
end

-- Start the script with error handling
pcall(function()
    initialize()
end)
