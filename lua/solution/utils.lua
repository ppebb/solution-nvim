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

--- @param file string
--- @param path string Path relative to file
--- @return string
function M.path_absolute_from_relative_to_file(file, path)
    local file_dir = vim.fn.fnamemodify(file, ":p:h")
    -- Extra fnamemodify ":p" removes any redundant .. from the path
    return vim.fn.fnamemodify(M.path_combine(file_dir, path), ":p")
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

--- @param path string
--- @return string[]|nil, string[]|nil
function M.search_files(path)
    local path_mut = vim.fn.fnamemodify(path, ":p")
    if not path_mut then
        return nil, nil
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
                return nil, nil -- probably should not be returning nil here, or anywhere in this function, but oh well
            end

            local handle = uv.fs_scandir(path_mut)
            if not handle then
                return nil, nil
            end

            while true do
                local name, type = uv.fs_scandir_next(handle)
                if not name then
                    break
                end

                local abs_path = M.path_combine(path_mut, name)
                type = type or (uv.fs_stat(abs_path) or {}).type

                if type == "file" then
                    if name:find("%.csproj") then
                        table.insert(found_projects, abs_path)
                    elseif name:find("%.sln") then
                        table.insert(found_solutions, abs_path)
                    end
                end
            end

            if path_mut == path_root then -- Should break once :h is run all the way to the root of the fs
                break
            end
        end
    end

    return found_solutions, found_projects
end

--- @param path string
--- @return boolean
function M.file_exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
    end
    return f ~= nil
end

