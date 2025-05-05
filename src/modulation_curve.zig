const std = @import("std");
const color = @import("color/color.zig");

pub const ModulationCurve = struct {
    curve_values: std.ArrayList(Value),
    color_space: color.ColorSpace, // Stores which color space to modulate

    pub const Value = struct { a_mod: ?f32, b_mod: ?f32, c_mod: ?f32 };

    pub fn init(allocator: std.mem.Allocator, color_space: color.ColorSpace) @This() {
        return .{ .curve_values = std.ArrayList(Value).init(allocator), .color_space = color_space };
    }

    pub fn deinit(self: *@This()) void {
        self.curve_values.deinit();
    }

    pub fn applyCurve(self: *const @This(), allocator: std.mem.Allocator, clr: *const color.Color) ![]color.Color {
        const colors: []color.Color = try allocator.alloc(color.Color, self.curve_values.items.len);
        // Convert input color to the target color space (e.g., RGB/HSL/XYZ/LAB)
        // FIXME: Add when fixing color conversions
        // const converted_color = switch (self.color_space) {
        //     .rgb => clr.toRGB(),
        //     .hsl => clr.toHSL(),
        //     .xyz => clr.toXYZ(),
        //     .lab => clr.toLAB(),
        //     .oklab => clr.toOKLab(),
        // };
        const converted_color = clr;
        // Extract component values as an array (e.g., [r, g, b] for RGB)
        for (self.curve_values.items, 0..) |mod_value, i| {
            var modulated_components: [3]f32 = converted_color.values;
            // Apply modulations to each component based on the curve
            if (mod_value.a_mod) |a| modulated_components[0] = a;
            if (mod_value.b_mod) |b| modulated_components[1] = b;
            if (mod_value.c_mod) |c| modulated_components[2] = c;
            // Reconstruct modulated color in the target space using the union’s tagged value
            colors[i] = color.Color.init(self.color_space, modulated_components);
        }
        return colors;
    }
};
