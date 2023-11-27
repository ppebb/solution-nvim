local uv = vim.uv or vim.loop

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

function M.search_files(path)
    local path_mut = vim.fn.fnamemodify(path, ":p")
    if not path_mut then
        return nil
    end

    local path_root = M.path_root(path_mut)

    local found_projects = {}
    local found_solutions = {}

    -- Opened a project directly, use this instead of searching for more
    -- if path_mut:find(".csproj") then
    --     table.insert(found_projects, path_mut)
    -- end
    -- if path_mut:find(".sln") then
    --     table.insert(found_solutions, path_mut)
    -- end

    if not (#found_projects > 0 or #found_solutions > 0) then
        while true do
            path_mut = vim.fn.fnamemodify(path_mut, ":h") -- get the parent directory
            if not path_mut then
                return nil -- probably should not be returning nil here, or anywhere in this function, but oh well
            end

            local handle = uv.fs_scandir(path_mut)
            if not handle then
                return nil
            end

            while true do
                local name, type = uv.fs_scandir_next(handle)
                if not name then
                    break
                end

                local abs_path = M.path_combine(path_mut, name);
                type = type or (uv.fs_stat(abs_path) or {}).type

                if type == "file" then
                    if name:find(".csproj") then
                        table.insert(found_projects, abs_path)
                    elseif name:find(".sln") then
                        table.insert(found_solutions, abs_path)
                    end
                end
            end

            if path_mut == path_root then -- Should break once :h is run all the way to the root of the fs
                break
            end
        end
    end

    return found_projects, found_solutions
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
