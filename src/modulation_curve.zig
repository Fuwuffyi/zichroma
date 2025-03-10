const std = @import("std");
const color = @import("color.zig");

pub const ModulationValue = struct { h_mod: f32, s_mod: f32, l_mod: f32 };

pub const ModulationCurve = struct {
    curve_values: []const ModulationValue,

    pub fn init(curve_values: []const ModulationValue) ModulationCurve {
        return .{ .curve_values = curve_values };
    }

    pub fn applyCurve(self: *const @This(), allocator: std.mem.Allocator, clr: *const color.ColorHSL) ![]color.ColorHSL {
        var colors: []color.ColorHSL = try allocator.alloc(color.ColorHSL, 2);
        // Apply curve to the input color
        for (self.curve_values, 0..) |*modulation_value, idx| {
            colors[idx] = clr.modulate(modulation_value.h_mod, modulation_value.s_mod, modulation_value.l_mod);
        }
        return colors;
    }
};
