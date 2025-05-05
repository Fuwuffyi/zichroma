const std = @import("std");

const Vec3 = @Vector(3, f32);

const OneVec = @as(Vec3, @splat(1.0));
const ZeroVec = @as(Vec3, @splat(0.0));
const Epsilon = 1e-6;
// sRGB - linear RGB thresholds & coeffs
const SRGB_Threshold = 0.04045;
const SRGB_Linear_Factor = 12.92;
const SRGB_Linear_Exp = 2.4;
const SRGB_Inv_Linear_Exp = 1.0 / SRGB_Linear_Exp;
const SRGB_Scale = 1.055;
const SRGB_Offset = 0.055;
// CIE reference white
const D65: Vec3 = .{ 0.95047, 1.00000, 1.08883 };
// Color‐distance weights
const ColorWeightsRGB: Vec3 = .{ 0.2126, 0.7152, 0.0722 };
// RGB -> XYZ
const XYZ_Coeff: struct { x: Vec3, y: Vec3, z: Vec3 } = .{
    .x = .{ 0.4124, 0.3576, 0.1805 },
    .y = .{ 0.2126, 0.7152, 0.0722 },
    .z = .{ 0.0193, 0.1192, 0.9505 },
};
// XYZ -> RGB
const RGB_Coeff: struct { r: Vec3, g: Vec3, b: Vec3 } = .{
    .r = .{ 3.2406, -1.5372, -0.4986 },
    .g = .{ -0.9689, 1.8758, 0.0415 },
    .b = .{ 0.0557, -0.2040, 1.0570 },
};

inline fn powVec(v: Vec3, exp: f32) Vec3 {
    return .{
        std.math.pow(f32, v[0], exp),
        std.math.pow(f32, v[1], exp),
        std.math.pow(f32, v[2], exp),
    };
}

pub const ColorSpace = enum { rgb, hsl, xyz, lab, oklab };

pub const Color = union(ColorSpace) {
    rgb: ColorRGB,
    hsl: ColorHSL,
    xyz: ColorXYZ,
    lab: ColorLAB,
    oklab: ColorOKLab,

    pub inline fn values(self: *const @This()) [3]f32 {
        return switch (self.*) {
            inline else => |c| c.values,
        };
    }

    pub inline fn setValues(self: *@This(), v: [3]f32) void {
        switch (self.*) {
            inline else => |*c| c.values = v,
        }
    }

    pub inline fn toRGB(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .rgb = self.rgb },
            .hsl => .{ .rgb = self.hsl.toRGB() },
            .xyz => .{ .rgb = self.xyz.toRGB() },
            .lab => .{ .rgb = self.lab.toXYZ().toRGB() },
            .oklab => .{ .rgb = self.oklab.toRGB() },
        };
    }

    pub inline fn toHSL(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .hsl = self.rgb.toHSL() },
            .hsl => .{ .hsl = self.hsl },
            .xyz => .{ .hsl = self.xyz.toRGB().toHSL() },
            .lab => .{ .hsl = self.lab.toXYZ().toRGB().toHSL() },
            .oklab => .{ .hsl = self.oklab.toRGB().toHSL() },
        };
    }

    pub inline fn toXYZ(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .xyz = self.rgb.toXYZ() },
            .hsl => .{ .xyz = self.hsl.toRGB().toXYZ() },
            .xyz => .{ .xyz = self.xyz },
            .lab => .{ .xyz = self.lab.toXYZ() },
            .oklab => .{ .xyz = self.oklab.toRGB().toXYZ() },
        };
    }

    pub inline fn toLAB(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .lab = self.rgb.toXYZ().toLAB() },
            .hsl => .{ .lab = self.hsl.toRGB().toXYZ().toLAB() },
            .xyz => .{ .lab = self.xyz.toLAB() },
            .lab => .{ .lab = self.lab },
            .oklab => .{ .lab = self.oklab.toRGB().toXYZ().toLAB() },
        };
    }

    pub inline fn toOKLab(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .oklab = self.rgb.toOKLab() },
            .hsl => .{ .oklab = self.hsl.toRGB().toOKLab() },
            .xyz => .{ .oklab = self.xyz.toRGB().toOKLab() },
            .lab => .{ .oklab = self.lab.toXYZ().toRGB().toOKLab() },
            .oklab => .{ .oklab = self.oklab },
        };
    }

    pub inline fn negative(self: Color) Color {
        return switch (self) {
            .rgb => |c| .{ .rgb = c.negative() },
            .hsl => |c| .{ .hsl = c.negative() },
            .xyz => |c| .{ .xyz = c.negative() },
            .lab => |c| .{ .lab = c.negative() },
            .oklab => |c| .{ .oklab = c.negative() },
        };
    }

    pub inline fn getBrightness(self: Color) f32 {
        return switch (self) {
            inline else => |c| c.getBrightness(),
        };
    }

    pub inline fn dst(self: *const @This(), other: *const Color) f32 {
        const tag = std.meta.activeTag(self.*);
        const o: Color = if (tag == std.meta.activeTag(other.*)) other.* else switch (self.*) {
            .rgb => other.toRGB(),
            .hsl => other.toHSL(),
            .xyz => other.toXYZ(),
            .lab => other.toLAB(),
            .oklab => other.toOKLab(),
        };
        return switch (self.*) {
            .rgb => self.rgb.dst(&o.rgb),
            .hsl => self.hsl.dst(&o.hsl),
            .xyz => self.xyz.dst(&o.xyz),
            .lab => self.lab.dst(&o.lab),
            .oklab => self.oklab.dst(&o.oklab),
        };
    }
};

