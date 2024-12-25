local utils = require("solution.utils")
local projects = require("solution").projects

local name = "ProjectAddProjectRef"

return {
    name = name,
    func = function(opts)
        local ppn = assert(opts.fargs[1], "A project name or path must be passed as argument 1")
        local project = assert(utils.resolve_project(ppn), string.format("Project '%s' could not be found!", ppn))

        local ppn_ref = assert(opts.fargs[2], "A project name or path must be passed as argument 2")
        local project_ref =
            assert(utils.resolve_project(ppn_ref), string.format("Project '%s' could not be found!", ppn))

        assert(project ~= project_ref, "Two different projects must be specified!")

        project:add_project_reference(project_ref, function(success, message, code)
            if not success then
                print(
                    string.format(
                        "Failed to add project reference '%s' to project '%s'%s%s",
                        project_ref.name,
                        project.name,
                        (message and ", " .. message) or "",
                        (code and ", code: " .. code) or ""
                    )
                )
            else
                print(
                    string.format(
                        "Successfully added project reference '%s' to project '%s'",
                        project_ref.name,
                        project.name
                    )
                )
            end
        end)
    end,
    opts = {
        nargs = "+",
        complete = function(arg_lead, cmd_line, cursor_pos)
            return utils.complete_2args(
                arg_lead,
                cmd_line,
                cursor_pos,
                function() return utils.complete_projects(cmd_line, #name + 2, cursor_pos) end,
                function(arg1)
                    return vim.tbl_filter(
                        function(e) return e ~= arg1 end,
                        utils.complete_projects(cmd_line, #name + #arg1 + 3, cursor_pos)
                    )
                end
            )
        end,
    },
}
