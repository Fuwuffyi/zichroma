const std = @import("std");
const color = @import("color.zig");
const image = @import("image.zig");

pub const Palette = struct {
    const PaletteValue = packed struct { clr: color.Color, weight: u32 };

    values: []const PaletteValue,

    pub fn init(allocator: *const std.mem.Allocator, img: *const image.Image) !@This() {
        // Create list of colors
        var colors: std.ArrayList(PaletteValue) = std.ArrayList(PaletteValue).init(allocator.*);
        defer colors.deinit();
        // Loop over the image colors
        for (img.colors) |*clr| blk: {
            // Check if color is in colors list
            for (colors.items) |*other| {
                if (clr.eql(&other.clr)) {
                    // If found increase the weight of that color
                    other.weight += 1;
                    break :blk;
                }
            }
            // If color not in list, add it
            try colors.append(.{ .clr = clr.*, .weight = 1 });
        }
        // Create the palette
        return .{ .values = try colors.toOwnedSlice() };
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        allocator.*.free(self.values);
    }
};
