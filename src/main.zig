const std = @import("std");
const config = @import("config.zig");
const color = @import("color.zig");
const image = @import("image.zig");
const palette = @import("palette.zig");
const clustering = @import("clustering.zig");
const modulation_curve = @import("modulation_curve.zig");

// TODO: Cache the palette values to external file to not do this every program execution
// TODO: Implement fuzz to ensure that similar colors get merged before the clustering begins
// TODO: Improve kmeans clustering through k-means++ initialization and threshold checking
// TODO: Add more clustering functions

pub fn main() !void {
    // Create an allocator
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator: std.mem.Allocator = gpa.allocator();
    // Read command arguments
    const argv: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    const conf: config.Config = try config.Config.init(allocator, argv);
    defer conf.deinit(allocator);
    // Load the image
    std.debug.print("Loading image...\n", .{});
    var start: i64 = std.time.milliTimestamp();
    const img: image.Image = try image.Image.init(allocator, conf.image_path);
    defer img.deinit(allocator);
    var stop: i64 = std.time.milliTimestamp();
    std.debug.print("Loading image took {}ms \n", .{stop - start});
    // Create the weighted palette from the image
    std.debug.print("Loading palette...\n", .{});
    start = std.time.milliTimestamp();
    const pal: palette.Palette = try palette.Palette.init(allocator, &img);
    defer pal.deinit(allocator);
    stop = std.time.milliTimestamp();
    std.debug.print("Loading palette took {}ms \n", .{stop - start});
    // Check if image is light or dark themed
    const is_palette_light: bool = if (conf.light_mode != null) conf.light_mode.? else pal.is_light();
    std.debug.print("Image is in {s} theme\n", .{if (is_palette_light) "light" else "dark"});
    // Get clustering data
    std.debug.print("Generating clusters...\n", .{});
    start = std.time.milliTimestamp();
    const clusters: []color.ColorHSL = try clustering.kmeans(allocator, &pal, 4, 50);
    defer allocator.free(clusters);
    stop = std.time.milliTimestamp();
    std.debug.print("Generating clusters took {}ms \n", .{stop - start});

    // TODO: Sort clusters based on image brightness
    const curve: [2]modulation_curve.ModulationValue = .{ .{ .h_mod = 0, .s_mod = 0.9, .l_mod = 0.8 }, .{ .h_mod = 0, .s_mod = 0.8, .l_mod = 0.5 } };
    const test_curve: modulation_curve.ModulationCurve = modulation_curve.ModulationCurve.init(&curve);

    // Do stuff
    for (clusters) |*col| {
        // Primary color
        const col_rgb: color.ColorRGB = col.toRGB();
        std.debug.print("\x1B[48;2;{};{};{}m     \x1B[0m", .{ @as(u32, @intFromFloat(col_rgb.r * 255)), @as(u32, @intFromFloat(col_rgb.g * 255)), @as(u32, @intFromFloat(col_rgb.b * 255)) });
        // Accent colors
        const new_cols: []color.ColorHSL = test_curve.applyCurve(allocator, col);
        defer allocator.free(new_cols);
        for (new_cols) |*col_acc| {
            const col_acc_rgb: color.ColorRGB = col_acc.toRGB();
            std.debug.print("\x1B[48;2;{};{};{}m     \x1B[0m", .{ @as(u32, @intFromFloat(col_acc_rgb.r * 255)), @as(u32, @intFromFloat(col_acc_rgb.g * 255)), @as(u32, @intFromFloat(col_acc_rgb.b * 255)) });
        }
        // Text color
        var col_neg: color.ColorHSL = col.negative();
        col_neg.h = 0.1;
        const col_neg_rgb: color.ColorRGB = col_neg.modulate(0.0, 1.0, 1.88).toRGB();
        std.debug.print("\x1B[48;2;{};{};{}m     \x1B[0m\n", .{ @as(u32, @intFromFloat(col_neg_rgb.r * 255)), @as(u32, @intFromFloat(col_neg_rgb.g * 255)), @as(u32, @intFromFloat(col_neg_rgb.b * 255)) });
    }
    std.debug.print("\n", .{});
}
