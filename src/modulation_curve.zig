const std = @import("std");
const color = @import("color.zig");

pub const ModulationCurve = struct {
    curve_values: []const Value,
    color_space: color.ColorSpace, // Stores which color space to modulate

    pub const Value = struct { a_mod: ?f32, b_mod: ?f32, c_mod: ?f32 };

    pub fn init(color_space: color.ColorSpace, curve_values: []const Value) ModulationCurve {
        return .{
            .color_space = color_space,
            .curve_values = curve_values,
        };
    }

    pub fn applyCurve(self: *const @This(), allocator: std.mem.Allocator, clr: *const color.Color) ![]color.Color {
        const colors: []color.Color = try allocator.alloc(color.Color, self.curve_values.len);
        // Convert input color to the target color space (e.g., RGB/HSL/XYZ/LAB)
        const converted_color = switch (self.color_space) {
            .rgb => clr.toRGB(),
            .hsl => clr.toHSL(),
            .xyz => clr.toXYZ(),
            .lab => clr.toLAB(),
        };
        // Extract component values as an array (e.g., [r, g, b] for RGB)
        const components: [3]f32 = converted_color.values();
        for (self.curve_values, 0..) |mod_value, i| {
            var modulated_components: [3]f32 = components;
            // Apply modulations to each component based on the curve
            if (mod_value.a_mod) |a| modulated_components[0] = a;
            if (mod_value.b_mod) |b| modulated_components[1] = b;
            if (mod_value.c_mod) |c| modulated_components[2] = c;
            // Reconstruct modulated color in the target space using the union’s tagged value
            colors[i] = switch (self.color_space) {
                .rgb => color.Color{ .rgb = undefined },
                .hsl => color.Color{ .hsl = undefined },
                .xyz => color.Color{ .xyz = undefined },
                .lab => color.Color{ .lab = undefined },
            };
            colors[i].setValues(modulated_components);
        }
        return colors;
    }
};
