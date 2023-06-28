local M = {}
M.__index = M

local utils = require("solution.utils")

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
--- @field node Node
--- @field read_line function
--- @param path string
function M.new(path)
    local self = setmetatable({}, M)

    if not path:find(".sln") then
        -- Opened a project directly, return a project instead. Project contains majority of the same stuff as a solution, so it can just pretend to be a solution.
        return require("solution.projectfile").new_from_file(path)
    else
        -- Opened a solution file
        self.name = vim.fn.fnamemodify(path, ":t:r")
        self.root = vim.fn.fnamemodify(path, ":p:h")
        self.path = path
        self.text = utils.file_read_all_text(path)
        self.type = "solution"
        self.projects = {}
        self.current_line = 1
        self.node = require("solution.explorer.node").new_folder(self.root, nil, self.name)

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
    end

    return self
end

return M
