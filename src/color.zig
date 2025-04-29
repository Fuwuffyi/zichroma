const std = @import("std");

const Vec3 = @Vector(3, f32);

pub const ColorSpace = enum { rgb, hsl, xyz, lab };

pub const Color = union(ColorSpace) {
    rgb: ColorRGB,
    hsl: ColorHSL,
    xyz: ColorXYZ,
    lab: ColorLAB,

    pub inline fn values(self: *const @This()) [3]f32 {
        return switch (self.*) {
            inline else => |c| c.values,
        };
    }

    pub inline fn setValues(self: *@This(), new_values: [3]f32) void {
        switch (self.*) {
            inline else => |*c| c.values = new_values,
        }
    }

    pub inline fn toRGB(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .rgb = self.rgb },
            .hsl => .{ .rgb = self.hsl.toRGB() },
            .xyz => .{ .rgb = self.xyz.toRGB() },
            .lab => .{ .rgb = self.lab.toXYZ().toRGB() },
        };
    }

    pub inline fn toHSL(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .hsl = self.rgb.toHSL() },
            .hsl => .{ .hsl = self.hsl },
            .xyz => .{ .hsl = self.xyz.toRGB().toHSL() },
            .lab => .{ .hsl = self.lab.toXYZ().toRGB().toHSL() },
        };
    }

    pub inline fn toXYZ(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .xyz = self.rgb.toXYZ() },
            .hsl => .{ .xyz = self.hsl.toRGB().toXYZ() },
            .xyz => .{ .xyz = self.xyz },
            .lab => .{ .xyz = self.lab.toXYZ() },
        };
    }

    pub inline fn toLAB(self: *const @This()) Color {
        return switch (self.*) {
            .rgb => .{ .lab = self.rgb.toXYZ().toLAB() },
            .hsl => .{ .lab = self.hsl.toRGB().toXYZ().toLAB() },
            .xyz => .{ .lab = self.xyz.toLAB() },
            .lab => .{ .lab = self.lab },
        };
    }

    pub inline fn negative(self: Color) Color {
        return switch (self) {
            .rgb => |rgb| .{ .rgb = rgb.negative() },
            .hsl => |hsl| .{ .hsl = hsl.negative() },
            .xyz => |xyz| .{ .xyz = xyz.negative() },
            .lab => |lab| .{ .lab = lab.negative() },
        };
    }

    pub inline fn getBrightness(self: Color) f32 {
        return switch (self) {
            inline else => |c| c.getBrightness()
        };
    }

    pub inline fn dst(self: *const @This(), other: *const Color) f32 {
        const self_tag = std.meta.activeTag(self.*);
        const other_tag = std.meta.activeTag(other.*);
        const other_converted: Color = if (self_tag == other_tag) other.* else switch (self.*) {
            .rgb => other.toRGB(),
            .hsl => other.toHSL(),
            .xyz => other.toXYZ(),
            .lab => other.toLAB(),
        };
        return switch (self.*) {
            .rgb => self.rgb.dst(&other_converted.rgb),
            .hsl => self.hsl.dst(&other_converted.hsl),
            .xyz => self.xyz.dst(&other_converted.xyz),
            .lab => self.lab.dst(&other_converted.lab),
        };
    }
};

const ColorRGB = struct {
    values: Vec3,

    // Used to slightly improve the percieved color in distance/brightness calculations
    const ColorWeights: Vec3 = .{ 0.2126, 0.7152, 0.0722 };
    // Used to convert RGB to XYZ colors
    const XYZ_XCoeff: Vec3 = .{ 0.4124, 0.3576, 0.1805 };
    const XYZ_YCoeff: Vec3 = .{ 0.2126, 0.7152, 0.0722 };
    const XYZ_ZCoeff: Vec3 = .{ 0.0193, 0.1192, 0.9505 };

    fn toHSL(self: *const @This()) ColorHSL {
        const max: f32 = @reduce(.Max, self.values);
        const min: f32 = @reduce(.Min, self.values);
        const delta: f32 = max - min;
        var h: f32 = 0.0;
        if (delta != 0) {
            if (max == self.values[0]) {
                h = (self.values[1] - self.values[2]) / delta;
            } else if (max == self.values[1]) {
                h = 2.0 + (self.values[2] - self.values[0]) / delta;
            } else {
                h = 4.0 + (self.values[0] - self.values[1]) / delta;
            }
            h *= 60.0;
        }
        h = @mod(h, 360.0);
        const l: f32 = (max + min) / 2.0;
        const s: f32 = if (delta == 0) 0.0 else delta / (1.0 - @abs(2.0 * l - 1.0));
        return .{ .values = .{ h, s, l } };
    }

    fn toXYZ(self: *const @This()) ColorXYZ {
        const mask: @Vector(3, bool) = self.values > @as(Vec3, @splat(0.04045));
        var first: Vec3 = (self.values + @as(Vec3, @splat(0.055))) / @as(Vec3, @splat(1.055));
        // FIXME: Workaround
        first[0] = std.math.pow(f32, first[0], 2.4);
        first[1] = std.math.pow(f32, first[1], 2.4);
        first[2] = std.math.pow(f32, first[2], 2.4);
        // End of workaround
        const other: Vec3 = self.values / @as(Vec3, @splat(12.92));
        const linear: Vec3 = @select(f32, mask, first, other);
        return .{
            .values = .{
                @reduce(.Add, linear * XYZ_XCoeff),
                @reduce(.Add, linear * XYZ_YCoeff),
                @reduce(.Add, linear * XYZ_ZCoeff),
            }
        };
    }

    fn dst(self: *const @This(), other: *const ColorRGB) f32 {
        const d: Vec3 = self.values - other.values;
        return @reduce(.Add, (d * d) * ColorWeights);
    }

    fn negative(self: ColorRGB) ColorRGB {
        return .{ .values = @as(Vec3, @splat(1.0)) - self.values };
    }

    fn getBrightness(self: ColorRGB) f32 {
        return @reduce(.Add, self.values * ColorWeights);
    }
};

