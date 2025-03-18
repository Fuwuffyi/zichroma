const std = @import("std");
const builtin = @import("builtin");
const palette = @import("palette.zig");
const color = @import("color.zig");

const cache_dir_name: []const u8 = "zig_colortheme_generator";

fn getCacheDir(allocator: std.mem.Allocator) ![]const u8 {
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
                break :blk try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".cache", cache_dir_name });
            };
            defer allocator.free(xdg_cache);
            break :blk try std.fs.path.join(allocator, &[_][]const u8{ xdg_cache, cache_dir_name });
        },
        .windows => blk: {
            // Use %LOCALAPPDATA%
            const local_app_data: []u8 = std.process.getEnvVarOwned(allocator, "LOCALAPPDATA") catch |err| {
                if (err == error.EnvironmentVariableNotFound) return error.MissingLocalAppData;
                return err;
            };
            defer allocator.free(local_app_data);
            break :blk try std.fs.path.join(allocator, &[_][]const u8{ local_app_data, cache_dir_name, "Cache" });
        },
        .macos => blk: {
            // Use ~/Library/Caches
            const home_dir: []const u8 = std.process.getEnvVarOwned(allocator, "HOME") catch |err| {
                if (err == error.EnvironmentVariableNotFound) return error.MissingHomeDir;
                return err;
            };
            defer allocator.free(home_dir);
            break :blk try std.fs.path.join(allocator, &[_][]const u8{ home_dir, "Library", "Caches", cache_dir_name });
        },
        else => return error.UnsupportedOS,
    };
    // Create the directory if it doesn't exist
    std.fs.cwd().makePath(cache_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
    return cache_dir;
}

pub fn writePaletteCache(allocator: std.mem.Allocator, pal: *const palette.Palette) !void {
    // Get the combined file path (cache_dir/pal.name.bin)
    const cache_dir: []const u8 = try getCacheDir(allocator);
    defer allocator.free(cache_dir);
    const file_name: []const u8 = try std.fmt.allocPrint(allocator, "{s}.bin", .{pal.name});
    defer allocator.free(file_name);
    const cache_file: []const u8 = try std.fs.path.join(allocator, &[_][]const u8{ cache_dir, file_name });
    defer allocator.free(cache_file);
    std.debug.print("File: {s}\n", .{cache_file});
    // Open the file
    const file: std.fs.File = std.fs.cwd().createFile(cache_file, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) return;
        return err;
    };
    defer file.close();
    // Write the palette data to the file
    const entries: usize = pal.values.len;
    const bytes_per_entry: usize = 3 * @sizeOf(f32) + @sizeOf(u32); // 3 color parts + 1 weight
    const total_bytes: usize = entries * bytes_per_entry + 1; // Adding one to write the color type
    const buffer: []u8 = try allocator.alloc(u8, total_bytes);
    defer allocator.free(buffer);
    var ptr: [*]u8 = buffer.ptr;
    // Write the color type first
    const tag: u8 = @as(u8, @intCast(@intFromEnum(std.meta.activeTag(pal.values[0].clr))));
    ptr[0] = tag;
    ptr += 1;
    // Write all the color palette values
    for (pal.values) |value| {
        const vals: [3]f32 = value.clr.values();
        const vals_bytes = std.mem.asBytes(&vals);
        @memcpy(ptr[0..vals_bytes.len], vals_bytes);
        ptr += vals_bytes.len;
        const weight_bytes = std.mem.asBytes(&value.weight);
        @memcpy(ptr[0..weight_bytes.len], weight_bytes);
        ptr += weight_bytes.len;
    }
    try file.writeAll(buffer);
}

pub fn readPaletteCache(allocator: std.mem.Allocator, img_file_path: []const u8) !?palette.Palette {
    const palette_name: []const u8 = std.fs.path.basename(img_file_path);
    // Get the combined file path (cache_dir/pal.name.bin)
    const cache_dir: []const u8 = try getCacheDir(allocator);
    defer allocator.free(cache_dir);
    const file_name: []const u8 = try std.fmt.allocPrint(allocator, "{s}.bin", .{palette_name});
    defer allocator.free(file_name);
    const cache_file: []const u8 = try std.fs.path.join(allocator, &[_][]const u8{ cache_dir, file_name });
    defer allocator.free(cache_file);
    // Open cache file if it exists
    const file: std.fs.File = std.fs.cwd().openFile(cache_file, .{}) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };
    defer file.close();
    // Read the palette data from the file
    const buffer: []u8 = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(buffer);
    if (buffer.len == 0) return error.InvalidData;
    // Read the color type first
    const tag: std.meta.Tag(color.Color) = @enumFromInt(buffer[0]);
    var remaining: []u8 = buffer[1..]; // Skip the tag byte
    const entry_size = @sizeOf([3]f32) + @sizeOf(u32);
    const data_length: usize = remaining.len;
    const entries: usize = data_length / entry_size;
    if (data_length % entry_size != 0) return error.InvalidData;
    const values: []palette.Palette.Value = try allocator.alloc(palette.Palette.Value, entries);
    for (0..entries) |i| {
        const clr_bytes: []const u8 = remaining[0..@sizeOf([3]f32)];
        const clr: [3]f32 = std.mem.bytesToValue([3]f32, clr_bytes);
        remaining = remaining[@sizeOf([3]f32)..];
        const weight_bytes: []const u8 = remaining[0..@sizeOf(u32)];
        const weight: u32 = std.mem.bytesToValue(u32, weight_bytes);
        remaining = remaining[@sizeOf(u32)..];
        values[i].weight = weight;
        values[i].clr = switch (tag) {
            .rgb => .{ .rgb = .{ .r = clr[0], .g = clr[1], .b = clr[2] } },
            .hsl => .{ .hsl = .{ .h = clr[0], .s = clr[1], .l = clr[2] } },
            .xyz => .{ .xyz = .{ .x = clr[0], .y = clr[1], .z = clr[2] } },
            .lab => .{ .lab = .{ .l = clr[0], .a = clr[1], .b = clr[2] } },
        };
    }
    return .{ .name = palette_name, .values = values };
}
