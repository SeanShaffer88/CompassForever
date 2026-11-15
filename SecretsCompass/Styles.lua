local _, namespace = ...
local secretColor = {0.82, 0.47, 1}
local framedRail = {0.31, 0.78, 0.98}
local framedSteel = {0.41, 0.54, 0.66}

-- Baselines, gaps, and decorations use the same 560-unit canvas in the HUD and preview.
local styles = {
    {
        id = "arc", name = "Arc", width = 2, arc = {1, 0.97, 0.89},
        y = function(f) return -62 * f * f end,
    },
    {
        id = "bar", name = "Framed", width = 1.5, arc = {0.86, 0.95, 1},
        labelInset = 2, tickBelow = true, trackHalfWidth = 228,
        plate = { width = 492, height = 52, color = {0.05, 0.10, 0.16, 0.95} },
        show = function() return false end,
        details = {
            {-246,  26, 246,  26, 6, 0.30, framedRail}, {-246, -26, 246, -26, 6, 0.30, framedRail},
            {-246,  26, 246,  26, 2, 0.94, framedRail}, {-246, -26, 246, -26, 2, 0.94, framedRail},
            {-246,  26, -262,  32, 5, 1, framedSteel}, {-262,  32, -278,  16, 5, 1, framedSteel},
            {-278,  16, -278, -16, 5, 1, framedSteel}, {-278, -16, -262, -32, 5, 1, framedSteel},
            {-262, -32, -246, -26, 5, 1, framedSteel}, {-262, -13, -262,  13, 3, 1, framedRail},
            {246,  26, 262,  32, 5, 1, framedSteel}, {262,  32, 278,  16, 5, 1, framedSteel},
            {278,  16, 278, -16, 5, 1, framedSteel}, {278, -16, 262, -32, 5, 1, framedSteel},
            {262, -32, 246, -26, 5, 1, framedSteel}, {262, -13, 262,  13, 3, 1, framedRail},
            {-9, -39, 0, -30, 1.75, 1}, {0, -30, 9, -39, 1.75, 1},
        },
    },
    {
        id = "tactical", name = "Tactical", width = 2, arc = {0.66, 1, 0.72},
        y = function(f) return -12 * math.max(0, 1 - math.abs(f) / 0.15) end,
        show = function(a) return a < 0.15 or (a < 0.92 and (math.floor(a * 20) + 1) % 4 ~= 0) end,
        details = { {-9, 10, 0, 4, 2, 0.85}, {0, 4, 9, 10, 2, 0.85}, {-280, -8, -266, -8}, {266, -8, 280, -8} },
    },
    {
        id = "flight", name = "Flight", width = 2, arc = {0.62, 0.92, 1}, tickBelow = true,
        y = function(f) return 9 * math.max(0, 1 - math.abs(f) / 0.05) end,
        show = function(a) return a > 0.05 end,
        details = { {-14, 0, 0, 9, 2, 0.85}, {0, 9, 14, 0, 2, 0.85},
            {-280, -8, -262, -8}, {262, -8, 280, -8} },
    },
    {
        id = "hero", name = "Hero", width = 4, arc = {1, 0.83, 0.48},
        y = function(f) return -28 * math.abs(f) ^ 4 end,
        details = { {-280, -28, -249, -5, 3, 0.80}, {-249, -5, -207, -3, 2, 0.72},
            {207, -3, 249, -5, 2, 0.72}, {249, -5, 280, -28, 3, 0.80},
            {-80, -12, 0, -16}, {0, -16, 80, -12} },
    },
    {
        id = "radical", name = "Radical", width = 3.5, arc = {1, 0.58, 0.73}, labelInset = 15,
        y = function(f) return -31 * math.max(0, 1 - math.abs(f) / 0.45) end,
        details = { {-280, 12, -222, 12, 3, 0.9}, {-222, 12, -194, 0, 3, 0.9},
            {194, 0, 222, 12, 3, 0.9}, {222, 12, 280, 12, 3, 0.9},
            {-50, -30, 0, -48, 1, 0.55}, {0, -48, 50, -30, 1, 0.55} },
    },
    {
        id = "fantasy", name = "Fantasy RPG", width = 1.5, arc = {1, 0.86, 0.58}, labelInset = 14,
        y = function(f) return -33 * f * f end,
        details = { {-280, -33, -264, -16, 2, 0.8}, {-264, -16, -247, -26, 2, 0.8},
            {-247, -26, -264, -43, 2, 0.8}, {-264, -43, -280, -33, 2, 0.8},
            {280, -33, 264, -16, 2, 0.8}, {264, -16, 247, -26, 2, 0.8},
            {247, -26, 264, -43, 2, 0.8}, {264, -43, 280, -33, 2, 0.8},
            {-38, -12, -16, -18}, {-16, -18, 0, -32}, {0, -32, 16, -18}, {16, -18, 38, -12} },
    },
    {
        id = "blocky", name = "Blocky", width = 6, arc = {0.81, 0.94, 1}, tickWidth = 3, labelInset = 16,
        y = function(f)
            local a = math.abs(f)
            return -12 * math.min(1, math.max(0, (a - 0.40) / 0.05))
                - 12 * math.min(1, math.max(0, (a - 0.70) / 0.05))
        end,
        show = function(a) return a < 0.4 or (a > 0.45 and a < 0.7) or a > 0.75 end,
        details = { {-280, -36, -222, -36, 4, 0.8}, {222, -36, 280, -36, 4, 0.8},
            {-51, -11, 51, -11, 3, 0.7} },
    },
    {
        id = "horizon", name = "Horizon", width = 1.5, arc = {0.72, 0.90, 1}, tickBelow = true,
        show = function(a) return a > 0.20 end,
        details = { {-54, 0, -20, 0, 3, 0.8}, {20, 0, 54, 0, 3, 0.8},
            {-20, 0, -10, -8, 2, 0.8}, {10, -8, 20, 0, 2, 0.8},
            {-10, -8, 10, -8, 2, 0.8}, {-280, 8, -228, 8}, {228, 8, 280, 8} },
    },
    {
        id = "ribbon", name = "Ribbon", width = 3, arc = {0.93, 0.82, 1},
        y = function(f) return 12 * math.sin(f * math.pi) end,
        details = { {-280, 0, -244, -20, 2, 0.8}, {-244, -20, -202, -22, 2, 0.8},
            {198, 10, 236, 22, 2, 0.8}, {236, 22, 280, 0, 2, 0.8},
            {-154, -20, -90, -18}, {90, 19, 154, 22} },
    },
    {
        id = "chevron", name = "Chevron", width = 2.5, arc = {1, 0.76, 0.53}, labelInset = 15,
        y = function(f) return -42 * (1 - math.abs(f)) end,
        details = { {-140, -16, 0, -36}, {0, -36, 140, -16},
            {-22, -56, 0, -68, 2, 0.85}, {0, -68, 22, -56, 2, 0.85} },
    },
    {
        id = "minimal", name = "Minimal", width = 1, arc = {0.96, 0.98, 1}, labelInset = 8, minorTicks = false,
        show = function(a) return a < 0.30 or (a > 0.85 and a < 0.95) end,
        details = { {0, -4, 0, 4, 1, 0.85} },
    },
}
local byID = {}
for _, style in ipairs(styles) do
    style.secret = secretColor
    style.details = style.details or {}
    byID[style.id] = style
end

function namespace.PositionCompassStylePlate(texture, parent, style, scale, baseline)
    local plate = style.plate
    if plate then
        texture:SetPoint("CENTER", parent, "CENTER", 0, baseline)
        texture:SetSize(plate.width * scale, plate.height * scale)
        texture:SetColorTexture(unpack(plate.color))
    end
    texture:SetShown(plate ~= nil)
end

namespace.CompassStyles = styles
namespace.CompassStyleY = function(id, fraction)
    local shape = byID[id] and byID[id].y
    return shape and shape(fraction) or 0
end
namespace.CompassStyleSegmentShown = function(id, index, count)
    local visible = byID[id] and byID[id].show
    local middle = math.abs(2 * (index - 0.5) / count - 1)
    return not visible or visible(middle)
end
