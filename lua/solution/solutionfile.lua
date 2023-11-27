local M = {}
M.__index = M

local utils = require("solution.utils")
local uv = vim.uv or vim.loop

--- @param self SolutionFile
--- @param version_str string
local function validate_slnfile_verison(self, version_str)
    local version = version_str:match("%d+")
    if not version then
        error("SolutionParseVersionError")
    end
    self.version = tonumber(version)
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
--- @field projects ProjectFile[]
--- @field current_line integer
--- @field read_line function
--- @param path string
--- @return SolutionFile|ProjectFile|nil
function M.new(path)
    if not path then
        return nil
    end
    local self = setmetatable({}, M)

    local found_projects, found_solutions = utils.search_files(path)
    print("slns " .. vim.inspect(found_solutions) .. " csproj " .. vim.inspect(found_projects))

    if found_solutions and #found_solutions > 0 then
        local found_solution = found_solutions[1]
        -- Opened a solution file
        self.name = vim.fn.fnamemodify(found_solution, ":t:r")
        self.root = vim.fn.fnamemodify(found_solution, ":p:h")
        self.path = found_solution
        self.text = utils.file_read_all_text(found_solution)
        self.type = "solution"
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
    elseif found_projects and #found_projects > 0 then
        -- Project file should probably have most of the same functions defined as a Solution file, so just pretend it's a solution
        return require("solution.projectfile").new_from_file(found_projects[1])
    end

    return nil -- couldn't find a csproj or sln anywhere
end

return M
