local log = require("solution.log")

return {
    name = "SolutionLog",
    func = function(_) vim.cmd(string.format("tabnew %s", log.log_path)) end,
}
