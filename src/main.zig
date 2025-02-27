const std = @import("std");
const image = @import("image.zig");
const palette = @import("palette.zig");
const clustering = @import("clustering.zig");

pub fn main() !void {
    // Create an allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // Load the image
    std.debug.print("Loading image...\n", .{});
    const img: image.Image = try image.Image.init(&allocator, "testing.png");
    defer img.deinit(&allocator);
    // Create the weighted palette from the image
    std.debug.print("Loading palette...\n", .{});
    const pal: palette.Palette = try palette.Palette.init(&allocator, &img);
    defer pal.deinit(&allocator);
    // Get clustering data
    std.debug.print("Generating clusters...\n", .{});
    const clusters: []const image.Color = try clustering.kmeans(&allocator, &pal);
    defer allocator.free(clusters);
    // Do stuff
    for (clusters) |*col| {
        std.debug.print("\x1B[48;2;{};{};{}m     ", .{ @as(u32, @intFromFloat(col.r * 255)), @as(u32, @intFromFloat(col.g * 255)), @as(u32, @intFromFloat(col.b * 255)) });
    }
    std.debug.print("\n", .{});
}
