local M = {}

local api = vim.api

local bufnr
local winhl
local frame = 1
local frames = {
    ".",
    "..",
    "...",
    " ..",
    "  .",
    "",
}

local timer_id

local function create_win_opts()
    local l = vim.o.lines - vim.o.cmdheight
    local c = vim.o.columns
    local h = math.ceil(l * 0.9)
    local w = math.ceil(c * 0.8)
    return {
        height = h,
        width = w,
        row = math.floor((l - h) / 2),
        col = math.floor((c - w) / 2),
        relative = "editor",
        style = "minimal",
        zindex = 50,
    }
end

function M.start(path)
    bufnr = api.nvim_create_buf(false, false)
    winhl = api.nvim_open_win(bufnr, true, create_win_opts())

    local buf_opts = {
        swapfile = false,
        buftype = "nofile",
        buflisted = false,
        bufhidden = "wipe",
        filetype = "solution_loading",
    }

    for k, v in pairs(buf_opts) do
        api.nvim_set_option_value(k, v, { buf = bufnr })
    end

    local group = api.nvim_create_augroup("solution_loading", { clear = true })
    api.nvim_create_autocmd("WinEnter", {
        group = group,
        callback = function()
            if api.nvim_buf_is_valid(bufnr) then
                api.nvim_buf_delete(bufnr, { force = true })
            end

            if api.nvim_win_is_valid(winhl) then
                api.nvim_win_close(winhl, true)
            end
        end,
    })

    local draw_frame = function()
        if not api.nvim_buf_is_valid(bufnr) then
            vim.fn.timer_stop(timer_id)
            return
        end

        api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Loading " .. path .. " " .. frames[frame] })
        frame = frame + 1

        if frame > #frames then
            frame = 1
        end
    end

    timer_id = vim.fn.timer_start(100, draw_frame, { ["repeat"] = -1 })
end

function M.stop() vim.fn.timer_stop(timer_id) end

return M
