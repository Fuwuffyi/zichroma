const std = @import("std");
const config = @import("config.zig");
const cache = @import("cache.zig");
const color = @import("color.zig");
const palette = @import("palette.zig");
const clustering = @import("clustering.zig");
const modulation_curve = @import("modulation_curve.zig");

// TODO: Implement fuzz to ensure that similar colors get merged before the clustering begins
// TODO: Improve kmeans clustering through k-means++ initialization
// TODO: Add more clustering functions

pub fn main() !void {
    // Create an allocator
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator: std.mem.Allocator = gpa.allocator();
    // Read command arguments
    const argv: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    // Read config file
    var conf: config.Config = try config.Config.init(allocator);
    defer conf.deinit(allocator);
    // Create the weighted palette from the image or load the cache
    // std.debug.print("Loading palette...\n", .{});
    // var start: i64 = std.time.milliTimestamp();
    // const pal: palette.Palette = try cache.readPaletteCache(allocator, conf.image_path) orelse try palette.Palette.init(allocator, conf.image_path);
    // defer pal.deinit(allocator);
    // try cache.writePaletteCache(allocator, &pal);
    // std.debug.print("Creating new palette took {}ms \n", .{std.time.milliTimestamp() - start});
    // // Check if image is light or dark themed
    // const is_palette_light: bool = if (conf.light_mode != null) conf.light_mode.? else pal.isLight();
    // std.debug.print("Image is in {s} theme\n", .{if (is_palette_light) "light" else "dark"});
    // // Get clustering data
    // std.debug.print("Generating clusters...\n", .{});
    // start = std.time.milliTimestamp();
    // const clusters: []color.Color = try clustering.kmeans(allocator, &pal, 4, 50);
    // defer allocator.free(clusters);
    // std.debug.print("Generating clusters took {}ms \n", .{std.time.milliTimestamp() - start});
    // // Sort based on color theme
    // const sort_ctx = struct { light_mode: bool };
    // std.sort.block(color.Color, clusters, sort_ctx{ .light_mode = is_palette_light }, struct {
    //     pub fn lessThan(ctx: sort_ctx, a: color.Color, b: color.Color) bool {
    //         return if (ctx.light_mode) a.getBrightness() > b.getBrightness() else a.getBrightness() < b.getBrightness();
    //     }
    // }.lessThan);
    // // Create the modulation curve for accent colors
    // const test_curve: modulation_curve.ModulationCurve = modulation_curve.ModulationCurve.init(.hsl, &.{
    //     .{ .a_mod = null, .b_mod = 0.98, .c_mod = 0.09 },
    //     .{ .a_mod = null, .b_mod = 0.94, .c_mod = 0.16 },
    //     .{ .a_mod = null, .b_mod = 0.90, .c_mod = 0.25 },
    //     .{ .a_mod = null, .b_mod = 0.82, .c_mod = 0.30 },
    //     .{ .a_mod = null, .b_mod = 0.67, .c_mod = 0.42 },
    //     .{ .a_mod = null, .b_mod = 0.68, .c_mod = 0.62 },
    //     .{ .a_mod = null, .b_mod = 0.76, .c_mod = 0.75 },
    //     .{ .a_mod = null, .b_mod = 0.92, .c_mod = 0.87 },
    // });
    // // Do stuff
    // for (clusters) |*col| {
    //     // Primary color
    //     const col_rgb: color.Color = col.toRGB();
    //     std.debug.print("\x1B[48;2;{};{};{}m     \x1B[0m", .{ @as(u32, @intFromFloat(col_rgb.rgb.r * 255)), @as(u32, @intFromFloat(col_rgb.rgb.g * 255)), @as(u32, @intFromFloat(col_rgb.rgb.b * 255)) });
    //     // Accent colors
    //     const new_cols: []color.Color = try test_curve.applyCurve(allocator, col);
    //     defer allocator.free(new_cols);
    //     std.sort.block(color.Color, new_cols, sort_ctx{ .light_mode = is_palette_light }, struct {
    //         pub fn lessThan(ctx: sort_ctx, a: color.Color, b: color.Color) bool {
    //             return if (ctx.light_mode) a.getBrightness() > b.getBrightness() else a.getBrightness() < b.getBrightness();
    //         }
    //     }.lessThan);
    //     for (new_cols) |*col_acc| {
    //         const col_acc_rgb: color.Color = col_acc.toRGB();
    //         std.debug.print("\x1B[48;2;{};{};{}m     \x1B[0m", .{ @as(u32, @intFromFloat(col_acc_rgb.rgb.r * 255)), @as(u32, @intFromFloat(col_acc_rgb.rgb.g * 255)), @as(u32, @intFromFloat(col_acc_rgb.rgb.b * 255)) });
    //     }
    //     // Text color
    //     var col_neg_hsl: color.Color = col.negative().toHSL();
    //     col_neg_hsl.hsl.s = 0.1;
    //     col_neg_hsl.hsl.l = if (is_palette_light) 0.01 else 0.99;
    //     const col_neg_rgb: color.Color = col_neg_hsl.toRGB();
    //     std.debug.print("\x1B[48;2;{};{};{}m     \x1B[0m\n", .{ @as(u32, @intFromFloat(col_neg_rgb.rgb.r * 255)), @as(u32, @intFromFloat(col_neg_rgb.rgb.g * 255)), @as(u32, @intFromFloat(col_neg_rgb.rgb.b * 255)) });
    // }
    // std.debug.print("\n", .{});
}
