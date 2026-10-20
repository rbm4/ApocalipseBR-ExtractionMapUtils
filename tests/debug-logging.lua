local media = "ApocalipseBR-ExtractionMapUtils/common/media/lua/"
package.path = media .. "shared/?.lua;" .. media .. "server/?.lua;" .. package.path
require "ApocExtractionMapUtils"
local Utils = ApocExtractionMapUtils
local originalPrint, lines, checks = print, {}, 0
print = function(line) lines[#lines + 1] = line end
local function check(value, message) checks = checks + 1; assert(value, message) end

SandboxVars = nil
Utils.debugLog("before sandbox load")
check(#lines == 0 and not Utils.debugLogEnabled(), "unavailable sandbox defaults to silent")
SandboxVars = { ApocExtractionMapUtils = {} }
for _, value in ipairs({ false, "true", 1 }) do
    SandboxVars.ApocExtractionMapUtils.debugLog = value
    Utils.debugLog("disabled")
end
check(#lines == 0, "debugLog requires literal true")
SandboxVars.ApocExtractionMapUtils.debugLog = true
Utils.debugLog("[test] line1\nline2\r\t" .. string.rep("x", 3000))
check(#lines == 1 and #lines[1] == 2048 and not lines[1]:find("[%c]"), "enabled logs are bounded single lines")
local Log = require "ApocExtractionMapUtils_EventRuntime/Diagnostics"
Log.log("test", "preview", { enabled = true })
check(#lines == 2 and lines[2]:find("[ApocExtractionEventRuntime]", 1, true), "event previews use shared gate")
SandboxVars.ApocExtractionMapUtils.debugLog = false
Log.describe = function() error("disabled logging must not serialize previews") end
Log.log("test", "preview", {})
Utils.debugLog("disabled again")
check(#lines == 2, "gate reads current sandbox values and skips preview formatting")
print = originalPrint
print("PASS: " .. checks .. " debug logging default, opt-in, bounds and event-preview assertions")
