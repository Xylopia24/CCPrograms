--[[
    AudioManager API
    Version: 3.0.0
    Created By: Xylopia (Vinyl)

    A comprehensive audio management API for ComputerCraft speakers.

    Features:
    - Multi-speaker stereo support
    - Advanced playlist management
    - Volume control with fading effects
    - Crossfading between tracks
    - Comprehensive event system
    - Optional TaskMaster integration for advanced parallelism
]]

-----------------------------------------------------------
-- Core Module Structure
-----------------------------------------------------------

local AudioManager = {
    VERSION = "3.0.0",
    DEBUG = false,

    -- TaskMaster integration options
    TASK_MASTER_ENABLED = false, -- Default to disabled
    TASK_MASTER_PATH = nil,      -- Default path (nil means try common paths)

    -- Publicly accessible EventType enum
    EventType = {
        SONG_START = "SONG_START",
        SONG_END = "SONG_END",
        PLAYLIST_START = "PLAYLIST_START",
        PLAYLIST_END = "PLAYLIST_END",
        VOLUME_CHANGE = "VOLUME_CHANGE",
        ERROR = "ERROR",
        MUTE_CHANGE = "MUTE_CHANGE",
        PLAYLIST_LOOP = "PLAYLIST_LOOP",
        CROSSFADE_START = "CROSSFADE_START",
        CROSSFADE_END = "CROSSFADE_END"
    }
}

-----------------------------------------------------------
-- TaskMaster Integration
-----------------------------------------------------------

-- TaskMaster integration state
local TaskMasterIntegration = {
    available = false,
    instance = nil,
    loadAttempted = false
}

-- Try to load TaskMaster from various possible paths
local function tryLoadTaskMaster()
    if TaskMasterIntegration.loadAttempted then
        return TaskMasterIntegration.available
    end

    TaskMasterIntegration.loadAttempted = true

    local paths = {
        AudioManager.TASK_MASTER_PATH, -- User-specified path first
        "taskmaster",
        "TaskMaster",
        "Taskmaster",
        "core.libs.system.TaskMaster"
    }

    for _, path in ipairs(paths) do
        if path then -- Skip nil paths
            local success, result = pcall(require, path)
            if success and result then
                TaskMasterIntegration.available = true
                TaskMasterIntegration.instance = result() -- Create a task loop

                if AudioManager.DEBUG then
                    print("[AudioManager] TaskMaster loaded successfully from " .. path)
                end

                return true
            end
        end
    end

    if AudioManager.DEBUG then
        print("[AudioManager] TaskMaster not found or failed to load")
    end

    return false
end

-----------------------------------------------------------
-- Internal State Management
-----------------------------------------------------------

-- Central state store
local State = {
    initialized = false,
    playback = {
        currentSong = nil,
        songName = nil,
        startTime = nil,
        duration = nil,
        position = 0,
        isPlaying = false,
        playbackLock = false
    },
    volume = {
        level = 1.0,
        lastLevel = 1.0,
        isMuted = false,
        fade = {
            active = false,
            timer = nil,
            target = nil,
            stepSize = 0.05,
            interval = 0.1
        }
    },
    playlist = {
        current = {},
        name = nil,
        index = 1,
        isLooping = true,
        isShuffle = false,
        history = {},
        queue = {}
    },
    effects = {
        crossfade = {
            duration = 2,
            isEnabled = true,
            active = false
        }
    }
}

-- Speaker management system
local SpeakerSystem = {
    devices = {},
    primary = nil,
    stereo = {
        enabled = false,
        left = nil,
        right = nil,
        balance = {
            left = 1.0,
            right = 1.0
        }
    }
}

-- Configuration defaults
local Config = {
    defaultVolume = 1.0,
    defaultCrossfade = 2.0,
    leftSpeaker = nil,
    rightSpeaker = nil,
    maxRange = 16,
    logErrors = true
}

-- Event system
local EventSystem = {
    listeners = {},

    -- Register an event listener
    addListener = function(eventType, callback)
        if not EventSystem.listeners[eventType] then
            EventSystem.listeners[eventType] = {}
        end
        table.insert(EventSystem.listeners[eventType], callback)
        return callback -- Return for easier removal
    end,

    -- Remove a specific listener
    removeListener = function(eventType, callback)
        if not EventSystem.listeners[eventType] then return false end

        for i, cb in ipairs(EventSystem.listeners[eventType]) do
            if cb == callback then
                table.remove(EventSystem.listeners[eventType], i)
                return true
            end
        end
        return false
    end,

    -- Trigger an event with data
    trigger = function(eventType, data)
        if not EventSystem.listeners[eventType] then return end

        for _, callback in ipairs(EventSystem.listeners[eventType]) do
            local success, err = pcall(callback, data)
            if not success and Config.logErrors then
                printError(string.format("Error in %s event handler: %s", eventType, err))
            end
        end
    end
}

-----------------------------------------------------------
-- Utility Functions
-----------------------------------------------------------

-- Advanced debug logging
local function debugLog(...)
    if not AudioManager.DEBUG then return end

    local args = { ... }
    local output = "[AudioManager] "

    for i, arg in ipairs(args) do
        if type(arg) == "table" then
            output = output .. textutils.serialize(arg) .. " "
        else
            output = output .. tostring(arg) .. " "
        end
    end

    print(output)
end

-- Error logging
local function logError(message, source)
    if not Config.logErrors then return end

    local errorMsg = "[AudioManager Error"
    if source then errorMsg = errorMsg .. " in " .. source end
    errorMsg = errorMsg .. "] " .. message

    printError(errorMsg)

    -- Trigger error event
    EventSystem.trigger(AudioManager.EventType.ERROR, {
        message = message,
        source = source
    })
