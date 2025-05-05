const std = @import("std");
const vecutil = @import("vector.zig");

const color_rgb = @import("color_rgb.zig");
const color_hsl = @import("color_hsl.zig");
const color_xyz = @import("color_xyz.zig");
const color_lab = @import("color_lab.zig");
const color_oklab = @import("color_oklab.zig");

pub const ColorSpace = enum {
    rgb,
    hsl,
    xyz,
    lab,
    oklab,
};

pub const ColorVTable = struct {
    // Color operations
    negative: *const fn (*const vecutil.Vec3) vecutil.Vec3,
    brightness: *const fn (*const vecutil.Vec3) f32,
    dst: *const fn (*const vecutil.Vec3, *const vecutil.Vec3) f32,
};

pub const Color = struct {
    const Self = @This();

    vtable: ColorVTable,
    values: vecutil.Vec3,

    pub fn init(color_space: ColorSpace, values: [3]f32) Color {
        return switch (color_space) {
            .rgb => color_rgb.init(values),
            .hsl => color_hsl.init(values),
            .xyz => color_xyz.init(values),
            .lab => color_lab.init(values),
            .oklab => color_oklab.init(values),
        };
    }

    pub fn negative(self: *const Self) Self {
        return .{ .vtable = self.vtable, .values = self.vtable.negative(&self.values) };
    }

    pub fn brightness(self: *const Self) f32 {
        return self.vtable.brightness(&self.values);
    }

    pub fn dst(self: *const Self, other: *const Self) f32 {
        return self.vtable.dst(&self.values, &other.values);
    }
};

