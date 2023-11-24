if vim.g.loaded_solution_nvim then
    return
end

vim.g.loaded_solution_nvim = 1

vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("solution", { clear = true }),
    callback = function()
        local bufname = vim.api.nvim_buf_get_name(0);

        if bufname:find(".cs") or bufname:find(".csproj") or bufname:find(".sln") then
            vim.g.in_solution = 1
            require("solution").init(arg)
            return true -- delete the autocmd. Maybe I could support multiple solutions later but I'd prefer not to deal with that.
        end
    end,
})
