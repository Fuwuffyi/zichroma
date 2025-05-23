const std = @import("std");
const vecutil = @import("vector.zig");

const color_rgb = @import("color_rgb.zig");
const color_hsl = @import("color_hsl.zig");
const color_xyz = @import("color_xyz.zig");
const color_lab = @import("color_lab.zig");
const color_oklab = @import("color_oklab.zig");

pub const ColorSpace = enum(u3) {
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

    tag: ColorSpace,
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
        return .{ .tag = self.tag, .vtable = self.vtable, .values = self.vtable.negative(&self.values) };
    }

    pub fn brightness(self: *const Self) f32 {
        return self.vtable.brightness(&self.values);
    }

    pub fn dst(self: *const Self, other: *const Self) f32 {
        return self.vtable.dst(&self.values, &other.values);
    }

    pub fn convertTo(self: *const Self, target: ColorSpace) Self {
        if (self.tag == target) return self.*;
        const values: vecutil.Vec3 = switch (self.tag) {
            .rgb => switch (target) {
                .hsl => color_rgb.toHSL(&self.values),
                .xyz => color_rgb.toXYZ(&self.values),
                .oklab => color_rgb.toOKLab(&self.values),
                else => self.convertTo(.xyz).convertTo(target).values,
            },
            .hsl => switch (target) {
                .rgb => color_hsl.toRGB(&self.values),
                else => self.convertTo(.rgb).convertTo(target).values,
            },
            .xyz => switch (target) {
                .rgb => color_xyz.toRGB(&self.values),
                .lab => color_xyz.toLAB(&self.values),
                else => self.convertTo(.rgb).convertTo(target).values,
            },
            .lab => switch (target) {
                .xyz => color_lab.toXYZ(&self.values),
                else => self.convertTo(.xyz).convertTo(target).values,
            },
            .oklab => switch (target) {
                .rgb => color_oklab.toRGB(&self.values),
                else => self.convertTo(.rgb).convertTo(target).values,
            },
        };
        return init(target, values);
    }
};