const ColorRGB = struct {
    values: Vec3,

    fn toHSL(self: *const @This()) ColorHSL {
        const mx: f32 = @reduce(.Max, self.values);
        const mn: f32 = @reduce(.Min, self.values);
        const d: f32 = mx - mn;
        var h: f32 = 0.0;
        if (d > Epsilon) {
            if (mx == self.values[0]) {
                h = ((self.values[1] - self.values[2]) / d) * 60.0;
            } else if (mx == self.values[1]) {
                h = ((self.values[2] - self.values[0]) / d + 2.0) * 60.0;
            } else {
                h = ((self.values[0] - self.values[1]) / d + 4.0) * 60.0;
            }
        }
        h = @mod(h, 360.0);
        const l: f32 = (mx + mn) * 0.5;
        const s: f32 = if (d < Epsilon) 0.0 else d / (1.0 - @abs(2.0 * l - 1.0));
        return .{ .values = .{ h, s, l } };
    }

    fn toXYZ(self: *const @This()) ColorXYZ {
        const mask: @Vector(3, bool) = self.values > @as(Vec3, @splat(SRGB_Threshold));
        const lin: Vec3 = @select(f32, mask, powVec((self.values + @as(Vec3, @splat(SRGB_Offset))) / @as(Vec3, @splat(SRGB_Scale)), SRGB_Linear_Exp), self.values / @as(Vec3, @splat(SRGB_Linear_Factor)));
        return .{ .values = .{
            @reduce(.Add, lin * XYZ_Coeff.x),
            @reduce(.Add, lin * XYZ_Coeff.y),
            @reduce(.Add, lin * XYZ_Coeff.z),
        } };
    }

    fn toOKLab(self: *const @This()) ColorOKLab {
        const c = self.values;
        const mask: @Vector(3, bool) = c > @as(Vec3, @splat(SRGB_Threshold));
        const lin: Vec3 = @select(f32, mask, powVec((c + @as(Vec3, @splat(SRGB_Offset))) / @as(Vec3, @splat(SRGB_Scale)), SRGB_Linear_Exp), c / @as(Vec3, @splat(SRGB_Linear_Factor)));
        const l: f32 = 0.4122214708 * lin[0] + 0.5363325363 * lin[1] + 0.0514459929 * lin[2];
        const m: f32 = 0.2119034982 * lin[0] + 0.6806995451 * lin[1] + 0.1073969566 * lin[2];
        const s: f32 = 0.0883024619 * lin[0] + 0.2817188376 * lin[1] + 0.6299787005 * lin[2];
        const l_: f32 = std.math.cbrt(l);
        const m_: f32 = std.math.cbrt(m);
        const s_: f32 = std.math.cbrt(s);
        const L: f32 = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
        const a: f32 = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
        const b: f32 = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;
        return .{ .values = .{ L, a, b } };
    }

    fn dst(self: *const @This(), other: *const ColorRGB) f32 {
        const d: Vec3 = self.values - other.values;
        return @reduce(.Add, d * d * ColorWeightsRGB);
    }

    fn negative(self: ColorRGB) ColorRGB {
        return .{ .values = OneVec - self.values };
    }

    fn getBrightness(self: ColorRGB) f32 {
        return @reduce(.Add, self.values * ColorWeightsRGB);
    }
};

