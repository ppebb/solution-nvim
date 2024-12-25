local alert = require("solution.ui.alert")
local nuget_ui = require("solution.ui.nuget_browser")
local textmenu = require("solution.ui.textmenu")
local utils = require("solution.utils")
local projects = require("solution").projects

--- @param project ProjectFile
--- @param width integer
--- @return TextmenuHeader
local function make_header(project, width)
    local lines = utils.center_align({
        " solution-nvim ",
        "Editing project " .. project.name,
    }, width)

    return {
        lines = lines,
        highlights = {
            { group = "SolutionNugetHeader", line = 0, col_start = lines[1]:find("%S") - 2, col_end = -1 },
        },
    }
end

--- @param project ProjectFile
--- @return TextmenuEntry[]
local function make_entries(project)
    local ret = {}

    if #project.dependencies == 0 then
        table.insert(ret, {
            text = { "    No dependencies present" },
            expand = {},
            data = {},
        })

        return ret
    end

    for _, dependency in ipairs(project.dependencies) do
        local text
        local expand = {}

        if dependency.type == "Nuget" then
            text = string.format("    Package Dependency %s (%s)", dependency.name, dependency.version)
        elseif dependency.type == "Project" then
            text = string.format("    Project Dependency %s (%s)", dependency.name, dependency.rel_path)
        elseif dependency.type == "Local" then
            text = string.format("    Local Dependency %s (%s)", dependency.name, dependency.path)
        else
            error(string.format("Attempted to create entry for unknown dependency of type '%s'", dependency.type))
        end

        table.insert(ret, { text = { text }, expand = expand, data = { dependency = dependency } })
    end

    return ret
end

--- @param tm Textmenu
--- @param project ProjectFile
local function add_package(tm, project)
    nuget_ui.open(
        project,
        vim.schedule_wrap(function(browser)
            browser:close()
            tm:render()
        end)
    )
end

function _G.ProjectAddProjectRefCompletion(_, cmd_line, cursor_pos)
    return utils.complete_file(cmd_line, 0, cursor_pos, { "%.csproj" })
end

--- @param tm Textmenu
--- @param project ProjectFile
local function add_project(tm, project)
    -- Projects are stored as a table<path, project>, vim.ui.input expects an
    -- integer indexed list
    local items = utils.tbl_map_to_arr(projects, function(_, v) return v end)
    table.insert(items, "Provide a path...")

    local function handle_selection(item)
        if not item then
            return
        end

        local function cb(success, message, code, project_ref)
            local alert_message
            if not success then
                alert_message = string.format(
                    "Failed to add project reference '%s' to project '%s'%s%s",
                    project_ref.name,
                    project.name,
                    (message and ", " .. message) or "",
                    (code and ", code: " .. code) or ""
                )
            else
                tm:render()
                alert_message = string.format(
                    "Successfully added project reference '%s' to project '%s'",
                    project.name,
                    project_ref.name
                )
            end

            alert.open(utils.word_wrap(alert_message, 40))
        end

        if type(item) == "string" then
            vim.ui.input(
                { prompt = "Select a project: ", completion = "customlist,v:lua.ProjectAddProjectRefCompletion" },
                vim.schedule_wrap(function(input)
                    local project_ref = utils.resolve_project(input)

                    if not project_ref then
                        alert.open(utils.word_wrap(string.format("Unable to resolve project '%s'", input), 40))
                        return
                    end

                    project:add_project_reference(
                        project_ref,
                        vim.schedule_wrap(function(s, m, c) cb(s, m, c, project_ref) end)
                    )
                end)
            )
        else
            project:add_project_reference(item, vim.schedule_wrap(function(s, m, c) cb(s, m, c, item) end))
        end
    end

    vim.ui.select(
        items,
        { prompt = "Select a project: ", format_item = function(item) return item.name or item end },
        handle_selection
    )
end

function _G.ProjectAddLocalDepCompletion(_, cmd_line, cursor_pos)
    return utils.complete_file(cmd_line, 0, cursor_pos, { "%.dll$" })
end

--- @param tm Textmenu
--- @param project ProjectFile
local function add_local(tm, project)
    local function cb(input)
        if not input then
            return
        end

        local success, msg = project:add_local_dep(input)
        local alert_message
        if not success then
            alert_message = string.format("Failed to add dependency '%s' to project '%s', %s", input, project.name, msg)
        else
            tm:render()
            alert_message = string.format("Successfully added dependency '%s' to project '%s'", input, project.name)
        end

        alert.open(utils.word_wrap(alert_message, 40))
    end

    vim.ui.input(
        { prompt = "Select a DLL: ", completion = "customlist,v:lua.ProjectAddLocalDepCompletion" },
        vim.schedule_wrap(cb)
    )
end

--- @type Keymap[]
local keymaps = {
    {
        mode = "n",
        lhs = "a",
        opts = {
            noremap = true,
            callback = function(tm, project, _)
                vim.ui.select(
                    { "Package", "Project", "Local" },
                    { prompt = "Select a dependency type: " },
                    function(choice)
                        if choice == "Package" then
                            add_package(tm, project)
                        elseif choice == "Project" then
                            add_project(tm, project)
                        elseif choice == "Local" then
                            add_local(tm, project)
                        end
                    end
                )
            end,
        },
    },
    {
        mode = "n",
        lhs = "d",
        opts = {
            noremap = true,
            callback = function(tm, project, entry)
                if not entry.data.dependency then
                    return
                end

                local cb = function(success, message, code)
                    local alert_message
                    if not success then
                        alert_message = string.format(
                            "Failed to remove dependency '%s' from project '%s'%s%s",
                            entry.data.dependency.name,
                            project.name,
                            (message and ", " .. message) or "",
                            (code and ", code: " .. code) or ""
                        )
                    else
                        tm:render()

                        alert_message = string.format(
                            "Successfully removed dependency '%s' from project '%s'!",
                            entry.data.dependency.name,
                            project.name
                        )
                    end

                    alert.open(utils.word_wrap(alert_message, 40))
                end

                project:remove_dependency(entry.data.dependency, vim.schedule_wrap(cb))
            end,
        },
    },
}

--- @param project ProjectFile
return function(project)
    local tm = textmenu.new(project, keymaps, "ProjectEditor", "ProjectEditor")
    tm:set_refresh(function() return make_header(project, tm.win_opts.width), make_entries(project) end)
    tm:render()
end
