local data_manager = require("solution.data_manager")
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
    output = require("solution.output.qf"),
}

function M.init(path)
    if not path then
        return
    end

    local root = utils.locate_root(path, M.config.root_markers)
    if not root then
        return
    end

    vim.api.nvim_set_current_dir(root)

    local found_solutions, found_projects = utils.search_files(root)

    if not found_solutions and not found_projects then
        print("SolutionNvim was unable to locate any solutions or projects")
        data_manager.load()
        return
    end

    if found_solutions then
        for _, sln in ipairs(found_solutions) do
            require("solution.solutionfile").new(sln)
        end

        -- Set the default projects to match the solution because this is
        -- reasonable... if the user changes them to mismatch that's their
        -- problem though.
        -- Pairs is non-deterministic so we use a sorted list of keys instead.
        -- The project changing every time you use the plugin would be unwanted.

        local first_sln
        local sln_keys = vim.tbl_keys(M.slns)
        table.sort(sln_keys, function(a, b) return a:upper() < b:upper() end)

        for _, key in ipairs(sln_keys) do
            if vim.tbl_count(M.slns[key].projects) ~= 0 then
                first_sln = M.slns[key]
                break
            end
        end

        if first_sln then
            local project_keys = vim.tbl_keys(first_sln.projects)
            table.sort(project_keys, function(a, b) return a:upper() < b:upper() end)

            data_manager.set_default_project(first_sln.projects[project_keys[1]], true)
        end
    end

    -- Only includes projects that aren't owned by a solution
    if found_projects then
        for _, project in ipairs(found_projects) do
            if not M.projects[project] then
                require("solution.projectfile").new_from_file(project)
            end
        end
    end

    data_manager.load()

    if #found_solutions > 1 then
        print(
            string.format(
                "SolutionNvim located multiple solutions, change the default from '%s' using :SolutionSetDefault",
                data_manager.get_defaults().sln.name
            )
        )
    end

    if #found_projects > 1 then
        print(
            string.format(
                "SolutionNvim located multiple projects, change the default from '%s' using :ProjectSetDefault",
                data_manager.get_defaults().project.name
            )
        )
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
