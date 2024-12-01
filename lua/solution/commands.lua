local api = vim.api
local log = require("solution.log")
local utils = require("solution.utils")

local M = {}

--- @type SolutionFile[]
local _slns
--- @type table<string, ProjectFile>
local _aggregate_projects

--- @class Command
--- @field name string
--- @field func fun(opts: table)
--- @field opts table?
--- @field cond? fun(): boolean

--- @type Command[]
local commands = {
    {
        name = "SolutionRegister",
        func = function(opts)
            local fname = assert(opts.fargs[1], "A solution or project file must be provided as argument 1")
            local csproj = fname:find("%.csproj$")
            local sln = fname:find("%.sln$")
            assert(csproj or sln, "A solution or project file must be provided as argument 1")

            assert(utils.file_exists(fname), string.format("The file '%s' does not exist!", fname))

            if csproj then
                require("solution.projectfile").new_from_file(fname)
            else
                table.insert(require("solution").slns, require("solution.solutionfile").new(fname))
            end
        end,
        opts = {
            nargs = 1,
            complete = "file",
        },
    },
    {
        name = "SolutionRemoveProject",
        func = function(opts)
            local sln_name = assert(opts.fargs[1], "A solution name must be provided as argument 1")
            local sln = assert(
                utils.sln_from_name(_slns, sln_name),
                string.format("No solution of name '%s' was found!", sln_name)
            )

            local ppn = assert(opts.fargs[2], "A project name or path must be provided as argument 2")
            local project = assert(
                utils.resolve_project(ppn, sln.projects),
                string.format("Project '%s' was found in the solution!", ppn)
            )

            sln:remove_project(project, function(success, message, code)
                if not success then
                    print(
                        string.format(
                            "Failed to remove project '%s' from solution '%s'%s%s",
                            sln.name,
                            project.name,
                            (message and ", " .. message) or "",
                            (code and ", code: " .. code) or ""
                        )
                    )
                else
                    print(
                        string.format("Successfully removed project '%s' from solution '%s'!", sln.name, project.name)
                    )
                end
            end)
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
            local sln_name = assert(opts.fargs[1], "A solution name must be provided as argument 1")
            local sln = assert(
                utils.sln_from_name(_slns, sln_name),
                string.format("No solution of name '%s' was found!", sln_name)
            )

            local ppn = assert(opts.fargs[2], "A project name or path must be provided as argument 2")
            local project = assert(
                utils.resolve_project(ppn, sln.projects),
                string.format("Project '%s' was found in the solution!", ppn)
            )

            sln:add_project(project, function(success, message, code)
                if not success then
                    print(
                        string.format(
                            "Failed to add project '%s' to solution '%s'%s%s",
                            sln.name,
                            project.name,
                            (message and ", " .. message) or "",
                            (code and ", code: " .. code) or ""
                        )
                    )
                else
                    print(string.format("Successfully added project '%s' to solution '%s'!", project.name, sln.name))
                end
            end)
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
    {
        name = "SolutionLog",
        func = function(_) vim.cmd(string.format("tabnew %s", log.log_path)) end,
    },
    {
        name = "ProjectAddNugetDep",
        func = function(opts)
            local ppn = assert(opts.fargs[1], "A project name or path must be passed as argument 1")
            local project =
                assert(utils.resolve_project(ppn), string.format("Project '%s' was found in the solution!", ppn))

            local package_name = assert(opts.fargs[2], "A package name must be provided as argument 2")
            local package_ver = opts.fargs[3]

            project:add_nuget_dep(package_name, package_ver, function(success, message, code)
                if not success then
                    print(
                        string.format(
                            "Failed to add package '%s' to project '%s'%s%s",
                            package_name,
                            project.name,
                            (message and ", " .. message) or "",
                            (code and ", code: " .. code) or ""
                        )
                    )
                else
                    print(string.format("Successfully added package '%s' to project '%s'", package_name, project.name))
                end
            end)
        end,
        opts = {
            nargs = "+",
            complete = function(arg_lead, cmd_line, cursor_pos)
                return utils.complete_2args(arg_lead, cmd_line, cursor_pos, function()
                    return vim.tbl_map(function(e) return e.name end, _aggregate_projects)
                end, function(_)
                    -- TODO: Complete nuget packages using ???
                    return {}
                end)
            end,
        },
        cond = function() return vim.tbl_count(_aggregate_projects) ~= 0 end,
    },
    {
        name = "ProjectRemoveDep",
        func = function(opts)
            local ppn = assert(opts.fargs[1], "A project name or path must be passed as argument 1")
            local project =
                assert(utils.resolve_project(ppn), string.format("Project '%s' was found in the solution!", ppn))

            local dep_name = assert(opts.fargs[2], "A dependency name must be provided as argument 2")
            local dep =
                assert(project:dependency_from_name(dep_name), "A valid dependency name must be provided as argument 2")

            local function response_handler(success, message, code)
                if not success then
                    print(
                        string.format(
                            "Failed to remove dependency '%s' of type '%s' from project '%s'%s%s",
                            dep.name,
                            dep.type,
                            project.name,
                            (message and ", " .. message) or "",
                            (code and ", code: " .. code) or ""
                        )
                    )
                else
                    print(
                        string.format("Successfully removed dependency '%s' from project '%s'", dep.name, project.name)
                    )
                end
            end

            if dep.type == "Nuget" then
                project:remove_nuget_dep(dep.package, response_handler)
            elseif dep.type == "Project" then
                project:remove_project_ref(dep.project, response_handler)
            elseif dep.type == "Local" then
                project:remove_local_dep(dep.path, response_handler)
            else
                -- This should never hit, or something has gone very wrong
                error(
                    string.format(
                        "Attempted to remove dependency of unkown type '%s' from project '%s'",
                        dep.type,
                        project.name
                    )
                )
            end
        end,
        opts = {
            nargs = "+",
            complete = function(arg_lead, cmd_line, cursor_pos)
                return utils.complete_2args(arg_lead, cmd_line, cursor_pos, function()
                    return vim.tbl_map(function(e) return e.name end, _aggregate_projects)
                end, function(arg1)
                    local project = utils.resolve_project(arg1)
                    if project then
                        return {
                            vim.tbl_map(function(e) return e.name end, project.dependencies),
                        }
                    end

                    return {}
                end)
            end,
        },
        cond = function() return vim.tbl_count(_aggregate_projects) ~= 0 end,
    },
}

--- @param slns SolutionFile[]
--- @param aggregate_projects table<string, ProjectFile>
function M.init(slns, aggregate_projects)
    _slns = slns
    _aggregate_projects = aggregate_projects
    for _, command in ipairs(commands) do
        if not command.cond or command.cond() then
            api.nvim_create_user_command(command.name, command.func, command.opts or {})
        end
    end
end

return M
