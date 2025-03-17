const std = @import("std");

pub const Color = union(enum) {
    rgb: ColorRGB,
    hsl: ColorHSL,
    xyz: ColorXYZ,
    lab: ColorLAB,

    pub fn values(self: *const @This()) [3]f32 {
        return switch (self.*) {
            .rgb => self.rgb.values(),
            .hsl => self.hsl.values(),
            .xyz => self.xyz.values(),
            .lab => self.lab.values(),
        };
    }

    pub fn toRGB(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .rgb = self.rgb },
            .hsl => .{ .rgb = self.hsl.toRGB() },
            .xyz => .{ .rgb = self.xyz.toRGB() },
            .lab => self.toXYZ().toRGB(),
        };
    }

    pub fn toHSL(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .hsl = self.rgb.toHSL() },
            .hsl => .{ .hsl = self.hsl },
            .xyz => self.toRGB().toHSL(),
            .lab => self.toXYZ().toRGB().toHSL(),
        };
    }

    pub fn toXYZ(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .xyz = self.rgb.toXYZ() },
            .hsl => self.toRGB().toXYZ(),
            .xyz => .{ .xyz = self.xyz },
            .lab => .{ .xyz = self.lab.toXYZ() },
        };
    }

    pub fn toLAB(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => self.toXYZ().toLAB(),
            .hsl => self.toRGB().toXYZ().toLAB(),
            .xyz => .{ .lab = self.xyz.toLAB() },
            .lab => .{ .lab = self.lab },
        };
    }

    pub fn dst(self: *const @This(), other: *const Color) f32 {
        const self_tag = std.meta.activeTag(self.*);
        const other_tag = std.meta.activeTag(other.*);
        const other_converted: Color = if (self_tag == other_tag) other.* else switch (self.*) {
            .rgb => other.toRGB(),
            .hsl => other.toHSL(),
            .xyz => other.toXYZ(),
            .lab => other.toLAB(),
        };
        return switch (self.*) {
            .rgb => self.rgb.dst(&other_converted.rgb),
            .hsl => self.hsl.dst(&other_converted.hsl),
            .xyz => self.xyz.dst(&other_converted.xyz),
            .lab => self.lab.dst(&other_converted.lab),
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

    fn toLinear(self: *const @This()) ColorRGB {
        return .{
            .r = if (self.r > 0.04045) std.math.pow(f32, (self.r + 0.055) / 1.055, 2.4) else self.r / 12.92,
            .g = if (self.g > 0.04045) std.math.pow(f32, (self.g + 0.055) / 1.055, 2.4) else self.g / 12.92,
            .b = if (self.b > 0.04045) std.math.pow(f32, (self.b + 0.055) / 1.055, 2.4) else self.b / 12.92,
        };
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
        const linear: ColorRGB = self.toLinear();
        return .{
            .x = linear.r * 0.4124 + linear.g * 0.3576 + linear.b * 0.1805,
            .y = linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722,
            .z = linear.r * 0.0193 + linear.g * 0.1192 + linear.b * 0.9505,
        };
    }

    fn dst(self: *const @This(), other: *const ColorRGB) f32 {
        const dr: f32 = self.r - other.r;
        const dg: f32 = self.g - other.g;
        const db: f32 = self.b - other.b;
        return (dr * dr + dg * dg + db * db) / 3.0;
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
        const x: f32 = chroma * (1.0 - @abs(@mod(h_prime, 2.0) - 1.0));
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
        return .{
            .r = std.math.clamp(r + m, 0.0, 1.0),
            .g = std.math.clamp(g + m, 0.0, 1.0),
            .b = std.math.clamp(b + m, 0.0, 1.0),
        };
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
            .r = std.math.clamp(if (vr > 0.0031308) 1.055 * std.math.pow(f32, vr, 1.0 / 2.4) - 0.055 else 12.92 * vr, 0, 1),
            .g = std.math.clamp(if (vg > 0.0031308) 1.055 * std.math.pow(f32, vg, 1.0 / 2.4) - 0.055 else 12.92 * vg, 0, 1),
            .b = std.math.clamp(if (vb > 0.0031308) 1.055 * std.math.pow(f32, vb, 1.0 / 2.4) - 0.055 else 12.92 * vb, 0, 1),
        };
    }

    fn toLAB(self: *const @This()) ColorLAB {
        const reference_white: [3]f32 = .{ 0.95047, 1.0, 1.08883 };
        const x: f32 = self.x / reference_white[0];
        const y: f32 = self.y / reference_white[1];
        const z: f32 = self.z / reference_white[2];
        const fx: f32 = if (x > 0.008856) std.math.pow(f32, x, 1.0 / 3.0) else (903.3 * x + 16.0) / 116.0;
        const fy: f32 = if (y > 0.008856) std.math.pow(f32, y, 1.0 / 3.0) else (903.3 * y + 16.0) / 116.0;
        const fz: f32 = if (z > 0.008856) std.math.pow(f32, z, 1.0 / 3.0) else (903.3 * z + 16.0) / 116.0;
        return .{
            .l = 116.0 * fy - 16.0,
            .a = 500.0 * (fx - fy),
            .b = 200.0 * (fy - fz),
        };
    }

    fn dst(self: *const @This(), other: *const ColorXYZ) f32 {
        const dx: f32 = self.x - other.x;
        const dy: f32 = self.y - other.y;
        const dz: f32 = self.z - other.z;
        return (dx * dx + dy * dy + dz * dz) / 3.0;
    }
};

