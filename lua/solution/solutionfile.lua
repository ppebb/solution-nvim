local utils = require("solution.utils")

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
--- @field text string
--- @field type string
--- @field version number
--- @field projects ProjectFile[]
--- @field current_line integer
--- @field read_line function
--- @field add_project function
--- @field remove_project function
--- @field project_from_name fun(self: SolutionFile, name: string): ProjectFile|nil
--- @param path string
--- @return SolutionFile|nil
function M.new(path)
    if not path then
        return nil
    end

    local self = setmetatable({}, M)

    -- Opened a solution file
    self.name = vim.fn.fnamemodify(path, ":t:r")
    self.root = vim.fn.fnamemodify(path, ":p:h")
    self.path = path
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
            table.insert(self.projects, project)
            -- elseif -- handle additional lines
        end
    end

    return self
end

local function resolve_path_or_project(path_or_project)
    if type(path_or_project) == "string" then
        if not utils.file_exists(path_or_project) then
            return nil, nil
        end

        return path_or_project, require("solution").aggregate_projects[vim.fn.fnamemodify(path_or_project, ":p")]
    else
        return path_or_project.path, path_or_project
    end
end

--- @param self SolutionFile
--- @param path_or_project string|ProjectFile
function M:add_project(path_or_project)
    local path, project = resolve_path_or_project(path_or_project)

    if not path then
        print(("Error adding project '%s' to solution '%s', file does not exist!"):format(path_or_project, self.name))
        return
    end

    local stdout_agg = ""
    local stderr_agg = ""
    utils.spawn_proc(
        "dotnet",
        { "sln", self.path, "add", path },
        function(_, chunk) stdout_agg = stdout_agg .. (chunk or "") end,
        function(_, chunk) stderr_agg = stderr_agg .. (chunk or "") end,
        function(code)
            if stdout_agg:find("added to the solution", 1, true) and code == 0 then
                print(string.format("Successfully added project '%s' to the solution '%s'", path, self.name))

                if project then
                    table.insert(self.projects, project)
                else
                    table.insert(self.projects, require("solution.projectfile").new_from_file(path))
                end
                return
            end

            print(
                ("Error adding project '%s' to the solution '%s', message '%s', code '%s'"):format(
                    path,
                    self.name,
                    (stdout_agg .. stderr_agg):gsub("\n", ""),
                    code
                )
            )
        end
    )
end

--- @param path_or_project string|ProjectFile
function M:remove_project(path_or_project)
    local path, project = resolve_path_or_project(path_or_project)

    if not path then
        print(
            ("Error removing project '%s' from solution '%s', file does not exist!"):format(path_or_project, self.name)
        )
        return
    end

    local stdout_agg = ""
    local stderr_agg = ""
    utils.spawn_proc(
        "dotnet",
        { "sln", "remove", path },
        function(_, chunk) stdout_agg = stdout_agg .. chunk end,
        function(_, chunk) stderr_agg = stderr_agg .. chunk end,
        function(code)
            if stdout_agg:find("added to the solution", 1, true) and code == 0 then
                print(string.format("Successfully added project '%s' to the solution '%s'", path, self.name))

                if project then
                    table.remove(self.projects, utils.tbl_find(self.projects, project))
                end

                return
            end

            print(
                ("Error adding project '%s' to the solution '%s', message '%s', code '%s'"):format(
                    path,
                    self.name,
                    (stdout_agg .. stderr_agg):gsub("\n", ""),
                    code
                )
            )
        end
    )
end

--- Returns the project matching the provided name, or nil
--- @param self SolutionFile
--- @param name string
--- @return ProjectFile|nil
function M:project_from_name(name)
    for _, project in ipairs(self.projects) do
        if project.name == name then
            return project
        end
    end

    return nil
end

return M
