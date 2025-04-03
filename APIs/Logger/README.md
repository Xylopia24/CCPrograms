# Logger for ComputerCraft

A robust logging system for ComputerCraft with multiple severity levels, category-based log files, automatic rotation, and backup management.

## Features

- **Multiple Log Levels**: debug, info, warn, error, and fatal
- **Category-Based Logging**: Separate log files for different systems
- **Automatic Log Rotation**: Prevents log files from growing too large
- **Backup Management**: Maintains a configurable number of backup logs
- **Timestamp Formatting**: All logs include precise timestamps
- **Simple API**: Consistent and easy-to-use logging methods

## Installation

1. Create a `/logs` directory in your ComputerCraft computer
2. Copy `Logger.lua` to your ComputerCraft `/apis` or project directory

Alternatively, you can download directly in ComputerCraft:

```lua
-- Download Logger
shell.run("wget https://raw.githubusercontent.com/Xylopia24/ComputerCraft-Programs-Repo/main/APIs/Logger/Logger.lua /apis/Logger.lua")
```

## Quick Start

```lua
-- Load the Logger
local Logger = require("Logger") -- or dofile("Logger.lua")

-- Basic logging
Logger:info("Application started")
Logger:debug("Connection details: " .. tostring(data))
Logger:warn("Low disk space detected")
Logger:error("Failed to connect to server")
Logger:fatal("Critical system failure")

-- Category-based logging
Logger:info("network", "Connection established")
Logger:warn("security", "Failed login attempt from " .. user)
Logger:error("database", "Query failed: " .. errorMsg)
```

## API Reference

### Basic Logging Methods

Each method supports two formats:

1. `Logger:level(category, message)` - Log to specific category
2. `Logger:level(message)` - Log to default category

```lua
-- Log a debug message
Logger:debug("category", "Debug message")
Logger:debug("Debug message")  -- Uses default category

-- Log an informational message
Logger:info("category", "Info message")
Logger:info("Info message")

-- Log a warning
Logger:warn("category", "Warning message")
Logger:warn("Warning message")

-- Log an error
Logger:error("category", "Error message")
Logger:error("Error message")

-- Log a fatal error
Logger:fatal("category", "Fatal error message")
Logger:fatal("Fatal error message")
```

### Advanced Methods

```lua
-- Directly log with specified level
Logger:log("category", "level", "message")

-- Clear logs for a category
Logger:clear("category")  -- Clears logs and backups
Logger:clear()  -- Clears default category logs

-- Enable/disable console output
Logger:setConsoleOutput(true)  -- Also print logs to console
Logger:setConsoleOutput(false) -- Default, logs only to files

-- Set minimum log level (will ignore logs below this level)
Logger:setMinLevel("warn")  -- Will only log warn, error, and fatal levels
```

### Configuration

You can configure Logger by modifying these properties:

```lua
-- Change log directory
Logger.LOG_DIR = "/custom/logs/path"

-- Change backup directory
Logger.BACKUP_DIR = "/custom/logs/backups"

-- Change maximum number of backups
Logger.MAX_BACKUPS = 10

-- Change default category
Logger.DEFAULT_CATEGORY = "app"
```

## Usage Examples

### Structured Application Logging

```lua
local Logger = require("Logger")

-- Application startup
Logger:info("app", "Starting application v1.2.0")

-- Handle different subsystems with categories
function networkConnect(address)
    Logger:debug("network", "Connecting to " .. address)
    -- Connection code...
    if connected then
        Logger:info("network", "Connected to " .. address)
    else
        Logger:error("network", "Failed to connect to " .. address)
    end
end

function saveData(data)
    Logger:debug("storage", "Saving " .. #data .. " records")
    -- Storage code...
    if success then
        Logger:info("storage", "Data saved successfully")
    else
        Logger:error("storage", "Failed to save data: " .. errorMessage)
    end
end

-- Mark critical system failure
function systemFailure(reason)
    Logger:fatal("system", "Critical failure: " .. reason)
    -- Show error UI and attempt recovery...
end
```

### Tracking User Activity

```lua
local Logger = require("Logger")

-- Enable console output during development
Logger:setConsoleOutput(true)

-- Monitor user logins
function onLogin(username)
    Logger:info("security", "User logged in: " .. username)
end

-- Track failed login attempts
function onFailedLogin(username, reason)
    Logger:warn("security", "Failed login for user: " .. username .. " (" .. reason .. ")")

    -- If too many failed attempts, escalate to error
    if attempts > 5 then
        Logger:error("security", "Multiple failed login attempts for user: " .. username)
    end
end

-- Log important user actions
function trackUserAction(username, action, details)
    Logger:info("audit", username .. " performed action: " .. action .. " - " .. details)
end
```

### System Monitoring

```lua
local Logger = require("Logger")

-- Check system resources periodically
function monitorResources()
    while true do
        local freeDisk = fs.getFreeSpace("/")
        local usedDisk = fs.getCapacity("/") - freeDisk

        -- Log disk usage
        Logger:debug("monitor", "Disk usage: " .. usedDisk .. " / " .. fs.getCapacity("/"))

        -- Warn when disk space is low
        if freeDisk < 10000 then
            Logger:warn("monitor", "Low disk space: " .. freeDisk .. " bytes remaining")
        end

        -- Check computer uptime
        local uptime = os.clock()
        Logger:debug("monitor", "System uptime: " .. uptime .. " seconds")

        sleep(60) -- Check every minute
    end
end

-- Log any errors in a function with error handling
function safeExecute(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        Logger:error("system", "Function execution failed: " .. result)
        return nil
    end
    return result
end
```

## Best Practices

1. **Use Appropriate Log Levels**:

   - `debug`: Detailed information useful for debugging
   - `info`: General information about system operation
   - `warn`: Potential issues that don't affect core functionality
   - `error`: Errors that affect functionality but don't crash the system
   - `fatal`: Critical errors that prevent system operation

2. **Organize with Categories**:

   - Use consistent category names across your application
   - Create separate categories for major subsystems
   - Categories help you find relevant logs quickly

3. **Include Contextual Information**:

   - Log relevant variables and state information
   - Include identifying information (user IDs, request IDs)
   - Format messages for easy parsing and readability

4. **Use Console Output Selectively**:

   - Enable during development with `Logger:setConsoleOutput(true)`
   - Disable in production for performance

5. **Manage Log Size**:

   - The automatic rotation system prevents log files from growing too large
   - Adjust `MAX_BACKUPS` based on your storage constraints
   - Call `Logger:clear(category)` when needed to remove old logs

## License

[MIT License](LICENSE)
