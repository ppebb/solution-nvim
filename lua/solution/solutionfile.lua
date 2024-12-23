local alert = require("solution.alert")
local textmenu = require("solution.textmenu")
local utils = require("solution.utils")
local projects = require("solution").projects
local slns = require("solution").slns

--- @class SolutionFile
--- @field name string
--- @field root string
--- @field path string
--- @field text string[]
--- @field version number
--- @field projects table<string, ProjectFile>
--- @field current_line integer
local M = {}
M.__index = M

--- @param self SolutionFile
--- @param version_str string
local function validate_slnfile_verison(self, version_str)
    local version = version_str:match("%d+")
    if not version then
        error("SolutionParseVersionError")
    end

    self.version = tonumber(version) or error("SolutionParseVersionError")
end

--- @param self SolutionFile
local function parse_slnfile_header(self)
    local SLNFILE_HEADER_NO_VERSION = "Microsoft Visual Studio Solution File, Format Version "

    for _ = 1, 2 do
        local str = self:read_line()
        if not str then
            break
        end

        if utils.starts_with(str, SLNFILE_HEADER_NO_VERSION) then
            validate_slnfile_verison(self, str:sub(#SLNFILE_HEADER_NO_VERSION))
            return
        end
    end

    error("SolutionParseNoHeaderError")
end

function M:read_line()
    local line = self.text[self.current_line + 1]
    self.current_line = self.current_line + 1

    return (line and utils.trim(line)) or nil
end

--- @param path string
--- @return SolutionFile|nil
function M.new(path)
    if not path then
        return nil
    end

    local path_full = vim.fn.fnamemodify(path, ":p")
    if slns[path_full] then
        return slns[path_full]
    end

    local self = setmetatable({}, M)

    -- Opened a solution file
    self.name = vim.fn.fnamemodify(path, ":t")
    self.root = vim.fn.fnamemodify(path, ":p:h")
    self.path = path_full
    self.text = utils.file_read_all_text(path)
    self.projects = {}
    self.current_line = 1

    parse_slnfile_header(self)

    while true do
        local line = self:read_line()
        if not line then
            break
        end

        if utils.starts_with(line, "Project(") then
            local project = require("solution.projectfile").new_from_sln(self, line)
            self.projects[project.path] = project
            -- elseif -- handle additional lines
        end
    end

    slns[path_full] = self
    return self
end

--- @param project ProjectFile
--- @param cb fun(success: boolean, message: string|nil, code: integer?)
function M:add_project(project, cb)
    utils.spawn_proc(
        "dotnet",
        { "sln", self.path, "add", project.path },
        nil,
        nil,
        function(code, _, stdout_agg, stderr_agg)
            if not stdout_agg:find("added to the solution", 1, true) or code ~= 0 then
                cb(false, (stdout_agg .. stderr_agg):gsub("\n", ""), code)
                return
            end

            self.projects[project.path] = project

            cb(true, nil, nil)
        end
    )
end

--- @param project ProjectFile
--- @param cb fun(success: boolean, message: string|nil, code: integer?)
function M:remove_project(project, cb)
    utils.spawn_proc(
        "dotnet",
        { "sln", self.path, "remove", project.path },
        nil,
        nil,
        function(code, _, stdout_agg, stderr_agg)
            if not stdout_agg:find("removed from the solution", 1, true) or code ~= 0 then
                cb(false, (stdout_agg .. stderr_agg):gsub("\n", ""), code)
                return
            end

            if project then
                self.projects[project.path] = nil
            end

            cb(true, nil, nil)
        end
    )
end

--- @private
--- @return TextmenuHeader
function M:make_header(width)
    local lines = utils.center_align({
        " solution-nvim ",
        "Editing solution " .. self.name,
    }, width)

    return {
        lines = lines,
        highlights = {
            { group = "SolutionNugetHeader", line = 0, col_start = lines[1]:find("%S") - 2, col_end = -1 },
        },
    }
end

--- @private
--- @return TextmenuEntry[]
function M:make_entries()
    local ret = {}

    if vim.tbl_count(self.projects) == 0 then
        table.insert(ret, {
            text = { "    No projects present" },
            expand = {},
            data = {},
        })

        return ret
    end

    for _, project in pairs(self.projects) do
        local expand = {}

        for _, dependency in ipairs(project.dependencies) do
            local line

            if dependency.type == "Nuget" then
                line = string.format("        Package Dependency %s (%s)", dependency.name, dependency.version)
            elseif dependency.type == "Project" then
                line = string.format("        Project Dependency %s (%s)", dependency.name, dependency.rel_path)
            elseif dependency.type == "Local" then
                line = string.format("        Local Dependency %s (%s)", dependency.name, dependency.path)
            end

            table.insert(expand, line)
        end

        table.insert(expand, "")

        table.insert(ret, {
            text = { string.format("    %s (%s)", project.name, project.path) },
            expand = expand,
            data = { project = project },
        })
    end

    return ret
end

-- NOTE: As far as I can tell this is the only way to provide the solution to
-- complete for, because viml anonymous functions aren't a thing. One option
-- would be redefining some viml function within the callback using this... but
-- honestly I think that's worse
_G.SolutionToCompleteFor = nil
function _G.SolutionAddProjectCompletion(_)
    local sln = _G.SolutionToCompleteFor
    if sln then
        return utils.tbl_map_to_arr(
            vim.tbl_filter(function(proj) return not vim.tbl_contains(sln.projects, proj) end, projects),
            function(_, e) return e.name end
        )
    else
        return utils.tbl_map_to_arr(projects, function(_, v) return v.name end)
    end
end

--- @type Keymap[]
local keymaps = {
    {
        mode = "n",
        lhs = "a",
        opts = {
            noremap = true,
            callback = function(tm, sln, _)
                _G.SolutionToCompleteFor = sln

                local handle_input = function(input)
                    if not input or #input == 0 then
                        alert.open({ "No project name provided" })
                        return
                    end

                    local project = utils.resolve_project(input)
                    if not project then
                        alert.open(utils.word_wrap(string.format("Project '%s' could not be found!", input), 40))
                        return
                    end

                    local cb = function(success, message, code)
                        local alert_message
                        if not success then
                            alert_message = string.format(
                                "Failed to add project '%s' to solution '%s'%s%s",
                                project.name,
                                sln.name,
                                (message and ", " .. message) or "",
                                (code and ", code: " .. code) or ""
                            )
                        else
                            tm:render()

                            alert_message = string.format(
                                "Successfully added project '%s' to solution '%s'!",
                                project.name,
                                sln.name
                            )
                        end

                        alert.open(utils.word_wrap(alert_message, 40))
                    end

                    sln:add_project(project, vim.schedule_wrap(cb))
                end

                vim.ui.input(
                    { prompt = "Add a project: ", completion = "customlist,v:lua.SolutionAddProjectCompletion" },
                    handle_input
                )
            end,
        },
    },
    {
        mode = "n",
        lhs = "d",
        opts = {
            noremap = true,
            callback = function(tm, sln, entry)
                if not entry.data.project then
                    return
                end

                local cb = function(success, message, code)
                    local alert_message
                    if not success then
                        alert_message = string.format(
                            "Failed to remove project '%s' from solution '%s'%s%s",
                            entry.data.project.name,
                            sln.name,
                            (message and ", " .. message) or "",
                            (code and ", code: " .. code) or ""
                        )
                    else
                        tm:render()

                        alert_message = string.format(
                            "Successfully removed project '%s' to solution '%s'!",
                            entry.data.project.name,
                            sln.name
                        )
                    end

                    alert.open(utils.word_wrap(alert_message, 40))
                end

                sln:remove_project(entry.data.project, vim.schedule_wrap(cb))
            end,
        },
    },
}

function M:open_textmenu()
    local tm = textmenu.new(self, keymaps, "SolutonEditor", "SolutonEditor")
    tm:set_refresh(function() return self:make_header(tm.win_opts.width), self:make_entries() end)
    tm:render()
end

return M