end

-- Get a readable track name from song ID
local function getFormattedTrackName(songName)
    if not songName then return "Unknown" end

    -- Check if in current playlist first
    if State.playlist.current and #State.playlist.current > 0 then
        for _, track in ipairs(State.playlist.current) do
            if track.song == songName and track.name then
                return track.name
            end
        end
    end

    -- Extract from namespace:path format
    local namespace, path = songName:match("([^:]+):(.+)")
    if namespace and path then
        -- Format nicely with capital first letter and spaces
        path = path:gsub("%.", " "):gsub("_", " ")
        return path:gsub("(%l)(%w*)", function(first, rest)
            return first:upper() .. rest
        end)
    end

    return songName
end

-- Play a sound on all speakers with proper balancing
local function playSoundOnSpeakers(songName, volume)
    if not volume then volume = State.volume.level end
    if State.volume.isMuted then volume = 0 end

    -- No speakers available
    if not SpeakerSystem.primary then
        logError("No speakers available", "playSoundOnSpeakers")
        return false
    end

    -- Stop all speakers first for clean playback
    for _, speaker in pairs(SpeakerSystem.devices) do
        pcall(function() speaker.device.stop() end)
    end

    -- Small delay to ensure clean transition
    os.sleep(0.05)

    local success = true

    -- Play on all speakers
    for name, speaker in pairs(SpeakerSystem.devices) do
        local speakerVolume = volume

        -- Apply stereo balancing if enabled
        if SpeakerSystem.stereo.enabled then
            if name == SpeakerSystem.stereo.left then
                speakerVolume = speakerVolume * SpeakerSystem.stereo.balance.left
            elseif name == SpeakerSystem.stereo.right then
                speakerVolume = speakerVolume * SpeakerSystem.stereo.balance.right
            end
        end

        -- Ensure volume is in valid range
        speakerVolume = math.max(0, math.min(1, speakerVolume))

        local ok = pcall(function()
            speaker.device.playSound(songName, speakerVolume)
        end)

        if not ok then
            logError("Failed to play sound: " .. songName, "playSoundOnSpeakers")
        end

        success = success and ok
    end

    return success
end

-----------------------------------------------------------
-- Core Audio Functions
-----------------------------------------------------------

-- Initialize the AudioManager with configuration options
function AudioManager.initialize(options)
    options = options or {}

    -- Update configuration
    Config.defaultVolume = options.volume or Config.defaultVolume
    Config.defaultCrossfade = options.crossfadeDuration or Config.defaultCrossfade
    Config.leftSpeaker = options.leftSpeaker or Config.leftSpeaker
    Config.rightSpeaker = options.rightSpeaker or Config.rightSpeaker
    Config.logErrors = options.logErrors ~= false

    -- TaskMaster integration options
    AudioManager.TASK_MASTER_ENABLED = options.enableTaskMaster == true
    AudioManager.TASK_MASTER_PATH = options.taskMasterPath

    -- Try loading TaskMaster if enabled
    if AudioManager.TASK_MASTER_ENABLED then
        tryLoadTaskMaster()
    end

    -- Reset state
    State.initialized = false
    State.volume.level = Config.defaultVolume
    State.volume.lastLevel = Config.defaultVolume
    State.volume.isMuted = false
    State.effects.crossfade.duration = Config.defaultCrossfade
    State.effects.crossfade.isEnabled = options.crossfade ~= false
    State.playlist.isLooping = options.isLooping ~= false
    State.playlist.isShuffle = false

    -- Reset playback state
    State.playback = {
        currentSong = nil,
        songName = nil,
        startTime = nil,
        duration = nil,
        position = 0,
        isPlaying = false,
        playbackLock = false
    }

    -- Reset speaker system
    SpeakerSystem.devices = {}
    SpeakerSystem.primary = nil
    SpeakerSystem.stereo.enabled = false
    SpeakerSystem.stereo.left = nil
    SpeakerSystem.stereo.right = nil

    -- Find all speakers
    local speakerList = { peripheral.find("speaker") }

    if #speakerList == 0 then
        logError("No speakers found", "initialize")
        return false
    end

    -- Register all speakers
    for _, speaker in ipairs(speakerList) do
        local name = peripheral.getName(speaker)

        SpeakerSystem.devices[name] = {
            device = speaker,
            volume = Config.defaultVolume,
            isLeft = name == Config.leftSpeaker,
            isRight = name == Config.rightSpeaker
        }

        -- Set primary speaker
        if not SpeakerSystem.primary then
            SpeakerSystem.primary = name
        end

        -- Configure stereo if available
        if name == Config.leftSpeaker then
            SpeakerSystem.stereo.left = name
        elseif name == Config.rightSpeaker then
            SpeakerSystem.stereo.right = name
        end
    end

    -- Enable stereo if we have both left and right speakers
    SpeakerSystem.stereo.enabled =
        SpeakerSystem.stereo.left ~= nil and
        SpeakerSystem.stereo.right ~= nil

    State.initialized = true

    debugLog("Initialized AudioManager with", #speakerList, "speakers",
        SpeakerSystem.stereo.enabled and "(Stereo enabled)" or "")

    return true
end

