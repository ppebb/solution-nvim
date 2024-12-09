local utils = require("solution.utils")
local projects = require("solution").projects

return {
    name = "ProjectListDependencies",
    func = function(opts)
        local ppn = assert(opts.fargs[1], "A project name or path must be passed as argument 1")
        local project = assert(utils.resolve_project(ppn), string.format("Project '%s' could not be found!", ppn))

        if #project.dependencies == 0 then
            print(string.format("Project '%s' does not have any dependencies!", project.name))
            return
        end

        for _, dependency in ipairs(project.dependencies) do
            if dependency.type == "Local" then
                print(string.format("DLL Reference: %s, %s, %s", dependency.name, dependency.include, dependency.path))
            elseif dependency.type == "Nuget" then
                print(string.format("Package Reference: %s, version %s", dependency.package, dependency.version))
            elseif dependency.type == "Project" then
                print(string.format("Project Reference: %s, %s", dependency.name, dependency.path))
            end
        end
    end,
    opts = {
        nargs = 1,
        complete = function()
            return utils.tbl_map_to_arr(projects, function(_, e) return e.name end)
        end,
    },
}
