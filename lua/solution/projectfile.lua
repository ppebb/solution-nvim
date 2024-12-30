local alert = require("solution.ui.alert")
local data_manager = require("solution.data_manager")
local handler = require("xml2lua.xmlhandler.tree")
local log = require("solution.log")
local utils = require("solution.utils")
local xml2lua = require("xml2lua.xml2lua")
local projects = require("solution").projects

--- @class ProjectFile
--- @field name string
--- @field root string
--- @field path string
--- @field xml table
--- @field dependencies Dependency[]
--- @field populated boolean
--- @field output_root? string
--- @field output_dll? string
--- @field building boolean
--- @field running boolean
local M = {}
M.__index = M

function M:shared_ctor_ending()
    self.populated = false
    self.output_root = nil
    self.output_dll = nil
    self:refresh_xml()
    self:populate_output()

    projects[self.path] = self
    data_manager.set_default_project(self)
end

--- @param path string
--- @return ProjectFile|nil
function M.new_from_file(path)
    if not path or not path:find("%.csproj$") then
        return nil
    end

    local path_full = vim.fn.fnamemodify(path, ":p")
    if projects[path] then
        return projects[path]
    end

    if not utils.file_exists(path_full) then
        return nil
    end

    --- @type ProjectFile
    local self = setmetatable({}, M)

    self.name = vim.fn.fnamemodify(path_full, ":t")
    self.root = vim.fn.fnamemodify(path_full, ":h")
    self.path = path_full

    self:shared_ctor_ending()

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

--- Returns project file if it already exists and has been parsed, otherwise
--- mutates self
--- @return ProjectFile|nil
function M:parse_first_project_line(first_line)
    local project_type_guid, project_name, relative_path, project_guid = first_line:match(CRACK_PROJECT_LINE)
    relative_path = utils.os_path(relative_path)
    local full_path = vim.fn.fnamemodify(relative_path, ":p")

    if projects[full_path] then
        return projects[full_path]
    end

    self.path = full_path
    self.name = project_name .. ".csproj"
    self.root = vim.fn.fnamemodify(full_path, ":h")
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

    return nil
end

--- @return ProjectFile|nil
function M:parse(slnfile, first_line)
    local project = self:parse_first_project_line(first_line)
    if project then
        return project
    end

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
                -- TODO: Figure out what ProjectDependencies actually are and whether this plugin needs them
                -- table.insert(self.dependencies, reference_guid)
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

    return nil
end

--- @class ProjectFile
--- @field project_guid string|nil
--- @field project_type solution_project_type
--- @param sln SolutionFile
--- @param first_line string
--- @return ProjectFile
function M.new_from_sln(sln, first_line)
    local self = setmetatable({}, M)

    -- This checks if the project already exists
    local project = self:parse(sln, first_line)
    if project then
        return project
    end

    self:shared_ctor_ending()

    return self
end

--- @enum DependencyType
local dependency_type = {
    nuget = "Nuget",
    project = "Project",
    _local = "Local",
}

--- @class Dependency
--- @field type DependencyType
--- @field name string
--- @field pkg string?
--- @field version string?
--- @field project ProjectFile?
--- @field rel_path string?
--- @field path string?
--- @field include string?

--- @private
--- @return Dependency[]
function M:collect_dependencies()
    --- @type Dependency[]
    local ret = {}

    if not self.xml.Project.ItemGroup then
        return ret
    end

    for _, section in ipairs(self.xml.Project.ItemGroup) do
        if section.PackageReference then
            for _, entry in ipairs(section.PackageReference) do
                local include = entry._attr.Include
                table.insert(
                    ret,
                    { type = dependency_type.nuget, name = include, pkg = include, version = entry._attr.Version }
                )
            end
        end

        if section.ProjectReference then
            for _, entry in ipairs(section.ProjectReference) do
                local project = utils.resolve_project(
                    utils.path_absolute_from_relative_to_file(self.path, utils.os_path(entry._attr.Include))
                )

                if project then
                    table.insert(ret, {
                        type = dependency_type.project,
                        name = project.name,
                        rel_path = utils.os_path(entry._attr.Include),
                        project = project,
                    })
                else
                    error(
                        string.format("Unable to resolve dependency '%s' found in '%s'", entry._attr.Include, self.name)
                    )
                end
            end
        end

        if section.Reference then
            for _, entry in ipairs(section.Reference) do
                table.insert(ret, {
                    type = dependency_type._local,
                    name = vim.fn.fnamemodify(entry.HintPath, ":t"),
                    path = entry.HintPath,
                    include = entry._attr.Include,
                })
            end
        end
    end

    return ret
