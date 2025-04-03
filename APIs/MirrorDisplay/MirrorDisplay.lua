--[[
    MirrorDisplay API
    Version: 3.0.0
    Created By: Xylopia (Vinyl)

    A comprehensive terminal mirroring system for ComputerCraft monitors.

    Features:
    - High-quality terminal mirroring to external displays
    - Customizable borders and titles
    - Multi-scale support with auto-sizing
    - Automatic monitor detection
    - Background redraw operations (with TaskMaster)
    - Theme integration support
]]

-----------------------------------------------------------
-- Module Configuration
-----------------------------------------------------------

local MirrorDisplay = {
    -- Version information
    VERSION = "3.0.0",
    DEBUG = false,

    -- TaskMaster integration options
    TASK_MASTER_ENABLED = false, -- Default to disabled
    TASK_MASTER_PATH = nil,      -- Default path (nil means try common paths)

    -- Default styling options
    DEFAULT_SCALE = 0.5,
    DEFAULT_TITLE = "Terminal Mirror",
    DEFAULT_THEME = {
        border = colors.blue,
        title = colors.cyan,
        background = colors.black,
        text = colors.white
    },

    -- Customizable border characters
    BORDER_STYLES = {
        default = {
            corner = "+",
            horizontal = "-",
            vertical = "|"
        },
        double = {
            corner = "╬",
            horizontal = "═",
            vertical = "║"
        },
        rounded = {
            corner = "•",
            horizontal = "─",
            vertical = "│"
        }
    },

    -- Status tracking
    active = false,
    refreshRate = 0.1, -- Seconds between auto-refreshes
}

-----------------------------------------------------------
-- Internal State Management
-----------------------------------------------------------

-- Private state variables
local State = {
    initialized = false,
    monitor = nil,
    originalTerm = nil,
    window = nil,
    multiTerm = nil,
    frameOffset = { x = 0, y = 0 },
    termSize = { width = 0, height = 0 },
    monitorSize = { width = 0, height = 0 },
    borderStyle = nil,
    autoRefresh = false,
    theme = {},
    title = nil
}

-----------------------------------------------------------
-- TaskMaster Integration
-----------------------------------------------------------

-- TaskMaster integration state
local TaskMasterIntegration = {
    available = false,
    instance = nil,
    loadAttempted = false,
    refreshTask = nil
}

