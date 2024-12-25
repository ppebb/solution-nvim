local alert = require("solution.ui.alert")
local nuget_api = require("solution.nuget.api")
local textmenu = require("solution.ui.textmenu")
local utils = require("solution.utils")
local config = require("solution").config
local projects = require("solution").projects

--- @class NugetBrowser
--- @field tm Textmenu
--- @field page integer
--- @field query_text string|nil
--- @field query_count integer
--- @field results table<integer, QueryResult[]>
--- @field project ProjectFile|nil
--- @field cb fun(browser: NugetBrowser) Called upon adding a package to the project
local M = {}
M.__index = M

--- @param prompt string|nil
function M:search(prompt)
    -- If a new prompt is provided, reset everything
    if prompt then
        self.query_text = prompt
        self.query_count = 0
        self.results = {}
        self.page = 0
    end

    -- If the result already exists, then just return it
    local existing_result = self.results[self.page]
    if existing_result then
        return existing_result
    end

    self.query_count, self.results[self.page] =
        nuget_api.query(self.query_text or "", self.page * config.nuget.take, config.nuget.take)
end

--- @param num integer
function M:change_page(num)
    self.page = self.page + num

    if self.page < 0 then
        self.page = 0
    end

    local max_page = math.floor(self.query_count / config.nuget.take)
    if self.page > max_page then
        self.page = max_page
    end

    self:search()
end

function M:add_to_project(package_name, version)
    self.project:add_nuget_dep(package_name, version, function(success, message, code)
        local msg
        if not success then
            msg = string.format(
                "Failed to add package '%s' to project '%s'%s%s",
                package_name,
                self.project.name,
                (message and ", " .. message) or "",
                (code and ", code: " .. code) or ""
            )
        else
            msg = string.format("Successfully added package '%s' to project '%s'", package_name, self.project.name)
            if self.cb then
                self.cb(self)
            end
        end

        local wrapped = utils.word_wrap(msg, math.max(60, #self.project.name))
        vim.schedule(function() alert.open(wrapped) end)
    end)
end

--- @private
--- @return TextmenuHeader
function M:make_header()
    local lines = utils.center_align({
        " solution-nvim ",
        "Press 's' to search",
        "Query: " .. (#self.query_text ~= 0 and self.query_text or "None"),
        string.format(
            "%s Result%s: Page %s of %s",
            self.query_count,
            (self.query_count == 1 and "" or "s"),
            self.page + 1,
            math.ceil(self.query_count / config.nuget.take)
        ),
    }, self.tm.win_opts.width)

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
function M:format_desc(desc)
    local lines = utils.split_by_pattern(desc, "\n")
    local width = self.tm.win_opts.width - 6
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

--- @private
--- @return TextmenuEntry[]
function M:make_entries()
    local ret = {}
    if not self.results[self.page] then
        return ret
    end

    for _, result in ipairs(self.results[self.page]) do
        local lines = {}

        table.insert(
            lines,
            "  " .. result.id .. (result.verified and " " or "") .. " by: " .. table.concat(result.owners, ", ")
        )
        table.insert(lines, "    " .. result.totalDownloads .. " total downloads")
        table.insert(lines, "    Latest version: " .. result.versions[#result.versions].version)

        local desc_lines = self:format_desc(result.description)
        table.insert(ret, { text = lines, expand = desc_lines, data = { name = result.id, version = nil } })
    end

    return ret
end

--- @type Keymap[]
local keymaps = {
    {
        mode = "n",
        lhs = "s",
        opts = {
            noremap = true,
            callback = function(tm, browser, _)
                vim.ui.input({ prompt = "Search for a package: " }, function(input)
                    browser:search(input)
                    tm:render()
                end)
            end,
        },
    },
    {
        mode = "n",
        lhs = "f",
        opts = {
            noremap = true,
            callback = function(tm, browser, _)
                browser:change_page(1)
                tm:render()
            end,
        },
    },
    {
        mode = "n",
        lhs = "d",
        opts = {
            noremap = true,
            callback = function(tm, browser, _)
                browser:change_page(-1)
                tm:render()
            end,
        },
    },
    {
        mode = "n",
        lhs = "a",
        opts = {
            noremap = true,
            callback = function(_, browser, entry)
                if browser.project then
                    browser:add_to_project(entry.data.name, entry.data.version)
                else
                    vim.ui.select(utils.tbl_map_to_arr(projects, function(_, v) return v end), {
                        prompt = "Select a project: ",
                        format_item = function(item) return item.name end,
                    }, function(choice)
                        if not choice then
                            return
                        end

                        browser.project = choice
                        browser:add_to_project(entry.data.name, entry.data.version)
                    end)
                end
            end,
        },
    },
}

--- @param project ProjectFile|nil
--- @param cb fun(tm: NugetBrowser) Called upon adding a package to the project
--- @return NugetBrowser
function M.open(project, cb)
    local self = {}
    setmetatable(self, M)

    self.project = project
    self.query_text = ""
    self.page = 0
    self.cb = cb
    self.results = {}

    self.tm = textmenu.new(self, keymaps, "SolutionNugetBrowser", "SolutionNugetBrowser")
    self.tm:set_refresh(function() return self:make_header(), self:make_entries() end)

    self:search()
    self.tm:render()

    return self
end

function M:close() self.tm:close() end

return M
