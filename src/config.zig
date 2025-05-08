const std = @import("std");
const builtin = @import("builtin");
const color = @import("color/color.zig");
const modulation_curve = @import("modulation_curve.zig");
const logError = @import("error.zig").logError;

const config_file_name: []const u8 = "config.conf";
const config_dir_name: []const u8 = "zichroma";

const HeaderSections = enum { none, core, profile, template };

const Theme = enum { auto, dark, light };

const Template = struct {
    template_in: []const u8,
    config_out: []const u8,
    post_cmd: ?[]const u8,
};

pub const Config = struct {
    cluster_count: u32,
    weight_exponent: f32,
    color_space: color.ColorSpace,
    profile: []const u8,
    theme: Theme,
    profiles: std.StringHashMap(modulation_curve.ModulationCurve),
    templates: std.StringHashMap(Template),

    pub fn init(allocator: std.mem.Allocator) !@This() {
        // Create default configuration
        var config: Config = .{
            .cluster_count = 4,
            .weight_exponent = 1.0,
            .color_space = .lab,
            .profile = try allocator.dupe(u8, "base"),
            .theme = .auto,
            .profiles = std.StringHashMap(modulation_curve.ModulationCurve).init(allocator),
            .templates = std.StringHashMap(Template).init(allocator),
        };
        errdefer {
            allocator.free(config.profile);
            var it = config.profiles.valueIterator();
            while (it.next()) |c| {
                c.deinit();
            }
            config.profiles.deinit();
            config.templates.deinit();
        }
        // Grab the configuration file
        const file: std.fs.File = try findConfigFile(allocator) orelse return logError(error.ConfigFileNotFound, .{});
        defer file.close();
        // Read the contents of the configuration file
        const file_contents: []const u8 = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(file_contents);
        // Section related variables
        var current_section: HeaderSections = .none;
        var current_name: []const u8 = undefined;
        // Loop over file lines
        var lines = std.mem.splitScalar(u8, file_contents, '\n');
        while (lines.next()) |line| {
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
                const section = try parseSectionHeader(cleaned_line);
                current_section = section.type;
                current_name = section.name;
                switch (section.type) {
                    .profile => {
                        const name: []const u8 = try allocator.dupe(u8, current_name);
                        try config.profiles.put(name, modulation_curve.ModulationCurve.init(allocator, undefined));
                    },
                    .template => {
                        const name: []const u8 = try allocator.dupe(u8, current_name);
                        try config.templates.put(name, .{
                            .template_in = "",
                            .config_out = "",
                            .post_cmd = null,
                        });
                    },
                    else => {},
                }
                continue;
            }
            // Handle the current line property
            const kv = try parseKeyValue(cleaned_line);
            try handleKeyValue(allocator, &config, current_section, current_name, kv.key, kv.value);
        }
        // Temporairly print to console
        return config;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        // Deinit templates
        defer self.templates.deinit();
        var template_it = self.templates.iterator();
        while (template_it.next()) |template| {
            defer allocator.free(template.key_ptr.*);
            defer allocator.free(template.value_ptr.template_in);
            defer allocator.free(template.value_ptr.config_out);
            if (template.value_ptr.post_cmd) |cmd| {
                defer allocator.free(cmd);
            }
        }
        // Deinit color curves
        defer self.profiles.deinit();
        var profiles_it = self.profiles.iterator();
        while (profiles_it.next()) |profile| {
            defer allocator.free(profile.key_ptr.*);
            defer profile.value_ptr.deinit();
        }
        // Deinit core profile
        defer allocator.free(self.profile);
    }
};

fn parseSectionHeader(line: []const u8) !struct { type: HeaderSections, name: []const u8 } {
    const end_idx: usize = std.mem.indexOfScalar(u8, line, ']') orelse return logError(error.InvalidSectionHeader, .{line});
    const section: []const u8 = std.mem.trim(u8, line[1..end_idx], " \t");
    if (std.mem.eql(u8, section, "core")) {
        return .{ .type = .core, .name = undefined };
    } else if (std.mem.startsWith(u8, section, "profile.")) {
        return .{ .type = .profile, .name = section["profile.".len..] };
    } else if (std.mem.startsWith(u8, section, "template.")) {
        return .{ .type = .template, .name = section["template.".len..] };
    } else {
        return logError(error.UnknownSection, .{ section, line });
    }
}

fn parseKeyValue(line: []const u8) !struct { key: []const u8, value: []const u8 } {
    const eq_pos: usize = std.mem.indexOfScalar(u8, line, '=') orelse return logError(error.InvalidKeyValue, .{line});
    return .{
        .key = std.mem.trim(u8, line[0..eq_pos], " \t"),
        .value = std.mem.trim(u8, line[eq_pos + 1 ..], " \t"),
    };
}

fn handleKeyValue(allocator: std.mem.Allocator, config: *Config, section: HeaderSections, section_name: []const u8, key: []const u8, value: []const u8) !void {
    switch (section) {
        .core => try handleCoreSetting(allocator, config, key, value),
        .profile => try handleProfileSetting(config, section_name, key, value),
        .template => try handleTemplateSetting(allocator, config, section_name, key, value),
        else => return logError(error.OrphanedKeyValue, .{key}),
    }
}