-- Try to load TaskMaster from various possible paths
local function tryLoadTaskMaster()
    if TaskMasterIntegration.loadAttempted then
        return TaskMasterIntegration.available
    end

    TaskMasterIntegration.loadAttempted = true

    local paths = {
        MirrorDisplay.TASK_MASTER_PATH, -- User-specified path first
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

                if MirrorDisplay.DEBUG then
                    print("[MirrorDisplay] TaskMaster loaded successfully from " .. path)
                end

                return true
            end
        end
    end

    if MirrorDisplay.DEBUG then
        print("[MirrorDisplay] TaskMaster not found or failed to load")
    end

    return false
end

-----------------------------------------------------------
-- Utility Functions
-----------------------------------------------------------

-- Debug logging function
local function debugLog(...)
    if not MirrorDisplay.DEBUG then return end

    local args = { ... }
    local output = "[MirrorDisplay] "

    for i, arg in ipairs(args) do
        if type(arg) == "table" then
            output = output .. textutils.serialize(arg) .. " "
        else
            output = output .. tostring(arg) .. " "
        end
    end

    print(output)
end

-- Error handling function
local function handleError(message, source)
    local errorMsg = "[MirrorDisplay Error"
    if source then
        errorMsg = errorMsg .. " in " .. source
    end
    errorMsg = errorMsg .. "] " .. message

    printError(errorMsg)
    return nil
end

-- Find the best text scale for a monitor given terminal size
local function findOptimalScale(monitor, termW, termH)
    local scales = { 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5 }
    local bestScale = 0.5

    for _, scale in ipairs(scales) do
        monitor.setTextScale(scale)
        local mw, mh = monitor.getSize()

        -- Need at least 4 extra chars for borders
        if mw >= termW + 4 and mh >= termH + 4 then
            bestScale = scale
        else
            break -- Stop once we find a scale that's too small
        end
    end

    return bestScale
end

-- Create a multitable that mirrors terminal operations to multiple terminals
local function createMultiTable(originalTerm, mirrorTerm)
    if not originalTerm or not mirrorTerm then
        return handleError("Invalid terminals provided", "createMultiTable")
    end

    local multiTerm = {}

    -- Function to wrap method calls to both terminals
    local function wrapFunction(funcName)
        return function(...)
            local args = { ... } -- Capture varargs in a local table
            local success, result = pcall(function()
                local r = originalTerm[funcName](table.unpack(args))
                pcall(function() mirrorTerm[funcName](table.unpack(args)) end)
                return r
            end)

            if success then
                return result
            else
                if MirrorDisplay.DEBUG then
                    debugLog("Error in " .. funcName .. ": " .. tostring(result))
                end
                -- Fallback to original term only on error
                return originalTerm[funcName](table.unpack(args))
            end
        end
    end

    -- Copy all functions from original terminal
    for k, v in pairs(originalTerm) do
        if type(v) == "function" then
            multiTerm[k] = wrapFunction(k)
        end
    end

    -- Special handling for certain methods
    multiTerm.write = function(text)
        originalTerm.write(text)
        pcall(function() mirrorTerm.write(text) end)
    end

    multiTerm.blit = function(text, textColors, bgColors)
        originalTerm.blit(text, textColors, bgColors)
        pcall(function() mirrorTerm.blit(text, textColors, bgColors) end)
    end

    multiTerm.clear = function()
        originalTerm.clear()
        pcall(function()
            mirrorTerm.setBackgroundColor(State.theme.background or colors.black)
            mirrorTerm.clear()
            MirrorDisplay.redrawFrame()
        end)
    end

    -- Get size should always return the original terminal's size
    multiTerm.getSize = function()
        return originalTerm.getSize()
    end

    return multiTerm
end

-----------------------------------------------------------
-- Drawing Functions
-----------------------------------------------------------

-- Draw frame directly on monitor
local function drawFrame(monitor, width, height, title, offsetX, offsetY)
    if not monitor then return false end

    local oldBg = monitor.getBackgroundColor()
    local oldFg = monitor.getTextColor()

    -- Apply theme
    monitor.setBackgroundColor(State.theme.background or colors.black)
    monitor.setTextColor(State.theme.border or colors.blue)

    -- Adjust offsets
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    -- Get border characters
    local border = State.borderStyle or MirrorDisplay.BORDER_STYLES.default

    -- Calculate border width
    width = width + 2 -- Add space for borders

    -- Create top border with title if provided
    local borderTop = border.corner .. string.rep(border.horizontal, width) .. border.corner

    if title then
        -- Use title theme if different from border
        local titleFg = State.theme.title or State.theme.border or colors.blue

        -- Calculate title position (centered)
        local titleStart = math.floor((width - #title) / 2)

        -- Draw pre-title border
        monitor.setCursorPos(offsetX + 1, offsetY + 1)
        monitor.write(border.corner .. string.rep(border.horizontal, titleStart - 1))

        -- Draw title with different color
        monitor.setTextColor(titleFg)
        monitor.write(title)

        -- Draw post-title border
        monitor.setTextColor(State.theme.border or colors.blue)
        monitor.write(string.rep(border.horizontal, width - #title - titleStart) .. border.corner)
    else
        monitor.setCursorPos(offsetX + 1, offsetY + 1)
        monitor.write(borderTop)
    end

    -- Draw bottom border
    monitor.setCursorPos(offsetX + 1, offsetY + height + 2)
    monitor.write(border.corner .. string.rep(border.horizontal, width) .. border.corner)

    -- Draw side borders
    for y = 1, height do
        monitor.setCursorPos(offsetX + 1, offsetY + y + 1)
        monitor.write(border.vertical)
        monitor.setCursorPos(offsetX + width + 2, offsetY + y + 1)
        monitor.write(border.vertical)
    end

    -- Restore colors
    monitor.setBackgroundColor(oldBg)
    monitor.setTextColor(oldFg)

    return true
end

-----------------------------------------------------------
-- Core API Functions
-----------------------------------------------------------

-- Initialize the mirror display
function MirrorDisplay.initialize(options)
    options = options or {}

    -- Save original terminal reference
    State.originalTerm = term.current()

    -- Get terminal size
    State.termSize.width, State.termSize.height = term.getSize()

    -- Find or validate monitor
    local monitorName = options.monitor
    local monitor = nil

    if monitorName then
        monitor = peripheral.wrap(monitorName)
        if not monitor then
            return handleError("Could not find monitor: " .. tostring(monitorName), "initialize")
        end
    else
        -- Auto-detect first monitor
        monitor = peripheral.find("monitor")
        if not monitor then
            return handleError("No monitor found", "initialize")
        end
    end

    State.monitor = monitor

    -- Apply theme options
    State.theme = {
        background = options.backgroundColor or MirrorDisplay.DEFAULT_THEME.background,
        border = options.borderColor or MirrorDisplay.DEFAULT_THEME.border,
        title = options.titleColor or MirrorDisplay.DEFAULT_THEME.title,
        text = options.textColor or MirrorDisplay.DEFAULT_THEME.text
    }

    -- Set border style
    local borderStyleName = options.borderStyle or "default"
    State.borderStyle = MirrorDisplay.BORDER_STYLES[borderStyleName] or MirrorDisplay.BORDER_STYLES.default

    -- Set title
    State.title = options.title or MirrorDisplay.DEFAULT_TITLE

    -- Set text scale - either use provided value, auto-detect, or default
    local scale = options.scale
    if options.autoScale then
        scale = findOptimalScale(monitor, State.termSize.width, State.termSize.height)
    else
        scale = scale or MirrorDisplay.DEFAULT_SCALE
    end
    monitor.setTextScale(scale)

    -- Clear monitor and set background
    monitor.setBackgroundColor(State.theme.background)
    monitor.clear()

    -- Get monitor dimensions
    State.monitorSize.width, State.monitorSize.height = monitor.getSize()

    -- Calculate frame offsets (for centering)
    local offsetX = math.floor((State.monitorSize.width - State.termSize.width) / 2) - 1
    local offsetY = math.floor((State.monitorSize.height - State.termSize.height) / 2) - 1

    State.frameOffset = { x = offsetX, y = offsetY }

    -- Create window on monitor
    State.window = window.create(
        monitor,
        offsetX + 2, -- +2 to account for border
        offsetY + 2,
        State.termSize.width,
        State.termSize.height,
        true
    )

    -- Initialize window properties
    State.window.setBackgroundColor(State.theme.background)
    State.window.setTextColor(State.theme.text)
    State.window.clear()

    -- Draw initial frame
    drawFrame(monitor, State.termSize.width, State.termSize.height, State.title, offsetX, offsetY)

    -- Try loading TaskMaster if enabled
    if MirrorDisplay.TASK_MASTER_ENABLED then
        tryLoadTaskMaster()
    end

    State.initialized = true
    debugLog("Initialized with monitor " .. peripheral.getName(monitor) .. ", scale " .. scale)

    return true
end

-- Redraw the frame (useful after resizes or theme changes)
function MirrorDisplay.redrawFrame(newTitle)
    if not State.initialized or not State.monitor then
        return handleError("Not initialized", "redrawFrame")
    end

    -- Update title if provided
    if newTitle then
        State.title = newTitle
    end

    -- Call drawing function
    return drawFrame(
        State.monitor,
        State.termSize.width,
        State.termSize.height,
        State.title,
        State.frameOffset.x,
        State.frameOffset.y
    )
end

-- Start mirroring terminal output to the monitor
function MirrorDisplay.start()
    if not State.initialized or not State.monitor or not State.window then
        return handleError("Not initialized", "start")
    end

    -- Create multi terminal that sends output to both screens
    State.multiTerm = createMultiTable(term.current(), State.window)

    -- Redirect terminal output through our multi-terminal
    term.redirect(State.multiTerm)

    -- Mark as active and show window
    MirrorDisplay.active = true
    State.window.setVisible(true)
    State.window.redraw()

    debugLog("Mirroring started")
    return true
end

-- Start auto-refresh using TaskMaster (if available)
function MirrorDisplay.startAutoRefresh(refreshRate)
    if not MirrorDisplay.active then
        return handleError("Mirror not active", "startAutoRefresh")
    end

    if not MirrorDisplay.TASK_MASTER_ENABLED or not TaskMasterIntegration.available then
        debugLog("TaskMaster not available, auto-refresh disabled")
        return false
    end

    -- Update refresh rate if provided
    if refreshRate then
        MirrorDisplay.refreshRate = refreshRate
    end

    -- Stop any existing refresh task
    if TaskMasterIntegration.refreshTask then
        TaskMasterIntegration.refreshTask:remove()
    end

    -- Create a timer that periodically redraws the mirror
    TaskMasterIntegration.refreshTask = TaskMasterIntegration.instance:addTimer(
        MirrorDisplay.refreshRate,
        function()
            if not MirrorDisplay.active then return 0 end -- Stop if no longer active

            pcall(function()
                State.window.redraw()
                MirrorDisplay.redrawFrame()
            end)

            return MirrorDisplay.refreshRate -- Continue with same interval
        end
    )

    State.autoRefresh = true
    debugLog("Auto-refresh started with interval " .. MirrorDisplay.refreshRate)

    return true
end

-- Stop auto-refresh
function MirrorDisplay.stopAutoRefresh()
    if TaskMasterIntegration.refreshTask then
        TaskMasterIntegration.refreshTask:remove()
        TaskMasterIntegration.refreshTask = nil
    end

    State.autoRefresh = false
    return true
end

-- Stop mirroring
function MirrorDisplay.stop()
    if not MirrorDisplay.active then return false end

    -- Stop auto-refresh if active
    if State.autoRefresh then
        MirrorDisplay.stopAutoRefresh()
    end

    -- Restore original terminal
    if State.originalTerm then
        term.redirect(State.originalTerm)
    end

    MirrorDisplay.active = false
    debugLog("Mirroring stopped")

    return true
end

-- Clean up resources
function MirrorDisplay.cleanup()
    MirrorDisplay.stop()

    -- Clear the monitor
    if State.monitor then
        State.monitor.setBackgroundColor(colors.black)
        State.monitor.clear()
    end

    -- Reset state
    State = {
        initialized = false,
        monitor = nil,
        originalTerm = nil,
        window = nil,
        multiTerm = nil,
        frameOffset = { x = 0, y = 0 },
        termSize = { width = 0, height = 0 },
        monitorSize = { width = 0, height = 0 },
        borderStyle = nil,
        autoRefresh = false
    }

    debugLog("Resources cleaned up")
    return true
end

-----------------------------------------------------------
-- Extended API Functions
-----------------------------------------------------------

-- Change border style
function MirrorDisplay.setBorderStyle(styleName)
    if not MirrorDisplay.BORDER_STYLES[styleName] then
        return handleError("Invalid border style: " .. tostring(styleName), "setBorderStyle")
    end

    State.borderStyle = MirrorDisplay.BORDER_STYLES[styleName]

    if MirrorDisplay.active then
        MirrorDisplay.redrawFrame()
    end

    return true
end

-- Set theme colors
function MirrorDisplay.setTheme(theme)
    if type(theme) ~= "table" then
        return handleError("Invalid theme (must be a table)", "setTheme")
    end

    -- Update theme with provided values, keep existing for missing ones
    for k, v in pairs(theme) do
        State.theme[k] = v
    end

    -- Apply text color to window if available
    if State.window and theme.text then
        State.window.setTextColor(theme.text)
    end

    -- Redraw with new theme
    if MirrorDisplay.active then
        MirrorDisplay.redrawFrame()
    end

    return true
end

-- Get current status
function MirrorDisplay.getStatus()
    return {
        active = MirrorDisplay.active,
        initialized = State.initialized,
        autoRefresh = State.autoRefresh,
        title = State.title,
        termSize = {
            width = State.termSize.width,
            height = State.termSize.height
        },
        monitorSize = {
            width = State.monitorSize.width,
            height = State.monitorSize.height
        },
        theme = State.theme,
        taskMaster = {
            enabled = MirrorDisplay.TASK_MASTER_ENABLED,
            available = TaskMasterIntegration.available
        }
    }
end

-- Set title
function MirrorDisplay.setTitle(title)
    State.title = title or ""

    if MirrorDisplay.active then
        MirrorDisplay.redrawFrame()
    end

    return true
end

-----------------------------------------------------------
-- TaskMaster Integration Functions
-----------------------------------------------------------

-- Get the TaskMaster instance if available
function MirrorDisplay.getTaskMaster()
    if not MirrorDisplay.TASK_MASTER_ENABLED then return nil end

    -- Try loading TaskMaster on-demand if needed
    if not tryLoadTaskMaster() then
        return nil
    end

    return TaskMasterIntegration.instance
end

-- Check if TaskMaster integration is available
function MirrorDisplay.isTaskMasterAvailable()
    return MirrorDisplay.TASK_MASTER_ENABLED and TaskMasterIntegration.available
end

-- Enable TaskMaster support (with optional path)
function MirrorDisplay.enableTaskMaster(path)
    MirrorDisplay.TASK_MASTER_ENABLED = true

    if path then
        MirrorDisplay.TASK_MASTER_PATH = path
    end

    return tryLoadTaskMaster()
end

-- Disable TaskMaster support
function MirrorDisplay.disableTaskMaster()
    -- Stop auto-refresh if active
    if State.autoRefresh then
        MirrorDisplay.stopAutoRefresh()
    end

    MirrorDisplay.TASK_MASTER_ENABLED = false
    return true
end

-- Add custom border style
function MirrorDisplay.addBorderStyle(name, style)
    if type(name) ~= "string" or type(style) ~= "table" then
        return handleError("Invalid border style", "addBorderStyle")
    end

    if not style.corner or not style.horizontal or not style.vertical then
        return handleError("Border style must have corner, horizontal, and vertical properties", "addBorderStyle")
    end

    MirrorDisplay.BORDER_STYLES[name] = style
    return true
end

-- Enable or disable debug mode
function MirrorDisplay.setDebug(enabled)
    MirrorDisplay.DEBUG = enabled == true
    return MirrorDisplay.DEBUG
end

return MirrorDisplay
