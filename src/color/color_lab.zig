const color = @import("color.zig");
const vecutil = @import("vector.zig");

const color_xyz = @import("color_xyz.zig");

fn toXYZ(self: *const vecutil.Vec3) vecutil.Vec3 {
    const fy: f32 = (self[0] + 16) / 116;
    const fx: f32 = self[1] / 500 + fy;
    const fz: f32 = fy - self[2] / 200;
    const xr: f32 = if (fx > 0.206897) fx * fx * fx else (116 * fx - 16) / 903.3;
    const yr: f32 = if (self[0] > 7.9996) fy * fy * fy else self[0] / 903.3;
    const zr: f32 = if (fz > 0.206897) fz * fz * fz else (116 * fz - 16) / 903.3;
    return .{ xr * color_xyz.D65[0], yr * color_xyz.D65[1], zr * color_xyz.D65[2] };
}

fn negative(self: *const vecutil.Vec3) vecutil.Vec3 {
    return .{
        100 - self[0],
        -self[1],
        -self[2],
    };
}

fn brightness(self: *const vecutil.Vec3) f32 {
    return self[0];
}

fn dst(self: *const vecutil.Vec3, other: *const vecutil.Vec3) f32 {
    const d: vecutil.Vec3 = self.* - other.*;
    return @reduce(.Add, d * d) * 7.08856e-6;
}

const labVTable: color.ColorVTable = .{
    .negative = &negative,
    .brightness = &brightness,
    .dst = &dst,
};

pub fn init() color.Color {
    return .{
        .vtable = labVTable,
        .values = vecutil.Vec3{ 0, 0, 0 },
    };
}
