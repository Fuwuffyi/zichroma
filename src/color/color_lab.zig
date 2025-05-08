const color = @import("color.zig");
const vecutil = @import("vector.zig");

const color_xyz = @import("color_xyz.zig");

pub fn toXYZ(self: *const vecutil.Vec3) vecutil.Vec3 {
    const fy: f32 = (self[0] + 16.0) / 116.0;
    const f: vecutil.Vec3 = .{
        self[1] / 500.0 + fy,
        fy,
        fy - self[2] / 200.0,
    };
    const mask: @Vector(3, bool) = f > @as(vecutil.Vec3, @splat(color_xyz.DELTA));
    const x: vecutil.Vec3 = @select(f32, mask, vecutil.powVec(f, 3), (f - @as(vecutil.Vec3, @splat(color_xyz.INV_KAPPA))) / @as(vecutil.Vec3, @splat(color_xyz.INV_3_DELTA_SQR)));
    return x * color_xyz.D65;
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

pub fn init(values: [3]f32) color.Color {
    return .{
        .tag = .lab,
        .vtable = labVTable,
        .values = values,
    };
}
