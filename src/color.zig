const std = @import("std");

pub const Color = union(enum) {
    rgb: ColorRGB,
    hsl: ColorHSL,
    xyz: ColorXYZ,

    pub fn values(self: *const @This()) [3]f32 {
        return switch (self.*) {
            .rgb => self.rgb.values(),
            .hsl => self.hsl.values(),
            .xyz => self.xyz.values(),
        };
    }

    pub fn toRGB(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .rgb = self.rgb },
            .hsl => .{ .rgb = self.hsl.toRGB() },
            .xyz => .{ .rgb = self.xyz.toRGB() },
        };
    }

    pub fn toHSL(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .hsl = self.rgb.toHSL() },
            .hsl => .{ .hsl = self.hsl },
            .xyz => self.toRGB().toHSL(),
        };
    }

    pub fn toXYZ(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .xyz = self.rgb.toXYZ() },
            .hsl => self.toRGB().toXYZ(),
            .xyz => .{ .xyz = self.xyz },
        };
    }

    pub fn dst(self: *const @This(), other: *const Color) f32 {
        const other_tag = std.meta.activeTag(other.*);
        const self_tag = std.meta.activeTag(self.*);
        const other_converted: Color = if (self_tag == other_tag) other.* else switch (self.*) {
            .rgb => other.toRGB(),
            .hsl => other.toHSL(),
            .xyz => other.toXYZ(),
        };
        return switch (self.*) {
            .rgb => self.rgb.dst(&other_converted.rgb),
            .hsl => self.hsl.dst(&other_converted.hsl),
            .xyz => self.xyz.dst(&other_converted.xyz),
        };
    }
};

const ColorRGB = packed struct {
    r: f32,
    g: f32,
    b: f32,

    fn values(self: *const @This()) [3]f32 {
        return .{ self.r, self.g, self.b };
    }

    fn toHSL(self: *const @This()) ColorHSL {
        const max: f32 = @max(self.r, @max(self.g, self.b));
        const min: f32 = @min(self.r, @min(self.g, self.b));
        const delta: f32 = max - min;
        var h: f32 = 0.0;
        if (delta != 0) {
            if (max == self.r) {
                h = (self.g - self.b) / delta;
            } else if (max == self.g) {
                h = 2.0 + (self.b - self.r) / delta;
            } else {
                h = 4.0 + (self.r - self.g) / delta;
            }
            h *= 60.0;
        }
        h = @mod(h, 360.0);
        const l: f32 = (max + min) / 2.0;
        const s: f32 = if (delta == 0) 0.0 else delta / (1.0 - @abs(2.0 * l - 1.0));
        return .{ .h = h, .s = s, .l = l };
    }

    fn toXYZ(self: *const @This()) ColorXYZ {
        const val_r: f32 = if (self.r > 0.04045) std.math.pow(f32, (self.r + 0.055) / 1.055, 2.4) else self.r / 12.92;
        const val_g: f32 = if (self.g > 0.04045) std.math.pow(f32, (self.g + 0.055) / 1.055, 2.4) else self.g / 12.92;
        const val_b: f32 = if (self.b > 0.04045) std.math.pow(f32, (self.b + 0.055) / 1.055, 2.4) else self.b / 12.92;
        return .{
            .x = val_r * 0.4124 + val_g * 0.3576 + val_b * 0.1805,
            .y = val_r * 0.2126 + val_g * 0.7152 + val_b * 0.0722,
            .z = val_r * 0.0193 + val_g * 0.1192 + val_b * 0.9505,
        };
    }

    fn dst(self: *const @This(), other: *const ColorRGB) f32 {
        const dr: f32 = self.r - other.r;
        const dg: f32 = self.g - other.g;
        const db: f32 = self.b - other.b;
        return 0.2126 * dr * dr + 0.7152 * dg * dg + 0.0722 * db * db;
    }
};

const ColorHSL = packed struct {
    h: f32,
    s: f32,
    l: f32,

    fn values(self: *const @This()) [3]f32 {
        return .{ self.h, self.s, self.l };
    }

    fn toRGB(self: *const @This()) ColorRGB {
        if (self.s == 0.0) {
            return .{ .r = self.l, .g = self.l, .b = self.l };
        }
        const chroma: f32 = (1.0 - @abs(2.0 * self.l - 1.0)) * self.s;
        const h_prime: f32 = self.h / 60.0;
        const sector: u32 = @mod(@as(u32, @intFromFloat(h_prime)), 6);
        const mod_val: f32 = @mod(h_prime, 2.0);
        const x: f32 = chroma * (1.0 - @abs(mod_val - 1.0));
        const m: f32 = self.l - chroma / 2.0;
        var r: f32 = 0.0;
        var g: f32 = 0.0;
        var b: f32 = 0.0;
        switch (sector) {
            0 => {
                r = chroma;
                g = x;
            },
            1 => {
                r = x;
                g = chroma;
            },
            2 => {
                g = chroma;
                b = x;
            },
            3 => {
                g = x;
                b = chroma;
            },
            4 => {
                r = x;
                b = chroma;
            },
            5 => {
                r = chroma;
                b = x;
            },
            else => unreachable,
        }
        return .{ .r = r + m, .g = g + m, .b = b + m };
    }

    fn dst(self: *const @This(), other: *const ColorHSL) f32 {
        const h1_rad: f32 = std.math.degreesToRadians(self.h);
        const h2_rad: f32 = std.math.degreesToRadians(other.h);
        const x1: f32 = self.s * @cos(h1_rad);
        const y1: f32 = self.s * @sin(h1_rad);
        const x2: f32 = other.s * @cos(h2_rad);
        const y2: f32 = other.s * @sin(h2_rad);
        const dx: f32 = x1 - x2;
        const dy: f32 = y1 - y2;
        const dz: f32 = self.l - other.l;
        return (dx * dx + dy * dy + dz * dz) / 3.0;
    }
};

const ColorXYZ = packed struct {
    x: f32,
    y: f32,
    z: f32,

    fn values(self: *const @This()) [3]f32 {
        return .{ self.x, self.y, self.z };
    }

    fn toRGB(self: *const @This()) ColorRGB {
        const vr: f32 = self.x * 3.2406 + self.y * -1.5372 + self.z * -0.4986;
        const vg: f32 = self.x * -0.9689 + self.y * 1.8758 + self.z * 0.0415;
        const vb: f32 = self.x * 0.0557 + self.y * -0.2040 + self.z * 1.0570;
        return .{
            .r = if (vr > 0.0031308) 1.055 * std.math.pow(f32, vr, 1.0 / 2.4) - 0.055 else 12.92 * vr,
            .g = if (vg > 0.0031308) 1.055 * std.math.pow(f32, vg, 1.0 / 2.4) - 0.055 else 12.92 * vg,
            .b = if (vb > 0.0031308) 1.055 * std.math.pow(f32, vb, 1.0 / 2.4) - 0.055 else 12.92 * vb,
        };
    }

    fn dst(self: *const @This(), other: *const ColorXYZ) f32 {
        const dx: f32 = self.x - other.x;
        const dy: f32 = self.y - other.y;
        const dz: f32 = self.z - other.z;
        return (dx * dx + dy * dy + dz * dz) / 3.0;
    }
};

const expectEqualSlices = std.testing.expectEqualSlices;

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
