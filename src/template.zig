const std = @import("std");
const builtin = @import("builtin");
const color = @import("color.zig");

pub const TemplateValue = struct {
    primary_color: color.Color,
    text_color: color.Color,
    accent_colors: []const color.Color
};

pub fn applyTemplate(template_path: []const u8, out_path: []const u8, colors: []const TemplateValue, command: ?[]const u8, allocator: std.mem.Allocator) !void {
    _ = template_path;
    _ = out_path;
    _ = colors;
    // Run the command after applying the template and colors
    if (command) |cmd| {
        try runCommand(allocator, cmd);
    }
}

fn executeCommand(allocator: std.mem.Allocator, command: []const u8) !struct {stdout: []u8, stderr: []u8, term: std.process.Child.Term} {
    // Handle shell execution for string commands
    const shell_cmd: []const []const u8 = 
        if (builtin.target.os.tag == .windows) 
            &[_][]const u8{"cmd.exe", "/C", command} 
        else 
            &[_][]const u8{"/bin/sh", "-c", command};
    const argv: []const []const u8 = shell_cmd;
    var child = std.process.Child.init(argv, allocator);
    // Capture output
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    // Read output streams
    const stdout = try child.stdout.?.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    errdefer allocator.free(stdout);
    const stderr = try child.stderr.?.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    errdefer allocator.free(stderr);
    const term = try child.wait();
    return .{
        .stdout = stdout,
        .stderr = stderr,
        .term = term,
    };
}

fn runCommand(allocator: std.mem.Allocator, command: []const u8) !void {
    const result = try executeCommand(allocator, command);
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    if (result.stdout.len > 0) {
        std.debug.print("{s}\n", .{result.stdout});
    }
    if (result.stderr.len > 0) {
        std.debug.print("ERROR: {s}\n", .{result.stderr});
    }
    switch (result.term) {
        .Exited => |code| if (code != 0) {
            return error.CommandFailed;
        },
        else => return error.CommandFailed,
    }
}
