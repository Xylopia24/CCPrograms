-- PeripheralManager: A comprehensive peripheral management system for ComputerCraft
-- Provides friendly naming, automatic detection, and organization of peripherals

local PeripheralManager = {
    -- Configuration (can be modified by users)
    CONFIG_DIR = "/peripherals",
    CONFIG_FILE = "mappings.json",
    peripherals = {}, -- Currently connected peripherals
    aliases = {},     -- Friendly names for peripherals
    groups = {}       -- Groups of peripherals
}

-- Initialize the peripheral manager
function PeripheralManager:init()
    -- Create config directory if it doesn't exist
    if not fs.exists(self.CONFIG_DIR) then
        fs.makeDir(self.CONFIG_DIR)
    end

    -- Load peripheral mappings from storage
    self:loadMappings()

    -- Initial scan of all connected peripherals
    self:scanPeripherals()

    -- Monitor peripheral attach and detach events
    self:startEventListener()

    return self
end

-- Built-in JSON handling for config files
function PeripheralManager:readJSON(path)
    if not fs.exists(path) then
        return nil
    end

    local file = fs.open(path, "r")
    local content = file.readAll()
    file.close()

    -- Use textutils to parse JSON
    return textutils.unserializeJSON(content)
end

function PeripheralManager:writeJSON(path, data)
    local file = fs.open(path, "w")
    local content = textutils.serializeJSON(data, true) -- true for pretty printing
    file.write(content)
    file.close()
    return true
end

-- Load peripheral mappings from storage
function PeripheralManager:loadMappings()
    local configPath = fs.combine(self.CONFIG_DIR, self.CONFIG_FILE)
    local data = self:readJSON(configPath)

    if data then
        self.aliases = data.aliases or {}
        self.groups = data.groups or {}
        print("[PeripheralManager] Loaded peripheral mappings")
    else
        self.aliases = {}
        self.groups = {}
        print("[PeripheralManager] No peripheral mappings found, using defaults")
    end
end

-- Save peripheral mappings to storage
function PeripheralManager:saveMappings()
    local configPath = fs.combine(self.CONFIG_DIR, self.CONFIG_FILE)
    local data = {
        aliases = self.aliases,
        groups = self.groups
    }

    local success = self:writeJSON(configPath, data)
    if success then
        print("[PeripheralManager] Saved peripheral mappings")
    else
        print("[PeripheralManager] Failed to save peripheral mappings")
    end
    return success
end

-- Scan for all connected peripherals
function PeripheralManager:scanPeripherals()
    self.peripherals = {}
    local sides = peripheral.getNames()

    for _, name in ipairs(sides) do
        local periph = peripheral.wrap(name)
        if periph then
            local periphType = peripheral.getType(name)
            local entry = {
                id = name,
                type = periphType,
                object = periph
            }

            self.peripherals[name] = entry
            print("[PeripheralManager] Found " .. periphType .. " at " .. name)
        end
    end

    -- Update status of aliased peripherals (mark as disconnected if not found)
    for alias, mapping in pairs(self.aliases) do
        if not self.peripherals[mapping.id] then
            mapping.connected = false
        else
            mapping.connected = true
        end
    end
end

