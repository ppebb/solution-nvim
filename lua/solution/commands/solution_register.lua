local utils = require("solution.utils")

return {
    name = "SolutionRegister",
    func = function(opts)
        local fname = assert(opts.fargs[1], "A solution or project file must be provided as argument 1")
        local csproj = fname:find("%.csproj$")
        local sln = fname:find("%.sln$")
        assert(csproj or sln, "A solution or project file must be provided as argument 1")

        assert(utils.file_exists(fname), string.format("The file '%s' does not exist!", fname))

        if csproj then
            require("solution.projectfile").new_from_file(fname)
        else
            table.insert(require("solution").slns, require("solution.solutionfile").new(fname))
        end
    end,
    opts = {
        nargs = 1,
        complete = "file",
    },
}