// FIXME: Fix the test once the color space implementations are done
test "color format conversions" {
    const expectEqualSlices = std.testing.expectEqualSlices;
    // FIXME: Allow some bit of tolerance to tests, as values provided are not f32 precise lmao
    const colors_rgb: [8]Color = .{
        Color.init(.rgb, .{ 1, 0, 0 }),
        Color.init(.rgb, .{ 0, 1, 0 }),
        Color.init(.rgb, .{ 0, 0, 1 }),
        Color.init(.rgb, .{ 1, 1, 0 }),
        Color.init(.rgb, .{ 1, 0, 1 }),
        Color.init(.rgb, .{ 0, 1, 1 }),
        Color.init(.rgb, .{ 0, 0, 0 }),
        Color.init(.rgb, .{ 1, 1, 1 }),
    };
    const colors_hsl: [8]Color = .{
        Color.init(.hsl, .{ 0, 1, 0.5 }),
        Color.init(.hsl, .{ 120, 1, 0.5 }),
        Color.init(.hsl, .{ 240, 1, 0.5 }),
        Color.init(.hsl, .{ 60, 1, 0.5 }),
        Color.init(.hsl, .{ 300, 1, 0.5 }),
        Color.init(.hsl, .{ 180, 1, 0.5 }),
        Color.init(.hsl, .{ 0, 0, 0 }),
        Color.init(.hsl, .{ 0, 0, 1 }),
    };
    const colors_xyz: [8]Color = .{
        Color.init(.xyz, .{ 0.4124, 0.2126, 0.0193 }),
        Color.init(.xyz, .{ 0.3576, 0.7152, 0.1192 }),
        Color.init(.xyz, .{ 0.1805, 0.0722, 0.9505 }),
        Color.init(.xyz, .{ 0.77, 0.9278, 0.1385 }),
        Color.init(.xyz, .{ 0.5929, 0.2848, 0.9698 }),
        Color.init(.xyz, .{ 0.5381, 0.7874, 1.0697 }),
        Color.init(.xyz, .{ 0, 0, 0 }),
        Color.init(.xyz, .{ 0.9505, 1, 1.089 }),
    };
    const colors_lab: [8]Color = .{
        Color.init(.lab, .{ 53.23, 80.11, 67.22 }),
        Color.init(.lab, .{ 87.74, -86.18, 83.18 }),
        Color.init(.lab, .{ 32.3, 79.2, -107.86 }),
        Color.init(.lab, .{ 97.14, -21.56, 94.48 }),
        Color.init(.lab, .{ 60.32, 98.25, -60.84 }),
        Color.init(.lab, .{ 91.12, -48.08, -14.14 }),
        Color.init(.lab, .{ 0, 0, 0 }),
        Color.init(.lab, .{ 100, 0.01, -0.01 }),
    };
    const colors_oklab: [8]Color = .{
        Color.init(.oklab, .{ 0.628, 0.5625, 0.315 }),
        Color.init(.oklab, .{ 0.866, -0.585, 0.4475 }),
        Color.init(.oklab, .{ 0.452, -0.8, -0.78 }),
        Color.init(.oklab, .{ 0.968, -0.1775, 0.4975 }),
        Color.init(.oklab, .{ 0.702, 0.6875, -0.4225 }),
        Color.init(.oklab, .{ 0.968, -0.1775, 0.4975 }),
        Color.init(.oklab, .{ 0, 0, 0 }),
        Color.init(.oklab, .{ 1.0, 0, 0 }),
    };
    var failed: bool = false;
    //// TEST RGB -> OTHER
    // RGB -> HSL
    for (colors_rgb, 0..) |c_rgb, i| {
        const hsl_clr: Color = c_rgb.convertTo(.hsl);
        const a_vals: [3]f32 = hsl_clr.values;
        const b_vals: [3]f32 = colors_hsl[i].values;
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error RGB -> HSL at index: {}\n", .{i});
            failed = true;
        };
    }
    // RGB -> XYZ
    for (colors_rgb, 0..) |c_rgb, i| {
        const xyz_clr: Color = c_rgb.convertTo(.xyz);
        const a_vals: [3]f32 = xyz_clr.values;
        const b_vals: [3]f32 = colors_xyz[i].values;
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error RGB -> XYZ at index: {}\n", .{i});
            failed = true;
        };
    }
    // RGB -> OKLAB
    for (colors_rgb, 0..) |c_rgb, i| {
        const oklab_clr: Color = c_rgb.convertTo(.oklab);
        const a_vals: [3]f32 = oklab_clr.values;
        const b_vals: [3]f32 = colors_oklab[i].values;
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error RGB -> OKLAB at index: {}\n\n", .{i});
            failed = true;
        };
    }
    //// TEST HSL -> OTHER
    // HSL -> RGB
    for (colors_hsl, 0..) |c_hsl, i| {
        const rgb_clr: Color = c_hsl.convertTo(.rgb);
        const a_vals: [3]f32 = rgb_clr.values;
        const b_vals: [3]f32 = colors_rgb[i].values;
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error HSL -> RGB at index: {}\n", .{i});
            failed = true;
        };
    }
    //// TEST XYZ -> OTHER
    // XYZ -> RGB
    for (colors_xyz, 0..) |c_xyz, i| {
        const rgb_clr: Color = c_xyz.convertTo(.rgb);
        const a_vals: [3]f32 = rgb_clr.values;
        const b_vals: [3]f32 = colors_rgb[i].values;
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error XYZ -> RGB at index: {}\n", .{i});
            failed = true;
        };
    }
    // XYZ -> LAB
    for (colors_xyz, 0..) |c_xyz, i| {
        const lab_clr: Color = c_xyz.convertTo(.lab);
        const a_vals: [3]f32 = lab_clr.values;
        const b_vals: [3]f32 = colors_lab[i].values;
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error XYZ -> LAB at index: {}\n", .{i});
            failed = true;
        };
    }
    //// TEST LAB -> OTHER
    // LAB -> XYZ
    for (colors_lab, 0..) |c_lab, i| {
        const xyz_clr: Color = c_lab.convertTo(.xyz);
        const a_vals: [3]f32 = xyz_clr.values;
        const b_vals: [3]f32 = colors_xyz[i].values;
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error LAB -> XYZ at index: {}\n", .{i});
            failed = true;
        };
    }
    //// TEST OKLAB -> OTHER
    // OKLAB -> RGB
    for (colors_oklab, 0..) |c_oklab, i| {
        const rgb_clr: Color = c_oklab.convertTo(.rgb);
        const a_vals: [3]f32 = rgb_clr.values;
        const b_vals: [3]f32 = colors_rgb[i].values;
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error OKLAB -> RGB at index: {}\n", .{i});
            failed = true;
        };
    }
    try std.testing.expect(!failed);
}
