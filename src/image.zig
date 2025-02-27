const std = @import("std");
const zigimg = @import("zigimg");

pub const Color = packed struct { r: f32, g: f32, b: f32, a: f32 };

pub const Image = struct {
    colors: []Color,
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
        var image: Image = .{ .colors = try allocator.alloc(Color, loaded_image.width * loaded_image.height), .width = @intCast(loaded_image.width), .height = @intCast(loaded_image.height) };
        // Get the image colors
        var color_iterator = loaded_image.iterator();
        var counter: usize = 0;
        while (color_iterator.next()) |*c| : (counter += 1) {
            image.colors[counter] = .{ .r = c.r, .g = c.g, .b = c.b, .a = c.a };
        }
        // Return the new struct
        return image;
    }

    pub fn deinit(self: *const @This(), allocator: *const std.mem.Allocator) void {
        allocator.free(self.colors);
    }
};
