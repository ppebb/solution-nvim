local api = vim.api
local ntapi = require("nvim-tree.api")
local utils = require("solution.utils")
local project_open_textmenu = require("solution.ui.project_menu")
local sln_open_textmenu = require("solution.ui.solution_menu")

local M = {}

--- @class SolutionNvimOnAttachOpts
--- @field menu_key? string
--- @field right_click_key? string

--- @param bufnr integer
--- @param opts? SolutionNvimOnAttachOpts|nil
function M.on_attach(bufnr, opts)
    api.nvim_buf_set_keymap(bufnr, "n", (opts and opts.menu_key) or "<leader>s", "", {
        desc = "Opens the relevant solution-nvim menu for the current node",
        noremap = true,
        nowait = true,
        callback = function()
            --- @type Node
            local node = ntapi.tree.get_node_under_cursor()

            if not node then
                return
            end

            if utils.is_csproj(node.absolute_path) then
                project_open_textmenu(utils.resolve_project(node.absolute_path))
            elseif utils.is_sln(node.absolute_path) then
                sln_open_textmenu(utils.resolve_solution(node.absolute_path))
            end
        end,
    })

    api.nvim_buf_set_keymap(bufnr, "n", (opts and opts.right_click_key) or "<leader>r", "", {
        desc = "Opens an action menu akin to right-clicking in other IDEs",
        noremap = true,
        nowait = true,
        callback = function()
            --- @type Node
            local node = ntapi.tree.get_node_under_cursor()

            if not node then
                return
            end
        end,
    })
end

return M