-- Play a song with an optional duration
function AudioManager.playSong(songName, duration)
    if not State.initialized then
        logError("AudioManager not initialized", "playSong")
        return false
    end

    -- Prevent playback during certain operations
    if State.playback.playbackLock then
        debugLog("Playback locked, ignoring playSong request")
        return false
    end

    -- Play the song on all speakers
    local success = playSoundOnSpeakers(songName, State.volume.level)

    if not success then
        return false
    end

    -- Update playback state
    State.playback.currentSong = songName
    State.playback.songName = getFormattedTrackName(songName)
    State.playback.startTime = os.epoch("local") / 1000
    State.playback.duration = duration or 0
    State.playback.position = 0
    State.playback.isPlaying = true

    -- Trigger song start event
    EventSystem.trigger(AudioManager.EventType.SONG_START, {
        song = songName,
        name = State.playback.songName,
        duration = duration
    })

    -- Start automatic playback monitoring if duration is set
    if duration and duration > 0 then
        -- Create a separate thread to monitor playback
        parallel.waitForAny(function()
            local endTime = State.playback.startTime + duration
            while os.epoch("local") / 1000 < endTime do
                if not State.playback.isPlaying or State.playback.currentSong ~= songName then
                    -- Playback was stopped or changed
                    return
                end
                os.sleep(0.5) -- Check every half second
            end

            -- Song finished, play next in playlist if available
            if State.playback.currentSong == songName then
                AudioManager.playNextSong()
            end
        end)
    end

    return true
end

-- Play a song with TaskMaster for background monitoring (if available)
function AudioManager.playSongAsync(songName, duration)
    -- First check if we can use TaskMaster
    if not AudioManager.TASK_MASTER_ENABLED or not TaskMasterIntegration.available then
        -- Fall back to normal playback
        return AudioManager.playSong(songName, duration)
    end

    if not State.initialized then
        logError("AudioManager not initialized", "playSongAsync")
        return false
    end

    -- Prevent playback during certain operations
    if State.playback.playbackLock then
        debugLog("Playback locked, ignoring playSongAsync request")
        return false
    end

    -- Play the song normally (no duration monitoring)
    local success = playSoundOnSpeakers(songName, State.volume.level)

    if not success then
        return false
    end

    -- Update playback state
    State.playback.currentSong = songName
    State.playback.songName = getFormattedTrackName(songName)
    State.playback.startTime = os.epoch("local") / 1000
    State.playback.duration = duration or 0
    State.playback.position = 0
    State.playback.isPlaying = true

    -- Trigger song start event
    EventSystem.trigger(AudioManager.EventType.SONG_START, {
        song = songName,
        name = State.playback.songName,
        duration = duration
    })

    -- Use TaskMaster to monitor the playback duration
    if duration and duration > 0 then
        TaskMasterIntegration.instance:addTimer(duration, function()
            -- Check if this is still the active song
            if State.playback.isPlaying and State.playback.currentSong == songName then
                AudioManager.playNextSong()
            end
            return 0 -- Don't repeat
        end)
    end

    return true
end

-- Stop all playback
function AudioManager.stopAll()
    if not State.initialized then return false end

    -- Stop all active fade operations
    if State.volume.fade.timer then
        os.cancelTimer(State.volume.fade.timer)
        State.volume.fade.timer = nil
        State.volume.fade.active = false
    end

    -- Stop all speakers
    for name, speaker in pairs(SpeakerSystem.devices) do
        pcall(function() speaker.device.stop() end)
    end

    -- Save song info for event before clearing
    local previousSong = State.playback.currentSong
    local previousName = State.playback.songName

    -- Reset playback state
    State.playback.currentSong = nil
    State.playback.songName = nil
    State.playback.startTime = nil
    State.playback.duration = nil
    State.playback.position = 0
    State.playback.isPlaying = false

    -- Only trigger event if we were playing something
    if previousSong then
        EventSystem.trigger(AudioManager.EventType.SONG_END, {
            song = previousSong,
            name = previousName,
            completed = false
        })
    end

    return true
end

-- Crossfade to a new song
function AudioManager.crossfade(newSong, duration)
    if not State.initialized then
        logError("AudioManager not initialized", "crossfade")
        return false
    end

    duration = duration or State.effects.crossfade.duration
    local currentSong = State.playback.currentSong

    if not currentSong then
        -- No song playing, just play the new one
        return AudioManager.playSong(newSong, duration)
    end

    -- Set playback lock to prevent interference during crossfade
    State.playback.playbackLock = true
    State.effects.crossfade.active = true

    -- Trigger crossfade start event
    EventSystem.trigger(AudioManager.EventType.CROSSFADE_START, {
        from = currentSong,
        fromName = State.playback.songName,
        to = newSong,
        toName = getFormattedTrackName(newSong),
        duration = duration
    })

    -- Store original volume
    local originalVolume = State.volume.level

    -- Calculate fade steps
    local steps = math.max(5, math.floor(duration / 0.1)) -- At least 5 steps
    local stepDuration = duration / steps
    local volumeStep = originalVolume / steps

    -- Create crossfade operation in separate thread
    parallel.waitForAll(
    -- Fade out current song
        function()
            local currentVolume = originalVolume
            for i = 1, steps do
                currentVolume = currentVolume - volumeStep
                if currentVolume < 0 then currentVolume = 0 end

                -- Get all speakers by their current config
                for name, speaker in pairs(SpeakerSystem.devices) do
                    pcall(function()
                        local speakerVolume = currentVolume

                        -- Apply stereo balancing if enabled
                        if SpeakerSystem.stereo.enabled then
                            if name == SpeakerSystem.stereo.left then
                                speakerVolume = speakerVolume * SpeakerSystem.stereo.balance.left
                            elseif name == SpeakerSystem.stereo.right then
                                speakerVolume = speakerVolume * SpeakerSystem.stereo.balance.right
                            end
                        end

                        speaker.device.playSound(currentSong, speakerVolume)
                    end)
                end

                os.sleep(stepDuration)
            end

            -- Stop all speakers
            for _, speaker in pairs(SpeakerSystem.devices) do
                pcall(function() speaker.device.stop() end)
            end
        end,

        -- Fade in new song
        function()
            -- Wait briefly for fade out to start
            os.sleep(stepDuration * 1.5)

            -- Start new sound at 0 volume
            for name, speaker in pairs(SpeakerSystem.devices) do
                pcall(function()
                    speaker.device.playSound(newSong, 0)
                end)
            end

            -- Small pause to ensure clean start
            os.sleep(stepDuration)

            -- Fade in
            local currentVolume = 0
            for i = 1, steps do
                currentVolume = currentVolume + volumeStep
                if currentVolume > originalVolume then
                    currentVolume = originalVolume
                end

                -- Play on all speakers with proper balancing
                for name, speaker in pairs(SpeakerSystem.devices) do
                    pcall(function()
                        local speakerVolume = currentVolume

                        -- Apply stereo balancing if enabled
                        if SpeakerSystem.stereo.enabled then
                            if name == SpeakerSystem.stereo.left then
                                speakerVolume = speakerVolume * SpeakerSystem.stereo.balance.left
                            elseif name == SpeakerSystem.stereo.right then
                                speakerVolume = speakerVolume * SpeakerSystem.stereo.balance.right
                            end
                        end

                        speaker.device.playSound(newSong, speakerVolume)
                    end)
                end

                os.sleep(stepDuration)
            end
        end
    )

    -- Update state after crossfade
    State.playback.currentSong = newSong
    State.playback.songName = getFormattedTrackName(newSong)
    State.playback.startTime = os.epoch("local") / 1000
    State.playback.isPlaying = true

    -- Release playback lock
    State.playback.playbackLock = false
    State.effects.crossfade.active = false

    -- Trigger event
    EventSystem.trigger(AudioManager.EventType.CROSSFADE_END, {
        song = newSong,
        name = State.playback.songName
    })

    return true
