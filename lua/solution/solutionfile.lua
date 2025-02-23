local alert = require("solution.ui.alert")
local data_manager = require("solution.data_manager")
local utils = require("solution.utils")
local slns = require("solution").slns

--- @class SolutionFile
--- @field name string
--- @field root string
--- @field path string
--- @field text string[]
--- @field version number
--- @field projects table<string, ProjectFile>
--- @field current_line integer
--- @field building boolean
--- @field running boolean
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
    if not path or not utils.is_sln(path) then
        return nil
    end

    local path_full = vim.fn.fnamemodify(path, ":p")
    if slns[path_full] then
        return slns[path_full]
    end

    if not utils.file_exists(path_full) then
        return nil
    end

    local self = setmetatable({}, M)

    -- Opened a solution file
    self.name = vim.fn.fnamemodify(path, ":t")
    self.root = vim.fn.fnamemodify(path, ":p:h")
    self.path = path_full
    -- The file is guaranteed to exist, barring something incrediblt odd
    -- happening the file should read
    ---@diagnostic disable-next-line: assign-type-mismatch
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
    data_manager.set_default_sln(self)

    return self
end

--- @param project ProjectFile
--- @param cb fun(success: boolean, message?: string, code?: integer)
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
--- @param cb fun(success: boolean, message?: string, code?: integer)
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

--- @param extra_args? string[]
function M:build(output, extra_args)
    if self.building then
        alert.open({ string.format("Solution '%s' is already building.", self.name) })
        return
    end

    self.building = true

    utils.execute_dotnet_in_output(output, { "build", self.path }, extra_args, function() self.building = false end)
end

--- @param extra_args? string[]
function M:run(output, extra_args)
    if self.running then
        alert.open({ string.format("Solution '%s' is already running.", self.name) })
        return
    end

    self.running = true

    utils.execute_dotnet_in_output(output, { "build", self.path }, extra_args, function() self.running = false end)
end

--- @param extra_args? string[]
function M:clean(output, extra_args) utils.execute_dotnet_in_output(output, { "clean", self.path }, extra_args) end

--- @param extra_args? string[]
function M:restore(output, extra_args) utils.execute_dotnet_in_output(output, { "restore", self.path }, extra_args) end

return M
