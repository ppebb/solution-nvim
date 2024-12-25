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

--- @class QueryResult
--- @field id string The ID of the matched package
--- @field version string The full SemVer 2.0.0 version string of the package (could contain build metadata)
--- @field description? string
--- @field versions QueryResultVersion[] All of the versions of the package matching the prerelease parameter
--- @field authors? string|string[]
--- @field iconUrl? string
--- @field licenseUrl? string
--- @field owners? string|string[] A string represents a single owner's username
--- @field projectUrl? string
--- @field registration? string The absolute URL to the associated registration index
--- @field summary? string
--- @field tags? string|string[]
--- @field title? string
--- @field totalDownloads? integer This value can be inferred by the sum of downloads in the versions array
--- @field verified? boolean A JSON boolean indicating whether the package is verified
--- @field packageTypes QueryResultPackageType[] The package types defined by the package author (added in SearchQueryService/3.5.0)

--- @class QueryResultVersion
--- @field @id string The absolute URL to the associated registration leaf
--- @field version string The full SemVer 2.0.0 version string of the package (could contain build metadata)
--- @field downloads integer The number of downloads for this specific package version

--- @class QueryResultPackageType
--- @field name string The name of the package type.

--- @retrn number, QueryResult[]
function M.query(query, skip, take)
    local full_response = {}

    curl.easy({
        url = endpoints["SearchQueryService/3.5.0"]
            .. "?q="
            .. (query or "")
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

--- @retrn number, table
function M.complete(query, skip, take)
    local full_response = {}

    curl.easy({
        url = endpoints["SearchAutocompleteService/3.5.0"]
            .. "?q="
            .. (query or "")
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
