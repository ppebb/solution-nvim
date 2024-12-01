local utils = require("solution.utils")
local aggregate_projects = require("solution").aggregate_projects

return {
    name = "ProjectAddNugetDep",
    func = function(opts)
        local ppn = assert(opts.fargs[1], "A project name or path must be passed as argument 1")
        local project = assert(utils.resolve_project(ppn), string.format("Project '%s' could not be found!", ppn))

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
                return utils.tbl_map_to_arr(aggregate_projects, function(_, e) return e.name end)
            end, function(_)
                -- TODO: Complete nuget packages using ???
                return {}
            end)
        end,
    },
    cond = function() return vim.tbl_count(aggregate_projects) ~= 0 end,
}
