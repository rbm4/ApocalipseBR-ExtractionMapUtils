local Log = require "ApocExtractionMapUtils_EventRuntime/Diagnostics"
local C = require "ApocExtractionMapUtils_Objectives/Contract"
local JSON = require "ApocExtractionMapUtils_JSON"
local Objectives = { name = "Objectives" }

local function recipients(value)
    if value == nil then return nil end
    assert(JSON.kind(value) == "array" and #value <= 256, "invalid objective recipients")
    local names = {}
    for _, name in ipairs(value) do
        assert(type(name) == "string" and #name > 0 and #name <= 128 and not name:find("%c"), "invalid recipient name")
        names[name] = true
    end
    return names
end

function Objectives.prepare(record)
    local p = record.definition.parameters
    local ui = p.properties.objectivesUI or {}
    assert(JSON.kind(ui) == "object", "invalid objective UI configuration")
    assert(ui.title == nil or type(ui.title) == "string", "invalid objective UI title")
    assert(ui.titleKey == nil or type(ui.titleKey) == "string", "invalid objective UI title key")
    local visible = ui.visibleRows or 6
    assert(C.integer(visible, 1, C.VISIBLE), "invalid objective row limit")
    local plan = { eventId = record.eventId, definitionRevision = record.revision,
        title = C.text(ui.title or record.name, 192), titleKey = C.text(ui.titleKey, 192),
        visibleRows = visible, recipients = recipients(p.properties.participants), objectives = {} }
    local regions = {}
    for _, region in ipairs(p.regions) do
        local bounds = region.bounds
        if not bounds then
            local provider = RegionManager and RegionManager.Server and RegionManager.Server.registeredZones
            local zone = provider and provider[region.regionId]
            if zone then
                bounds = C.copy(zone.bounds)
                bounds.minZ, bounds.maxZ = zone.region.z, zone.region.z
            end
        end
        regions[region.id] = bounds or false
    end
    for _, objective in ipairs(p.objectives) do
        local props = objective.properties
        assert(props.title == nil or type(props.title) == "string", "invalid objective title")
        local target = objective.target or 1
        assert(C.integer(target, 1, 1000000), "invalid objective target")
        if objective.type == "kill_zombies" then assert(objective.target, "kill objective requires a target") end
        local row = { id = objective.id, type = objective.type, scope = objective.scope, target = target,
            required = objective.required, titleKey = C.text(objective.titleKey, 192),
            title = C.text(props.title or objective.id, 192), dependsOn = C.copy(objective.dependsOn),
            recipients = recipients(props.recipients), regions = {}, regionMissing = false,
            properties = JSON.copy(props), regionIds = C.copy(objective.regionIds), entityIds = C.copy(objective.entityIds) }
        for _, regionId in ipairs(objective.regionIds) do
            if not regions[regionId] then row.regionMissing = true
            else row.regions[#row.regions + 1] = C.copy(regions[regionId]) end
        end
        plan.objectives[#plan.objectives + 1] = row
    end
    Log.log(Objectives.name, "Prepared server objective/UI contract", { count = #plan.objectives, eventId = plan.eventId })
    return plan
end

function Objectives.activate(plan)
    local Service = require "ApocExtractionMapUtils_Objectives/Service"
    assert(Service.attach(plan), "objective activation rejected")
end

return Objectives