const ColorHSL = struct {
    values: Vec3,

    fn toRGB(self: *const @This()) ColorRGB {
        if (self.values[1] == 0.0) {
            return .{ .values = @as(Vec3, @splat(self.values[2])) };
        }
        const chroma: f32 = (1.0 - @abs(2.0 * self.values[2] - 1.0)) * self.values[1];
        const h_prime: f32 = self.values[0] / 60.0;
        const sector: u32 = @mod(@as(u32, @intFromFloat(h_prime)), 6);
        const x: f32 = chroma * (1.0 - @abs(@mod(h_prime, 2.0) - 1.0));
        const m: f32 = self.values[2] - chroma / 2.0;
        var rgb: Vec3 = switch (sector) {
            0 => .{ chroma, x, 0.0 },
            1 => .{ x, chroma, 0.0 },
            2 => .{ 0.0, chroma, x },
            3 => .{ 0.0, x, chroma },
            4 => .{ x, 0.0, chroma },
            5 => .{ chroma, 0.0, x },
            else => unreachable,
        };
        rgb += @as(Vec3, @splat(m));
        return .{ .values = @min(@max(rgb, @as(Vec3, @splat(0.0))), @as(Vec3, @splat(1.0))) };
    }

    fn negative(self: ColorHSL) ColorHSL {
        return .{ .values = .{ self.values[0], self.values[1], 1.0 - self.values[2] } };
    }

    fn getBrightness(self: ColorHSL) f32 {
        return self.values[2];
    }

    fn dst(self: *const @This(), other: *const ColorHSL) f32 {
        const h1_rad: f32 = std.math.degreesToRadians(self.values[0]);
        const h2_rad: f32 = std.math.degreesToRadians(other.values[0]);
        const vec1: Vec3 = .{ self.values[1] * @cos(h1_rad), self.values[1] * @sin(h1_rad), self.values[2] };
        const vec2: Vec3 = .{ other.values[1] * @cos(h2_rad), other.values[1] * @sin(h2_rad), self.values[2] };
        const d: Vec3 = vec1 - vec2;
        return @reduce(.Add, d * d) / 3.0;
    }
};

