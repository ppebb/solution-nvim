local M = {}
M.__index = M

local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local main
local utils = require("solution.utils")
local uv = vim.loop

--- @return string, string
local function get_file_icon_default(_)
    local hl_group = "SolutionExplorerFileIcon"
    local icon = main.config.explorer.icons.glyphs.default
    if #icon > 0 then
        return icon, hl_group
    else
        return "", ""
    end
end

--- @param filename string
--- @return string, string
local function get_file_icon_devicon(filename)
    local ext = vim.fn.fnamemodify(filename, ":e")
    local icon, hl_group = devicons.get_icon(filename, ext)
    if not main.config.explorer.icons.devicon_colors then
        hl_group = "SolutionExplorerFileIcon"
    end

    if icon and hl_group ~= "DevIconDefault" then
        return icon, hl_group
    elseif ext ~= vim.fn.fnamemodify(filename, ":e:e") then
        return get_file_icon_devicon(vim.fn.fnamemodify(filename, ":r"))
    else
        return get_file_icon_default()
    end
end

function M.init()
    main = require("solution")
    if has_devicons then
        M.get_file_icon = get_file_icon_devicon
        devicons.setup({
            override_by_extension = {
                ["csproj"] = {
                    icon = "",
                    color = "#596706",
                    cterm_color = "58",
                    name = "Csproj",
                },
            },
        })
    else
        M.get_file_icon = get_file_icon_default
    end

    M.separator = main.config.explorer.add_trailing and utils.separator or ""
end

local function is_executable(absolute_path)
    if utils.is_wsl or utils.is_windows then -- Executable detection on windows is buggy
        return false
    end

    return uv.fs_access(absolute_path, "X")
end

--- @class Node
--- @field name string
--- @field type string
--- @field path string
--- @field parent Node|nil
--- @field executable boolean|nil
--- @field get_children function
--- @field get_icon function
--- @field get_text function
--- @field should_render function
--- @param absolute_path string
--- @param parent Node|nil
--- @param name string
function M.new_file(absolute_path, parent, name)
    local self = {}
    setmetatable(self, M)

    self.name = name
    self.type = "file"
    self.path = absolute_path
    self.executable = is_executable(absolute_path)
    self.parent = parent

    return self
end

--- @class Node
--- @field has_children boolean|nil
--- @field children Node[]|nil
--- @field open boolean|nil
--- @field watcher nil
function M.new_folder(absolute_path, parent, name)
    local self = {}
    setmetatable(self, M)

    local handle = uv.fs_scandir(absolute_path)

    self.name = name
    self.type = "folder"
    self.path = absolute_path
    self.has_children = handle and uv.fs_scandir_next(handle) ~= nil
    self.children = nil
    self.open = false
    self.parent = parent
    self.watcher = nil

    return self
end

--- @class Node
--- @field real_path string
function M.new_symlink(absolute_path, parent, name)
    local self = {}
    setmetatable(self, M)

    local real_path = uv.fs_realpath(absolute_path)
    local is_dir = (real_path ~= nil) and uv.fs_stat(real_path).type == "directory"

    self.name = name
    self.type = "link"
    self.path = absolute_path
    self.real_path = real_path
    self.parent = parent

    if is_dir then
        local handle = uv.fs_scandir(absolute_path)
        self.has_children = handle and uv.fs_scandir_next(handle) ~= nil
        self.children = nil
        self.open = false
        self.watcher = nil
    end

    return self
end

--- @return string, string
function M:get_icon()
    if self.type == "file" then
        return M.get_file_icon(self.name)
    else
        local n
        if self.type == "link" and self.open then
            n = main.config.explorer.icons.glyphs.folder.symlink
        elseif self.type == "link" then
            n = main.config.explorer.icons.glyphs.folder.symlink_open
        elseif self.open then
            if self.has_children then
                n = main.config.explorer.icons.glyphs.folder.open
            else
                n = main.config.explorer.icons.glyphs.folder.empty_open
            end
        else
            if self.has_children then
                n = main.config.explorer.icons.glyphs.folder.default
            else
                n = main.config.explorer.icons.glyphs.folder.empty
            end
        end

        return n, "SolutionExplorer" .. (self.type == "link" and "LinkIcon" or "FolderIcon")
    end
end

--- @return string, string
function M:get_text()
    if self.type == "file" then
        return self.name, "SolutionExplorerFileName"
    elseif self.type == "folder" then
        return self.name .. M.separator, "SolutionExplorerFolderName"
    else
        return self.name .. main.config.explorer.icons.symlink_arrow .. self.real_path, "SolutionExplorerLinkName"
    end
end

--- @return Node[]|nil
function M:get_children()
    if self.has_children and not self.children then
        self:populate_children()
    end

    return self.children
end

--- @param self Node
function M:populate_children()
    if self.type ~= "folder" and not (self.type == "link" and self.has_children) then
        return
    end

    local dir = self.path
    local handle = uv.fs_scandir(dir)
    if not handle then
        return
    end

    while true do
        local name, type = uv.fs_scandir_next(handle)
        if not name then
            break
        end

        local absolute_path = utils.path_combine(self.path, name)
        type = type or (uv.fs_stat(dir) or {}).type
        local child = nil
        if type == "directory" and uv.fs_access(dir, "R") then
            child = M.new_folder(absolute_path, self, name)
        elseif type == "file" then
            child = M.new_file(absolute_path, self, name)
        elseif type == "link" then
            local link = M.new_symlink(absolute_path, self, name)
            if link.real_path ~= nil then
                child = link
            end
        end

        if child then
            if not self.children then
                self.children = {}
            end
            table.insert(self.children, child)
        end
    end

    table.sort(self.children, function(a, b)
        local function is_folder(node) return node.type == "folder" or (node.type == "link" and node.has_children) end

        if is_folder(a) and not is_folder(b) then
            return true
        elseif is_folder(b) and not is_folder(a) then
            return false
        end

        if a.name:lower() < b.name:lower() then
            return true
        end

        return false
    end)
end

function M:should_render()
    local ext = vim.fn.fnamemodify(self.path, ":e")
    return not (ext == ".csproj" or self.name == "obj" or self.name == "bin")
end

return M
