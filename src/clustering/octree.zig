const std = @import("std");
const palette = @import("../palette.zig");
const color = @import("../color/color.zig");
const vecutil = @import("../color/vector.zig");
const o = @import("../util/octree.zig");

pub fn octree(allocator: std.mem.Allocator, colors: []palette.ImgValue, k: u32) ![]palette.ImgValue {
    // Create an octree
    var tree: o.Octree(palette.ImgValue) = o.Octree(palette.ImgValue).init(allocator, 16);
    defer tree.deinit();
    // Create a bit extraction function
    const bitExtractionFunction: o.Octree(palette.ImgValue).ExtractBitFn = struct {
        fn extractFn(value: palette.ImgValue) u3 {
            const vals: vecutil.Vec3 = value.clr.values;
            return (@as(u3, @intFromBool(vals[0] > 0.5)) << 2) | (@as(u3, @intFromBool(vals[1] > 0.5)) << 1) | @as(u3, @intFromBool(vals[2] > 0.5));
        }
    }.extractFn;
    const valueMergeFunction: o.Octree(palette.ImgValue).MergeValueFn = struct {
        fn mergeFn(a: palette.ImgValue, b: palette.ImgValue) palette.ImgValue {
            const merge_weight: f32 = a.weight + b.weight;
            const a_weight_vec: vecutil.Vec3 = @splat(a.weight);
            const b_weight_vec: vecutil.Vec3 = @splat(b.weight);
            const merge_weight_vec: vecutil.Vec3 = @splat(merge_weight);
            const col_avg: color.Color = color.Color.init(a.clr.tag, (a.clr.values * a_weight_vec + b.clr.values * b_weight_vec) / merge_weight_vec);
            return .{ .clr = col_avg, .weight = merge_weight };
        }
    }.mergeFn;
    // Add all colors to the palette
    for (colors) |c| {
        try tree.insert(c, bitExtractionFunction);
        std.debug.print("Test: {}\n", .{ tree.count });
    }
    // Merge colors until K colors remain
    while (tree.count > k) {
        try tree.mergeSimilar(valueMergeFunction);
        std.debug.print("Test: {}\n", .{ tree.count });
    }
    return try tree.values();
}
