local utils = require("solution.utils")
local sln_open_textmenu = require("solution.ui.solution_menu")

local name = "SolutionMenu"

return {
    name = name,
    func = function(opts)
        local ssn = assert(opts.fargs[1], "A solution file or name must be provided as argument 1")
        local sln = assert(utils.resolve_solution(ssn), "No solution of name '%s' was found!")

        sln_open_textmenu(sln)
    end,
    opts = {
        nargs = 1,
        complete = function(_, cmd_line, cursor_pos) return utils.complete_solutions(cmd_line, #name + 2, cursor_pos) end,
    },
}
