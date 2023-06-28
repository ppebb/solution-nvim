local M = {}

local anim = require("solution.animation")
local node = require("solution.explorer.node")
local renderer = require("solution.explorer.renderer")
local window = require("solution.explorer.window")

local DEFAULT = {
    explorer = {
        width = 40,
        lock_cursor = true,
        side = "right",
        add_trailing = true,
        indent_width = 2,
        icon_padding = " ",
        icons = {
            devicon_colors = true,
            symlink_arrow = " ➛ ",
            glyphs = {
                default = "",
                symlink = "",
                folder = {
                    default = "",
                    open = "",
                    empty = "",
                    empty_open = "",
                    symlink = "",
                    symlink_open = "",
                },
            },
        },
    },
}

function M.init(path)
    anim.start(path)

    if M.config.explorer.icons then
        local has_devicons, _ = pcall(require, "nvim-web-devicons")
        assert(
            has_devicons,
            "Enabling icons requires nvim-web-devicons (https://github.com/nvim-tree/nvim-web-devicons)"
        )
    end

    M.sln = require("solution.solutionfile").new(path)

    node.init()
    window.init()
    -- renderer.init()
    anim.stop() -- anim.stop()
end

function M.setup(config)
    M.config = vim.tbl_deep_extend("force", DEFAULT, config or {})

    local has_devicons, devicons = pcall(require, "nvim-web-devicons")
    if has_devicons then
        devicons.setup({
            override_by_extension = {
                ["csproj"] = {
                    icon = "",
                    color = "#596706",
                    cterm_color = "58",
                    name = "Csproj",
                },
            },
        })
    end
end

return M
