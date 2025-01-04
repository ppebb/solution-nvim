local utils = require("solution.utils")

-- This has to run synchronously to actually print correctly.
return {
    run = function(cmd, args, on_exit)
        local _code, _signal, _stdout_agg, _stderr_agg
        local output_in_order = {}

        local function append(err, data) table.insert(output_in_order, err or data) end

        local co = coroutine.running()

        utils.spawn_proc(cmd, args, append, append, function(code, signal, stdout_agg, stderr_agg)
            _code, _signal, _stdout_agg, _stderr_agg = code, signal, stdout_agg, stderr_agg

            coroutine.resume(co)
        end)

        coroutine.yield()

        print(table.concat(output_in_order, "\n"))

        if on_exit then
            on_exit(_code, _signal, _stdout_agg, _stderr_agg)
        end
    end,
}
