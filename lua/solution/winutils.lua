local api = vim.api

local M = {}

--- @param height integer|nil
--- @param width integer|nil
--- @return vim.api.keyset.win_config
function M.create_win_opts(height, width)
    local l = vim.o.lines - vim.o.cmdheight
    local c = vim.o.columns
    local h = height or math.ceil(l * 0.9)
    local w = width or math.ceil(c * 0.8)
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

--- @param bufnr integer
function M.set_buf_opts(bufnr, opts)
    local buf_opts = {
        modifiable = false,
        swapfile = false,
        buftype = "nofile",
        buflisted = false,
        bufhidden = "wipe",
    }

    buf_opts = vim.tbl_deep_extend("force", buf_opts, opts or {})

    for k, v in pairs(buf_opts) do
        api.nvim_set_option_value(k, v, { buf = bufnr })
    end
end

--- @param winhl integer
--- @param bufnr integer
function M.close_win_and_buf(winhl, bufnr)
    if winhl and api.nvim_win_is_valid(winhl) then
        api.nvim_win_close(winhl, true)
    end

    if bufnr and api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_delete(bufnr, { force = true })
    end
end

return M
