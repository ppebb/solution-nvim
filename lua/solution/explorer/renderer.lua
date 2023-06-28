local M = {}
M.__index = M

local node = require("solution.explorer.node")

--- @class Renderer
--- @field depth integer
--- @field highlights table
--- @field lines string[]
--- @field hl_index integer
--- @field icon_padding string
--- @field indent_width integer
--- @field insert_line function
--- @field insert_highlight function
--- @field build_header function
--- @field build_project function
--- @field build_line function
--- @field unwrap function
function M.new()
    return setmetatable({
        depth = 0,
        highlights = {},
        lines = {},
        hl_index = 0,
    }, M)
end

function M:configure(config)
    self.icon_padding = config.explorer.icon_padding
    self.indent_width = config.explorer.indent_width

    return self
end

--- @param line string
function M:insert_line(line) table.insert(self.lines, line) end

--- @param group string
--- @param start integer
--- @param _end integer|nil
function M:insert_highlight(group, start, _end)
    table.insert(self.highlights, { group = group, line = self.hl_index, start = start, _end = _end or -1 })
end

--- @param self Renderer
--- @param project SolutionFile|ProjectFile
local function make_project_line(self, project)
    local icon, icon_hl = node.get_file_icon(project.path)
    local indent_padding = string.rep(" ", self.depth * self.indent_width)
    self:insert_line(indent_padding .. icon .. self.icon_padding .. project.name)
    local hl_offset = #indent_padding + #icon
    self:insert_highlight(icon_hl, #indent_padding, hl_offset)
    self:insert_highlight("Sometexthl", hl_offset + #self.icon_padding, -1)
    self.hl_index = self.hl_index + 1
end

--- @param sln SolutionFile|ProjectFile
function M:build_header(sln)
    if sln.type == "solution" then
        make_project_line(self, sln)
        return self
    end

    return self
end

function M:build_projects(projects)
    for _, project in ipairs(projects) do
        make_project_line(self, project)
    end
    return self
end

--- @param _node Node
function M:build_line(_node) return self end

function M:unwrap() return self.lines, self.highlights end

return M
