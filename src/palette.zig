const std = @import("std");
const image = @import("image.zig");
const color = @import("color.zig");

pub const Palette = struct {
    pub const Value = struct { clr: color.ColorHSL, weight: u32 };

    values: []const Value,

    pub fn init(allocator: std.mem.Allocator, img: *const image.Image) !@This() {
        // Create list of colors
        var colors_hashmap: std.AutoHashMap(u96, u32) = std.AutoHashMap(u96, u32).init(allocator);
        defer colors_hashmap.deinit();
        try colors_hashmap.ensureTotalCapacity(@as(u32, @intCast(img.colors.len)));
        // Loop over the image colors
        for (img.colors) |clr| {
            // Convert rgba to bits and use it as key
            const key: u96 = @bitCast(clr);
            const gop = try colors_hashmap.getOrPut(key);
            // Increase weight for that color if existing
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

    pub fn is_light(self: *const @This()) bool {
        var total: f32 = 0.0;
        var weight_sum: f32 = 0.0;
        for (self.values) |val| {
            total += val.clr.l * @as(f32, @floatFromInt(val.weight));
            weight_sum += @floatFromInt(val.weight);
        }
        return total / weight_sum > 0.5;
    }
};
