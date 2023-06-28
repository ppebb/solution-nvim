local M = {}

M.is_wsl = vim.fn.has("wsl") == 1
M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win32unix") == 1

M.separator = string.sub(package.config, 1, 1)

function M.platformify_path(path) return path:gsub("\\", M.separator) end

function M.file_exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
    end
    return f ~= nil
end

function M.file_read_all_text(path)
    if not M.file_exists(path) then
        return {}
    end

    local lines = {}
    for line in io.lines(path) do
        lines[#lines + 1] = line
    end
    return lines
end

function M.starts_with(str, start) return str:sub(1, #start) == start end

function M.ends_with(str, ending) return ending == "" or str:sub(-#ending) == ending end

function M.trim(str) return str:match("^()%s*$") and "" or str:match("^%s*(.*%S)") end

return M
