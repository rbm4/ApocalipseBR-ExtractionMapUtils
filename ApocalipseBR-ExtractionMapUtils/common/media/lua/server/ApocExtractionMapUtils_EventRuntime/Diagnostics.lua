require "ApocExtractionMapUtils"
-- Bounded, single-line previews. Called on event intake, never from OnTick/render.
local JSON = require "ApocExtractionMapUtils_JSON"
local Diagnostics = {}

function Diagnostics.describe(value)
    local parts, remaining, nodes = {}, 1800, 0
    local function append(text)
        if remaining <= 0 then return end
        local piece = text:sub(1, remaining)
        parts[#parts + 1], remaining = piece, remaining - #piece
    end
    local function visit(item, depth)
        nodes = nodes + 1
        if remaining <= 0 then return end
        if nodes > 128 or depth > 6 then append("<omitted>"); return end
        local kind = JSON.kind(item)
        if kind == "null" then append("null")
        elseif kind == "string" then
            local text = item:sub(1, 240):gsub("[%c]", " "):gsub('"', "'")
            append('"' .. text .. (#item > 240 and "..." or "") .. '"')
        elseif kind ~= "object" and kind ~= "array" then append(tostring(item))
        else
            local keys, limited = {}, false
            for key in pairs(item) do
                if #keys == 24 then limited = true; break end
                keys[#keys + 1] = key
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            append("{")
            for index, key in ipairs(keys) do
                if index > 1 then append(", ") end
                append(tostring(key):sub(1, 120):gsub("[%c]", " "))
                append("="); visit(item[key], depth + 1)
            end
            if limited then append(", <more>") end
            append("}")
        end
    end
    visit(value, 0)
    return table.concat(parts) .. (remaining == 0 and " <truncated>" or "")
end

function Diagnostics.log(moduleName, message, data)
    if not ApocExtractionMapUtils.debugLogEnabled() then return end
    ApocExtractionMapUtils.debugLog("[ApocExtractionEventRuntime][preview][" .. moduleName .. "] " .. message
        .. (data ~= nil and " " .. Diagnostics.describe(data) or ""))
end

return Diagnostics
