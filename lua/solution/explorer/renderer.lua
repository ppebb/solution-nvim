local M = {}
M.__index = M

--- @class Renderer
--- @field depth integer
--- @field highlights table
--- @field lines string[]
--- @field hl_index integer
--- @field icon_padding string
--- @field indent_width integer
--- @field indent_markers table
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
    self.indent_markers = config.explorer.icons.indent_markers

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
    local icon, icon_hl = require("solution.explorer.node").get_file_icon(project.path)
    local indent_padding = string.rep(" ", self.depth * self.indent_width)
    self:insert_line(indent_padding .. icon .. self.icon_padding .. project.name)
    local hl_offset = #indent_padding + #icon
    self:insert_highlight(icon_hl, #indent_padding, hl_offset)
    local name_hl = project.type == "solution" and "SolutionName" or "ProjectName"
    self:insert_highlight("SolutionExplorer" .. name_hl, hl_offset + #self.icon_padding, -1)
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
        self:recurse_node(project.node)
    end
    return self
end

--- @param _node Node
function M:recurse_node(_node)
    self.depth = self.depth + 1

    if _node.open then
        local children = _node:get_children()
        for i = 1, #children do
            local child = children[i]
            if child:should_render() then
                self:build_line(child, i == #children)

                if child.has_children then
                    self:recurse_node(child)
                end
            end
        end
    end

    self.depth = self.depth - 1
end

function M:make_indent_padding(last)
    local not_marker_padding = string.rep(" ", self.indent_width - 1)
    return string.rep(self.indent_markers.edge .. not_marker_padding, self.depth - 1)
        .. (last and self.indent_markers.corner or self.indent_markers.item)
        .. not_marker_padding
end

--- @param _node Node
--- @param last boolean
function M:build_line(_node, last)
    local icon, icon_hl = _node:get_icon()
    local text, text_hl = _node:get_text()
    local indent_padding
    if not self.indent_markers.enabled then
        indent_padding = string.rep(" ", self.depth * self.indent_width)
    else
        indent_padding = self:make_indent_padding(last)
    end

    self:insert_line(indent_padding .. icon .. self.icon_padding .. text)
    local hl_offset = #indent_padding + #icon
    self:insert_highlight("SolutionExplorerIndentPadding", 0, #indent_padding)
    self:insert_highlight(icon_hl, #indent_padding, hl_offset)
    self:insert_highlight(text_hl, hl_offset + #self.icon_padding, -1)
    self.hl_index = self.hl_index + 1
end

function M:unwrap() return self.lines, self.highlights end

return M
