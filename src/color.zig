const std = @import("std");

pub const Color = packed struct {
    r: f32,
    g: f32,
    b: f32,

    pub fn brightness(self: *const @This()) f32 {
        return @sqrt(0.2126 * self.r + 0.7152 * self.g + 0.0722 * self.b);
    }

    // Euclidean distance calculation
    // Efficiency: High
    // Percieved Color: Low
    pub fn dst_squared(self: *const @This(), other: *const Color) f32 {
        const dr: f32 = self.r - other.r;
        const dg: f32 = self.g - other.g;
        const db: f32 = self.b - other.b;
        return dr * dr + dg * dg + db * db;
    }

    // Redman distance calculation
    // Efficiency: High
    // Percieved Color: Low
    pub fn dst_squared_redman(self: *const @This(), other: *const Color) f32 {
        const r: f32 = (self.r + other.r) * 0.5;
        const dr: f32 = self.r - other.r;
        const dg: f32 = self.g - other.g;
        const db: f32 = self.b - other.b;
        return (2 + r / 256) * dr * dr + 4 * dg * dg + (2 + (255 - r) / 256) * db * db;
    }
};
