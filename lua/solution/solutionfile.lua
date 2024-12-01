local utils = require("solution.utils")
local slns = require("solution").slns

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

--- @class SolutionFile
--- @field name string
--- @field root string
--- @field path string
--- @field text string[]
--- @field version number
--- @field projects table<string, ProjectFile>
--- @field current_line integer
--- @field read_line function
--- @field add_project function
--- @field remove_project function
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
    self.name = vim.fn.fnamemodify(path, ":t:r")
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

--- @param self SolutionFile
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

--- @param self SolutionFile
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

return M
