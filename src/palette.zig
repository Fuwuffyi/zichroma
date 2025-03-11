const std = @import("std");
const zigimg = @import("zigimg");
const color = @import("color.zig");

pub const Palette = struct {
    pub const Value = struct { clr: color.ColorHSL, weight: u32 };

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
            const clr_rgb: color.ColorRGB = color.ColorRGB{ .r = c.r, .g = c.g, .b = c.b };
            const key: u96 = @bitCast(clr_rgb);
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
            values[i] = .{
                .clr = @as(color.ColorRGB, @bitCast(entry.key_ptr.*)).toHSL(),
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
