local data_manager = require("solution.data_manager")

return {
    name = "SolutionNvimReset",
    func = function(_) data_manager.reset() end,
    opts = {
        nargs = 0,
    },
}
