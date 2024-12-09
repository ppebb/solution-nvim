local utils = require("solution.utils")
local slns = require("solution").slns

return {
    name = "SolutionListProjects",
    func = function(opts)
        local sln_name = assert(opts.fargs[1], "A solution name must be provided as argument 1")
        local sln =
            assert(utils.resolve_solution(sln_name), string.format("No solution of name '%s' was found!", sln_name))

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
        complete = function()
            return utils.tbl_map_to_arr(slns, function(_, e) return e.name end)
        end,
    },
}
