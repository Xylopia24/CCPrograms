# ThemeManager for ComputerCraft

A powerful and flexible theme manager for ComputerCraft terminals, allowing you to create, save, and switch between custom color themes with semantic UI mapping.

## Features

- **Terminal Themes**: Customize all 16 ComputerCraft colors
- **Theme Organization**: Support for categorizing themes in subdirectories
- **UI Element Mapping**: Map semantic UI elements to specific colors for consistent interfaces
- **Theme Preview**: Preview themes before applying them
- **Hex Color Support**: Convert between hex colors and ComputerCraft's RGB format
- **Default Theme**: Includes a built-in default theme

## Installation

1. Create a `/themes` directory in your ComputerCraft computer
2. Copy `ThemeManager.lua` to your ComputerCraft `/apis` or project directory
3. Copy `DEFAULT.json` to your `/themes` directory

Alternatively, you can download directly in ComputerCraft:

```lua
-- Download ThemeManager
shell.run("wget https://raw.githubusercontent.com/Xylopia24/ComputerCraft-Programs-Repo/main/APIs/ThemeManager/ThemeManager.lua /apis/ThemeManager.lua")
shell.run("wget https://raw.githubusercontent.com/Xylopia24/ComputerCraft-Programs-Repo/main/APIs/ThemeManager/DEFAULT.json /themes/DEFAULT.json")
```

## Quick Start

```lua
-- Load the ThemeManager
local ThemeManager = require("ThemeManager") -- or dofile("ThemeManager.lua")

-- Apply the default theme
ThemeManager:applyTheme("DEFAULT")

-- List available themes
local themes = ThemeManager:getThemeNames()
for name, info in pairs(themes) do
    print(name .. " by " .. info.author)
end

-- Create and save a custom theme
term.setPaletteColor(colors.black, 0.1, 0.1, 0.15) -- Dark navy background
term.setPaletteColor(colors.white, 0.9, 0.95, 1.0) -- Slightly blue-tinted text
ThemeManager:saveCurrentTheme("CUSTOM/NIGHTSKY")

-- Preview a theme
ThemeManager:previewTheme("CUSTOM/NIGHTSKY")

-- Apply a theme
ThemeManager:applyTheme("CUSTOM/NIGHTSKY")
```

## Theme File Structure

Themes are stored as JSON files with the following structure:

```json
{
  "meta": {
    "name": "Theme Name",
    "author": "Author Name",
    "description": "Theme description text",
    "version": "1.0.0"
  },
  "colors": {
    "white": "#FFFFFF",
    "orange": "#F2B233",
    "magenta": "#E57FD8",
    "lightBlue": "#99B2F2",
    "yellow": "#DEDE6C",
    "lime": "#7FCC19",
    "pink": "#F2B2CC",
    "gray": "#4C4C4C",
    "lightGray": "#999999",
    "cyan": "#4C99B2",
    "purple": "#B266E5",
    "blue": "#3366CC",
    "brown": "#7F664C",
    "green": "#57A64E",
    "red": "#CC4C4C",
    "black": "#111111"
  },
  "gui": {
    "background": "black",
    "text": "white",
    "header": "blue",
    "accent": "purple",
    "highlight": "lightGray",
    "error": "red",
    "success": "green",
    "warning": "yellow",
    "info": "cyan",
    "disabled": "gray",
    "border": "gray"
  }
}
```

## UI Element Mapping

ThemeManager provides semantic UI element mapping to create consistent interfaces:

```lua
-- Create UI functions using semantic colors
function drawHeader(text)
    term.setBackgroundColor(ThemeManager:getUIColor("header"))
    term.setTextColor(ThemeManager:getUIColor("text"))
    term.clearLine()
    term.write(text)
end

function showError(message)
    term.setTextColor(ThemeManager:getUIColor("error"))
    print("ERROR: " .. message)
    term.setTextColor(ThemeManager:getUIColor("text"))
end

-- These functions will automatically adapt to any active theme
drawHeader("System Status")
if not systemOK then
    showError("Connection lost")
end
```

## API Reference

### Basic Theme Operations

```lua
-- Apply a theme
ThemeManager:applyTheme("themeName")
ThemeManager:applyTheme("category/themeName")  -- Using subdirectory structure

-- Reset to default theme
ThemeManager:resetToDefault()

-- Get current theme
local currentTheme = ThemeManager:getCurrentTheme()

-- Get available themes
local themes = ThemeManager:getThemeNames()
```

### Theme Creation and Management

