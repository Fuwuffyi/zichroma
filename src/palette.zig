const std = @import("std");
const zigimg = @import("zigimg");
const color_rgb = @import("color/color_rgb.zig");
const color = @import("color/color.zig");
const logError = @import("error.zig").logError;

pub const Palette = struct {
    pub const Value = struct { clr: color.Color, weight: f32 };

    name: []const u8,
    values: []Value,

    pub fn init(allocator: std.mem.Allocator, filepath: []const u8, colorspace: color.ColorSpace) !@This() {
        // Load the image file
        var loaded_image = zigimg.Image.fromFilePath(allocator, filepath) catch return logError(error.FileOpenError, .{filepath});
        defer loaded_image.deinit();
        // Initialize hashmap to count color frequencies
        var colors_hashmap: std.AutoHashMap(u32, f32) = std.AutoHashMap(u32, f32).init(allocator);
        defer colors_hashmap.deinit();
        try colors_hashmap.ensureTotalCapacity(@as(u32, @intCast(loaded_image.width * loaded_image.height)));
        // Loop over the image's pixels and count the occurrences of each color
        var color_iterator = loaded_image.iterator();
        while (color_iterator.next()) |*c| {
            // Extract f32 components and convert their bit patterns to u8
            const r = @as(u8, @intFromFloat(c.r * 255.0 + 0.5));
            const g = @as(u8, @intFromFloat(c.g * 255.0 + 0.5));
            const b = @as(u8, @intFromFloat(c.b * 255.0 + 0.5));
            // Pack into a u32 key (3 u8s = 3 bytes)
            const key: u32 = (@as(u32, r) << 16) | (@as(u32, g) << 8) | b;
            const gop = try colors_hashmap.getOrPut(key);
            if (gop.found_existing) {
                gop.value_ptr.* += 1.0;
            } else {
                gop.value_ptr.* = 1.0;
            }
        }
        // Directly allocate the result slice with precise sizing
        const values: []Value = try allocator.alloc(Value, colors_hashmap.count());
        // Populate the array directly using iterator
        var it = colors_hashmap.iterator();
        var i: usize = 0;
        while (it.next()) |entry| : (i += 1) {
            const key = entry.key_ptr.*;
            // Extract RGB components
            const r: f32 = @as(f32, @floatFromInt(@as(u8, @truncate(key >> 16)))) / 255.0;
            const g: f32 = @as(f32, @floatFromInt(@as(u8, @truncate(key >> 8)))) / 255.0;
            const b: f32 = @as(f32, @floatFromInt(@as(u8, @truncate(key)))) / 255.0;
            // Save to lab
            const clr_rgb: color.Color = color.Color.init(.rgb, .{ r, g, b });
            values[i] = .{ .clr = clr_rgb.convertTo(colorspace), .weight = entry.value_ptr.* };
        }
        // Sort colors by highest weight first
        std.mem.sort(Value, values, {}, struct {
            fn lessThan(_: void, a: Value, b: Value) bool {
                return a.weight > b.weight;
            }
        }.lessThan);
        // Normalize weights based on max weight
        max_weight_normalization(values);
        // Return new palette
        return .{ .name = std.fs.path.basename(filepath), .values = values };
    }

    fn max_weight_normalization(values: []Value) void {
        const max: f32 = values[0].weight;
        for (values) |*value| value.weight /= max;
    }

    pub fn map_weights_exponential(self: *@This(), alpha: f32) void {
        if (alpha == 0.0) return;
        for (self.values) |*value| value.*.weight = (1 - @exp(-alpha * value.weight)) / (1 - @exp(-alpha));
    }

    pub fn deinit(self: *const @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.values);
    }

    pub fn isLight(self: *const @This()) bool {
        var total: f32 = 0.0;
        var weight_sum: f32 = 0.0;
        for (self.values) |val| {
            total += val.clr.brightness() * val.weight;
            weight_sum += val.weight;
        }
        return total / weight_sum > 0.5;
    }
};
