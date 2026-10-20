local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. media .. "server/?.lua;" .. package.path
local Schema = require "ApocExtractionMapUtils_EventSchema"
local sample = dofile("tests/fixtures/event-definition-v1.lua")
local checks, originalPrint = 0, print
local function check(value, message) checks = checks + 1; assert(value, message) end
local id, other = "12345678-1234-1234-1234-123456789abc", "22345678-1234-1234-1234-123456789abc"
local function fixture()
    for key in pairs(package.loaded) do
        if key == "ApocExtractionMapUtils" or key == "ApocExtractionMapUtils_EventDefinitions"
            or key:find("ApocExtractionMapUtils_EventRuntime", 1, true) == 1 or key:find("ApocExtractionMapUtils_Objectives",1,true) == 1 then package.loaded[key] = nil end
    end
    ApocExtractionMapUtils = nil
    SandboxVars = { ApocExtractionMapUtils = { debugLog = true } }
    local f = { server = true, due = true, logs = {}, starts = {}, hooks = {} }
    function isServer() return f.server end
    print = function(message) f.logs[#f.logs + 1] = message end
    Events = { OnServerStarted = { Add = function(fn) f.starts[#f.starts + 1] = fn end },
        OnApocBRLobbyEventDue = { Add = function(fn) f.hooks[#f.hooks + 1] = fn end } }
    f.context = { eventId = id, revision = 1, isReplay = false, name = "Operation",
        startsAtMillis = 1000, state = "scheduled", metadataJson = sample }
    ApocBREventControl = {
        getEventContext = function(e, r)
            if e == f.context.eventId and r == f.context.revision then return f.context end
        end,
        isDue = function(e, r) return f.due and e == f.context.eventId and r == f.context.revision end,
        isReleaseAuthorized = function() return true end
    }
    RegionManager = { Server = { registeredZones = { event_docks = {
        bounds = { minX = 10, minY = 20, maxX = 30, maxY = 40 },
        region = { z = 0 }, properties = { pvpEnabled = true, sprinterChance = 20 }
    } }, addHotRegion = function() error("mock must not register real regions") end,
        updateHotRegion = function() error("mock must not edit real regions") end } }
    function getWorld() error("preview must not access terrain") end
    function addZombiesInOutfit() error("preview must not spawn zombies") end
    f.intake = require "ApocExtractionMapUtils_EventDefinitions"
    f.runtime = ApocExtractionMapUtils.EventRuntime
    f.starts[1]()
    function f.deliver() return f.hooks[1](f.context.eventId, f.context.revision, f.context) end
    function f.count(text)
        local n = 0
        for _, line in ipairs(f.logs) do if line:find(text, 1, true) then n = n + 1 end end
        return n
    end
    return f
end

local f = fixture()
check(f.runtime.getSnapshot() == nil, "no preview synthesized from cached desired state")
check(f.deliver(), "real intake dispatches validated data")
local state = f.runtime.getSnapshot()
check(state.status == "prepared" and state.mode == "objectives", "parsing alone cannot activate preview")
check(f.count("Event activating") == 0, "no activation notification before release")
check(state.plans.Gameplay.gameType == "extraction" and state.plans.Gameplay.ruleset == "operation.default", "gameplay receives envelope")
check(state.plans.Gameplay.properties.friendlyFire == false, "gameplay retains false extension properties")
check(#state.plans.Regions == 2 and state.plans.Regions[1].binding.status == "resolved", "existing Regions registry lookup")
check(state.plans.Regions[1].binding.bounds.minX == 10 and state.plans.Regions[1].binding.z == 0, "provider geometry retained")
check(state.plans.Regions[2].binding.status == "inline_preview", "inline geometry staged without registration")
check(state.plans.Regions[1].population.minAlive == 30 and state.plans.Regions[1].pvp == "disabled", "requested policies retained")
check(#state.plans.Bosses == 1 and state.plans.Bosses[1].id == "commander", "bosses selected from entities by type")
check(state.plans.Bosses[1].properties.healthMultiplier == 5, "boss properties routed")
check(#state.plans.Objectives.objectives == 5 and state.plans.Objectives.objectives[3].dependsOn[1] == "clear", "objectives and dependencies routed")
state.plans.Regions[1].binding.bounds.minX = 999
check(RegionManager.Server.registeredZones.event_docks.bounds.minX == 10
    and f.runtime.getSnapshot().plans.Regions[1].binding.bounds.minX == 10, "snapshots and provider data isolated")
local logCount = #f.logs
f.deliver()
check(#f.logs == logCount, "duplicate dispatch does not repeat previews")
f.runtime.confirmRelease(other, 1)
check(f.runtime.getSnapshot().status == "prepared", "unmatched release does not activate")
f.runtime.confirmRelease(id, 1)
check(f.runtime.getSnapshot().status == "in_progress" and f.count("Event activating") == 1, "matching accepted release activates once")
f.runtime.confirmRelease(id, 1); f.deliver()
check(f.count("Event activating") == 1, "duplicate acknowledgements are harmless")
f.context.isReplay = true
f.deliver(); f.deliver()
check(f.count("Event activating") == 1 and f.count("Receipt replay observed") == 1, "replay never starts a fresh round")
f.server = false
check(f.runtime.getSnapshot() == nil and not f.runtime.confirmRelease(id, 1), "client guards")

f = fixture()
f.runtime.confirmRelease(id, 1)
check(f.runtime.getSnapshot() == nil, "release arriving first waits for a definition")
f.deliver()
check(f.runtime.getSnapshot().status == "in_progress" and f.count("Event activating") == 1, "reverse listener order works")

f = fixture()
f.context.isReplay = true
f.deliver(); f.runtime.confirmRelease(id, 1)
check(f.runtime.getSnapshot() == nil and f.count("Would select gameplay") == 0, "restart receipt is not fresh activation")
f.context.metadataJson = nil
check(not f.deliver() and f.runtime.getSnapshot() == nil, "receipt without original metadata cannot create preview")

f = fixture()
RegionManager = nil
f.deliver()
check(f.runtime.getSnapshot().plans.Regions[1].binding.status == "provider_unavailable", "optional provider absence stays explicit")
f = fixture()
RegionManager.Server.registeredZones.event_docks = nil
f.deliver()
check(f.runtime.getSnapshot().plans.Regions[1].binding.status == "missing_region", "unknown provider ID stays explicit")

f = fixture()
f.context.metadataJson = '{"schemaVersion":1,"gameType":"custom","ruleset":"default","durationMinutes":1,"parameters":{}}'
f.deliver()
state = f.runtime.getSnapshot()
check(#state.plans.Regions == 0 and #state.plans.Bosses == 0 and #state.plans.Objectives.objectives == 0, "empty metadata normalizes for all modules")
check(state.plans.Gameplay.gameType == "custom", "mock records unknown gameplay types without claiming implementation")
f.context.revision, f.context.metadataJson = 2, sample
f.deliver()
check(f.runtime.getSnapshot().revision == 2 and #f.runtime.getSnapshot().plans.Objectives.objectives == 5, "new revision replaces previous preview without history")
f.context.revision = 1
f.deliver()
check(f.runtime.getSnapshot().revision == 2, "older definition cannot roll runtime back")

f = fixture()
local gameplay = require "ApocExtractionMapUtils_EventRuntime/Modules/Gameplay"
gameplay.prepare = function() error("simulated provider failure") end
f.runtime.confirmRelease(id, 1); f.deliver(); f.deliver()
check(f.runtime.getSnapshot().status == "failed" and f.count("Event activating") == 0, "provider failure blocks activation")
check(f.count("Module preparation failed") == 1 and f.count("Would select boss") == 0, "failure stops downstream modules without retry spam")

local Log = require "ApocExtractionMapUtils_EventRuntime/Diagnostics"
local text = Log.describe({ text = "line1\nline2", payload = string.rep("x", 50000), ["key\nname"] = true })
check(#text < 1900 and not text:find("\n", 1, true), "diagnostic output bounded and single-line")
f = fixture()
f.context.metadataJson = '{"invalid":true}'
check(not f.deliver() and f.runtime.getSnapshot() == nil, "schema rejection never reaches runtime")

print = originalPrint
print("PASS: " .. checks .. " event runtime routing/order/replay/provider/preview assertions")
