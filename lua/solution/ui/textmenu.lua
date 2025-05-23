local api = vim.api
local utils = require("solution.utils")
local wu = require("solution.winutils")

--- @class Textmenu
--- @field instance any
--- @field bufnr integer
--- @field winhl integer
--- @field nsname string
--- @field augroup integer
--- @field hlns integer
--- @field extns integer
--- @field current_line integer
--- @field win_opts vim.api.keyset.win_config
--- @field restrict boolean
--- @field current_extid integer
--- @field entry_by_extid table<integer, TextmenuEntry>
--- @field old_pos integer[]
--- @field refresh fun(): TextmenuHeader, TextmenuEntry[]
--- @field header TextmenuHeader
--- @field entries TextmenuEntry[]
local M = {}
M.__index = M

--- @class TextmenuEntry
--- @field text string[]
--- @field expand? string[]
--- @field data? table Arbitrary data to hold in the entry for use with keymaps
--- @field skip? boolean
--- @field open? boolean

--- @class TextmenuHeader
--- @field lines string[]
--- @field highlights TextmenuHighlight[]

--- @class TextmenuHighlight
--- @field group string
--- @field line integer
--- @field col_start integer
--- @field col_end integer

function M:register_autocmds()
    self.augroup = api.nvim_create_augroup(self.nsname, { clear = true })

    api.nvim_create_autocmd("VimResized", {
        group = self.augroup,
        buffer = self.bufnr,
        callback = function()
            local opts = wu.create_win_opts()
            self.win_opts = opts
            api.nvim_win_set_config(self.winhl, opts)

            self:do_refresh()
            self:render()
        end,
    })

    api.nvim_create_autocmd({ "BufHidden", "BufUnload" }, {
        group = self.augroup,
        buffer = self.bufnr,
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

    api.nvim_create_autocmd("CursorMoved", {
        group = self.augroup,
        buffer = self.bufnr,
        callback = function()
            if not self.restrict then
                return
            end

            -- NOTE: Extmark row, col indexing is 0-based
            local extmarks = api.nvim_buf_get_extmarks(self.bufnr, self.extns, 0, -1, {})
            -- NOTE: pos row, col indexing is (1, 0) based, let's fix that
            -- nvim_win_set_cursor is indexed the same way
            local pos = api.nvim_win_get_cursor(self.winhl)
            local pos_row = pos[1] - 1

            local pextmark
            local nextmark
            for _, extmark in ipairs(extmarks) do
                local ext_row = extmark[2]

                if ext_row <= pos_row then
                    pextmark = extmark
                elseif ext_row > pos_row then
                    nextmark = extmark
                    break
                end
            end

            local old_row = self.old_pos and self.old_pos[1]

            if
                pextmark
                and (
                    not nextmark
                    or (old_row and pos_row <= old_row)
                    or (not old_row and pextmark)
                    -- HACK: This fixes an issue with skipping entries when they are only one line long
                    or (pextmark and nextmark and (nextmark[2] - pextmark[2] <= 1))
                )
            then
                api.nvim_win_set_cursor(self.winhl, { pextmark[2] + 1, pextmark[3] })
                self.current_extid = pextmark[1]
            elseif nextmark then
                api.nvim_win_set_cursor(self.winhl, { nextmark[2] + 1, nextmark[3] })
                self.current_extid = nextmark[1]
            end

            self.old_pos = api.nvim_win_get_cursor(self.winhl)
            self.old_pos[1] = self.old_pos[1] - 1
        end,
    })
end

--- @class KeymapOpts
--- @field noremap? boolean
--- @field nowait? boolean
--- @field silent? boolean
--- @field script? boolean
--- @field expr? boolean
--- @field unique? boolean
--- @field callback? fun(tm: Textmenu, instance: any, entry: TextmenuEntry)
--- @field desc? string
--- @field replace_keycodes? boolean

--- @class Keymap
--- @field mode string
--- @field lhs? string
--- @field rhs? string
--- @field opts? KeymapOpts

--- @param instance any Instance of object the textmenu represents
--- @param nsname string Name for highlight and extmark namespaces
--- @param keymaps Keymap[]
--- @param filetype string
--- @return Textmenu
function M.new(instance, keymaps, nsname, filetype)
    local win_opts = wu.create_win_opts()
    local bufnr = api.nvim_create_buf(false, true)

    --- @type Textmenu
    --- @diagnostic disable-next-line: missing-fields
    local self = {
        instance = instance,
        bufnr = bufnr,
        winhl = api.nvim_open_win(bufnr, true, win_opts),
        nsname = nsname,
        win_opts = win_opts,
        current_line = 0,
        hlns = api.nvim_create_namespace(nsname),
        extns = api.nvim_create_namespace(nsname .. "_exts"),
        restrict = true,
        entry_by_extid = {},
    }

    setmetatable(self, M)
    wu.set_buf_opts(bufnr, { filetype = filetype })

    self:register_autocmds()

    api.nvim_buf_set_keymap(self.bufnr, "n", "q", "", { noremap = true, callback = function() self:close() end })
    api.nvim_buf_set_keymap(self.bufnr, "n", "<ESC>", "", { noremap = true, callback = function() self:close() end })
    api.nvim_buf_set_keymap(self.bufnr, "n", "<CR>", "", {
        noremap = true,
        callback = function()
            if not api.nvim_get_option_value("modifiable", { buf = self.bufnr }) then
                api.nvim_set_option_value("modifiable", true, { buf = self.bufnr })
            end

            if self.current_extid then
                local entry = self.entry_by_extid[self.current_extid]
                local ext = api.nvim_buf_get_extmark_by_id(self.bufnr, self.extns, self.current_extid, {})

                if not entry.expand then
                    return
                end

                local start_line = ext[1] + #entry.text
                local end_line = start_line + #entry.expand
                if entry.open then
                    api.nvim_buf_set_lines(self.bufnr, start_line, end_line, false, {})
                else
                    api.nvim_buf_set_lines(self.bufnr, start_line, start_line, false, entry.expand)
                end

                entry.open = not entry.open
            end

            api.nvim_set_option_value("modifiable", false, { buf = self.bufnr })
        end,
    })

    for _, keymap in ipairs(keymaps) do
        local opts = utils.tbl_shallow_copy(keymap.opts)

        if opts.callback then
            local temp = opts.callback
            if temp then
                opts.callback = function()
                    local entry
                    if self.current_extid then
                        entry = self.entry_by_extid[self.current_extid]
                    end

                    temp(self, instance, entry)
                end
            end
        end

        api.nvim_buf_set_keymap(self.bufnr, keymap.mode, keymap.lhs or "", keymap.rhs or "", opts)
    end

    return self
end

--- @param restrict boolean
function M:set_restrict_cursor(restrict) self.restrict = restrict end

--- @private
function M:add_lines(lines)
    api.nvim_buf_set_lines(self.bufnr, self.current_line, -1, false, lines)
    self.current_line = self.current_line + #lines
end

--- @param func fun(): TextmenuHeader, TextmenuEntry[]
function M:set_refresh(func) self.refresh = func end

function M:do_refresh()
    self.header, self.entries = self.refresh()
end

function M:render()
    self.current_line = 0
    self.entry_by_extid = {}
    api.nvim_buf_clear_namespace(self.bufnr, self.hlns, 0, -1)
    api.nvim_buf_clear_namespace(self.bufnr, self.extns, 0, -1)

    self:do_refresh()

    if not api.nvim_get_option_value("modifiable", { buf = self.bufnr }) then
        api.nvim_set_option_value("modifiable", true, { buf = self.bufnr })
    end

    self:add_lines(self.header.lines)
    self:add_lines({ "" })

    for _, hl in ipairs(self.header.highlights) do
        api.nvim_buf_add_highlight(self.bufnr, self.hlns, hl.group, hl.line, hl.col_start, hl.col_end)
    end

    for _, entry in ipairs(self.entries) do
        local start = entry.text[1]:find("%S")
        local ext_row = self.current_line

        self:add_lines(entry.text)

        if not entry.skip and start then
            local ext_id = api.nvim_buf_set_extmark(self.bufnr, self.extns, ext_row, start - 1, {})
            self.entry_by_extid[ext_id] = entry
        end
    end

    api.nvim_set_option_value("modifiable", false, { buf = self.bufnr })

    api.nvim_win_set_cursor(self.winhl, { 1, 0 })
end

function M:close()
    wu.close_win_and_buf(self.winhl, self.bufnr)
    api.nvim_clear_autocmds({ group = self.augroup })
end

return M
