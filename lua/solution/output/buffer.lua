local api = vim.api
local utils = require("solution.utils")

local bufnr

local append = vim.schedule_wrap(function(err, data)
    local line = err or data
    if not line then
        return
    end

    local lines
    if line:find("\n") then
        lines = utils.split_by_pattern(line, "\n")
    else
        lines = { line }
    end

    api.nvim_buf_set_lines(bufnr, -2, -2, false, lines)
end)

local function open_win()
    local winhl = api.nvim_open_win(bufnr, false, {
        height = 14,
        split = "below",
    })

    api.nvim_set_option_value("wrap", false, { win = winhl })
end

local function create_buf()
    local _bufnr = api.nvim_create_buf(false, true)
    api.nvim_set_option_value("bufhidden", "wipe", { buf = _bufnr })

    return _bufnr
end

local function run(cmd, args, on_exit)
    if not bufnr or not api.nvim_buf_is_valid(bufnr) then
        bufnr = create_buf()
    end

    if not utils.check_buf_visible(bufnr) then
        open_win()
    end

    append(string.format("%s %s", cmd, table.concat(args, " ")))
    append("")
    utils.spawn_proc(cmd, args, append, append, function()
        append("")

        if on_exit then
            on_exit()
        end
    end)
end

return { run = run }
