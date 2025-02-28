const std = @import("std");
const color = @import("color.zig");
const image = @import("image.zig");
const palette = @import("palette.zig");
const clustering = @import("clustering.zig");

pub fn main() !void {
    // Create an allocator
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator: std.mem.Allocator = gpa.allocator();
    // Read command arguments
    const argv: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    // Get the file name
    if (argv.len < 2) {
        // No file name
        return error.FileNotFound;
    }
    const filename: [:0]const u8 = argv[1];
    // Load the image
    std.debug.print("Loading image...\n", .{});
    var start: i64 = std.time.milliTimestamp();
    const img: image.Image = try image.Image.init(&allocator, filename);
    defer img.deinit(&allocator);
    var stop: i64 = std.time.milliTimestamp();
    std.debug.print("Loading image took {}ms \n", .{stop - start});
    // Create the weighted palette from the image
    std.debug.print("Loading palette...\n", .{});
    start = std.time.milliTimestamp();
    const pal: palette.Palette = try palette.Palette.init(&allocator, &img);
    defer pal.deinit(&allocator);
    stop = std.time.milliTimestamp();
    std.debug.print("Loading palette took {}ms \n", .{stop - start});
    // Get clustering data
    std.debug.print("Generating clusters...\n", .{});
    start = std.time.milliTimestamp();
    const clusters: []const color.Color = try clustering.kmeans(&allocator, &pal, 4, 50);
    defer allocator.free(clusters);
    stop = std.time.milliTimestamp();
    std.debug.print("Generating clusters took {}ms \n", .{stop - start});
    // Do stuff
    for (clusters) |*col| {
        std.debug.print("\x1B[48;2;{};{};{}m     \x1B[0m", .{ @as(u32, @intFromFloat(col.r * 255)), @as(u32, @intFromFloat(col.g * 255)), @as(u32, @intFromFloat(col.b * 255)) });
    }
    std.debug.print("\n", .{});
}