end

-- Crossfade to a new song using TaskMaster (if available)
function AudioManager.crossfadeAsync(newSong, duration)
    -- First check if we can use TaskMaster
    if not AudioManager.TASK_MASTER_ENABLED or not TaskMasterIntegration.available then
        -- Fall back to normal crossfade
        return AudioManager.crossfade(newSong, duration)
    end

    if not State.initialized then
        logError("AudioManager not initialized", "crossfadeAsync")
        return false
    end

    duration = duration or State.effects.crossfade.duration
    local currentSong = State.playback.currentSong

    if not currentSong then
        -- No song playing, just play the new one
        return AudioManager.playSongAsync(newSong, duration)
    end

    -- Set playback lock to prevent interference during crossfade
    State.playback.playbackLock = true
    State.effects.crossfade.active = true

    -- Trigger crossfade start event
    EventSystem.trigger(AudioManager.EventType.CROSSFADE_START, {
        from = currentSong,
        fromName = State.playback.songName,
        to = newSong,
        toName = getFormattedTrackName(newSong),
        duration = duration
    })

    -- Store original volume
    local originalVolume = State.volume.level

    -- Calculate fade steps
    local steps = math.max(5, math.floor(duration / 0.1)) -- At least 5 steps
    local stepDuration = duration / steps
    local volumeStep = originalVolume / steps

    -- Use TaskMaster for the fade operation
    local taskLoop = TaskMasterIntegration.instance

    -- Create a promise for the crossfade
    taskLoop.Promise.new(function(resolve, reject)
        -- Fade out current song
        local currentVolume = originalVolume

        taskLoop:addTask(function()
            for i = 1, steps do
                currentVolume = currentVolume - volumeStep
                if currentVolume < 0 then currentVolume = 0 end

                -- Play on all speakers with proper balancing
                for name, speaker in pairs(SpeakerSystem.devices) do
                    pcall(function()
                        local speakerVolume = currentVolume

                        -- Apply stereo balancing if enabled
                        if SpeakerSystem.stereo.enabled then
                            if name == SpeakerSystem.stereo.left then
                                speakerVolume = speakerVolume * SpeakerSystem.stereo.balance.left
                            elseif name == SpeakerSystem.stereo.right then
                                speakerVolume = speakerVolume * SpeakerSystem.stereo.balance.right
                            end
                        end

                        speaker.device.playSound(currentSong, speakerVolume)
                    end)
                end

                os.sleep(stepDuration)
            end

            -- Stop old song on all speakers
            for _, speaker in pairs(SpeakerSystem.devices) do
                pcall(function() speaker.device.stop() end)
            end
        end)

        -- Fade in new song (with delay to allow first fade to start)
        taskLoop:addTask(function()
            os.sleep(stepDuration * 1.5)

            -- Start new sound at 0 volume
            for name, speaker in pairs(SpeakerSystem.devices) do
                pcall(function() speaker.device.playSound(newSong, 0) end)
            end

            -- Small pause to ensure clean start
            os.sleep(stepDuration)

            -- Fade in
            local newVolume = 0
            for i = 1, steps do
                newVolume = newVolume + volumeStep
                if newVolume > originalVolume then
                    newVolume = originalVolume
                end

                -- Play on all speakers with proper balancing
                for name, speaker in pairs(SpeakerSystem.devices) do
                    pcall(function()
                        local speakerVolume = newVolume

                        -- Apply stereo balancing if enabled
                        if SpeakerSystem.stereo.enabled then
                            if name == SpeakerSystem.stereo.left then
                                speakerVolume = speakerVolume * SpeakerSystem.stereo.balance.left
                            elseif name == SpeakerSystem.stereo.right then
                                speakerVolume = speakerVolume * SpeakerSystem.stereo.balance.right
                            end
                        end

                        speaker.device.playSound(newSong, speakerVolume)
                    end)
                end

                os.sleep(stepDuration)
            end

            -- Update state after crossfade
            State.playback.currentSong = newSong
            State.playback.songName = getFormattedTrackName(newSong)
            State.playback.startTime = os.epoch("local") / 1000
            State.playback.isPlaying = true

            -- Release playback lock
            State.playback.playbackLock = false
            State.effects.crossfade.active = false

            -- Trigger event
            EventSystem.trigger(AudioManager.EventType.CROSSFADE_END, {
                song = newSong,
                name = State.playback.songName
            })

            -- Resolve the promise
            resolve(newSong)
        end)
    end)

    return true