```lua
-- Save current terminal colors as a theme
ThemeManager:saveCurrentTheme("myTheme")
ThemeManager:saveCurrentTheme("category/myTheme")  -- Save to subdirectory

-- Preview a theme without applying it
ThemeManager:previewTheme("themeName")

-- Preview with custom display function
ThemeManager:previewTheme("themeName", function()
    -- Custom display code here
end)
```

### Color Utilities

```lua
-- Convert hex color to RGB components (0-1 range)
local r, g, b = ThemeManager:hexToRGB("#FF5500")

-- Convert RGB components to hex color
local hexColor = ThemeManager:rgbToHex(1.0, 0.5, 0.2)

-- Get current palette as a theme object
local currentColors = ThemeManager:getCurrentPalette()
```

### Theme Organization

```lua
-- Get list of theme categories (folders)
local categories = ThemeManager:getThemeCategories()

-- Get themes in a specific category
local themesByCategory = ThemeManager:getThemesByCategory("CUSTOM")
```

### UI Element Color Mapping

```lua
-- Get color for a semantic UI element
local bgColor = ThemeManager:getUIColor("background")
local textColor = ThemeManager:getUIColor("header")

-- Get default UI element color (fallback)
local defaultColor = ThemeManager:getDefaultUIColor("border")
```

## Configuration

You can configure ThemeManager by modifying these properties:

```lua
-- Change themes directory
ThemeManager.THEMES_DIR = "/custom/themes/path"

-- Change default theme
ThemeManager.defaultTheme = "MY_DEFAULT"

-- Define custom UI element mappings
ThemeManager.defaultUI.accent = "cyan" -- Change default accent color
```

## Examples

### Creating a Theme Switcher

```lua
local ThemeManager = require("ThemeManager")

function displayThemeMenu()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Theme Selector ===")

    local themes = ThemeManager:getThemeNames()
    local themeList = {}
    local i = 1

    for name, info in pairs(themes) do
        print(i .. ": " .. info.name .. " by " .. info.author)
        themeList[i] = name
        i = i + 1
    end

    print("\nEnter number to preview, 'q' to quit:")
    while true do
        local input = read()
        if input == "q" then break end
        local num = tonumber(input)
        if num and themeList[num] then
            ThemeManager:previewTheme(themeList[num])
            print("Apply this theme? (y/n)")
            if read() == "y" then
                ThemeManager:applyTheme(themeList[num])
                print("Theme applied! Press any key...")
                os.pullEvent("key")
            end
            displayThemeMenu()
            break
        end
    end
end

displayThemeMenu()
```

### Creating Consistent UI Elements

```lua
local ThemeManager = require("ThemeManager")
ThemeManager:applyTheme("DEFAULT")

local UI = {
    drawBox = function(x, y, width, height)
        local bg = ThemeManager:getUIColor("background")
        local border = ThemeManager:getUIColor("border")

        -- Draw border
        term.setBackgroundColor(bg)
        term.setTextColor(border)

        -- Top border
        term.setCursorPos(x, y)
        term.write("+" .. string.rep("-", width-2) .. "+")

        -- Sides
        for i = 1, height-2 do
            term.setCursorPos(x, y+i)
            term.write("|")
            term.setCursorPos(x+width-1, y+i)
            term.write("|")
        end

        -- Bottom border
        term.setCursorPos(x, y+height-1)
        term.write("+" .. string.rep("-", width-2) .. "+")
    end,

    drawButton = function(x, y, text, active)
        local bg = active and ThemeManager:getUIColor("accent") or ThemeManager:getUIColor("disabled")
        local fg = ThemeManager:getUIColor("text")

        term.setCursorPos(x, y)
        term.setBackgroundColor(bg)
        term.setTextColor(fg)
        term.write(" " .. text .. " ")
    end,

    showMessage = function(message, type)
        local color = ThemeManager:getUIColor(type or "info")
        term.setTextColor(color)
        print(message)
        term.setTextColor(ThemeManager:getUIColor("text"))
    end
}

-- Usage:
term.setBackgroundColor(ThemeManager:getUIColor("background"))
term.clear()

UI.drawBox(3, 3, 20, 10)
UI.drawButton(5, 5, "Save", true)
UI.drawButton(15, 5, "Cancel", false)
UI.showMessage("Operation successful!", "success")
UI.showMessage("Warning: Low disk space", "warning")
UI.showMessage("Error: Connection failed", "error")
```

## License

[MIT License](LICENSE)
