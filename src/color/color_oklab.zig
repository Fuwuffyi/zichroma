const std = @import("std");
const color = @import("color.zig");
const vecutil = @import("vector.zig");

const color_rgb = @import("color_rgb.zig");

const M1_Inv_Oklab: struct { x: vecutil.Vec3, y: vecutil.Vec3, z: vecutil.Vec3 } = .{
    .x = .{ 1.0, 0.3963377922, 0.2158037581 },
    .y = .{ 1.0, -0.1055613423, -0.0638541748 },
    .z = .{ 1.0, -0.0894841821, -1.2914855379 },
};

const M2_Inv_Oklab: struct { x: vecutil.Vec3, y: vecutil.Vec3, z: vecutil.Vec3 } = .{
    .x = .{ 4.0767416621, -3.3077115913, 0.2309699292 },
    .y = .{ -1.2684380046, 2.6097574011, -0.3413193965 },
    .z = .{ -0.0041960863, -0.7034186147, 1.7076147010 },
};

pub fn toRGB(self: *const vecutil.Vec3) vecutil.Vec3 {
    const c: vecutil.Vec3 = self.*;
    const LMS: vecutil.Vec3 = vecutil.powVec(.{
        @reduce(.Add, c * M1_Inv_Oklab.x),
        @reduce(.Add, c * M1_Inv_Oklab.y),
        @reduce(.Add, c * M1_Inv_Oklab.z),
    }, 3);
    const lin: vecutil.Vec3 = .{
        @reduce(.Add, LMS * M2_Inv_Oklab.x),
        @reduce(.Add, LMS * M2_Inv_Oklab.y),
        @reduce(.Add, LMS * M2_Inv_Oklab.z),
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
