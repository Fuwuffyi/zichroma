const std = @import("std");
const color = @import("color.zig");
const image = @import("image.zig");

pub const Palette = struct {
    const PaletteValue = packed struct { clr: color.Color, weight: u32 };

    values: []const PaletteValue,

    pub fn init(allocator: *const std.mem.Allocator, img: *const image.Image) !@This() {
        // Create list of colors
        var colors_hashmap: std.AutoHashMap(u64, PaletteValue) = std.AutoHashMap(u64, PaletteValue).init(allocator.*);
        defer colors_hashmap.deinit();
        // Loop over the image colors
        for (img.colors) |*clr| {
            const hash: u64 = std.hash.Wyhash.hash(0, std.mem.asBytes(clr));
            const gop = try colors_hashmap.getOrPut(hash);
            if (!gop.found_existing) {
                gop.value_ptr.* = .{ .clr = clr.*, .weight = 1 };
            } else {
                gop.value_ptr.weight += 1;
            }
        }
        var colors_list = std.ArrayList(PaletteValue).init(allocator.*);
        defer colors_list.deinit();
        var it = colors_hashmap.iterator();
        while (it.next()) |*entry| {
            try colors_list.append(entry.value_ptr.*);
        }
        // Create the palette
        return .{ .values = try colors_list.toOwnedSlice() };
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        allocator.*.free(self.values);
    }
};
