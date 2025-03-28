const std = @import("std");
const config = @import("config.zig");
const cache = @import("cache.zig");
const color = @import("color.zig");
const palette = @import("palette.zig");
const clustering = @import("clustering.zig");
const modulation_curve = @import("modulation_curve.zig");
const template = @import("template.zig");

// TODO: Implement fuzz to ensure that similar colors get merged before the clustering begins
// TODO: Improve kmeans clustering through k-means++ initialization
// TODO: Add more clustering functions

pub fn main() !void {
    // Create an allocator
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator: std.mem.Allocator = gpa.allocator();
    // Read config file
    var conf: config.Config = try config.Config.init(allocator);
    defer conf.deinit(allocator);
    // Read command arguments
    const argv: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    // Create the weighted palette from the image or load the cache
    const pal: palette.Palette = try cache.readPaletteCache(allocator, argv[1]) orelse try palette.Palette.init(allocator, argv[1]);
    defer pal.deinit(allocator);
    try cache.writePaletteCache(allocator, &pal);
    // Check if image is light or dark themed
    const is_palette_light: bool = if (conf.theme == .light) true else if (conf.theme == .dark) false else pal.isLight();
    std.debug.print("Image is in {s} theme\n", .{if (is_palette_light) "light" else "dark"});
    // Get clustering data
    const clusters: []color.Color = try clustering.kmeans(allocator, &pal, conf.cluster_count, 50);
    defer allocator.free(clusters);
    // Sort based on color theme
    const sort_ctx = struct { light_mode: bool };
    // Sort clusters
    std.sort.block(color.Color, clusters, sort_ctx{ .light_mode = is_palette_light }, struct {
        pub fn lessThan(ctx: sort_ctx, a: color.Color, b: color.Color) bool {
            return if (ctx.light_mode) a.getBrightness() > b.getBrightness() else a.getBrightness() < b.getBrightness();
        }
    }.lessThan);
    // Create the modulation curve for accent colors
    const color_curve: *modulation_curve.ModulationCurve = conf.profiles.getPtr(conf.profile) orelse return error.ProfileNotFound;
    // TODO: Invert curve if light theme
    // Create template colors
    const template_colors: []const template.TemplateValue = try createColorsFromClusters(clusters, color_curve, is_palette_light, allocator);
    defer allocator.free(template_colors);
    defer for (template_colors) |*col| {
        allocator.free(col.accent_colors);
    };
}

fn createColorsFromClusters(clusters: []const color.Color, color_curve: *const modulation_curve.ModulationCurve, light_theme: bool, allocator: std.mem.Allocator) ![]const template.TemplateValue {
    const template_colors: []template.TemplateValue = try allocator.alloc(template.TemplateValue, clusters.len);
    for (clusters, 0..) |*col, i| {
        template_colors[i].primary_color = col.toRGB();
        template_colors[i].accent_colors = try color_curve.applyCurve(allocator, col);
        // TODO: Improve negative color gen
        var col_neg_hsl: color.Color = col.negative().toHSL();
        col_neg_hsl.hsl.s = 0.1;
        col_neg_hsl.hsl.l = if (light_theme) 0.01 else 0.99;
        template_colors[i].text_color = col_neg_hsl.toRGB();
    }
    return template_colors;
}

//std.debug.print("\x1B[48;2;{};{};{}m     \x1B[0m", .{ @as(u32, @intFromFloat(col_acc_rgb.rgb.r * 255)), @as(u32, @intFromFloat(col_acc_rgb.rgb.g * 255)), @as(u32, @intFromFloat(col_acc_rgb.rgb.b * 255)) });
