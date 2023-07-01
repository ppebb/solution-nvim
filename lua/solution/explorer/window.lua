local M = {}

local api = vim.api
local main
local renderer = require("solution.explorer.renderer")

local wininfo_per_tabpage = {}

local function set_cursor_pos()
    local row = api.nvim_win_get_cursor(M.get_winhl())[1]
    local line = api.nvim_get_current_line()
    local start, _ = line:find("[%a\\.]")
    api.nvim_win_set_cursor(M.get_winhl(), { row, start - 1 })
end

local function set_win_pos_and_size(winhl)
    local old_hl = api.nvim_get_current_win()

    api.nvim_set_current_win(winhl)
    if main.config.explorer.side == "left" then
        vim.cmd("wincmd H")
    else
        vim.cmd("wincmd L")
    end
    api.nvim_win_set_width(winhl, main.config.explorer.width)

    api.nvim_set_current_win(old_hl)
end

--- @return Node|ProjectFile|SolutionFile|nil
local function get_node_under_cursor()
    local row = api.nvim_win_get_cursor(M.get_winhl())[1]
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

local function open()
    local node = get_node_under_cursor()
    if not node then
        return
    end

    if node.type == "project" then
        node.node.open = not node.node.open
    elseif node.type == "folder" or (node.type == "link" and node.has_children) then
        node.open = not node.open
    end

    print(node.name)

    M.redraw()
end

local function register_keybinds()
    api.nvim_buf_set_keymap(M.bufnr, "n", "<CR>", "", {
        desc = "[Solution Explorer] Open node",
        callback = open,
    })

    api.nvim_buf_set_keymap(M.bufnr, "n", "<2-LeftMouse>", "", {
        desc = "[Solution Explorer] Open node",
        callback = open,
    })
end

local function register_autocmds()
    local group = api.nvim_create_augroup("solution_explorer", { clear = true })

    if main.config.explorer.lock_cursor then
        api.nvim_create_autocmd("CursorMoved", {
            group = group,
            buffer = M.bufnr,
            desc = "[Solution Explorer] Keep cursor in line with the file listing",
            callback = function() set_cursor_pos() end,
        })
    end

    api.nvim_create_autocmd({ "WinNew", "WinClosed" }, {
        group = group,
        desc = "[Solution Explorer] Keep window the right side and the right size",
        callback = function()
            local winhl = M.get_winhl()
            if winhl and api.nvim_win_is_valid(winhl) then
                set_win_pos_and_size(winhl)
            end
        end,
    })
end

function M.init()
    main = require("solution")
    local buf_opts = {
        swapfile = false,
        buftype = "nofile",
        modifiable = false,
        filetype = "solution_explorer",
    }

    M.bufnr = api.nvim_create_buf(false, false)
    M.hi_ns = api.nvim_create_namespace("solution_explorer_highlights")
    M.ext_ns = api.nvim_create_namespace("solution_explorer_extmarks")
    for k, v in pairs(buf_opts) do
        api.nvim_set_option_value(k, v, { buf = M.bufnr })
    end

    register_keybinds()
    register_autocmds()
    M.redraw()
end

function M.is_open()
    local tabpage_winhl = M.get_winhl()
    return tabpage_winhl and api.nvim_win_is_valid(tabpage_winhl)
end

function M.get_winhl()
    local wininfo = wininfo_per_tabpage[api.nvim_get_current_tabpage()]
    return wininfo and wininfo.winhl
end

function M.get_winnr()
    local wininfo = wininfo_per_tabpage[api.nvim_get_current_tabpage()]
    return wininfo and wininfo.winnr
end

local function set_win_opts()
    local opts = {
        number = false,
        signcolumn = "yes",
        statuscolumn = "",
        foldcolumn = "0",
        wrap = false,
        winfixwidth = true,
        winfixheight = true,
        spell = false,
        foldmethod = "manual",
        list = false,
    }

    for k, v in pairs(opts) do
        vim.opt_local[k] = v
    end
end

function M.open()
    if M.is_open() then
        api.nvim_set_current_win(M.get_winnr())
        set_cursor_pos()
        return
    end

    vim.cmd("vsp")
    local winhl = api.nvim_get_current_win()
    local winnr = api.nvim_win_get_number(winhl)

    api.nvim_set_current_buf(M.bufnr)
    wininfo_per_tabpage[api.nvim_get_current_tabpage()] = { winhl = winhl, winnr = winnr }

    set_win_opts()
    set_win_pos_and_size(winhl)
    set_cursor_pos()
end

function M.close()
    if M.is_open() then
        api.nvim_win_close(M.get_winhl(), true)
    end
end

function M.toggle()
    if M.is_open() then
        M.close()
    else
        M.open()
    end
end

function M.redraw()
    api.nvim_set_option_value("modifiable", true, { buf = M.bufnr })

    local lines, highlights = renderer
        .new()
        :configure(main.config)
        :build_header(main.sln)
        :build_projects(main.sln.projects or { main.sln })
        :unwrap()

    api.nvim_buf_set_lines(M.bufnr, 0, -1, false, lines)
    for _, hl in ipairs(highlights) do
        api.nvim_buf_add_highlight(M.bufnr, M.hi_ns, hl.group, hl.line, hl.start, hl._end)
    end

    api.nvim_set_option_value("modifiable", false, { buf = M.bufnr })
end

return M
