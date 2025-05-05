const std = @import("std");

pub const Vec3 = @Vector(3, f32);
pub const OneVec = @as(Vec3, @splat(1.0));
pub const ZeroVec = @as(Vec3, @splat(0.0));

pub inline fn powVec(v: Vec3, exp: f32) Vec3 {
    return .{
        std.math.pow(f32, v[0], exp),
        std.math.pow(f32, v[1], exp),
        std.math.pow(f32, v[2], exp),
    };
}
