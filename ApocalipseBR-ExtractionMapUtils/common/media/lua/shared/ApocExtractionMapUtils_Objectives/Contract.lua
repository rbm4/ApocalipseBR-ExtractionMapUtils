local C = { MODULE = "ApocExtractionObjectives", VERSION = 1, MAX = 128, PAGE = 8, VISIBLE = 8 }
C.statuses = { active = true, complete = true, locked = true, unavailable = true, unsupported = true }
function C.integer(n, min, max)
    return type(n) == "number" and n == math.floor(n) and n >= min and n <= max
end
function C.text(s, limit)
    if type(s) ~= "string" then return "" end
    s = s:gsub("[%c]", " ")
    local n = math.min(#s, limit)
    while n > 0 and s:byte(n + 1) and s:byte(n + 1) >= 128 and s:byte(n + 1) < 192 do n = n - 1 end
    return s:sub(1, n)
end
function C.copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = C.copy(v) end
    return out
end
function C.validRow(row)
    return type(row) == "table" and type(row.id) == "string" and #row.id > 0 and #row.id <= 80
        and type(row.title) == "string" and #row.title <= 192 and type(row.titleKey) == "string" and #row.titleKey <= 192
        and type(row.type) == "string" and #row.type <= 80
        and (row.scope == "player" or row.scope == "team" or row.scope == "event")
        and type(row.required) == "boolean" and C.integer(row.target, 1, 1000000)
        and C.integer(row.count, 0, row.target) and C.statuses[row.status] == true
        and (row.status ~= "complete" or row.count == row.target)
end
function C.sameProgress(a, b) return a and b and a.count == b.count and a.status == b.status end
function C.equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    if getmetatable(a) ~= getmetatable(b) then return false end
    for k, v in pairs(a) do if not C.equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
return C
