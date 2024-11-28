local utils = require("solution.utils")

local M = {}
M.log_path = utils.path_combine(vim.fn.stdpath("cache"), "solution-nvim.log")

--- @param level string
--- @param text string
function M.log(level, text)
    local fd = io.open(M.log_path, "a+")

    if not fd then
        error(string.format("Unable to open log file '%s'!", M.log_path))
        return
    end

    local info = debug.getinfo(2)
    fd:write(
        string.format(
            '[%s][%s] %s "%s"\n',
            level:upper(),
            os.date("%Y-%m-%d %H:%M:%S", os.time()),
            info.short_src or "unknown_source",
            text
        )
    )
    fd:close()
end

return M
