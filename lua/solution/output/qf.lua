local api = vim.api
local utils = require("solution.utils")

local function quickfixtextfunc(opts)
    local ret = {}
    local items = vim.fn.getqflist({ id = opts.id, items = 1 }).items

    for i = opts.start_idx, opts.end_idx do
        local item = items[i]

        if item.valid == 1 then
            table.insert(
                ret,
                string.format("|| %s(%s,%s): %s", api.nvim_buf_get_name(item.bufnr), item.lnum, item.col, item.text)
            )
        else
            table.insert(ret, string.format("|| %s", item.text))
        end
    end

    return ret
end

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

    vim.fn.setqflist({}, "a", {
        lines = lines,
        efm = [[ %#%f(%l\\\,%c):\ %m]],
        quickfixtextfunc = quickfixtextfunc,
    })
end)

local function run(cmd, args, on_exit)
    vim.fn.setqflist({}, " ", {
        title = string.format("%s %s", cmd, table.concat(args, " ")),
    })

    local winhl = api.nvim_get_current_win()
    vim.cmd("bot copen")
    api.nvim_set_current_win(winhl)

    utils.spawn_proc(cmd, args, append, append, on_exit)
end

return { run = run }
