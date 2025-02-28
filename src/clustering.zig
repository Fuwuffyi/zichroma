const std = @import("std");
const palette = @import("palette.zig");
const image = @import("image.zig");
const color = @import("color.zig");

const ClusteringError = error{
    EmptyPalette,
    InvalidK,
};

var random_generator: std.Random.Xoshiro256 = std.Random.DefaultPrng.init(0);
const random: std.Random = random_generator.random();

pub fn kmeans(allocator: *const std.mem.Allocator, pal: *const palette.Palette, k: u32, iters: u32) ![]const color.Color {
    // Error checking
    const k_usize: usize = @intCast(k);
    if (pal.values.len == 0) return error.EmptyPalette;
    if (k_usize == 0) return error.InvalidK;
    // Generate "random" centroids
    const centroids: []color.Color = try allocator.alloc(color.Color, k_usize);
    errdefer allocator.free(centroids);
    for (centroids) |*centroid| {
        centroid.* = pal.values[random.int(usize) % pal.values.len].clr;
    }
    // Preallocate accumulators
    var sum_r: []f32 = try allocator.alloc(f32, k_usize);
    defer allocator.free(sum_r);
    var sum_g: []f32 = try allocator.alloc(f32, k_usize);
    defer allocator.free(sum_g);
    var sum_b: []f32 = try allocator.alloc(f32, k_usize);
    defer allocator.free(sum_b);
    var total_weight: []f32 = try allocator.alloc(f32, k_usize);
    defer allocator.free(total_weight);
    // Create array to store the cluster the color appartains to
    for (0..iters) |_| {
        // Reset accumulators
        @memset(sum_r, 0.0);
        @memset(sum_g, 0.0);
        @memset(sum_b, 0.0);
        @memset(total_weight, 0.0);
        // Loop through palette
        for (pal.values) |value| {
            // Update cluster values based on closest one to cluster center
            var best_idx: usize = 0;
            var min_dist: f32 = std.math.floatMax(f32);
            const weight: f32 = @as(f32, @floatFromInt(value.weight));
            for (centroids, 0..) |*centroid, idx| {
                const dist_sq: f32 = value.clr.dst_squared_redman(centroid);
                const weighted_dist: f32 = weight * dist_sq;
                if (weighted_dist < min_dist) {
                    min_dist = weighted_dist;
                    best_idx = idx;
                }
            }
            // Increase accumulators
            sum_r[best_idx] += value.clr.r * weight;
            sum_g[best_idx] += value.clr.g * weight;
            sum_b[best_idx] += value.clr.b * weight;
            total_weight[best_idx] += weight;
        }
        // Update centroids
        for (centroids, 0..) |*centroid, i| {
            const tw: f32 = total_weight[i];
            if (tw == 0) continue;
            centroid.r = sum_r[i] / tw;
            centroid.g = sum_g[i] / tw;
            centroid.b = sum_b[i] / tw;
        }
    }
    return centroids;
}
