# PeripheralManager for ComputerCraft

A powerful peripheral management system for ComputerCraft that provides friendly naming, automatic detection, and organization of peripherals.

## Features

- **Friendly Names**: Create and use aliases for peripherals (like "main_monitor" instead of "monitor_0")
- **Peripheral Groups**: Organize related peripherals for batch operations
- **Automatic Detection**: Find peripherals by type without knowing their specific IDs
- **Connection Tracking**: Automatically detect when peripherals connect or disconnect
- **Persistent Configuration**: Save alias and group mappings between system restarts
- **Auto-discovery**: Find and optionally register peripherals of specific types

## Installation

1. Create a `/peripherals` directory in your ComputerCraft computer
2. Copy `PeripheralManager.lua` to your ComputerCraft `/apis` or project directory

Alternatively, you can download directly in ComputerCraft:

```lua
-- Download PeripheralManager
shell.run("wget https://raw.githubusercontent.com/Xylopia24/ComputerCraft-Programs-Repo/main/APIs/PeripheralManager/PeripheralManager.lua /apis/PeripheralManager.lua")
```

## Quick Start

```lua
-- Load the PeripheralManager
local PeripheralManager = require("PeripheralManager") -- or dofile("PeripheralManager.lua")

-- Register friendly names for peripherals
PeripheralManager:registerAlias("main_display", "monitor_0", {
    description = "Main information display"
})

PeripheralManager:registerAlias("storage", "minecraft:barrel_0", {
    description = "Storage inventory"
})

-- Use the friendly names in your code
local display = PeripheralManager:getPeripheral("main_display")
if display then
    display.clear()
    display.setCursorPos(1, 1)
    display.write("Hello from PeripheralManager!")
end

-- Create a group of related peripherals
PeripheralManager:createGroup("monitors", {"main_display", "status_display"})

-- Find peripherals by type
local printer = PeripheralManager:findPeripheralByType("printer")
if printer then
    printer.write("Found a printer automatically!")
    printer.endPage()
end
```

## API Reference

### Peripheral Registration and Access

```lua
-- Register a friendly name for a peripheral
PeripheralManager:registerAlias("aliasName", "peripheralID", options)
-- Options can include: description, group, autoReconnect, type

-- Unregister a peripheral alias
PeripheralManager:unregisterAlias("aliasName")

-- Get a peripheral by its alias
local peripheral = PeripheralManager:getPeripheral("aliasName")

-- Check if a peripheral alias exists
local exists = PeripheralManager:aliasExists("aliasName")

-- Check if a peripheral is connected
local connected = PeripheralManager:isConnected("aliasName")
```

### Peripheral Groups

```lua
-- Create or update a group
PeripheralManager:createGroup("groupName", {"alias1", "alias2", ...})

-- Remove a group
PeripheralManager:removeGroup("groupName")

-- Get all peripherals in a group
local groupPeripherals = PeripheralManager:getGroup("groupName")
```

### Peripheral Discovery

```lua
-- Get all peripherals of a specific type
local peripherals = PeripheralManager:getPeripheralsByType("monitor")

-- Find a peripheral by type (with optional auto-registration)
local peripheral, id = PeripheralManager:findPeripheralByType("monitor", {
    autoRegister = true,
    description = "Auto-discovered monitor",
    group = "displays"
})
```

### Information and Management

```lua
-- List all available peripherals
local peripherals = PeripheralManager:listPeripherals()

-- List all registered aliases
local aliases = PeripheralManager:listAliases()

-- List all peripheral groups
local groups = PeripheralManager:listGroups()

-- Get the alias of a peripheral by its ID
local alias = PeripheralManager:getAliasByID("monitor_0")

-- Rescan for all connected peripherals
PeripheralManager:scanPeripherals()

-- Reset all peripheral aliases and groups
PeripheralManager:reset()
```

## Configuration

You can configure PeripheralManager by modifying these properties:

```lua
-- Change configuration directory
PeripheralManager.CONFIG_DIR = "/custom/peripherals/path"

-- Change configuration filename
PeripheralManager.CONFIG_FILE = "custom_mappings.json"
```

## Examples

### Basic Peripheral Management

