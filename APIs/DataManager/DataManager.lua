local DataManager = {
    -- Configuration (more generic defaults)
    DATA_DIR = "/data",
    DEFAULT_ENCODING = "json"
}

-- Set custom data directory
function DataManager:setDataDir(path)
    self.DATA_DIR = path
    return self
end

-- Set default encoding
function DataManager:setDefaultEncoding(encoding)
    self.DEFAULT_ENCODING = encoding
    return self
end

-- Ensure data directory exists
function DataManager:ensureDataDir(subDir)
    local path = self.DATA_DIR

    if subDir then
        path = fs.combine(path, subDir)
    end

    if not fs.exists(path) then
        fs.makeDir(path)
    end

    return path
end

-- Get full path for a data file
function DataManager:getPath(filename, type, subDir)
    type = type or self.DEFAULT_ENCODING
    -- Ensure file has correct extension
    if not filename:match("%." .. type .. "$") then
        filename = filename .. "." .. type
    end

    local basePath = self.DATA_DIR
    if subDir then
        basePath = fs.combine(basePath, subDir)
    end

    return fs.combine(basePath, filename)
end

------------------------------------------
-- JSON Functions
------------------------------------------

-- Pretty JSON encoder with indentation
function DataManager:encodeJSON(data, level)
    level = level or 0
    local indent = string.rep("    ", level)
    local nextIndent = string.rep("    ", level + 1)

    if type(data) == "table" then
        -- Handle arrays (numeric keys) vs objects (string keys)
        local isArray = true
        local maxIndex = 0
        for k, v in pairs(data) do
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        if isArray and maxIndex > #data then
            isArray = false -- Sparse array should be treated as object
        end

        -- Empty table check
        local isEmpty = true
        for _ in pairs(data) do
            isEmpty = false
            break
        end

        if isEmpty then
            return isArray and "[]" or "{}"
        end

        local result = ""

        if isArray then
            result = "[\n"
            for i, v in ipairs(data) do
                result = result .. nextIndent .. self:encodeJSON(v, level + 1)
                if i < #data then
                    result = result .. ","
                end
                result = result .. "\n"
            end
            result = result .. indent .. "]"
        else
            result = "{\n"
            local first = true
            for k, v in pairs(data) do
                if not first then
                    result = result .. ",\n"
                else
                    first = false
                end
                result = result .. nextIndent .. '"' .. tostring(k) .. '": ' .. self:encodeJSON(v, level + 1)
            end
            result = result .. "\n" .. indent .. "}"
        end

        return result
    elseif type(data) == "string" then
        -- Escape special characters
        local escaped = data:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
        return '"' .. escaped .. '"'
    elseif type(data) == "number" then
        return tostring(data)
    elseif type(data) == "boolean" then
        return data and "true" or "false"
    elseif data == nil then
        return "null"
    else
        return '"' .. tostring(data) .. '"' -- Convert other types to string
    end
end

