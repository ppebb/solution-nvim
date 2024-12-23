local utils = require("solution.utils")
local slns = require("solution").slns

return {
    name = "SolutionMenu",
    func = function(opts)
        local ssn = assert(opts.fargs[1], "A solution file or name must be provided as argument 1")
        local sln = assert(utils.resolve_solution(ssn), "No solution of name '%s' was found!")

        sln:open_textmenu()
    end,
    opts = {
        nargs = 1,
        complete = function(_)
            return utils.tbl_map_to_arr(slns, function(_, e) return e.name end)
        end,
    },
}
