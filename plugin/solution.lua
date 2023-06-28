if vim.g.loaded_solution_nvim then
    return
end

vim.g.loaded_solution_nvim = 1

vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("solution", { clear = true }),
    callback = function()
        local arg = vim.fn.argv(vim.fn.argidx(), -1)
        if string.find(arg, ".csproj") == nil and string.find(arg, ".sln") == nil then
            return true
        end

        -- local has_plenary, _ = pcall(require, "plenary")
        -- assert(has_plenary, "This plugin requires plenary.nvim (https://github.com/nvim-lua/plenary.nvim)")

        vim.g.in_solution = 1
        require("solution").init(arg)
    end,
})
