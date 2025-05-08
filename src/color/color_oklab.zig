const std = @import("std");
const color = @import("color.zig");
const vecutil = @import("vector.zig");

const color_rgb = @import("color_rgb.zig");

pub fn toRGB(self: *const vecutil.Vec3) vecutil.Vec3 {
    const c: vecutil.Vec3 = self.*;
    const lp: f32 = c[0] + 0.3963377922 * c[1] + 0.2158037581 * c[2];
    const mp: f32 = c[0] - 0.1055613423 * c[1] - 0.0638541748 * c[2];
    const sp: f32 = c[0] - 0.0894841821 * c[1] - 1.2914855379 * c[2];
    const L: f32 = lp * lp * lp;
    const M: f32 = mp * mp * mp;
    const S: f32 = sp * sp * sp;
    const lin: vecutil.Vec3 = .{
        4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S,
       -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S,
       -0.0041960863 * L - 0.7034186147 * M + 1.7076147010 * S,
    };
    const mask: @Vector(3, bool) = lin > @as(vecutil.Vec3, @splat(color_rgb.SRGB_Inv_Threshold));
    const srgb: vecutil.Vec3 = @select(f32, mask, vecutil.powVec(lin, color_rgb.SRGB_Inv_Gamma) * @as(vecutil.Vec3, @splat(color_rgb.SRGB_Scale)) - @as(vecutil.Vec3, @splat(color_rgb.SRGB_Offset)), lin * @as(vecutil.Vec3, @splat(color_rgb.SRGB_Linear_Factor)));
    return @min(@max(srgb, vecutil.ZeroVec), vecutil.OneVec);
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
