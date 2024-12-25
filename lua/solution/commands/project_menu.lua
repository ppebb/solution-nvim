local utils = require("solution.utils")
local project_open_textmenu = require("solution.ui.project_menu")

local name = "ProjectMenu"

return {
    name = name,
    func = function(opts)
        local ppn = assert(opts.fargs[1], "A project file or name must be provided as argument 1")
        local project = assert(utils.resolve_project(ppn), "No project of name '%s' was found!")

        project_open_textmenu(project)
    end,
    opts = {
        nargs = 1,
        complete = function(_, cmd_line, cursor_pos) return utils.complete_projects(cmd_line, #name + 2, cursor_pos) end,
    },
}
