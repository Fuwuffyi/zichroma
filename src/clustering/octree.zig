const std = @import("std");
const palette = @import("../palette.zig");
const color = @import("../color/color.zig");
const o = @import("../util/octree.zig");

pub fn octree(allocator: std.mem.Allocator, colors: []palette.ImgValue, k: u32) []palette.ImgValue {
    var tree: o.Octree(palette.ImgValue) = o.Octree(palette.ImgValue).init(allocator);
    defer tree.deinit();
    _ = k;
    // TODO: Implement this method lmao
    return colors;
}
