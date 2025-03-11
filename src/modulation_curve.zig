const std = @import("std");
const color = @import("color.zig");

pub const ModulationCurve = struct {
    pub const Value = struct { h_mod: ?f32, s_mod: ?f32, l_mod: ?f32 };

    curve_values: []const Value,

    pub fn init(curve_values: []const Value) ModulationCurve {
        return .{ .curve_values = curve_values };
    }

    pub fn applyCurve(self: *const @This(), allocator: std.mem.Allocator, clr: *const color.ColorHSL) ![]color.ColorHSL {
        var colors: []color.ColorHSL = try allocator.alloc(color.ColorHSL, self.curve_values.len);
        // Apply curve to the input color
        for (self.curve_values, 0..) |*modulation_value, idx| {
            colors[idx] = clr.modulateAbsolute(modulation_value);
        }
        return colors;
    }
};
