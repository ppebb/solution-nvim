local api = vim.api
local nuget_api = require("solution.nuget.api")

local M = {}

local _config
local bufnr
local winhl

local page = 0
local query_text = nil
local count = 0
local results = {}

function M.init(config) _config = config end

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

local function close()
    if winhl and api.nvim_win_is_valid(winhl) then
        api.nvim_win_close(winhl, true)
    end

    if bufnr and api.nvim_buf_is_valid(bufnr) then
        api.nvim_buf_delete(bufnr, { force = true })
    end
end

function M.open()
    bufnr = api.nvim_create_buf(false, true)
    winhl = api.nvim_open_win(bufnr, true, create_win_opts())

    local buf_opts = {
        modifiable = false,
        swapfile = false,
        buftype = "nofile",
        buflisted = false,
        bufhidden = "wipe",
        filetype = "solution_nuget_browser",
    }

    for k, v in pairs(buf_opts) do
        api.nvim_buf_set_option(bufnr, k, v)
    end

    local group = api.nvim_create_augroup("SolutionNugetBrowser", { clear = true })
    api.nvim_create_autocmd("VimResized", {
        group = group,
        buffer = bufnr,
        callback = function()
            M.render()
            api.nvim_win_set_config(winhl, create_win_opts())
        end,
    })

    api.nvim_create_autocmd({ "BufHidden", "BufUnload" }, {
        group = group,
        buffer = bufnr,
        callback = function()
            vim.schedule(function()
                if api.nvim_win_is_valid(winhl) then
                    api.nvim_win_close(winhl, true)
                end
            end)
        end,
    })

    api.nvim_create_autocmd("WinEnter", {
        group = group,
        pattern = "*",
        callback = function()
            local buftype = api.nvim_buf_get_option(0, "buftype")
            if buftype ~= "prompt" and buftype ~= "nofile" then
                close()
                return true
            end
        end,
    })

    api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
        noremap = true,
        callback = function() close() end,
    })

    api.nvim_buf_set_keymap(bufnr, "n", "s", "", {
        noremap = true,
        callback = function() M.search({ prompt = true }) end,
    })

    api.nvim_buf_set_keymap(bufnr, "n", "f", "", {
        noremap = true,
        callback = function() M.change_page(1) end,
    })

    api.nvim_buf_set_keymap(bufnr, "n", "d", "", {
        noremap = true,
        callback = function() M.change_page(-1) end,
    })

    M.search({ reset = true })
end

local function reset()
    query_text = nil
    page = 0
    results = {}
end

local function query()
    count, results[page] = nuget_api.query(query_text, page * _config.nuget.take, _config.nuget.take)
end

function M.search(opts) -- This is really ugly but vim.ui.input cannot be done synchronously
    if opts and opts.prompt then
        vim.ui.input({ prompt = "Search for a package" }, function(input)
            if not input then
                return
            end
            reset()
            query_text = input
            query()
            M.render()
        end)
    else
        if opts and opts.reset then
            reset()
        elseif results[page] then
            M.render()
            return
        end
        query()
        M.render()
    end
end

function M.change_page(num)
    page = page + num

    if page < 0 then
        page = 0
    end

    local max_page = math.floor(count / _config.nuget.take)
    if page > max_page then
        page = max_page
    end

    M.search()
end

local function center_align(text_arr)
    local numspaces = {}
    for _, line in pairs(text_arr) do
        table.insert(numspaces, math.floor((api.nvim_win_get_width(winhl) - api.nvim_strwidth(line)) / 2))
    end

    local centered = {}
    for i = 1, #text_arr do
        table.insert(centered, (" "):rep(numspaces[i]) .. text_arr[i])
    end

    return centered
end

local hi_ns = api.nvim_create_namespace("solution_nuget_highlights")

local function header()
    local lines =
        center_align({ " solution-nvim ", "Press 's' to search", "Query: " .. (query_text and query_text or "None") })
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local scol = lines[1]:find("%S") - 2
    api.nvim_buf_add_highlight(bufnr, hi_ns, "SolutionNugetHeader", 0, scol, -1)
    scol = lines[2]:find("'s'") - 1
    api.nvim_buf_add_highlight(bufnr, hi_ns, "SolutionNugetHighlight", 1, scol, scol + 3)

    return #lines
end

function M.render()
    if not api.nvim_buf_get_option(bufnr, "modifiable") then
        api.nvim_buf_set_option(bufnr, "modifiable", true)
    end

    local current_line = header()

    api.nvim_buf_set_lines(
        bufnr,
        current_line,
        -1,
        false,
        center_align({
            "  "
                .. count
                .. " "
                .. (count == 1 and "Result" or "Results")
                .. ": Page "
                .. page + 1
                .. " of "
                .. math.ceil(count / _config.nuget.take),
        })
    )
    current_line = current_line + 1

    if not results[page] then
        return
    end

    for _, result in ipairs(results[page]) do
        local lines = {}

        table.insert(
            lines,
            "  " .. result.id .. (result.verified and " " or "") .. " by: " .. table.concat(result.owners, ", ")
        )
        table.insert(lines, "  v " .. result.totalDownloads .. " total downloads")
        table.insert(lines, "  Latest version: " .. result.versions[#result.versions].version)
        table.insert(lines, "  " .. result.description:gsub("\n", " "))

        api.nvim_buf_set_lines(bufnr, current_line, -1, false, lines)
        current_line = current_line + #lines
    end

    api.nvim_buf_set_option(bufnr, "modifiable", false)
end

return M