```lua
local PeripheralManager = require("PeripheralManager")

-- Register peripherals with descriptive names
PeripheralManager:registerAlias("farm_controller", "minecraft:computer_0", {
    description = "Farm automation controller"
})

PeripheralManager:registerAlias("item_storage", "minecraft:barrel_0", {
    description = "Main item storage"
})

-- Check if peripherals are connected
if PeripheralManager:isConnected("farm_controller") then
    print("Farm controller is connected")
else
    print("Farm controller is disconnected")
end

-- Use peripherals by friendly name
local storage = PeripheralManager:getPeripheral("item_storage")
if storage then
    local items = storage.list()
    print("Storage contains " .. #items .. " item stacks")
end
```

### Managing Multiple Monitors

```lua
local PeripheralManager = require("PeripheralManager")

-- Set up multiple monitors
PeripheralManager:registerAlias("status_display", "monitor_0", {
    description = "Status information display"
})

PeripheralManager:registerAlias("inventory_display", "monitor_1", {
    description = "Inventory display"
})

-- Create a group for all displays
PeripheralManager:createGroup("displays", {"status_display", "inventory_display"})

-- Function to clear all displays
function clearAllDisplays()
    local displays = PeripheralManager:getGroup("displays")
    for name, monitor in pairs(displays) do
        monitor.clear()
        monitor.setCursorPos(1, 1)
        print("Cleared " .. name)
    end
end

-- Function to broadcast an alert to all displays
function broadcastAlert(message)
    local displays = PeripheralManager:getGroup("displays")
    for name, monitor in pairs(displays) do
        monitor.clear()
        monitor.setTextColor(colors.red)
        monitor.setCursorPos(1, 1)
        monitor.write("ALERT: " .. message)
    end
end

-- Usage
clearAllDisplays()
broadcastAlert("System maintenance in 5 minutes")
```

### Auto-Discovery of Peripherals

```lua
local PeripheralManager = require("PeripheralManager")

-- Find peripherals without knowing their specific IDs
function findAndSetupPeripherals()
    -- Find a modem for network communication
    local modem, modemAlias = PeripheralManager:findPeripheralByType("modem", {
        autoRegister = true,
        description = "Network communication"
    })

    if modem then
        print("Found modem at " .. modemAlias)
        modem.open(1) -- Open channel 1
    end

    -- Find storage devices
    local storageDevices = PeripheralManager:getPeripheralsByType("minecraft:barrel")
    print("Found " .. table.maxn(storageDevices) .. " storage devices")

    for id, storage in pairs(storageDevices) do
        local alias = "storage_" .. os.clock():gsub("%.", "")
        PeripheralManager:registerAlias(alias, id, {
            description = "Storage container",
            group = "storage"
        })
        print("Registered " .. id .. " as " .. alias)
    end
end

findAndSetupPeripherals()
```

### Handling Peripheral Disconnections

```lua
local PeripheralManager = require("PeripheralManager")

-- Set up a monitor
PeripheralManager:registerAlias("info_display", "monitor_0")

-- Function that gracefully handles peripheral disconnections
function updateDisplay(message)
    if PeripheralManager:isConnected("info_display") then
        local monitor = PeripheralManager:getPeripheral("info_display")
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.write(message)
        return true
    else
        print("Warning: Display not connected. Message was: " .. message)
        return false
    end
end

-- Continuous monitoring with fallback behavior
while true do
    local status = "System status: " .. os.date()

    -- Try to update display, fall back to console
    if not updateDisplay(status) then
        -- Try to find another monitor
        local newMonitor = PeripheralManager:findPeripheralByType("monitor", {
            autoRegister = true,
            description = "Replacement display"
        })

        if newMonitor then
            print("Found new monitor! Switching to it.")
        end
    end

    sleep(5)
end
```

## Best Practices

1. **Use Descriptive Aliases**:

   - Choose clear, descriptive names that explain the purpose of the peripheral
   - Example: "inventory_reader" instead of "reader1"
   - Use consistent naming conventions across your system

2. **Organize with Groups**:

   - Group related peripherals together (e.g., "displays", "storage", "sensors")
   - Use groups for batch operations on multiple peripherals
   - Keep group membership updated when changing your setup

3. **Handle Disconnections Gracefully**:

   - Always check if a peripheral is connected before using it
   - Provide fallback behavior for disconnected peripherals
   - Use `isConnected()` to verify status before performing actions

4. **Leverage Auto-Discovery**:

   - Use type-based discovery to make your code more portable
   - Consider auto-registration for plug-and-play functionality
   - Fall back to manual peripheral IDs only when necessary

5. **Secure Advanced Peripherals**:
   - Be especially careful with modems and other security-sensitive peripherals
   - Consider creating a separate group for secure peripherals
   - Implement additional authentication for critical operations

## License

[MIT License](LICENSE)
