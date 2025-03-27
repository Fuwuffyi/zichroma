const std = @import("std");
const builtin = @import("builtin");
const color = @import("color.zig");
const modulation_curve = @import("modulation_curve.zig");

const HeaderSections = enum { none, core, profile, template };

const Theme = enum { auto, dark, light };

const Template = struct {
    template_in: []const u8,
    config_out: []const u8,
    post_cmd: ?[]const u8,
};

pub const Config = struct {
    cluster_count: u32,
    color_space: color.ColorSpace,
    profile: []const u8,
    theme: Theme,
    profiles: std.StringHashMap(modulation_curve.ModulationCurve),
    templates: std.StringHashMap(Template),
    arena: std.heap.ArenaAllocator,

    pub fn init(alloc: std.mem.Allocator) !@This() {
        var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(alloc);
        errdefer arena.deinit();
        const allocator: std.mem.Allocator = arena.allocator();
        // Grab the configuration file
        const file: std.fs.File = try findConfigFile(allocator) orelse return error.ConfigFileNotFound;
        defer file.close();
        // Read the contents of the configuration file
        const file_contents: []const u8 = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(file_contents);
        // Create return var
        var config: Config = undefined;
        // Initialize hash maps
        config.arena = arena;
        config.profiles = std.StringHashMap(modulation_curve.ModulationCurve).init(allocator);
        config.templates = std.StringHashMap(Template).init(allocator);
        // Section related variables
        var current_section: HeaderSections = .none;
        var current_name: []const u8 = undefined;
        // Loop over file lines
        var lines = std.mem.splitScalar(u8, file_contents, '\n');
        blk: while (lines.next()) |line| {
            // Clean up lines
            const trimmed_line: []const u8 = std.mem.trim(u8, line, " \t\r");
            var split_iterator = std.mem.splitScalar(u8, trimmed_line, '#');
            const stripped_line: []const u8 = split_iterator.first();
            const cleaned_line: []const u8 = std.mem.trim(u8, stripped_line, " \t");
            // Skip empty lines
            if (cleaned_line.len == 0) continue;
            // Check if section header
            if (cleaned_line[0] == '[') {
                // Parse new section header
                const end_idx: usize = std.mem.indexOfScalar(u8, cleaned_line, ']') orelse continue;
                const section: []const u8 = std.mem.trim(u8, cleaned_line[1..end_idx], " \t");
                if (std.mem.eql(u8, section, "core")) {
                    current_section = .core;
                } else if (std.mem.startsWith(u8, section, "profile.")) {
                    current_section = .profile;
                    current_name = section["profile.".len..];
                    try config.profiles.put(try allocator.dupe(u8, current_name), modulation_curve.ModulationCurve.init(allocator, undefined));
                } else if (std.mem.startsWith(u8, section, "template.")) {
                    current_section = .template;
                    current_name = section["template.".len..];
                    try config.templates.put(try allocator.dupe(u8, current_name), undefined);
                } else {
                    return error.UnknownSection;
                }
                continue :blk;
            }
            // Get key value pair of current line
            const eq_pos: usize = std.mem.indexOfScalar(u8, cleaned_line, '=') orelse continue;
            const key: []const u8 = std.mem.trim(u8, cleaned_line[0..eq_pos], " \t");
            const value: []const u8 = std.mem.trim(u8, cleaned_line[eq_pos + 1 ..], " \t");
            // Set current value to current section
            switch (current_section) {
                .core => {
                    if (std.mem.eql(u8, key, "cluster_count")) {
                        config.cluster_count = try std.fmt.parseUnsigned(u32, value, 10);
                    } else if (std.mem.eql(u8, key, "color_space")) {
                        config.color_space = std.meta.stringToEnum(color.ColorSpace, value) orelse return error.InvalidColorSpace;
                    } else if (std.mem.eql(u8, key, "profile")) {
                        config.profile = try allocator.dupe(u8, value);
                    } else if (std.mem.eql(u8, key, "theme")) {
                        config.theme = std.meta.stringToEnum(Theme, value) orelse return error.InvalidTheme;
                    } else {
                        return error.UnknownCoreSetting;
                    }
                },
                .profile => {
                    if (std.mem.eql(u8, key, "color_space")) {
                        config.profiles.getPtr(current_name).?.color_space = std.meta.stringToEnum(color.ColorSpace, value) orelse return error.InvalidColorSpace;
                    } else if (std.mem.startsWith(u8, key, "color_")) {
                        try config.profiles.getPtr(current_name).?.curve_values.append(try parseModulationValue(value));
                    } else {
                        return error.UnknownProfileSetting;
                    }
                },
                .template => {
                    if (std.mem.eql(u8, key, "template_in")) {
                        config.templates.getPtr(current_name).?.template_in = try allocator.dupe(u8, value);
                    } else if (std.mem.eql(u8, key, "config_out")) {
                        config.templates.getPtr(current_name).?.config_out = try allocator.dupe(u8, value);
                    } else if (std.mem.eql(u8, key, "post_cmd")) {
                        config.templates.getPtr(current_name).?.post_cmd = try allocator.dupe(u8, value);
                    } else {
                        return error.UnknownTemplateSetting;
                    }
                },
                else => return error.OrphanedKeyValue,
            }
        }
        // Temporairly print to console
        return config;
    }

    pub fn deinit(self: *const @This()) void {
        // Deinit templates
        defer self.arena.deinit();
    }
};

fn parseModulationValue(s: []const u8) !modulation_curve.ModulationCurve.Value {
    const trimmed: []const u8 = std.mem.trim(u8, s, "() ");
    var parts = std.mem.splitScalar(u8, trimmed, ',');
    var values: [3]?f32 = .{null} ** 3;
    var i: usize = 0;
    while (parts.next()) |part| : (i += 1) {
        if (i >= 3) return error.TooManyModulationValues;
        const val_str: []const u8 = std.mem.trim(u8, part, " \t");
        if (std.mem.eql(u8, val_str, "null")) {
            values[i] = null;
        } else {
            values[i] = try std.fmt.parseFloat(f32, val_str);
        }
    }
    if (i < 3) return error.TooFewModulationValues;
    return .{ .a_mod = values[0], .b_mod = values[1], .c_mod = values[2] };
}

const config_file_name: []const u8 = "config.conf";
const config_dir_name: []const u8 = "zig_colortheme_generator";

fn findConfigFile(allocator: std.mem.Allocator) !?std.fs.File {
    const config_dir: ?[]const u8 = try getConfigDir(allocator);
    defer if (config_dir) |dir| allocator.free(dir);
    // Check config directory first
    if (config_dir) |dir| {
        if (try openFileInDir(allocator, dir, config_file_name)) |file| return file;
    }
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
fn getConfigDir(allocator: std.mem.Allocator) !?[]const u8 {
    switch (builtin.target.os.tag) {
        .linux => {
            // Check XDG_CONFIG_HOME first
            const xdg_config_dir: []const u8 = std.process.getEnvVarOwned(allocator, "XDG_CONFIG_HOME") catch |err| {
                if (err != error.EnvironmentVariableNotFound) return null;
                // Else check HOME variable
                const home_dir: []const u8 = std.process.getEnvVarOwned(allocator, "HOME") catch return null;
                defer allocator.free(home_dir);
                return try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".config", config_dir_name });
            };
            defer allocator.free(xdg_config_dir);
            return try std.fs.path.join(allocator, &[_][]const u8{ xdg_config_dir, config_dir_name });
        },
        .windows => {
            return null;
        },
        .macos => {
            return null;
        },
        else => return error.UnsupportedOS,
    }
}
