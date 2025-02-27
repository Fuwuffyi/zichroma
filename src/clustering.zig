const std = @import("std");
const palette = @import("palette.zig");
const image = @import("image.zig");

var random_generator: std.Random.Xoshiro256 = std.Random.DefaultPrng.init(0);
const random: std.Random = random_generator.random();

pub fn kmeans(allocator: *const std.mem.Allocator, pal: *const palette.Palette, k: u32, iters: u32) ![]const image.Color {
    // Generate "random" centroids
    const centroids: []image.Color = try allocator.alloc(image.Color, k);
    for (centroids) |*centroid| {
        centroid.* = pal.values[random.int(usize) % pal.values.len].clr;
    }
    // Create array to store the cluster the color appartains to
    var appartains_to: []usize = try allocator.alloc(usize, pal.values.len);
    for (0..iters) |_| {
        for (centroids) |*col| {
            std.debug.print("\x1B[48;2;{};{};{}m     ", .{ @as(u32, @intFromFloat(col.r * 255)), @as(u32, @intFromFloat(col.g * 255)), @as(u32, @intFromFloat(col.b * 255)) });
        }
        std.debug.print("\n", .{});
        // Loop through palette
        for (pal.values, 0..) |*palette_value, palette_index| {
            // Calculate closest centroid
            var best_index: usize = undefined;
            var lowest_distance: f32 = std.math.floatMax(f32);
            for (centroids, 0..) |*centroid, centroid_index| {
                const distance: f32 = @as(f32, @floatFromInt(palette_value.weight)) * (std.math.pow(f32, palette_value.clr.r - centroid.r, 2) + std.math.pow(f32, palette_value.clr.g - centroid.g, 2) + std.math.pow(f32, palette_value.clr.b - centroid.b, 2) + std.math.pow(f32, palette_value.clr.a - centroid.a, 2));
                if (distance < lowest_distance) {
                    lowest_distance = distance;
                    best_index = centroid_index;
                }
            }
            // Set color to appartain to that closest centroid
            appartains_to[palette_index] = best_index;
        }
        // Calculate average of the colors of a given centroid
        for (centroids, 0..) |*centroid, centroid_index| {
            var cnt: f32 = 0;
            var sum: image.Color = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
            for (appartains_to, 0..) |appartains_val, appartains_idx| {
                if (appartains_val != centroid_index) continue;
                const val: *const palette.Palette.PaletteValue = &pal.values[appartains_idx];
                sum.r += val.clr.r * @as(f32, @floatFromInt(val.weight));
                sum.g += val.clr.g * @as(f32, @floatFromInt(val.weight));
                sum.b += val.clr.b * @as(f32, @floatFromInt(val.weight));
                sum.a += val.clr.a * @as(f32, @floatFromInt(val.weight));
                cnt += @as(f32, @floatFromInt(val.weight));
            }
            centroid.r = sum.r / cnt;
            centroid.g = sum.g / cnt;
            centroid.b = sum.b / cnt;
            centroid.a = sum.a / cnt;
        }
    }
    return centroids;
}
