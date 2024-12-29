local data_manager = require("solution.data_manager")
local utils = require("solution.utils")

local name = "ProjectSetDefault"

return {
    name = name,
    func = function(opts)
        local ppn = assert(opts.fargs[1], "A project file or name must be provided as argument 1")
        local project = assert(utils.resolve_project(ppn), "No project of name '%s' was found!")

        data_manager.set_default_project(project, true)
        data_manager.set_defaults_for_path(vim.fn.getcwd(), project, nil)
    end,
    opts = {
        nargs = 1,
        complete = function(_, cmd_line, cursor_pos) return utils.complete_projects(cmd_line, #name + 2, cursor_pos) end,
    },
}