end

-----------------------------------------------------------
-- Volume Control Functions
-----------------------------------------------------------

-- Set the master volume level
function AudioManager.setVolume(newVolume)
    -- Validate volume range
    newVolume = math.max(0, math.min(1, newVolume))

    -- Update state
    State.volume.level = newVolume

    -- Apply to current playback if active
    if State.playback.currentSong then
        playSoundOnSpeakers(State.playback.currentSong, newVolume)
    end

    -- Trigger event
    EventSystem.trigger(AudioManager.EventType.VOLUME_CHANGE, {
        volume = newVolume,
        isMuted = State.volume.isMuted
    })

    return true
end

-- Get the current volume level
function AudioManager.getVolume()
    return State.volume.level
end

-- Gradually fade volume to target level
function AudioManager.fadeVolume(targetVolume, duration)
    if not State.initialized then return false end

    -- Cancel any existing fade operation
    if State.volume.fade.active then
        if State.volume.fade.timer then
            os.cancelTimer(State.volume.fade.timer)
        end
        State.volume.fade.active = false
        State.volume.fade.timer = nil
    end

    -- Validate target volume
    targetVolume = math.max(0, math.min(1, targetVolume))
    duration = duration or 2 -- Default to 2 seconds

    -- Calculate fade parameters
    local initialVolume = State.volume.level
    local steps = math.max(5, math.floor(duration / 0.1)) -- At least 5 steps
    local volumeStep = (targetVolume - initialVolume) / steps
    local stepDuration = duration / steps

    -- Start fade operation in separate thread
    State.volume.fade.active = true

    parallel.waitForAll(function()
        local currentVolume = initialVolume

        for i = 1, steps do
            currentVolume = currentVolume + volumeStep

            -- Clamp to valid range
            currentVolume = math.max(0, math.min(1, currentVolume))

            -- Apply volume change
            State.volume.level = currentVolume

            -- Update playback if active
            if State.playback.currentSong then
                playSoundOnSpeakers(State.playback.currentSong, currentVolume)
            end

            -- Wait for next step
            os.sleep(stepDuration)
        end

        -- Ensure exact target volume at end
        State.volume.level = targetVolume

        -- Final playback update
        if State.playback.currentSong then
            playSoundOnSpeakers(State.playback.currentSong, targetVolume)
        end

        -- Trigger event
        EventSystem.trigger(AudioManager.EventType.VOLUME_CHANGE, {
            volume = targetVolume,
            isMuted = State.volume.isMuted
        })

        -- Clear fade state
        State.volume.fade.active = false
    end)

    return true
end

-- Fade volume using TaskMaster (if available)
function AudioManager.fadeVolumeAsync(targetVolume, duration)
    -- Check if we can use TaskMaster
    if not AudioManager.TASK_MASTER_ENABLED or not TaskMasterIntegration.available then
        -- Fall back to normal fade
        return AudioManager.fadeVolume(targetVolume, duration)
    end

    if not State.initialized then return false end

    -- Cancel any existing fade operation
    if State.volume.fade.active then
        if State.volume.fade.timer then
            os.cancelTimer(State.volume.fade.timer)
        end
        State.volume.fade.active = false
        State.volume.fade.timer = nil
    end

    -- Validate target volume
    targetVolume = math.max(0, math.min(1, targetVolume))
    duration = duration or 2 -- Default to 2 seconds

    -- Calculate fade parameters
    local initialVolume = State.volume.level
    local steps = math.max(5, math.floor(duration / 0.1)) -- At least 5 steps
    local volumeStep = (targetVolume - initialVolume) / steps
    local stepDuration = duration / steps

    -- Start fade operation using TaskMaster
    State.volume.fade.active = true

    -- Create promise for the fade operation
    return TaskMasterIntegration.instance.Promise.new(function(resolve, reject)
        TaskMasterIntegration.instance:addTask(function()
            local currentVolume = initialVolume

            for i = 1, steps do
                currentVolume = currentVolume + volumeStep

                -- Clamp to valid range
                currentVolume = math.max(0, math.min(1, currentVolume))

                -- Apply volume change
                State.volume.level = currentVolume

                -- Update playback if active
                if State.playback.currentSong then
                    playSoundOnSpeakers(State.playback.currentSong, currentVolume)
                end

                -- Wait for next step
                os.sleep(stepDuration)
            end

            -- Ensure exact target volume at end
            State.volume.level = targetVolume

            -- Final playback update
            if State.playback.currentSong then
                playSoundOnSpeakers(State.playback.currentSong, targetVolume)
            end

            -- Trigger event
            EventSystem.trigger(AudioManager.EventType.VOLUME_CHANGE, {
                volume = targetVolume,
                isMuted = State.volume.isMuted
            })

            -- Clear fade state
            State.volume.fade.active = false

            -- Resolve the promise
            resolve(targetVolume)
        end)
    end)
