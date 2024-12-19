local nuget_api = require("solution.nuget.api")
local textmenu = require("solution.textmenu")
local utils = require("solution.utils")
local config = require("solution").config
local projects = require("solution").projects

local M = {}

--- @type Textmenu
local tm

local page = 0
local query_text = nil
local count = 0
local results = {}

local function reset()
    query_text = ""
    page = 0
    results = {}
end

local function query()
    count, results[page] = nuget_api.query(query_text, page * config.nuget.take, config.nuget.take)
end

local function make_header()
    local lines = utils.center_align({
        " solution-nvim ",
        "Press 's' to search",
        "Query: " .. (#query_text ~= 0 and query_text or "None"),
        string.format(
            "%s Result%s: Page %s of %s",
            count,
            (count == 1 and "" or "s"),
            page + 1,
            math.ceil(count / config.nuget.take)
        ),
    }, tm.win_opts.width)

    local scol2 = lines[2]:find("'s'") - 1
    return {
        lines = lines,
        highlights = {
            { group = "SolutionNugetHeader", line = 0, col_start = lines[1]:find("%S") - 2, col_end = -1 },
            { group = "SolutionNugetHighlight", line = 1, col_start = scol2, col_end = scol2 + 3 },
        },
    }
end

--- @param desc string
--- @return string[]
local function format_desc(desc)
    local lines = utils.split_by_pattern(desc, "\n")
    local width = tm.win_opts.width - 6
    local i = 1

    while i <= #lines do
        local line = lines[i]

        if #line > width then
            local wrapped = utils.word_wrap(line, width)

            table.remove(lines, i)

            for _, word in ipairs(wrapped) do
                table.insert(lines, i, word)
                i = i + 1
            end
        end

        i = i + 1
    end

    table.insert(lines, "")

    return vim.tbl_map(function(e) return "      " .. e end, lines)
end

--- @return TextmenuEntry[]
local function make_entries()
    local ret = {}
    if not results[page] then
        return ret
    end

    for _, result in ipairs(results[page]) do
        local lines = {}

        table.insert(
            lines,
            "  " .. result.id .. (result.verified and " " or "") .. " by: " .. table.concat(result.owners, ", ")
        )
        table.insert(lines, "    " .. result.totalDownloads .. " total downloads")
        table.insert(lines, "    Latest version: " .. result.versions[#result.versions].version)

        local desc_lines = format_desc(result.description)
        table.insert(ret, { text = lines, expand = desc_lines, data = { name = result.id, version = nil } })
    end

    return ret
end

local function refresh() return make_header(), make_entries() end

--- @type Keymap[]
local keymaps = {
    { mode = "n", lhs = "s", opts = { noremap = true, callback = function(_) M.search({ prompt = true }) end } },
    { mode = "n", lhs = "f", opts = { noremap = true, callback = function(_) M.change_page(1) end } },
    { mode = "n", lhs = "d", opts = { noremap = true, callback = function(_) M.change_page(-1) end } },
    {
        mode = "n",
        lhs = "a",
        opts = {
            noremap = true,
            callback = function(entry)
                vim.ui.select(
                    utils.tbl_map_to_arr(projects, function(_, e) return e.name end),
                    { prompt = "Select a project:" },
                    function(choice)
                        local project = utils.resolve_project(choice)

                        project:add_nuget_dep(entry.data.name, entry.data.version, function(success, message, code)
                            local msg
                            if not success then
                                msg = string.format(
                                    "Failed to add package '%s' to project '%s'%s%s",
                                    entry.data.name,
                                    project.name,
                                    (message and ", " .. message) or "",
                                    (code and ", code: " .. code) or ""
                                )
                            else
                                msg = string.format(
                                    "Successfully added package '%s' to project '%s'",
                                    entry.data.name,
                                    project.name
                                )
                            end

                            local wrapped = utils.word_wrap(msg, 40)
                            vim.schedule(function() textmenu.alert(wrapped, #wrapped, 40) end)
                        end)
                    end
                )
            end,
        },
    },
}

function M.open()
    tm = textmenu.new("SolutionNugetBrowser", keymaps, "SolutionNugetBrowser")
    tm:set_refresh(refresh)

    M.search({ reset = true })
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
            tm:render()
        end)
    else
        if opts and opts.reset then
            reset()
        elseif results[page] then
            tm:render()
            return
        end
        query()
        tm:render()
    end
end

function M.change_page(num)
    page = page + num

    if page < 0 then
        page = 0
    end

    local max_page = math.floor(count / config.nuget.take)
    if page > max_page then
        page = max_page
    end

    M.search()
end

return M
