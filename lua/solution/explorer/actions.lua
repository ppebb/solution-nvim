local M = {}

local main
local api = vim.api
local utils = require("solution.utils")
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

function M.real_node_under_cursor()
    local node = M.get_node_under_cursor()
    if not node then
        return nil
    end

    if node.type == "solution" or node.type == "project" then
        node = node.node
    end

    return node
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

function M.remove()
    local node = M.real_node_under_cursor()
    if not node then
        return
    end

    vim.ui.select({ "y", "n" }, {
        prompt = "Remove File",
    }, function(item)
        if item == "y" then
        end
    end)
end

function M.new()
    local node = M.real_node_under_cursor()
    if not node then
        return
    end
    local base_path

    if node.type == "file" then
        base_path = node.parent.path
    elseif node.type == "directory" then
        base_path = node.path
    else
        -- figure out symlinks, for now just return
        return
    end
    base_path = utils.add_trailing_separator(base_path)

    vim.ui.input({
        prompt = "Create File",
        default = base_path,
        completion = "file",
    }, function(new_file)
        local function make_parents(path)
            local function recurse_parents(dir)
                if not utils.file_exists(dir) then
                    recurse_parents(vim.fn.fnamemodify(dir, ":h"))
                    uv.fs_mkdir(dir, 493)
                end
            end

            local parent = vim.fn.fnamemodify(path, ":h")
            recurse_parents(parent)
        end

        if not new_file or new_file == base_path then
            return
        end

        if utils.file_exists(new_file) then
            vim.notify("File " .. new_file .. " already exists", vim.log.levels.WARN)
            return
        end

        make_parents(new_file)

        if new_file:find(utils.separator .. "$") then
            uv.fs_mkdir(new_file, 493)
        else
            local descriptor, err = uv.fs_open(new_file, "w", 420)
            if err then
                vim.notify("Unable to create file " .. new_file .. " " .. err, vim.log.levels.WARN)
            end
            if descriptor then
                uv.fs_close(descriptor)
            end
        end

        node:refresh()
    end)
end

return M