const ColorLAB = packed struct {
    l: f32,
    a: f32,
    b: f32,

    fn values(self: *const @This()) [3]f32 {
        return .{ self.l, self.a, self.b };
    }

    fn toXYZ(self: *const @This()) ColorXYZ {
        const reference_white: [3]f32 = .{ 0.95047, 1.0, 1.08883 };
        const fy: f32 = (self.l + 16.0) / 116.0;
        const fx: f32 = self.a / 500.0 + fy;
        const fz: f32 = fy - self.b / 200.0;
        const xr: f32 = if (fx > 0.206897) fx * fx * fx else (116.0 * fx - 16.0) / 903.3;
        const yr: f32 = if (self.l > 7.9996) fy * fy * fy else self.l / 903.3;
        const zr: f32 = if (fz > 0.206897) fz * fz * fz else (116.0 * fz - 16.0) / 903.3;
        return .{
            .x = xr * reference_white[0],
            .y = yr * reference_white[1],
            .z = zr * reference_white[2],
        };
    }

    fn dst(self: *const @This(), other: *const ColorLAB) f32 {
        // TODO: Implement proper LAB distance color functions
        const dl: f32 = self.l - other.l;
        const da: f32 = self.a - other.a;
        const db: f32 = self.b - other.b;
        return da * da + dl * dl + db * db;
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
        .{ .xyz = .{ .x = 0.5929, .y = 0.2848, .z = 0.9698 } },
        .{ .xyz = .{ .x = 0.5381, .y = 0.7874, .z = 1.0697 } }, // ???? Why > 1 (> 100 should not be possible)
        .{ .xyz = .{ .x = 0, .y = 0, .z = 0 } },
        .{ .xyz = .{ .x = 0.9505, .y = 1, .z = 1.089 } }, // ???? Why > 1 (> 100 should not be possible)
    };
    const colors_lab: [8]Color = .{
        .{ .lab = .{ .l = 53.23, .a = 80.11, .b = 67.22 } },
        .{ .lab = .{ .l = 87.74, .a = -86.18, .b = 83.18 } },
        .{ .lab = .{ .l = 32.3, .a = 79.2, .b = -107.86 } },
        .{ .lab = .{ .l = 97.14, .a = -21.56, .b = 94.48 } },
        .{ .lab = .{ .l = 60.32, .a = 98.25, .b = -60.84 } },
        .{ .lab = .{ .l = 91.12, .a = -48.08, .b = -14.14 } },
        .{ .lab = .{ .l = 0, .a = 0, .b = 0 } },
        .{ .lab = .{ .l = 100, .a = 0.01, .b = -0.01 } },
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
    // RGB -> LAB
    for (colors_rgb, 0..) |c_rgb, i| {
        const color_lab: Color = c_rgb.toLAB();
        const a_vals: [3]f32 = color_lab.values();
        const b_vals: [3]f32 = colors_lab[i].values();
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
    // HSL -> LAB
    for (colors_hsl, 0..) |c_hsl, i| {
        const color_lab: Color = c_hsl.toLAB();
        const a_vals: [3]f32 = color_lab.values();
        const b_vals: [3]f32 = colors_lab[i].values();
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
    // XYZ -> LAB
    for (colors_xyz, 0..) |c_xyz, i| {
        const color_lab: Color = c_xyz.toLAB();
        const a_vals: [3]f32 = color_lab.values();
        const b_vals: [3]f32 = colors_lab[i].values();
        try expectEqualSlices(f32, &a_vals, &b_vals);
    }
    //// TEST LAB -> OTHER
    // LAB -> RGB
    for (colors_lab, 0..) |c_lab, i| {
        const color_rgb: Color = c_lab.toRGB();
        const a_vals: [3]f32 = color_rgb.values();
        const b_vals: [3]f32 = colors_rgb[i].values();
        try expectEqualSlices(f32, &a_vals, &b_vals);
    }
    // LAB -> HSL
    for (colors_lab, 0..) |c_lab, i| {
        const color_hsl: Color = c_lab.toHSL();
        const a_vals: [3]f32 = color_hsl.values();
        const b_vals: [3]f32 = colors_hsl[i].values();
        try expectEqualSlices(f32, &a_vals, &b_vals);
    }
    // LAB -> XYZ
    for (colors_lab, 0..) |c_lab, i| {
        const color_xyz: Color = c_lab.toXYZ();
        const a_vals: [3]f32 = color_xyz.values();
        const b_vals: [3]f32 = colors_xyz[i].values();
        try expectEqualSlices(f32, &a_vals, &b_vals);
    }
}