fn handleCoreSetting(allocator: std.mem.Allocator, config: *Config, key: []const u8, value: []const u8) !void {
    if (std.mem.eql(u8, key, "cluster_count")) {
        config.cluster_count = try std.fmt.parseUnsigned(u32, value, 10);
    } else if (std.mem.eql(u8, key, "color_space")) {
        config.color_space = std.meta.stringToEnum(color.ColorSpace, value) orelse return logError(error.InvalidColorSpace, .{value});
    } else if (std.mem.eql(u8, key, "profile")) {
        const new_profile: []const u8 = try allocator.dupe(u8, value);
        allocator.free(config.profile);
        config.profile = new_profile;
    } else if (std.mem.eql(u8, key, "theme")) {
        config.theme = std.meta.stringToEnum(Theme, value) orelse return logError(error.InvalidTheme, .{value});
    } else {
        return logError(error.UnknownCoreSetting, .{key});
    }
}

fn handleProfileSetting(config: *Config, profile_name: []const u8, key: []const u8, value: []const u8) !void {
    const profile: *modulation_curve.ModulationCurve = config.profiles.getPtr(profile_name) orelse return logError(error.ProfileNotFound, .{profile_name});
    if (std.mem.eql(u8, key, "color_space")) {
        profile.color_space = std.meta.stringToEnum(color.ColorSpace, value) orelse return logError(error.InvalidColorSpace, .{value});
    } else if (std.mem.startsWith(u8, key, "color_")) {
        try profile.curve_values.append(try parseModulationValue(value));
    } else {
        return logError(error.UnknownProfileSetting, .{key});
    }
}

fn handleTemplateSetting(
    allocator: std.mem.Allocator,
    config: *Config,
    template_name: []const u8,
    key: []const u8,
    value: []const u8,
) !void {
    const template: *Template = config.templates.getPtr(template_name) orelse return logError(error.TemplateNotFound, .{template_name});
    if (std.mem.eql(u8, key, "template_in")) {
        template.template_in = try expandPath(allocator, value);
    } else if (std.mem.eql(u8, key, "config_out")) {
        template.config_out = try expandPath(allocator, value);
    } else if (std.mem.eql(u8, key, "post_cmd")) {
        template.post_cmd = try allocator.dupe(u8, value);
    } else {
        return logError(error.UnknownTemplateSetting, .{key});
    }
}

fn expandTilde(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, path, "~/")) {
        const home: []const u8 = std.process.getEnvVarOwned(allocator, "HOME") catch "";
        defer allocator.free(home);
        return std.fs.path.join(allocator, &[_][]const u8{ home, path[2..] });
    }
    return allocator.dupe(u8, path);
}

fn expandEnvVars(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = std.ArrayList(u8).init(allocator);
    defer result.deinit();
    var i: usize = 0;
    while (i < path.len) {
        if (path[i] == '$' and (i + 1 < path.len)) {
            const start: usize = i + 1;
            var end: usize = start;
            var brace: bool = false;
            if (path[start] == '{') {
                brace = true;
                end += 1;
                while (end < path.len and path[end] != '}') : (end += 1) {}
                if (end >= path.len) return error.UnclosedBrace;
            } else {
                while (end < path.len and (std.ascii.isAlphanumeric(path[end]) or path[end] == '_')) : (end += 1) {}
            }
            const var_name: []const u8 = if (brace) path[start + 1 .. end] else path[start..end];
            const var_value: []const u8 = std.process.getEnvVarOwned(allocator, var_name) catch "";
            defer allocator.free(var_value);
            try result.appendSlice(var_value);
            i = if (brace) end + 1 else end;
        } else {
            try result.append(path[i]);
            i += 1;
        }
    }
    return result.toOwnedSlice();
}

fn expandPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const tilde_expanded = try expandTilde(allocator, path);
    defer allocator.free(tilde_expanded);
    return expandEnvVars(allocator, tilde_expanded);
}

fn parseModulationValue(s: []const u8) !modulation_curve.ModulationCurve.Value {
    const trimmed: []const u8 = std.mem.trim(u8, s, "() ");
    var parts = std.mem.splitScalar(u8, trimmed, ',');
    var values: [3]?f32 = .{ null, null, null };
    for (&values) |*val| {
        const part: []const u8 = parts.next() orelse return logError(error.TooFewModulationValues, .{s});
        const val_str: []const u8 = std.mem.trim(u8, part, " \t");
        if (val_str.len == 0) continue;
        val.* = if (std.mem.eql(u8, val_str, "null")) null else try std.fmt.parseFloat(f32, val_str);
    }
    if (parts.next() != null) return logError(error.TooManyModulationValues, .{s});
    return .{ .a_mod = values[0], .b_mod = values[1], .c_mod = values[2] };
}

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
            const appdata_dir: []const u8 = std.process.getEnvVarOwned(allocator, "APPDATA") catch return null;
            defer allocator.free(appdata_dir);
            return try std.fs.path.join(allocator, &[_][]const u8{ appdata_dir, config_dir_name });
        },
        .macos => {
            const home_dir: []const u8 = std.process.getEnvVarOwned(allocator, "HOME") catch return null;
            defer allocator.free(home_dir);
            return try std.fs.path.join(allocator, &[_][]const u8{ home_dir, "Library", "Application Support", config_dir_name });
        },
        else => return logError(error.UnsupportedOS, .{}),
    }
}