end

--- @param name string
function M:dependency_from_name(name)
    return utils.tbl_first_matching(self.dependencies, function(_, v) return v.name == name end)
end

--- @param noread? boolean
function M:refresh_xml(noread)
    if not noread then
        local h = handler:new()
        h.options = {
            noreduce = {
                ItemGroup = true,
                PackageReference = true,
                ProjectReference = true,
                Reference = true,
            },
        }
        local parser = xml2lua.parser(h)

        local success = xpcall(parser.parse, function(e)
            log.log(
                "error",
                string.format("Error parsing project file '%s': %s\n%s\n", self.path, e, debug.traceback())
            )
            print(string.format("Error parsing project file '%s', see :SolutionLog for more info!", self.path))
        end, parser, utils.remove_bom(table.concat(utils.file_read_all_text(self.path), "\n")))

        if success then
            self.xml = h.root
        else
            return
        end
    end

    self.dependencies = self:collect_dependencies()
end

-- TODO: Preserve formatting of original csproj file
--- @return boolean
function M:set_xml() return utils.file_write_all_text(self.path, xml2lua.toXml(self.xml)) end

--- @param package_name string
--- @param version? string
--- @param cb fun(success: boolean, message: string|nil, code: integer?)
function M:add_nuget_dep(package_name, version, cb)
    local args = { "add", self.path, "package", package_name }

    if version then
        table.insert(args, "--version")
        table.insert(args, version)
    end

    utils.spawn_proc("dotnet", args, nil, nil, function(code, _, stdout_agg, stderr_agg)
        if stdout_agg:find("PackageReference for package '.*' version '.*' added to file") then
            self:refresh_xml()
            cb(true, "added package", nil)
            return
        elseif stdout_agg:find("PackageReference for package '.*' version '.*' updated in file") then
            self:refresh_xml()
            cb(true, "updated package", nil)
            return
        end

        log.log("error", stdout_agg .. stderr_agg)
        cb(false, "failed to add package, see :SolutionLog for more info", code)
    end)
end

--- @param package_name string
--- @param cb fun(success: boolean, message: string|nil, code: integer?)
function M:remove_nuget_dep(package_name, cb)
    -- TODO: check reference exists before invoking dotnet

    utils.spawn_proc(
        "dotnet",
        { "remove", self.path, "package", package_name },
        nil,
        nil,
        function(code, _, stdout_agg, stderr_agg)
            local start, _ = stdout_agg:find("error:")
            if start or code ~= 0 then
                log.log("error", stdout_agg .. stderr_agg)
                cb(false, (stdout_agg:sub(start or 1) .. stderr_agg):gsub("\n", ""), code)
                return
            end

            self:refresh_xml()
            cb(true, nil, nil)
        end
    )
end

--- @param path string
--- @return boolean, string|nil
function M:add_local_dep(path)
    if not utils.file_exists(path) then
        return false, "file does not exist"
    end

    local ref = {
        HintPath = path,
        _attr = {
            Include = vim.fn.fnamemodify(path, ":."),
        },
    }

    if not self.xml.Project.ItemGroup then
        self.xml.Project.ItemGroup = {}
    end

    local k, v = utils.tbl_first_matching(self.xml.Project.ItemGroup, function(_, _v) return _v.Reference ~= nil end)
    if not k or not v then
        table.insert(self.xml.Project.ItemGroup, { Reference = { ref } })
    else
        table.insert(v.Reference, ref)
    end

    self:set_xml()
    self:refresh_xml(true)
    return true, nil
end

