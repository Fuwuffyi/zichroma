const std = @import("std");
const color = @import("color.zig");
const vecutil = @import("vector.zig");

const ColorWeightsRGB: vecutil.Vec3 = .{ 0.2126, 0.7152, 0.0722 };

pub const SRGB_Threshold: f32 = 0.04045;
pub const SRGB_Linear_Factor: f32 = 12.92;
pub const SRGB_Gamma: f32 = 2.4;
pub const SRGB_Inv_Gamma: f32 = 1.0 / SRGB_Gamma;
pub const SRGB_Scale: f32 = 1.055;
pub const SRGB_Offset: f32 = 0.055;

const XYZ_Coeff: struct { x: vecutil.Vec3, y: vecutil.Vec3, z: vecutil.Vec3 } = .{
    .x = .{ 0.4124564, 0.3575761, 0.1804375 },
    .y = .{ 0.2126720, 0.7151522, 0.0721750 },
    .z = .{ 0.0193339, 0.1191920, 0.9503041 },
};

pub fn toHSL(self: *const vecutil.Vec3) vecutil.Vec3 {
    const mx: f32 = @reduce(.Max, self.*);
    const mn: f32 = @reduce(.Min, self.*);
    const d: f32 = mx - mn;
    const l: f32 = (mx + mn) * 0.5;
    var h: f32 = 0.0;
    const s: f32 = if (d <= 0.0) 0.0 else d / (1.0 - @abs(2.0 * l - 1.0));
    if (d > 0.0) {
        const inv_d: f32 = 1.0 / d;
        if (mx == self[0]) {
            h = @mod((self[1] - self[2]) * inv_d, 6.0);
        } else if (mx == self[1]) {
            h = ((self[2] - self[0]) * inv_d) + 2.0;
        } else {
            h = ((self[0] - self[1]) * inv_d) + 4.0;
        }
        h *= 60.0;
        if (h < 0.0) h += 360.0;
    }
    return .{ h, s, l };
}

pub fn toXYZ(self: *const vecutil.Vec3) vecutil.Vec3 {
    const c: vecutil.Vec3 = self.*;
    const mask: @Vector(3, bool) = c > @as(vecutil.Vec3, @splat(SRGB_Threshold));
    const lin: vecutil.Vec3 = @select(f32, mask, vecutil.powVec((c + @as(vecutil.Vec3, @splat(SRGB_Offset))) / @as(vecutil.Vec3, @splat(SRGB_Scale)), SRGB_Gamma), c / @as(vecutil.Vec3, @splat(SRGB_Linear_Factor)));
    return .{
        @reduce(.Add, lin * XYZ_Coeff.x),
        @reduce(.Add, lin * XYZ_Coeff.y),
        @reduce(.Add, lin * XYZ_Coeff.z),
    };
}

pub fn toOKLab(self: *const vecutil.Vec3) vecutil.Vec3 {
    const c: vecutil.Vec3 = self.*;
    const mask: @Vector(3, bool) = c > @as(vecutil.Vec3, @splat(SRGB_Threshold));
    const lin: vecutil.Vec3 = @select(f32, mask, vecutil.powVec((c + @as(vecutil.Vec3, @splat(SRGB_Offset))) / @as(vecutil.Vec3, @splat(SRGB_Scale)), SRGB_Gamma), c / @as(vecutil.Vec3, @splat(SRGB_Linear_Factor)));
    const l: f32 = 0.4122214708 * lin[0] + 0.5363325363 * lin[1] + 0.0514459929 * lin[2];
    const m: f32 = 0.2119034982 * lin[0] + 0.6806995451 * lin[1] + 0.1073969566 * lin[2];
    const s: f32 = 0.0883024619 * lin[0] + 0.2817188376 * lin[1] + 0.6299787005 * lin[2];
    const l_: f32 = std.math.cbrt(l);
    const m_: f32 = std.math.cbrt(m);
    const s_: f32 = std.math.cbrt(s);
    const L: f32 = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
    const a: f32 = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
    const b: f32 = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;
    return .{ L, a, b };
}

fn negative(self: *const vecutil.Vec3) vecutil.Vec3 {
    return vecutil.OneVec - self.*;
}

fn brightness(self: *const vecutil.Vec3) f32 {
    return @reduce(.Add, self.* * ColorWeightsRGB);
}

fn dst(self: *const vecutil.Vec3, other: *const vecutil.Vec3) f32 {
    const d: vecutil.Vec3 = self.* - other.*;
    return @reduce(.Add, d * d * ColorWeightsRGB);
}

const rgbVTable: color.ColorVTable = .{
    .negative = &negative,
    .brightness = &brightness,
    .dst = &dst,
};

pub fn init(values: [3]f32) color.Color {
    return .{
        .tag = .rgb,
        .vtable = rgbVTable,
        .values = values,
    };
}
