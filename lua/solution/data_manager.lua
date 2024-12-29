local log = require("solution.log")
local utils = require("solution.utils")

local M = {}

---@diagnostic disable-next-line: param-type-mismatch
M.data_path = utils.path_combine(vim.fn.stdpath("data"), "solution-nvim.data")

--- @class SolutionNvimDefaults
--- @field project? ProjectFile
--- @field sln? SolutionFile
local defaults = {
    project = nil,
    sln = nil,
}

--- @class SolutionNvimStoredDefaults
--- @field project_path? string
--- @field sln_path? string

--- @class SolutionNvimSaveData
--- @field defaults_by_path table<string, SolutionNvimStoredDefaults>

--- @type SolutionNvimSaveData
local data = {
    defaults_by_path = {},
}

--- @return SolutionNvimDefaults
function M.get_defaults_by_path(path)
    local by_path = data.defaults_by_path[path]

    return (
        by_path
        and {
            project = utils.resolve_project(by_path.project_path),
            sln = utils.resolve_solution(by_path.sln_path),
        }
    )
end

--- @return SolutionNvimDefaults
function M.get_defaults() return defaults end

--- @param sln SolutionFile
--- @param force? boolean Force assign the default solution.
function M.set_default_sln(sln, force)
    if not defaults.sln or force then
        defaults.sln = sln
    end
end

--- @param project ProjectFile
--- @param force? boolean Force assign the default solution.
function M.set_default_project(project, force)
    if not defaults.project or force then
        defaults.project = project
    end
end

--- @param path string
--- @param project ProjectFile|nil
--- @param sln SolutionFile|nil
function M.set_defaults_for_path(path, project, sln)
    local temp = data.defaults_by_path[path] or {}
    temp.project_path = temp.project_path or (project and project.path)
    temp.sln_path = temp.sln_path or (sln and sln.path)

    data.defaults_by_path[path] = temp

    M.save()
end

function M.save() utils.file_write_all_text(M.data_path, vim.mpack.encode(data)) end

function M.load()
    if not utils.file_exists(M.data_path) then
        return
    end

    local success, res = xpcall(vim.mpack.decode, function(e)
        log.log("error", string.format("Error reading saved data at '%s': %s\n%s\n", M.data_path, e, debug.traceback()))
        print(
            "Error reading saved data for solution-nvim, use :SolutionNvimReset to clear saved data, see :SolutionNvimLog for more info!"
        )
    end, table.concat(utils.file_read_all_text(M.data_path), "\n"))

    if success then
        data = res
    end

    -- Ensure fields exists in case the saved data is broken
    data = data or {}
    data.defaults_by_path = data.defaults_by_path or {}

    local saved = M.get_defaults_by_path(vim.fn.getcwd())
    if saved then
        if saved.sln then
            defaults.sln = saved.sln
        end

        if saved.project then
            defaults.project = saved.project
        end
    end
end

function M.reset()
    if not utils.file_exists(M.data_path) then
        return
    end

    vim.fn.delete(M.data_path)
end

return M