end

-- Toggle mute state
function AudioManager.toggleMute()
    if not State.initialized then return false end

    State.volume.isMuted = not State.volume.isMuted

    -- Save/restore volume
    if State.volume.isMuted then
        State.volume.lastLevel = State.volume.level
        AudioManager.setVolume(0)
    else
        AudioManager.setVolume(State.volume.lastLevel)
    end

    -- Trigger event
    EventSystem.trigger(AudioManager.EventType.MUTE_CHANGE, {
        isMuted = State.volume.isMuted,
        volume = State.volume.level
    })

    return State.volume.isMuted
end

-----------------------------------------------------------
-- TaskMaster-Enhanced Playlist Management
-----------------------------------------------------------

-- Process a playlist with TaskMaster Promise support
function AudioManager.processPlaylistWithPromises(playlist, options)
    if not AudioManager.TASK_MASTER_ENABLED or not TaskMasterIntegration.available then
        logError("TaskMaster not available", "processPlaylistWithPromises")
        return false
    end

    options = options or {}
    local loop = TaskMasterIntegration.instance

    -- Set up the playlist
    AudioManager.setCurrentPlaylist(playlist, options.name)

    -- Create a chain of promises for sequential playback
    local chain = loop.Promise.resolve()

    for i, track in ipairs(playlist.tracks) do
        chain = chain:next(function()
            return loop.Promise.new(function(resolve, reject)
                local success

                -- Use crossfade if enabled except for first track
                if i > 1 and State.effects.crossfade.isEnabled then
                    success = AudioManager.crossfadeAsync(track.song, track.duration)
                else
                    success = AudioManager.playSongAsync(track.song, track.duration)
                end

                if not success then
                    reject("Failed to play: " .. track.song)
                    return
                end

                -- Set up a timer to wait for song to finish
                loop:addTimer(track.duration or 30, function()
                    resolve(i) -- Resolve with track index
                    return 0   -- Don't repeat
                end)
            end)
        end)
    end

    -- Handle completion
    chain:next(function()
        EventSystem.trigger(AudioManager.EventType.PLAYLIST_END, {
            name = State.playlist.name,
            trackCount = #State.playlist.current
        })
        debugLog("Playlist completed via promises")
    end)
        :catch(function(err)
            logError("Playlist promise error: " .. tostring(err), "processPlaylistWithPromises")
        end)

    return true
end

-----------------------------------------------------------
-- Playlist Management Functions
-----------------------------------------------------------

-- Create a new playlist
function AudioManager.createPlaylist(name, tracks)
    -- Validate input
    if type(tracks) ~= "table" or #tracks == 0 then
        logError("Invalid tracks provided to createPlaylist", "createPlaylist")
        return nil
    end

    -- Process and validate tracks
    local validatedTracks = {}

    for i, track in ipairs(tracks) do
        -- Must have at least a song property
        if type(track) ~= "table" or not track.song then
            logError("Invalid track at position " .. i, "createPlaylist")
            return nil
        end

        -- Create a copy with defaults for missing properties
        table.insert(validatedTracks, {
            song = track.song,
            name = track.name or getFormattedTrackName(track.song),
            duration = track.duration or 0
        })
    end

    -- Create and return playlist object
    return {
        metadata = {
            name = name or "Untitled Playlist",
            created = os.epoch("local"),
            lastModified = os.epoch("local")
        },
        tracks = validatedTracks
    }
end

-- Set the active playlist
function AudioManager.setCurrentPlaylist(playlist, name)
    if not State.initialized then return false end

    -- Validate playlist
    if type(playlist) ~= "table" or type(playlist.tracks) ~= "table" or #playlist.tracks == 0 then
        logError("Invalid playlist provided", "setCurrentPlaylist")
        return false
    end

    -- Update state
    State.playlist.current = playlist.tracks
    State.playlist.name = name or (playlist.metadata and playlist.metadata.name) or "Unnamed Playlist"
    State.playlist.index = 1
    State.playlist.history = {}

    -- Apply shuffle if enabled
    if State.playlist.isShuffle then
        AudioManager.shufflePlaylist()
    end

    -- Trigger event
    EventSystem.trigger(AudioManager.EventType.PLAYLIST_START, {
        name = State.playlist.name,
        trackCount = #State.playlist.current
    })

    return true
end

-- Shuffle the current playlist
function AudioManager.shufflePlaylist()
    if not State.initialized or #State.playlist.current <= 1 then
        return false
    end

    -- Create shuffled indices
    local indices = {}
    for i = 1, #State.playlist.current do
        indices[i] = i
    end

    -- Shuffle using Fisher-Yates algorithm
    for i = #indices, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    -- Create shuffled playlist
    local shuffled = {}
    for i, index in ipairs(indices) do
        shuffled[i] = State.playlist.current[index]
    end

    -- Update playlist
    State.playlist.current = shuffled
    State.playlist.index = 1

    return true
end

-- Toggle shuffle mode
function AudioManager.toggleShuffle()
    if not State.initialized then return false end

    State.playlist.isShuffle = not State.playlist.isShuffle

    -- Apply shuffle immediately if enabled
    if State.playlist.isShuffle then
        AudioManager.shufflePlaylist()
    end

    return State.playlist.isShuffle
end

-- Set looping behavior
function AudioManager.setLooping(shouldLoop)
    if not State.initialized then return false end

    local previousState = State.playlist.isLooping
    State.playlist.isLooping = shouldLoop == true

    -- Only trigger event if the state changed
    if previousState ~= State.playlist.isLooping then
        EventSystem.trigger(AudioManager.EventType.PLAYLIST_LOOP, {
            isLooping = State.playlist.isLooping
        })
    end

    return State.playlist.isLooping
