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
        const other_converted: Color = switch (self.*) {
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
        const l = (max + min) / 2.0;
        const s: f32 = if (delta == 0) 0.0 else delta / (1.0 - @abs(2.0 * l - 1.0));
        return .{ .h = h, .s = s, .l = l };
    }

    fn toXYZ(self: *const @This()) ColorXYZ {
        const val_r: f32 = if (self.r > 0.04045) std.math.pow(f32, (self.r + 0.055) / 1.055, 2.4) else self.r;
        const val_g: f32 = if (self.g > 0.04045) std.math.pow(f32, (self.g + 0.055) / 1.055, 2.4) else self.g;
        const val_b: f32 = if (self.b > 0.04045) std.math.pow(f32, (self.b + 0.055) / 1.055, 2.4) else self.b;
        return .{
            .x = val_r * 0.4124 + val_g * 0.3576 + val_b * 0.1805,
            .y = val_r * 0.2126 + val_g * 0.7152 + val_b * 0.0722,
            .z = val_r * 0.0193 + val_g * 0.1192 + val_b * 0.9505,
        };
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
        const dh_raw: f32 = @abs(self.h - other.h);
        const dh: f32 = @min(dh_raw, 360 - dh_raw) / 360.0;
        const ds: f32 = self.s - other.s;
        const dl: f32 = self.l - other.l;
        return (dh * dh + ds * ds + dl * dl) / 3.0;
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
            .r = if (vr > 0.0031308) 1.055 * std.math.pow(f32, vr, (1.0 / 2.4)) - 0.055 else 12.92 * vr,
            .g = if (vg > 0.0031308) 1.055 * std.math.pow(f32, vg, (1.0 / 2.4)) - 0.055 else 12.92 * vg,
            .b = if (vb > 0.0031308) 1.055 * std.math.pow(f32, vb, (1.0 / 2.4)) - 0.055 else 12.92 * vb,
        };
    }

    // Calculates a normalized distance between two HSL colors
    // Euclidean distance calculation, converting hue and saturation to cartesian coordinates
    // Efficiency: High
    // Percieved Color: Lower
    fn dst(self: *const @This(), other: *const ColorXYZ) f32 {
        const dx: f32 = self.x - other.x;
        const dy: f32 = self.y - other.y;
        const dz: f32 = self.z - other.z;
        return (dx * dx + dy * dy + dz * dz) / 3.0;
    }
};
