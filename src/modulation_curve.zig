const std = @import("std");
const color = @import("color.zig");

pub const ModulationCurve = struct {
    pub const Value = struct { a_mod: ?f32, b_mod: ?f32, c_mod: ?f32 };

    curve_values: []const Value,

    pub fn init(curve_values: []const Value) ModulationCurve {
        return .{ .curve_values = curve_values };
    }

    pub fn applyCurve(self: *const @This(), allocator: std.mem.Allocator, clr: *const color.Color) ![]color.Color {
        const colors: []color.Color = try allocator.alloc(color.Color, self.curve_values.len);
        // Apply curve to the input color
        for (self.curve_values, 0..) |*modulation_value, idx| {
            // colors[idx] = clr.modulateAbsolute(modulation_value);
            _ = modulation_value;
            _ = idx;
        }
        _ = clr;
        return colors;
    }
};
