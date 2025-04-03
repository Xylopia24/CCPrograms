# MirrorDisplay API

A comprehensive terminal mirroring system for ComputerCraft monitors with advanced styling and TaskMaster integration.

## 📋 Overview

MirrorDisplay provides a robust solution for mirroring terminal output to connected monitors with features including custom borders, automatic scaling, theme support, and optional background operations through TaskMaster integration.

With MirrorDisplay, you can create professional-looking terminal mirrors with minimal setup, perfect for control rooms, monitoring stations, or any application where you need to display terminal output on remote screens.

## 📝 Changelog

### Version 3.0.0

- Added TaskMaster integration for background operations
- Added theme system with customizable colors
- Added multiple border styles and custom border support
- Added automatic scaling for optimal readability
- Completely refactored internal architecture
- Improved error handling and debugging

### Version 2.0.0

- Added frame styling with custom headers
- Improved window positioning
- Fixed terminal redirection issues

### Version 1.0.0

- Initial release with basic mirroring functionality

## ⚙️ Installation

1. Copy `MirrorDisplay.lua` to your computer
2. Ensure you have a monitor connected to your computer
3. Include the API in your program:

```lua
local MirrorDisplay = require("MirrorDisplay")
```

## 🚀 Quick Start

### Basic Usage

```lua
-- Load the API
local MirrorDisplay = require("MirrorDisplay")

-- Initialize with a monitor (auto-detects first monitor if not specified)
MirrorDisplay.initialize({
    title = "My Terminal Mirror"
})

-- Start mirroring
MirrorDisplay.start()

-- Your program code here...
print("This will show on both terminal and monitor!")

-- Clean up when done
MirrorDisplay.cleanup()
```

### Advanced Configuration

```lua
-- Load the API
local MirrorDisplay = require("MirrorDisplay")

-- Initialize with detailed configuration
MirrorDisplay.initialize({
    monitor = "monitor_0",           -- Specific monitor peripheral name
    title = "System Monitor",        -- Title for the border
    borderStyle = "double",          -- Border style (default, double, rounded)
    autoScale = true,                -- Find best text scale automatically
    backgroundColor = colors.black,  -- Custom background color
    borderColor = colors.blue,       -- Custom border color
    titleColor = colors.cyan,        -- Custom title color
    textColor = colors.white         -- Custom text color
})

-- Start mirroring
MirrorDisplay.start()

-- Your program code...

-- Clean up resources
MirrorDisplay.cleanup()
```

### TaskMaster Integration

```lua
-- Load the APIs
local MirrorDisplay = require("MirrorDisplay")

-- Initialize with TaskMaster support
MirrorDisplay.initialize({
    title = "Background Mirror"
})

-- Enable TaskMaster integration
MirrorDisplay.enableTaskMaster("core.libs.system.TaskMaster")

-- Start mirroring
MirrorDisplay.start()

-- Enable automatic background refreshing
MirrorDisplay.startAutoRefresh(0.5)  -- Refresh every 0.5 seconds

-- Get the TaskMaster instance for custom tasks
local taskMaster = MirrorDisplay.getTaskMaster()
if taskMaster then
    taskMaster:addTimer(5, function()
        print("Background task running...")
        return 5  -- Repeat every 5 seconds
    end)

    -- Run the TaskMaster loop in the background
    parallel.waitForAny(
        function() taskMaster:run() end,
        function()
            -- Your main program here
            while true do
                -- Do work
                os.sleep(1)
            end
        end
    )
end

-- Clean up when done
MirrorDisplay.cleanup()
```

## 📖 API Reference

### Core Functions

```lua
-- Initialize with options
MirrorDisplay.initialize(options)
-- options: table with the following properties (all optional):
-- monitor: string - peripheral name of the monitor
-- title: string - title to display in border
-- borderStyle: string - "default", "double", or "rounded"
-- autoScale: boolean - find optimal text scale
-- scale: number - specific scale value (0.5-5.0)
-- backgroundColor: color - background color
-- borderColor: color - border color
-- titleColor: color - title text color
-- textColor: color - main text color
-- Returns: boolean - success/failure

-- Start mirroring
MirrorDisplay.start()
-- Returns: boolean - success/failure

-- Redraw the frame (useful after changes)
MirrorDisplay.redrawFrame(newTitle)
-- newTitle: string (optional) - update the title
-- Returns: boolean - success/failure

-- Stop mirroring (can be restarted)
MirrorDisplay.stop()
-- Returns: boolean - success/failure

-- Clean up resources completely
MirrorDisplay.cleanup()
-- Returns: boolean - success/failure
```

### Theme and Styling

```lua
-- Set theme colors
MirrorDisplay.setTheme(themeTable)
-- themeTable: table with the following properties (all optional):
-- background: color - background color
-- border: color - border color
-- title: color - title text color
-- text: color - main text color
-- Returns: boolean - success/failure

-- Change border style
MirrorDisplay.setBorderStyle(styleName)
-- styleName: string - "default", "double", "rounded", or custom style
-- Returns: boolean - success/failure

-- Add custom border style
MirrorDisplay.addBorderStyle(name, styleTable)
-- name: string - name for the style
-- styleTable: table with the following properties:
-- corner: string - corner character
-- horizontal: string - horizontal border character
-- vertical: string - vertical border character
-- Returns: boolean - success/failure

-- Set title
MirrorDisplay.setTitle(title)
-- title: string - new title
-- Returns: boolean - success/failure
```

### TaskMaster Integration

```lua
-- Enable TaskMaster support
MirrorDisplay.enableTaskMaster(path)
-- path: string (optional) - path to TaskMaster module
-- Returns: boolean - success/failure

-- Disable TaskMaster support
MirrorDisplay.disableTaskMaster()
-- Returns: boolean - success/failure

-- Start automatic refresh
MirrorDisplay.startAutoRefresh(refreshRate)
-- refreshRate: number (optional) - seconds between refreshes
-- Returns: boolean - success/failure

-- Stop automatic refresh
MirrorDisplay.stopAutoRefresh()
-- Returns: boolean - success/failure

-- Check if TaskMaster is available
MirrorDisplay.isTaskMasterAvailable()
-- Returns: boolean - availability status

-- Get TaskMaster instance
MirrorDisplay.getTaskMaster()
-- Returns: TaskMaster instance or nil if not available
```

### Status and Debugging

```lua
-- Get comprehensive status
MirrorDisplay.getStatus()
-- Returns: table with detailed status information

-- Enable or disable debug mode
MirrorDisplay.setDebug(enabled)
-- enabled: boolean
-- Returns: boolean - current debug state
```

## ⚡ Performance Considerations

- Using auto-refresh with TaskMaster has minimal impact on performance
- Higher refresh rates (below 0.1s) may affect system responsiveness
- For resource-constrained systems, use manual redrawing or slower refresh rates

## 🔍 Troubleshooting

- **Monitor not found**: Check peripheral connection and name
- **Display too small**: Try using `autoScale = true` or a smaller scale value
- **TaskMaster errors**: Verify TaskMaster is installed and properly referenced
- **Performance issues**: Reduce refresh rate or disable auto-refresh

## 🤝 Compatibility

- Compatible with all ComputerCraft/CC:Tweaked versions
- Works with standard monitors and advanced monitors
- Optional TaskMaster integration for enhanced functionality