--- @param dll_name string
--- @return boolean, string|nil
function M:remove_local_dep(dll_name)
    if not self.xml.Project.ItemGroup then
        return false, "missing ItemGroup"
    end

    local function remove_dep()
        for i, section in ipairs(self.xml.Project.ItemGroup) do
            if section.Reference then
                local idx, _ = utils.tbl_first_matching(
                    section.Reference,
                    function(_, _v) return _v._attr.Include:find(dll_name, 1, true) end
                )

                if idx then
                    table.remove(section.Reference, idx)

                    if vim.tbl_count(self.xml.Project.ItemGroup[i].Reference) == 0 then
                        self.xml.Project.ItemGroup[i].Reference = nil
                    end

                    if vim.tbl_count(self.xml.Project.ItemGroup[i]) == 0 then
                        self.xml.Project.ItemGroup[i] = nil
                    end

                    if vim.tbl_count(self.xml.Project.ItemGroup) == 0 then
                        self.xml.Project.ItemGroup = nil
                    end

                    return true
                end
            end
        end
    end

    if not remove_dep() then
        return false, "no matching reference found"
    end

    self:set_xml()
    self:refresh_xml(true)
    return true, nil
end

--- @param project ProjectFile
--- @param cb fun(success: boolean, message: string|nil, code: integer?)
function M:add_project_reference(project, cb)
    utils.spawn_proc(
        "dotnet",
        { "add", self.path, "reference", project.path },
        nil,
        nil,
        function(code, _, stdout_agg, stderr_agg)
            if not stdout_agg:find("added to the project", 1, true) or code ~= 0 then
                log.log("error", stdout_agg .. stderr_agg)
                cb(false, (stdout_agg .. stderr_agg):gsub("\n", ""), code)
                return
            end

            self:refresh_xml()
            cb(true, nil, nil)
        end
    )
end

--- @param project ProjectFile
--- @param cb fun(success: boolean, message: string|nil, code: integer?)
function M:remove_project_reference(project, cb)
    utils.spawn_proc(
        "dotnet",
        { "remove", self.path, "reference", project.path },
        nil,
        nil,
        function(code, _, stdout_agg, stderr_agg)
            if not stdout_agg:find("removed%.") then
                log.log("error", stdout_agg .. stderr_agg)
                cb(false, (stdout_agg .. stderr_agg):gsub("\n", ""), code)
                return
            end

            self:refresh_xml()
            cb(true, nil, nil)
        end
    )
end

--- @param dep Dependency
--- @param cb fun(success: boolean, message: string|nil, code: integer?)
function M:remove_dependency(dep, cb)
    if dep.type == "Nuget" then
        self:remove_nuget_dep(dep.pkg, cb)
    elseif dep.type == "Project" then
        self:remove_project_reference(dep.project, cb)
    elseif dep.type == "Local" then
        local success, message = self:remove_local_dep(dep.path)
        cb(success, message, nil)
    else
        -- This should never hit, or something has gone very wrong
        cb(
            false,
            string.format("Attempted to remove dependency of unkown type '%s' from self '%s'", dep.type, self.name),
            nil
        )
    end
end

-- This is performed asynchronously upon project creation
function M:populate_output()
    utils.spawn_proc(
        "dotnet",
        { "msbuild", self.path, "-getProperty:OutputPath", "-getProperty:TargetExt", "-getProperty:AssemblyName" },
        nil,
        nil,
        function(code, _, stdout_agg, stderr_agg)
            if code ~= 0 or stdout_agg:find("error") then
                error(
                    string.format(
                        "Unable to determine build output for project '%s', %s",
                        self.name,
                        stdout_agg .. stderr_agg
                    )
                )

                return
            end

            local res = vim.json.decode(stdout_agg)

            self.populated = true
            self.output_root = vim.fn.fnamemodify(res.OutputPath, ":p")
            self.output_dll = string.format("%s%s%s", self.output_root, res.AssemblyName, res.TargetExt)
        end
    )
end

--- @param extra_args? string[]
function M:build(output, extra_args)
    if self.building then
        alert.open({ string.format("Project '%s' is already building.", self.name) })
        return
    end

    self.building = true

    utils.execute_dotnet_in_output(output, { "build", self.path }, extra_args, function() self.building = false end)
end

--- @param extra_args? string[]
function M:run(output, extra_args)
    if self.running then
        alert.open({ string.format("Project '%s' is already running.", self.name) })
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
