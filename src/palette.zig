const std = @import("std");
const zigimg = @import("zigimg");
const color = @import("color.zig");
const logError = @import("error.zig").logError;

pub const Palette = struct {
    pub const Value = struct { clr: color.Color, weight: u32 };

    name: []const u8,
    values: []const Value,

    pub fn init(allocator: std.mem.Allocator, filepath: []const u8, colorspace: color.ColorSpace) !@This() {
        // Load the image file
        var loaded_image = zigimg.Image.fromFilePath(allocator, filepath) catch return logError(error.FileOpenError, .{ filepath });
        defer loaded_image.deinit();
        // Initialize hashmap to count color frequencies
        var colors_hashmap: std.AutoHashMap(u32, u32) = std.AutoHashMap(u32, u32).init(allocator);
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
                gop.value_ptr.* += 1;
            } else {
                gop.value_ptr.* = 1;
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
            const clr_rgb: color.Color = .{ .rgb = .{ .values = .{ r, g, b } } };
            values[i] = .{ .clr = undefined, .weight = entry.value_ptr.* };
            values[i].clr = switch(colorspace) {
                .rgb => clr_rgb.toRGB(),
                .hsl => clr_rgb.toHSL(),
                .xyz => clr_rgb.toXYZ(),
                .lab => clr_rgb.toLAB(),
            };
        }
        // Sort colors by highest weight first
        std.mem.sort(Value, values, {}, struct {
            fn lessThan(_: void, a: Value, b: Value) bool {
                return a.weight > b.weight;
            }
        }.lessThan);
        // Return new palette
        return .{ .name = std.fs.path.basename(filepath), .values = values };
    }

    pub fn deinit(self: *const @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.values);
    }

    pub fn isLight(self: *const @This()) bool {
        var total: f32 = 0.0;
        var weight_sum: f32 = 0.0;
        for (self.values) |val| {
            total += val.clr.getBrightness() * @as(f32, @floatFromInt(val.weight));
            weight_sum += @as(f32, @floatFromInt(val.weight));
        }
        return total / weight_sum > 0.5;
    }
};
