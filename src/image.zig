const std = @import("std");
const zigimg = @import("zigimg");

pub const Color = packed struct { r: f32, g: f32, b: f32 };

pub const Image = struct {
    colors: []Color,
    width: u32,
    height: u32,

    pub fn init(allocator: *const std.mem.Allocator, filepath: []const u8) !@This() {
        // Load the image file through zigimg
        var loaded_image = try zigimg.Image.fromFilePath(allocator.*, filepath);
        defer loaded_image.deinit();
        // Get image data
        const width: u32 = @intCast(loaded_image.width);
        const height: u32 = @intCast(loaded_image.height);
        const len: usize = width * height;
        // Create the new image
        var image: Image = .{ .colors = try allocator.alloc(Color, len), .width = width, .height = height };
        // Get the image colors
        var color_iterator = loaded_image.iterator();
        var counter: usize = 0;
        while (color_iterator.next()) |*c| : (counter += 1) {
            image.colors[counter] = .{
                .r = c.r,
                .g = c.g,
                .b = c.b,
            };
        }
        // Return the new struct
        return image;
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        allocator.free(self.colors);
    }
};