end

-- Get looping state
function AudioManager.isLooping()
    return State.playlist.isLooping
end

-- Set the current track index
function AudioManager.setCurrentTrackIndex(index)
    if not State.initialized or not State.playlist.current then
        return false
    end

    -- Validate index
    if index < 1 or index > #State.playlist.current then
        logError("Invalid track index: " .. index, "setCurrentTrackIndex")
        return false
    end

    State.playlist.index = index
    return true
end

-- Play the next song in the playlist
function AudioManager.playNextSong()
    if not State.initialized or #State.playlist.current == 0 then
        return false
    end

    -- Track the previous song
    local previousSong = State.playback.currentSong
    local previousIndex = State.playlist.index

    -- Handle the last song in playlist
    if State.playlist.index >= #State.playlist.current then
        -- At the end of playlist
        if State.playlist.isLooping then
            -- Loop back to beginning
            State.playlist.index = 1
        else
            -- End of playlist, stop playback
            AudioManager.stopAll()

            -- Trigger playlist end event
            EventSystem.trigger(AudioManager.EventType.PLAYLIST_END, {
                name = State.playlist.name,
                trackCount = #State.playlist.current
            })

            return false
        end
    else
        -- Not at end, increment to next song
        State.playlist.index = State.playlist.index + 1
    end

    -- Get the next track
    local nextTrack = State.playlist.current[State.playlist.index]
    if not nextTrack then
        logError("Invalid track at index " .. State.playlist.index, "playNextSong")
        return false
    end

    -- Record previous song to history
    if previousSong then
        table.insert(State.playlist.history, {
            song = previousSong,
            index = previousIndex
        })

        -- Limit history size
        if #State.playlist.history > 20 then
            table.remove(State.playlist.history, 1)
        end
    end

    -- Play the track with appropriate method
    if previousSong and State.effects.crossfade.isEnabled then
        -- Use crossfade if enabled and previously playing
        return AudioManager.crossfade(nextTrack.song, nextTrack.duration)
    else
        -- Direct play otherwise
        return AudioManager.playSong(nextTrack.song, nextTrack.duration)
    end
end

-- Play the previous song in the playlist or history
function AudioManager.playPreviousSong()
    if not State.initialized or #State.playlist.current == 0 then
        return false
    end

    -- Check if we have history
    if #State.playlist.history > 0 then
        -- Get the last played song from history
        local previous = table.remove(State.playlist.history)

        -- Restore the index
        State.playlist.index = previous.index

        -- Get the track
        local prevTrack = State.playlist.current[State.playlist.index]
        if not prevTrack then
            logError("Invalid track from history", "playPreviousSong")
            return false
        end

        -- Play the track
        if State.playback.currentSong and State.effects.crossfade.isEnabled then
            return AudioManager.crossfade(prevTrack.song, prevTrack.duration)
        else
            return AudioManager.playSong(prevTrack.song, prevTrack.duration)
        end
    else
        -- No history, just go to the start of the playlist
        State.playlist.index = 1

        -- Get the first track
        local firstTrack = State.playlist.current[1]
        if not firstTrack then
            logError("Invalid first track", "playPreviousSong")
            return false
        end

        -- Play the track
        if State.playback.currentSong and State.effects.crossfade.isEnabled then
            return AudioManager.crossfade(firstTrack.song, firstTrack.duration)
        else
            return AudioManager.playSong(firstTrack.song, firstTrack.duration)
        end
    end
end

-----------------------------------------------------------
-- Speaker Management Functions
-----------------------------------------------------------

-- Configure speakers for stereo output
function AudioManager.configureSpeakers(leftName, rightName)
    if not State.initialized then
        logError("AudioManager not initialized", "configureSpeakers")
        return false
    end

    -- Update configuration
    Config.leftSpeaker = leftName
    Config.rightSpeaker = rightName

    -- Check if we have the specified speakers
    local hasLeft = SpeakerSystem.devices[leftName] ~= nil
    local hasRight = SpeakerSystem.devices[rightName] ~= nil

    -- Update speaker system
    if hasLeft then
        SpeakerSystem.stereo.left = leftName
        SpeakerSystem.devices[leftName].isLeft = true
    end

    if hasRight then
        SpeakerSystem.stereo.right = rightName
        SpeakerSystem.devices[rightName].isRight = true
    end

    -- Update stereo state
    SpeakerSystem.stereo.enabled = hasLeft and hasRight

    -- Reset other speakers
    for name, speaker in pairs(SpeakerSystem.devices) do
        if name ~= leftName and name ~= rightName then
            speaker.isLeft = false
            speaker.isRight = false
        end
    end

    return SpeakerSystem.stereo.enabled
end

-- Set stereo balance between left and right speakers
function AudioManager.setSpeakerBalance(left, right)
    if not State.initialized then
        return false
    end

    -- Validate volume levels
    left = math.max(0, math.min(1, left))
    right = math.max(0, math.min(1, right))

    -- Update balance settings
    SpeakerSystem.stereo.balance.left = left
    SpeakerSystem.stereo.balance.right = right
    SpeakerSystem.stereo.enabled = true

    -- Apply to current playback if active
    if State.playback.currentSong then
        playSoundOnSpeakers(State.playback.currentSong, State.volume.level)
    end

    return true
end

