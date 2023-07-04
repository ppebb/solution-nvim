local M = {}

local uv = vim.uv or vim.loop

--- @param node Node
function M.new(node)
    local self = {}

    self.event = uv.new_fs_event()
    if not self.event then
        return
    end

    self.event:start(node.path, {}, function(err)
        if err then
            vim.notify("Watcher " .. node.path .. " errored with " .. err, vim.log.levels.ERROR)
        end

        -- print(node.name .. " event fired")
        -- print(err, filename, vim.inspect(events))
        node:refresh()
    end)

    return setmetatable(self, M)
end

return M
