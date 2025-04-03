# DataManager

A comprehensive data management library for ComputerCraft that handles multiple file formats with a consistent API.

## Features

- Multiple data formats supported:
  - **JSON** - For interoperability and complex data structures
  - **Lua tables** - For maximum performance and native Lua integration
  - **Metadata/INI** - For simple, human-editable configuration files
- Directory management with automatic folder creation
- Customizable data directories and subdirectory support
- Pretty formatting for all saved files
- Type conversion between Lua and stored formats

## Installation

1. Download `DataManager.lua` to your ComputerCraft computer
2. Place it in a folder where you keep your APIs (e.g., `/apis`)
3. Use `require` or `dofile` to include it in your programs

```lua
-- Using require (recommended):
local DataManager = require("apis.DataManager")

-- OR using dofile:
local DataManager = dofile("apis/DataManager.lua")
```

## Configuration

By default, DataManager stores files in the `/data` directory. You can customize this:

```lua
-- Change the base data directory
DataManager:setDataDir("/myapp/storage")

-- Change the default file format (default is "json")
DataManager:setDefaultEncoding("lua")
```

## Basic Usage

### Reading and Writing Data

The simplest way to use DataManager is with the generic read/write methods:

```lua
-- Save data (format determined by file extension)
local myData = {name = "John", age = 25, items = {"sword", "shield"}}
DataManager:write("playerdata.json", myData)
DataManager:write("config.lua", myData)
DataManager:write("settings.meta", myData)

-- Read data (format determined by file extension)
local fromJson = DataManager:read("playerdata.json")
local fromLua = DataManager:read("config.lua")
local fromMeta = DataManager:read("settings.meta")
```

### Using Subdirectories

Organize your data in folders:

```lua
-- Store in subdirectories
DataManager:write("player.json", playerData, "players/" .. playerName)
DataManager:write("region.json", worldData, "world/regions")

-- Load from subdirectories
local playerData = DataManager:read("player.json", "players/" .. playerName)
```

### Format-Specific API

You can also use format-specific methods when needed:

```lua
-- JSON
DataManager:writeJSON("settings", data)
local data = DataManager:readJSON("settings")

-- Lua tables
DataManager:writeLua("config", data)
local data = DataManager:readLua("config")

-- Metadata/INI
DataManager:writeMeta("profile", data)
local data = DataManager:readMeta("profile")
```

### Manual Encoding/Decoding

For advanced use cases, you can manually encode/decode without file operations:

```lua
-- JSON string encoding/decoding
local jsonString = DataManager:encodeJSON(data)
local data = DataManager:decodeJSON(jsonString)

-- Convert Lua value to code string
local luaCode = DataManager:valueToLuaCode(data)

-- Parse metadata value
local typed = DataManager:parseMetaValue("123")  -- returns number 123
```

## Data Format Examples

### JSON Format

```json
{
  "name": "Test User",
  "level": 42,
  "inventory": ["sword", "shield", "potion"],
  "stats": {
    "health": 100,
    "mana": 50
  }
}
```

### Lua Table Format

```lua
return {
    name = "Test User",
    level = 42,
    inventory = {
        "sword",
        "shield",
        "potion",
    },
    stats = {
        health = 100,
        mana = 50,
    },
}
```

### Metadata/INI Format

```ini
name = Test User
level = 42

[ inventory ]
item1 = sword
item2 = shield
item3 = potion

[ stats ]
health = 100
mana = 50
```

## API Reference

### Configuration

- `DataManager:setDataDir(path)` - Set base directory for data files
- `DataManager:setDefaultEncoding(type)` - Set default file format

### File Operations

- `DataManager:read(filename, subDir)` - Read data from file (auto-detects format)
- `DataManager:write(filename, data, subDir)` - Write data to file (auto-detects format)
- `DataManager:getPath(filename, type, subDir)` - Get full path for a file
- `DataManager:ensureDataDir(subDir)` - Create directory if it doesn't exist

### JSON Functions

- `DataManager:readJSON(filename, subDir)` - Read JSON data from file
- `DataManager:writeJSON(filename, data, subDir)` - Write data as JSON
- `DataManager:encodeJSON(data)` - Convert data to JSON string
- `DataManager:decodeJSON(json)` - Parse JSON string to data

### Lua Table Functions

- `DataManager:readLua(filename, subDir)` - Read Lua table from file
- `DataManager:writeLua(filename, data, subDir)` - Write data as Lua table
- `DataManager:valueToLuaCode(value)` - Convert value to Lua code string

### Metadata Functions

- `DataManager:readMeta(filename, subDir)` - Read metadata from file
- `DataManager:writeMeta(filename, data, subDir)` - Write data as metadata
- `DataManager:parseMetaValue(value)` - Convert string to appropriate type

## Best Practices

1. **Choose the Right Format:**

   - Use JSON for data shared with other systems
   - Use Lua tables for best performance and complex data
   - Use metadata for simple configuration files

2. **Organize with Subdirectories:**

   - Group related data in meaningful folders
   - Consider using namespaced paths (e.g., "players/john/inventory")

3. **Error Handling:**

   ```lua
   -- Check for nil return values
   local data = DataManager:read("config.json")
   if not data then
       print("Config file not found, creating default")
       data = {setting = "default"}
       DataManager:write("config.json", data)
   end
   ```

4. **Performance Tips:**
   - Cache frequently accessed data in memory
   - For large files, use Lua format instead of JSON
   - Consider breaking very large datasets into multiple files

## License

This library is provided as-is, free to use and modify.
