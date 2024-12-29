local api = vim.api
local uv = vim.uv or vim.loop

local M = {}

--- @class Command
--- @field name string
--- @field func fun(opts: table)
--- @field opts table?

local function commands_dir()
    local fname, _ = debug.getinfo(1).source:gsub("@", "")
    return vim.fn.fnamemodify(fname, ":h") -- no trailing slash
end

local function find_commands(dir)
    local uv = vim.uv or vim.loop

    local ret = {}

    local handle, err_name, err_msg = uv.fs_scandir(dir)
    if not handle then
        error(string.format("Unable to access handle for %s to detect command modules, %s:%s", dir, err_name, err_msg))
        return ret
    end

    while true do
        local name, _ = uv.fs_scandir_next(handle)
        if not name then
            break
        end

        if name ~= "init.lua" then
            table.insert(ret, name)
        end
    end

    return vim.mpack.encode(ret)
end

local initialized = false

function M.init()
    if initialized then
        return
    end

    initialized = true

    uv.queue_work(
        uv.new_work(
            find_commands,
            vim.schedule_wrap(function(ret)
                if not ret then
                    return
                end

                local files = vim.mpack.decode(ret)
                for _, file in ipairs(files) do
                    local command = require("solution.commands." .. vim.fn.fnamemodify(file, ":t:r"))
                    api.nvim_create_user_command(command.name, command.func, command.opts or {})
                end
            end)
        ),
        commands_dir()
    )
end

return M