const ColorHSL = struct {
    values: Vec3,

    fn toRGB(self: *const @This()) ColorRGB {
        const l: f32 = self.values[2];
        if (self.values[1] == 0.0) {
            return .{ .values = @as(Vec3, @splat(l)) };
        }
        const c: f32 = (1 - @abs(2.0 * l - 1.0)) * self.values[1];
        const hp: f32 = self.values[0] / 60.0;
        const x: f32 = c * (1.0 - @abs(@mod(hp, 2.0) - 1.0));
        const m: f32 = l - c * 0.5;
        var rgb: Vec3 = switch (@mod(@as(u8, @intFromFloat(hp)), 6)) {
            0 => Vec3{ c, x, 0 },
            1 => Vec3{ x, c, 0 },
            2 => Vec3{ 0, c, x },
            3 => Vec3{ 0, x, c },
            4 => Vec3{ x, 0, c },
            5 => Vec3{ c, 0, x },
            else => unreachable,
        } + @as(Vec3, @splat(m));
        rgb = @min(@max(rgb, ZeroVec), OneVec);
        return .{ .values = rgb };
    }

    fn dst(self: *const @This(), other: *const ColorHSL) f32 {
        const a: f32 = std.math.degreesToRadians(self.values[0]);
        const b: f32 = std.math.degreesToRadians(other.values[0]);
        const u: Vec3 = .{ self.values[1] * @cos(a), self.values[1] * @sin(a), self.values[2] };
        const v: Vec3 = .{ other.values[1] * @cos(b), other.values[1] * @sin(b), other.values[2] };
        const d: Vec3 = u - v;
        return @reduce(.Add, d * d) / 3.0;
    }

    fn negative(self: ColorHSL) ColorHSL {
        return .{ .values = .{ self.values[0], self.values[1], 1 - self.values[2] } };
    }

    fn getBrightness(self: ColorHSL) f32 {
        return self.values[2];
    }
};

const ColorXYZ = struct {
    values: Vec3,

    fn toRGB(self: *const @This()) ColorRGB {
        const v: Vec3 = .{
            @reduce(.Add, self.values * RGB_Coeff.r),
            @reduce(.Add, self.values * RGB_Coeff.g),
            @reduce(.Add, self.values * RGB_Coeff.b),
        };
        const mask: @Vector(3, bool) = v > @as(Vec3, @splat(0.0031308));
        var srgb: Vec3 = @select(f32, mask, powVec(v, SRGB_Inv_Linear_Exp) * @as(Vec3, @splat(SRGB_Scale)) - @as(Vec3, @splat(SRGB_Offset)), v * @as(Vec3, @splat(SRGB_Linear_Factor)));
        srgb = @min(@max(srgb, ZeroVec), OneVec);
        return .{ .values = srgb };
    }

    fn toLAB(self: *const @This()) ColorLAB {
        const r: Vec3 = self.values / D65;
        const mask: @Vector(3, bool) = r > @as(Vec3, @splat(0.008856));
        const f: Vec3 = @select(f32, mask, powVec(r, 1.0 / 3.0), (r * @as(Vec3, @splat(903.3)) + @as(Vec3, @splat(16.0))) / @as(Vec3, @splat(116.0)));
        return .{ .values = .{
            116.0 * f[1] - 16.0,
            500.0 * (f[0] - f[1]),
            200.0 * (f[1] - f[2]),
        } };
    }

    fn dst(self: *const @This(), other: *const ColorXYZ) f32 {
        const d: Vec3 = self.values - other.values;
        return @reduce(.Add, d * d) / 3.0;
    }

    fn negative(self: ColorXYZ) ColorXYZ {
        return .{ .values = OneVec - self.values };
    }

    fn getBrightness(self: ColorXYZ) f32 {
        return self.values[1];
    }
};

const ColorLAB = struct {
    values: Vec3,

    fn toXYZ(self: *const @This()) ColorXYZ {
        const fy: f32 = (self.values[0] + 16) / 116;
        const fx: f32 = self.values[1] / 500 + fy;
        const fz: f32 = fy - self.values[2] / 200;
        const xr: f32 = if (fx > 0.206897) fx * fx * fx else (116 * fx - 16) / 903.3;
        const yr: f32 = if (self.values[0] > 7.9996) fy * fy * fy else self.values[0] / 903.3;
        const zr: f32 = if (fz > 0.206897) fz * fz * fz else (116 * fz - 16) / 903.3;
        return .{ .values = .{ xr * D65[0], yr * D65[1], zr * D65[2] } };
    }

    fn dst(self: *const @This(), other: *const ColorLAB) f32 {
        const d: Vec3 = self.values - other.values;
        return @reduce(.Add, d * d) * 7.08856e-6;
    }

    fn negative(self: ColorLAB) ColorLAB {
        return .{ .values = .{
            100 - self.values[0],
            -self.values[1],
            -self.values[2],
        } };
    }

    fn getBrightness(self: ColorLAB) f32 {
        return self.values[0];
    }
};