-- Fixed JSON decoder
function DataManager:decodeJSON(json)
    -- Basic JSON parser with proper scope
    local pos = 1

    -- Trim whitespace
    json = json:gsub("^%s*(.-)%s*$", "%1")

    -- Forward declarations for mutual recursion
    local parseValue, parseObject, parseArray, parseString, parseNumber

    parseValue = function()
        local char = json:sub(pos, pos)

        if char == "{" then
            return parseObject()
        elseif char == "[" then
            return parseArray()
        elseif char == '"' then
            return parseString()
        elseif char:match("[%d%-]") then
            return parseNumber()
        elseif json:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif json:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif json:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end

        error("Invalid JSON at position " .. pos .. ": " .. json:sub(pos, pos + 10))
    end

    parseObject = function()
        local obj = {}
        pos = pos + 1 -- Skip '{'

        -- Handle empty object
        if json:sub(pos, pos):match("%s*") and json:sub(pos, pos):match("%s*"):find("}") then
            -- Skip whitespace until }
            while pos <= #json and json:sub(pos, pos) ~= "}" do
                pos = pos + 1
            end
            pos = pos + 1 -- Skip '}'
            return obj
        end

        -- Skip whitespace after {
        while pos <= #json and json:sub(pos, pos):match("%s") do
            pos = pos + 1
        end

        -- Handle empty object with whitespace
        if pos <= #json and json:sub(pos, pos) == "}" then
            pos = pos + 1
            return obj
        end

        while true do
            -- Skip whitespace
            while pos <= #json and json:sub(pos, pos):match("%s") do
                pos = pos + 1
            end

            -- Expect string key
            if json:sub(pos, pos) ~= '"' then
                error("Expected string key in object at position " .. pos)
            end

            local key = parseString()

            -- Skip whitespace before colon
            while pos <= #json and json:sub(pos, pos):match("%s") do
                pos = pos + 1
            end

            -- Expect colon
            if json:sub(pos, pos) ~= ":" then
                error("Expected ':' after key in object at position " .. pos)
            end
            pos = pos + 1

            -- Skip whitespace after colon
            while pos <= #json and json:sub(pos, pos):match("%s") do
                pos = pos + 1
            end

            -- Parse value
            local value = parseValue()
            obj[key] = value

            -- Skip whitespace after value
            while pos <= #json and json:sub(pos, pos):match("%s") do
                pos = pos + 1
            end

            -- Check for end of object or next pair
            local nextChar = json:sub(pos, pos)
            if nextChar == "}" then
                pos = pos + 1
                break
            elseif nextChar == "," then
                pos = pos + 1
                -- Continue to next iteration
            else
                error("Expected ',' or '}' in object at position " .. pos)
            end
        end

        return obj
    end

    parseArray = function()
        local arr = {}
        pos = pos + 1 -- Skip '['

        -- Handle empty array
        if json:sub(pos, pos):match("%s*") and json:sub(pos, pos):match("%s*"):find("]") then
            -- Skip whitespace until ]
            while pos <= #json and json:sub(pos, pos) ~= "]" do
                pos = pos + 1
            end
            pos = pos + 1 -- Skip ']'
            return arr
        end

        -- Skip whitespace after [
        while pos <= #json and json:sub(pos, pos):match("%s") do
            pos = pos + 1
        end

        -- Handle empty array with whitespace
        if pos <= #json and json:sub(pos, pos) == "]" then
            pos = pos + 1
            return arr
        end

        local index = 1

        while true do
            -- Skip whitespace
            while pos <= #json and json:sub(pos, pos):match("%s") do
                pos = pos + 1
            end

            -- Parse value
            local value = parseValue()
            arr[index] = value
            index = index + 1

            -- Skip whitespace after value
            while pos <= #json and json:sub(pos, pos):match("%s") do
                pos = pos + 1
            end

            -- Check for end of array or next item
            local nextChar = json:sub(pos, pos)
            if nextChar == "]" then
                pos = pos + 1
                break
            elseif nextChar == "," then
                pos = pos + 1
                -- Continue to next iteration
            else
                error("Expected ',' or ']' in array at position " .. pos)
            end
        end

        return arr
    end

    parseString = function()
        pos = pos + 1 -- Skip opening quote
        local startPos = pos
        local value = ""

        while pos <= #json do
            local char = json:sub(pos, pos)

            if char == '"' then
                pos = pos + 1
                return value
            elseif char == "\\" then
                pos = pos + 1
                local escapeChar = json:sub(pos, pos)
                if escapeChar == '"' then
                    value = value .. '"'
                elseif escapeChar == "\\" then
                    value = value .. "\\"
                elseif escapeChar == "/" then
                    value = value .. "/"
                elseif escapeChar == "b" then
                    value = value .. "\b"
                elseif escapeChar == "f" then
                    value = value .. "\f"
                elseif escapeChar == "n" then
                    value = value .. "\n"
                elseif escapeChar == "r" then
                    value = value .. "\r"
                elseif escapeChar == "t" then
                    value = value .. "\t"
                else
                    error("Invalid escape sequence '\\" .. escapeChar .. "' at position " .. pos)
                end
            else
                value = value .. char
            end

            pos = pos + 1
        end

        error("Unterminated string starting at position " .. startPos)
    end

    parseNumber = function()
        local startPos = pos
        while pos <= #json and json:sub(pos, pos):match("[%d%.eE%+%-]") do
            pos = pos + 1
        end

        local numStr = json:sub(startPos, pos - 1)
        return tonumber(numStr)
    end

    local result = parseValue()

    -- Check for trailing content
    while pos <= #json and json:sub(pos, pos):match("%s") do
        pos = pos + 1
    end

    if pos <= #json then
        error("Unexpected trailing character at position " .. pos)
    end

    return result
end

-- Read JSON data from file
function DataManager:readJSON(filename, subDir)
    local path = self:getPath(filename, "json", subDir)

    if not fs.exists(path) then
        return nil
    end

    local file = fs.open(path, "r")
    local content = file.readAll()
    file.close()

    -- Parse JSON
    return self:decodeJSON(content)
end

-- Write JSON data to file
function DataManager:writeJSON(filename, data, subDir)
    self:ensureDataDir(subDir)
    local path = self:getPath(filename, "json", subDir)

    local file = fs.open(path, "w")
    file.write(self:encodeJSON(data))
    file.close()

    return true
end

------------------------------------------
-- Lua Table Functions
------------------------------------------

-- Converts a Lua value to a string representation
function DataManager:valueToLuaCode(value, indent, depth)
    depth = depth or 0
    indent = indent or "  "
    local indentStr = string.rep(indent, depth)
    local nextIndentStr = string.rep(indent, depth + 1)

    if type(value) == "table" then
        local parts = {}
        local isArray = true
        local maxIndex = 0

        -- Check if table is an array
        for k, v in pairs(value) do
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        if isArray and maxIndex > #value then
            isArray = false
        end

        -- Empty table
        if next(value) == nil then
            return "{}"
        end

        -- Build table string
        table.insert(parts, "{\n")

        -- For arrays, print without keys
        if isArray then
            for i, v in ipairs(value) do
                table.insert(parts, nextIndentStr)
                table.insert(parts, self:valueToLuaCode(v, indent, depth + 1))
                table.insert(parts, ",\n")
            end
        else
            -- For regular tables, print with keys
            for k, v in pairs(value) do
                table.insert(parts, nextIndentStr)

                -- Format the key
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    -- Valid identifier
                    table.insert(parts, k)
                else
                    -- Needs brackets
                    table.insert(parts, "[")
                    table.insert(parts, self:valueToLuaCode(k, indent, depth + 1))
                    table.insert(parts, "]")
                end

                table.insert(parts, " = ")
                table.insert(parts, self:valueToLuaCode(v, indent, depth + 1))
                table.insert(parts, ",\n")
            end
        end

        table.insert(parts, indentStr)
        table.insert(parts, "}")
        return table.concat(parts)
    elseif type(value) == "string" then
        -- Convert string to Lua string literal with proper escaping
        local escaped = string.gsub(value, '(["\\\n\r\t])', {
            ['"'] = '\\"',
            ['\\'] = '\\\\',
            ['\n'] = '\\n',
            ['\r'] = '\\r',
            ['\t'] = '\\t'
        })
        return '"' .. escaped .. '"'
    elseif type(value) == "number" or type(value) == "boolean" then
        -- Numbers and booleans can be converted directly
        return tostring(value)
    elseif type(value) == "function" then
        -- This is a stub - functions can't be properly serialized
        return "function() error('Function was serialized') end"
    elseif value == nil then
        return "nil"
    else
        -- For any other type, convert to a commented string
        return '"' .. tostring(value) .. '" --[[ ' .. type(value) .. ' ]]'
    end
end

-- Read Lua table from file
function DataManager:readLua(filename, subDir)
    local path = self:getPath(filename, "lua", subDir)

    if not fs.exists(path) then
        return nil
    end

    -- Execute the Lua file directly to get the data
    local success, result = pcall(function()
        local func, err = loadfile(path)
        if not func then error(err, 0) end
        return func()
    end)

    if success then
        return result
    else
        error("Failed to load Lua file: " .. result)
    end
end

-- Write Lua table to file
function DataManager:writeLua(filename, data, subDir)
    self:ensureDataDir(subDir)
    local path = self:getPath(filename, "lua", subDir)

    -- Generate Lua code
    local luaCode = "return " .. self:valueToLuaCode(data)

    local file = fs.open(path, "w")
    file.write(luaCode)
    file.close()

    return true
end

------------------------------------------
-- Metadata Functions
------------------------------------------

-- Parse metadata value (convert strings to appropriate types)
function DataManager:parseMetaValue(value)
    -- Remove extra spaces
    value = value:gsub("^%s*(.-)%s*$", "%1")

    -- Try to convert to number
    local num = tonumber(value)
    if num then return num end

    -- Check for boolean values
    if value == "true" then return true end
    if value == "false" then return false end

    -- Return as string (remove quotes if present)
    if value:match('^"(.*)"$') or value:match("^'(.*)'$") then
        return value:sub(2, -2)
    end

    return value
end

-- Read metadata from file
function DataManager:readMeta(filename, subDir)
    local path = self:getPath(filename, "meta", subDir)

    if not fs.exists(path) then
        return nil
    end

    local file = fs.open(path, "r")
    local data = {}
    local currentSection = nil

    while true do
        local line = file.readLine()
        if not line then break end

        -- Skip empty lines and comments
        if line:match("^%s*$") or line:match("^%s*#") then
            -- Do nothing

            -- Check for section header: [Section]
        elseif line:match("^%s*%[.+%]%s*$") then
            -- Extract section name and trim whitespace
            local sectionName = line:match("^%s*%[(.-)%]%s*$"):gsub("^%s*(.-)%s*$", "%1")

            -- Add section to data table
            if sectionName and sectionName ~= "" then
                data[sectionName] = {} -- Always create a new table for the section
                currentSection = sectionName
            end

            -- Check for key-value pair: key = value
        elseif line:match("^%s*(.-)%s*=%s*(.-)%s*$") then
            local key, value = line:match("^%s*(.-)%s*=%s*(.-)%s*$")
            -- Trim key
            key = key:gsub("^%s*(.-)%s*$", "%1")

            if key and key ~= "" then
                value = self:parseMetaValue(value)

                if currentSection then
                    -- Store in current section
                    data[currentSection][key] = value
                else
                    -- Store at top level
                    data[key] = value
                end
            end
        end
    end

    file.close()
    return data
end

-- Write metadata to file
function DataManager:writeMeta(filename, data, subDir)
    self:ensureDataDir(subDir)
    local path = self:getPath(filename, "meta", subDir)

    local file = fs.open(path, "w")

    -- Write top-level key-value pairs first
    for k, v in pairs(data) do
        if type(v) ~= "table" then
            file.writeLine(tostring(k) .. " = " .. tostring(v))
        end
    end

    -- Then write sections
    for section, sectionData in pairs(data) do
        if type(sectionData) == "table" then
            file.writeLine("")
            file.writeLine("[ " .. section .. " ]")

            for k, v in pairs(sectionData) do
                file.writeLine(tostring(k) .. " = " .. tostring(v))
            end
        end
    end

    file.close()
    return true
end

-- Generic read function that determines file type from extension
function DataManager:read(filename, subDir)
    local extension = filename:match("%.([^%.]+)$") or self.DEFAULT_ENCODING

    if extension == "json" then
        return self:readJSON(filename, subDir)
    elseif extension == "lua" then
        return self:readLua(filename, subDir)
    elseif extension == "meta" then
        return self:readMeta(filename, subDir)
    else
        error("Unsupported file extension: " .. extension)
    end
end

-- Generic write function that determines file type from extension
function DataManager:write(filename, data, subDir)
    local extension = filename:match("%.([^%.]+)$") or self.DEFAULT_ENCODING

    if extension == "json" then
        return self:writeJSON(filename, data, subDir)
    elseif extension == "lua" then
        return self:writeLua(filename, data, subDir)
    elseif extension == "meta" then
        return self:writeMeta(filename, data, subDir)
    else
        error("Unsupported file extension: " .. extension)
    end
end

return DataManager
