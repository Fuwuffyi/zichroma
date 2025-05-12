const std = @import("std");
const palette = @import("../palette.zig");
const color = @import("../color/color.zig");
const vecutil = @import("../color/vector.zig");
const o = @import("../util/octree.zig");

pub fn octree(allocator: std.mem.Allocator, colors: []palette.ImgValue, k: u32) ![]palette.ImgValue {
    // Create an octree
    var tree: o.Octree(palette.ImgValue) = o.Octree(palette.ImgValue).init(allocator, 8);
    defer tree.deinit();
    // Create a bit extraction function
    const bitExtractionFunction: o.Octree(palette.ImgValue).ExtractBitFn = struct {
        fn extractFn(value: palette.ImgValue) u3 {
            const vals: vecutil.Vec3 = value.clr.values;
            return (@as(u3, @intFromBool(vals[0] > 0.5)) << 2) | (@as(u3, @intFromBool(vals[1] > 0.5)) << 1) | @as(u3, @intFromBool(vals[2] > 0.5));
        }
    }.extractFn;
    // Add all colors to the palette
    for (colors) |c| {
        try tree.insert(c, bitExtractionFunction);
    }
    _ = k;
    // TODO: Implement this method lmao
    return colors;
}
