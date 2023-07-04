local M = {}

local main
local api = vim.api
local uv = vim.uv or vim.loop
local window

function M.init()
    main = require("solution")
    window = require("solution.explorer.window")
end

--- @return Node|ProjectFile|SolutionFile|nil
function M.get_node_under_cursor()
    local row = api.nvim_win_get_cursor(window.get_winhl())[1]
    local index = 2 -- start at 2 because the first line is always going to be main.sln

    --- @param node Node
    --- @return Node|nil
    local function check_node(node)
        if node:should_render() then
            if row == index then
                return node
            elseif node.open and node.has_children then
                index = index + 1
                for _, child in ipairs(node:get_children()) do
                    local grandchild = check_node(child)
                    if grandchild then
                        return grandchild
                    end
                end
            else
                index = index + 1
            end
        end
    end

    if row == 1 then
        return main.sln
    end

    if main.sln.type == "solution" then
        for _, project in ipairs(main.sln.projects) do
            if row == index then
                return project
            end

            local node = check_node(project.node)
            if node then
                return node
            end
        end
    else
        return check_node(main.sln.node)
    end
end

function M.open()
    local node = M.get_node_under_cursor()
    if not node then
        return
    end

    if node.type == "project" then
        node.node.open = not node.node.open
    elseif node.type == "directory" or (node.type == "link" and node.has_children) then
        node.open = not node.open
    end

    print(node.name)

    window.redraw()
end

function M.remove() local node = M.get_node_under_cursor() end

function M.new()
    local node = M.get_node_under_cursor()

    if node.type == "folder" then
    end
end

return M
