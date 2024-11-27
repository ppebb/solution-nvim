local curl = require("cURL")
local uv = vim.uv or vim.loop

local M = {}

local initialized = false
local endpoints = {}

function M.init()
    if initialized then
        return
    end

    initialized = true

    local function query_endpoints()
        local full_response = {}

        require("cURL")
            .easy({
                url = "https://api.nuget.org/v3/index.json",
                writefunction = function(chunk) table.insert(full_response, chunk) end,
            })
            :perform()
            :close()

        local ret = {}
        local decoded = vim.json.decode(table.concat(full_response))
        for _, resource in pairs(decoded.resources) do
            local type = resource["@type"]
            if not ret[type] then
                ret[type] = resource["@id"]
            end
        end

        return vim.mpack.encode(ret)
    end

    uv.queue_work(uv.new_work(query_endpoints, function(ret) endpoints = vim.mpack.decode(ret) end))
end

--- @retrn number, table
function M.query(query, skip, take)
    local full_response = {}

    curl.easy({
        url = endpoints["SearchQueryService/3.5.0"]
            .. "?q="
            .. ((query and query) or "")
            .. ((skip and "&skip=" .. skip) or "")
            .. ((take and "&take=" .. take) or "")
            .. "&packageType=Dependency",
        writefunction = function(chunk) table.insert(full_response, chunk) end,
    })
        :perform()
        :close()

    local decoded = vim.json.decode(table.concat(full_response))

    if not decoded then
        return 0, nil
    end

    return decoded.totalHits, decoded.data
end

return M
