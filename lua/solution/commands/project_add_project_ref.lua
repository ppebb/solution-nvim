local utils = require("solution.utils")

return {
    name = "ProjectAddProjectRef",
    func = function(opts)
        local ppn = assert(opts.fargs[1], "A project name or path must be passed as argument 1")
        local project = assert(utils.resolve_project(ppn), string.format("Project '%s' could not be found!", ppn))

        local ppn_ref = assert(opts.fargs[2], "A project name or path must be passed as argument 2")
        local project_ref =
            assert(utils.resolve_project(ppn_ref), string.format("Project '%s' could not be found!", ppn))

        project:add_project_reference(project_ref, function(success, message, code)
            if not success then
                print(
                    string.format(
                        "Failed to add project reference '%s' to project '%s'%s%s",
                        project_ref.name,
                        project.name,
                        (message and ", " .. message) or "",
                        (code and ", code: " .. code) or ""
                    )
                )
            else
                print(
                    string.format(
                        "Successfully added project reference '%s' to project '%s'",
                        project_ref.name,
                        project.name
                    )
                )
            end
        end)
    end,
    opts = {
        nargs = "+",
        -- TODO: Custom file completion as the second argument
    },
}
