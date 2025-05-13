const std = @import("std");
const palette = @import("../palette.zig");
const color = @import("../color/color.zig");
const vecutil = @import("../color/vector.zig");
const o = @import("../util/octree.zig");

pub fn octree(allocator: std.mem.Allocator, colors: []palette.ImgValue, k: u32) ![]palette.ImgValue {
    // Create an octree
    var tree: o.Octree(palette.ImgValue) = try o.Octree(palette.ImgValue).init(allocator, 6, 4);
    defer tree.deinit();
    // Create a bit extraction function
    const bitExtractionFunction: o.Octree(palette.ImgValue).ExtractBitFn = struct {
        fn extractFn(value: palette.ImgValue, depth: usize) u3 {
            const vec: vecutil.Vec3 = value.clr.values;
            const ux: u32 = @as(u32, @bitCast(vec[0])) ^ 0x8000_0000;
            const uy: u32 = @as(u32, @bitCast(vec[1])) ^ 0x8000_0000;
            const uz: u32 = @as(u32, @bitCast(vec[2])) ^ 0x8000_0000;
            const shift: u32 = @intCast(31 - depth);
            const bx = (ux >> @intCast(shift)) & 1;
            const by = (uy >> @intCast(shift)) & 1;
            const bz = (uz >> @intCast(shift)) & 1;
            return @intCast((bx << 2) | (by << 1) | bz);
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
    }
    // Merge colors until K colors remain
    while (tree.len > k) {
        try tree.merge(valueMergeFunction);
        std.debug.print("Test: {}\n", .{ tree.len });
    }
    return try tree.values();
}
