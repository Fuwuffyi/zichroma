const std = @import("std");
const modulation_curve = @import("modulation_curve.zig");

pub const ColorRGB = packed struct {
    r: f32,
    g: f32,
    b: f32,

    pub fn toHSL(self: *const @This()) ColorHSL {
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
        const l = (max + min) / 2.0;
        const s: f32 = if (delta == 0) 0.0 else delta / (1.0 - @abs(2.0 * l - 1.0));
        return .{ .h = h, .s = s, .l = l };
    }
};

pub const ColorHSL = packed struct {
    h: f32,
    s: f32,
    l: f32,

    // Euclidean distance calculation, converting hue and saturation to cartesian coordinates
    // Efficiency: High
    // Percieved Color: Lower
    pub fn dstSquared(self: *const @This(), other: *const ColorHSL) f32 {
        const dh: f32 = @abs(self.h - other.h) / 360.0;
        const ds: f32 = self.s - other.s;
        const dl: f32 = self.l - other.l;
        return dh * dh + ds * ds + dl * dl;
    }

    pub fn negative(self: *const @This()) ColorHSL {
        return .{ .h = @mod(self.h + 180.0, 360.0), .s = 1.0 - self.s, .l = 1.0 - self.l };
    }

    pub fn modulateRelative(self: *const @This(), mod_value: *const modulation_curve.ModulationCurve.Value) ColorHSL {
        return .{
            .h = @mod(self.h + mod_value.h_mod orelse 0.0, 360.0),
            .s = std.math.clamp(self.s * mod_value.s_mod orelse 1.0, 0.0, 1.0),
            .l = std.math.clamp(self.l * mod_value.l_mod orelse 1.0, 0.0, 1.0),
        };
    }

    pub fn modulateAbsolute(self: *const @This(), mod_value: *const modulation_curve.ModulationCurve.Value) ColorHSL {
        return .{
            .h = @mod(mod_value.h_mod orelse self.h, 360.0),
            .s = std.math.clamp(mod_value.s_mod orelse self.s, 0.0, 1.0),
            .l = std.math.clamp(mod_value.l_mod orelse self.l, 0.0, 1.0),
        };
    }

    pub fn toRGB(self: *const @This()) ColorRGB {
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
        return .{
            .r = r + m,
            .g = g + m,
            .b = b + m,
        };
    }
};

const expect = std.testing.expect;

test "rgb to hsl" {
    const test_rgb_colors: [10]ColorRGB = .{
        .{ .r = 0.0, .g = 0.0, .b = 0.0 },
        .{ .r = 1.0, .g = 1.0, .b = 1.0 },
        .{ .r = 1.0, .g = 0.0, .b = 0.0 },
        .{ .r = 0.0, .g = 1.0, .b = 0.0 },
        .{ .r = 0.0, .g = 0.0, .b = 1.0 },
        .{ .r = 1.0, .g = 1.0, .b = 0.0 },
        .{ .r = 1.0, .g = 0.0, .b = 1.0 },
        .{ .r = 0.0, .g = 1.0, .b = 1.0 },
        .{ .r = 0.2, .g = 0.2, .b = 0.2 },
        .{ .r = 0.6, .g = 0.6, .b = 0.6 },
    };
    const test_expected_hsl: [10]ColorHSL = .{
        .{ .h = 0.0, .s = 0.0, .l = 0.0 },
        .{ .h = 0.0, .s = 0.0, .l = 1.0 },
        .{ .h = 0.0, .s = 1.0, .l = 0.5 },
        .{ .h = 120.0, .s = 1.0, .l = 0.5 },
        .{ .h = 240.0, .s = 1.0, .l = 0.5 },
        .{ .h = 60.0, .s = 1.0, .l = 0.5 },
        .{ .h = 300.0, .s = 1.0, .l = 0.5 },
        .{ .h = 180.0, .s = 1.0, .l = 0.5 },
        .{ .h = 0.0, .s = 0.0, .l = 0.2 },
        .{ .h = 0.0, .s = 0.0, .l = 0.6 },
    };
    try expect(test_rgb_colors.len == test_expected_hsl.len);
    for (test_rgb_colors, 0..) |rgb, i| {
        std.debug.print("Current idx: {}\n", .{i});
        const hsl = rgb.toHSL();
        const expected_hsl = test_expected_hsl[i];
        try expect(hsl.h == expected_hsl.h);
        try expect(hsl.s == expected_hsl.s);
        try expect(hsl.l == expected_hsl.l);
    }
}

test "hsl to rgb" {
    const test_hsl_colors: [10]ColorHSL = .{
        .{ .h = 0.0, .s = 0.0, .l = 0.0 },
        .{ .h = 0.0, .s = 0.0, .l = 1.0 },
        .{ .h = 0.0, .s = 1.0, .l = 0.5 },
        .{ .h = 120.0, .s = 1.0, .l = 0.5 },
        .{ .h = 240.0, .s = 1.0, .l = 0.5 },
        .{ .h = 60.0, .s = 1.0, .l = 0.5 },
        .{ .h = 300.0, .s = 1.0, .l = 0.5 },
        .{ .h = 180.0, .s = 1.0, .l = 0.5 },
        .{ .h = 0.0, .s = 0.0, .l = 0.2 },
        .{ .h = 0.0, .s = 0.0, .l = 0.6 },
    };
    const test_expected_rgb: [10]ColorRGB = .{
        .{ .r = 0.0, .g = 0.0, .b = 0.0 },
        .{ .r = 1.0, .g = 1.0, .b = 1.0 },
        .{ .r = 1.0, .g = 0.0, .b = 0.0 },
        .{ .r = 0.0, .g = 1.0, .b = 0.0 },
        .{ .r = 0.0, .g = 0.0, .b = 1.0 },
        .{ .r = 1.0, .g = 1.0, .b = 0.0 },
        .{ .r = 1.0, .g = 0.0, .b = 1.0 },
        .{ .r = 0.0, .g = 1.0, .b = 1.0 },
        .{ .r = 0.2, .g = 0.2, .b = 0.2 },
        .{ .r = 0.6, .g = 0.6, .b = 0.6 },
    };
    try expect(test_hsl_colors.len == test_expected_rgb.len);
    for (test_hsl_colors, 0..) |hsl, i| {
        std.debug.print("Current idx: {}\n", .{i});
        const rgb = hsl.toRGB();
        const expected_rgb = test_expected_rgb[i];
        try expect(rgb.r == expected_rgb.r);
        try expect(rgb.g == expected_rgb.g);
        try expect(rgb.b == expected_rgb.b);
    }
}