-- Start listening for peripheral events
function PeripheralManager:startEventListener()
    local function handleEvent()
        while true do
            local event, side = os.pullEvent()

            if event == "peripheral" then
                -- Peripheral connected
                local periphType = peripheral.getType(side)
                local periph = peripheral.wrap(side)

                self.peripherals[side] = {
                    id = side,
                    type = periphType,
                    object = periph
                }

                -- Update status of aliased peripheral if this matches
                for alias, mapping in pairs(self.aliases) do
                    if mapping.id == side then
                        mapping.connected = true
                        print("[PeripheralManager] Peripheral " .. alias .. " (" .. side .. ") reconnected")
                    end
                end

                print("[PeripheralManager] Peripheral connected: " .. periphType .. " at " .. side)
            elseif event == "peripheral_detach" then
                -- Peripheral disconnected
                local periph = self.peripherals[side]
                if periph then
                    self.peripherals[side] = nil

                    -- Update status of aliased peripheral if this matches
                    for alias, mapping in pairs(self.aliases) do
                        if mapping.id == side then
                            mapping.connected = false
                            print("[PeripheralManager] Peripheral " .. alias .. " (" .. side .. ") disconnected")
                        end
                    end

                    print("[PeripheralManager] Peripheral disconnected: " .. side)
                end
            end
        end
    end

    -- Run the event handler in a separate coroutine
    local co = coroutine.create(handleEvent)
    coroutine.resume(co)
end

-- Register a peripheral alias
function PeripheralManager:registerAlias(alias, peripheralID, options)
    if not alias or not peripheralID then
        print("[PeripheralManager] Invalid alias or peripheral ID")
        return false
    end

    options = options or {}

    -- Check if the peripheral exists
    local periph = peripheral.wrap(peripheralID)
    if not periph then
        print("[PeripheralManager] Warning: Registering alias for non-connected peripheral: " .. peripheralID)
    end

    -- Create the alias mapping
    self.aliases[alias] = {
        id = peripheralID,
        type = periph and peripheral.getType(peripheralID) or options.type,
        description = options.description or "",
        group = options.group,
        connected = periph ~= nil,
        autoReconnect = options.autoReconnect == nil and true or options.autoReconnect
    }

    -- Add to group if specified
    if options.group then
        self.groups[options.group] = self.groups[options.group] or {}
        self.groups[options.group][alias] = true
    end

    -- Save the updated mappings
    self:saveMappings()

    print("[PeripheralManager] Registered alias: " .. alias .. " -> " .. peripheralID)
    return true
end

-- Unregister a peripheral alias
function PeripheralManager:unregisterAlias(alias)
    if not self.aliases[alias] then
        print("[PeripheralManager] Alias not found: " .. alias)
        return false
    end

    -- Remove from group if it's in one
    local group = self.aliases[alias].group
    if group and self.groups[group] then
        self.groups[group][alias] = nil

        -- Clean up empty groups
        if not next(self.groups[group]) then
            self.groups[group] = nil
        end
    end

    -- Remove the alias
    self.aliases[alias] = nil

    -- Save the updated mappings
    self:saveMappings()

    print("[PeripheralManager] Unregistered alias: " .. alias)
    return true
end

-- Get a peripheral by its alias
function PeripheralManager:getPeripheral(alias)
    local mapping = self.aliases[alias]
    if not mapping then
        return nil
    end

    -- Try to get the peripheral
    local periph = peripheral.wrap(mapping.id)

    -- Update connected status
    if periph then
        mapping.connected = true
    else
        mapping.connected = false
    end

    return periph
end

-- Get all peripherals of a specific type
function PeripheralManager:getPeripheralsByType(periphType)
    local result = {}

    -- Check all connected peripherals
    for name, data in pairs(self.peripherals) do
        if data.type == periphType then
            result[name] = data.object
        end
    end

    return result
end

-- Get all peripherals in a group
function PeripheralManager:getGroup(groupName)
    local result = {}
    local group = self.groups[groupName]

    if not group then
        return result
    end

    -- Get each peripheral in the group
    for alias in pairs(group) do
        local periph = self:getPeripheral(alias)
        if periph then
            result[alias] = periph
        end
    end

    return result
end

-- Create a group of peripherals
function PeripheralManager:createGroup(groupName, aliases)
    if not groupName then
        print("[PeripheralManager] Invalid group name")
        return false
    end

    -- Create or update the group
    self.groups[groupName] = self.groups[groupName] or {}

    -- Add aliases to the group
    if aliases then
        for _, alias in ipairs(aliases) do
            if self.aliases[alias] then
                self.groups[groupName][alias] = true
                self.aliases[alias].group = groupName
            else
                print("[PeripheralManager] Warning: Alias not found for group: " .. alias)
            end
        end
    end

    -- Save the updated mappings
    self:saveMappings()

    print("[PeripheralManager] Created/updated group: " .. groupName)
    return true
