local api = vim.api

--- @class Textmenu
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
--- @field expand string[]
--- @field data table Arbitrary data to hold in the entry for use with keymaps
--- @field open? boolean

--- @class TextmenuHeader
--- @field lines string[]
--- @field highlights TextmenuHighlight[]

--- @class TextmenuHighlight
--- @field group string
--- @field line integer
--- @field col_start integer
--- @field col_end integer

--- @return vim.api.keyset.win_config
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

function M:register_autocmds()
    self.augroup = api.nvim_create_augroup(self.nsname, { clear = true })

    api.nvim_create_autocmd("VimResized", {
        group = self.augroup,
        buffer = self.bufnr,
        callback = function()
            local opts = create_win_opts()
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
            vim.schedule(function()
                if api.nvim_win_is_valid(self.winhl) then
                    api.nvim_win_close(self.winhl, true)
                end
            end)
        end,
    })

    api.nvim_create_autocmd("WinEnter", {
        group = self.augroup,
        callback = function()
            local buftype = api.nvim_get_option_value("buftype", { buf = 0 })
            if buftype ~= "prompt" and buftype ~= "nofile" then
                self:close()
                return true
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

            if (old_row and pos_row <= old_row and pextmark) or (not old_row and pextmark) or not nextmark then
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

--- @class Keymap
--- @field mode string
--- @field lhs? string
--- @field rhs? string
--- @field opts? vim.api.keyset.keymap

--- @param nsname string
--- @param keymaps Keymap[]
--- @param filetype string
--- @return Textmenu
function M.new(nsname, keymaps, filetype)
    local opts = create_win_opts()
    local bufnr = api.nvim_create_buf(false, true)

    --- @type Textmenu
    --- @diagnostic disable-next-line: missing-fields
    local self = {
        bufnr = bufnr,
        winhl = api.nvim_open_win(bufnr, true, opts),
        nsname = nsname,
        win_opts = opts,
        current_line = 0,
        hlns = api.nvim_create_namespace(nsname),
        extns = api.nvim_create_namespace(nsname .. "_exts"),
        restrict = true,
        entry_by_extid = {},
    }

    setmetatable(self, M)
    local buf_opts = {
        modifiable = false,
        swapfile = false,
        buftype = "nofile",
        buflisted = false,
        bufhidden = "wipe",
        filetype = filetype,
    }

    for k, v in pairs(buf_opts) do
        api.nvim_set_option_value(k, v, { buf = self.bufnr })
    end

    self:register_autocmds()

    api.nvim_buf_set_keymap(self.bufnr, "n", "q", "", { noremap = true, callback = function() self:close() end })
    api.nvim_buf_set_keymap(self.bufnr, "n", "<CR>", "", {
        noremap = true,
        callback = function()
            if not api.nvim_get_option_value("modifiable", { buf = self.bufnr }) then
                api.nvim_set_option_value("modifiable", true, { buf = self.bufnr })
            end

            if self.current_extid then
                local entry = self.entry_by_extid[self.current_extid]
                local ext = api.nvim_buf_get_extmark_by_id(self.bufnr, self.extns, self.current_extid, {})

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
        if keymap.opts and keymap.opts.callback then
            local temp = keymap.opts.callback
            keymap.opts.callback = function()
                local entry
                if self.current_extid then
                    entry = self.entry_by_extid[self.current_extid]
                end

                temp(entry)
            end
        end

        api.nvim_buf_set_keymap(self.bufnr, keymap.mode, keymap.lhs or "", keymap.rhs or "", keymap.opts or {})
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
        local ext_col = entry.text[1]:find("%S") - 1
        local ext_row = self.current_line

        self:add_lines(entry.text)

        if ext_col then
            local ext_id = api.nvim_buf_set_extmark(self.bufnr, self.extns, ext_row, ext_col, {})
            self.entry_by_extid[ext_id] = entry
        end
    end

    api.nvim_set_option_value("modifiable", false, { buf = self.bufnr })

    api.nvim_win_set_cursor(self.winhl, { 1, 0 })
end

function M:close()
    if self.winhl and api.nvim_win_is_valid(self.winhl) then
        api.nvim_win_close(self.winhl, true)
    end

    if self.bufnr and api.nvim_buf_is_valid(self.bufnr) then
        api.nvim_buf_delete(self.bufnr, { force = true })
    end
end

return M
