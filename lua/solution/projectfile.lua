local xml2lua = require("xml2lua")
local handler = require("xmlhandler.tree")
local utils = require("solution.utils")
local aggregate_projects = require("solution").aggregate_projects

local M = {}
M.__index = M

--- @class ProjectFile
--- @field name string
--- @field root string
--- @field path string
--- @field text string
--- @field type string
--- @param path string
function M.new_from_file(path)
    if aggregate_projects[path] then
        return aggregate_projects[path]
    end

    local self = setmetatable({}, M)

    self.name = vim.fn.fnamemodify(path, ":t:r")
    self.root = vim.fn.fnamemodify(path, ":p:h")
    self.path = path
    self.text = utils.file_read_all_text(path)
    self.type = "project"

    self:refresh_xml()

    aggregate_projects[self.path] = self

    return self
end

-- Matches and extracts information from Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "ClassLibrary1", "ClassLibrary1\ClassLibrary1.csproj", "{05A5AD00-71B5-4612-AF2F-9EA9121C4111}"
local CRACK_PROJECT_LINE = "^" -- Beginning of line
    .. 'Project%("({[%a%d-]+})"%)' -- Match Project("{AHFS-AHF...}")
    .. "%s*=%s*" -- Any amount of whitespace plus "=" plus any amount of whitespace
    .. '"(.*)"' -- Any character/s between quotes
    .. "%s*,%s*" -- Any amount of whitespace plus "," plus any amount of whitespace
    .. '"(.*)"' -- Any character/s between quotes
    .. "%s*,%s*" -- Any amount of whitespace plus "," plus any amount of whitespace
    .. '"(.*)"' -- Any character/s between quotes
    .. "$" -- End of line

local CRACK_PROPERTY_LINE = "^"
    .. "([^%=]*)" -- Match every character but equals
    .. "%s*,%s*"
    .. "(.*)" -- Match any character
    .. "$" -- End of line

local vb_project_guid = "{F184B08F-C81C-45F6-A57F-5ABD9991F28F}"
local cs_project_guid = "{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}"
local cps_project_guid = "{13B669BE-BB05-4DDF-9536-439F39A36129}"
local cps_cs_project_guid = "{9A19103F-16F7-4668-BE54-9A1E7A4F7556}"
local cps_vb_project_guid = "{778DAE3C-4631-46EA-AA77-85C1314464D9}"
local cps_fs_project_guid = "{6EC3EE1D-3C4E-46DD-8F32-0CC8E7565705}"
local vj_project_guid = "{E6FDF86B-F3D1-11D4-8576-0002A516ECE8}"
local vc_project_guid = "{8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942}"
local fs_project_guid = "{F2A71F9B-5D33-465A-A702-920D77279786}"
local db_project_guid = "{C8D11400-126E-41CD-887F-60BD40844F9E}"
local wd_project_guid = "{2CFEAB61-6A3B-4EB8-B523-560B4BEEF521}"
local syn_project_guid = "{BBD0F5D1-1CC4-42FD-BA4C-A96779C64378}"
local web_project_guid = "{E24C65DC-7377-472B-9ABA-BC803B73C61A}"
local solution_folder_guid = "{2150E333-8FDC-42A3-9474-1A3956D46DE8}"
local shared_project_guid = "{D954291E-2A0B-460D-934E-DC6B0785DB48}"

--- @enum solution_project_type
local solution_project_type = {
    unknown = 0,
    known_to_be_msbuild_format = 1,
    solution_folder = 2,
    web_project = 3,
    web_deployment_project = 4,
    etp_sub_project = 5,
    shared_project = 6,
}

function M:parse_first_project_line(first_line)
    local project_type_guid, project_name, relative_path, project_guid = first_line:match(CRACK_PROJECT_LINE)
    relative_path = utils.os_path(relative_path)
    self.path = vim.fn.fnamemodify(relative_path, ":p")
    self.name = project_name
    self.root = vim.fn.fnamemodify(self.path, ":p:h")
    self.project_guid = project_guid

    if
        project_type_guid == vb_project_guid
        or project_type_guid == cs_project_guid
        or project_type_guid == cps_project_guid
        or project_type_guid == cps_cs_project_guid
        or project_type_guid == cps_vb_project_guid
        or project_type_guid == cps_fs_project_guid
        or project_type_guid == fs_project_guid
        or project_type_guid == db_project_guid
        or project_type_guid == vj_project_guid
        or project_type_guid == syn_project_guid
    then
        self.project_type = solution_project_type.known_to_be_msbuild_format
    elseif project_type_guid == shared_project_guid then
        self.project_type = solution_project_type.shared_project
    elseif project_type_guid == solution_folder_guid then
        self.project_type = solution_project_type.solution_folder
    elseif project_type_guid == vc_project_guid then
        if utils.ends_with(relative_path, ".vcproj") then
            error("ProjectUpgradeNeededToVcxProj")
        else
            self.project_type = solution_project_type.known_to_be_msbuild_format
        end
    elseif project_type_guid == web_project_guid then
        self.project_type = solution_project_type.web_project
    elseif project_type_guid == wd_project_guid then
        self.project_type = solution_project_type.web_deployment_project
    else
        self.project_type = solution_project_type.unknown
    end
end

function M:parse(slnfile, first_line)
    self.type = "project"
    self.dependencies = {}

    self:parse_first_project_line(first_line)

    local line
    while true do
        line = slnfile:read_line()
        if not line then
            break
        end

        if line == "EndProject" then
            break
        elseif utils.starts_with(line, "ProjectSection(ProjectDependencies)") then
            line = slnfile:read_line()
            while not utils.starts_with(line, "EndProjectSection") do
                local _, reference_guid = line:match(CRACK_PROPERTY_LINE)
                table.insert(self.dependencies, reference_guid)
                line = slnfile:read_line()
            end
        elseif utils.starts_with(line, "ProjectSection(WebsiteProperties)") then
            line = slnfile:read_line()
            while not utils.starts_with(line, "EndProjectSection") do
                local property_name, property_value = line:match(CRACK_PROPERTY_LINE)
                -- Parse asp next compiler property...
                line = slnfile:read_line()
            end
        elseif utils.starts_with(line, "ProjectSection(SolutionItems)") then
            line = slnfile:read_line()
            while not utils.starts_with(line, "EndProjectSection") do
                local _, path = line:match(CRACK_PROPERTY_LINE)
                table.insert(self.files, path)
                line = slnfile:read_line()
            end
        elseif utils.starts_with(line, "Project(") then -- Malformed solution file, just continue going into the next project
            self:parse(slnfile, line)
            break
        end
    end

    self:refresh_xml()

    return self
end

function M:refresh_xml()
    local h = handler:new()
    local parser = xml2lua.parser(h)

    parser:parse(table.concat(utils.file_read_all_text(self.path), "\n"))
    self.xml = h.root
end

--- @return boolean
function M:set_xml() return utils.file_write_all_text(self.path, xml2lua.toXml(self.xml)) end

--- @class ProjectFile
--- @field project_guid string|nil
--- @field project_type solution_project_type
--- @param sln SolutionFile
--- @param first_line string
function M.new_from_sln(sln, first_line)
    -- TODO: Avoid reparsing the entire project entry if the project already exists
    local self = setmetatable({}, M)

    self:parse(sln, first_line)

    if aggregate_projects[self.path] then
        return aggregate_projects[self.path]
    end

    aggregate_projects[self.path] = self

    return self
end

return M