const ColorXYZ = struct {
    values: Vec3,
    
    // Used to convert XYZ to RGB colors
    const RGB_RCoeff: Vec3 = .{ 3.2406, -1.5372, -0.4986 };
    const RGB_GCoeff: Vec3 = .{ -0.9689, 1.8758, 0.0415 };
    const RGB_BCoeff: Vec3 = .{ 0.0557, -0.2040, 1.0570 };

    fn toRGB(self: *const @This()) ColorRGB {
        const v: Vec3 = .{
            @reduce(.Add, self.values * RGB_RCoeff),
            @reduce(.Add, self.values * RGB_GCoeff),
            @reduce(.Add, self.values * RGB_BCoeff),
        };
        const mask: @Vector(3, bool) = v > @as(Vec3, @splat(0.0031308));
        const first: Vec3 =
            Vec3{
                // FIXME: Workaround
                std.math.pow(f32, v[0], 1.0 / 2.4),
                std.math.pow(f32, v[1], 1.0 / 2.4),
                std.math.pow(f32, v[2], 1.0 / 2.4),
            } * @as(Vec3, @splat(1.055)) - @as(Vec3, @splat(0.055));
        const other: Vec3 = v * @as(Vec3, @splat(12.92));
        
        const result: Vec3 = @select(f32, mask, first, other);
        return .{ .values = @min(@max(result, @as(Vec3, @splat(0.0))), @as(Vec3, @splat(1.0))) };
    }

    fn toLAB(self: *const @This()) ColorLAB {
        const reference_white: [3]f32 = .{ 0.95047, 1.0, 1.08883 };
        const referenced_color: Vec3 = self.values / reference_white;
        const mask: @Vector(3, bool) = referenced_color > @as(Vec3, @splat(0.008856));
        var first: Vec3 = referenced_color;
        // FIXME: Workaround
        first[0] = std.math.pow(f32, first[0], 1.0 / 3.0);
        first[1] = std.math.pow(f32, first[1], 1.0 / 3.0);
        first[2] = std.math.pow(f32, first[2], 1.0 / 3.0);
        // End of workaround
        const other: Vec3 = (referenced_color * @as(Vec3, @splat(903.3)) + @as(Vec3, @splat(16.0))) / @as(Vec3, @splat(116.0));
        const f: Vec3 = @select(f32, mask, first, other);
        return .{ .values = .{
            116.0 * f[1] - 16.0,
            500.0 * (f[0] - f[1]),
            200.0 * (f[1] - f[2]),
        } };
    }

    // TODO: Get better function
    fn negative(self: ColorXYZ) ColorXYZ {
        return self.toRGB().negative().toXYZ();
    }

    // TODO: Get better function
    fn getBrightness(self: ColorXYZ) f32 {
        return self.toRGB().getBrightness();
    }

    fn dst(self: *const @This(), other: *const ColorXYZ) f32 {
        const d: Vec3 = self.values - other.values;
        return @reduce(.Add, d * d) / 3.0;
    }
};

const ColorLAB = struct {
    values: Vec3,

    fn toXYZ(self: *const @This()) ColorXYZ {
        const reference_white: [3]f32 = .{ 0.95047, 1.0, 1.08883 };
        
        const fy: f32 = (self.values[0] + 16.0) / 116.0;
        const fx: f32 = self.values[1] / 500.0 + fy;
        const fz: f32 = fy - self.values[2] / 200.0;
        
        const xr: f32 = if (fx > 0.206897) fx * fx * fx else (116.0 * fx - 16.0) / 903.3;
        const yr: f32 = if (self.values[0] > 7.9996) fy * fy * fy else self.values[0] / 903.3;
        const zr: f32 = if (fz > 0.206897) fz * fz * fz else (116.0 * fz - 16.0) / 903.3;
        
        return .{
            .values = .{
                xr * reference_white[0],
                yr * reference_white[1],
                zr * reference_white[2],
            }
        };
    }

    fn negative(self: ColorLAB) ColorLAB {
        return .{ .values = .{
            100.0 - self.values[0],
            -self.values[1],
            -self.values[2],
        } };
    }

    // TODO: Get better function
    fn getBrightness(self: ColorLAB) f32 {
        return self.toXYZ().getBrightness();
    }

    fn dst(self: *const @This(), other: *const ColorLAB) f32 {
        const d: Vec3 = self.values - other.values;
        return @reduce(.Add, d * d) * 7.08856e-6;
    }
};

const expectEqualSlices = std.testing.expectEqualSlices;

test "color format conversions" {
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
    var failed: bool = false;
    //// TEST RGB -> OTHER
    // RGB -> HSL
    for (colors_rgb, 0..) |c_rgb, i| {
        const color_hsl: Color = c_rgb.toHSL();
        const a_vals: [3]f32 = color_hsl.values();
        const b_vals: [3]f32 = colors_hsl[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error RGB -> HSL at index: {}", .{ i });
            failed = true;
        };
    }
    // RGB -> XYZ
    for (colors_rgb, 0..) |c_rgb, i| {
        const color_xyz: Color = c_rgb.toXYZ();
        const a_vals: [3]f32 = color_xyz.values();
        const b_vals: [3]f32 = colors_xyz[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error RGB -> XYZ at index: {}", .{ i });
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
            std.debug.print("Error HSL -> RGB at index: {}", .{ i });
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
            std.debug.print("Error XYZ -> RGB at index: {}", .{ i });
            failed = true;
        };
    }
    // XYZ -> LAB
    for (colors_xyz, 0..) |c_xyz, i| {
        const color_lab: Color = c_xyz.toLAB();
        const a_vals: [3]f32 = color_lab.values();
        const b_vals: [3]f32 = colors_lab[i].values();
        expectEqualSlices(f32, &a_vals, &b_vals) catch {
            std.debug.print("Error XYZ -> LAB at index: {}", .{ i });
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
            std.debug.print("Error LAB -> XYZ at index: {}\n", .{ i });
            failed = true;
        };
    }
    try std.testing.expect(!failed);
}
