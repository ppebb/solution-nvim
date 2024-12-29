local data_manager = require("solution.data_manager")
local utils = require("solution.utils")

local name = "SolutionSetDefault"

return {
    name = name,
    func = function(opts)
        local ssn = assert(opts.fargs[1], "A solution file or name must be provided as argument 1")
        local sln = assert(utils.resolve_solution(ssn), "No solution of name '%s' was found!")

        data_manager.set_defaults_for_path(vim.fn.getcwd(), nil, sln)
    end,
    opts = {
        nargs = 1,
        complete = function(_, cmd_line, cursor_pos) return utils.complete_solutions(cmd_line, #name + 2, cursor_pos) end,
    },
}
