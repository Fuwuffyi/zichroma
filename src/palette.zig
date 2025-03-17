const std = @import("std");
const zigimg = @import("zigimg");
const color = @import("color.zig");

pub const Palette = struct {
    pub const Value = struct { clr: color.Color, weight: u32 };

    values: []const Value,

    pub fn init(allocator: std.mem.Allocator, filepath: []const u8) !@This() {
        // Load the image file
        var loaded_image = try zigimg.Image.fromFilePath(allocator, filepath);
        defer loaded_image.deinit();
        // Initialize hashmap to count color frequencies
        var colors_hashmap: std.AutoHashMap(u96, u32) = std.AutoHashMap(u96, u32).init(allocator);
        defer colors_hashmap.deinit();
        try colors_hashmap.ensureTotalCapacity(@as(u32, @intCast(loaded_image.width * loaded_image.height)));
        // Loop over the image's pixels and count the occurrences of each color
        var color_iterator = loaded_image.iterator();
        while (color_iterator.next()) |*c| {
            // Extract f32 components and convert their bit patterns to u32
            const r_bits = @as(u32, @bitCast(c.r));
            const g_bits = @as(u32, @bitCast(c.g));
            const b_bits = @as(u32, @bitCast(c.b));
            // Pack into a u96 key (3 u32s = 12 bytes)
            const key: u96 = (@as(u96, r_bits) << 64) | (@as(u96, g_bits) << 32) | b_bits;
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
            // Unpack the u96 key back into f32 components
            const key: u96 = entry.key_ptr.*;
            const r: f32 = @as(f32, @bitCast(@as(u32, @truncate(key >> 64))));
            const g: f32 = @as(f32, @bitCast(@as(u32, @truncate((key >> 32) & 0xFFFFFFFF))));
            const b: f32 = @as(f32, @bitCast(@as(u32, @truncate(key & 0xFFFFFFFF))));
            // Recreate the color from the stuff in HSL
            const clr_rgb: color.Color = .{ .rgb = .{ .r = r, .g = g, .b = b } };
            values[i] = .{
                .clr = clr_rgb,
                .weight = entry.value_ptr.*,
            };
        }
        return .{ .values = values };
    }

    pub fn deinit(self: *const @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.values);
    }

    pub fn isLight(self: *const @This()) bool {
        var total: f32 = 0.0;
        var weight_sum: f32 = 0.0;
        for (self.values) |val| {
            total += val.clr.l * @as(f32, @floatFromInt(val.weight));
            weight_sum += @floatFromInt(val.weight);
        }
        return total / weight_sum > 0.5;
    }
};
