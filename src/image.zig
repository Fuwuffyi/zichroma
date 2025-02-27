const std = @import("std");
const zigimg = @import("zigimg");
const pixel = @import("pixel.zig");

pub const Image = struct {
    colors: [][]pixel.Pixel,
    width: u32,
    height: u32,

    pub fn init(allocator: *const std.mem.Allocator, filepath: []const u8) !@This() {
        // Open the image file
        var file: std.fs.File = try std.fs.cwd().openFile(filepath, .{});
        defer file.close();
        // Load the image file through zigimg
        var loaded_image = try zigimg.Image.fromFile(allocator.*, &file);
        defer loaded_image.deinit();
        // Create the new image
        var image: Image = .{ .colors = undefined, .width = @intCast(loaded_image.width), .height = @intCast(loaded_image.height) };
        image.colors = try allocator.alloc([]pixel.Pixel, image.width);
        for (image.colors) |*color_row| {
            color_row.* = try allocator.alloc(pixel.Pixel, image.height);
        }
        // Get the image colors
        var color_iterator = loaded_image.iterator();
        var counter: usize = 0;
        while (color_iterator.next()) |*color| : (counter += 1) {
            const col_idx: usize = counter % image.width;
            const row_idx: usize = counter / image.width;
            image.colors[row_idx][col_idx] = .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
        }
        // Return the new struct
        return image;
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        defer allocator.free(self.colors);
        for (self.colors) |*color_row| {
            allocator.free(color_row.*);
        }
    }
};
