-- Standalone ISUI presentation, informed by the Quest RPG tracker investigation.
-- No QuestSystem globals, quest engine, rewards, assets or imports.
local C = require "ApocExtractionMapUtils_Objectives/Contract"
local T = { accent = { .32, .84, .64 }, done = { .46, .86, .46 }, dim = { .60, .66, .65 } }
function T.label(key, fallback)
    if key and key ~= "" then
        local translated = getTextOrNull and getTextOrNull(key) or getText(key)
        if translated and translated ~= key then return translated end
    end
    return fallback or ""
end
function T.clip(text, width)
    local measure = getTextManager()
    if measure:MeasureStringX(UIFont.Small, text) <= width then return text end
    local low, high = 0, #text
    while low < high do
        local mid = math.floor((low + high + 1) / 2)
        if measure:MeasureStringX(UIFont.Small, C.text(text, mid) .. "...") <= width then low = mid else high = mid - 1 end
    end
    return C.text(text, low) .. "..."
end
function T.bar(panel, x, y, width, ratio, color)
    panel:drawRect(x, y, width, 4, .65, .15, .20, .20)
    panel:drawRect(x, y, width * math.max(0, math.min(1, ratio)), 4, .95, color[1], color[2], color[3])
end
function T.checkbox(panel, x, y, complete, color)
    panel:drawRectBorder(x, y, 10, 10, .85, color[1], color[2], color[3])
    if complete then panel:drawRect(x + 2, y + 2, 6, 6, .95, color[1], color[2], color[3]) end
end
return T
