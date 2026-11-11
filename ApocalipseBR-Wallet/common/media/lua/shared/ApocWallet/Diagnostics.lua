require "ApocWallet/Protocol"
if ApocWallet.Diagnostics then return ApocWallet.Diagnostics end
local Diagnostics = { enabled = true }
ApocWallet.Diagnostics = Diagnostics

function Diagnostics.log(side,event,token,code)
    if not Diagnostics.enabled then return end
    -- Correlate only our timestamp/sequence references, never arbitrary client text.
    local ref = type(token)=="string" and #token<=80 and token:match("^%d+:%d+$") and token or "opaque"
    local safeCode = type(code)=="string" and #code<=80 and code:match("^[A-Z0-9_]+$") and code or "NONE"
    pcall(print,"[ApocWallet][" .. side .. "] " .. event .. " ref=" .. ref .. " code=" .. safeCode)
end

function Diagnostics.stage(entry,event,code)
    local key = event .. ":" .. (code or "")
    if entry.diagnosticStage == key then return end
    entry.diagnosticStage = key
    Diagnostics.log("server",event,entry.token,code)
end

return Diagnostics
