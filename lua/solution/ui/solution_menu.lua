local alert = require("solution.ui.alert")
local textmenu = require("solution.ui.textmenu")
local utils = require("solution.utils")
local projects = require("solution").projects

--- @param sln SolutionFile
--- @param width integer
--- @return TextmenuHeader
local function make_header(sln, width)
    local lines = utils.center_align({
        " solution-nvim ",
        "Editing solution " .. sln.name,
    }, width)

    return {
        lines = lines,
        highlights = {
            { group = "SolutionNugetHeader", line = 0, col_start = lines[1]:find("%S") - 2, col_end = -1 },
        },
    }
end

--- @param sln SolutionFile
--- @return TextmenuEntry[]
local function make_entries(sln)
    local ret = {}

    if vim.tbl_count(sln.projects) == 0 then
        table.insert(ret, {
            text = { "    No projects present" },
            expand = {},
            data = {},
        })

        return ret
    end

    for _, project in pairs(sln.projects) do
        local expand = {}

        for _, dependency in ipairs(project.dependencies) do
            local line

            if dependency.type == "Nuget" then
                line = string.format("        Package Dependency %s (%s)", dependency.name, dependency.version)
            elseif dependency.type == "Project" then
                line = string.format("        Project Dependency %s (%s)", dependency.name, dependency.rel_path)
            elseif dependency.type == "Local" then
                line = string.format("        Local Dependency %s (%s)", dependency.name, dependency.path)
            end

            table.insert(expand, line)
        end

        table.insert(expand, "")

        table.insert(ret, {
            text = { string.format("    %s (%s)", project.name, project.path) },
            expand = expand,
            data = { project = project },
        })
    end

    return ret
end

-- NOTE: As far as I can tell this is the only way to provide the solution to
-- complete for, because viml anonymous functions aren't a thing. One option
-- would be redefining some viml function within the callback using this... but
-- honestly I think that's worse
_G.SolutionToCompleteFor = nil
function _G.SolutionAddProjectCompletion(_)
    local sln = _G.SolutionToCompleteFor
    if sln then
        return utils.tbl_map_to_arr(
            vim.tbl_filter(function(proj) return not vim.tbl_contains(sln.projects, proj) end, projects),
            function(_, e) return e.name end
        )
    else
        return utils.tbl_map_to_arr(projects, function(_, v) return v.name end)
    end
end

--- @type Keymap[]
local keymaps = {
    {
        mode = "n",
        lhs = "a",
        opts = {
            noremap = true,
            callback = function(tm, sln, _)
                _G.SolutionToCompleteFor = sln

                local handle_input = function(input)
                    if not input or #input == 0 then
                        alert.open({ "No project name provided" })
                        return
                    end

                    local project = utils.resolve_project(input)
                    if not project then
                        alert.open(utils.word_wrap(string.format("Project '%s' could not be found!", input), 40))
                        return
                    end

                    local function cb(success, message, code)
                        local alert_message
                        if not success then
                            alert_message = string.format(
                                "Failed to add project '%s' to solution '%s'%s%s",
                                project.name,
                                sln.name,
                                (message and ", " .. message) or "",
                                (code and ", code: " .. code) or ""
                            )
                        else
                            tm:render()

                            alert_message = string.format(
                                "Successfully added project '%s' to solution '%s'!",
                                project.name,
                                sln.name
                            )
                        end

                        alert.open(utils.word_wrap(alert_message, 40))
                    end

                    sln:add_project(project, vim.schedule_wrap(cb))
                end

                vim.ui.input(
                    { prompt = "Add a project: ", completion = "customlist,v:lua.SolutionAddProjectCompletion" },
                    handle_input
                )
            end,
        },
    },
    {
        mode = "n",
        lhs = "d",
        opts = {
            noremap = true,
            callback = function(tm, sln, entry)
                if not entry.data.project then
                    return
                end

                local function cb(success, message, code)
                    local alert_message
                    if not success then
                        alert_message = string.format(
                            "Failed to remove project '%s' from solution '%s'%s%s",
                            entry.data.project.name,
                            sln.name,
                            (message and ", " .. message) or "",
                            (code and ", code: " .. code) or ""
                        )
                    else
                        tm:render()

                        alert_message = string.format(
                            "Successfully removed project '%s' from solution '%s'!",
                            entry.data.project.name,
                            sln.name
                        )
                    end

                    alert.open(utils.word_wrap(alert_message, 40))
                end

                sln:remove_project(entry.data.project, vim.schedule_wrap(cb))
            end,
        },
    },
}

--- @param sln SolutionFile
return function(sln)
    local tm = textmenu.new(sln, keymaps, "SolutonEditor", "SolutonEditor")
    tm:set_refresh(function() return make_header(sln, tm.win_opts.width), make_entries(sln) end)
    tm:render()
end
