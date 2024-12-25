local utils = require("solution.utils")
local projects = require("solution").projects
local slns = require("solution").slns

return {
    name = "SolutionAddProject",
    func = function(opts)
        local ssn = assert(opts.fargs[1], "A solution name or file must be provided as argument 1")
        local sln = assert(utils.resolve_solution(ssn), string.format("Solution '%s' could not be found!", ssn))

        local ppn = assert(opts.fargs[2], "A project name or path must be provided as argument 2")
        local project = assert(utils.resolve_project(ppn), string.format("Project '%s' could not be found!", ppn))

        sln:add_project(project, function(success, message, code)
            if not success then
                print(
                    string.format(
                        "Failed to add project '%s' to solution '%s'%s%s",
                        project.name,
                        sln.name,
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
                return utils.tbl_map_to_arr(slns, function(_, e) return e.name end)
            end, function(arg1)
                local sln = utils.resolve_solution(arg1)
                if sln then
                    return utils.tbl_map_to_arr(
                        vim.tbl_filter(function(proj) return not vim.tbl_contains(sln.projects, proj) end, projects),
                        function(_, e) return e.name end
                    )
                end

                return {}
            end)
        end,
    },
}
