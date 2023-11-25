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
    local self = setmetatable({}, M)

    local path_mut = path
    if not path_mut then
        return nil
    end

    local path_root = utils.path_root(path_mut)

    local found_csproj = path_mut:find(".csproj") and path_mut or nil
    local found_sln = path_mut:find(".sln") and path_mut or nil
    if not (found_csproj or found_sln) then
        while true do
            path_mut = vim.fn.fnamemodify(path_mut, ":h") -- get the parent directory
            if path_mut == path_root then
                break
            end

            local handle = uv.fs_scandir(path_mut)
            if not handle then
                return nil
            end

            while true do
                local name, type = uv.fs_scandir_next(handle)
                if not name then
                    break
                end

                local abs_path = utils.path_combine(path_mut, name);
                type = type or (uv.fs_stat(abs_path) or {}).type

                if type == "file" then
                    if name:find(".csproj") then
                        found_csproj = abs_path
                        break
                    elseif name:find(".sln") then
                        found_sln = abs_path
                        break
                    end
                end
            end
        end
    end

    if found_sln then
        print("found slnfile " .. found_sln)
        -- Opened a solution file
        self.name = vim.fn.fnamemodify(found_sln, ":t:r")
        self.root = vim.fn.fnamemodify(found_sln, ":p:h")
        self.path = found_sln
        self.text = utils.file_read_all_text(found_sln)
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
    elseif found_csproj then
        print("found project" .. found_csproj)
        -- Project file should probably have most of the same functions defined as a Solution file, so just pretend it's a solution
        return require("solution.projectfile").new_from_file(found_csproj)
    end

    return nil -- couldn't find a csproj or sln anywhere
end

return M
