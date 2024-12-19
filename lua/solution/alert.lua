local api = vim.api
local utils = require("solution.utils")
local wu = require("solution.winutils")

--- @class Alert
--- @field bufnr integer
--- @field winhl integer
--- @field augroup integer
local M = {}
M.__index = M

local num_alerts = 0

--- @param text string[]
--- @param h integer|nil
--- @param w integer|nil
--- @return Alert
function M.open(text, h, w)
    local _w = w

    if not _w then
        _w = -1

        for _, line in ipairs(text) do
            if #line > _w then
                _w = #line
            end
        end
    end

    local _text = utils.center_align(text, _w)

    local opts = wu.create_win_opts(h or #_text, _w)
    opts.border = "single"
    local bufnr = api.nvim_create_buf(false, false)

    --- @type Alert
    local self = {
        bufnr = bufnr,
        winhl = api.nvim_open_win(bufnr, true, opts),
        augroup = api.nvim_create_augroup("solution_alert" .. num_alerts, { clear = true }),
    }
    setmetatable(self, M)

    wu.set_buf_opts(bufnr, { modifiable = true })

    api.nvim_buf_set_lines(bufnr, 0, -1, false, _text)

    api.nvim_buf_set_keymap(bufnr, "n", "q", "", { noremap = true, callback = function() self:close() end })

    api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", { noremap = true, callback = function() self:close() end })

    api.nvim_create_autocmd("VimResized", {
        group = self.augroup,
        buffer = bufnr,
        callback = function()
            local _opts = wu.create_win_opts(h, w)
            api.nvim_win_set_config(self.winhl, _opts)
        end,
    })

    api.nvim_create_autocmd({ "BufHidden", "BufUnload" }, {
        group = self.augroup,
        buffer = bufnr,
        callback = function()
            vim.schedule(function() self:close() end)
        end,
    })

    api.nvim_create_autocmd("WinEnter", {
        group = self.augroup,
        callback = function()
            local buftype = api.nvim_get_option_value("buftype", { buf = 0 })
            if buftype ~= "prompt" and buftype ~= "nofile" then
                self:close()
            end
        end,
    })

    api.nvim_set_option_value("modifiable", false, { buf = bufnr })

    num_alerts = num_alerts + 1

    return self
end

function M:close()
    wu.close_win_and_buf(self.winhl, self.bufnr)
    api.nvim_clear_autocmds({ group = self.augroup })
end

return M
