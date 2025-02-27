const std = @import("std");
const image = @import("image.zig");

pub const Palette = struct {
    pub const PaletteValue = struct { clr: image.Color, weight: u32 };

    values: []const PaletteValue,

    pub fn init(allocator: *const std.mem.Allocator, img: *const image.Image) !@This() {
        // Create list of colors
        var colors_hashmap: std.AutoHashMap(u96, u32) = std.AutoHashMap(u96, u32).init(allocator.*);
        defer colors_hashmap.deinit();
        try colors_hashmap.ensureTotalCapacity(@as(u32, @intCast(img.colors.len)));
        // Loop over the image colors
        for (img.colors) |*clr| {
            // Convert rgba to bits and use it as key
            const key: u96 = @bitCast(clr.*);
            const gop = try colors_hashmap.getOrPut(key);
            // Increase weight for that color if existing
            if (!gop.found_existing) {
                gop.value_ptr.* = 1;
            } else {
                gop.value_ptr.* += 1;
            }
        }
        // Create new list to store the unique values
        var colors_list: std.ArrayList(PaletteValue) = std.ArrayList(PaletteValue).init(allocator.*);
        defer colors_list.deinit();
        try colors_list.ensureTotalCapacity(colors_hashmap.count());
        // Read weight values and create the list of unique colors
        var it = colors_hashmap.iterator();
        while (it.next()) |*entry| {
            const clr: image.Color = @bitCast(entry.key_ptr.*);
            colors_list.appendAssumeCapacity(.{ .clr = clr, .weight = entry.value_ptr.* });
        }
        // Create the palette
        return .{ .values = try colors_list.toOwnedSlice() };
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        allocator.*.free(self.values);
    }
};
