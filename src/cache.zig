const std = @import("std");
const builtin = @import("builtin");

pub fn getCacheDir(allocator: std.mem.Allocator, app_name: []const u8) ![]const u8 {
    const cache_dir = switch (builtin.target.os.tag) {
        .linux => blk: {
            // Check $XDG_CACHE_HOME or fallback to $HOME/.cache
            const xdg_cache: []const u8 = std.process.getEnvVarOwned(allocator, "XDG_CACHE_HOME") catch |err| {
                if (err != error.EnvironmentVariableNotFound) return err;
                // Fallback to $HOME/.cache
                const home_dir: []const u8 = std.process.getEnvVarOwned(allocator, "HOME") catch |e| {
                    if (e == error.EnvironmentVariableNotFound) return error.MissingHomeDir;
                    return e;
                };
                defer allocator.free(home_dir);
                break :blk try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".cache", app_name });
            };
            defer allocator.free(xdg_cache);
            break :blk try std.fs.path.join(allocator, &[_][]const u8{ xdg_cache, app_name });
        },
        .windows => blk: {
            // Use %LOCALAPPDATA%
            const local_app_data: []u8 = std.process.getEnvVarOwned(allocator, "LOCALAPPDATA") catch |err| {
                if (err == error.EnvironmentVariableNotFound) return error.MissingLocalAppData;
                return err;
            };
            defer allocator.free(local_app_data);
            break :blk try std.fs.path.join(allocator, &[_][]const u8{ local_app_data, app_name, "Cache" });
        },
        .macos => blk: {
            // Use ~/Library/Caches
            const home_dir: []const u8 = std.process.getEnvVarOwned(allocator, "HOME") catch |err| {
                if (err == error.EnvironmentVariableNotFound) return error.MissingHomeDir;
                return err;
            };
            defer allocator.free(home_dir);
            break :blk try std.fs.path.join(allocator, &[_][]const u8{ home_dir, "Library", "Caches", app_name });
        },
        else => return error.UnsupportedOS,
    };
    // Create the directory if it doesn't exist
    std.fs.cwd().makePath(cache_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
    return cache_dir;
}
