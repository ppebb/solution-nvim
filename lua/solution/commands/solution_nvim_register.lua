local utils = require("solution.utils")

return {
    name = "SolutionNvimRegister",
    func = function(opts)
        local fname = assert(opts.fargs[1], "A solution or project file must be provided as argument 1")
        local is_csproj = fname:find("%.csproj")
        local is_sln = fname:find("%.sln")
        assert(is_csproj or is_sln, "A solution or project file must be provided as argument 1")

        assert(utils.file_exists(fname), string.format("The file '%s' does not exist!", fname))

        if is_csproj then
            local project = require("solution.projectfile").new_from_file(fname)
            print(string.format("Successfully registered project '%s' at '%s'", project.name, project.path))
        else
            local sln = require("solution.solutionfile").new(fname)

            if sln then
                print(string.format("Successfully registered solution '%s' at '%s'", sln.name, sln.path))
            end
        end
    end,
    opts = {
        nargs = 1,
        complete = function(_, cmd_line, cursor_pos)
            return utils.complete_file(
                cmd_line,
                #"SolutionRegister" + 2,
                cursor_pos,
                { "%.sln", "%.csproj", "/", "\\", "%.%." }
            )
        end,
    },
}
