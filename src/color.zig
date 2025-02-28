const std = @import("std");

pub const Color = packed struct {
    r: f32,
    g: f32,
    b: f32,

    pub fn dst_squared(self: *const @This(), other: *const Color) f32 {
        const dr: f32 = self.r - other.r;
        const dg: f32 = self.g - other.g;
        const db: f32 = self.b - other.b;
        return dr * dr + dg * dg + db * db;
    }
};
