-- Logger: A robust logging system for ComputerCraft
-- Provides multiple severity levels, category-based logging, and automatic log rotation

local Logger = {
    -- Configuration (can be modified by users)
    LOG_DIR = "/logs",
    BACKUP_DIR = "/logs/backups",
    MAX_BACKUPS = 5,
    DEFAULT_CATEGORY = "system",
    -- Log levels with numeric values for filtering
    LEVELS = {
        debug = 10,
        info = 20,
        warn = 30,
        error = 40,
        fatal = 50
    }
}

-- Ensure directories exist
function Logger:ensureDirs()
    if not fs.exists(self.LOG_DIR) then
        fs.makeDir(self.LOG_DIR)
    end

    if not fs.exists(self.BACKUP_DIR) then
        fs.makeDir(self.BACKUP_DIR)
    end
end

-- Get log file path for a specific category
function Logger:getLogPath(category)
    category = category or self.DEFAULT_CATEGORY
    return self.LOG_DIR .. "/" .. category .. ".log"
end

-- Get backup file path for a specific category and backup number
function Logger:getBackupPath(category, backupNum)
    category = category or self.DEFAULT_CATEGORY
    return self.BACKUP_DIR .. "/" .. category .. "_" .. backupNum .. ".log"
end

-- Format log entry with timestamp, level, and message
function Logger:formatLogEntry(level, message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    return "[" .. timestamp .. "] [" .. level:upper() .. "] " .. message
end

-- Rotate logs for a given category
function Logger:rotateLogs(category)
    category = category or self.DEFAULT_CATEGORY

    -- Delete oldest backup if it exists
    local oldestBackup = self:getBackupPath(category, self.MAX_BACKUPS)
    if fs.exists(oldestBackup) then
        fs.delete(oldestBackup)
    end

    -- Shift all existing backups
    for i = self.MAX_BACKUPS - 1, 1, -1 do
        local currentBackup = self:getBackupPath(category, i)
        local newBackup = self:getBackupPath(category, i + 1)

        if fs.exists(currentBackup) then
            fs.copy(currentBackup, newBackup)
            fs.delete(currentBackup)
        end
    end

    -- Move current log to backup 1
    local logPath = self:getLogPath(category)
    if fs.exists(logPath) then
        fs.copy(logPath, self:getBackupPath(category, 1))
        fs.delete(logPath)
    end
end

-- Check if log file needs rotation (size > 8KB)
function Logger:checkRotation(category)
    category = category or self.DEFAULT_CATEGORY
    local logPath = self:getLogPath(category)

    if fs.exists(logPath) then
        local file = fs.open(logPath, "r")
        local size = 0

        while file.readLine() ~= nil do
            size = size + 1
        end

        file.close()

        -- Rotate if over 1000 lines (approximately 8KB)
        if size > 1000 then
            self:rotateLogs(category)
        end
    end
end

-- Log a message
function Logger:log(category, level, message)
    -- Handle case when category is omitted (level, message)
    if message == nil then
        message = level
        level = category
        category = self.DEFAULT_CATEGORY
    end

    -- Validate log level
    if not self.LEVELS[level] then
        level = "info"
    end

    self:ensureDirs()
    self:checkRotation(category)

    local logPath = self:getLogPath(category)
    local formattedEntry = self:formatLogEntry(level, message)

    -- Append to log file
    local file = fs.open(logPath, "a")
    file.writeLine(formattedEntry)
    file.close()

    -- Print to console if in debug mode (can be toggled by user)
    if self.CONSOLE_OUTPUT then
        print(formattedEntry)
    end
end

-- Convenience methods for different log levels
function Logger:debug(category, message)
    -- Allow for debug("message") format
    if message == nil then
        message = category
        category = self.DEFAULT_CATEGORY
    end
    self:log(category, "debug", message)
end

function Logger:info(category, message)
    if message == nil then
        message = category
        category = self.DEFAULT_CATEGORY
    end
    self:log(category, "info", message)
end

function Logger:warn(category, message)
    if message == nil then
        message = category
        category = self.DEFAULT_CATEGORY
    end
    self:log(category, "warn", message)
end

function Logger:error(category, message)
    if message == nil then
        message = category
        category = self.DEFAULT_CATEGORY
    end
    self:log(category, "error", message)
end

function Logger:fatal(category, message)
    if message == nil then
        message = category
        category = self.DEFAULT_CATEGORY
    end
    self:log(category, "fatal", message)
end

-- Clear logs for testing/cleanup
function Logger:clear(category)
    category = category or self.DEFAULT_CATEGORY

    -- Remove main log file
    local logPath = self:getLogPath(category)
    if fs.exists(logPath) then
        fs.delete(logPath)
    end

    -- Remove backup files
    for i = 1, self.MAX_BACKUPS do
        local backupPath = self:getBackupPath(category, i)
        if fs.exists(backupPath) then
            fs.delete(backupPath)
        end
    end
end

-- Enable or disable console output
function Logger:setConsoleOutput(enabled)
    self.CONSOLE_OUTPUT = (enabled == true)
    return self
end

-- Set minimum log level (will ignore logs below this level)
function Logger:setMinLevel(level)
    if self.LEVELS[level] then
        self.MIN_LEVEL = self.LEVELS[level]
    end
    return self
end

-- Initialize directories on require
Logger:ensureDirs()

return Logger
