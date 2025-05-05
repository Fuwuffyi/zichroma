const std = @import("std");
const color = @import("color.zig");
const vecutil = @import("vector.zig");

fn toRGB(self: *const vecutil.Vec3) vecutil.Vec3 {
    const l: f32 = self[2];
    if (self[1] == 0.0) {
        return @as(vecutil.Vec3, @splat(l));
    }
    const c: f32 = (1 - @abs(2.0 * l - 1.0)) * self[1];
    const hp: f32 = self[0] / 60.0;
    const x: f32 = c * (1.0 - @abs(@mod(hp, 2.0) - 1.0));
    const m: f32 = l - c * 0.5;
    const rgb: vecutil.Vec3 = switch (@mod(@as(u8, @intFromFloat(hp)), 6)) {
        0 => vecutil.Vec3{ c, x, 0 },
        1 => vecutil.Vec3{ x, c, 0 },
        2 => vecutil.Vec3{ 0, c, x },
        3 => vecutil.Vec3{ 0, x, c },
        4 => vecutil.Vec3{ x, 0, c },
        5 => vecutil.Vec3{ c, 0, x },
        else => unreachable,
    } + @as(vecutil.Vec3, @splat(m));
    return @min(@max(rgb, vecutil.ZeroVec), vecutil.OneVec);
}

fn negative(self: *const vecutil.Vec3) vecutil.Vec3 {
    return .{ self[0], self[1], 1 - self[2] };
}

fn brightness(self: *const vecutil.Vec3) f32 {
    return self[2];
}

fn dst(self: *const vecutil.Vec3, other: *const vecutil.Vec3) f32 {
    const a: f32 = std.math.degreesToRadians(self[0]);
    const b: f32 = std.math.degreesToRadians(other[0]);
    const u: vecutil.Vec3 = .{ self[1] * @cos(a), self[1] * @sin(a), self[2] };
    const v: vecutil.Vec3 = .{ other[1] * @cos(b), other[1] * @sin(b), other[2] };
    const d: vecutil.Vec3 = u - v;
    return @reduce(.Add, d * d) / 3.0;
}

const hslVTable: color.ColorVTable = .{
    .negative = &negative,
    .brightness = &brightness,
    .dst = &dst,
};

pub fn init() color.Color {
    return .{
        .vtable = hslVTable,
        .values = vecutil.Vec3{ 0, 0, 0 },
    };
}
