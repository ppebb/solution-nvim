local api = vim.api

local M = {}

--- @class Command
--- @field name string
--- @field func fun(opts: table)
--- @field opts table?
--- @field cond? fun(): boolean

local commands = {
    -- TODO: Autodetection of commands? May require file io to read all modules
    -- in directory, in which case it's not happening
    require("solution.commands.nuget_browser"),
    require("solution.commands.project_add_local_dep"),
    require("solution.commands.project_add_nuget_dep"),
    require("solution.commands.project_add_project_ref"),
    require("solution.commands.project_list_dependencies"),
    require("solution.commands.project_remove_dep"),
    require("solution.commands.solution_add_project"),
    require("solution.commands.solution_list_projects"),
    require("solution.commands.solution_menu"),
    require("solution.commands.solution_nvim_log"),
    require("solution.commands.solution_nvim_register"),
    require("solution.commands.solution_remove_project"),
}

function M.init()
    for _, command in ipairs(commands) do
        if not command.cond or command.cond() then
            api.nvim_create_user_command(command.name, command.func, command.opts or {})
        end
    end
end

return M
