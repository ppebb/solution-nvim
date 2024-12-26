local utils = require("solution.utils")

local M = {}
--- All solutions
--- @type table<string, SolutionFile>
M.slns = {}
--- All projects. Populated on project creation in solution.projectfile.new...
--- @type table<string, ProjectFile>
M.projects = {}

local DEFAULT = {
    icons = true,
    nuget = {
        take = 10,
    },
    root_markers = {},
}

function M.init(path)
    if not path then
        return
    end

    local found_solutions, found_projects = utils.search_files(path, M.config.root_markers)

    if not found_solutions and not found_projects then
        return
    end

    if found_solutions then
        for _, sln in ipairs(found_solutions) do
            require("solution.solutionfile").new(sln)
        end
    end

    -- Only includes projects that aren't owned by a solution
    if found_projects then
        for _, project in ipairs(found_projects) do
            if not utils.slns_contains_project(M.slns, project) then
                require("solution.projectfile").new_from_file(project)
            end
        end
    end

    require("solution.commands").init()
    require("solution.nuget.api").init()
end

function M.setup(config)
    M.config = vim.tbl_deep_extend("force", DEFAULT, config or {})

    if not M.config.icons then
        return
    end

    local has_devicons, devicons = pcall(require, "nvim-web-devicons")
    if has_devicons then
        devicons.setup({
            override_by_extension = {
                ["dll"] = {
                    icon = "",
                    color = "#6d8086",
                    cterm_color = "66",
                    name = "Dll",
                },
            },
        })
    end
end

return M