// // FIXME: Fix the test once the color space implementations are done
// test "color format conversions" {
//     const expectEqualSlices = std.testing.expectEqualSlices;
//     // FIXME: Allow some bit of tolerance to tests, as values provided are not f32 precise lmao
//     const colors_rgb: [8]Color = .{
//         .{ .rgb = .{ .values = .{ 1, 0, 0 } } },
//         .{ .rgb = .{ .values = .{ 0, 1, 0 } } },
//         .{ .rgb = .{ .values = .{ 0, 0, 1 } } },
//         .{ .rgb = .{ .values = .{ 1, 1, 0 } } },
//         .{ .rgb = .{ .values = .{ 1, 0, 1 } } },
//         .{ .rgb = .{ .values = .{ 0, 1, 1 } } },
//         .{ .rgb = .{ .values = .{ 0, 0, 0 } } },
//         .{ .rgb = .{ .values = .{ 1, 1, 1 } } },
//     };
//     const colors_hsl: [8]Color = .{
//         .{ .hsl = .{ .values = .{ 0, 1, 0.5 } } },
//         .{ .hsl = .{ .values = .{ 120, 1, 0.5 } } },
//         .{ .hsl = .{ .values = .{ 240, 1, 0.5 } } },
//         .{ .hsl = .{ .values = .{ 60, 1, 0.5 } } },
//         .{ .hsl = .{ .values = .{ 300, 1, 0.5 } } },
//         .{ .hsl = .{ .values = .{ 180, 1, 0.5 } } },
//         .{ .hsl = .{ .values = .{ 0, 0, 0 } } },
//         .{ .hsl = .{ .values = .{ 0, 0, 1 } } },
//     };
//     const colors_xyz: [8]Color = .{
//         .{ .xyz = .{ .values = .{ 0.4124, 0.2126, 0.0193 } } },
//         .{ .xyz = .{ .values = .{ 0.3576, 0.7152, 0.1192 } } },
//         .{ .xyz = .{ .values = .{ 0.1805, 0.0722, 0.9505 } } },
//         .{ .xyz = .{ .values = .{ 0.77, 0.9278, 0.1385 } } },
//         .{ .xyz = .{ .values = .{ 0.5929, 0.2848, 0.9698 } } },
//         .{ .xyz = .{ .values = .{ 0.5381, 0.7874, 1.0697 } } },
//         .{ .xyz = .{ .values = .{ 0, 0, 0 } } },
//         .{ .xyz = .{ .values = .{ 0.9505, 1, 1.089 } } },
//     };
//     const colors_lab: [8]Color = .{
//         .{ .lab = .{ .values = .{ 53.23, 80.11, 67.22 } } },
//         .{ .lab = .{ .values = .{ 87.74, -86.18, 83.18 } } },
//         .{ .lab = .{ .values = .{ 32.3, 79.2, -107.86 } } },
//         .{ .lab = .{ .values = .{ 97.14, -21.56, 94.48 } } },
//         .{ .lab = .{ .values = .{ 60.32, 98.25, -60.84 } } },
//         .{ .lab = .{ .values = .{ 91.12, -48.08, -14.14 } } },
//         .{ .lab = .{ .values = .{ 0, 0, 0 } } },
//         .{ .lab = .{ .values = .{ 100, 0.01, -0.01 } } },
//     };
//     const colors_oklab: [8]Color = .{
//         .{ .oklab = .{ .values = .{ 0.628, 0.5625, 0.315 } } },
//         .{ .oklab = .{ .values = .{ 0.866, -0.585, 0.4475 } } },
//         .{ .oklab = .{ .values = .{ 0.452, -0.8, -0.78 } } },
//         .{ .oklab = .{ .values = .{ 0.968, -0.1775, 0.4975 } } },
//         .{ .oklab = .{ .values = .{ 0.702, 0.6875, -0.4225 } } },
//         .{ .oklab = .{ .values = .{ 0.968, -0.1775, 0.4975 } } },
//         .{ .oklab = .{ .values = .{ 0, 0, 0 } } },
//         .{ .oklab = .{ .values = .{ 1.0, 0, 0 } } },
//     };
//     var failed: bool = false;
//     //// TEST RGB -> OTHER
//     // RGB -> HSL
//     for (colors_rgb, 0..) |c_rgb, i| {
//         const color_hsl: Color = c_rgb.toHSL();
//         const a_vals: [3]f32 = color_hsl.values();
//         const b_vals: [3]f32 = colors_hsl[i].values();
//         expectEqualSlices(f32, &a_vals, &b_vals) catch {
//             std.debug.print("Error RGB -> HSL at index: {}", .{i});
//             failed = true;
//         };
//     }
//     // RGB -> XYZ
//     for (colors_rgb, 0..) |c_rgb, i| {
//         const color_xyz: Color = c_rgb.toXYZ();
//         const a_vals: [3]f32 = color_xyz.values();
//         const b_vals: [3]f32 = colors_xyz[i].values();
//         expectEqualSlices(f32, &a_vals, &b_vals) catch {
//             std.debug.print("Error RGB -> XYZ at index: {}", .{i});
//             failed = true;
//         };
//     }
//     // RGB -> OKLAB
//     for (colors_rgb, 0..) |c_rgb, i| {
//         const color_oklab: Color = c_rgb.toOKLab();
//         const a_vals: [3]f32 = color_oklab.values();
//         const b_vals: [3]f32 = colors_oklab[i].values();
//         expectEqualSlices(f32, &a_vals, &b_vals) catch {
//             std.debug.print("Error RGB -> OKLAB at index: {}\n", .{i});
//             failed = true;
//         };
//     }
//     //// TEST HSL -> OTHER
//     // HSL -> RGB
//     for (colors_hsl, 0..) |c_hsl, i| {
//         const color_rgb: Color = c_hsl.toRGB();
//         const a_vals: [3]f32 = color_rgb.values();
//         const b_vals: [3]f32 = colors_rgb[i].values();
//         expectEqualSlices(f32, &a_vals, &b_vals) catch {
//             std.debug.print("Error HSL -> RGB at index: {}", .{i});
//             failed = true;
//         };
//     }
//     //// TEST XYZ -> OTHER
//     // XYZ -> RGB
//     for (colors_xyz, 0..) |c_xyz, i| {
//         const color_rgb: Color = c_xyz.toRGB();
//         const a_vals: [3]f32 = color_rgb.values();
//         const b_vals: [3]f32 = colors_rgb[i].values();
//         expectEqualSlices(f32, &a_vals, &b_vals) catch {
//             std.debug.print("Error XYZ -> RGB at index: {}", .{i});
//             failed = true;
//         };
//     }
//     // XYZ -> LAB
//     for (colors_xyz, 0..) |c_xyz, i| {
//         const color_lab: Color = c_xyz.toLAB();
//         const a_vals: [3]f32 = color_lab.values();
//         const b_vals: [3]f32 = colors_lab[i].values();
//         expectEqualSlices(f32, &a_vals, &b_vals) catch {
//             std.debug.print("Error XYZ -> LAB at index: {}", .{i});
//             failed = true;
//         };
//     }
//     //// TEST LAB -> OTHER
//     // LAB -> XYZ
//     for (colors_lab, 0..) |c_lab, i| {
//         const color_xyz: Color = c_lab.toXYZ();
//         const a_vals: [3]f32 = color_xyz.values();
//         const b_vals: [3]f32 = colors_xyz[i].values();
//         expectEqualSlices(f32, &a_vals, &b_vals) catch {
//             std.debug.print("Error LAB -> XYZ at index: {}\n", .{i});
//             failed = true;
//         };
//     }
//     //// TEST OKLAB -> OTHER
//     // OKLAB -> RGB
//     for (colors_oklab, 0..) |c_oklab, i| {
//         const color_rgb: Color = c_oklab.toRGB();
//         const a_vals: [3]f32 = color_rgb.values();
//         const b_vals: [3]f32 = colors_rgb[i].values();
//         expectEqualSlices(f32, &a_vals, &b_vals) catch {
//             std.debug.print("Error OKLAB -> RGB at index: {}\n", .{i});
//             failed = true;
//         };
//     }
//     try std.testing.expect(!failed);
// }
