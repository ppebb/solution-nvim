local api = vim.api
local ntapi = require("nvim-tree.api")
local utils = require("solution.utils")

local M = {}

--- @param bufnr integer
--- @param key string|nil
function M.on_attach(bufnr, key)
    api.nvim_buf_set_keymap(bufnr, "n", key or "<leader>s", "", {
        desc = "Opens the relevant solution-nvim menu for the current node",
        noremap = true,
        nowait = true,
        callback = function()
            --- @type Node
            local node = ntapi.tree.get_node_under_cursor()

            if not node then
                return
            end

            if node.absolute_path:find("%.csproj") then
                -- open csproj menu
            elseif node.absolute_path:find("%.sln") then
                utils.resolve_solution(node.absolute_path):open_textmenu()
            end
        end,
    })
end

return M
