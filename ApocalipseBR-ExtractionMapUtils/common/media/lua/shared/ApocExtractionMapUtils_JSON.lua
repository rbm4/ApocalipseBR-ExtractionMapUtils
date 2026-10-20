-- Bounded JSON data decoder. Never evaluates Lua or resolves globals.
local JSON = {}
local objectMT, arrayMT, nullMT = {}, {}, {}
JSON.null = setmetatable({}, nullMT)

function JSON.array() return setmetatable({}, arrayMT) end

function JSON.kind(value)
    if type(value) ~= "table" then return type(value) end
    local mt = getmetatable(value)
    if mt == nullMT then return "null" end
    if mt == arrayMT then return "array" end
    return "object"
end

function JSON.copy(value)
    if type(value) ~= "table" then return value end
    if value == JSON.null then return value end
    local result = setmetatable({}, getmetatable(value))
    for k, v in pairs(value) do result[k] = JSON.copy(v) end
    return result
end

local function utf8char(cp)
    if cp < 128 then return string.char(cp) end
    if cp < 2048 then return string.char(192 + math.floor(cp / 64), 128 + cp % 64) end
    if cp < 65536 then
        return string.char(224 + math.floor(cp / 4096), 128 + math.floor(cp / 64) % 64, 128 + cp % 64)
    end
    return string.char(240 + math.floor(cp / 262144), 128 + math.floor(cp / 4096) % 64,
        128 + math.floor(cp / 64) % 64, 128 + cp % 64)
end

local function decode(text)
    assert(type(text) == "string" and #text <= 32768, "JSON must be a string of at most 32768 bytes")
    -- Validate raw UTF-8, including overlong forms, surrogate encodings and truncation.
    local u = 1
    while u <= #text do
        local b = text:byte(u)
        local count, cp, minimum = 0, b, 0
        if b >= 194 and b <= 223 then count, cp, minimum = 1, b - 192, 128
        elseif b >= 224 and b <= 239 then count, cp, minimum = 2, b - 224, 2048
        elseif b >= 240 and b <= 244 then count, cp, minimum = 3, b - 240, 65536
        elseif b >= 128 then error("Invalid UTF-8") end
        for j = 1, count do
            local c = text:byte(u + j)
            assert(c and c >= 128 and c <= 191, "Invalid UTF-8")
            cp = cp * 64 + c - 128
        end
        assert(cp >= minimum and cp <= 1114111 and not (cp >= 55296 and cp <= 57343), "Invalid UTF-8")
        u = u + count + 1
    end
    local pos, nodes = 1, 0
    local function skip()
        while text:sub(pos, pos):match("[ \t\r\n]") do pos = pos + 1 end
    end
    local function take(expected)
        assert(text:sub(pos, pos) == expected, "Invalid JSON delimiter")
        pos = pos + 1
    end
    local function hex()
        local digits = text:sub(pos, pos + 3)
        assert(#digits == 4 and digits:match("^%x%x%x%x$"), "Invalid Unicode escape")
        pos = pos + 4
        return tonumber(digits, 16)
    end
    local escapes = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
    local function str()
        take('"')
        local parts = {}
        while true do
            local c = text:sub(pos, pos)
            assert(c ~= "", "Unterminated JSON string")
            pos = pos + 1
            if c == '"' then return table.concat(parts) end
            if c == '\\' then
                local escape = text:sub(pos, pos)
                pos = pos + 1
                if escape == "u" then
                    local cp = hex()
                    if cp >= 55296 and cp <= 56319 then
                        assert(text:sub(pos, pos + 1) == "\\u", "Missing low surrogate")
                        pos = pos + 2
                        local low = hex()
                        assert(low >= 56320 and low <= 57343, "Invalid low surrogate")
                        cp = 65536 + (cp - 55296) * 1024 + low - 56320
                    else assert(cp < 56320 or cp > 57343, "Unpaired low surrogate") end
                    parts[#parts + 1] = utf8char(cp)
                else
                    assert(escapes[escape], "Invalid JSON escape")
                    parts[#parts + 1] = escapes[escape]
                end
            else
                assert(c:byte() >= 32, "Unescaped JSON control character")
                parts[#parts + 1] = c
            end
        end
    end
    local value
    value = function(depth)
        nodes = nodes + 1
        assert(depth <= 24 and nodes <= 8192, "JSON complexity limit exceeded")
        skip()
        local c = text:sub(pos, pos)
        if c == '"' then return str() end
        if c == "{" or c == "[" then
            local object = c == "{"
            pos = pos + 1
            local result = setmetatable({}, object and objectMT or arrayMT)
            local close = object and "}" or "]"
            skip()
            if text:sub(pos, pos) == close then pos = pos + 1; return result end
            while true do
                skip()
                local key = #result + 1
                if object then
                    key = str()
                    assert(result[key] == nil, "Duplicate JSON member")
                    skip(); take(":")
                end
                result[key] = value(depth + 1)
                skip()
                if text:sub(pos, pos) == close then pos = pos + 1; return result end
                take(",")
            end
        end
        for _, literal in ipairs({ "true", "false", "null" }) do
            if text:sub(pos, pos + #literal - 1) == literal then
                pos = pos + #literal
                if literal == "null" then return JSON.null end
                return literal == "true"
            end
        end
        local start = pos
        if c == "-" then pos = pos + 1 end
        if text:sub(pos, pos) == "0" then pos = pos + 1
        else
            assert(text:sub(pos, pos):match("[1-9]"), "Invalid JSON value")
            repeat pos = pos + 1 until not text:sub(pos, pos):match("%d")
        end
        if text:sub(pos, pos) == "." then
            pos = pos + 1
            assert(text:sub(pos, pos):match("%d"), "Invalid JSON fraction")
            repeat pos = pos + 1 until not text:sub(pos, pos):match("%d")
        end
        if text:sub(pos, pos):match("[eE]") then
            pos = pos + 1
            if text:sub(pos, pos):match("[+-]") then pos = pos + 1 end
            assert(text:sub(pos, pos):match("%d"), "Invalid JSON exponent")
            repeat pos = pos + 1 until not text:sub(pos, pos):match("%d")
        end
        local number = tonumber(text:sub(start, pos - 1))
        assert(number and number == number and math.abs(number) <= 9007199254740991, "JSON number outside safe range")
        return number
    end
    local result = value(1)
    skip()
    assert(pos > #text, "Trailing JSON data")
    return result
end

function JSON.decode(text)
    local ok, result = pcall(decode, text)
    if ok then return result end
    -- Return fixed diagnostics, never echo the potentially private payload.
    return nil, "invalid_json"
end

return JSON
