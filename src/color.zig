const std = @import("std");

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
    // Efficiency: Medium-High
    // Percieved Color: Lower
    pub fn dst_squared(self: *const @This(), other: *const ColorHSL) f32 {
        const h1_rad: f32 = std.math.degreesToRadians(self.h);
        const h2_rad: f32 = std.math.degreesToRadians(other.h);
        const x1: f32 = self.s * @cos(h1_rad);
        const y1: f32 = self.s * @sin(h1_rad);
        const x2: f32 = other.s * @cos(h2_rad);
        const y2: f32 = other.s * @sin(h2_rad);
        const dx: f32 = x1 - x2;
        const dy: f32 = y1 - y2;
        const dl: f32 = self.l - other.l;
        return dx * dx + dy * dy + dl * dl;
    }

    pub fn negative(self: *const @This()) ColorHSL {
        return .{ .h = @mod(self.h + 180.0, 360.0), .s = 1.0 - self.s, .l = 1.0 - self.l };
    }

    pub fn modulate(self: *const @This(), h_mod: f32, s_mod: f32, l_mod: f32) ColorHSL {
        return .{
            .h = @mod(self.h + h_mod, 360.0),
            .s = std.math.clamp(self.s * s_mod, 0.0, 1.0),
            .l = std.math.clamp(self.l * l_mod, 0.0, 1.0),
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
