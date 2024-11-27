local api = vim.api
local utils = require("solution.utils")

local M = {}

--- @type SolutionFile[]
local _slns
--- @type ProjectFile[]
local _projects
--- @type table<string, ProjectFile>
local _aggregate_projects

--- @class Command
--- @field name string
--- @field func fun(opts: table)
--- @field opts table?
--- @field cond fun(): boolean

local function validate_sln_arg(sln_name)
    if not sln_name then
        error("A solution name must be provided as argument 1!")
        return nil
    end

    local sln = utils.sln_from_name(_slns, sln_name)

    if not sln then
        error(string.format("No solution with name %s exists!", sln_name))
        return nil
    end

    return sln
end

--- @param sln SolutionFile
--- @param proj_name string
--- @return ProjectFile|nil
local function validate_proj_arg(sln, proj_name)
    if not proj_name then
        error("A project name must be provided as argument 2!")
        return nil
    end

    local proj = sln:project_from_name(proj_name)

    if not proj then
        error(string.format("No project with name %s was found in solution %s", proj_name, sln.name))
        return nil
    end

    return proj
end

--- @type Command[]
local commands = {
    {
        name = "SolutionRemoveProject",
        func = function(opts)
            local sln = validate_sln_arg(opts.fargs[1])
            if not sln then
                return
            end

            local proj = validate_proj_arg(sln, opts.fargs[2])
            if not proj then
                return
            end

            sln:remove_project(proj)
        end,
        opts = {
            nargs = "+",
            complete = function(arg_lead, cmd_line, cursor_pos)
                return utils.complete_2args(arg_lead, cmd_line, cursor_pos, function()
                    return vim.tbl_map(function(e) return e.name end, _slns)
                end, function(arg1)
                    local sln = utils.sln_from_name(_slns, arg1)
                    if sln then
                        return vim.tbl_map(function(e) return e.name end, sln.projects)
                    end

                    return {}
                end)
            end,
        },
        cond = function() return #_slns > 0 end,
    },
    {
        name = "SolutionAddProject",
        func = function(opts)
            local sln = validate_sln_arg(opts.fargs[1])

            if not sln then
                return
            end

            local proj_name = opts.fargs[2]
            if not proj_name then
                error("A project name or path must be provided as argument 2!")
                return
            end

            ---@type string|ProjectFile|nil
            local proj_or_path = utils.tbl_first_matching(
                _aggregate_projects,
                function(_, v) return v.name == proj_name end
            )
            if not proj_or_path then
                proj_or_path = vim.fn.fnamemodify(proj_name, ":p")
            end

            sln:add_project(proj_or_path)
        end,
        opts = {
            nargs = "+",
            complete = function(arg_lead, cmd_line, cursor_pos)
                return utils.complete_2args(arg_lead, cmd_line, cursor_pos, function()
                    return vim.tbl_map(function(e) return e.name end, _slns)
                end, function(arg1)
                    local sln = utils.sln_from_name(_slns, arg1)
                    if sln then
                        return vim.tbl_map(
                            function(e) return e.name end,
                            vim.tbl_filter(
                                function(proj) return not vim.tbl_contains(sln.projects, proj) end,
                                _aggregate_projects
                            )
                        )
                    end

                    return {}
                end)
            end,
        },
        cond = function() return #_slns > 0 end,
    },
}

--- @param slns SolutionFile[]
--- @param projects ProjectFile[]
--- @param aggregate_projects ProjectFile[]
function M.init(slns, projects, aggregate_projects)
    _slns = slns
    _projects = projects
    _aggregate_projects = aggregate_projects
    for _, command in ipairs(commands) do
        if command.cond() then
            api.nvim_create_user_command(command.name, command.func, command.opts)
        end
    end
end

return M
