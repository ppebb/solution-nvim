local M = {}

local actions = require("solution.explorer.actions")
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

local function register_keybinds()
    local function normal(lhs, desc, cb) api.nvim_buf_set_keymap(M.bufnr, "n", lhs, "", { desc = desc, callback = cb }) end

    normal("q", "[Solution Explorer] Quit menu", M.toggle)
    normal("<ESC>", "[Solution Explorer] Quit menu", M.toggle)
    normal("<CR>", "[Solution Explorer] Open node", actions.open)
    normal("<2-LeftMouse>", "[Solution Explorer] Open node", actions.open)
    normal("a", "[Solution Explorer] New file", actions.new)
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
    require("solution.explorer.actions").init()
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
