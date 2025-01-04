local api = vim.api
local utils = require("solution.utils")

local function open_win(bufnr)
    return api.nvim_open_win(bufnr, true, {
        height = 14,
        split = "below",
    })
end

local function run(cmd, args, on_exit)
    local bufnr = api.nvim_create_buf(false, false)

    open_win(bufnr)

    local stdout_agg = {}
    local stderr_agg = {}

    vim.fn.termopen(string.format("%s %s", cmd, table.concat(args, " ")), {
        on_stdout = function(_, data) vim.list_extend(stdout_agg, data) end,
        on_stderr = function(_, data) vim.list_extend(stderr_agg, data) end,
        on_exit = function(_, code, event)
            vim.bo[bufnr].scrollback = vim.bo[bufnr].scrollback - 1
            vim.bo[bufnr].scrollback = vim.bo[bufnr].scrollback + 1

            if on_exit then
                on_exit(code, event, stdout_agg, stderr_agg)
            end
        end,
    })

    api.nvim_create_autocmd("TermClose", {
        buffer = bufnr,
        callback = function(_)
            if api.nvim_buf_is_valid(bufnr) then
                api.nvim_buf_delete(bufnr, { force = true })
            end
        end,
    })
end

return { run = run }
