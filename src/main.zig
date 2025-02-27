const std = @import("std");
const image = @import("image.zig");

pub fn main() !void {
    // Create an allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // Load the image
    const img: image.Image = try image.Image.init(&allocator, "testing.png");
    defer img.deinit(&allocator);
    // Do stuff
    std.debug.print("{} {}\n", .{ img.width, img.height });
    for (img.colors) |*row| {
        for (row.*) |*col| {
            std.debug.print("{} {} {} {}\n", .{ col.r, col.g, col.b, col.a });
        }
    }
}
