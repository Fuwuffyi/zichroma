const color = @import("color.zig");
const vecutil = @import("vector.zig");

const color_rgb = @import("color_rgb.zig");

pub const D65: vecutil.Vec3 = .{ 0.95047, 1.00000, 1.08883 };

const RGB_Coeff: struct { r: vecutil.Vec3, g: vecutil.Vec3, b: vecutil.Vec3 } = .{
    .r = .{ 3.2406, -1.5372, -0.4986 },
    .g = .{ -0.9689, 1.8758, 0.0415 },
    .b = .{ 0.0557, -0.2040, 1.0570 },
};

pub fn toRGB(self: *const vecutil.Vec3) vecutil.Vec3 {
    const v: vecutil.Vec3 = .{
        @reduce(.Add, self.* * RGB_Coeff.r),
        @reduce(.Add, self.* * RGB_Coeff.g),
        @reduce(.Add, self.* * RGB_Coeff.b),
    };
    const mask: @Vector(3, bool) = v > @as(vecutil.Vec3, @splat(0.0031308));
    const srgb: vecutil.Vec3 = @select(f32, mask, vecutil.powVec(v, color_rgb.SRGB_Inv_Linear_Exp) * @as(vecutil.Vec3, @splat(color_rgb.SRGB_Scale)) - @as(vecutil.Vec3, @splat(color_rgb.SRGB_Offset)), v * @as(vecutil.Vec3, @splat(color_rgb.SRGB_Linear_Factor)));
    return @min(@max(srgb, vecutil.ZeroVec), vecutil.OneVec);
}

pub fn toLAB(self: *const vecutil.Vec3) vecutil.Vec3 {
    const r: vecutil.Vec3 = self.* / D65;
    const mask: @Vector(3, bool) = r > @as(vecutil.Vec3, @splat(0.008856));
    const f: vecutil.Vec3 = @select(f32, mask, vecutil.powVec(r, 1.0 / 3.0), (r * @as(vecutil.Vec3, @splat(903.3)) + @as(vecutil.Vec3, @splat(16.0))) / @as(vecutil.Vec3, @splat(116.0)));
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
