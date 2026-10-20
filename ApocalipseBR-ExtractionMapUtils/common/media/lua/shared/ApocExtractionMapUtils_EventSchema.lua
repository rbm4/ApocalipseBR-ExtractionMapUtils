local JSON = require "ApocExtractionMapUtils_JSON"
local rules = require "ApocExtractionMapUtils_EventSchemaRules"
local Schema = {}

local function fail(path, code) return nil, path .. ": " .. code end

-- This interpreter implements the subset used by the checked-in schema only.
-- Provider-specific properties stay data; consumers validate their own semantics.
local validate
validate = function(value, rule, path)
    if rule["$ref"] then
        local name = rule["$ref"]:match("^#/%$defs/(.+)$")
        return validate(value, assert(rules["$defs"][name]), path)
    end
    local kind = JSON.kind(value)
    if rule.type and kind ~= rule.type then
        if not (rule.type == "integer" and kind == "number" and value == math.floor(value)) then
            return fail(path, "expected_" .. rule.type)
        end
    end
    if rule.const ~= nil and value ~= rule.const then return fail(path, "unsupported_version") end
    if rule.enum then
        local found = false
        for _, choice in ipairs(rule.enum) do if value == choice then found = true end end
        if not found then return fail(path, "invalid_choice") end
    end
    if kind == "number" then
        if rule.minimum and value < rule.minimum or rule.maximum and value > rule.maximum then
            return fail(path, "out_of_range")
        end
    elseif kind == "string" then
        if rule.minLength and #value < rule.minLength or rule.maxLength and #value > rule.maxLength then
            return fail(path, "invalid_length")
        end
        if rule.pattern and not value:match(rule.pattern) then return fail(path, "invalid_identifier") end
    elseif kind == "array" then
        if rule.maxItems and #value > rule.maxItems then return fail(path, "too_many_items") end
        local seen = {}
        for i, item in ipairs(value) do
            if rule.items then
                local ok, err = validate(item, rule.items, path .. "[" .. i .. "]")
                if not ok then return nil, err end
            end
            if rule.uniqueItems then
                if seen[item] then return fail(path, "duplicate_reference") end
                seen[item] = true
            end
        end
    elseif kind == "object" then
        for _, key in ipairs(rule.required or {}) do
            if value[key] == nil then return fail(path .. "." .. key, "required") end
        end
        for key, item in pairs(value) do
            local child = rule.properties and rule.properties[key]
            if child then
                local ok, err = validate(item, child, path .. "." .. key)
                if not ok then return nil, err end
            elseif rule.additionalProperties == false then
                -- Do not include arbitrary unknown keys or values in diagnostics/logs.
                return fail(path, "unknown_field")
            end
        end
    end
    if rule.oneOf then
        local matches = 0
        for _, branch in ipairs(rule.oneOf) do
            if validate(value, branch, path) then matches = matches + 1 end
        end
        if matches ~= 1 then return fail(path, "choose_one_source") end
    end
    return true
end

local function normalize(definition)
    local p = definition.parameters
    p.schemaVersion = p.schemaVersion or 1
    for _, key in ipairs({ "regions", "objectives", "entities" }) do p[key] = p[key] or JSON.array() end
    p.properties = p.properties or {}
    for _, region in ipairs(p.regions) do
        region.pvp, region.tags, region.properties = region.pvp or "inherit", region.tags or JSON.array(), region.properties or {}
        if region.population then region.population.properties = region.population.properties or {} end
    end
    for _, objective in ipairs(p.objectives) do
        if objective.required == nil then objective.required = true end
        for _, key in ipairs({ "regionIds", "entityIds", "dependsOn" }) do
            objective[key] = objective[key] or JSON.array()
        end
        objective.properties = objective.properties or {}
    end
    for _, entity in ipairs(p.entities) do
        entity.tags, entity.properties = entity.tags or JSON.array(), entity.properties or {}
    end
end

local function semantics(definition)
    local p, index = definition.parameters, {}
    for _, key in ipairs({ "regions", "objectives", "entities" }) do
        index[key] = {}
        for i, item in ipairs(p[key]) do
            if index[key][item.id] then return fail("$.parameters." .. key .. "[" .. i .. "]", "duplicate_id") end
            index[key][item.id] = item
        end
    end
    for i, region in ipairs(p.regions) do
        local b, population = region.bounds, region.population
        if b and (b.minX > b.maxX or b.minY > b.maxY or b.minZ > b.maxZ) then
            return fail("$.parameters.regions[" .. i .. "].bounds", "inverted_bounds")
        end
        if population and population.minAlive > population.maxAlive then
            return fail("$.parameters.regions[" .. i .. "].population", "inverted_population")
        end
    end
    for i, entity in ipairs(p.entities) do
        if entity.regionId and not index.regions[entity.regionId] then
            return fail("$.parameters.entities[" .. i .. "].regionId", "unknown_region")
        end
        local region = entity.regionId and index.regions[entity.regionId]
        local b, at = region and region.bounds, entity.position
        if b and at and (at.x < b.minX or at.x > b.maxX or at.y < b.minY or at.y > b.maxY or at.z < b.minZ or at.z > b.maxZ) then
            return fail("$.parameters.entities[" .. i .. "].position", "outside_region")
        end
    end
    for i, objective in ipairs(p.objectives) do
        for key, target in pairs({ regionIds = "regions", entityIds = "entities", dependsOn = "objectives" }) do
            for _, id in ipairs(objective[key]) do
                if not index[target][id] then return fail("$.parameters.objectives[" .. i .. "]." .. key, "unknown_reference") end
            end
        end
    end
    -- Linear graph walk: every bounded objective/dependency edge visited once.
    local visiting, visited = {}, {}
    local function visit(id)
        if visiting[id] then return false end
        if visited[id] then return true end
        visiting[id] = true
        for _, dependency in ipairs(index.objectives[id].dependsOn) do
            if not visit(dependency) then return false end
        end
        visiting[id], visited[id] = nil, true
        return true
    end
    for _, objective in ipairs(p.objectives) do
        if not visit(objective.id) then return fail("$.parameters.objectives", "dependency_cycle") end
    end
    return true
end

function Schema.parse(metadataJson)
    local definition, err = JSON.decode(metadataJson)
    if definition == nil then return nil, err end
    local ok
    ok, err = validate(definition, rules, "$")
    if not ok then return nil, err end
    normalize(definition)
    ok, err = semantics(definition)
    if not ok then return nil, err end
    return definition
end

local function integer(value, maximum)
    return type(value) == "number" and value > 0 and value <= maximum and value == math.floor(value)
end

function Schema.parseContext(eventId, revision, context)
    if type(eventId) ~= "string" or #eventId ~= 36
        or not eventId:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")
        or not integer(revision, 9007199254740991) then return fail("context", "invalid_identity") end
    if type(context) ~= "table" or context.eventId ~= eventId or context.revision ~= revision
        or type(context.isReplay) ~= "boolean" then return fail("context", "identity_mismatch") end
    if context.metadataJson == nil and context.isReplay then return nil, "replay_without_definition" end
    if type(context.name) ~= "string" or #context.name == 0 or #context.name > 640
        or context.name:find("%c") or not integer(context.startsAtMillis, 253402300799999)
        or context.state ~= "scheduled" then return fail("context", "invalid_schedule") end
    local definition, err = Schema.parse(context.metadataJson)
    if not definition then return nil, err end
    return {
        eventId = eventId, revision = revision, isReplay = context.isReplay,
        name = context.name, startsAtMillis = context.startsAtMillis, state = context.state,
        definition = definition
    }
end

Schema.copy = JSON.copy
return Schema