const ColorOKLab = struct {
    values: Vec3,

    fn toRGB(self: *const @This()) ColorRGB {
        const c: Vec3 = self.values;
        const l_: f32 = c[0] + 0.3963377774 * c[1] + 0.2158037573 * c[2];
        const m_: f32 = c[0] - 0.1055613458 * c[1] - 0.0638541728 * c[2];
        const s_: f32 = c[0] - 0.0894841775 * c[1] - 1.2914855480 * c[2];
        const l: f32 = l_ * l_ * l_;
        const m: f32 = m_ * m_ * m_;
        const s: f32 = s_ * s_ * s_;
        const lin: Vec3 = .{
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
        };
        const mask: @Vector(3, bool) = lin > @as(Vec3, @splat(SRGB_Threshold));
        var c_srgb: Vec3 = @select(f32, mask, powVec(lin, SRGB_Inv_Linear_Exp) * @as(Vec3, @splat(SRGB_Scale)) - @as(Vec3, @splat(SRGB_Offset)), lin * @as(Vec3, @splat(SRGB_Linear_Factor)));
        c_srgb = @min(@max(c_srgb, ZeroVec), OneVec);
        return .{ .values = c_srgb };
    }

    fn dst(self: *const @This(), other: *const ColorOKLab) f32 {
        const d: Vec3 = self.values - other.values;
        return @reduce(.Add, d * d);
    }

    fn negative(self: ColorOKLab) ColorOKLab {
        return .{ .values = OneVec - self.values };
    }

    fn getBrightness(self: ColorOKLab) f32 {
        return self.values[0];
    }
};

