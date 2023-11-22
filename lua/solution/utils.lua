local M = {}

local uv = vim.uv or vim.loop

M.is_wsl = vim.fn.has("wsl") == 1
M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win32unix") == 1

M.separator = string.sub(package.config, 1, 1)

function M.sanitize_path(path) return path:gsub("\\", M.separator):gsub("/", M.separator) end

--- @param ... string
--- @return string
function M.path_combine(...)
    local args = { ... }
    local res = M.sanitize_path(args[1])
    for i = 2, #args do
        local segment = M.sanitize_path(args[i])
        local rew = M.ends_with(res, M.separator)
        local ssw = M.starts_with(segment, M.separator)

        if rew and ssw then
            segment = segment:sub(2)
        elseif not rew and not ssw then
            segment = M.separator .. segment
        end

        res = res .. segment
    end

    return res
end

function M.add_trailing_separator(path)
    if path:find(M.separator .. "$") then
        return path
    else
        return path .. M.separator
    end
end

function M.key_by(tbl, key)
    local ret = {}

    for _, element in ipairs(tbl) do
        ret[element[key]] = element
    end

    return ret
end

function M.file_exists(path)
    local _, e = uv.fs_stat(path)
    return not e
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

--- @param str string
function M.starts_with(str, start) return str:sub(1, #start) == start end

function M.ends_with(str, ending) return ending == "" or str:sub(-#ending) == ending end

function M.trim(str) return str:match("^()%s*$") and "" or str:match("^%s*(.*%S)") end

return M
