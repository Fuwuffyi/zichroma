const std = @import("std");
const color = @import("color.zig");
const vecutil = @import("vector.zig");

const color_rgb = @import("color_rgb.zig");

pub fn toRGB(self: *const vecutil.Vec3) vecutil.Vec3 {
    const c: vecutil.Vec3 = self.*;
    const l_: f32 = c[0] + 0.3963377774 * c[1] + 0.2158037573 * c[2];
    const m_: f32 = c[0] - 0.1055613458 * c[1] - 0.0638541728 * c[2];
    const s_: f32 = c[0] - 0.0894841775 * c[1] - 1.2914855480 * c[2];
    const l: f32 = l_ * l_ * l_;
    const m: f32 = m_ * m_ * m_;
    const s: f32 = s_ * s_ * s_;
    const lin: vecutil.Vec3 = .{
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    };
    const mask: @Vector(3, bool) = lin > @as(vecutil.Vec3, @splat(color_rgb.SRGB_Threshold));
    const c_srgb: vecutil.Vec3 = @select(f32, mask, vecutil.powVec(lin, color_rgb.SRGB_Inv_Linear_Exp) * @as(vecutil.Vec3, @splat(color_rgb.SRGB_Scale)) - @as(vecutil.Vec3, @splat(color_rgb.SRGB_Offset)), lin * @as(vecutil.Vec3, @splat(color_rgb.SRGB_Linear_Factor)));
    return @min(@max(c_srgb, vecutil.ZeroVec), vecutil.OneVec);
}

fn negative(self: *const vecutil.Vec3) vecutil.Vec3 {
    return vecutil.OneVec - self.*;
}

fn brightness(self: *const vecutil.Vec3) f32 {
    return self[0];
}

fn dst(self: *const vecutil.Vec3, other: *const vecutil.Vec3) f32 {
    const d: vecutil.Vec3 = self.* - other.*;
    return @reduce(.Add, d * d);
}

const oklabVTable: color.ColorVTable = .{
    .negative = &negative,
    .brightness = &brightness,
    .dst = &dst,
};

pub fn init(values: [3]f32) color.Color {
    return .{
        .tag = .oklab,
        .vtable = oklabVTable,
        .values = values,
    };
}
