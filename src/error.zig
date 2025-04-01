const std = @import("std");

const errorMessages: std.StaticStringMap([]const u8) = std.StaticStringMap([]const u8).initComptime(.{
    // General
    .{"UnsupportedOS", "Your OS is currently unsupported, please write an issue or make a pr on github."},
    .{"FileCreationError", "Could not create file: {s}."},
    .{"FileOpenError", "Could not open file: {s}."},
    .{"MissingHomeDir", "Could not read $XDG_CACHE_HOME nor $HOME env vars."},
    .{"MissingLocalAppData", "Could not locate AppData directory."},
    // Clustering errors
    .{"EmptyPalette", "The palette of the current image is empty."},
    .{"InvalidK", "The cluster_count value is invalid."},
    // Cache errors
    .{"InvalidData", "The cache file is invalid.\nPath: {s}"}
});

pub fn logError(comptime err: anyerror, args: anytype) anyerror {
    const key: [:0]const u8 = comptime @errorName(err);
    comptime {
        if (!errorMessages.has(key)) {
            @compileError("The error " ++ key ++ " has no associated string.");
        }
    }
    std.log.err(errorMessages.get(key).?, args);
    return err;
}
