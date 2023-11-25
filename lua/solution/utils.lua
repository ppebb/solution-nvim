local M = {}

M.separator = string.sub(package.config, 1, 1)

function M.os_path(path) return path:gsub("\\", M.separator):gsub("/", M.separator) end

--- @param ... string
--- @return string
function M.path_combine(...)
    local args = { ... }
    local res = M.os_path(args[1])
    for i = 2, #args do
        local segment = M.os_path(args[i])
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

function M.path_root(path)
    local path_mut = path

    while true do
        local t = vim.fn.fnamemodify(path_mut, ":h")
        if t == path_mut then
            return t
        else
            path_mut = t
        end
    end
end

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