--- @param path string
--- @return string[]|nil
function M.file_read_all_text(path)
    if not M.file_exists(path) then
        return nil
    end

    local lines = {}
    for line in io.lines(path) do
        lines[#lines + 1] = line
    end
    return lines
end

--- @param path string
--- @param text string
--- @return boolean
function M.file_write_all_text(path, text)
    local f = io.open(path, "w")
    if not f then
        return false
    end

    f:write(text)
    f:close()

    return true
end

--- @param cmd string
--- @param args string[]
--- @param onstdout? fun(err: string?, data: string?)|nil
--- @param onstderr? fun(err: string?, data: string?)|nil
--- @param onexit? fun(code: integer, signal: integer, stdout_agg: string, stderr_agg: string)|nil
function M.spawn_proc(cmd, args, onstdout, onstderr, onexit)
    local stdout = uv.new_pipe()
    local stderr = uv.new_pipe()

    local stdout_agg = ""
    local stderr_agg = ""

    local handle
    handle, _ = uv.spawn(cmd, { args = args, stdio = { nil, stdout, stderr } }, function(code, signal)
        stdout:read_stop()
        stderr:read_stop()
        stdout:close()
        stderr:close()
        ---@diagnostic disable-next-line: need-check-nil
        handle:close()

        if onexit then
            onexit(code, signal, stdout_agg, stderr_agg)
        end
    end)

    uv.read_start(stdout, function(err, data)
        stdout_agg = stdout_agg .. (data or "")
        if onstdout then
            onstdout(err, data)
        end
    end)

    uv.read_start(stderr, function(err, data)
        stderr_agg = stderr_agg .. (data or "")
        if onstderr then
            onstderr(err, data)
        end
    end)
end

--- Checks if the provided project path is present within any solution
--- @param slns table<string, SolutionFile>
--- @param path string
--- @return boolean
function M.slns_contains_project(slns, path)
    for _, sln in pairs(slns) do
        for _, project in pairs(sln.projects) do
            if project.path == path then
                return true
            end
        end
    end

    return false
end

--- @param ssn string The path or solution name
--- @param solutions? table<string, SolutionFile> The solutions table to resolve from
--- @return SolutionFile|nil
function M.resolve_solution(ssn, solutions)
    local fpath = vim.fn.fnamemodify(ssn, ":p")
    local _solutions = solutions or require("solution").slns

    if _solutions[fpath] then
        return _solutions[fpath]
    end

    local _, by_name = M.tbl_first_matching(_solutions, function(_, v) return v.name == ssn end)
    if by_name then
        return by_name
    end

    if fpath:find("%.sln") and M.file_exists(fpath) then
        local new = require("solution.solutionfile").new(fpath)

        -- Register the project, but only return it if we're not searching specifically within an array
        if not solutions then
            return new
        end
    end

    return nil
end

--- @param ppn string The path or project name
--- @param projects? table<string, ProjectFile> The projects table to resolve from
--- @return ProjectFile|nil
function M.resolve_project(ppn, projects)
    local fpath = vim.fn.fnamemodify(ppn, ":p")
    local _projects = projects or require("solution").projects

    if _projects[fpath] then
        return _projects[fpath]
    end

    local _, by_name = M.tbl_first_matching(_projects, function(_, v) return v.name == ppn end)
    if by_name then
        return by_name
    end

    if fpath:find("%.csproj") and M.file_exists(fpath) then
        local new = require("solution.projectfile").new_from_file(fpath)

        -- Register the project, but only return it if we're not searching specifically within an array
        if not projects then
            return new
        end
    end

    return nil
end

function M.center_align(text_arr, width)
    local numspaces = {}
    for _, line in pairs(text_arr) do
        table.insert(numspaces, math.floor((width - vim.api.nvim_strwidth(line)) / 2))
    end

    local centered = {}
    for i = 1, #text_arr do
        table.insert(centered, (" "):rep(numspaces[i]) .. text_arr[i])
    end

    return centered
end

--- @param str string
--- @return string[]
function M.split_by_whitespace(str)
    -- NOTE: I'd like to use split_by_pattern for this, but the weird matching
    -- prevents that. I wasn't clever enough to come up with a working pattern
    local segments = {}

    local old_pos = 1
    local pos = str:find("[^\\]%s")

    while pos do
        table.insert(segments, str:sub(old_pos, pos))

        old_pos = pos + 2
        pos = str:find("[^\\]%s", pos + 2)
    end

    if old_pos < #str then
        table.insert(segments, str:sub(old_pos))
    end

    return segments
end

--- @param str string
--- @param pattern string
--- @return string[]
function M.split_by_pattern(str, pattern)
    local segments = {}

    local old_pos = 1
    local pos, end_pos, capt = str:find(pattern)

    while pos do
        if capt then
            table.insert(segments, capt)
        else
            table.insert(segments, str:sub(old_pos, pos - 1))
        end

        old_pos = end_pos + 1
        pos, end_pos, capt = str:find(pattern, end_pos + 1)
    end

    if old_pos < #str then
        table.insert(segments, str:sub(old_pos))
    end

    return segments
end

--- @param str string
--- @param pattern string
--- @param n integer
--- @param plain boolean?
--- @return integer
function M.nth_occurrence(str, pattern, n, plain)
    local count = 0
    local start = 1

    while count < n do
        local pos = str:find(pattern, start, plain)

        if not pos then
            return -1
        end

        count = count + 1
        start = pos + 1

        if count == n then
            return pos
        end
    end

    return -1
end

--- Returns the first element where the predicate returns true
--- @generic T
--- @generic U
--- @param tbl table<T, U>
--- @param predicate fun(key: T, value: U): boolean
--- @return T|nil, U|nil
function M.tbl_first_matching(tbl, predicate)
    for key, value in pairs(tbl) do
        if predicate(key, value) then
            return key, value
        end
    end

    return nil, nil
end

--- Returns the first key corresponding to the provided element
--- @generic T
--- @generic U
--- @param tbl table<T, U>
--- @return T|nil
function M.tbl_find(tbl, element)
    for key, value in pairs(tbl) do
        if value == element then
            return key
        end
    end

    return nil
end

--- @param comp_arg1 fun(arg1: string): string[]
--- @param comp_arg2 fun(arg1: string, arg2: string): string[]
function M.complete_2args(_, cmd_line, cursor_pos, comp_arg1, comp_arg2)
    local split = M.split_by_whitespace(cmd_line)
    local splen = #split

    local _2nd = M.nth_occurrence(cmd_line, "[^\\]%s", 2)
    local _3rd = M.nth_occurrence(cmd_line, "[^\\]%s", 3)

    if splen == 1 then
        return comp_arg1(split[2])
    elseif splen > 1 and splen < 4 then
        if cursor_pos <= _2nd or _2nd == -1 then
            return comp_arg1(split[2])
        elseif cursor_pos < _3rd or _3rd == -1 then
            return comp_arg2(split[2], split[3])
        end
    end
end

function M.complete_file(pat, offset, cursor_pos, filters)
    local res = vim.fn.getcompletion(pat:sub(offset, cursor_pos), "file")

    filters = filters or {}
    table.insert(filters, "/$") -- Matches folders
    table.insert(filters, "\\$") -- Matches windows folders
    table.insert(filters, "%.%.") -- Matches parent directory

    res = vim.tbl_filter(function(e)
        for _, pattern in ipairs(filters) do
            if e:find(pattern) then
                return true
            end
        end

        return false
    end, res)

    res = vim.tbl_map(function(e) return e:gsub(" ", "\\ ") end, res)

    return res
end

--- @param cmd_line string
--- @param offset integer
--- @param cursor_pos integer
--- @param projects ProjectFile[]|nil
function M.complete_projects(cmd_line, offset, cursor_pos, projects)
    local _projects = projects or require("solution").projects
    local ret = M.tbl_map_to_arr(_projects, function(_, e) return e.name end)

    if #ret == 0 then
        return M.complete_file(cmd_line, offset, cursor_pos, { "%.csproj" })
    end

    return ret
end

--- @param cmd_line string
--- @param offset integer
--- @param cursor_pos integer
--- @param solutions SolutionFile[]|nil
function M.complete_solutions(cmd_line, offset, cursor_pos, solutions)
    local _slns = solutions or require("solution").slns
    local ret = M.tbl_map_to_arr(_slns, function(_, e) return e.name end)

    if #ret == 0 then
        return M.complete_file(cmd_line, offset, cursor_pos, { "%.sln" })
    end

    return ret
end

--- @generic U
--- @generic T
--- @generic Z
--- @param tbl table<U, T>
--- @param func fun(key: U, value: T): Z
--- @return Z[]
function M.tbl_map_to_arr(tbl, func)
    local ret = {}

    for k, v in pairs(tbl) do
        table.insert(ret, func(k, v))
    end

    return ret
end

--- @param str string
--- @param start string
--- @return boolean
function M.starts_with(str, start) return str:sub(1, #start) == start end

--- @param str string
--- @param ending string
--- @return boolean
function M.ends_with(str, ending) return ending == "" or str:sub(-#ending) == ending end

--- @param str string
--- @return string
function M.trim(str) return str:match("^()%s*$") and "" or str:match("^%s*(.*%S)") end

--- @param str string
--- @return string
function M.remove_bom(str)
    local b1, b2, b3 = str:byte(1, 3)
    if b1 == 239 and b2 == 187 and b3 == 191 then
        return str:sub(4)
    end

    return str
end

--- @param str string
--- @return string[]
function M.tokenize(str)
    local ret = {}
    for token in str:gmatch("%S+") do
        table.insert(ret, token)
    end

    return ret
end

--- @param str string
--- @param width integer
--- @return string[]
function M.word_wrap(str, width)
    local tokens = M.tokenize(str)
    local lines = {}
    local idx = 1

    for _, token in ipairs(tokens) do
        if #(lines[idx] or "") + #token + 1 > width then
            idx = idx + 1
        end

        lines[idx] = (lines[idx] or "") .. (#(lines[idx] or "") ~= 0 and " " or "") .. token
    end

    return lines
end

return M
