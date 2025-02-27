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
    std.debug.print("Loading image...\n", .{});
    const img: image.Image = try image.Image.init(&allocator, "testing.png");
    defer img.deinit(&allocator);
    // Create the weighted palette from the image
    std.debug.print("Loading palette...\n", .{});
    const pal: palette.Palette = try palette.Palette.init(&allocator, &img);
    defer pal.deinit(&allocator);
    // Do stuff
    for (pal.values) |*value| {
        const col: *const color.Color = &value.clr;
        std.debug.print("\x1B[48;2;{};{};{}m     \x1B[0mInstances: {}\n", .{ @as(u32, @intFromFloat(col.r * 255)), @as(u32, @intFromFloat(col.g * 255)), @as(u32, @intFromFloat(col.b * 255)), value.weight });
    }
}