end

-- Remove a group
function PeripheralManager:removeGroup(groupName)
    if not self.groups[groupName] then
        print("[PeripheralManager] Group not found: " .. groupName)
        return false
    end

    -- Remove group reference from all aliases in the group
    for alias in pairs(self.groups[groupName]) do
        if self.aliases[alias] then
            self.aliases[alias].group = nil
        end
    end

    -- Remove the group
    self.groups[groupName] = nil

    -- Save the updated mappings
    self:saveMappings()

    print("[PeripheralManager] Removed group: " .. groupName)
    return true
end

-- Get the alias of a peripheral by its ID
function PeripheralManager:getAliasByID(peripheralID)
    for alias, mapping in pairs(self.aliases) do
        if mapping.id == peripheralID then
            return alias
        end
    end
    return nil
end

-- Find a peripheral by type if it's not already aliased
-- Useful for automatically finding and using peripherals
function PeripheralManager:findPeripheralByType(periphType, options)
    options = options or {}

    -- Check if we already have an alias for this type
    for alias, mapping in pairs(self.aliases) do
        if mapping.type == periphType and (not options.group or mapping.group == options.group) then
            local periph = self:getPeripheral(alias)
            if periph then
                return periph, alias
            end
        end
    end

    -- Find a peripheral of this type that isn't aliased yet
    for name, data in pairs(self.peripherals) do
        if data.type == periphType then
            local isAliased = false
            for _, mapping in pairs(self.aliases) do
                if mapping.id == name then
                    isAliased = true
                    break
                end
            end

            if not isAliased then
                -- Auto-register if specified
                if options.autoRegister then
                    local alias = periphType .. "_" .. os.clock():gsub("%.", "")
                    self:registerAlias(alias, name, {
                        description = options.description or "Auto-registered " .. periphType,
                        group = options.group,
                        autoReconnect = options.autoReconnect
                    })
                    return data.object, alias
                end

                return data.object, name
            end
        end
    end

    return nil
end

-- List all available peripherals with their IDs and types
function PeripheralManager:listPeripherals()
    local result = {}

    for name, data in pairs(self.peripherals) do
        local alias = self:getAliasByID(name)
        result[name] = {
            type = data.type,
            alias = alias
        }
    end

    return result
end

-- List all registered aliases
function PeripheralManager:listAliases()
    local result = {}

    for alias, mapping in pairs(self.aliases) do
        result[alias] = {
            id = mapping.id,
            type = mapping.type,
            description = mapping.description,
            group = mapping.group,
            connected = mapping.connected
        }
    end

    return result
end

-- List all groups with their aliases
function PeripheralManager:listGroups()
    local result = {}

    for group, aliases in pairs(self.groups) do
        result[group] = {}
        for alias in pairs(aliases) do
            result[group][alias] = self.aliases[alias]
        end
    end

    return result
end

-- Check if a peripheral alias exists
function PeripheralManager:aliasExists(alias)
    return self.aliases[alias] ~= nil
end

-- Check if a peripheral alias is connected
function PeripheralManager:isConnected(alias)
    local mapping = self.aliases[alias]
    if not mapping then
        return false
    end

    -- Check current connection status
    local connected = peripheral.isPresent(mapping.id)
    mapping.connected = connected
    return connected
end

-- Reset all peripheral aliases and groups
function PeripheralManager:reset()
    self.aliases = {}
    self.groups = {}
    self:saveMappings()
    print("[PeripheralManager] Reset all peripheral mappings")
    return true
end

-- Initialize on require
return PeripheralManager:init()
