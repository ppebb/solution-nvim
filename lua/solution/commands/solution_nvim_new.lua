local main = require("solution")
local utils = require("solution.utils")

local name = "SolutionNvimNew"

local ARG_SPEC_MISSING = "Argument specifier %s was provided, but the following value was missing"

local function pop_arg(list, arg, position)
    local len = #list
    assert(len >= position + 1, string.format(ARG_SPEC_MISSING, arg))

    local ret = list[position + 1]
    table.remove(list, position)
    table.remove(list, position)

    return ret
end

return {
    name = name,
    func = function(opts)
        local output

        for i = #opts.fargs, 1, -1 do
            local arg = opts.fargs[i]

            -- Output arg should be passed explicitly to the function, so it's
            -- removed from the array and readded later
            if arg == "-o" or arg == "--output" then
                output = pop_arg(opts.fargs, arg, i)
            end
        end

        main.new_from_template(output or vim.fn.getcwd(), opts.fargs, function(success, message, _, _, _)
            if success then
                print(string.format("Successfully created template %s", opts.fargs[1]))
            else
                print(string.format("Failed to create template %s, %s", opts.fargs[1], message))
            end
        end)
    end,
    opts = {
        nargs = "+",
        complete = function(_, cmd_line, cursor_pos)
            local ret = {}

            utils.spawn_proc(
                "dotnet",
                { "complete", "new " .. cmd_line:sub(#name + 2, cursor_pos) },
                nil,
                nil,
                function(code, _, stdout_agg, _)
                    if code == 0 then
                        ret = utils.split_by_pattern(stdout_agg, "\n")
                    end

                    vim.uv.stop()
                end
            )

            -- This hangs until stop is vim.uv.stop is called.
            vim.uv.run("default")

            for i = #ret, 1, -1 do
                local res = ret[i]

                -- Completion options which make no sense given the context of
                -- calling dotnet new.
                if
                    res == "-?"
                    or res == "/?"
                    or res == "-h"
                    or res == "/h"
                    or res == "--diagnostics"
                    or res == "--help"
                    or res == "--verbosity"
                    or res == "create"
                    or res == "details"
                    or res == "install"
                    or res == "list"
                    or res == "search"
                    or res == "uninstall"
                    or res == "update"
                then
                    table.remove(ret, i)
                end
            end

            if #ret == 0 or vim.deep_equal(ret, { "" }) then
                local old_pos = 1
                local pos = cmd_line:find("[^\\]%s")

                while pos do
                    old_pos = pos + 2
                    pos = cmd_line:find("[^\\]%s", pos + 2)
                end

                ret = utils.complete_file(cmd_line, old_pos, cursor_pos)
            end

            return ret
        end,
    },
}
