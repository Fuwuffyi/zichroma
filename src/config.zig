const std = @import("std");
const builtin = @import("builtin");
const color = @import("color.zig");
const modulation_curve = @import("modulation_curve.zig");

pub const Config = struct {
    const Template = struct {
        template_in: []const u8,
        config_out: []const u8,
        post_cmd: ?[]const u8,
    };

    cluster_count: u32,
    color_space: color.ColorSpace,
    profile: []const u8,
    theme: enum { auto, dark, light },
    profiles: std.StringHashMap(modulation_curve.ModulationCurve),
    templates: std.StringHashMap(Template),

    pub fn init(allocator: std.mem.Allocator) !@This() {
        // Grab the configuration file
        const file = try findConfigFile(allocator) orelse return error.ConfigFileNotFound;
        defer file.close();
        // Read the contents of the configuration file
        const file_contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(file_contents);
        // Temporairly print to console
        std.debug.print("{s}\n", .{file_contents});
        return undefined;
    }
};

const config_file_name: []const u8 = "config.conf";
const config_dir_name: []const u8 = "zig_colortheme_generator";

fn findConfigFile(allocator: std.mem.Allocator) !?std.fs.File {
    const config_dir: []const u8 = try getConfigDir(allocator);
    defer allocator.free(config_dir);
    // Check config directory first
    if (try openFileInDir(allocator, config_dir, config_file_name)) |file| return file;
    // Otherwise check exe directory
    const exe_dir: []const u8 = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_dir);
    return try openFileInDir(allocator, exe_dir, config_file_name);
}

fn openFileInDir(allocator: std.mem.Allocator, dir_path: []const u8, filename: []const u8) !?std.fs.File {
    const full_path: []const u8 = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, filename });
    defer allocator.free(full_path);
    return std.fs.openFileAbsolute(full_path, .{}) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
}

// TODO: Add other os specific config directories
fn getConfigDir(allocator: std.mem.Allocator) ![]const u8 {
    switch (builtin.target.os.tag) {
        .linux => {
            // Check XDG_CONFIG_HOME first
            const xdg_config_dir: []const u8 = std.process.getEnvVarOwned(allocator, "XDG_CONFIG_HOME") catch |err| {
                if (err != error.EnvironmentVariableNotFound) return err;
                // Else check HOME variable
                const home_dir: []const u8 = try std.process.getEnvVarOwned(allocator, "HOME");
                defer allocator.free(home_dir);
                return try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".config", config_dir_name});
            };
            defer allocator.free(xdg_config_dir);
            return try std.fs.path.join(allocator, &[_][]const u8{ xdg_config_dir, config_dir_name});
        },
        else => unreachable
    }
}
