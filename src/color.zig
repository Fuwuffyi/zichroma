const std = @import("std");
const modulation_curve = @import("modulation_curve.zig");

pub const Color = union(enum) {
    rgb: ColorRGB,
    hsl: ColorHSL,

    pub fn values(self: *const @This()) [3]f32 {
        return switch (self.*) {
            .rgb => self.rgb.values(),
            .hsl => self.hsl.values(),
        };
    }

    pub fn toRGB(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .rgb = self.rgb },
            .hsl => .{ .rgb = self.hsl.toRGB() },
        };
    }

    pub fn toHSL(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .hsl = self.rgb.toHSL() },
            .hsl => .{ .hsl = self.hsl },
        };
    }

    pub fn dst(self: *const @This(), other: *const Color) f32 {
        const other_converted: Color = switch (self.*) {
            .rgb => other.toRGB(),
            .hsl => other.toHSL(),
        };
        return switch (self.*) {
            .rgb => self.rgb.dst(&other_converted.rgb),
            .hsl => self.hsl.dst(&other_converted.hsl),
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
        const l = (max + min) / 2.0;
        const s: f32 = if (delta == 0) 0.0 else delta / (1.0 - @abs(2.0 * l - 1.0));
        return .{ .h = h, .s = s, .l = l };
    }

    // Calculates a normalized distance between two RGB colors
    // Euclidean distance calculation
    // Efficiency: High
    // Percieved Color: Lower
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

    // Calculates a normalized distance between two HSL colors
    // Euclidean distance calculation, converting hue and saturation to cartesian coordinates
    // Efficiency: High
    // Percieved Color: Lower
    fn dst(self: *const @This(), other: *const ColorHSL) f32 {
        const dh: f32 = @abs(self.h - other.h) / 360.0;
        const ds: f32 = self.s - other.s;
        const dl: f32 = self.l - other.l;
        return (dh * dh + ds * ds + dl * dl) / 3.0;
    }
};
