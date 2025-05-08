const color = @import("color.zig");
const vecutil = @import("vector.zig");

const color_rgb = @import("color_rgb.zig");

pub const D65: vecutil.Vec3 = .{ 95.0489, 100.0, 108.8840 };
pub const DELTA: f32 = 6.0 / 29.0;
pub const DELTA_CUBED: f32 = DELTA * DELTA * DELTA;
pub const INV_3_DELTA_SQR: f32 = 1.0 / (3.0 * DELTA * DELTA);
pub const INV_KAPPA: f32 = 16.0 / 116.0;
pub const KAPPA: f32 = 24389.0 / 27.0;

const RGB_Coeff: struct { r: vecutil.Vec3, g: vecutil.Vec3, b: vecutil.Vec3 } = .{
    .r = .{ 3.2404542, -1.5371385, -0.4985314 },
    .g = .{ -0.9692660, 1.8760108, 0.0415560 },
    .b = .{ 0.0556434, -0.2040259, 1.0572252 },
};

pub fn toRGB(self: *const vecutil.Vec3) vecutil.Vec3 {
    const v: vecutil.Vec3 = .{
        @reduce(.Add, self.* * RGB_Coeff.r),
        @reduce(.Add, self.* * RGB_Coeff.g),
        @reduce(.Add, self.* * RGB_Coeff.b),
    };
    const mask: @Vector(3, bool) = v > @as(vecutil.Vec3, @splat(color_rgb.SRGB_Inv_Threshold));
    const srgb: vecutil.Vec3 = @select(f32, mask, vecutil.powVec(v, color_rgb.SRGB_Inv_Gamma) * @as(vecutil.Vec3, @splat(color_rgb.SRGB_Scale)) - @as(vecutil.Vec3, @splat(color_rgb.SRGB_Offset)), v * @as(vecutil.Vec3, @splat(color_rgb.SRGB_Linear_Factor)));
    return @min(@max(srgb, vecutil.ZeroVec), vecutil.OneVec);
}

pub fn toLAB(self: *const vecutil.Vec3) vecutil.Vec3 {
    const r: vecutil.Vec3 = self.* / D65;
    const mask: @Vector(3, bool) = r > @as(vecutil.Vec3, @splat(DELTA_CUBED));
    const f: vecutil.Vec3 = @select(f32, mask, vecutil.powVec(r, 1.0 / 3.0), (r * @as(vecutil.Vec3, @splat(INV_3_DELTA_SQR)) + @as(vecutil.Vec3, @splat(INV_KAPPA))));
    return .{
        116.0 * f[1] - 16.0,
        500.0 * (f[0] - f[1]),
        200.0 * (f[1] - f[2]),
    };
}

fn negative(self: *const vecutil.Vec3) vecutil.Vec3 {
    return vecutil.OneVec - self.*;
}

fn brightness(self: *const vecutil.Vec3) f32 {
    return self[1];
}

fn dst(self: *const vecutil.Vec3, other: *const vecutil.Vec3) f32 {
    const d: vecutil.Vec3 = self.* - other.*;
    return @reduce(.Add, d * d) / 3.0;
}

const xyzVTable: color.ColorVTable = .{
    .negative = &negative,
    .brightness = &brightness,
    .dst = &dst,
};

pub fn init(values: [3]f32) color.Color {
    return .{
        .tag = .xyz,
        .vtable = xyzVTable,
        .values = values,
    };
}
