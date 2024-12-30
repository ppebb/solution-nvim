local api = vim.api
local utils = require("solution.utils")

local channel
local bufnr

local function open_win(_bufnr)
    return api.nvim_open_win(_bufnr, true, {
        height = 14,
        split = "below",
    })
end

-- TODO: find some way to detect the command finishing, because on_exit only
-- runs when the terminal is closed. One option would be to just execute the
-- command directly rather than allowing the terminal to continue to be used,
-- but that's lame...
local function open_term(winhl, on_exit)
    channel = vim.fn.termopen(vim.env.SHELL, { on_exit = on_exit })
    bufnr = api.nvim_win_get_buf(winhl)
end

local function run(cmd, args, on_exit)
    if not channel or not bufnr or not api.nvim_buf_is_valid(bufnr) then
        open_term(open_win(api.nvim_create_buf(false, false)), on_exit)
    elseif not utils.check_buf_visible(bufnr) then
        open_win(bufnr)
    end

    if not pcall(vim.fn.chansend, channel, string.format("%s %s\n", cmd, table.concat(args, " "))) then
        channel = nil
        run(cmd, args)
        return
    end

    api.nvim_create_autocmd("TermClose", {
        buffer = bufnr,
        callback = function(_)
            api.nvim_buf_delete(bufnr, { force = true })
            channel = nil
        end,
    })
end

return { run = run }
