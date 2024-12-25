local utils = require("solution.utils")
local projects = require("solution").projects

return {
    name = "ProjectRemoveDep",
    func = function(opts)
        local ppn = assert(opts.fargs[1], "A project name or path must be passed as argument 1")
        local project = assert(utils.resolve_project(ppn), string.format("Project '%s' could not be found!", ppn))

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
                print(string.format("Successfully removed dependency '%s' from project '%s'", dep.name, project.name))
            end
        end

        if dep.type == "Nuget" then
            project:remove_nuget_dep(dep.package, response_handler)
        elseif dep.type == "Project" then
            project:remove_project_reference(dep.project, response_handler)
        elseif dep.type == "Local" then
            local success, message = project:remove_local_dep(dep.path)
            response_handler(success, message, nil)
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
                return utils.tbl_map_to_arr(
                    vim.tbl_filter(function(e) return #e.dependencies > 0 end, projects),
                    function(_, e) return e.name end
                )
            end, function(arg1)
                local project = utils.resolve_project(arg1)
                if project then
                    return vim.tbl_map(function(e) return e.name end, project.dependencies) or {}
                end

                return {}
            end)
        end,
    },
}
