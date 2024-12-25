local utils = require("solution.utils")

local name = "SolutionListProjects"

return {
    name = name,
    func = function(opts)
        local ssn = assert(opts.fargs[1], "A solution name or path must be provided as argument 1")
        local sln = assert(utils.resolve_solution(ssn), string.format("Solution '%s' could not be found!", ssn))

        if vim.tbl_count(sln.projects) == 0 then
            print(string.format("Solution '%s' does not contain any projects!", sln.name))
            return
        end

        for _, project in pairs(sln.projects) do
            print(string.format("%s, %s", project.name, project.path))
        end
    end,
    opts = {
        nargs = 1,
        complete = function(_, cmd_line, cursor_pos) return utils.complete_solutions(cmd_line, #name + 2, cursor_pos) end,
    },
}