test "color format conversions" {
    const expectEqualSlices = std.testing.expectEqualSlices;
    // FIXME: Allow some bit of tolerance to tests, as values provided are not f32 precise lmao
    const colors_rgb: [8]Color = .{
        .{ .rgb = .{ .values = .{ 1, 0, 0 } } },
        .{ .rgb = .{ .values = .{ 0, 1, 0 } } },
        .{ .rgb = .{ .values = .{ 0, 0, 1 } } },
        .{ .rgb = .{ .values = .{ 1, 1, 0 } } },
        .{ .rgb = .{ .values = .{ 1, 0, 1 } } },
        .{ .rgb = .{ .values = .{ 0, 1, 1 } } },
        .{ .rgb = .{ .values = .{ 0, 0, 0 } } },
        .{ .rgb = .{ .values = .{ 1, 1, 1 } } },
    };
    const colors_hsl: [8]Color = .{
        .{ .hsl = .{ .values = .{ 0, 1, 0.5 } } },
        .{ .hsl = .{ .values = .{ 120, 1, 0.5 } } },
        .{ .hsl = .{ .values = .{ 240, 1, 0.5 } } },
        .{ .hsl = .{ .values = .{ 60, 1, 0.5 } } },
        .{ .hsl = .{ .values = .{ 300, 1, 0.5 } } },
        .{ .hsl = .{ .values = .{ 180, 1, 0.5 } } },
        .{ .hsl = .{ .values = .{ 0, 0, 0 } } },
        .{ .hsl = .{ .values = .{ 0, 0, 1 } } },
    };
    const colors_xyz: [8]Color = .{
        .{ .xyz = .{ .values = .{ 0.4124, 0.2126, 0.0193 } } },
        .{ .xyz = .{ .values = .{ 0.3576, 0.7152, 0.1192 } } },
        .{ .xyz = .{ .values = .{ 0.1805, 0.0722, 0.9505 } } },
        .{ .xyz = .{ .values = .{ 0.77, 0.9278, 0.1385 } } },
        .{ .xyz = .{ .values = .{ 0.5929, 0.2848, 0.9698 } } },
        .{ .xyz = .{ .values = .{ 0.5381, 0.7874, 1.0697 } } },
        .{ .xyz = .{ .values = .{ 0, 0, 0 } } },
        .{ .xyz = .{ .values = .{ 0.9505, 1, 1.089 } } },
    };
    const colors_lab: [8]Color = .{
        .{ .lab = .{ .values = .{ 53.23, 80.11, 67.22 } } },
        .{ .lab = .{ .values = .{ 87.74, -86.18, 83.18 } } },
        .{ .lab = .{ .values = .{ 32.3, 79.2, -107.86 } } },
        .{ .lab = .{ .values = .{ 97.14, -21.56, 94.48 } } },
        .{ .lab = .{ .values = .{ 60.32, 98.25, -60.84 } } },
        .{ .lab = .{ .values = .{ 91.12, -48.08, -14.14 } } },
        .{ .lab = .{ .values = .{ 0, 0, 0 } } },
        .{ .lab = .{ .values = .{ 100, 0.01, -0.01 } } },
    };
    const colors_oklab: [8]Color = .{
        .{ .oklab = .{ .values = .{ 0.628, 0.5625, 0.315 } } },
        .{ .oklab = .{ .values = .{ 0.866, -0.585, 0.4475 } } },
        .{ .oklab = .{ .values = .{ 0.452, -0.8, -0.78 } } },
        .{ .oklab = .{ .values = .{ 0.968, -0.1775, 0.4975 } } },
        .{ .oklab = .{ .values = .{ 0.702, 0.6875, -0.4225 } } },
        .{ .oklab = .{ .values = .{ 0.968, -0.1775, 0.4975 } } },
        .{ .oklab = .{ .values = .{ 0, 0, 0 } } },
        .{ .oklab = .{ .values = .{ 1.0, 0, 0 } } },
    };
    var failed: bool = false;
    //// TEST RGB -> OTHER
    // RGB -> HSL
    for (colors_rgb, 0..) |c_rgb, i| {
        const color_hsl: Color = c_rgb.toHSL();
        const a_vals: [3]f32 = color_hsl.values();
        const b_vals: [3]f32 = colors_hsl[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error RGB -> HSL at index: {}", .{i});
            failed = true;
        };
    }
    // RGB -> XYZ
    for (colors_rgb, 0..) |c_rgb, i| {
        const color_xyz: Color = c_rgb.toXYZ();
        const a_vals: [3]f32 = color_xyz.values();
        const b_vals: [3]f32 = colors_xyz[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error RGB -> XYZ at index: {}", .{i});
            failed = true;
        };
    }
    // RGB -> OKLAB
    for (colors_rgb, 0..) |c_rgb, i| {
        const color_oklab: Color = c_rgb.toOKLab();
        const a_vals: [3]f32 = color_oklab.values();
        const b_vals: [3]f32 = colors_oklab[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error RGB -> OKLAB at index: {}\n", .{i});
            failed = true;
        };
    }
    //// TEST HSL -> OTHER
    // HSL -> RGB
    for (colors_hsl, 0..) |c_hsl, i| {
        const color_rgb: Color = c_hsl.toRGB();
        const a_vals: [3]f32 = color_rgb.values();
        const b_vals: [3]f32 = colors_rgb[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error HSL -> RGB at index: {}", .{i});
            failed = true;
        };
    }
    //// TEST XYZ -> OTHER
    // XYZ -> RGB
    for (colors_xyz, 0..) |c_xyz, i| {
        const color_rgb: Color = c_xyz.toRGB();
        const a_vals: [3]f32 = color_rgb.values();
        const b_vals: [3]f32 = colors_rgb[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error XYZ -> RGB at index: {}", .{i});
            failed = true;
        };
    }
    // XYZ -> LAB
    for (colors_xyz, 0..) |c_xyz, i| {
        const color_lab: Color = c_xyz.toLAB();
        const a_vals: [3]f32 = color_lab.values();
        const b_vals: [3]f32 = colors_lab[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error XYZ -> LAB at index: {}", .{i});
            failed = true;
        };
    }
    //// TEST LAB -> OTHER
    // LAB -> XYZ
    for (colors_lab, 0..) |c_lab, i| {
        const color_xyz: Color = c_lab.toXYZ();
        const a_vals: [3]f32 = color_xyz.values();
        const b_vals: [3]f32 = colors_xyz[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error LAB -> XYZ at index: {}\n", .{i});
            failed = true;
        };
    }
    //// TEST OKLAB -> OTHER
    // OKLAB -> RGB
    for (colors_oklab, 0..) |c_oklab, i| {
        const color_rgb: Color = c_oklab.toRGB();
        const a_vals: [3]f32 = color_rgb.values();
        const b_vals: [3]f32 = colors_rgb[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error OKLAB -> RGB at index: {}\n", .{i});
            failed = true;
        };
    }
    try std.testing.expect(!failed);
}
