const std = @import("std");
const palette = @import("palette.zig");
const color = @import("color/color.zig");
const logError = @import("error.zig").logError;

const iter_threshold: comptime_float = 1e-6;

pub fn kmeans(allocator: std.mem.Allocator, pal: *const palette.Palette, k: u32, iters: u32) ![]color.Color {
    // Error checking
    const k_usize: usize = @intCast(k);
    if (pal.values.len == 0) return logError(error.EmptyPalette, .{});
    if (k_usize == 0 or k_usize > pal.values.len) return logError(error.InvalidK, .{});
    // Generate "random" centroids
    const centroids: []color.Color = try allocator.alloc(color.Color, k_usize);
    errdefer allocator.free(centroids);
    // Initialize first centroid using frequency
    centroids[0] = pal.values[0].clr;
    for (centroids[1..], 1..) |*centroid, idx| {
        // Initialize other centroids as furthest color in palette compared to initialized centroids
        var best_score: f32 = 0;
        var best_color: *const color.Color = undefined;
        for (pal.values) |*val| {
            var min_dst: f32 = std.math.floatMax(f32);
            for (centroids[0..idx]) |*other| {
                min_dst = @min(min_dst, other.dst(&val.clr));
            }
            if (min_dst < 1e-5) continue;
            const score = min_dst * @as(f32, @floatFromInt(val.weight));
            if (score > best_score) {
                best_score = score;
                best_color = &val.clr;
            }
        }
        centroid.* = best_color.*;
    }
    // Preallocate accumulators
    var sum_a: []f32 = try allocator.alloc(f32, k_usize);
    defer allocator.free(sum_a);
    var sum_b: []f32 = try allocator.alloc(f32, k_usize);
    defer allocator.free(sum_b);
    var sum_c: []f32 = try allocator.alloc(f32, k_usize);
    defer allocator.free(sum_c);
    var total_weight: []f32 = try allocator.alloc(f32, k_usize);
    defer allocator.free(total_weight);
    // Create array to store the cluster the color appartains to
    for (0..iters) |_| {
        // Reset accumulators
        @memset(sum_a, 0.0);
        @memset(sum_b, 0.0);
        @memset(sum_c, 0.0);
        @memset(total_weight, 0.0);
        // Loop through palette
        for (pal.values) |value| {
            // Update cluster values based on closest one to cluster center
            var best_idx: usize = 0;
            var min_dist: f32 = std.math.floatMax(f32);
            const weight: f32 = @as(f32, @floatFromInt(value.weight));
            for (centroids, 0..) |*centroid, idx| {
                const dist_sq: f32 = value.clr.dst(centroid);
                if (dist_sq < min_dist) {
                    min_dist = dist_sq;
                    best_idx = idx;
                }
            }
            // Increase accumulators
            sum_a[best_idx] += value.clr.values[0] * weight;
            sum_b[best_idx] += value.clr.values[1] * weight;
            sum_c[best_idx] += value.clr.values[2] * weight;
            total_weight[best_idx] += weight;
        }
        // Update centroids
        var threshold_exit: bool = true;
        for (centroids, 0..) |*centroid, i| {
            const tw: f32 = total_weight[i];
            if (tw == 0) continue;
            const new_vals: [3]f32 = .{
                sum_a[i] / tw,
                sum_b[i] / tw,
                sum_c[i] / tw,
            };
            const old_col: color.Color = centroid.*;
            centroid.values = new_vals;
            // Check for threshold for early exit
            if (old_col.dst(centroid) > iter_threshold) {
                threshold_exit = false;
            }
        }
        // Early exit when threshold met
        if (threshold_exit) {
            break;
        }
    }
    return centroids;
}
