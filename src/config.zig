const std = @import("std");

pub const Config = struct {
    image_path: []const u8,
    light_mode: ?bool,

    pub fn init(allocator: std.mem.Allocator, argv: [][:0]u8) !@This() {
        // Setup empty configuration
        var config: Config = undefined;
        config.light_mode = null;
        // Loop through command arguments
        for (argv[1..]) |arg| {
            if (std.mem.startsWith(u8, arg, "-image=")) {
                // Set the image file path to the one passed by cli
                config.image_path = try allocator.dupe(u8, arg["-image=".len..]);
            } else if (std.mem.startsWith(u8, arg, "-theme=")) {
                // Get the theme from cli
                const theme_str: []const u8 = try allocator.dupe(u8, arg["-theme=".len..]);
                defer allocator.free(theme_str);
                // Set the appropriate value based on theme
                if (std.mem.eql(u8, theme_str, "auto")) continue;
                if (std.mem.eql(u8, theme_str, "dark")) {
                    config.light_mode = false;
                } else if (std.mem.eql(u8, theme_str, "light")) {
                    config.light_mode = true;
                } else {
                    std.debug.print("Unknown theme: {s}\n", .{theme_str});
                    return error.InvalidColortheme;
                }
            } else {
                std.debug.print("Unknown argument: {s}\n", .{arg});
                return error.InvalidArgument;
            }
        }
        // Check if image is not set set
        if (std.mem.eql(u8, config.image_path, "")) {
            std.debug.print("Missing required argument: -image\n", .{});
            return error.MissingArgument;
        }
        return config;
    }

    pub fn deinit(self: *const @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.image_path);
    }
};
