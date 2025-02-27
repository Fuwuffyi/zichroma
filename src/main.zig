const std = @import("std");
const image = @import("image.zig");
const palette = @import("palette.zig");
const color = @import("color.zig");

pub fn main() !void {
    // Create an allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // Load the image
    const img: image.Image = try image.Image.init(&allocator, "testing.png");
    defer img.deinit(&allocator);
    // Create the weighted palette from the image
    const pal: palette.Palette = try palette.Palette.init(&allocator, &img);
    defer pal.deinit(&allocator);
    // Do stuff
    for (pal.values) |*value| {
        const w: u32 = value.weight;
        const col: *const color.Color = &value.clr;
        std.debug.print("{} {} {} {} {}\n", .{ col.r, col.g, col.b, col.a, w });
    }
}
