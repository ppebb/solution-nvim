local utils = require("solution.utils")

return {
    name = "ProjectAddLocalDep",
    func = function(opts)
        local ppn = assert(opts.fargs[1], "A project name or path must be passed as argument 1")
        local project = assert(utils.resolve_project(ppn), string.format("Project '%s' could not be found!", ppn))

        local dep_path = assert(opts.fargs[2], "A dll path must be provided as argument 2")
        assert(dep_path:find("%.dll$"), "A dll path must be provided as argument 2")

        local success, err = project:add_local_dep(dep_path)
        if not success then
            error(string.format("Failed to add dependency '%s' to project '%s', %s", dep_path, project.name, err))
        else
            print(string.format("Successfully added dependency '%s' to project '%s'", dep_path, project.name))
        end
    end,
    opts = {
        nargs = "+",
        -- TODO: Custom file completion as the second argument
    },
}