# AudioManager API

A comprehensive audio management API for ComputerCraft/CC: Tweaked speakers with support for playlists, crossfading, and stereo output.

## Features

- Multi-speaker support with stereo balancing
- Playlist management with shuffle and loop options
- Volume control with fade effects
- Crossfading between tracks
- Event system for audio state changes
- Comprehensive error handling
- Debug capabilities
- Optional TaskMaster integration for advanced parallelism

## Sound File Support

The AudioManager uses Minecraft's built-in sound system and supports:

- Resource pack sound files (.ogg format)
- Mod-added sounds
- Built-in Minecraft sounds

Sound files are referenced using Minecraft's namespace format:

- `minecraft:block.note_block.harp` - Vanilla Minecraft sounds
- `modid:path.to.sound` - Mod-added sounds
- `resourcepack:custom.sound` - Resource pack sounds

### Sound File Examples

```lua
-- Vanilla Minecraft sounds
"minecraft:block.note_block.harp"      -- Note block sounds
"minecraft:music.game"                 -- Background music
"minecraft:music.creative"             -- Creative mode music
"minecraft:block.bell.use"            -- Bell sound

-- Common mod sound format
"kubejs:custom.music.track1"          -- KubeJS added sounds
"mymod:music/custom_track"            -- Mod music
```

## Installation

1. Place `AudioManager.lua` in your computer's APIs directory or whereever you'd like to store external APIs
2. Require the API in your program:

```lua
local AudioManager = require("AudioManager")
```

3. If using TaskMaster integration (optional):
   - Place `TaskMaster.lua` in your computer
   - Enable TaskMaster during initialization (see TaskMaster Integration section)

## Basic Usage

```lua
-- Initialize the API with specific speaker configuration
AudioManager.initialize({
    volume = 0.8,           -- Initial volume (0.0-1.0)
    leftSpeaker = "speaker_4",   -- Specific speaker peripheral names
    rightSpeaker = "speaker_5"
})

-- Create a playlist using Minecraft sound files
local playlist = AudioManager.createPlaylist("Background Music", {
    {
        name = "Minecraft Menu",
        song = "minecraft:music.menu",     -- Original Minecraft music
        duration = 600                     -- Duration in seconds
    },
    {
        name = "Custom Mod Track",
        song = "mymod:music.custom_track", -- Mod-added music
        duration = 180
    }
})

-- Set and play the playlist
AudioManager.setCurrentPlaylist(playlist, "Background Music")
AudioManager.playSong(playlist.tracks[1].song, playlist.tracks[1].duration)
```

## Speaker Configuration

### Single Speaker Setup

```lua
AudioManager.initialize()  -- Uses first available speaker
```

### Stereo Setup

```lua
-- Configure specific speakers
AudioManager.configureSpeakers("speaker_1", "speaker_2")

-- Adjust balance
AudioManager.setSpeakerBalance(0.8, 1.0)  -- Left: 80%, Right: 100%
```

## Playlist Management

### Creating Playlists

```lua
local playlist = AudioManager.createPlaylist("Example", {
    {
        name = "Custom Name",     -- Optional, defaults to song ID
        song = "namespace:path",   -- Required
        duration = 10             -- Optional, defaults to 0
    }
})
```

### Playlist Controls

```lua
AudioManager.setLooping(true)      -- Enable playlist loop
AudioManager.toggleShuffle()       -- Toggle shuffle mode
AudioManager.setCurrentTrackIndex(2)  -- Jump to specific track
```

## Volume Control

```lua
AudioManager.setVolume(0.5)        -- Set volume (0.0-1.0)
AudioManager.fadeVolume(0.8, 2)    -- Fade to volume over duration
AudioManager.toggleMute()          -- Toggle mute
```

## Event System

```lua
-- Add event listener
AudioManager.addEventListener(AudioManager.EventType.SONG_END, function(data)
    print("Song ended:", data.song)
end)

-- Available events:
-- SONG_START, SONG_END, PLAYLIST_START, PLAYLIST_END
-- VOLUME_CHANGE, ERROR, MUTE_CHANGE, PLAYLIST_LOOP
-- CROSSFADE_START, CROSSFADE_END
```

## TaskMaster Integration

AudioManager can optionally integrate with the TaskMaster library for enhanced parallelism, promises, and background operations.

### Enabling TaskMaster

```lua
-- Enable during initialization
AudioManager.initialize({
    enableTaskMaster = true,        -- Enable TaskMaster integration
    taskMasterPath = "TaskMaster"   -- Optional: Specify TaskMaster path
})

-- Or enable after initialization
AudioManager.enableTaskMaster("core.libs.system.TaskMaster")  -- Optional path
```

### Using Async Functions

```lua
-- Use async versions of functions for background processing
AudioManager.playSongAsync("minecraft:music.game", 30)  -- Plays and monitors in background
AudioManager.crossfadeAsync("minecraft:music.menu", 3)  -- Crossfades in background
AudioManager.fadeVolumeAsync(0.3, 2)                   -- Fades volume in background

-- Check if TaskMaster is available
if AudioManager.isTaskMasterAvailable() then
    print("TaskMaster integration is working!")
end

-- Get direct access to TaskMaster
local taskMaster = AudioManager.getTaskMaster()
if taskMaster then
    -- Use TaskMaster directly for custom operations
    taskMaster:addTimer(10, function()
        print("10 seconds elapsed")
        return 0  -- Don't repeat
    end)
end
```