-- Get speaker status
function AudioManager.getSpeakerStatus()
    local status = {
        total = 0,
        stereoEnabled = SpeakerSystem.stereo.enabled,
        speakers = {}
    }

    -- Count active speakers
    for name, speaker in pairs(SpeakerSystem.devices) do
        status.total = status.total + 1

        status.speakers[name] = {
            isLeft = speaker.isLeft,
            isRight = speaker.isRight,
            isPrimary = (name == SpeakerSystem.primary),
            volume = State.volume.level * (
                speaker.isLeft and SpeakerSystem.stereo.balance.left or
                speaker.isRight and SpeakerSystem.stereo.balance.right or
                1.0
            )
        }
    end

    return status
end

-- Get current speaker configuration
function AudioManager.getSpeakerConfig()
    return {
        left = SpeakerSystem.stereo.left,
        right = SpeakerSystem.stereo.right,
        primary = SpeakerSystem.primary,
        stereoEnabled = SpeakerSystem.stereo.enabled,
        balance = {
            left = SpeakerSystem.stereo.balance.left,
            right = SpeakerSystem.stereo.balance.right
        }
    }
end

-----------------------------------------------------------
-- TaskMaster Integration Functions
-----------------------------------------------------------

-- Get the TaskMaster instance if available
function AudioManager.getTaskMaster()
    if not AudioManager.TASK_MASTER_ENABLED then return nil end

    -- Try loading TaskMaster on-demand if needed
    if not tryLoadTaskMaster() then
        return nil
    end

    return TaskMasterIntegration.instance
end

-- Check if TaskMaster integration is available
function AudioManager.isTaskMasterAvailable()
    return AudioManager.TASK_MASTER_ENABLED and TaskMasterIntegration.available
end

-- Enable TaskMaster support (with optional path)
function AudioManager.enableTaskMaster(path)
    AudioManager.TASK_MASTER_ENABLED = true

    if path then
        AudioManager.TASK_MASTER_PATH = path
    end

    return tryLoadTaskMaster()
end

-- Disable TaskMaster support
function AudioManager.disableTaskMaster()
    AudioManager.TASK_MASTER_ENABLED = false
    return true
end

-----------------------------------------------------------
-- Status and Information Functions
-----------------------------------------------------------

-- Get current song info
function AudioManager.getCurrentSong()
    if not State.initialized or not State.playback.currentSong then
        return nil
    end

    return State.playback.currentSong
end

-- Get current song name
function AudioManager.getCurrentSongName()
    if not State.initialized or not State.playback.songName then
        return nil
    end

    return State.playback.songName
end

-- Get current playback position
function AudioManager.getCurrentTime()
    if not State.initialized or not State.playback.startTime then
        return 0
    end

    -- Calculate position
    local position = os.epoch("local") / 1000 - State.playback.startTime
    State.playback.position = position

    return math.floor(position)
end

-- Get current song duration
function AudioManager.getCurrentSongDuration()
    if not State.initialized or not State.playback.duration then
        return 0
    end

    return State.playback.duration
end

-- Get current playlist name
function AudioManager.getCurrentPlaylistName()
    if not State.initialized or not State.playlist.name then
        return nil
    end

    return State.playlist.name
end

-- Get comprehensive status
function AudioManager.getStatus()
    local status = {
        initialized = State.initialized,
        playback = {
            isPlaying = State.playback.isPlaying,
            currentSong = State.playback.currentSong,
            songName = State.playback.songName,
            position = AudioManager.getCurrentTime(),
            duration = State.playback.duration
        },
        volume = {
            level = State.volume.level,
            isMuted = State.volume.isMuted,
            fading = State.volume.fade.active
        },
        effects = {
            crossfadeEnabled = State.effects.crossfade.isEnabled,
            crossfadeActive = State.effects.crossfade.active,
            crossfadeDuration = State.effects.crossfade.duration
        },
        playlist = {
            name = State.playlist.name,
            trackCount = State.playlist.current and #State.playlist.current or 0,
            currentIndex = State.playlist.index,
            isLooping = State.playlist.isLooping,
            isShuffle = State.playlist.isShuffle
        },
        speakers = AudioManager.getSpeakerStatus(),
        taskMaster = {
            enabled = AudioManager.TASK_MASTER_ENABLED,
            available = TaskMasterIntegration.available,
            loaded = TaskMasterIntegration.instance ~= nil
        }
    }

    return status
end

-----------------------------------------------------------
-- Event System Interface
-----------------------------------------------------------

-- Add an event listener
function AudioManager.addEventListener(eventType, callback)
    return EventSystem.addListener(eventType, callback)
end

-- Remove an event listener
function AudioManager.removeEventListener(eventType, callback)
    return EventSystem.removeListener(eventType, callback)
end

-----------------------------------------------------------
-- API Utility Functions
-----------------------------------------------------------

-- Get API version
function AudioManager.getVersion()
    return AudioManager.VERSION
end

-- Enable or disable debug mode
function AudioManager.setDebug(enabled)
    AudioManager.DEBUG = enabled == true
    return AudioManager.DEBUG
end

-- Dump the full system state (debug function)
function AudioManager.debugState()
    if not AudioManager.DEBUG then return end

    local stateSnapshot = {
        playback = State.playback,
        volume = State.volume,
        playlist = State.playlist,
        effects = State.effects,
        speakers = {
            devices = {},
            stereo = SpeakerSystem.stereo
        }
    }

    -- Filter out device objects in speakers
    for name, speaker in pairs(SpeakerSystem.devices) do
        stateSnapshot.speakers.devices[name] = {
            isLeft = speaker.isLeft,
            isRight = speaker.isRight,
            volume = speaker.volume
        }
    end

    print(textutils.serialize(stateSnapshot))
end

-- Auto-initialize if not initialized
if AudioManager.initialize then
    AudioManager.initialize()
end

-- Return the public API
return AudioManager
