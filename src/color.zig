const std = @import("std");

pub const ColorRGB = packed struct {
    r: f32,
    g: f32,
    b: f32,

    // Euclidean distance calculation
    // Efficiency: High
    // Percieved Color: Lower
    // UNUSED
    pub fn dst_squared(self: *const @This(), other: *const ColorRGB) f32 {
        const dr: f32 = self.r - other.r;
        const dg: f32 = self.g - other.g;
        const db: f32 = self.b - other.b;
        return dr * dr + dg * dg + db * db;
    }

    // Redman distance calculation
    // Efficiency: High
    // Percieved Color: Low
    // UNUSED
    pub fn dst_squared_redman(self: *const @This(), other: *const ColorRGB) f32 {
        const r: f32 = (self.r + other.r) * 0.5;
        const dr: f32 = self.r - other.r;
        const dg: f32 = self.g - other.g;
        const db: f32 = self.b - other.b;
        return (2 + r / 256) * dr * dr + 4 * dg * dg + (2 + (255 - r) / 256) * db * db;
    }

    pub fn toHSL(rgb: *const @This()) ColorHSL {
        const r: f32 = rgb.r;
        const g: f32 = rgb.g;
        const b: f32 = rgb.b;
        const max: f32 = @max(r, @max(g, b));
        const min: f32 = @min(r, @min(g, b));
        const delta: f32 = max - min;
        var h: f32 = 0;
        if (delta != 0) {
            if (max == r) {
                h = (g - b) / delta;
            } else if (max == g) {
                h = 2 + (b - r) / delta;
            } else {
                h = 4 + (r - g) / delta;
            }
        }
        h *= 60;
        if (h < 0) {
            h += 360;
        }
        const l: f32 = (max + min) / 2;
        return .{ .h = h, .s = if (delta == 0) 0 else delta / (1 - @abs(2 * l - 1)), .l = l };
    }
};

pub const ColorHSL = packed struct {
    h: f32,
    s: f32,
    l: f32,

    // Euclidean distance calculation, converting hue and saturation to cartesian coordinates
    // Efficiency: Medium-High
    // Percieved Color: Lower
    pub fn dst_squared(self: *const @This(), other: *const ColorHSL) f32 {
        const h1_rad: f32 = self.h * std.math.pi / 180;
        const h2_rad: f32 = other.h * std.math.pi / 180;
        const x1: f32 = self.s * std.math.cos(h1_rad);
        const y1: f32 = self.s * std.math.sin(h1_rad);
        const x2: f32 = other.s * std.math.cos(h2_rad);
        const y2: f32 = other.s * std.math.sin(h2_rad);
        const dx: f32 = x1 - x2;
        const dy: f32 = y1 - y2;
        const dl: f32 = self.l - other.l;
        return dx * dx + dy * dy + dl * dl;
    }

    pub fn toRGB(hsl: *const @This()) ColorRGB {
        if (hsl.s == 0) {
            return ColorRGB{ .r = hsl.l, .g = hsl.l, .b = hsl.l };
        }
        const c: f32 = (1 - @abs(2 * hsl.l - 1)) * hsl.s;
        const h_prime: f32 = hsl.h / 60;
        const mod2: f32 = h_prime - 2 * @floor(h_prime / 2);
        const x: f32 = c * (1 - @abs(mod2 - 1));
        const m: f32 = hsl.l - c / 2;
        var r1: f32 = 0;
        var g1: f32 = 0;
        var b1: f32 = 0;
        if (h_prime < 1) {
            r1 = c;
            g1 = x;
            b1 = 0;
        } else if (h_prime < 2) {
            r1 = x;
            g1 = c;
            b1 = 0;
        } else if (h_prime < 3) {
            r1 = 0;
            g1 = c;
            b1 = x;
        } else if (h_prime < 4) {
            r1 = 0;
            g1 = x;
            b1 = c;
        } else if (h_prime < 5) {
            r1 = x;
            g1 = 0;
            b1 = c;
        } else {
            r1 = c;
            g1 = 0;
            b1 = x;
        }
        return ColorRGB{
            .r = r1 + m,
            .g = g1 + m,
            .b = b1 + m,
        };
    }
};
