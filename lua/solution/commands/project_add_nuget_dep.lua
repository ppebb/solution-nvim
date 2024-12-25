local utils = require("solution.utils")
local nuget_ui = require("solution.ui.nuget_browser")
local nuget_api = require("solution.nuget.api")

local name = "ProjectAddNugetDep"

return {
    name = name,
    func = function(opts)
        if #opts.fargs == 0 then
            nuget_ui.open()
            return
        end

        local ppn = assert(opts.fargs[1], "A project name or path must be passed as argument 1")
        local project = assert(utils.resolve_project(ppn), string.format("Project '%s' could not be found!", ppn))

        if #opts.fargs == 1 then
            nuget_ui.open(project)
            return
        end

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
        nargs = "*",
        complete = function(arg_lead, cmd_line, cursor_pos)
            return utils.complete_2args(
                arg_lead,
                cmd_line,
                cursor_pos,
                function() return utils.complete_projects(cmd_line, #name + 2, cursor_pos) end,
                function(_, arg1) return select(2, nuget_api.complete(arg1 or "")) or {} end
            )
        end,
    },
}
