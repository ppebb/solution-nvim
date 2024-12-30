return {
    run = function(cmd, args, on_exit)
        local _cmd = vim.list_extend({ cmd }, args)
        print(vim.fn.system(_cmd))

        if on_exit then
            on_exit()
        end
    end,
}
