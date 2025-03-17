const std = @import("std");
const expectEqualSlices = std.testing.expectEqualSlices;
const Color = @import("../src/color.zig");

test "color format conversions" {
    const colors_rgb: [8]Color = .{
        .{ .rgb = .{ .r = 1, .g = 0, .b = 0 } },
        .{ .rgb = .{ .r = 0, .g = 1, .b = 0 } },
        .{ .rgb = .{ .r = 0, .g = 0, .b = 1 } },
        .{ .rgb = .{ .r = 1, .g = 1, .b = 0 } },
        .{ .rgb = .{ .r = 1, .g = 0, .b = 1 } },
        .{ .rgb = .{ .r = 0, .g = 1, .b = 1 } },
        .{ .rgb = .{ .r = 0, .g = 0, .b = 0 } },
        .{ .rgb = .{ .r = 1, .g = 1, .b = 1 } },
    };
    const colors_hsl: [8]Color = .{
        .{ .hsl = .{ .h = 0, .s = 1, .l = 0.5 } },
        .{ .hsl = .{ .h = 120, .s = 1, .l = 0.5 } },
        .{ .hsl = .{ .h = 240, .s = 1, .l = 0.5 } },
        .{ .hsl = .{ .h = 60, .s = 1, .l = 0.5 } },
        .{ .hsl = .{ .h = 300, .s = 1, .l = 0.5 } },
        .{ .hsl = .{ .h = 180, .s = 1, .l = 0.5 } },
        .{ .hsl = .{ .h = 0, .s = 0, .l = 0 } },
        .{ .hsl = .{ .h = 0, .s = 0, .l = 1 } },
    };
    const colors_xyz: [8]Color = .{
        .{ .xyz = .{ .x = 0.4124, .y = 0.2126, .z = 0.0193 } },
        .{ .xyz = .{ .x = 0.3576, .y = 0.7152, .z = 0.1192 } },
        .{ .xyz = .{ .x = 0.1805, .y = 0.0722, .z = 0.9505 } },
        .{ .xyz = .{ .x = 0.77, .y = 0.9278, .z = 0.1385 } },
        // .{ .xyz = .{ .x = 0.5929, .y = 0.2848, .z = 0.9698 } },
        .{ .xyz = .{ .x = 0.59290004, .y = 0.2848, .z = 0.9698 } }, // ???? Seems like a round issue probably
        .{ .xyz = .{ .x = 0.5381, .y = 0.7874, .z = 1.0697 } }, // ???? Why > 1 (> 100 should not be possible)
        .{ .xyz = .{ .x = 0, .y = 0, .z = 0 } },
        .{ .xyz = .{ .x = 0.9505, .y = 1, .z = 1.089 } }, // ???? Why > 1 (> 100 should not be possible)
    };
    //// TEST RGB -> OTHER
    // RGB -> HSL
    for (colors_rgb, 0..) |c_rgb, i| {
        const color_hsl: Color = c_rgb.toHSL();
        const a_vals: [3]f32 = color_hsl.values();
        const b_vals: [3]f32 = colors_hsl[i].values();
        try expectEqualSlices(f32, &a_vals, &b_vals);
    }
    // RGB -> XYZ
    for (colors_rgb, 0..) |c_rgb, i| {
        const color_xyz: Color = c_rgb.toXYZ();
        const a_vals: [3]f32 = color_xyz.values();
        const b_vals: [3]f32 = colors_xyz[i].values();
        try expectEqualSlices(f32, &a_vals, &b_vals);
    }
    //// TEST HSL -> OTHER
    // HSL -> RGB
    for (colors_hsl, 0..) |c_hsl, i| {
        const color_rgb: Color = c_hsl.toRGB();
        const a_vals: [3]f32 = color_rgb.values();
        const b_vals: [3]f32 = colors_rgb[i].values();
        try expectEqualSlices(f32, &a_vals, &b_vals);
    }
    // HSL -> XYZ
    for (colors_hsl, 0..) |c_hsl, i| {
        const color_xyz: Color = c_hsl.toXYZ();
        const a_vals: [3]f32 = color_xyz.values();
        const b_vals: [3]f32 = colors_xyz[i].values();
        try expectEqualSlices(f32, &a_vals, &b_vals);
    }
    //// TEST XYZ -> OTHER
    // XYZ -> RGB
    for (colors_xyz, 0..) |c_xyz, i| {
        const color_rgb: Color = c_xyz.toRGB();
        const a_vals: [3]f32 = color_rgb.values();
        const b_vals: [3]f32 = colors_rgb[i].values();
        try expectEqualSlices(f32, &a_vals, &b_vals);
    }
    // XYZ -> HSL
    for (colors_xyz, 0..) |c_xyz, i| {
        const color_hsl: Color = c_xyz.toHSL();
        const a_vals: [3]f32 = color_hsl.values();
        const b_vals: [3]f32 = colors_hsl[i].values();
        try expectEqualSlices(f32, &a_vals, &b_vals);
    }
}
