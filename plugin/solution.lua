if vim.g.loaded_solution_nvim then
    return
end

vim.g.loaded_solution_nvim = 1

vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("solution", { clear = true }),
    pattern = "*.cs,*.csproj,*.sln";
    callback = function()
        vim.g.in_solution = 1
        require("solution").init(vim.api.nvim_buf_get_name(0))
        return true
    end,
})
