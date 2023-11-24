local M = {}

local DEFAULT = {
    icons = true
}

function M.init(path)
    M.sln = require("solution.solutionfile").new(path)
end

function M.setup(config)
    M.config = vim.tbl_deep_extend("force", DEFAULT, config or {})

    if not config.icons then
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