### Promise-Based Playlist Processing

```lua
-- Process a playlist with TaskMaster promises
local playlist = AudioManager.createPlaylist("Advanced Playlist", {
    { song = "minecraft:music.game", duration = 10 },
    { song = "minecraft:music.creative", duration = 15 }
})

AudioManager.processPlaylistWithPromises(playlist, {
    name = "Enhanced Playlist"
})
```

## API Reference

### Initialization

- `initialize(options)` - Initialize the API
- `configureSpeakers(leftName, rightName)` - Configure stereo speakers
- `getSpeakerConfig()` - Get current speaker configuration

### Playback Control

- `playSong(songName, duration)` - Play a single song
- `playSongAsync(songName, duration)` - Play a song with background monitoring (TaskMaster)
- `stopAll()` - Stop all playback
- `crossfade(newSong, duration)` - Crossfade to new song
- `crossfadeAsync(newSong, duration)` - Crossfade to new song in background (TaskMaster)

### Volume Control

- `setVolume(volume)` - Set volume (0.0-1.0)
- `getVolume()` - Get current volume
- `fadeVolume(target, duration)` - Fade volume
- `fadeVolumeAsync(target, duration)` - Fade volume in background (TaskMaster)
- `toggleMute()` - Toggle mute state

### Playlist Management

- `createPlaylist(name, tracks)` - Create new playlist
- `setCurrentPlaylist(playlist, name)` - Set active playlist
- `shufflePlaylist()` - Shuffle current playlist
- `setLooping(shouldLoop)` - Set playlist loop
- `toggleShuffle()` - Toggle shuffle mode
- `processPlaylistWithPromises(playlist, options)` - Process playlist with TaskMaster promises

### TaskMaster Integration

- `enableTaskMaster(path)` - Enable TaskMaster integration
- `disableTaskMaster()` - Disable TaskMaster integration
- `isTaskMasterAvailable()` - Check if TaskMaster integration is available
- `getTaskMaster()` - Get the TaskMaster instance

### Status & Information

- `getStatus()` - Get comprehensive status
- `getCurrentSong()` - Get current song ID
- `getCurrentSongName()` - Get current song name
- `getCurrentTime()` - Get current track position
- `getSpeakerStatus()` - Get speaker status

### Event System

- `addEventListener(eventType, callback)` - Add event listener
- `removeEventListener(eventType, callback)` - Remove event listener

## Examples

### Advanced Playlist with Crossfading

```lua
-- Create and configure playlist
local playlist = AudioManager.createPlaylist("Background Music", {
    { name = "Track 1", song = "minecraft:music.menu" },
    { name = "Track 2", song = "minecraft:music.game" }
})

-- Set up event handling
AudioManager.addEventListener(AudioManager.EventType.SONG_END, function(data)
    local nextTrack = playlist.tracks[AudioManager.getCurrentTrackIndex() + 1]
    if nextTrack then
        AudioManager.crossfade(nextTrack.song, 2)
    end
end)

-- Start playback
AudioManager.setCurrentPlaylist(playlist)
AudioManager.playSong(playlist.tracks[1].song)
```

### TaskMaster-Enhanced Background Audio System

```lua
-- Initialize with TaskMaster
AudioManager.initialize({ enableTaskMaster = true })

-- Verify TaskMaster is available
if not AudioManager.isTaskMasterAvailable() then
    print("TaskMaster not available, using standard functions")
end

-- Create playlist
local playlist = AudioManager.createPlaylist("Background Ambience", {
    { song = "minecraft:ambient.cave", duration = 30 },
    { song = "minecraft:ambient.underwater", duration = 25 }
})

-- Set up background audio system with TaskMaster
AudioManager.setCurrentPlaylist(playlist)

-- Get TaskMaster instance for custom timing
local taskMaster = AudioManager.getTaskMaster()
if taskMaster then
    taskMaster:addTask(function()
        -- Start playlist with async functions
        AudioManager.playSongAsync(playlist.tracks[1].song, playlist.tracks[1].duration)

        -- Set up volume control based on in-game time
        taskMaster:addTimer(5, function()
            local timeOfDay = os.time()

            -- Fade volume based on time
            if timeOfDay > 0.7 or timeOfDay < 0.3 then
                -- Night time - quieter
                AudioManager.fadeVolumeAsync(0.4, 3)
            else
                -- Day time - louder
                AudioManager.fadeVolumeAsync(0.8, 3)
            end

            return 5 -- Check again in 5 seconds
        end)
    end)

    -- Run TaskMaster in background
    parallel.waitForAny(function() taskMaster:run() end, function()
        -- Your main program code here
        while true do
            -- Do other operations
            os.sleep(1)
        end
    end)
else
    -- Fallback for no TaskMaster
    AudioManager.playSong(playlist.tracks[1].song, playlist.tracks[1].duration)
end
```

## Version History

- 3.0.0
  - Added TaskMaster integration for enhanced parallelism
  - Added async versions of core functions
  - Added promise-based playlist processing
  - Completely Refactored.
- 2.1.0
  - Added stereo support and speaker configuration
- 2.0.0
  - Initial public release
  - Removed all Reference to the Previous Program Locked method of this API

## Credits

Created by Xylopia (Vinyl)
